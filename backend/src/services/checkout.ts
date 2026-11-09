import type { PoolConnection } from 'mysql2/promise';
import { config } from '../config.js';
import { IST_TODAY, exec, isDuplicateKey, one, pool, rows, withTx } from '../db/pool.js';
import { AppError, badRequest, conflict, forbidden, notFound } from '../errors.js';
import { scheduleHoldExpiry } from '../jobs/holdExpiry.js';
import { gateway } from '../payments/gateway.js';
import { billTaxPaise, canteenTakesOrders, effectiveStallStatus, toPaise, toRupees } from '../util.js';
import { audit } from './audit.js';
import { bustMenuCache } from './menu.js';
import { loadOrder } from './orders.js';

export interface CartLine {
  productId: number;
  qty: number;
}

export interface Shortage {
  productId: string;
  name: string;
  requested: number;
  available: number;
}

interface LockedProduct {
  product_id: number;
  stall_id: number;
  product_name: string;
  price: number;
  stock_quantity: number;
  is_active: number;
  approval_status: string;
  on_menu: number;
  canteen_id: number;
  stall_status: 'open' | 'paused' | 'closed';
  paused_until: Date | null;
  stall_active: number;
  stall_name: string;
  gst_rate: number;
}

/** Adds up repeated products so each product appears once. */
function mergeLines(items: CartLine[]) {
  const map = new Map<number, number>();
  for (const { productId, qty } of items) map.set(productId, (map.get(productId) ?? 0) + qty);
  return [...map.entries()].map(([productId, qty]) => ({ productId, qty })).sort((a, b) => a.productId - b.productId);
}

/** Recomputes every bill and the order header from their items (all money on the server, in paise). */
export async function recalcTotals(conn: PoolConnection, orderId: number) {
  const bills = await rows<{ stall_order_id: number }>(conn, 'SELECT stall_order_id FROM stall_orders WHERE order_id = ?', [orderId]);
  let subtotal = 0;
  let tax = 0;
  for (const bill of bills) {
    const items = await rows<{ price: number; quantity: number; gst_rate: number }>(
      conn,
      "SELECT price, quantity, gst_rate FROM order_items WHERE stall_order_id = ? AND item_status = 'active'",
      [bill.stall_order_id],
    );
    const lines = items.map((i) => ({ pricePaise: toPaise(i.price), quantity: i.quantity, gstRate: i.gst_rate }));
    const billSubtotal = lines.reduce((s, l) => s + l.pricePaise * l.quantity, 0);
    const billTax = billTaxPaise(lines);
    subtotal += billSubtotal;
    tax += billTax;
    await exec(conn, 'UPDATE stall_orders SET subtotal = ?, tax = ?, total = ? WHERE stall_order_id = ?', [
      toRupees(billSubtotal),
      toRupees(billTax),
      toRupees(billSubtotal + billTax),
      bill.stall_order_id,
    ]);
  }
  const fee = toPaise(config.CONVENIENCE_FEE);
  await exec(conn, 'UPDATE orders SET subtotal = ?, tax = ?, convenience_fee = ?, total = ? WHERE order_id = ?', [
    toRupees(subtotal),
    toRupees(tax),
    toRupees(fee),
    toRupees(subtotal + tax + fee),
    orderId,
  ]);
}

/**
 * Reserve stock and create the order (blueprint 4.1). One transaction:
 * lock the product rows in product_id order (so two checkouts never deadlock), take
 * min(requested, available) of each, and hold it for HOLD_MINUTES. Nothing is charged yet.
 */
