import type { PoolConnection } from 'mysql2/promise';
import { exec, one, pool, rows, withTx } from '../db/pool.js';
import { publishOrder } from '../realtime.js';
import { SYSTEM, audit } from './audit.js';
import { bustMenuCache } from './menu.js';

/** Puts held stock back on sale. Products are updated in product_id order, like checkout, so no deadlocks. */
export async function releaseHolds(conn: PoolConnection, orderId: number) {
  const holds = await rows<{ hold_id: number; product_id: number; qty: number }>(
    conn,
    "SELECT hold_id, product_id, qty FROM stock_holds WHERE order_id = ? AND status = 'held' ORDER BY product_id FOR UPDATE",
    [orderId],
  );
  for (const h of holds) {
    await exec(conn, 'UPDATE products SET stock_quantity = stock_quantity + ? WHERE product_id = ?', [h.qty, h.product_id]);
    await exec(conn, "UPDATE stock_holds SET status = 'released' WHERE hold_id = ? AND status = 'held'", [h.hold_id]);
  }
  return holds.length;
}

/**
 * The 5-minute hold ran out without a payment: release the stock and expire the order.
 * Safe to call many times and from several workers: only the first call for a pending, overdue order does anything.
 */
export async function expireOrder(orderId: number) {
  const canteenId = await withTx(async (conn) => {
    const order = await one(
      conn,
      "SELECT order_id, canteen_id FROM orders WHERE order_id = ? AND status = 'pending' AND payment_expires_at <= UTC_TIMESTAMP() FOR UPDATE",
      [orderId],
    );
    if (!order) return null;
    const released = await releaseHolds(conn, orderId);
    await exec(conn, "UPDATE orders SET status = 'expired' WHERE order_id = ? AND status = 'pending'", [orderId]);
    await exec(
      conn,
      "UPDATE stall_orders SET status = 'expired', expired_at = UTC_TIMESTAMP() WHERE order_id = ? AND status = 'awaiting_payment'",
      [orderId],
    );
    await audit(conn, SYSTEM, 'hold_expired', 'orders', orderId, { status: 'pending' }, { status: 'expired', holdsReleased: released });
    return order.canteen_id as number;
  });
  if (canteenId === null) return false;
  await bustMenuCache([canteenId]);
  await publishOrder(orderId);
  return true;
}

/** Safety net behind the per-order jobs: expires anything overdue. Runs every minute. */
export async function expireOverdueOrders(limit = 200) {
  const overdue = await rows<{ order_id: number }>(
    pool,
    "SELECT order_id FROM orders WHERE status = 'pending' AND payment_expires_at <= UTC_TIMESTAMP() ORDER BY payment_expires_at LIMIT ?",
    [limit],
  );
  let expired = 0;
  for (const o of overdue) if (await expireOrder(o.order_id)) expired += 1;
  return expired;
}
