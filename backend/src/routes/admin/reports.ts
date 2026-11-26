import type { Request, Response } from 'express';
import { Router } from 'express';
import { one, pool, rows } from '../../db/pool.js';
import { forbidden, notFound } from '../../errors.js';
import { type Panel, can, invalid, maskEmail, maskPhone, panelOf, scopeCanteen } from '../../services/access.js';
import { audit } from '../../services/audit.js';
import { getSettings } from '../../services/settings.js';
import { toPaise, toRupees } from '../../util.js';
import { listProducts } from './catalog.js';
import { listAudit } from './misc.js';
import { listPayments, listRefunds, listSettlements } from './money.js';
import { listBills } from './orders.js';
import { listUsers } from './people.js';
import { addDays, istDay, q, zDate } from './util.js';

/**
 * Reports & analytics (handover section 7). Every day is an IST day; amounts are rupees; rates are fractions (0.92).
 * Test orders do not exist yet, so nothing needs excluding.
 */
export const reportsRouter = Router();

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;
type Report = { rows: Row[]; breakdown?: { label: string; value: number }[] };
const n = (v: unknown) => Number(v ?? 0);
const r2 = (v: number) => Math.round(v * 100) / 100;
const pct = (a: number, b: number) => (b ? a / b : 0);
const ist = (col: string) => `DATE(CONVERT_TZ(${col}, '+00:00', '+05:30'))`;
const IST_HOUR = (col: string) => `HOUR(CONVERT_TZ(${col}, '+00:00', '+05:30'))`;

interface Filters {
  from: string;
  to: string;
  canteenId: number | null;
  stallId: number | null;
  groupBy: 'day' | 'week' | 'month';
}

function filters(req: Request, p: Panel): Filters {
  const to = q(req, 'to') ? zDate.parse(q(req, 'to')) : istDay();
  const from = q(req, 'from') ? zDate.parse(q(req, 'from')) : addDays(to, -13);
  if (from > to) throw invalid('The start date is after the end date.');
  const g = q(req, 'groupBy');
  const stall = Number(q(req, 'stallId'));
  return { from, to, canteenId: scopeCanteen(p, req.query.canteenId), stallId: Number.isInteger(stall) && stall > 0 ? stall : null, groupBy: g === 'week' || g === 'month' ? g : 'day' };
}

/** SQL for the period a date column falls in: day YYYY-MM-DD, week = its Monday, month YYYY-MM. */
function period(col: string, g: Filters['groupBy']) {
  if (g === 'month') return `DATE_FORMAT(${col}, '%Y-%m')`;
  if (g === 'week') return `DATE_FORMAT(DATE_SUB(${col}, INTERVAL WEEKDAY(${col}) DAY), '%Y-%m-%d')`;
  return `DATE_FORMAT(${col}, '%Y-%m-%d')`;
}

/** WHERE parts for bills (stall_orders so) in the date range with the canteen/stall filter. */
function billScope(f: Filters, dateCol = 'so.bill_date') {
  const where = [`${dateCol} BETWEEN ? AND ?`];
  const params: unknown[] = [f.from, f.to];
  if (f.canteenId) (where.push('so.canteen_id = ?'), params.push(f.canteenId));
  if (f.stallId) (where.push('so.stall_id = ?'), params.push(f.stallId));
  return { where: where.join(' AND '), params };
}

const PAID_BILL = "so.bill_no IS NOT NULL AND so.status NOT IN ('awaiting_payment','expired')";
const LIVE_BILL = "so.status NOT IN ('awaiting_payment','expired','cancelled','rejected','refunded')";

function percentile(values: number[], p: number) {
  if (!values.length) return null;
  const s = [...values].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.ceil((p / 100) * s.length) - 1)];
}
const avg = (values: number[]) => (values.length ? Math.round(values.reduce((a, b) => a + b, 0) / values.length) : null);

// ---------------------------------------------------------------- the 10 reports

async function canteensReport(f: Filters): Promise<Report> {
  const s = await getSettings();
  const per = period('so.bill_date', f.groupBy);
  const { where, params } = billScope(f);
  const list = await rows(
    pool,
    `SELECT ${per} AS period, c.canteen_name AS canteen, COUNT(DISTINCT so.order_id) AS orders,
            SUM(so.total + so.platform_fee + so.convenience_fee) AS gmv, SUM(so.platform_fee + so.convenience_fee) AS fees,
            SUM(CASE WHEN ${LIVE_BILL} THEN so.subtotal ELSE 0 END) AS live_subtotal
       FROM stall_orders so JOIN canteens c ON c.canteen_id = so.canteen_id
      WHERE ${PAID_BILL} AND ${where} GROUP BY period, c.canteen_id, c.canteen_name ORDER BY period, canteen`,
    params,
  );
  return {
    rows: list.map((r) => {
      const commission = r2((n(r.live_subtotal) * s.vendorCommissionPct) / 100);
      return {
        period: r.period,
        canteen: r.canteen,
        orders: n(r.orders),
        gmv: n(r.gmv),
        convenienceFees: n(r.fees),
        commission,
        brunchyEarnings: r2(n(r.fees) + commission),
        averageOrderValue: n(r.orders) ? r2(n(r.gmv) / n(r.orders)) : 0,
      };
    }),
  };
}

