import type { Request, Response } from 'express';
import { Router } from 'express';
import { z } from 'zod';
import { exec, one, pool, rows, withTx } from '../../db/pool.js';
import { AppError, conflict, notFound } from '../../errors.js';
import { type Panel, assertCanteen, invalid, need, panelOf, panelPermissions, scopeCanteen } from '../../services/access.js';
import { audit } from '../../services/audit.js';
import { getSettings } from '../../services/settings.js';
import { iso, toPaise, toRupees } from '../../util.js';
import { addDays, idOf, istDay, paging, q, sortSql, zDate, zId } from './util.js';

/**
 * Money screens of the admin panel: Payments & refunds (payments, refunds, reconciliation) and Vendor settlements.
 * All need the payments section (view to read, edit to change). Managers given payments access see their canteen.
 */
export const moneyRouter = Router();

const actor = (p: Panel) => ({ id: p.id, role: p.role });
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;
const istDate = (col: string) => `DATE(CONVERT_TZ(${col}, '+00:00', '+05:30'))`;
const r2 = (paise: number) => toRupees(Math.round(paise));
const money = (n: unknown) => Number(n ?? 0);

function dateRange(req: Request, col: string, where: string[], params: unknown[]) {
  const from = q(req, 'from') ? zDate.parse(q(req, 'from')) : undefined;
  const to = q(req, 'to') ? zDate.parse(q(req, 'to')) : undefined;
  if (from) (where.push(`${istDate(col)} >= ?`), params.push(from));
  if (to) (where.push(`${istDate(col)} <= ?`), params.push(to));
}

// ---------------------------------------------------------------- payments

const PAYMENT_SORT: Record<string, string> = { createdAt: 'pm.created_at', orderId: 'pm.order_id', studentName: 'u.name', amount: 'pm.amount', status: 'pm.payment_status' };

const PAYMENT_SELECT = `
  SELECT pm.*, o.canteen_id, o.total AS order_total, u.name AS student_name,
         (SELECT MIN(so.stall_order_id) FROM stall_orders so WHERE so.order_id = pm.order_id) AS bill_id,
         (SELECT COALESCE(SUM(r.amount), 0) FROM refunds r WHERE r.order_id = pm.order_id AND r.status = 'completed') AS refunded
    FROM payments pm JOIN orders o ON o.order_id = pm.order_id JOIN users u ON u.user_id = o.user_id`;

const paymentStatus = (pm: Row) =>
  pm.payment_status === 'created' ? 'pending' : pm.payment_status === 'success' && money(pm.refunded) > 0 && money(pm.refunded) >= money(pm.amount) - 0.005 ? 'refunded' : pm.payment_status;

const toPaymentRow = (pm: Row) => ({
  id: pm.payment_id,
  orderId: pm.order_id,
  gatewayRef: pm.gateway_payment_ref,
  upiApp: pm.upi_app ?? '',
  amount: money(pm.amount),
  method: 'upi', // Brunchy takes UPI only
  status: paymentStatus(pm),
  failureReason: pm.failure_reason,
  createdAt: iso(pm.created_at),
  canteenId: pm.canteen_id,
  studentName: pm.student_name,
  billId: pm.bill_id,
  razorpayFee: 0, // comes with the Razorpay settlement import (not built yet)
});

