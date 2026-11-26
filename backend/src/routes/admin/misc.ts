import { type Request, type Response, Router } from 'express';
import { IST_TODAY, one, pool, rows, withTx } from '../../db/pool.js';
import { forbidden } from '../../errors.js';
import { type Panel, can, need, panelOf, scopeCanteen } from '../../services/access.js';
import { audit } from '../../services/audit.js';
import { getSettings, saveSettings, settingsPatch } from '../../services/settings.js';
import { effectiveStallStatus, iso, toPaise, toRupees } from '../../util.js';
import { addDays, istDay, paging, q, sortSql, zDate } from './util.js';

export const miscRouter = Router();

// ---------------------------------------------------------------- settings (PDF 11)

/** Content and ads accounts read the settings too (minimum order, ad fallback). */
miscRouter.get('/admin/settings', need(['settings', 'content', 'ads']), async (_req, res) => {
  res.json(await getSettings());
});

miscRouter.patch('/admin/settings', need('settings', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const patch = settingsPatch.parse(req.body);
  const after = await withTx(async (conn) => {
    const { before, after } = await saveSettings(conn, patch, p.id);
    const old = Object.fromEntries(Object.keys(patch).map((k) => [k, before[k as keyof typeof before]]));
    await audit(conn, { id: p.id, role: p.role }, 'admin_settings_update', 'settings', 1, old, patch);
    return after;
  });
  res.json(after);
});

// ---------------------------------------------------------------- audit log

const AUDIT_SORT: Record<string, string> = { at: 'a.created_at', action: 'a.action', table: 'a.table_name', actorName: 'u.name' };

/** Managers see their canteen's records only (their own and their vendors' actions, and its stalls, items and bills). */
function auditScope(p: Panel) {
  if (p.role !== 'manager') return { sql: '', params: [] as unknown[] };
  const c = p.canteenId ?? -1;
  return {
    sql: `AND (a.actor_user_id IN (SELECT user_id FROM users WHERE canteen_id = ? AND role IN ('manager','vendor'))
           OR (a.table_name = 'canteens' AND a.record_id = ?)
           OR (a.table_name = 'stalls' AND a.record_id IN (SELECT stall_id FROM stalls WHERE canteen_id = ?))
           OR (a.table_name = 'products' AND a.record_id IN (SELECT p.product_id FROM products p JOIN stalls s ON s.stall_id = p.stall_id WHERE s.canteen_id = ?))
           OR (a.table_name = 'stall_orders' AND a.record_id IN (SELECT stall_order_id FROM stall_orders WHERE canteen_id = ?)))`,
    params: [c, c, c, c, c],
  };
}

miscRouter.get('/admin/audit', (req, res) => listAudit(req, res));

export async function listAudit(req: Request, res: Response) {
  const p = panelOf(req);
  const { page, pageSize, limit, offset } = paging(req);
  const where: string[] = ['1 = 1'];
  const params: unknown[] = [];
  const from = q(req, 'from') ? zDate.parse(q(req, 'from')) : undefined;
  const to = q(req, 'to') ? zDate.parse(q(req, 'to')) : undefined;
  if (from) (where.push("DATE(CONVERT_TZ(a.created_at, '+00:00', '+05:30')) >= ?"), params.push(from));
  if (to) (where.push("DATE(CONVERT_TZ(a.created_at, '+00:00', '+05:30')) <= ?"), params.push(to));
  if (q(req, 'actor')) (where.push('u.name LIKE ?'), params.push(`%${q(req, 'actor')}%`));
  if (q(req, 'actorId')) (where.push('a.actor_user_id = ?'), params.push(Number(q(req, 'actorId'))));
  if (q(req, 'action')) (where.push('a.action = ?'), params.push(q(req, 'action')));
  if (q(req, 'table')) (where.push('a.table_name = ?'), params.push(q(req, 'table')));
  if (q(req, 'recordId')) (where.push('a.record_id = ?'), params.push(Number(q(req, 'recordId'))));
  const scope = auditScope(p);
  const w = `${where.join(' AND ')} ${scope.sql}`;
  const all = [...params, ...scope.params];
  const total = (await one<{ n: number }>(pool, `SELECT COUNT(*) AS n FROM audit_log a LEFT JOIN users u ON u.user_id = a.actor_user_id WHERE ${w}`, all))!.n;
  const list = await rows(
    pool,
    `SELECT a.*, u.name AS actor_name, u.role AS actor_role FROM audit_log a LEFT JOIN users u ON u.user_id = a.actor_user_id
      WHERE ${w} ORDER BY ${sortSql(req, AUDIT_SORT, 'a.created_at DESC')}, a.audit_id DESC LIMIT ? OFFSET ?`,
    [...all, limit, offset],
  );
  const json = (v: unknown) => (typeof v === 'string' ? JSON.parse(v) : v);
  res.json({
    items: list.map((a) => ({
      id: Number(a.audit_id),
      at: iso(a.created_at),
      actorId: a.actor_user_id,
      action: a.action,
      table: a.table_name,
      recordId: a.record_id,
      old: json(a.old_value),
      new: json(a.new_value),
      actorName: a.actor_name ?? (a.role === 'system' ? 'System' : 'Unknown'),
      actorRole: a.actor_role ?? null,
    })),
    page,
    pageSize,
    total: Number(total),
  });
}