async function salesReport(f: Filters): Promise<Report> {
  const per = period('so.bill_date', f.groupBy);
  const { where, params } = billScope(f);
  const sales = await rows(
    pool,
    `SELECT ${per} AS period, SUM(so.total + so.platform_fee + so.convenience_fee) AS gross, SUM(so.tax) AS gst,
            SUM(so.platform_fee + so.convenience_fee) AS fees, COUNT(DISTINCT so.order_id) AS orders, COUNT(*) AS bills
       FROM stall_orders so WHERE ${PAID_BILL} AND ${where} GROUP BY period ORDER BY period`,
    params,
  );
  // Refunds count in the period they were created; whole-order refunds (no bill) count when no stall is filtered.
  const rp = period(ist('r.created_at'), f.groupBy);
  const rw = [`${ist('r.created_at')} BETWEEN ? AND ?`, "r.status NOT IN ('rejected','failed')"];
  const rparams: unknown[] = [f.from, f.to];
  if (f.canteenId) (rw.push('o.canteen_id = ?'), rparams.push(f.canteenId));
  if (f.stallId) (rw.push('so.stall_id = ?'), rparams.push(f.stallId));
  const refunds = await rows(
    pool,
    `SELECT ${rp} AS period, SUM(r.amount) AS amount FROM refunds r JOIN orders o ON o.order_id = r.order_id
       LEFT JOIN stall_orders so ON so.stall_order_id = r.stall_order_id WHERE ${rw.join(' AND ')} GROUP BY period`,
    rparams,
  );
  const periods = [...new Set([...sales.map((r) => r.period), ...refunds.map((r) => r.period)])].sort();
  return {
    rows: periods.map((pd) => {
      const s = sales.find((r) => r.period === pd);
      const refund = n(refunds.find((r) => r.period === pd)?.amount);
      const gross = n(s?.gross);
      return {
        period: pd,
        grossSales: gross,
        refunds: refund,
        netSales: r2(gross - refund),
        gst: n(s?.gst),
        convenienceFees: n(s?.fees),
        paidOrders: n(s?.orders),
        bills: n(s?.bills),
        averageOrderValue: n(s?.orders) ? r2(gross / n(s?.orders)) : 0,
      };
    }),
  };
}

async function stallsReport(f: Filters): Promise<Report> {
  const { where, params } = billScope(f);
  const list = await rows(
    pool,
    `SELECT s.stall_name AS stall, COUNT(*) AS bills, SUM(so.subtotal) AS subtotal,
            AVG(CASE WHEN so.ready_at IS NOT NULL AND so.accepted_at IS NOT NULL THEN TIMESTAMPDIFF(SECOND, so.accepted_at, so.ready_at) END) AS prep,
            SUM(so.status = 'rejected') AS rejected, SUM(so.status = 'cancelled') AS cancelled, SUM(so.status = 'collected') AS collected,
            (SELECT COALESCE(SUM(r.amount), 0) FROM refunds r JOIN stall_orders x ON x.stall_order_id = r.stall_order_id
              WHERE x.stall_id = so.stall_id AND x.bill_date BETWEEN ? AND ? AND r.status NOT IN ('rejected','failed')) AS refunds
       FROM stall_orders so JOIN stalls s ON s.stall_id = so.stall_id
      WHERE ${PAID_BILL} AND ${where} GROUP BY so.stall_id, s.stall_name ORDER BY subtotal DESC`,
    [f.from, f.to, ...params],
  );
  return {
    rows: list.map((r) => ({
      stall: r.stall,
      bills: n(r.bills),
      netSales: r2(n(r.subtotal) - n(r.refunds)),
      avgPrepSec: r.prep == null ? null : Math.round(n(r.prep)),
      rejectionPct: pct(n(r.rejected), n(r.bills)),
      cancelPct: pct(n(r.cancelled), n(r.bills)),
      collectedPct: pct(n(r.collected), n(r.bills)),
    })),
  };
}