export async function listPayments(req: Request, res: Response) {
  const p = panelOf(req);
  const { page, pageSize, limit, offset } = paging(req);
  const where: string[] = ['1 = 1'];
  const params: unknown[] = [];
  dateRange(req, 'pm.created_at', where, params);
  const canteenId = scopeCanteen(p, req.query.canteenId);
  if (canteenId) (where.push('o.canteen_id = ?'), params.push(canteenId));
  const method = q(req, 'method');
  if (method && method !== 'upi') where.push('1 = 0');
  const text = q(req, 'q');
  if (text) {
    const id = Number(text.replace(/^ORD-0*/i, ''));
    where.push('(pm.gateway_payment_ref = ? OR pm.order_id = ?)');
    params.push(text, Number.isInteger(id) ? id : 0);
  }
  const base = `${PAYMENT_SELECT} WHERE ${where.join(' AND ')}`;
  // The displayed status (pending / success / failed / refunded) is computed, so it is filtered one level up.
  const status = q(req, 'status');
  const statusSql = `CASE WHEN x.payment_status = 'created' THEN 'pending'
                          WHEN x.payment_status = 'success' AND x.refunded > 0 AND x.refunded >= x.amount - 0.005 THEN 'refunded'
                          ELSE x.payment_status END`;
  const filtered = `SELECT y.* FROM (SELECT x.*, ${statusSql} AS st FROM (${base}) x) y ${status ? 'WHERE y.st = ?' : ''}`;
  const all = [...params, ...(status ? [status] : [])];
  const counts = (await one(pool, `SELECT COUNT(*) AS n, SUM(z.st = 'success' OR z.st = 'refunded') AS ok FROM (${filtered}) z`, all))!;
  const order = sortSql(req, Object.fromEntries(Object.entries(PAYMENT_SORT).map(([k, v]) => [k, v.replace(/^pm\.|^u\./, 'f.').replace('f.name', 'f.student_name')])), 'f.created_at DESC');
  const list = await rows(pool, `SELECT f.* FROM (${filtered}) f ORDER BY ${order}, f.payment_id DESC LIMIT ? OFFSET ?`, [...all, limit, offset]);
  const total = Number(counts.n);
  res.json({ items: list.map(toPaymentRow), page, pageSize, total, successRate: total ? Number(counts.ok) / total : null });
}
moneyRouter.get('/admin/payments', need('payments'), listPayments);

// ---------------------------------------------------------------- refunds

const REFUND_SELECT = `
  SELECT r.*, o.canteen_id, so.bill_no, s.stall_name, rq.name AS requested_by_name, ap.name AS approved_by_name
    FROM refunds r
    JOIN orders o ON o.order_id = r.order_id
    LEFT JOIN stall_orders so ON so.stall_order_id = r.stall_order_id
    LEFT JOIN stalls s ON s.stall_id = so.stall_id
    LEFT JOIN users rq ON rq.user_id = r.requested_by
    LEFT JOIN users ap ON ap.user_id = r.approved_by`;

const refundStatus = (s: string) => (s === 'processing' ? 'approved' : s);

const toRefundRow = (r: Row) => ({
  id: r.refund_id,
  orderId: r.order_id,
  billId: r.stall_order_id,
  amount: money(r.amount),
  reasonCode: r.reason_code,
  requestedBy: r.requested_by,
  approvedBy: r.approved_by,
  status: refundStatus(r.status),
  gatewayRefundRef: r.gateway_refund_ref,
  note: r.note,
  createdAt: iso(r.created_at),
  completedAt: iso(r.completed_at),
  billNo: r.bill_no,
  stallName: r.stall_name,
  requestedByName: r.requested_by_name ?? 'System',
  approvedByName: r.approved_by_name,
  canteenId: r.canteen_id,
});

const REFUND_SORT: Record<string, string> = { createdAt: 'r.created_at', amount: 'r.amount', reasonCode: 'r.reason_code', status: 'r.status', completedAt: 'r.completed_at', billNo: 'so.bill_no', stallName: 's.stall_name' };

export async function listRefunds(req: Request, res: Response) {
  const p = panelOf(req);
  const { page, pageSize, limit, offset } = paging(req);
  const where: string[] = ['1 = 1'];
  const params: unknown[] = [];
  dateRange(req, 'r.created_at', where, params);
  const canteenId = scopeCanteen(p, req.query.canteenId);
  if (canteenId) (where.push('o.canteen_id = ?'), params.push(canteenId));
  const status = q(req, 'status');
  if (status === 'approved') where.push("r.status IN ('approved','processing')");
  else if (status) (where.push('r.status = ?'), params.push(status));
  const w = where.join(' AND ');
  const total = (await one<{ n: number }>(pool, `SELECT COUNT(*) AS n FROM (${REFUND_SELECT} WHERE ${w}) x`, params))!.n;
  const list = await rows(pool, `${REFUND_SELECT} WHERE ${w} ORDER BY ${sortSql(req, REFUND_SORT, 'r.created_at DESC')}, r.refund_id DESC LIMIT ? OFFSET ?`, [...params, limit, offset]);
  res.json({ items: list.map(toRefundRow), page, pageSize, total: Number(total) });
}
moneyRouter.get('/admin/refunds', need('payments'), listRefunds);

async function loadRefund(id: number) {
  const r = await one(pool, `${REFUND_SELECT} WHERE r.refund_id = ?`, [id]);
  if (!r) throw notFound('not_found', 'Refund not found');
  return r;
}