// ---------------------------------------------------------------- overview (PDF 2)

const PAID_DAY = "DATE(CONVERT_TZ(o.paid_at, '+00:00', '+05:30'))";
const OPEN = ['new', 'accepted', 'preparing', 'ready'];

async function kpisFor(day: string, canteenId: number | null) {
  const c = canteenId ? 'AND o.canteen_id = ?' : '';
  const cp = canteenId ? [canteenId] : [];
  const orders = (await one(
    pool,
    `SELECT COUNT(*) AS n, COALESCE(SUM(o.total), 0) AS gross, COUNT(DISTINCT o.user_id) AS students,
            COALESCE(SUM(o.convenience_fee + o.additional_fee), 0) AS fees
       FROM orders o WHERE o.status = 'paid' AND ${PAID_DAY} = ? ${c}`,
    [day, ...cp],
  ))!;
  const bills = (await one(
    pool,
    `SELECT COUNT(*) AS n, SUM(so.status = 'collected') AS collected, SUM(so.status = 'ready') AS ready
       FROM stall_orders so JOIN orders o ON o.order_id = so.order_id WHERE so.bill_date = ? ${c}`,
    [day, ...cp],
  ))!;
  const refunds = (await one(
    pool,
    `SELECT COUNT(*) AS n, COALESCE(SUM(r.amount), 0) AS amount FROM refunds r JOIN orders o ON o.order_id = r.order_id
      WHERE DATE(CONVERT_TZ(r.created_at, '+00:00', '+05:30')) = ? AND r.status NOT IN ('rejected') ${c}`,
    [day, ...cp],
  ))!;
  const paid = Number(orders.n);
  const collected = Number(bills.collected ?? 0);
  const ready = Number(bills.ready ?? 0);
  return {
    grossSales: Number(orders.gross),
    paidOrders: paid,
    bills: Number(bills.n),
    averageOrderValue: paid ? toRupees(Math.round(toPaise(Number(orders.gross)) / paid)) : 0,
    collectedPct: collected + ready ? collected / (collected + ready) : 0,
    refundsCount: Number(refunds.n),
    refundsAmount: Number(refunds.amount),
    activeStudents: Number(orders.students),
    // Commission is not charged yet, so Brunchy earns the platform and convenience fees.
    brunchyEarnings: Number(orders.fees),
  };
}

const MONEY = ['grossSales', 'averageOrderValue', 'refundsAmount', 'brunchyEarnings'] as const;

