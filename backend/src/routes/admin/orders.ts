import { type Request, type Response, Router } from 'express';
import { z } from 'zod';
import { exec, one, pool, rows, withTx } from '../../db/pool.js';
import { AppError, conflict, notFound } from '../../errors.js';
import { publishBills } from '../../realtime.js';
import { type Panel, assertCanteen, can, maskEmail, need, panelOf, scopeCanteen } from '../../services/access.js';
import { audit } from '../../services/audit.js';
import { lockBill, returnStock, successfulPaymentId } from '../../services/bills.js';
import { bustMenuCache } from '../../services/menu.js';
import { insertRefund } from '../../services/payments.js';
import { getSettings } from '../../services/settings.js';
import { iso, toPaise, toRupees } from '../../util.js';
import { idOf, paging, q, sortSql, zDate } from './util.js';

export const ordersRouter = Router();

const actor = (p: Panel) => ({ id: p.id, role: p.role });
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;

const IST_CREATED = "DATE(CONVERT_TZ(so.created_at, '+00:00', '+05:30'))";
const secs = (a: Date | null, b: Date | null) => (a && b ? Math.max(0, Math.round((b.getTime() - a.getTime()) / 1000)) : null);
/** What the student paid for this bill: items + its share of both fees. */
const billPaid = (b: Row) => toRupees(toPaise(b.total) + toPaise(b.platform_fee) + toPaise(b.convenience_fee));

function paymentStatus(b: Row) {
  if (b.status === 'refunded') return 'refunded';
  if (b.order_status === 'paid') return 'paid';
  if (b.order_status === 'pending') return 'pending';
  return 'failed';
}

const BILL_SELECT = `
  SELECT so.*, s.stall_name, c.canteen_name, o.status AS order_status, o.paid_at, o.fees_waived, o.user_id,
         u.name AS student_name, u.email AS student_email, u.register_no,
         (SELECT COALESCE(SUM(oi.quantity), 0) FROM order_items oi WHERE oi.stall_order_id = so.stall_order_id AND oi.item_status = 'active') AS item_count
    FROM stall_orders so
    JOIN stalls s ON s.stall_id = so.stall_id
    JOIN canteens c ON c.canteen_id = so.canteen_id
    JOIN orders o ON o.order_id = so.order_id
    JOIN users u ON u.user_id = o.user_id`;

function toBillRow(b: Row, showContact: boolean) {
  return {
    id: b.stall_order_id,
    orderId: b.order_id,
    stallId: b.stall_id,
    canteenId: b.canteen_id,
    billNo: b.bill_no,
    pickupCode: b.pickup_code,
    status: b.status,
    subtotal: Number(b.subtotal),
    tax: Number(b.tax),
    billDate: b.bill_date ? new Date(b.bill_date).toISOString().slice(0, 10) : null,
    createdAt: iso(b.created_at),
    acceptedAt: iso(b.accepted_at),
    preparingAt: iso(b.preparing_at),
    readyAt: iso(b.ready_at),
    collectedAt: iso(b.collected_at),
    cancelReason: b.cancel_reason,
    pickupAt: null,
    test: false,
    stallName: b.stall_name,
    canteenName: b.canteen_name,
    studentName: b.student_name,
    studentEmail: showContact ? b.student_email : maskEmail(b.student_email),
    registerNo: b.register_no,
    itemCount: Number(b.item_count),
    total: billPaid(b),
    paidAt: iso(b.paid_at),
    prepSec: secs(b.accepted_at, b.ready_at),
    waitSec: secs(b.ready_at, b.collected_at),
    paymentStatus: paymentStatus(b),
    offer: b.fees_waived ? 'FIRST_ORDERS_FREE_FEE' : null,
  };
}

const BILL_SORT: Record<string, string> = {
  billNo: 'so.bill_no',
  stallName: 's.stall_name',
  canteenName: 'c.canteen_name',
  studentName: 'u.name',
  itemCount: 'item_count',
  total: 'so.total',
  status: 'so.status',
  paidAt: 'o.paid_at',
  acceptedAt: 'so.accepted_at',
  readyAt: 'so.ready_at',
  collectedAt: 'so.collected_at',
  createdAt: 'so.created_at',
};