const REASONS = ['OUT_OF_STOCK', 'ITEM_UNAVAILABLE', 'KITCHEN_ISSUE', 'STALL_EMERGENCY', 'STALL_REJECTED', 'CANCELLED_BY_USER', 'PAYMENT_TIMEOUT', 'LATE_PAYMENT', 'DUPLICATE_PAYMENT', 'AMOUNT_MISMATCH'] as const;

/** Initiate a refund for a paid order (bill no or order id). Total refunds of an order never exceed what was paid. */
moneyRouter.post('/admin/refunds', need('payments', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const b = z
    .object({ bill: z.string().trim().min(1), amount: z.number().positive().max(100000), reasonCode: z.enum(REASONS), note: z.string().trim().max(255).optional() })
    .parse(req.body);
  const text = b.bill.toUpperCase();
  // A bill number restarts every day, so the most recent bill with that number is meant.
  const bill = /^[A-Z0-9]{1,5}-\d+$/.test(text)
    ? await one(pool, 'SELECT stall_order_id, order_id FROM stall_orders WHERE bill_no = ? ORDER BY stall_order_id DESC LIMIT 1', [text])
    : null;
  const orderId = bill?.order_id ?? Number(text.replace(/^ORD-0*/, ''));
  const order = Number.isInteger(orderId) && orderId > 0 ? await one(pool, 'SELECT * FROM orders WHERE order_id = ?', [orderId]) : undefined;
  if (!order) throw invalid('No bill or order with that number.');
  assertCanteen(p, order.canteen_id);
  if (order.status !== 'paid') throw new AppError(422, 'invalid', 'Only paid orders can be refunded.');
  const id = await withTx(async (conn) => {
    await one(conn, 'SELECT order_id FROM orders WHERE order_id = ? FOR UPDATE', [orderId]);
    const done = await one<{ s: number }>(conn, "SELECT COALESCE(SUM(amount), 0) AS s FROM refunds WHERE order_id = ? AND status NOT IN ('rejected','failed')", [orderId]);
    const left = toPaise(order.total) - toPaise(money(done?.s));
    if (toPaise(b.amount) > left) throw new AppError(422, 'invalid', `At most ₹${r2(left)} of this order can still be refunded.`);
    const pay = await one<{ payment_id: number }>(conn, "SELECT payment_id FROM payments WHERE order_id = ? AND payment_status = 'success' ORDER BY payment_id LIMIT 1", [orderId]);
    const r = await exec(conn, 'INSERT INTO refunds (order_id, stall_order_id, payment_id, amount, reason_code, requested_by, note) VALUES (?, ?, ?, ?, ?, ?, ?)', [
      orderId,
      bill?.stall_order_id ?? null,
      pay?.payment_id ?? null,
      b.amount,
      b.reasonCode,
      p.id,
      b.note ?? null,
    ]);
    await audit(conn, actor(p), 'admin_refund_create', 'refunds', r.insertId, undefined, b);
    return r.insertId;
  });
  res.status(201).json(toRefundRow(await loadRefund(id)));
});

/** requested → approved → completed (with the reference), or requested → rejected. Final states never change. */
async function moveRefund(req: Request, from: string[], to: 'approved' | 'rejected' | 'completed', extra: { note?: string; reference?: string }) {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'refund');
  const r = await loadRefund(id);
  assertCanteen(p, r.canteen_id);
  await withTx(async (conn) => {
    const cur = await one(conn, 'SELECT status FROM refunds WHERE refund_id = ? FOR UPDATE', [id]);
    if (!from.includes(cur!.status)) {
      const need = from.includes('approved') ? 'approved' : 'requested';
      throw conflict('invalid_state', `Only ${need} refunds can be ${to}.`);
    }
    if (to === 'approved') await exec(conn, "UPDATE refunds SET status = 'approved', approved_by = ? WHERE refund_id = ?", [p.id, id]);
    if (to === 'rejected') await exec(conn, "UPDATE refunds SET status = 'rejected', note = ? WHERE refund_id = ?", [extra.note, id]);
    if (to === 'completed') {
      await exec(conn, "UPDATE refunds SET status = 'completed', gateway_refund_ref = ?, completed_at = UTC_TIMESTAMP() WHERE refund_id = ?", [extra.reference, id]);
    }
    const action = to === 'approved' ? 'admin_refund_approve' : to === 'rejected' ? 'admin_refund_reject' : 'admin_refund_complete';
    await audit(conn, actor(p), action, 'refunds', id, { status: cur!.status }, { status: to, ...extra });
  });
  return { ok: true };
}

