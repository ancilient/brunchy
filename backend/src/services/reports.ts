import { pool, rows } from '../db/pool.js';
import type { AuthUser } from '../middleware/auth.js';
import { forbidden } from '../errors.js';

/** Bills that count as sales on the dashboard: paid and taken on by the stall (not new, cancelled or refunded). */
const COUNTED = "('accepted','preparing','ready','collected')";
const IST = "'+05:30'";
const istTime = (col: string) => `CONVERT_TZ(${col}, '+00:00', ${IST})`;

export type DashboardPeriod = 'today' | 'this_week' | 'this_month';

const DAY_MS = 24 * 60 * 60 * 1000;
const ymd = (d: Date) => d.toISOString().slice(0, 10);
const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/** Today's date in India, as a UTC-midnight Date (so date arithmetic is plain day steps). */
function istToday(now = new Date()) {
  const ist = new Date(now.getTime() + 5.5 * 60 * 60 * 1000);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()));
}

/** [from, to] (inclusive IST dates) for the period and for the same span just before it. */
export function periodRanges(period: DashboardPeriod, now = new Date()) {
  const today = istToday(now);
  if (period === 'today') {
    const y = new Date(today.getTime() - DAY_MS);
    return { from: today, to: today, prevFrom: y, prevTo: y };
  }
  if (period === 'this_week') {
    const weekday = (today.getUTCDay() + 6) % 7; // Mon = 0
    const from = new Date(today.getTime() - weekday * DAY_MS);
    return {
      from,
      to: today,
      prevFrom: new Date(from.getTime() - 7 * DAY_MS),
      prevTo: new Date(today.getTime() - 7 * DAY_MS),
    };
  }
  const from = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), 1));
  const prevFrom = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth() - 1, 1));
  const prevMonthDays = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), 0)).getUTCDate();
  const prevTo = new Date(Date.UTC(prevFrom.getUTCFullYear(), prevFrom.getUTCMonth(), Math.min(today.getUTCDate(), prevMonthDays)));
  return { from, to: today, prevFrom, prevTo };
}

/** Percent change, plus the "new" (was 0) and "none" (both 0) flags the app shows instead of a number. */
function change(current: number, previous: number) {
  if (previous === 0) return { pct: 0, isNew: current > 0, isNone: current === 0 };
  return { pct: Math.round(((current - previous) / previous) * 1000) / 10, isNew: false, isNone: false };
}

async function totals(stallId: number, from: Date, to: Date) {
  const [t] = await rows<{ revenue: number | null; orders: number }>(
    pool,
    `SELECT SUM(total) AS revenue, COUNT(*) AS orders FROM stall_orders
      WHERE stall_id = ? AND bill_date BETWEEN ? AND ? AND status IN ${COUNTED}`,
    [stallId, ymd(from), ymd(to)],
  );
  const revenue = Number(t?.revenue ?? 0);
  const orders = Number(t?.orders ?? 0);
  return { revenue, orders, aov: orders ? Math.round((revenue / orders) * 100) / 100 : 0 };
}

/**
 * The vendor dashboard (vendor app: DashboardStats.fromJson). All figures come from real bills of the vendor's stall;
 * money is the stall's item total (the platform fee is not the stall's income).
 */
