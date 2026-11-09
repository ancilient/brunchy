import { randomInt } from 'node:crypto';
import type { PoolConnection } from 'mysql2/promise';
import { IST_TODAY, exec, isDuplicateKey, one, rows, withTx } from '../db/pool.js';
import { AppError } from '../errors.js';
import { logger } from '../logger.js';
import { gateway, type PaymentEvent } from '../payments/gateway.js';
import { publishBills, publishOrder } from '../realtime.js';
import { toPaise, toRupees } from '../util.js';
import { SYSTEM, audit } from './audit.js';
import { bustMenuCache } from './menu.js';

export async function insertRefund(
  conn: PoolConnection,
  r: { orderId: number; billId?: number | null; paymentId?: number | null; amount: number; reason: string; requestedBy?: number | null },
) {
  await exec(conn, 'INSERT INTO refunds (order_id, stall_order_id, payment_id, amount, reason_code, requested_by) VALUES (?, ?, ?, ?, ?, ?)', [
    r.orderId,
    r.billId ?? null,
    r.paymentId ?? null,
    r.amount,
    r.reason,
    r.requestedBy ?? null,
  ]);
}

/** Next running bill number for the stall today: BH-0001, BH-0002 … (atomic, restarts each IST day). */
async function nextBillNo(conn: PoolConnection, stallId: number, prefix: string) {
  await exec(
    conn,
    `INSERT INTO stall_bill_counters (stall_id, bill_date, last_no) VALUES (?, ${IST_TODAY}, LAST_INSERT_ID(1))
     ON DUPLICATE KEY UPDATE last_no = LAST_INSERT_ID(last_no + 1)`,
    [stallId],
  );
  const row = await one<{ n: number }>(conn, 'SELECT LAST_INSERT_ID() AS n');
  return `${prefix}-${String(row!.n).padStart(4, '0')}`;
}

/**
 * Payment confirmed: give every bill of the order its bill number and a 3-digit pickup code, and send it to the kitchen.
 * The database guarantees the code is unique among the stall's open bills of the day; on a clash we pick another.
 */
async function issueBills(conn: PoolConnection, orderId: number) {
  const bills = await rows<{ stall_order_id: number; stall_id: number; bill_prefix: string }>(
    conn,
    `SELECT so.stall_order_id, so.stall_id, s.bill_prefix FROM stall_orders so JOIN stalls s ON s.stall_id = so.stall_id
      WHERE so.order_id = ? AND so.status IN ('awaiting_payment','expired') FOR UPDATE`,
    [orderId],
  );
  for (const bill of bills) {
    const billNo = await nextBillNo(conn, bill.stall_id, bill.bill_prefix);
    let issued = false;
    for (let attempt = 0; attempt < 50 && !issued; attempt++) {
      try {
        await exec(
          conn,
          `UPDATE stall_orders SET status = 'new', bill_date = ${IST_TODAY}, bill_no = ?, pickup_code = ?, code_attempts = 0,
                  code_locked_until = NULL, expired_at = NULL
            WHERE stall_order_id = ?`,
          [billNo, String(randomInt(100, 1000)), bill.stall_order_id],
        );
        issued = true;
      } catch (err) {
        if (!isDuplicateKey(err)) throw err;
      }
    }
    if (!issued) throw new Error(`could not find a free pickup code for stall ${bill.stall_id}`);
  }
  return bills.map((b) => b.stall_order_id);
}

/** Late payment for an expired order: take the stock again if it is still there. */
async function reReserve(conn: PoolConnection, orderId: number) {
  const items = await rows<{ item_id: number; product_id: number; quantity: number }>(
    conn,
    `SELECT oi.item_id, oi.product_id, oi.quantity FROM order_items oi JOIN stall_orders so ON so.stall_order_id = oi.stall_order_id
      WHERE so.order_id = ? AND oi.item_status = 'active' AND oi.quantity > 0 ORDER BY oi.product_id`,
    [orderId],
  );
  const stock = await rows<{ product_id: number; stock_quantity: number }>(
    conn,
    'SELECT product_id, stock_quantity FROM products WHERE product_id IN (?) ORDER BY product_id FOR UPDATE',
    [items.map((i) => i.product_id)],
  );
  const need = new Map<number, number>();
  for (const i of items) need.set(i.product_id, (need.get(i.product_id) ?? 0) + i.quantity);
  if (stock.some((p) => p.stock_quantity < (need.get(p.product_id) ?? 0))) return false;
  for (const [productId, qty] of need) {
    await exec(conn, 'UPDATE products SET stock_quantity = stock_quantity - ? WHERE product_id = ? AND stock_quantity >= ?', [qty, productId, qty]);
  }
  await exec(conn, "UPDATE stock_holds SET status = 'confirmed' WHERE order_id = ? AND status = 'released'", [orderId]);
  return true;
}