moneyRouter.post('/admin/refunds/:id/approve', need('payments', 'edit'), async (req, res) => {
  res.json(await moveRefund(req, ['requested'], 'approved', {}));
});
moneyRouter.post('/admin/refunds/:id/reject', need('payments', 'edit'), async (req, res) => {
  const { note } = z.object({ note: z.string().trim().min(1, 'Add a note').max(255) }).parse(req.body ?? {});
  res.json(await moveRefund(req, ['requested'], 'rejected', { note }));
});
/** Refunds are paid manually until the Razorpay refund API is connected: the admin enters the transfer reference. */
moneyRouter.post('/admin/refunds/:id/complete', need('payments', 'edit'), async (req, res) => {
  const { reference } = z.object({ reference: z.string().trim().min(3).max(100) }).parse(req.body ?? {});
  res.json(await moveRefund(req, ['approved', 'processing', 'failed'], 'completed', { reference }));
});

// ---------------------------------------------------------------- reconciliation

/**
 * Compares what the gateway captured (successful payment rows from verified Razorpay webhooks) with Brunchy's orders.
 * Importing Razorpay's settlement report (gateway fee, settled amount) is not built yet.
 */
moneyRouter.get('/admin/reconciliation', need('payments'), async (req, res) => {
  const p = panelOf(req);
  const where: string[] = ["pm.payment_status = 'success'"];
  const params: unknown[] = [];
  dateRange(req, 'pm.created_at', where, params);
  const canteenId = scopeCanteen(p, req.query.canteenId);
  if (canteenId) (where.push('o.canteen_id = ?'), params.push(canteenId));
  const payments = await rows(
    pool,
    `SELECT pm.*, o.status AS order_status, o.total AS order_total,
            (SELECT COUNT(*) FROM refunds r WHERE r.order_id = o.order_id AND r.stall_order_id IS NULL AND r.status <> 'rejected') AS order_refunds
       FROM payments pm JOIN orders o ON o.order_id = pm.order_id WHERE ${where.join(' AND ')} ORDER BY pm.payment_id`,
    params,
  );
  const out: Row[] = [];
  let matched = 0;
  const seen = new Set<number>();
  for (const pm of payments) {
    const amount = money(pm.amount);
    const dup = seen.has(pm.order_id);
    seen.add(pm.order_id);
    // Money for an order that is not paid (late/duplicate payment) is fine once it has a refund request.
    if ((pm.order_status !== 'paid' || dup) && !Number(pm.order_refunds)) {
      out.push({ kind: 'no_order', gatewayRef: pm.gateway_payment_ref, orderId: pm.order_id, paymentAmount: money(pm.order_total), gatewayAmount: amount, at: iso(pm.created_at) });
    } else if (pm.order_status === 'paid' && !dup && toPaise(amount) !== toPaise(money(pm.order_total))) {
      out.push({ kind: 'amount_mismatch', gatewayRef: pm.gateway_payment_ref, orderId: pm.order_id, paymentAmount: money(pm.order_total), gatewayAmount: amount, at: iso(pm.created_at) });
    } else matched++;
  }
  const ow: string[] = ["o.status = 'paid'", "NOT EXISTS (SELECT 1 FROM payments pm WHERE pm.order_id = o.order_id AND pm.payment_status = 'success')"];
  const op: unknown[] = [];
  dateRange(req, 'o.paid_at', ow, op);
  if (canteenId) (ow.push('o.canteen_id = ?'), op.push(canteenId));
  for (const o of await rows(pool, `SELECT o.* FROM orders o WHERE ${ow.join(' AND ')}`, op)) {
    out.push({ kind: 'no_payment', gatewayRef: o.gateway_order_ref, orderId: o.order_id, paymentAmount: money(o.total), gatewayAmount: null, at: iso(o.paid_at) });
  }
  out.sort((a, b) => Date.parse(b.at) - Date.parse(a.at));
  res.json({ matched, rows: out });
});

// ---------------------------------------------------------------- vendor settlements