export async function getVendorDashboard(user: AuthUser, period: DashboardPeriod) {
  if (!user.stallId) throw forbidden('NO_STALL', 'This account is not linked to a stall');
  const stallId = user.stallId;
  const { from, to, prevFrom, prevTo } = periodRanges(period);
  const range = [stallId, ymd(from), ymd(to)];
  const current = await totals(stallId, from, to);
  const previous = await totals(stallId, prevFrom, prevTo);

  // Chart buckets: hours for today, weekdays for this week, days of the month for this month.
  const bucketSql =
    period === 'today' ? `HOUR(${istTime('created_at')})` : period === 'this_week' ? 'WEEKDAY(bill_date)' : 'DAY(bill_date)';
  const bucketRows = await rows<{ b: number; revenue: number; orders: number }>(
    pool,
    `SELECT ${bucketSql} AS b, SUM(total) AS revenue, COUNT(*) AS orders FROM stall_orders
      WHERE stall_id = ? AND bill_date BETWEEN ? AND ? AND status IN ${COUNTED} GROUP BY b`,
    range,
  );
  const byBucket = new Map(bucketRows.map((r) => [Number(r.b), r]));
  const daysInMonth = new Date(Date.UTC(to.getUTCFullYear(), to.getUTCMonth() + 1, 0)).getUTCDate();
  const buckets =
    period === 'today'
      ? Array.from({ length: 24 }, (_, h) => ({ key: h, label: `${h}:00` }))
      : period === 'this_week'
        ? WEEKDAYS.map((label, i) => ({ key: i, label }))
        : Array.from({ length: daysInMonth }, (_, i) => ({ key: i + 1, label: String(i + 1) }));
  const chartData = buckets.map(({ key, label }) => {
    const r = byBucket.get(key);
    return { label, revenue: Number(r?.revenue ?? 0), orders: Number(r?.orders ?? 0) };
  });

  // Items: best sellers, and the stall's slowest items (including ones that sold nothing).
  const sales = await rows<{ product_id: number; name: string; qty: number; order_count: number; revenue: number }>(
    pool,
    `SELECT oi.product_id, oi.product_name AS name, SUM(oi.quantity) AS qty, COUNT(DISTINCT so.stall_order_id) AS order_count,
            SUM(oi.price * oi.quantity) AS revenue
       FROM order_items oi JOIN stall_orders so ON so.stall_order_id = oi.stall_order_id
      WHERE so.stall_id = ? AND so.bill_date BETWEEN ? AND ? AND so.status IN ${COUNTED} AND oi.item_status = 'active'
      GROUP BY oi.product_id, oi.product_name`,
    range,
  );
  const item = (s: { name: string; qty: number; order_count: number; revenue: number }) => ({
    name: s.name,
    qty: Number(s.qty),
    orderCount: Number(s.order_count),
    revenue: Number(s.revenue),
  });
  const topItems = [...sales].sort((a, b) => Number(b.qty) - Number(a.qty)).slice(0, 5).map(item);
  const products = await rows<{ product_id: number; product_name: string }>(
    pool,
    "SELECT product_id, product_name FROM products WHERE stall_id = ? AND is_active = TRUE AND approval_status = 'published'",
    [stallId],
  );
  const soldBy = new Map(sales.map((s) => [Number(s.product_id), s]));
  const slowItems = products
    .map((p) => soldBy.get(p.product_id) ?? { name: p.product_name, qty: 0, order_count: 0, revenue: 0 })
    .sort((a, b) => Number(a.qty) - Number(b.qty) || a.name.localeCompare(b.name))
    .slice(0, 3)
    .map(item);

  const hourRows = await rows<{ h: number; n: number }>(
    pool,
    `SELECT HOUR(${istTime('created_at')}) AS h, COUNT(*) AS n FROM stall_orders
      WHERE stall_id = ? AND bill_date BETWEEN ? AND ? AND status IN ${COUNTED} GROUP BY h`,
    range,
  );
  const hourMap = new Map(hourRows.map((r) => [Number(r.h), Number(r.n)]));
  const peakHours = Array.from({ length: 24 }, (_, hour) => ({ hour, count: hourMap.get(hour) ?? 0 }));

  const [split] = await rows<{ collected: number; cancelled: number; accepted: number }>(
    pool,
    `SELECT SUM(status = 'collected') AS collected,
            SUM(status IN ('cancelled','refunded','rejected')) AS cancelled,
            SUM(status IN ('new','accepted','preparing','ready')) AS accepted
       FROM stall_orders WHERE stall_id = ? AND bill_date BETWEEN ? AND ? AND bill_no IS NOT NULL`,
    range,
  );
  const [prep] = await rows<{ minutes: number | null }>(
    pool,
    `SELECT AVG(TIMESTAMPDIFF(SECOND, accepted_at, ready_at)) / 60 AS minutes FROM stall_orders
      WHERE stall_id = ? AND bill_date BETWEEN ? AND ? AND accepted_at IS NOT NULL AND ready_at IS NOT NULL`,
    range,
  );

  const rev = change(current.revenue, previous.revenue);
  const ord = change(current.orders, previous.orders);
  const aov = change(current.aov, previous.aov);
  return {
    period,
    from: ymd(from),
    to: ymd(to),
    totalRevenue: current.revenue,
    orderCount: current.orders,
    avgOrderValue: current.aov,
    revenueChangePct: rev.pct,
    orderCountChangePct: Math.round(ord.pct),
    aovChangePct: aov.pct,
    revenueChangeIsNew: rev.isNew,
    revenueChangeIsNone: rev.isNone,
    orderChangeIsNew: ord.isNew,
    orderChangeIsNone: ord.isNone,
    aovChangeIsNew: aov.isNew,
    aovChangeIsNone: aov.isNone,
    chartData,
    topItems,
    slowItems,
    peakHours,
    statusSplit: {
      collected: Number(split?.collected ?? 0),
      cancelled: Number(split?.cancelled ?? 0),
      accepted: Number(split?.accepted ?? 0),
    },
    avgPrepMinutes: prep?.minutes == null ? 0 : Math.round(Number(prep.minutes) * 10) / 10,
  };
}