type Outcome =
  | { kind: 'ignored'; reason: string }
  | { kind: 'replay' }
  | { kind: 'failed' }
  | { kind: 'paid'; orderId: number; canteenId: number; billIds: number[] }
  | { kind: 'refund'; orderId: number; reason: string };

async function applyEvent(ev: PaymentEvent): Promise<Outcome> {
  return withTx(async (conn) => {
    const order = await one(conn, 'SELECT * FROM orders WHERE gateway_order_ref = ? FOR UPDATE', [ev.gatewayOrderRef]);
    if (!order) return { kind: 'ignored', reason: 'unknown gateway order' };
    const orderId = order.order_id as number;
    const success = ev.type === 'payment.captured';

    let paymentId: number;
    try {
      const p = await exec(
        conn,
        'INSERT INTO payments (order_id, gateway_payment_ref, upi_app, amount, payment_status, failure_reason) VALUES (?, ?, ?, ?, ?, ?)',
        [orderId, ev.gatewayPaymentRef, ev.upiApp ?? null, toRupees(ev.amountPaise), success ? 'success' : 'failed', ev.failureReason ?? null],
      );
      paymentId = p.insertId;
    } catch (err) {
      if (isDuplicateKey(err)) return { kind: 'replay' }; // same notification again: change nothing
      throw err;
    }

    if (!success) {
      await audit(conn, SYSTEM, 'payment_failed', 'orders', orderId, undefined, { gatewayPaymentRef: ev.gatewayPaymentRef });
      return { kind: 'failed' };
    }

    // The amount is always the server's own total; a different amount is never accepted as payment.
    if (ev.amountPaise !== toPaise(order.total)) {
      await exec(conn, "UPDATE payments SET payment_status = 'failed', failure_reason = 'AMOUNT_MISMATCH' WHERE payment_id = ?", [paymentId]);
      await insertRefund(conn, { orderId, paymentId, amount: toRupees(ev.amountPaise), reason: 'AMOUNT_MISMATCH' });
      await audit(conn, SYSTEM, 'payment_amount_mismatch', 'orders', orderId, { total: order.total }, { paid: toRupees(ev.amountPaise) });
      return { kind: 'refund', orderId, reason: 'AMOUNT_MISMATCH' };
    }

    if (order.status === 'paid') {
      await insertRefund(conn, { orderId, paymentId, amount: order.total, reason: 'DUPLICATE_PAYMENT' });
      await audit(conn, SYSTEM, 'duplicate_payment', 'orders', orderId);
      return { kind: 'refund', orderId, reason: 'DUPLICATE_PAYMENT' };
    }

    if (order.status === 'expired' && !(await reReserve(conn, orderId))) {
      await insertRefund(conn, { orderId, paymentId, amount: order.total, reason: 'LATE_PAYMENT' });
      await audit(conn, SYSTEM, 'late_payment_refund', 'orders', orderId);
      return { kind: 'refund', orderId, reason: 'LATE_PAYMENT' };
    }

    if (order.status === 'cancelled') {
      await insertRefund(conn, { orderId, paymentId, amount: order.total, reason: 'LATE_PAYMENT' });
      return { kind: 'refund', orderId, reason: 'LATE_PAYMENT' };
    }

    const marked = await exec(conn, "UPDATE orders SET status = 'paid', paid_at = UTC_TIMESTAMP() WHERE order_id = ? AND status IN ('pending','expired')", [
      orderId,
    ]);
    if (marked.affectedRows !== 1) throw new Error(`order ${orderId} could not be marked paid`);
    await exec(conn, "UPDATE stock_holds SET status = 'confirmed' WHERE order_id = ? AND status = 'held'", [orderId]);
    const billIds = await issueBills(conn, orderId);
    await audit(conn, SYSTEM, 'payment_success', 'orders', orderId, { status: order.status }, { status: 'paid', paymentId, billIds });
    return { kind: 'paid', orderId, canteenId: order.canteen_id as number, billIds };
  });
}

/**
 * Handles a payment gateway webhook. This is the ONLY place an order becomes paid (build guide part 5).
 * Signature checked first; replays of the same notification are harmless.
 */
export async function handleWebhook(rawBody: Buffer, headers: Record<string, string | string[] | undefined>) {
  if (!gateway.verifyWebhook(rawBody, headers)) throw new AppError(401, 'INVALID_SIGNATURE', 'Webhook signature is not valid');
  const ev = gateway.parseWebhook(rawBody);
  if (!ev) return { received: true, result: 'ignored' };
  const outcome = await applyEvent(ev);
  logger.info({ outcome, gatewayOrderRef: ev.gatewayOrderRef }, 'payment webhook');
  if (outcome.kind === 'paid') {
    await bustMenuCache([outcome.canteenId]);
    await publishBills(outcome.billIds, 'bill.new');
    await publishOrder(outcome.orderId);
  } else if (outcome.kind === 'refund') {
    await publishOrder(outcome.orderId);
  }
  return { received: true, result: outcome.kind };
}
