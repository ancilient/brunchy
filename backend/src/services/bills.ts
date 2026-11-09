import type { PoolConnection } from 'mysql2/promise';
import { IST_TODAY, exec, one, pool, rows, withTx } from '../db/pool.js';
import { AppError, badRequest, conflict, forbidden, notFound } from '../errors.js';
import type { AuthUser } from '../middleware/auth.js';
import { publishBills } from '../realtime.js';
import { effectiveStallStatus, iso } from '../util.js';
import { audit } from './audit.js';
import { bustMenuCache } from './menu.js';
import { OPEN_BILL_STATUSES, loadBills } from './orders.js';
import { insertRefund } from './payments.js';

const MAX_CODE_ATTEMPTS = 4; // same as the vendor app
const CODE_LOCK_MINUTES = 5;

export const REJECT_REASONS = ['OUT_OF_STOCK', 'ITEM_UNAVAILABLE', 'KITCHEN_ISSUE', 'STALL_EMERGENCY', 'STALL_REJECTED'] as const;

const actorOf = (u: AuthUser) => ({ id: u.id, role: u.role });

function vendorStall(user: AuthUser) {
  if (user.role !== 'vendor' || !user.stallId) throw forbidden('NOT_A_VENDOR', 'This account is not linked to a stall');
  return user.stallId;
}

async function successfulPaymentId(conn: PoolConnection, orderId: number) {
  const p = await one<{ payment_id: number }>(conn, "SELECT payment_id FROM payments WHERE order_id = ? AND payment_status = 'success' ORDER BY payment_id LIMIT 1", [orderId]);
  return p?.payment_id ?? null;
}

/** Food that will not be made goes back on sale. */
async function returnStock(conn: PoolConnection, billId: number) {
  const items = await rows<{ product_id: number; quantity: number }>(
    conn,
    "SELECT product_id, quantity FROM order_items WHERE stall_order_id = ? AND item_status = 'active' AND quantity > 0 ORDER BY product_id",
    [billId],
  );
  for (const i of items) await exec(conn, 'UPDATE products SET stock_quantity = stock_quantity + ? WHERE product_id = ?', [i.quantity, i.product_id]);
}

async function lockBill(conn: PoolConnection, billId: number) {
  const bill = await one(
    conn,
    `SELECT so.*, o.user_id FROM stall_orders so JOIN orders o ON o.order_id = so.order_id WHERE so.stall_order_id = ? FOR UPDATE`,
    [billId],
  );
  if (!bill) throw notFound('BILL_NOT_FOUND', 'Bill not found');
  return bill;
}

// ---------------------------------------------------------------- vendor

const LIST_FILTERS: Record<string, readonly string[]> = {
  active: OPEN_BILL_STATUSES,
  new: ['new'],
  accepted: ['accepted'],
  preparing: ['preparing'],
  ready: ['ready'],
  collected: ['collected'],
  closed: ['collected', 'rejected', 'cancelled', 'refunded'],
  all: ['new', 'accepted', 'preparing', 'ready', 'collected', 'rejected', 'cancelled', 'refunded'],
};

/** The live board: this stall's paid bills for today (a vendor never sees another stall's bills). */
export async function listVendorBills(user: AuthUser, filter = 'active') {
  const stallId = vendorStall(user);
  const statuses = LIST_FILTERS[filter];
  if (!statuses) throw badRequest('INVALID_FILTER', `status must be one of: ${Object.keys(LIST_FILTERS).join(', ')}`);
  const bills = await loadBills(pool, `so.stall_id = ? AND so.bill_date = ${IST_TODAY} AND so.status IN (?)`, [stallId, statuses], 'so.stall_order_id ASC');
  return { bills: bills.map(({ userId: _u, ...b }) => b) };
}

/** Finds today's open bill with this pickup code at the vendor's stall. */
export async function findBillByCode(user: AuthUser, code: string) {
  const stallId = vendorStall(user);
  const [bill] = await loadBills(pool, `so.stall_id = ? AND so.bill_date = ${IST_TODAY} AND so.active_code = ?`, [stallId, code]);
  if (!bill) throw notFound('CODE_NOT_FOUND', 'No open bill with this code at your stall today');
  const { userId: _u, ...rest } = bill;
  return { bill: rest };
}

const TRANSITIONS = {
  accepted: { from: ['new'], set: 'accepted_at = UTC_TIMESTAMP(), estimated_ready_at = UTC_TIMESTAMP() + INTERVAL ? MINUTE' },
  preparing: { from: ['new', 'accepted'], set: 'preparing_at = UTC_TIMESTAMP(), accepted_at = COALESCE(accepted_at, UTC_TIMESTAMP())' },
  ready: { from: ['new', 'accepted', 'preparing'], set: 'ready_at = UTC_TIMESTAMP()' },
  rejected: { from: ['new', 'accepted', 'preparing'], set: 'cancelled_at = UTC_TIMESTAMP(), cancel_reason = ?' },
} as const;

export type VendorStatus = keyof typeof TRANSITIONS;