ordersRouter.get('/admin/bills', need('orders'), (req, res) => listBills(req, res));

export async function listBills(req: Request, res: Response) {
  const p = panelOf(req);
  const { page, pageSize, limit, offset } = paging(req);
  if (q(req, 'test') === 'only') {
    res.json({ items: [], page, pageSize, total: 0 }); // test orders are not built yet
    return;
  }
  const where: string[] = [];
  const params: unknown[] = [];
  const from = q(req, 'from') ? zDate.parse(q(req, 'from')) : undefined;
  const to = q(req, 'to') ? zDate.parse(q(req, 'to')) : undefined;
  if (from) (where.push(`COALESCE(so.bill_date, ${IST_CREATED}) >= ?`), params.push(from));
  if (to) (where.push(`COALESCE(so.bill_date, ${IST_CREATED}) <= ?`), params.push(to));
  const canteenId = scopeCanteen(p, req.query.canteenId);
  if (canteenId) (where.push('so.canteen_id = ?'), params.push(canteenId));
  if (q(req, 'stallId')) (where.push('so.stall_id = ?'), params.push(Number(q(req, 'stallId'))));
  if (q(req, 'status')) (where.push('so.status = ?'), params.push(q(req, 'status')));
  if (q(req, 'cancelReason')) (where.push('so.cancel_reason = ?'), params.push(q(req, 'cancelReason')));
  const ps = q(req, 'paymentStatus');
  if (ps === 'refunded') where.push("so.status = 'refunded'");
  else if (ps === 'paid') where.push("o.status = 'paid' AND so.status <> 'refunded'");
  else if (ps === 'pending') where.push("o.status = 'pending'");
  else if (ps === 'failed') where.push("o.status IN ('cancelled','expired')");
  const user = q(req, 'user');
  if (user) {
    where.push(p.contactAccess ? '(u.name LIKE ? OR u.register_no LIKE ? OR u.email LIKE ?)' : '(u.name LIKE ? OR u.register_no LIKE ?)');
    params.push(`%${user}%`, `%${user}%`, ...(p.contactAccess ? [`%${user}%`] : []));
  }
  const text = q(req, 'q');
  if (text) {
    const orderNo = Number(text.replace(/^ORD-0*/i, ''));
    where.push(
      '(so.bill_no = ? OR so.pickup_code = ? OR so.order_id = ? OR EXISTS (SELECT 1 FROM payments pm WHERE pm.order_id = so.order_id AND pm.gateway_payment_ref = ?))',
    );
    params.push(text.toUpperCase(), text, Number.isInteger(orderNo) ? orderNo : 0, text);
  }
  const w = where.length ? `WHERE ${where.join(' AND ')}` : '';
  const total = (await one<{ n: number }>(pool, `SELECT COUNT(*) AS n FROM (${BILL_SELECT} ${w}) x`, params))!.n;
  const list = await rows(pool, `${BILL_SELECT} ${w} ORDER BY ${sortSql(req, BILL_SORT, 'so.created_at DESC')}, so.stall_order_id DESC LIMIT ? OFFSET ?`, [
    ...params,
    limit,
    offset,
  ]);
  res.json({ items: list.map((b) => toBillRow(b, p.contactAccess)), page, pageSize, total: Number(total) });
}

async function loadBillRow(id: number) {
  const b = await one(pool, `${BILL_SELECT} WHERE so.stall_order_id = ?`, [id]);
  if (!b) throw notFound('not_found', 'Bill not found');
  return b;
}