async function itemsReport(f: Filters): Promise<Report> {
  const { where, params } = billScope(f);
  const list = await rows(
    pool,
    `SELECT oi.product_id, oi.product_name AS product, s.stall_name AS stall, SUM(oi.quantity) AS qty, SUM(oi.quantity * oi.price) AS revenue
       FROM order_items oi JOIN stall_orders so ON so.stall_order_id = oi.stall_order_id JOIN stalls s ON s.stall_id = so.stall_id
      WHERE oi.item_status = 'active' AND ${PAID_BILL} AND ${LIVE_BILL} AND ${where}
      GROUP BY oi.product_id, oi.product_name, s.stall_name ORDER BY revenue DESC`,
    params,
  );
  // Sold-out events: an admin or vendor set the stock to 0 (or marked it sold out) in the range.
  const soldOut = list.length
    ? await rows<{ record_id: number; n: number }>(
        pool,
        `SELECT record_id, COUNT(*) AS n FROM audit_log WHERE table_name = 'products' AND record_id IN (?)
           AND action IN ('product_update','admin_product_update') AND ${ist('created_at')} BETWEEN ? AND ?
           AND (JSON_EXTRACT(new_value, '$.stockQuantity') = 0 OR JSON_EXTRACT(new_value, '$.stock') = 0 OR JSON_EXTRACT(new_value, '$.available') = false)
         GROUP BY record_id`,
        [list.map((r) => r.product_id), f.from, f.to],
      )
    : [];
  return {
    rows: list.map((r) => ({
      product: r.product,
      stall: r.stall,
      quantity: n(r.qty),
      revenue: n(r.revenue),
      soldOutEvents: n(soldOut.find((s) => s.record_id === r.product_id)?.n),
    })),
  };
}

async function peakReport(f: Filters): Promise<Report> {
  const { where, params } = billScope(f);
  const list = await rows(
    pool,
    `SELECT DAYOFWEEK(CONVERT_TZ(so.created_at, '+00:00', '+05:30')) - 1 AS wd, ${IST_HOUR('so.created_at')} AS h, COUNT(*) AS bills
       FROM stall_orders so WHERE ${PAID_BILL} AND ${where} GROUP BY wd, h`,
    params,
  );
  const out: Row[] = [];
  for (let w = 0; w < 7; w++) for (let h = 0; h < 24; h++) out.push({ weekday: w, hour: h, bills: n(list.find((r) => n(r.wd) === w && n(r.h) === h)?.bills) });
  return { rows: out };
}

async function operationsReport(f: Filters): Promise<Report> {
  const { where, params } = billScope(f);
  const list = await rows(
    pool,
    `SELECT s.stall_name, o.paid_at, so.accepted_at, so.ready_at, so.collected_at FROM stall_orders so
       JOIN stalls s ON s.stall_id = so.stall_id JOIN orders o ON o.order_id = so.order_id
      WHERE ${PAID_BILL} AND ${where}`,
    params,
  );
  const gap = (a: Date | null, b: Date | null) => (a && b ? Math.max(0, (new Date(b).getTime() - new Date(a).getTime()) / 1000) : null);
  const summarize = (stall: string, bills: Row[]) => {
    const accept = bills.map((b) => gap(b.paid_at, b.accepted_at)).filter((x): x is number => x != null);
    const prep = bills.map((b) => gap(b.accepted_at, b.ready_at)).filter((x): x is number => x != null);
    const wait = bills.map((b) => gap(b.ready_at, b.collected_at)).filter((x): x is number => x != null);
    return {
      stall,
      acceptAvg: avg(accept),
      acceptP95: percentile(accept, 95),
      prepAvg: avg(prep),
      prepP95: percentile(prep, 95),
      waitAvg: avg(wait),
      waitP95: percentile(wait, 95),
    };
  };
  const stalls = [...new Set(list.map((b) => b.stall_name as string))].sort();
  return { rows: [summarize('All stalls', list), ...stalls.map((s) => summarize(s, list.filter((b) => b.stall_name === s)))] };
}

async function studentsReport(f: Filters): Promise<Report> {
  const cw = f.canteenId ? 'AND o.canteen_id = ?' : '';
  const cp = f.canteenId ? [f.canteenId] : [];
  const paid = await rows(
    pool,
    `SELECT DATE_FORMAT(${ist('o.paid_at')}, '%Y-%m-%d') AS d, o.user_id, COUNT(*) AS orders,
            (SELECT MIN(${ist('x.paid_at')}) FROM orders x WHERE x.user_id = o.user_id AND x.status = 'paid') AS first_day
       FROM orders o WHERE o.status = 'paid' AND ${ist('o.paid_at')} BETWEEN ? AND ? ${cw} GROUP BY d, o.user_id`,
    [f.from, f.to, ...cp],
  );
  const created = await rows(
    pool,
    `SELECT DATE_FORMAT(${ist('created_at')}, '%Y-%m-%d') AS d, COUNT(*) AS n FROM users WHERE role = 'student' AND ${ist('created_at')} BETWEEN ? AND ? GROUP BY d`,
    [f.from, f.to],
  );
  const noShows = await rows(
    pool,
    `SELECT DATE_FORMAT(so.bill_date, '%Y-%m-%d') AS d, COUNT(*) AS n FROM stall_orders so
      WHERE so.status = 'expired' AND so.ready_at IS NOT NULL AND so.bill_date BETWEEN ? AND ? ${f.canteenId ? 'AND so.canteen_id = ?' : ''} GROUP BY d`,
    [f.from, f.to, ...cp],
  );
  const out: Row[] = [];
  for (let d = f.from; d <= f.to; d = addDays(d, 1)) {
    const day = paid.filter((r) => r.d === d);
    const first = day.filter((r) => r.first_day && new Date(r.first_day).toISOString().slice(0, 10) === d).length;
    out.push({
      day: d,
      activeStudents: day.length,
      returning: day.length - first,
      firstTime: first,
      newStudents: n(created.find((r) => r.d === d)?.n),
      ordersPerStudent: day.length ? r2(day.reduce((s, r) => s + n(r.orders), 0) / day.length) : 0,
      noShows: n(noShows.find((r) => r.d === d)?.n),
    });
  }
  return { rows: out };
}