export async function checkout(userId: number, input: { canteenId: number; items: CartLine[]; idempotencyKey: string }) {
  const existing = await one<{ order_id: number }>(pool, 'SELECT order_id FROM orders WHERE user_id = ? AND idempotency_key = ?', [
    userId,
    input.idempotencyKey,
  ]);
  if (existing) return describeCheckout(existing.order_id); // a retry gets the same order, never a second one

  const user = await one<{ ordering_paused_until: Date | null }>(pool, 'SELECT ordering_paused_until FROM users WHERE user_id = ?', [userId]);
  if (user?.ordering_paused_until && user.ordering_paused_until.getTime() > Date.now()) {
    throw forbidden('ORDERING_PAUSED', 'Ordering is paused on your account because of missed pickups.');
  }

  const lines = mergeLines(input.items);
  const canteen = await one(pool, 'SELECT * FROM canteens WHERE canteen_id = ? AND is_active = TRUE', [input.canteenId]);
  if (!canteen) throw notFound('CANTEEN_NOT_FOUND', 'Canteen not found');
  if (!canteenTakesOrders(canteen as never)) throw conflict('CANTEEN_CLOSED', 'This canteen is not taking orders right now.');

  let orderId: number;
  try {
    orderId = await withTx(async (conn) => {
      const products = await rows<LockedProduct>(
        conn,
        `SELECT p.product_id, p.stall_id, p.product_name, p.price, p.stock_quantity, p.is_active, p.approval_status,
                (dm.product_id IS NOT NULL) AS on_menu,
                s.canteen_id, s.status AS stall_status, s.paused_until, s.is_active AS stall_active, s.stall_name, s.gst_rate
           FROM products p
           JOIN stalls s ON s.stall_id = p.stall_id
           LEFT JOIN daily_menu dm ON dm.product_id = p.product_id AND dm.menu_date = ${IST_TODAY}
          WHERE p.product_id IN (?)
          ORDER BY p.product_id
            FOR UPDATE OF p`,
        [lines.map((l) => l.productId)],
      );
      const byId = new Map(products.map((p) => [p.product_id, p]));

      for (const line of lines) {
        const p = byId.get(line.productId);
        if (!p) throw notFound('PRODUCT_NOT_FOUND', `Item ${line.productId} does not exist`);
        if (p.canteen_id !== input.canteenId) throw badRequest('MIXED_CANTEEN', 'All items must come from the same canteen.');
        if (!p.is_active || p.approval_status !== 'published' || !p.on_menu || !p.stall_active) {
          throw conflict('ITEM_UNAVAILABLE', `${p.product_name} is not on today's menu.`, { productId: String(p.product_id) });
        }
        const stallStatus = effectiveStallStatus({ status: p.stall_status, paused_until: p.paused_until });
        if (stallStatus !== 'open') {
          throw conflict('STALL_NOT_OPEN', `${p.stall_name} is ${stallStatus} right now.`, { stallId: String(p.stall_id), status: stallStatus });
        }
      }

      const taken = lines.map((line) => {
        const p = byId.get(line.productId)!;
        return { line, p, take: Math.min(line.qty, Math.max(0, p.stock_quantity)) };
      });
      if (taken.every((t) => t.take === 0)) {
        throw conflict('OUT_OF_STOCK', 'Everything in your cart is sold out.', {
          shortages: taken.map((t) => ({ productId: String(t.p.product_id), name: t.p.product_name, requested: t.line.qty, available: 0 })),
        });
      }

      // Atomic stock reduction (blueprint query A). The rows are locked, so this cannot oversell.
      for (const t of taken) {
        if (t.take === 0) continue;
        const r = await exec(conn, 'UPDATE products SET stock_quantity = stock_quantity - ? WHERE product_id = ? AND stock_quantity >= ?', [
          t.take,
          t.p.product_id,
          t.take,
        ]);
        if (r.affectedRows !== 1) throw new AppError(409, 'STOCK_CHANGED', 'Stock changed while ordering. Please try again.');
      }

      const holdSeconds = Math.round(config.HOLD_MINUTES * 60);
      const order = await exec(
        conn,
        `INSERT INTO orders (user_id, canteen_id, idempotency_key, subtotal, tax, convenience_fee, total, payment_expires_at)
         VALUES (?, ?, ?, 0, 0, 0, 0, UTC_TIMESTAMP() + INTERVAL ? SECOND)`,
        [userId, input.canteenId, input.idempotencyKey, holdSeconds],
      );
      const newOrderId = order.insertId;

      const stallIds = [...new Set(taken.map((t) => t.p.stall_id))];
      for (const stallId of stallIds) {
        const bill = await exec(conn, 'INSERT INTO stall_orders (order_id, stall_id, canteen_id, subtotal, tax, total) VALUES (?, ?, ?, 0, 0, 0)', [
          newOrderId,
          stallId,
          input.canteenId,
        ]);
        for (const t of taken.filter((x) => x.p.stall_id === stallId)) {
          const item = await exec(
            conn,
            `INSERT INTO order_items (stall_order_id, product_id, product_name, price, gst_rate, qty_requested, quantity)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [bill.insertId, t.p.product_id, t.p.product_name, t.p.price, t.p.gst_rate, t.line.qty, t.take],
          );
          if (t.take > 0) {
            await exec(
              conn,
              `INSERT INTO stock_holds (order_id, item_id, product_id, qty, expires_at)
               VALUES (?, ?, ?, ?, UTC_TIMESTAMP() + INTERVAL ? SECOND)`,
              [newOrderId, item.insertId, t.p.product_id, t.take, holdSeconds],
            );
          }
        }
      }
      await recalcTotals(conn, newOrderId);
      await audit(conn, { id: userId, role: 'student' }, 'checkout', 'orders', newOrderId, undefined, { lines });
      return newOrderId;
    });
  } catch (err) {
    if (isDuplicateKey(err)) {
      // Two identical requests raced: the other one created the order. Return it.
      const again = await one<{ order_id: number }>(pool, 'SELECT order_id FROM orders WHERE user_id = ? AND idempotency_key = ?', [
        userId,
        input.idempotencyKey,
      ]);
      if (again) return describeCheckout(again.order_id);
    }
    throw err;
  }

  await bustMenuCache([input.canteenId]);
  const created = await one<{ payment_expires_at: Date }>(pool, 'SELECT payment_expires_at FROM orders WHERE order_id = ?', [orderId]);
  await scheduleHoldExpiry(orderId, created!.payment_expires_at);
  const shortages = await shortagesOf(orderId);
  if (!shortages.length) await ensurePaymentOrder(orderId);
  return describeCheckout(orderId);
}

async function shortagesOf(orderId: number): Promise<Shortage[]> {
  const items = await rows(
    pool,
    `SELECT oi.product_id, oi.product_name, oi.qty_requested, oi.quantity
       FROM order_items oi JOIN stall_orders so ON so.stall_order_id = oi.stall_order_id
      WHERE so.order_id = ? AND oi.quantity < oi.qty_requested`,
    [orderId],
  );
  return items.map((i) => ({ productId: String(i.product_id), name: i.product_name, requested: i.qty_requested, available: i.quantity }));
}

/** Creates the gateway order once, for an order with no shortages left. */
export async function ensurePaymentOrder(orderId: number) {
  const order = await one<{ status: string; total: number; gateway_order_ref: string | null }>(
    pool,
    'SELECT status, total, gateway_order_ref FROM orders WHERE order_id = ?',
    [orderId],
  );
  if (!order || order.status !== 'pending' || order.gateway_order_ref) return;
  const { gatewayOrderRef } = await gateway.createOrder({ orderId, amountPaise: toPaise(order.total) });
  await exec(pool, 'UPDATE orders SET gateway_order_ref = ? WHERE order_id = ? AND gateway_order_ref IS NULL', [gatewayOrderRef, orderId]);
}

/** What the app needs after checkout: the order, any "only N left" shortages, and how to pay. */
export async function describeCheckout(orderId: number) {
  const order = await loadOrder(pool, orderId);
  if (!order) throw notFound('ORDER_NOT_FOUND', 'Order not found');
  const shortages = order.gatewayOrderRef ? [] : await shortagesOf(orderId);
  return {
    order,
    shortages,
    needsConfirmation: order.status === 'pending' && shortages.length > 0,
    payment:
      order.status === 'pending' && order.gatewayOrderRef
        ? { gateway: gateway.name, gatewayOrderRef: order.gatewayOrderRef, amountPaise: toPaise(order.total), currency: 'INR', expiresAt: order.paymentExpiresAt }
        : null,
  };
}

/**
 * The student answers the "Only N left" prompt: keep the reduced quantity, or remove the line.
 * Removed lines release their hold straight away. Then the payment order is created.
 */
export async function confirmPartial(userId: number, orderId: number, decisions: { productId: number; action: 'take_available' | 'remove' }[]) {
  const removeIds = new Set(decisions.filter((d) => d.action === 'remove').map((d) => d.productId));
  const canteenId = await withTx(async (conn) => {
    const order = await one(conn, 'SELECT * FROM orders WHERE order_id = ? AND user_id = ? FOR UPDATE', [orderId, userId]);
    if (!order) throw notFound('ORDER_NOT_FOUND', 'Order not found');
    if (order.status !== 'pending') throw conflict('ORDER_NOT_PENDING', `This order is ${order.status}.`);
    if (order.gateway_order_ref) throw conflict('ALREADY_CONFIRMED', 'This order is already waiting for payment.');
    if ((order.payment_expires_at as Date).getTime() <= Date.now()) throw conflict('ORDER_EXPIRED', 'The 5-minute hold has run out. Please check out again.');

    const items = await rows(
      conn,
      `SELECT oi.* FROM order_items oi JOIN stall_orders so ON so.stall_order_id = oi.stall_order_id
        WHERE so.order_id = ? ORDER BY oi.product_id`,
      [orderId],
    );
    for (const item of items) {
      if (!removeIds.has(item.product_id) && item.quantity > 0) continue;
      const hold = await one(conn, "SELECT * FROM stock_holds WHERE item_id = ? AND status = 'held' FOR UPDATE", [item.item_id]);
      if (hold) {
        await exec(conn, 'UPDATE products SET stock_quantity = stock_quantity + ? WHERE product_id = ?', [hold.qty, hold.product_id]);
        await exec(conn, 'DELETE FROM stock_holds WHERE hold_id = ?', [hold.hold_id]);
      }
      await exec(conn, 'DELETE FROM order_items WHERE item_id = ?', [item.item_id]);
    }
    // Everything left is accepted at the reserved quantity.
    await exec(
      conn,
      `UPDATE order_items oi JOIN stall_orders so ON so.stall_order_id = oi.stall_order_id
          SET oi.qty_requested = oi.quantity WHERE so.order_id = ?`,
      [orderId],
    );
    await exec(
      conn,
      `DELETE so FROM stall_orders so
        WHERE so.order_id = ? AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.stall_order_id = so.stall_order_id)`,
      [orderId],
    );
    const left = await one<{ n: number }>(conn, 'SELECT COUNT(*) AS n FROM stall_orders WHERE order_id = ?', [orderId]);
    if (!left || Number(left.n) === 0) {
      await exec(conn, "UPDATE orders SET status = 'cancelled', subtotal = 0, tax = 0, total = 0 WHERE order_id = ?", [orderId]);
    } else {
      await recalcTotals(conn, orderId);
    }
    await audit(conn, { id: userId, role: 'student' }, 'confirm_partial', 'orders', orderId, undefined, { decisions });
    return order.canteen_id as number;
  });
  await bustMenuCache([canteenId]);
  await ensurePaymentOrder(orderId);
  return describeCheckout(orderId);
}