ordersRouter.get('/admin/bills/:id', need('orders'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'bill');
  const b = await loadBillRow(id);
  assertCanteen(p, b.canteen_id);
  const [items, order, payments, refunds, notes, history, settings] = await Promise.all([
    rows(pool, 'SELECT * FROM order_items WHERE stall_order_id = ? ORDER BY item_id', [id]),
    one(pool, 'SELECT * FROM orders WHERE order_id = ?', [b.order_id]),
    rows(pool, 'SELECT * FROM payments WHERE order_id = ? ORDER BY payment_id', [b.order_id]),
    rows(pool, 'SELECT * FROM refunds WHERE order_id = ? AND (stall_order_id = ? OR stall_order_id IS NULL) ORDER BY refund_id', [b.order_id, id]),
    rows(pool, 'SELECT n.*, u.name FROM bill_notes n JOIN users u ON u.user_id = n.user_id WHERE n.stall_order_id = ? ORDER BY n.note_id', [id]),
    rows(
      pool,
      `SELECT a.*, u.name FROM audit_log a LEFT JOIN users u ON u.user_id = a.actor_user_id
        WHERE a.table_name = 'stall_orders' AND a.record_id = ? ORDER BY a.audit_id`,
      [id],
    ),
    getSettings(),
  ]);
  // Commission is not charged yet (vendorCommissionPct is 0 until settlements are built); fees go to Brunchy.
  const commissionPct = settings.vendorCommissionPct;
  const commission = toRupees(Math.round((toPaise(b.subtotal) * commissionPct) / 100));
  const commissionGst = toRupees(Math.round((toPaise(commission) * settings.commissionGstPct) / 100));
  const fees = toRupees(toPaise(b.platform_fee) + toPaise(b.convenience_fee));
  const showMoney = can(p, 'payments');
  const timeline: { at: string; label: string; actor: string | null }[] = [];
  const add = (at: Date | null, label: string, who: string | null = null) => at && timeline.push({ at: iso(at)!, label, actor: who });
  add(b.created_at, 'placed', b.student_name);
  add(b.paid_at, 'paid');
  for (const a of history) {
    const n = typeof a.new_value === 'string' ? JSON.parse(a.new_value) : a.new_value;
    const label = a.action.replace(/^admin_bill_/, 'admin: ').replace(/^bill_/, '');
    timeline.push({ at: iso(a.created_at)!, label: n?.reason ? `${label} (${n.reason})` : label, actor: a.name ?? (a.role === 'system' ? 'system' : null) });
  }
  if (!history.some((a) => a.action === 'handover' || a.action === 'admin_bill_collect')) add(b.collected_at, 'collected');
  timeline.sort((x, y) => Date.parse(x.at) - Date.parse(y.at));
  res.json({
    bill: toBillRow(b, p.contactAccess),
    breakdown: showMoney
      ? {
          itemTotal: Number(b.subtotal),
          convenienceFee: fees,
          canteenFee: 0,
          vendorCommission: commission,
          vendorCommissionPct: commissionPct,
          gst: Number(b.tax),
          vendorCommissionGst: commissionGst,
          razorpayFee: 0,
          netToVendor: toRupees(toPaise(b.subtotal) + toPaise(b.tax) - toPaise(commission) - toPaise(commissionGst)),
          brunchyEarnings: toRupees(toPaise(fees) + toPaise(commission)),
          orderTotal: billPaid(b),
        }
      : null,
    notes: notes.map((n) => ({ at: iso(n.created_at), by: n.user_id, byName: n.name, text: n.note })),
    items: items.map((i) => ({
      id: i.item_id,
      billId: i.stall_order_id,
      productId: i.product_id,
      name: i.product_name,
      price: Number(i.price),
      gstRate: Number(i.gst_rate),
      qtyRequested: i.qty_requested,
      quantity: i.quantity,
      status: i.item_status === 'active' ? 'ok' : 'unavailable',
    })),
    order: {
      id: order!.order_id,
      userId: order!.user_id,
      canteenId: order!.canteen_id,
      subtotal: Number(order!.subtotal),
      tax: Number(order!.tax),
      convenienceFee: toRupees(toPaise(order!.convenience_fee) + toPaise(order!.additional_fee)),
      canteenFee: 0,
      total: Number(order!.total),
      status: order!.status,
      createdAt: iso(order!.created_at),
      paidAt: iso(order!.paid_at),
      offer: order!.fees_waived ? 'FIRST_ORDERS_FREE_FEE' : null,
      test: false,
    },
    payments: payments.map((m) => ({
      id: m.payment_id,
      orderId: m.order_id,
      gatewayRef: m.gateway_payment_ref,
      upiApp: m.upi_app ?? '',
      amount: Number(m.amount),
      method: 'upi',
      status: m.payment_status === 'created' ? 'pending' : m.payment_status,
      failureReason: m.failure_reason,
      createdAt: iso(m.created_at),
    })),
    refunds: refunds.map((r) => ({
      id: r.refund_id,
      orderId: r.order_id,
      billId: r.stall_order_id,
      amount: Number(r.amount),
      reasonCode: r.reason_code,
      requestedBy: r.requested_by,
      approvedBy: r.approved_by,
      status: r.status === 'processing' ? 'approved' : r.status,
      gatewayRefundRef: r.gateway_refund_ref,
      note: null,
      createdAt: iso(r.created_at),
      completedAt: iso(r.completed_at),
    })),
    timeline,
  });
});