async function paymentsReport(f: Filters): Promise<Report> {
  const cw = f.canteenId ? 'AND o.canteen_id = ?' : '';
  const cp = f.canteenId ? [f.canteenId] : [];
  const pays = await rows(
    pool,
    `SELECT DATE_FORMAT(${ist('pm.created_at')}, '%Y-%m-%d') AS d, COUNT(*) AS attempts, SUM(pm.payment_status = 'success') AS ok
       FROM payments pm JOIN orders o ON o.order_id = pm.order_id WHERE ${ist('pm.created_at')} BETWEEN ? AND ? ${cw} GROUP BY d`,
    [f.from, f.to, ...cp],
  );
  const expired = await rows(
    pool,
    `SELECT DATE_FORMAT(${ist('o.created_at')}, '%Y-%m-%d') AS d, COUNT(*) AS n FROM orders o WHERE o.status = 'expired' AND ${ist('o.created_at')} BETWEEN ? AND ? ${cw} GROUP BY d`,
    [f.from, f.to, ...cp],
  );
  const late = await rows(
    pool,
    `SELECT DATE_FORMAT(${ist('r.created_at')}, '%Y-%m-%d') AS d, COUNT(*) AS n FROM refunds r JOIN orders o ON o.order_id = r.order_id
      WHERE r.reason_code = 'LATE_PAYMENT' AND ${ist('r.created_at')} BETWEEN ? AND ? ${cw} GROUP BY d`,
    [f.from, f.to, ...cp],
  );
  const reasons = await rows(
    pool,
    `SELECT COALESCE(pm.failure_reason, 'unknown') AS label, COUNT(*) AS value FROM payments pm JOIN orders o ON o.order_id = pm.order_id
      WHERE pm.payment_status = 'failed' AND ${ist('pm.created_at')} BETWEEN ? AND ? ${cw} GROUP BY label ORDER BY value DESC`,
    [f.from, f.to, ...cp],
  );
  const out: Row[] = [];
  for (let d = f.from; d <= f.to; d = addDays(d, 1)) {
    const p = pays.find((r) => r.d === d);
    out.push({
      day: d,
      attempts: n(p?.attempts),
      successRate: n(p?.attempts) ? n(p?.ok) / n(p?.attempts) : null,
      expiredHolds: n(expired.find((r) => r.d === d)?.n),
      latePaymentsRefunded: n(late.find((r) => r.d === d)?.n),
    });
  }
  return { rows: out, breakdown: reasons.map((r) => ({ label: r.label, value: n(r.value) })) };
}

async function cancellationsReport(f: Filters): Promise<Report> {
  const { where, params } = billScope(f);
  const list = await rows(
    pool,
    `SELECT so.stall_id, s.stall_name AS stall, c.canteen_name AS canteen, COUNT(*) AS bills,
            SUM(so.status = 'rejected') AS rejected, SUM(so.status = 'cancelled') AS cancelled
       FROM stall_orders so JOIN stalls s ON s.stall_id = so.stall_id JOIN canteens c ON c.canteen_id = so.canteen_id
      WHERE ${PAID_BILL} AND ${where} GROUP BY so.stall_id, s.stall_name, c.canteen_name ORDER BY rejected DESC, cancelled DESC`,
    params,
  );
  const reasons = await rows(
    pool,
    `SELECT so.stall_id, so.cancel_reason AS reason, COUNT(*) AS n FROM stall_orders so
      WHERE ${PAID_BILL} AND so.cancel_reason IS NOT NULL AND ${where} GROUP BY so.stall_id, so.cancel_reason ORDER BY n DESC`,
    params,
  );
  const totals = new Map<string, number>();
  for (const r of reasons) totals.set(r.reason, (totals.get(r.reason) ?? 0) + n(r.n));
  return {
    rows: list.map((r) => ({
      stall: r.stall,
      canteen: r.canteen,
      bills: n(r.bills),
      rejected: n(r.rejected),
      cancelled: n(r.cancelled),
      rejectionPct: pct(n(r.rejected), n(r.bills)),
      topReason: reasons.find((x) => x.stall_id === r.stall_id)?.reason ?? null,
    })),
    breakdown: [...totals.entries()].sort((a, b) => b[1] - a[1]).map(([label, value]) => ({ label, value })),
  };
}