/** Accept → Preparing → Ready, or Reject (with a reason; the student is refunded for that bill). */
export async function setBillStatus(user: AuthUser, billId: number, input: { status: VendorStatus; reason?: string; prepMinutes?: number }) {
  const stallId = vendorStall(user);
  const rule = TRANSITIONS[input.status];
  await withTx(async (conn) => {
    const bill = await lockBill(conn, billId);
    if (bill.stall_id !== stallId) throw forbidden('WRONG_STALL', 'This bill belongs to another stall');
    if (!(rule.from as readonly string[]).includes(bill.status)) {
      throw conflict('INVALID_TRANSITION', `A ${bill.status} bill cannot be marked ${input.status}`, { status: bill.status });
    }
    const params: unknown[] = [];
    if (input.status === 'accepted') {
      const stall = await one<{ avg_prep_minutes: number }>(conn, 'SELECT avg_prep_minutes FROM stalls WHERE stall_id = ?', [stallId]);
      params.push(input.prepMinutes ?? stall?.avg_prep_minutes ?? 5);
    }
    if (input.status === 'rejected') {
      if (!input.reason || !(REJECT_REASONS as readonly string[]).includes(input.reason)) {
        throw badRequest('REASON_REQUIRED', `Give a reason: ${REJECT_REASONS.join(', ')}`);
      }
      params.push(input.reason);
    }
    await exec(conn, `UPDATE stall_orders SET status = ?, ${rule.set} WHERE stall_order_id = ?`, [input.status, ...params, billId]);
    if (input.status === 'rejected') {
      if (input.reason !== 'OUT_OF_STOCK') await returnStock(conn, billId);
      await insertRefund(conn, {
        orderId: bill.order_id,
        billId,
        paymentId: await successfulPaymentId(conn, bill.order_id),
        amount: bill.total,
        reason: input.reason!,
        requestedBy: user.id,
      });
    }
    await audit(conn, actorOf(user), `bill_${input.status}`, 'stall_orders', billId, { status: bill.status }, { status: input.status, reason: input.reason });
  });
  await publishBills([billId], 'bill.updated');
  const [bill] = await loadBills(pool, 'so.stall_order_id = ?', [billId]);
  const { userId: _u, ...rest } = bill;
  return { bill: rest };
}

/**
 * Counter handover with the student's 3-digit code (OTP workflow guide).
 * The bill row is locked, so two simultaneous handovers cannot both succeed; the code works once.
 */
export async function handover(user: AuthUser, billId: number, code: string) {
  const stallId = vendorStall(user);
  const result = await withTx(async (conn) => {
    const bill = await lockBill(conn, billId);
    if (bill.stall_id !== stallId) return { error: forbidden('WRONG_STALL', 'This bill belongs to another stall') };
    if (bill.status === 'collected') {
      return { error: conflict('ALREADY_COLLECTED', 'This bill was already collected', { collectedAt: iso(bill.collected_at), collectedBy: String(bill.collected_by) }) };
    }
    if (bill.status !== 'ready') {
      const notReady = ['new', 'accepted', 'preparing'].includes(bill.status);
      return {
        error: conflict(notReady ? 'ORDER_NOT_READY' : 'BILL_NOT_ACTIVE', notReady ? 'Mark the order Ready before handing it over' : `This bill is ${bill.status}`, {
          status: bill.status,
        }),
      };
    }
    if (bill.code_locked_until && (bill.code_locked_until as Date).getTime() > Date.now()) {
      return { error: new AppError(423, 'CODE_LOCKED', 'Too many wrong codes. Try again in a few minutes.', { lockedUntil: iso(bill.code_locked_until) }) };
    }
    if (bill.pickup_code !== code) {
      const attempts = Number(bill.code_attempts) + 1;
      const locked = attempts >= MAX_CODE_ATTEMPTS;
      await exec(
        conn,
        `UPDATE stall_orders SET code_attempts = ?, code_locked_until = ${locked ? `UTC_TIMESTAMP() + INTERVAL ${CODE_LOCK_MINUTES} MINUTE` : 'NULL'}
          WHERE stall_order_id = ?`,
        [locked ? 0 : attempts, billId],
      );
      await audit(conn, actorOf(user), 'handover_wrong_code', 'stall_orders', billId, undefined, { attempts });
      // Committed first, then reported, so the attempt counts even though the request "fails".
      return {
        error: locked
          ? new AppError(423, 'CODE_LOCKED', 'Too many wrong codes. Try again in a few minutes.')
          : badRequest('CODE_WRONG', 'That code does not match this bill', { attemptsLeft: MAX_CODE_ATTEMPTS - attempts }),
      };
    }
    await exec(
      conn,
      "UPDATE stall_orders SET status = 'collected', collected_at = UTC_TIMESTAMP(), collected_by = ?, code_attempts = 0 WHERE stall_order_id = ? AND status = 'ready'",
      [user.id, billId],
    );
    await audit(conn, actorOf(user), 'handover', 'stall_orders', billId, { status: 'ready' }, { status: 'collected' });
    return { error: null };
  });
  if (result.error) throw result.error;
  await publishBills([billId], 'bill.updated');
  const [bill] = await loadBills(pool, 'so.stall_order_id = ?', [billId]);
  const { userId: _u, ...rest } = bill;
  return { bill: rest };
}