const reason = z.string().trim().min(1, 'Give a reason').max(300);

/** Cancel and refund (needs orders edit + payments edit): the refund is recorded as requested, for approval. */
ordersRouter.post('/admin/bills/:id/cancel', need('orders', 'edit'), need('payments', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'bill');
  const b = z
    .object({ reasonCode: z.enum(['OUT_OF_STOCK', 'ITEM_UNAVAILABLE', 'KITCHEN_ISSUE', 'STALL_EMERGENCY', 'CANCELLED_BY_USER']), reason })
    .parse(req.body);
  const canteenId = await withTx(async (conn) => {
    const bill = await lockBill(conn, id);
    assertCanteen(p, bill.canteen_id);
    if (!['new', 'accepted', 'preparing'].includes(bill.status)) throw conflict('invalid_state', `A ${bill.status} bill cannot be cancelled.`);
    await exec(conn, "UPDATE stall_orders SET status = 'cancelled', cancelled_at = UTC_TIMESTAMP(), cancel_reason = ? WHERE stall_order_id = ?", [b.reasonCode, id]);
    if (b.reasonCode !== 'OUT_OF_STOCK') await returnStock(conn, id);
    await insertRefund(conn, {
      orderId: bill.order_id,
      billId: id,
      paymentId: await successfulPaymentId(conn, bill.order_id),
      amount: billPaid(bill),
      reason: b.reasonCode,
      requestedBy: p.id,
    });
    await audit(conn, actor(p), 'admin_bill_cancel', 'stall_orders', id, { status: bill.status }, { status: 'cancelled', ...b });
    return bill.canteen_id as number;
  });
  await bustMenuCache([canteenId]);
  await publishBills([id], 'bill.updated');
  res.json({ ok: true });
});

/** Mark picked up when the vendor app was offline: the student's pickup code must match. */
ordersRouter.post('/admin/bills/:id/collect', need('orders', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'bill');
  const b = z.object({ code: z.string().trim(), reason }).parse(req.body);
  await withTx(async (conn) => {
    const bill = await lockBill(conn, id);
    assertCanteen(p, bill.canteen_id);
    if (!['accepted', 'preparing', 'ready'].includes(bill.status)) throw conflict('invalid_state', `A ${bill.status} bill cannot be marked picked up.`);
    if (bill.pickup_code !== b.code) throw new AppError(422, 'wrong_code', 'That pickup code does not match this bill.');
    await exec(
      conn,
      `UPDATE stall_orders SET status = 'collected', accepted_at = COALESCE(accepted_at, UTC_TIMESTAMP()), ready_at = COALESCE(ready_at, UTC_TIMESTAMP()),
              collected_at = UTC_TIMESTAMP(), collected_by = ? WHERE stall_order_id = ?`,
      [p.id, id],
    );
    await audit(conn, actor(p), 'admin_bill_collect', 'stall_orders', id, { status: bill.status }, { status: 'collected', reason: b.reason });
  });
  await publishBills([id], 'bill.updated');
  res.json({ ok: true });
});

const STATUS_TIME: Record<string, string> = {
  new: '',
  accepted: 'accepted_at = COALESCE(accepted_at, UTC_TIMESTAMP())',
  preparing: 'accepted_at = COALESCE(accepted_at, UTC_TIMESTAMP()), preparing_at = COALESCE(preparing_at, UTC_TIMESTAMP())',
  ready: 'accepted_at = COALESCE(accepted_at, UTC_TIMESTAMP()), ready_at = COALESCE(ready_at, UTC_TIMESTAMP())',
  collected: 'accepted_at = COALESCE(accepted_at, UTC_TIMESTAMP()), ready_at = COALESCE(ready_at, UTC_TIMESTAMP()), collected_at = UTC_TIMESTAMP()',
};