/** What each stall is owed for its collected bills in the range (whether or not a payout was prepared yet). */
async function settlementReport(f: Filters): Promise<Report> {
  const s = await getSettings();
  const { where, params } = billScope(f);
  const list = await rows(
    pool,
    `SELECT so.stall_id, s.stall_name AS stall, COUNT(*) AS bills, SUM(so.subtotal) AS subtotal, SUM(so.tax) AS gst,
            SUM(COALESCE(sb.commission, ROUND(so.subtotal * ? / 100, 2))) AS commission,
            (SELECT COALESCE(SUM(LEAST(r.amount, x.subtotal + x.tax)), 0) FROM refunds r JOIN stall_orders x ON x.stall_order_id = r.stall_order_id
              WHERE x.stall_id = so.stall_id AND x.status = 'refunded' AND x.collected_at IS NOT NULL AND x.bill_date BETWEEN ? AND ?
                AND r.status IN ('approved','processing','completed')) AS refunds
       FROM stall_orders so JOIN stalls s ON s.stall_id = so.stall_id LEFT JOIN settlement_bills sb ON sb.stall_order_id = so.stall_order_id
      WHERE so.status = 'collected' AND ${where} GROUP BY so.stall_id, s.stall_name ORDER BY s.stall_name`,
    [s.vendorCommissionPct, f.from, f.to, ...params],
  );
  return {
    rows: list.map((r) => {
      const commissionGst = r2((n(r.commission) * s.commissionGstPct) / 100);
      return {
        stall: r.stall,
        collectedBills: n(r.bills),
        billTotal: n(r.subtotal),
        gst: n(r.gst),
        commission: n(r.commission),
        commissionGst,
        refundsCharged: n(r.refunds),
        netPayable: r2(n(r.subtotal) + n(r.gst) - n(r.commission) - commissionGst - n(r.refunds)),
      };
    }),
  };
}

const REPORTS: Record<string, (f: Filters) => Promise<Report>> = {
  canteens: canteensReport,
  sales: salesReport,
  stalls: stallsReport,
  items: itemsReport,
  peak: peakReport,
  operations: operationsReport,
  students: studentsReport,
  payments: paymentsReport,
  cancellations: cancellationsReport,
  settlement: settlementReport,
};

reportsRouter.get('/admin/reports/:id', async (req, res) => {
  const p = panelOf(req);
  const build = REPORTS[req.params.id];
  if (!build) throw notFound('not_found', 'No such report');
  // The cancellations report is for orders or payments accounts; every other report needs payments.
  const ok = req.params.id === 'cancellations' ? can(p, 'orders') || can(p, 'payments') : can(p, 'payments');
  if (!ok) throw forbidden('forbidden', 'Your account cannot see this report.');
  res.json(await build(filters(req, p)));
});

// ---------------------------------------------------------------- growth analytics