/** T+2 bank working days (Saturdays and Sundays skipped). */
function dueDate(day: string) {
  let d = day;
  let left = 2;
  while (left > 0) {
    d = addDays(d, 1);
    const wd = new Date(`${d}T00:00:00Z`).getUTCDay();
    if (wd !== 0 && wd !== 6) left--;
  }
  return d;
}

const SETTLEMENT_SELECT = `
  SELECT st.*, s.stall_name, s.canteen_id, c.canteen_name, pb.name AS prepared_by_name, ab.name AS approved_by_name,
         (SELECT u.name FROM users u WHERE u.role = 'vendor' AND u.stall_id = st.stall_id ORDER BY u.user_id LIMIT 1) AS vendor_name
    FROM settlements st
    JOIN stalls s ON s.stall_id = st.stall_id
    JOIN canteens c ON c.canteen_id = s.canteen_id
    LEFT JOIN users pb ON pb.user_id = st.prepared_by
    LEFT JOIN users ab ON ab.user_id = st.approved_by`;

const ymd = (d: Date | string) => (typeof d === 'string' ? d.slice(0, 10) : new Date(d).toISOString().slice(0, 10));

const toSettlement = (s: Row) => ({
  id: s.settlement_id,
  stallId: s.stall_id,
  stallName: s.stall_name,
  canteenName: s.canteen_name,
  vendorName: s.vendor_name ?? null,
  periodDate: ymd(s.period_date),
  dueDate: ymd(s.due_date),
  orders: s.orders,
  gross: money(s.gross),
  commission: money(s.commission),
  commissionGst: money(s.commission_gst),
  gst: money(s.gst),
  refunds: money(s.refunds),
  adjustments: money(s.adjustments),
  netPayout: money(s.net_payout),
  status: s.status,
  preparedByName: s.prepared_by_name,
  approvedByName: s.approved_by_name,
  preparedAt: iso(s.prepared_at),
  approvedAt: iso(s.approved_at),
  paidAt: iso(s.paid_at),
  bankRef: s.bank_ref,
});

const SETTLEMENT_SORT: Record<string, string> = {
  periodDate: 'st.period_date',
  dueDate: 'st.due_date',
  stallName: 's.stall_name',
  orders: 'st.orders',
  gross: 'st.gross',
  netPayout: 'st.net_payout',
  status: 'st.status',
};

export async function listSettlements(req: Request, res: Response) {
  const p = panelOf(req);
  const { page, pageSize, limit, offset } = paging(req);
  const where: string[] = ['1 = 1'];
  const params: unknown[] = [];
  if (q(req, 'from')) (where.push('st.period_date >= ?'), params.push(zDate.parse(q(req, 'from'))));
  if (q(req, 'to')) (where.push('st.period_date <= ?'), params.push(zDate.parse(q(req, 'to'))));
  const canteenId = scopeCanteen(p, req.query.canteenId);
  if (canteenId) (where.push('s.canteen_id = ?'), params.push(canteenId));
  if (q(req, 'stallId')) (where.push('st.stall_id = ?'), params.push(Number(q(req, 'stallId'))));
  // Totals cover the whole filter (every status), not just the page.
  const totalsWhere = where.join(' AND ');
  const totalsParams = [...params];
  if (q(req, 'status')) (where.push('st.status = ?'), params.push(q(req, 'status')));
  const w = where.join(' AND ');
  const total = (await one<{ n: number }>(pool, `SELECT COUNT(*) AS n FROM settlements st JOIN stalls s ON s.stall_id = st.stall_id WHERE ${w}`, params))!.n;
  const sums = await rows<{ status: string; net: number }>(
    pool,
    `SELECT st.status, SUM(st.net_payout) AS net FROM settlements st JOIN stalls s ON s.stall_id = st.stall_id WHERE ${totalsWhere} GROUP BY st.status`,
    totalsParams,
  );
  const list = await rows(pool, `${SETTLEMENT_SELECT} WHERE ${w} ORDER BY ${sortSql(req, SETTLEMENT_SORT, 'st.period_date DESC, s.stall_name')}, st.settlement_id DESC LIMIT ? OFFSET ?`, [
    ...params,
    limit,
    offset,
  ]);
  const totals = { pending: 0, approved: 0, paid: 0 } as Record<string, number>;
  for (const s of sums) totals[s.status] = money(s.net);
  res.json({ items: list.map(toSettlement), page, pageSize, total: Number(total), totals });
}
moneyRouter.get('/admin/settlements', need('payments'), listSettlements);