/** Fixes a bill stuck in the wrong state. Times for skipped steps are filled with now. */
ordersRouter.post('/admin/bills/:id/status', need('orders', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'bill');
  const b = z.object({ status: z.enum(['new', 'accepted', 'preparing', 'ready', 'collected']), reason }).parse(req.body);
  await withTx(async (conn) => {
    const bill = await lockBill(conn, id);
    assertCanteen(p, bill.canteen_id);
    if (['cancelled', 'rejected', 'refunded', 'expired', 'awaiting_payment'].includes(bill.status)) {
      throw conflict('invalid_state', `A ${bill.status} bill cannot change status.`);
    }
    const extra = STATUS_TIME[b.status];
    await exec(conn, `UPDATE stall_orders SET status = ?${extra ? `, ${extra}` : ''}${b.status === 'collected' ? ', collected_by = ?' : ''} WHERE stall_order_id = ?`, [
      b.status,
      ...(b.status === 'collected' ? [p.id] : []),
      id,
    ]);
    await audit(conn, actor(p), 'admin_bill_status', 'stall_orders', id, { status: bill.status }, b);
  });
  await publishBills([id], 'bill.updated');
  res.json({ ok: true });
});

/** The money went back outside the app (Razorpay dashboard, UPI, cash): close the refund with its reference. */
ordersRouter.post('/admin/bills/:id/mark-refunded', need('orders', 'edit'), need('payments', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'bill');
  const b = z.object({ reference: z.string().trim().min(3).max(100), reason }).parse(req.body);
  await withTx(async (conn) => {
    const bill = await lockBill(conn, id);
    assertCanteen(p, bill.canteen_id);
    const order = await one(conn, 'SELECT status FROM orders WHERE order_id = ?', [bill.order_id]);
    if (order?.status !== 'paid') throw conflict('invalid_state', 'Only paid bills can be marked refunded.');
    if (bill.status === 'refunded') throw conflict('invalid_state', 'This bill is already refunded.');
    const open = await one(conn, "SELECT refund_id FROM refunds WHERE stall_order_id = ? AND status IN ('requested','approved','processing','failed') ORDER BY refund_id LIMIT 1 FOR UPDATE", [id]);
    if (open) {
      await exec(conn, "UPDATE refunds SET status = 'completed', gateway_refund_ref = ?, approved_by = COALESCE(approved_by, ?), completed_at = UTC_TIMESTAMP() WHERE refund_id = ?", [
        b.reference,
        p.id,
        open.refund_id,
      ]);
    } else {
      await exec(
        conn,
        `INSERT INTO refunds (order_id, stall_order_id, payment_id, amount, reason_code, requested_by, approved_by, gateway_refund_ref, status, completed_at)
         VALUES (?, ?, ?, ?, 'KITCHEN_ISSUE', ?, ?, ?, 'completed', UTC_TIMESTAMP())`,
        [bill.order_id, id, await successfulPaymentId(conn, bill.order_id), billPaid(bill), p.id, p.id, b.reference],
      );
    }
    if (['new', 'accepted', 'preparing', 'ready'].includes(bill.status)) await returnStock(conn, id);
    await exec(conn, "UPDATE stall_orders SET status = 'refunded', cancelled_at = COALESCE(cancelled_at, UTC_TIMESTAMP()) WHERE stall_order_id = ?", [id]);
    await audit(conn, actor(p), 'admin_bill_mark_refunded', 'stall_orders', id, { status: bill.status }, { status: 'refunded', ...b });
  });
  await publishBills([id], 'bill.updated');
  res.json({ ok: true });
});

ordersRouter.post('/admin/bills/:id/notes', need('orders', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'bill');
  const { text } = z.object({ text: z.string().trim().min(1).max(500) }).parse(req.body);
  const bill = await loadBillRow(id);
  assertCanteen(p, bill.canteen_id);
  await withTx(async (conn) => {
    await exec(conn, 'INSERT INTO bill_notes (stall_order_id, user_id, note) VALUES (?, ?, ?)', [id, p.id, text]);
    await audit(conn, actor(p), 'admin_bill_note', 'stall_orders', id, undefined, { text });
  });
  await publishBills([id], 'bill.updated');
  res.json({ ok: true });
});