reportsRouter.get('/admin/analytics', async (req, res) => {
  const p = panelOf(req);
  if (!can(p, 'payments')) throw forbidden('forbidden', 'Your account cannot see analytics.');
  const f = filters(req, p);
  const s = await getSettings();
  const cw = f.canteenId ? 'AND o.canteen_id = ?' : '';
  const cp = f.canteenId ? [f.canteenId] : [];
  const inRange = `o.status = 'paid' AND ${ist('o.paid_at')} BETWEEN ? AND ? ${cw}`;
  const rp = [f.from, f.to, ...cp];
  const [users, newUsers, orders, perUser, perCanteen, perHour, daily, dau, mau, waived] = await Promise.all([
    one(pool, "SELECT COUNT(*) AS n FROM users WHERE role = 'student' AND is_active = TRUE"),
    one(pool, `SELECT COUNT(*) AS n FROM users WHERE role = 'student' AND ${ist('created_at')} BETWEEN ? AND ?`, [f.from, f.to]),
    one(pool, `SELECT COUNT(*) AS n, COALESCE(SUM(o.total), 0) AS gmv FROM orders o WHERE ${inRange}`, rp),
    rows(pool, `SELECT o.user_id, COUNT(*) AS n FROM orders o WHERE ${inRange} GROUP BY o.user_id`, rp),
    rows(pool, `SELECT c.canteen_name AS canteen, COUNT(*) AS orders FROM orders o JOIN canteens c ON c.canteen_id = o.canteen_id WHERE ${inRange} GROUP BY c.canteen_name ORDER BY orders DESC`, rp),
    rows(pool, `SELECT ${IST_HOUR('o.paid_at')} AS h, COUNT(*) AS n FROM orders o WHERE ${inRange} GROUP BY h`, rp),
    rows(pool, `SELECT DATE_FORMAT(${ist('o.paid_at')}, '%Y-%m-%d') AS d, COUNT(DISTINCT o.user_id) AS n FROM orders o WHERE ${inRange} GROUP BY d`, rp),
    one(pool, `SELECT COUNT(DISTINCT o.user_id) AS n FROM orders o WHERE o.status = 'paid' AND ${ist('o.paid_at')} = ? ${cw}`, [f.to, ...cp]),
    one(pool, `SELECT COUNT(DISTINCT o.user_id) AS n FROM orders o WHERE o.status = 'paid' AND ${ist('o.paid_at')} BETWEEN ? AND ? ${cw}`, [addDays(f.to, -29), f.to, ...cp]),
    rows(
      pool,
      `SELECT o.user_id, o.subtotal,
              EXISTS (SELECT 1 FROM orders x WHERE x.user_id = o.user_id AND x.status = 'paid' AND x.fees_waived = FALSE AND x.paid_at > o.paid_at) AS converted
         FROM orders o WHERE ${inRange} AND o.fees_waived = TRUE`,
      rp,
    ),
  ]);
  const count = n(orders?.n);
  const freeUsers = new Set(waived.map((w) => w.user_id));
  const converted = new Set(waived.filter((w) => n(w.converted)).map((w) => w.user_id));
  const feeWaived = toRupees(waived.reduce((t, w) => t + Math.round((toPaise(n(w.subtotal)) * (s.platformFeePct + s.convenienceFeePct)) / 100), 0));
  const days: Row[] = [];
  for (let d = f.from; d <= f.to; d = addDays(d, 1)) days.push({ day: d, active: n(daily.find((r) => r.d === d)?.n) });
  res.json({
    from: f.from,
    to: f.to,
    totalUsers: n(users?.n),
    newUsers: n(newUsers?.n),
    dau: n(dau?.n),
    mau: n(mau?.n),
    repeatRate: pct(perUser.filter((u) => n(u.n) >= 2).length, perUser.length),
    orders: count,
    averageOrderValue: count ? r2(n(orders?.gmv) / count) : 0,
    aovTarget: 150,
    perCanteen: perCanteen.map((r) => ({ canteen: r.canteen, orders: n(r.orders) })),
    perHour: Array.from({ length: 16 }, (_, i) => i + 7).map((h) => ({ hour: h, orders: n(perHour.find((r) => n(r.h) === h)?.n) })),
    dailyActive: days,
    offerPerformance: {
      freeFeeOrders: waived.length,
      freeFeeUsers: freeUsers.size,
      convertedToPaying: converted.size,
      conversionRate: pct(converted.size, freeUsers.size),
      offers: waived.length ? [{ offer: 'FIRST_ORDERS_FREE_FEE', orders: waived.length, feeWaived }] : [],
    },
  });
});

// ---------------------------------------------------------------- exports (CSV / JSON)

type Col = { key: string; label: string; type?: 'text' | 'number' | 'money' | 'pct' | 'datetime' | 'date' | 'duration' };
const c = (key: string, label: string, type?: Col['type']): Col => ({ key, label, type });

/** Runs a list endpoint's function with every matching row (no paging) and returns its items. */
async function allRows(fn: (req: Request, res: Response) => Promise<void>, req: Request) {
  let body: { items: Row[] } = { items: [] };
  const fake = { json: (v: { items: Row[] }) => void (body = v) } as unknown as Response;
  (req as Request & { exportAll?: boolean }).exportAll = true;
  try {
    await fn(req, fake);
  } finally {
    (req as Request & { exportAll?: boolean }).exportAll = false;
  }
  return body.items;
}

interface Dataset {
  section: Parameters<typeof can>[1];
  columns: Col[];
  rows: (req: Request, p: Panel) => Promise<Row[]>;
}