/** The amounts one stall is paid for one business day (also used by the settlement report). */
export async function settlementFigures(db: typeof pool | import('mysql2/promise').PoolConnection, stallId: number, day: string, commissionPct: number, commissionGstPct: number, opts: { lock?: boolean } = {}) {
  const lock = opts.lock ? 'FOR UPDATE' : '';
  const bills = await rows<Row>(
    db,
    `SELECT so.stall_order_id, so.order_id, so.bill_no, so.created_at, so.subtotal, so.tax FROM stall_orders so
      WHERE so.stall_id = ? AND so.bill_date = ? AND so.status = 'collected'
        AND NOT EXISTS (SELECT 1 FROM settlement_bills sb WHERE sb.stall_order_id = so.stall_order_id)
      ORDER BY so.stall_order_id ${lock}`,
    [stallId, day],
  );
  // Refunds on bills already paid out to the stall, not yet charged, created up to the end of this day.
  const refunds = await rows(
    db,
    `SELECT r.refund_id, LEAST(r.amount, so.subtotal + so.tax) AS charged FROM refunds r
       JOIN stall_orders so ON so.stall_order_id = r.stall_order_id
       JOIN settlement_bills sb ON sb.stall_order_id = so.stall_order_id
      WHERE so.stall_id = ? AND r.status IN ('approved','processing','completed') AND r.settlement_id IS NULL
        AND ${istDate('r.created_at')} <= ? ORDER BY r.refund_id ${lock}`,
    [stallId, day],
  );
  const adjustments = await rows(db, `SELECT * FROM settlement_adjustments WHERE stall_id = ? AND settlement_id IS NULL ORDER BY adjustment_id ${lock}`, [stallId]);
  let subtotal = 0;
  let gst = 0;
  let commission = 0;
  const lines: Row[] = bills.map((b) => {
    const c = Math.round((toPaise(b.subtotal) * commissionPct) / 100);
    subtotal += toPaise(b.subtotal);
    gst += toPaise(b.tax);
    commission += c;
    return { ...b, commissionPaise: c };
  });
  const commissionGst = Math.round((commission * commissionGstPct) / 100);
  const refundPaise = refunds.reduce((s, r) => s + toPaise(money(r.charged)), 0);
  const adjPaise = adjustments.reduce((s, a) => s + toPaise(money(a.amount)), 0);
  return {
    bills: lines,
    refunds,
    adjustments,
    orders: new Set(bills.map((b) => b.order_id)).size,
    subtotal: r2(subtotal),
    gross: r2(subtotal + gst),
    gst: r2(gst),
    commission: r2(commission),
    commissionGst: r2(commissionGst),
    refundTotal: r2(refundPaise),
    adjustmentTotal: r2(adjPaise),
    net: r2(subtotal + gst - commission - commissionGst - refundPaise + adjPaise),
  };
}