miscRouter.get('/admin/overview', async (req, res) => {
  const p = panelOf(req);
  if (!can(p, 'orders') && !can(p, 'payments')) throw forbidden('forbidden', 'Your account cannot see the dashboard.');
  const day = q(req, 'date') ? zDate.parse(q(req, 'date')) : istDay();
  const canteenId = scopeCanteen(p, req.query.canteenId);
  const money = can(p, 'payments');
  const c = canteenId ? 'AND so.canteen_id = ?' : '';
  const cp = canteenId ? [canteenId] : [];
  const oc = canteenId ? 'AND o.canteen_id = ?' : '';

  const [today, lastWeek] = await Promise.all([kpisFor(day, canteenId), kpisFor(addDays(day, -7), canteenId)]);
  const kpis = Object.fromEntries(
    Object.keys(today).map((k) => {
      const key = k as keyof typeof today;
      const hide = !money && (MONEY as readonly string[]).includes(k);
      return [k, hide ? null : { today: today[key], lastWeek: lastWeek[key] }];
    }),
  );

  const statusCounts = await rows<{ status: string; n: number }>(
    pool,
    `SELECT so.status, COUNT(*) AS n FROM stall_orders so WHERE so.bill_date = ? ${c} GROUP BY so.status`,
    [day, ...cp],
  );
  const count = (s: string) => Number(statusCounts.find((r) => r.status === s)?.n ?? 0);
  const liveOpen = await rows<{ status: string; n: number }>(
    pool,
    `SELECT so.status, COUNT(*) AS n FROM stall_orders so WHERE so.status IN (?) AND so.bill_date = ${IST_TODAY} ${c} GROUP BY so.status`,
    [OPEN, ...cp],
  );
  const live = (s: string) => Number(liveOpen.find((r) => r.status === s)?.n ?? 0);

  const stalls = await rows(
    pool,
    `SELECT s.*, (SELECT COUNT(*) FROM stall_orders so WHERE so.stall_id = s.stall_id AND so.status IN (?) AND so.bill_date = ${IST_TODAY}) AS queue,
            (SELECT MIN(so.created_at) FROM stall_orders so WHERE so.stall_id = s.stall_id AND so.status = 'new' AND so.bill_date = ${IST_TODAY}) AS oldest
       FROM stalls s WHERE s.is_active = TRUE ${canteenId ? 'AND s.canteen_id = ?' : ''} ORDER BY s.canteen_id, s.stall_name`,
    [OPEN, ...cp],
  );

  const settings = await getSettings();
  const alerts: { id: string; kind: string; message: string; at: string }[] = [];
  for (const s of stalls) {
    if (s.oldest && Date.now() - new Date(s.oldest).getTime() > settings.alertNewBillMinutes * 60_000) {
      alerts.push({ id: `new-${s.stall_id}`, kind: 'bill_new_stuck', message: `${s.stall_name}: an order has waited over ${settings.alertNewBillMinutes} min to be accepted.`, at: iso(s.oldest)! });
    }
    if (effectiveStallStatus(s as never) === 'paused' && s.paused_at && Date.now() - new Date(s.paused_at).getTime() > settings.alertPausedStallMinutes * 60_000) {
      alerts.push({ id: `paused-${s.stall_id}`, kind: 'stall_paused_long', message: `${s.stall_name} has been paused for over ${settings.alertPausedStallMinutes} min.`, at: iso(s.paused_at)! });
    }
  }

  const hourly = await rows<{ day: string; h: number; gmv: number; n: number }>(
    pool,
    `SELECT DATE_FORMAT(${PAID_DAY}, '%Y-%m-%d') AS day, HOUR(CONVERT_TZ(o.paid_at, '+00:00', '+05:30')) AS h, SUM(o.total) AS gmv, COUNT(*) AS n
       FROM orders o WHERE o.status = 'paid' AND ${PAID_DAY} IN (?, ?) ${oc} GROUP BY day, h`,
    [day, addDays(day, -7), ...cp],
  );
  const hours = Array.from({ length: 16 }, (_, i) => i + 7); // 7 AM to 10 PM
  const at = (d: string, h: number) => hourly.find((r) => r.day === d && Number(r.h) === h);

  const perStall = await rows<{ stall_name: string; n: number }>(
    pool,
    `SELECT s.stall_name, COUNT(so.stall_order_id) AS n FROM stalls s
       LEFT JOIN stall_orders so ON so.stall_id = s.stall_id AND so.bill_date = ?
      WHERE s.is_active = TRUE ${canteenId ? 'AND s.canteen_id = ?' : ''} GROUP BY s.stall_id, s.stall_name ORDER BY n DESC`,
    [day, ...cp],
  );
  const daily = await rows<{ d: string; n: number; gmv: number }>(
    pool,
    `SELECT DATE_FORMAT(${PAID_DAY}, '%Y-%m-%d') AS d, COUNT(*) AS n, SUM(o.total) AS gmv FROM orders o
      WHERE o.status = 'paid' AND ${PAID_DAY} BETWEEN ? AND ? ${oc} GROUP BY d`,
    [addDays(day, -55), day, ...cp],
  );
  const dailyTrend = Array.from({ length: 14 }, (_, i) => addDays(day, i - 13)).map((d) => {
    const r = daily.find((x) => x.d === d);
    return { day: d, orders: Number(r?.n ?? 0), gmv: money ? Number(r?.gmv ?? 0) : 0 };
  });
  const monday = (d: string) => addDays(d, -((new Date(`${d}T00:00:00Z`).getUTCDay() + 6) % 7));
  const weeklyTrend = Array.from({ length: 8 }, (_, i) => addDays(monday(day), (i - 7) * 7)).map((w) => {
    const days = daily.filter((x) => monday(x.d) === w);
    return { week: w, orders: days.reduce((s, x) => s + Number(x.n), 0), gmv: money ? days.reduce((s, x) => s + Number(x.gmv), 0) : 0 };
  });
  const topItems = await rows<{ item: string; qty: number; revenue: number }>(
    pool,
    `SELECT oi.product_name AS item, SUM(oi.quantity) AS qty, SUM(oi.quantity * oi.price) AS revenue
       FROM order_items oi JOIN stall_orders so ON so.stall_order_id = oi.stall_order_id
      WHERE oi.item_status = 'active' AND so.status NOT IN ('awaiting_payment','expired','cancelled','rejected','refunded')
        AND so.bill_date BETWEEN ? AND ? ${c}
      GROUP BY oi.product_name ORDER BY revenue DESC LIMIT 10`,
    [addDays(day, -6), day, ...cp],
  );
  const canteens = await rows(
    pool,
    `SELECT c.*,
            (SELECT COUNT(*) FROM orders o WHERE o.canteen_id = c.canteen_id AND o.status = 'paid' AND ${PAID_DAY} = ?) AS orders,
            (SELECT COALESCE(SUM(o.total), 0) FROM orders o WHERE o.canteen_id = c.canteen_id AND o.status = 'paid' AND ${PAID_DAY} = ?) AS gmv,
            (SELECT COALESCE(SUM(o.convenience_fee + o.additional_fee), 0) FROM orders o WHERE o.canteen_id = c.canteen_id AND o.status = 'paid' AND ${PAID_DAY} = ?) AS earnings,
            (SELECT COUNT(*) FROM stall_orders so WHERE so.canteen_id = c.canteen_id AND so.status IN (?) AND so.bill_date = ${IST_TODAY}) AS live,
            (SELECT COUNT(*) FROM stalls s WHERE s.canteen_id = c.canteen_id AND s.is_active = TRUE) AS stalls,
            (SELECT COUNT(*) FROM stalls s WHERE s.canteen_id = c.canteen_id AND s.is_active = TRUE AND s.status = 'open') AS stalls_open,
            (SELECT COUNT(*) FROM orders o WHERE o.canteen_id = c.canteen_id AND o.status = 'paid' AND ${PAID_DAY} BETWEEN ? AND ?) AS week_orders,
            (SELECT COALESCE(SUM(o.total), 0) FROM orders o WHERE o.canteen_id = c.canteen_id AND o.status = 'paid' AND ${PAID_DAY} BETWEEN ? AND ?) AS week_gmv
       FROM canteens c WHERE c.is_active = TRUE ${canteenId ? 'AND c.canteen_id = ?' : ''} ORDER BY c.canteen_name`,
    [day, day, day, OPEN, addDays(day, -6), day, addDays(day, -6), day, ...cp],
  );

  res.json({
    date: day,
    canteenId,
    kpis,
    activeUsers: today.activeStudents,
    live: {
      billsByStatus: { new: live('new'), accepted: live('accepted'), preparing: live('preparing'), ready: live('ready'), collected: count('collected'), cancelled: count('cancelled') + count('rejected') },
      stalls: stalls.map((s) => ({
        id: s.stall_id,
        name: s.stall_name,
        status: effectiveStallStatus(s as never),
        pausedUntil: iso(s.paused_until),
        queue: Number(s.queue),
        oldestWaitingSec: s.oldest ? Math.round((Date.now() - new Date(s.oldest).getTime()) / 1000) : null,
      })),
    },
    alerts,
    salesByHour: hours.map((h) => ({ hour: h, today: money ? Number(at(day, h)?.gmv ?? 0) : 0, lastWeek: money ? Number(at(addDays(day, -7), h)?.gmv ?? 0) : 0 })),
    billsPerStall: perStall.map((s) => ({ stall: s.stall_name, bills: Number(s.n) })),
    ordersByHour: hours.map((h) => ({ hour: h, orders: Number(at(day, h)?.n ?? 0) })),
    dailyTrend,
    weeklyTrend,
    topItems: topItems.map((t) => ({ item: t.item, quantity: Number(t.qty), revenue: money ? Number(t.revenue) : 0 })),
    topCanteens: canteens
      .map((x) => ({ canteen: x.canteen_name, orders: Number(x.week_orders), gmv: money ? Number(x.week_gmv) : 0 }))
      .sort((a, b) => b.orders - a.orders),
    canteenSnapshot: canteens.map((x) => ({
      id: x.canteen_id,
      name: x.canteen_name,
      status: x.status,
      hidden: Boolean(x.hidden),
      orders: Number(x.orders),
      gmv: money ? Number(x.gmv) : 0,
      earnings: money ? Number(x.earnings) : 0,
      live: Number(x.live),
      stallsOpen: Number(x.stalls_open),
      stalls: Number(x.stalls),
    })),
  });
});