const DATASETS: Record<string, Dataset> = {
  bills: {
    section: 'orders',
    columns: [c('billNo', 'Bill no'), c('stallName', 'Stall'), c('canteenName', 'Canteen'), c('studentName', 'Student'), c('registerNo', 'Register no'), c('studentEmail', 'Email'), c('itemCount', 'Items', 'number'), c('total', 'Total', 'money'), c('status', 'Status'), c('paymentStatus', 'Payment status'), c('offer', 'Offer applied'), c('paidAt', 'Paid at', 'datetime'), c('acceptedAt', 'Accepted', 'datetime'), c('readyAt', 'Ready', 'datetime'), c('collectedAt', 'Collected', 'datetime'), c('prepSec', 'Prep time (s)', 'duration'), c('waitSec', 'Wait time (s)', 'duration'), c('cancelReason', 'Cancel reason')],
    rows: (req) => allRows(listBills, req),
  },
  payments: {
    section: 'payments',
    columns: [c('createdAt', 'Time', 'datetime'), c('orderId', 'Order'), c('studentName', 'Student'), c('gatewayRef', 'Razorpay payment ID'), c('method', 'Method'), c('upiApp', 'UPI app'), c('amount', 'Amount', 'money'), c('razorpayFee', 'Razorpay fee', 'money'), c('status', 'Status'), c('failureReason', 'Failure reason')],
    rows: (req) => allRows(listPayments, req),
  },
  refunds: {
    section: 'payments',
    columns: [c('createdAt', 'Created', 'datetime'), c('amount', 'Amount', 'money'), c('reasonCode', 'Reason'), c('billNo', 'Bill'), c('orderId', 'Order'), c('stallName', 'Stall'), c('requestedByName', 'Requested by'), c('status', 'Status'), c('gatewayRefundRef', 'Refund ref'), c('completedAt', 'Completed', 'datetime')],
    rows: (req) => allRows(listRefunds, req),
  },
  products: {
    section: 'content',
    columns: [c('name', 'name'), c('stallName', 'Stall'), c('category', 'category'), c('price', 'price', 'money'), c('stock', 'stock', 'number'), c('dailyDefaultQty', 'Daily qty', 'number'), c('prepMinutes', 'Prep minutes', 'number'), c('veg', 'Vegetarian'), c('approvalStatus', 'Approval'), c('active', 'active')],
    rows: (req) => allRows(listProducts, req),
  },
  students: {
    section: 'users',
    columns: [c('name', 'name'), c('email', 'email'), c('phone', 'phone'), c('registerNo', 'registerNo'), c('signInMethod', 'signInMethod'), c('status', 'status'), c('lastLoginAt', 'Last login', 'datetime'), c('createdAt', 'Joined', 'datetime'), c('orders', 'orders', 'number'), c('totalSpent', 'totalSpent', 'money'), c('noShowCount', 'noShowCount', 'number'), c('active', 'active')],
    rows: (req) => {
      req.query.role = 'student';
      return allRows(listUsers, req);
    },
  },
  vendors: {
    section: 'vendors',
    columns: [c('name', 'name'), c('email', 'email'), c('stallName', 'stallName'), c('canteenName', 'canteenName'), c('active', 'active')],
    rows: (req) => {
      req.query.role = 'vendor';
      return allRows(listUsers, req);
    },
  },
  audit_log: {
    section: 'settings',
    columns: [c('at', 'at', 'datetime'), c('actorName', 'actorName'), c('actorRole', 'actorRole'), c('action', 'action'), c('table', 'table'), c('recordId', 'recordId'), c('old', 'old'), c('new', 'new')],
    rows: (req) => allRows(listAudit, req),
  },
  settlements: {
    section: 'payments',
    columns: [c('periodDate', 'Business date', 'date'), c('dueDate', 'Due (T+2)', 'date'), c('stallName', 'stallName'), c('canteenName', 'canteenName'), c('orders', 'orders', 'number'), c('gross', 'gross', 'money'), c('commission', 'commission', 'money'), c('commissionGst', 'commissionGst', 'money'), c('gst', 'gst', 'money'), c('refunds', 'refunds', 'money'), c('adjustments', 'adjustments', 'money'), c('netPayout', 'netPayout', 'money'), c('status', 'status'), c('bankRef', 'bankRef'), c('paidAt', 'paidAt', 'datetime')],
    rows: (req) => allRows(listSettlements, req),
  },
  sales_daily: {
    section: 'payments',
    columns: [c('period', 'Period'), c('grossSales', 'Gross', 'money'), c('refunds', 'Refunds', 'money'), c('netSales', 'Net', 'money'), c('gst', 'GST', 'money'), c('convenienceFees', 'Convenience fees', 'money'), c('paidOrders', 'Orders', 'number'), c('bills', 'Bills', 'number'), c('averageOrderValue', 'AOV', 'money')],
    rows: async (req, p) => (await salesReport(filters(req, p))).rows,
  },
  stall_settlement: {
    section: 'payments',
    columns: [c('stall', 'Stall'), c('collectedBills', 'Collected bills', 'number'), c('billTotal', 'Bill total', 'money'), c('gst', 'GST', 'money'), c('commission', 'Commission', 'money'), c('commissionGst', 'GST on commission', 'money'), c('refundsCharged', 'Refunds charged', 'money'), c('netPayable', 'Net payable', 'money')],
    rows: async (req, p) => (await settlementReport(filters(req, p))).rows,
  },
  canteen_revenue: {
    section: 'payments',
    columns: [c('period', 'Period'), c('canteen', 'Canteen'), c('orders', 'Orders', 'number'), c('gmv', 'GMV', 'money'), c('convenienceFees', 'Convenience fees', 'money'), c('commission', 'Vendor commission', 'money'), c('brunchyEarnings', 'Brunchy earnings', 'money'), c('averageOrderValue', 'AOV', 'money')],
    rows: async (req, p) => (await canteensReport(filters(req, p))).rows,
  },
  /** Zoho Books sales import: one line per item of each paid bill (the bill is the invoice). */
  zoho_books: {
    section: 'payments',
    columns: [c('invoiceDate', 'Invoice Date', 'date'), c('invoiceNumber', 'Invoice Number'), c('customerName', 'Customer Name'), c('itemName', 'Item Name'), c('quantity', 'Quantity', 'number'), c('itemPrice', 'Item Price', 'money'), c('taxPct', 'Item Tax %', 'number'), c('itemTotal', 'Item Total', 'money'), c('branch', 'Branch Name'), c('paymentMode', 'Payment Mode'), c('referenceNumber', 'Reference Number')],
    rows: async (req, p) => {
      const f = filters(req, p);
      const { where, params } = billScope(f);
      const list = await rows(
        pool,
        `SELECT so.bill_date, so.bill_no, u.name AS customer, oi.product_name, oi.quantity, oi.price, oi.gst_rate, c.canteen_name,
                (SELECT pm.gateway_payment_ref FROM payments pm WHERE pm.order_id = so.order_id AND pm.payment_status = 'success' ORDER BY pm.payment_id LIMIT 1) AS ref
           FROM order_items oi JOIN stall_orders so ON so.stall_order_id = oi.stall_order_id JOIN orders o ON o.order_id = so.order_id
           JOIN users u ON u.user_id = o.user_id JOIN canteens c ON c.canteen_id = so.canteen_id
          WHERE oi.item_status = 'active' AND oi.quantity > 0 AND ${PAID_BILL} AND ${LIVE_BILL} AND ${where}
          ORDER BY so.bill_date, so.stall_order_id, oi.item_id`,
        params,
      );
      return list.map((r) => ({
        invoiceDate: new Date(r.bill_date).toISOString().slice(0, 10),
        invoiceNumber: r.bill_no,
        customerName: r.customer,
        itemName: r.product_name,
        quantity: n(r.quantity),
        itemPrice: n(r.price),
        taxPct: n(r.gst_rate),
        itemTotal: r2(n(r.price) * n(r.quantity)),
        branch: r.canteen_name,
        paymentMode: 'UPI',
        referenceNumber: r.ref ?? '',
      }));
    },
  },
};