/** Two-tap stock changes: set today's quantity, or switch the item on/off. */
export async function updateProduct(user: AuthUser, productId: number, input: { stockQuantity?: number; isActive?: boolean }) {
  const stallId = vendorStall(user);
  const canteenId = await withTx(async (conn) => {
    const p = await one(conn, 'SELECT p.*, s.canteen_id FROM products p JOIN stalls s ON s.stall_id = p.stall_id WHERE p.product_id = ? FOR UPDATE', [productId]);
    if (!p) throw notFound('PRODUCT_NOT_FOUND', 'Item not found');
    if (p.stall_id !== stallId) throw forbidden('WRONG_STALL', 'This item belongs to another stall');
    await exec(conn, 'UPDATE products SET stock_quantity = COALESCE(?, stock_quantity), is_active = COALESCE(?, is_active) WHERE product_id = ?', [
      input.stockQuantity ?? null,
      input.isActive ?? null,
      productId,
    ]);
    await audit(conn, actorOf(user), 'product_update', 'products', productId, { stockQuantity: p.stock_quantity, isActive: Boolean(p.is_active) }, input);
    return p.canteen_id as number;
  });
  await bustMenuCache([canteenId]);
  const p = await one(pool, 'SELECT * FROM products WHERE product_id = ?', [productId]);
  return { product: { id: String(p!.product_id), name: p!.product_name, stockQuantity: p!.stock_quantity, isActive: Boolean(p!.is_active), price: p!.price } };
}

/** Pause (auto-resumes), Close for today, or Resume. Paid orders already on the board continue normally. */
export async function setStallStatus(user: AuthUser, input: { action: 'pause' | 'close' | 'resume'; minutes?: number }) {
  const stallId = vendorStall(user);
  const canteenId = await withTx(async (conn) => {
    const s = await one(conn, 'SELECT * FROM stalls WHERE stall_id = ? FOR UPDATE', [stallId]);
    if (input.action === 'pause') {
      if (!input.minutes) throw badRequest('MINUTES_REQUIRED', 'Pause needs minutes (10, 15 or 30)');
      await exec(conn, "UPDATE stalls SET status = 'paused', paused_until = UTC_TIMESTAMP() + INTERVAL ? MINUTE WHERE stall_id = ?", [input.minutes, stallId]);
    } else if (input.action === 'close') {
      await exec(conn, "UPDATE stalls SET status = 'closed', paused_until = NULL WHERE stall_id = ?", [stallId]);
    } else {
      await exec(conn, "UPDATE stalls SET status = 'open', paused_until = NULL WHERE stall_id = ?", [stallId]);
    }
    await audit(conn, actorOf(user), `stall_${input.action}`, 'stalls', stallId, { status: s!.status }, input);
    return s!.canteen_id as number;
  });
  await bustMenuCache([canteenId]);
  const s = await one(pool, 'SELECT * FROM stalls WHERE stall_id = ?', [stallId]);
  return { stall: { id: String(stallId), name: s!.stall_name, status: effectiveStallStatus(s as never), pausedUntil: iso(s!.paused_until) } };
}

// ---------------------------------------------------------------- student

/** The student cancels one bill before the kitchen starts it. That bill is refunded; its food goes back on sale. */
export async function cancelBillByStudent(user: AuthUser, billId: number) {
  const canteenId = await withTx(async (conn) => {
    const bill = await lockBill(conn, billId);
    if (bill.user_id !== user.id) throw notFound('BILL_NOT_FOUND', 'Bill not found');
    if (!['new', 'accepted'].includes(bill.status)) {
      throw conflict('CANNOT_CANCEL', 'This bill can only be cancelled before the kitchen starts preparing it', { status: bill.status });
    }
    await exec(conn, "UPDATE stall_orders SET status = 'cancelled', cancelled_at = UTC_TIMESTAMP(), cancel_reason = 'CANCELLED_BY_USER' WHERE stall_order_id = ?", [
      billId,
    ]);
    await returnStock(conn, billId);
    await insertRefund(conn, {
      orderId: bill.order_id,
      billId,
      paymentId: await successfulPaymentId(conn, bill.order_id),
      amount: bill.total,
      reason: 'CANCELLED_BY_USER',
      requestedBy: user.id,
    });
    await audit(conn, actorOf(user), 'bill_cancelled', 'stall_orders', billId, { status: bill.status }, { status: 'cancelled' });
    return bill.canteen_id as number;
  });
  await bustMenuCache([canteenId]);
  await publishBills([billId], 'bill.updated');
  const [bill] = await loadBills(pool, 'so.stall_order_id = ?', [billId]);
  const { userId: _u, ...rest } = bill;
  return { bill: rest };
}