/** One pending payout per stall with picked-up bills on a finished business day. Open adjustments are attached. */
moneyRouter.post('/admin/settlements/prepare', need('payments', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const { date } = z.object({ date: zDate }).parse(req.body ?? {});
  if (date >= istDay()) throw invalid('Pick a finished business day (yesterday or earlier).');
  const s = await getSettings();
  const stalls = await rows<{ stall_id: number; canteen_id: number }>(
    pool,
    `SELECT DISTINCT so.stall_id, so.canteen_id FROM stall_orders so
      WHERE so.bill_date = ? AND so.status = 'collected' ${p.role === 'manager' ? 'AND so.canteen_id = ?' : ''}
        AND NOT EXISTS (SELECT 1 FROM settlements st WHERE st.stall_id = so.stall_id AND st.period_date = ?)`,
    p.role === 'manager' ? [date, p.canteenId, date] : [date, date],
  );
  let created = 0;
  for (const { stall_id: stallId } of stalls) {
    await withTx(async (conn) => {
      if (await one(conn, 'SELECT 1 FROM settlements WHERE stall_id = ? AND period_date = ? FOR UPDATE', [stallId, date])) return;
      const f = await settlementFigures(conn, stallId, date, s.vendorCommissionPct, s.commissionGstPct, { lock: true });
      if (!f.bills.length) return;
      const r = await exec(
        conn,
        `INSERT INTO settlements (stall_id, period_date, due_date, orders, gross, gst, commission, commission_gst, refunds, adjustments, net_payout,
                                  commission_pct, commission_gst_pct, prepared_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [stallId, date, dueDate(date), f.orders, f.gross, f.gst, f.commission, f.commissionGst, f.refundTotal, f.adjustmentTotal, f.net, s.vendorCommissionPct, s.commissionGstPct, p.id],
      );
      for (let i = 0; i < f.bills.length; i += 1000) {
        const chunk = f.bills.slice(i, i + 1000).map((b) => [b.stall_order_id, r.insertId, r2(b.commissionPaise)]);
        await exec(conn, 'INSERT INTO settlement_bills (stall_order_id, settlement_id, commission) VALUES ?', [chunk]);
      }
      if (f.refunds.length) await exec(conn, 'UPDATE refunds SET settlement_id = ? WHERE refund_id IN (?)', [r.insertId, f.refunds.map((x) => x.refund_id)]);
      if (f.adjustments.length) await exec(conn, 'UPDATE settlement_adjustments SET settlement_id = ? WHERE adjustment_id IN (?)', [r.insertId, f.adjustments.map((x) => x.adjustment_id)]);
      await audit(conn, actor(p), 'admin_settlement_prepare', 'settlements', r.insertId, undefined, { stallId, date, net: f.net });
      created++;
    });
  }
  res.json({ created });
});

async function loadSettlement(p: Panel, id: number) {
  const s = await one(pool, `${SETTLEMENT_SELECT} WHERE st.settlement_id = ?`, [id]);
  if (!s) throw notFound('not_found', 'Settlement not found');
  assertCanteen(p, s.canteen_id);
  return s;
}

/** Four-eyes: when more than one account can edit payments, the approver must not be the preparer. */
async function paymentEditors() {
  const team = await rows(pool, "SELECT role, permissions FROM users WHERE role IN ('admin','manager') AND is_active = TRUE");
  return team.filter((u) => panelPermissions(u.role, u.permissions).payments === 'edit').length;
}

moneyRouter.post('/admin/settlements/:id/approve', need('payments', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'settlement');
  const s = await loadSettlement(p, id);
  if (s.status !== 'pending') throw conflict('invalid_state', 'Only pending settlements can be approved.');
  if (s.prepared_by === p.id && (await paymentEditors()) > 1) {
    throw conflict('four_eyes', 'Another admin must approve a settlement you prepared.');
  }
  await withTx(async (conn) => {
    const r = await exec(conn, "UPDATE settlements SET status = 'approved', approved_by = ?, approved_at = UTC_TIMESTAMP() WHERE settlement_id = ? AND status = 'pending'", [p.id, id]);
    if (r.affectedRows !== 1) throw conflict('invalid_state', 'Only pending settlements can be approved.');
    await audit(conn, actor(p), 'admin_settlement_approve', 'settlements', id, { status: 'pending' }, { status: 'approved' });
  });
  res.json(toSettlement(await loadSettlement(p, id)));
});

moneyRouter.post('/admin/settlements/:id/pay', need('payments', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'settlement');
  const { bankRef } = z.object({ bankRef: z.string().trim().min(4, 'Enter the bank reference (UTR)').max(100) }).parse(req.body ?? {});
  await loadSettlement(p, id);
  await withTx(async (conn) => {
    const r = await exec(conn, "UPDATE settlements SET status = 'paid', bank_ref = ?, paid_at = UTC_TIMESTAMP() WHERE settlement_id = ? AND status = 'approved'", [bankRef, id]);
    if (r.affectedRows !== 1) throw conflict('invalid_state', 'Only approved settlements can be marked paid.');
    await audit(conn, actor(p), 'admin_settlement_paid', 'settlements', id, { status: 'approved' }, { status: 'paid', bankRef });
  });
  res.json(toSettlement(await loadSettlement(p, id)));
});

moneyRouter.get('/admin/settlements/:id', need('payments'), async (req, res) => {
  const p = panelOf(req);
  const s = await loadSettlement(p, idOf(req.params.id, 'settlement'));
  const bills = await rows(
    pool,
    `SELECT so.bill_no, so.created_at, so.subtotal, so.tax, sb.commission FROM settlement_bills sb
       JOIN stall_orders so ON so.stall_order_id = sb.stall_order_id WHERE sb.settlement_id = ? ORDER BY so.stall_order_id`,
    [s.settlement_id],
  );
  const adjustments = await rows(pool, 'SELECT * FROM settlement_adjustments WHERE settlement_id = ? ORDER BY adjustment_id', [s.settlement_id]);
  const gstPct = money(s.commission_gst_pct);
  res.json({
    settlement: toSettlement(s),
    commissionPct: money(s.commission_pct),
    commissionGstPct: gstPct,
    bills: bills.map((b) => {
      const c = toPaise(money(b.commission));
      const cGst = Math.round((c * gstPct) / 100);
      // Same rule as the payout: items + GST − commission − GST on commission.
      return { billNo: b.bill_no, createdAt: iso(b.created_at), subtotal: money(b.subtotal), gst: money(b.tax), commission: r2(c), net: r2(toPaise(b.subtotal) + toPaise(b.tax) - c - cGst) };
    }),
    adjustments: adjustments.map((a) => ({ id: a.adjustment_id, at: iso(a.created_at), amount: money(a.amount), note: a.note })),
  });
});

moneyRouter.get('/admin/settlements-ledger', need('payments'), async (req, res) => {
  const p = panelOf(req);
  const stallId = zId.parse(q(req, 'stallId'));
  const stall = await one(pool, 'SELECT canteen_id FROM stalls WHERE stall_id = ?', [stallId]);
  if (!stall) throw notFound('not_found', 'Stall not found');
  assertCanteen(p, stall.canteen_id);
  const payouts = await rows(pool, 'SELECT * FROM settlements WHERE stall_id = ? ORDER BY period_date DESC', [stallId]);
  const adjustments = await rows(
    pool,
    'SELECT a.*, st.status AS st_status FROM settlement_adjustments a LEFT JOIN settlements st ON st.settlement_id = a.settlement_id WHERE a.stall_id = ? ORDER BY a.adjustment_id DESC',
    [stallId],
  );
  const entries = [
    ...payouts.map((s) => ({
      at: iso(s.paid_at ?? s.approved_at ?? s.prepared_at)!,
      kind: 'payout' as const,
      description: `Settlement for ${ymd(s.period_date)} (${s.orders} orders)`,
      amount: money(s.net_payout),
      reference: s.bank_ref,
      status: s.status,
    })),
    ...adjustments.map((a) => ({
      at: iso(a.created_at)!,
      kind: 'adjustment' as const,
      description: a.note,
      amount: money(a.amount),
      reference: a.settlement_id ? `ST-${a.settlement_id}` : null,
      status: a.settlement_id ? (a.st_status as string) : 'pending',
    })),
  ].sort((a, b) => Date.parse(b.at) - Date.parse(a.at));
  const paid = payouts.filter((s) => s.status === 'paid').reduce((t, s) => t + toPaise(money(s.net_payout)), 0);
  const owed =
    payouts.filter((s) => s.status !== 'paid').reduce((t, s) => t + toPaise(money(s.net_payout)), 0) +
    adjustments.filter((a) => !a.settlement_id).reduce((t, a) => t + toPaise(money(a.amount)), 0);
  res.json({ entries, paid: r2(paid), outstanding: r2(owed) });
});

moneyRouter.post('/admin/settlements-adjustments', need('payments', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const b = z
    .object({ stallId: zId, amount: z.number().min(-100000).max(100000).refine((n) => n !== 0, 'The amount cannot be 0'), note: z.string().trim().min(1, 'Give a reason').max(255) })
    .parse(req.body ?? {});
  const stall = await one(pool, 'SELECT canteen_id FROM stalls WHERE stall_id = ?', [b.stallId]);
  if (!stall) throw invalid('That stall does not exist.');
  assertCanteen(p, stall.canteen_id);
  const id = await withTx(async (conn) => {
    const r = await exec(conn, 'INSERT INTO settlement_adjustments (stall_id, amount, note, created_by) VALUES (?, ?, ?, ?)', [b.stallId, b.amount, b.note, p.id]);
    await audit(conn, actor(p), 'admin_settlement_adjustment', 'settlements', r.insertId, undefined, b);
    return r.insertId;
  });
  res.status(201).json({ id, at: new Date().toISOString(), amount: b.amount, note: b.note });
});