const istStamp = (iso: string) => new Date(Date.parse(iso) + 330 * 60_000).toISOString().replace('T', ' ').slice(0, 19);

/** Same rules as admin_web src/lib/csv.ts: IST "YYYY-MM-DD HH:mm:ss", money 2 decimals, rates ×100. */
function csvCell(v: unknown, type: Col['type']): string {
  if (v == null || v === '') return '';
  let s: string;
  switch (type) {
    case 'money': s = Number(v).toFixed(2); break;
    case 'pct': s = (Number(v) * 100).toFixed(1); break;
    case 'datetime': s = istStamp(String(v)); break;
    case 'duration': s = String(Math.round(Number(v))); break;
    default: s = typeof v === 'object' ? JSON.stringify(v) : String(v);
  }
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

reportsRouter.get('/admin/exports/:dataset', async (req, res) => {
  const p = panelOf(req);
  const ds = DATASETS[req.params.dataset];
  if (!ds) throw notFound('not_found', 'No such export');
  if (!can(p, ds.section) && !(req.params.dataset === 'audit_log')) throw forbidden('forbidden', 'Your account cannot export this.');
  const from = q(req, 'from');
  const to = q(req, 'to');
  if (from && to && (Date.parse(to) - Date.parse(from)) / 86_400_000 > 366) throw invalid('Exports cover at most 366 days.');
  const data = await ds.rows(req, p);
  // Contact data stays masked without contact access (the list functions already mask students).
  if (!p.contactAccess && req.params.dataset === 'students') for (const r of data) (r.email = maskEmail(r.email)), (r.phone = maskPhone(r.phone));
  await audit(pool, { id: p.id, role: p.role }, 'export', req.params.dataset, 0, undefined, { query: req.query, rows: data.length });
  if (q(req, 'format') === 'json') {
    res.json({ columns: ds.columns, rows: data });
    return;
  }
  const lines = [ds.columns.map((x) => csvCell(x.label, 'text')).join(','), ...data.map((r) => ds.columns.map((x) => csvCell(r[x.key], x.type)).join(','))];
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="brunchy_${req.params.dataset}_${from ?? 'all'}_${to ?? 'all'}.csv"`);
  res.send(`﻿${lines.join('\r\n')}\r\n`);
});
