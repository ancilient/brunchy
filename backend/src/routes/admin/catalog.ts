import { randomBytes } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { type Request, type Response, Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { config } from '../../config.js';
import { IST_TODAY, exec, isDuplicateKey, one, pool, rows, withTx } from '../../db/pool.js';
import { AppError, conflict, forbidden, notFound } from '../../errors.js';
import { publishBills } from '../../realtime.js';
import { adminOnly, assertCanteen, can, invalid, need, panelOf, parseJson, scopeCanteen } from '../../services/access.js';
import { audit } from '../../services/audit.js';
import { rejectNewBillsForEmergency } from '../../services/bills.js';
import { bustMenuCache } from '../../services/menu.js';
import { effectiveStallStatus, iso } from '../../util.js';
import { idOf, paging, q, sortSql, zDate, zId, zTime } from './util.js';

export const catalogRouter = Router();

const actor = (p: { id: number; role: string }) => ({ id: p.id, role: p.role });
const hhmm = (t: string) => String(t).slice(0, 5);

// ---------------------------------------------------------------- serializers (admin_web src/lib/types.ts)

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;

export const toCanteen = (c: Row) => ({
  id: c.canteen_id,
  name: c.canteen_name,
  openingTime: hhmm(c.opening_time),
  closingTime: hhmm(c.closing_time),
  lastOrderMinutes: c.last_order_minutes,
  status: c.status,
  requiresApproval: Boolean(c.requires_approval),
  location: c.location ?? '',
  collegeId: c.college_id,
  photoUrl: c.photo_url,
  avgPrepMinutes: c.avg_prep_minutes,
  minOrder: Number(c.min_order),
  hidden: Boolean(c.hidden),
});

export const toStall = (s: Row) => ({
  id: s.stall_id,
  canteenId: s.canteen_id,
  name: s.stall_name,
  billPrefix: s.bill_prefix,
  gstRate: Number(s.gst_rate),
  category: s.category ?? '',
  colour: s.accent_color ?? '#c2410c',
  icon: s.icon_name ?? 'store',
  avgPrepMinutes: s.avg_prep_minutes,
  status: effectiveStallStatus(s as never),
  pausedUntil: effectiveStallStatus(s as never) === 'paused' ? iso(s.paused_until) : null,
  pausedAt: effectiveStallStatus(s as never) === 'paused' ? iso(s.paused_at) : null,
  photoUrl: s.photo_url,
});

const PENDING_KEYS = ['name', 'description', 'category', 'price', 'veg', 'tags', 'imageUrl'] as const;

export const toProduct = (p: Row) => ({
  id: p.product_id,
  stallId: p.stall_id,
  name: p.product_name,
  category: p.category ?? '',
  price: Number(p.price),
  veg: Boolean(p.is_veg),
  stock: p.stock_quantity,
  dailyDefaultQty: p.daily_default_qty,
  prepMinutes: p.prep_minutes ?? 0,
  imageUrl: p.image_url,
  description: p.description ?? '',
  tags: parseJson<string[]>(p.tags) ?? [],
  /** Sold out = no stock left today. */
  available: p.stock_quantity > 0,
  sortOrder: p.sort_order,
  approvalStatus: p.approval_status === 'draft' ? 'pending' : p.approval_status,
  active: Boolean(p.is_active),
  approvedBy: p.approved_by,
  approvedAt: iso(p.approved_at),
  rejectionReason: p.rejection_reason,
  pendingChange: parseJson(p.pending_change),
  stallName: p.stall_name,
  canteenId: p.canteen_id,
});

const PRODUCT_SELECT = `SELECT p.*, s.stall_name, s.canteen_id FROM products p JOIN stalls s ON s.stall_id = p.stall_id`;

async function loadProduct(id: number) {
  const p = await one(pool, `${PRODUCT_SELECT} WHERE p.product_id = ? AND p.deleted_at IS NULL`, [id]);
  if (!p) throw notFound('not_found', 'Item not found');
  return p;
}

// ---------------------------------------------------------------- canteens (PDF 7)

catalogRouter.get('/admin/canteens', async (req, res) => {
  const p = panelOf(req);
  const list = await rows(
    pool,
    `SELECT * FROM canteens WHERE is_active = TRUE ${p.role === 'manager' ? 'AND canteen_id = ?' : ''} ORDER BY canteen_name`,
    p.role === 'manager' ? [p.canteenId] : [],
  );
  res.json({ items: list.map(toCanteen), page: 1, pageSize: list.length, total: list.length });
});

const canteenFields = z.object({
  name: z.string().trim().min(2).max(100),
  collegeId: zId,
  location: z.string().trim().max(150).default(''),
  photoUrl: z.string().url().nullable().optional(),
  openingTime: zTime,
  closingTime: zTime,
  lastOrderMinutes: z.number().int().min(0).max(240).default(10),
  avgPrepMinutes: z.number().int().min(1).max(120).default(8),
  minOrder: z.number().min(0).max(100000).default(0),
  status: z.enum(['open', 'closed']).default('open'),
  requiresApproval: z.boolean().default(true),
  hidden: z.boolean().default(false),
});

function canteenColumns(b: Partial<z.infer<typeof canteenFields>>) {
  const map: Record<string, [string, unknown]> = {
    name: ['canteen_name', b.name],
    collegeId: ['college_id', b.collegeId],
    location: ['location', b.location],
    photoUrl: ['photo_url', b.photoUrl],
    openingTime: ['opening_time', b.openingTime],
    closingTime: ['closing_time', b.closingTime],
    lastOrderMinutes: ['last_order_minutes', b.lastOrderMinutes],
    avgPrepMinutes: ['avg_prep_minutes', b.avgPrepMinutes],
    minOrder: ['min_order', b.minOrder],
    status: ['status', b.status],
    requiresApproval: ['requires_approval', b.requiresApproval],
    hidden: ['hidden', b.hidden],
  };
  return Object.entries(map).filter(([k]) => k in b && (b as Row)[k] !== undefined).map(([, v]) => v);
}

async function checkCollege(id: number | undefined) {
  if (id && !(await one(pool, 'SELECT college_id FROM colleges WHERE college_id = ?', [id]))) throw invalid('That college does not exist.');
}

catalogRouter.post('/admin/canteens', need('content', 'edit'), adminOnly, async (req, res) => {
  const b = canteenFields.parse(req.body);
  if (b.closingTime <= b.openingTime) throw invalid('Closing time must be after opening time.');
  await checkCollege(b.collegeId);
  const cols = canteenColumns(b);
  try {
    const id = await withTx(async (conn) => {
      const r = await exec(conn, `INSERT INTO canteens (${cols.map((c) => c[0]).join(', ')}) VALUES (${cols.map(() => '?').join(', ')})`, cols.map((c) => c[1]));
      await audit(conn, actor(panelOf(req)), 'admin_canteen_create', 'canteens', r.insertId, undefined, b);
      return r.insertId;
    });
    res.status(201).json(toCanteen((await one(pool, 'SELECT * FROM canteens WHERE canteen_id = ?', [id]))!));
  } catch (err) {
    if (isDuplicateKey(err)) throw conflict('exists', 'A canteen with this name already exists.');
    throw err;
  }
});

catalogRouter.patch('/admin/canteens/:id', need('content', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'canteen');
  const b = canteenFields.partial().parse(req.body);
  assertCanteen(p, id);
  // Managers only switch their own canteen on/off (the Open/Close button); everything else is for admins.
  if (p.role === 'manager' && Object.keys(b).some((k) => k !== 'status')) throw forbidden('forbidden', 'Only admins can edit canteen details.');
  await checkCollege(b.collegeId);
  const before = await one(pool, 'SELECT * FROM canteens WHERE canteen_id = ? AND is_active = TRUE', [id]);
  if (!before) throw notFound('not_found', 'Canteen not found');
  const open = b.openingTime ?? before.opening_time;
  const close = b.closingTime ?? before.closing_time;
  if (String(close) <= String(open)) throw invalid('Closing time must be after opening time.');
  const cols = canteenColumns(b);
  if (cols.length) {
    try {
      await withTx(async (conn) => {
        await exec(conn, `UPDATE canteens SET ${cols.map((c) => `${c[0]} = ?`).join(', ')} WHERE canteen_id = ?`, [...cols.map((c) => c[1]), id]);
        await audit(conn, actor(p), 'admin_canteen_update', 'canteens', id, toCanteen(before), b);
      });
    } catch (err) {
      if (isDuplicateKey(err)) throw conflict('exists', 'A canteen with this name already exists.');
      throw err;
    }
  }
  await bustMenuCache([id]);
  res.json(toCanteen((await one(pool, 'SELECT * FROM canteens WHERE canteen_id = ?', [id]))!));
});

catalogRouter.delete('/admin/canteens/:id', need('content', 'edit'), adminOnly, async (req, res) => {
  const id = idOf(req.params.id, 'canteen');
  await withTx(async (conn) => {
    const c = await one(conn, 'SELECT * FROM canteens WHERE canteen_id = ? FOR UPDATE', [id]);
    if (!c) throw notFound('not_found', 'Canteen not found');
    if (await one(conn, 'SELECT 1 FROM orders WHERE canteen_id = ? LIMIT 1', [id])) {
      throw conflict('has_history', 'This canteen has orders, so it cannot be deleted. Hide it instead.');
    }
    if (await one(conn, 'SELECT 1 FROM stalls WHERE canteen_id = ? LIMIT 1', [id])) {
      throw conflict('has_stalls', 'Remove the stalls of this canteen first, or hide it.');
    }
    await exec(conn, 'UPDATE users SET canteen_id = NULL WHERE canteen_id = ?', [id]);
    await exec(conn, 'DELETE FROM canteens WHERE canteen_id = ?', [id]);
    await audit(conn, actor(panelOf(req)), 'admin_canteen_delete', 'canteens', id, toCanteen(c));
  });
  res.status(204).end();
});

// ---------------------------------------------------------------- colleges

catalogRouter.get('/admin/colleges', async (_req, res) => {
  const list = await rows(pool, 'SELECT college_id, college_name FROM colleges ORDER BY college_name');
  res.json({ items: list.map((c) => ({ id: c.college_id, name: c.college_name })), page: 1, pageSize: list.length, total: list.length });
});

catalogRouter.post('/admin/colleges', need('content', 'edit'), async (req, res) => {
  const b = z.object({ name: z.string().trim().min(2).max(150) }).parse(req.body);
  try {
    const r = await exec(pool, 'INSERT INTO colleges (college_name) VALUES (?)', [b.name]);
    await audit(pool, actor(panelOf(req)), 'admin_college_create', 'colleges', r.insertId, undefined, b);
    res.status(201).json({ id: r.insertId, name: b.name });
  } catch (err) {
    if (isDuplicateKey(err)) throw conflict('exists', 'This college already exists.');
    throw err;
  }
});

// ---------------------------------------------------------------- stalls

catalogRouter.get('/admin/stalls', async (req, res) => {
  const p = panelOf(req);
  const canteenId = scopeCanteen(p, req.query.canteenId);
  const list = await rows(
    pool,
    `SELECT * FROM stalls WHERE is_active = TRUE ${canteenId ? 'AND canteen_id = ?' : ''} ORDER BY canteen_id, stall_name`,
    canteenId ? [canteenId] : [],
  );
  res.json({ items: list.map(toStall), page: 1, pageSize: list.length, total: list.length });
});

const stallFields = z.object({
  canteenId: zId,
  name: z.string().trim().min(2).max(100),
  billPrefix: z.string().trim().toUpperCase().regex(/^[A-Z0-9]{1,5}$/, 'Bill prefix: 1 to 5 letters or digits'),
  gstRate: z.number().min(0).max(28),
  category: z.string().trim().max(100).default(''),
  avgPrepMinutes: z.number().int().min(1).max(120).default(5),
  colour: z.string().regex(/^#[0-9a-fA-F]{6}$/).default('#c2410c'),
  icon: z.string().trim().max(40).default('store'),
  photoUrl: z.string().url().nullable().optional(),
});

function stallColumns(b: Partial<z.infer<typeof stallFields>>) {
  const map: Record<string, [string, unknown]> = {
    canteenId: ['canteen_id', b.canteenId],
    name: ['stall_name', b.name],
    billPrefix: ['bill_prefix', b.billPrefix],
    gstRate: ['gst_rate', b.gstRate],
    category: ['category', b.category],
    avgPrepMinutes: ['avg_prep_minutes', b.avgPrepMinutes],
    colour: ['accent_color', b.colour],
    icon: ['icon_name', b.icon],
    photoUrl: ['photo_url', b.photoUrl],
  };
  return Object.entries(map).filter(([k]) => (b as Row)[k] !== undefined).map(([, v]) => v);
}

const loadStall = async (id: number) => {
  const s = await one(pool, 'SELECT * FROM stalls WHERE stall_id = ? AND is_active = TRUE', [id]);
  if (!s) throw notFound('not_found', 'Stall not found');
  return s;
};

catalogRouter.post('/admin/stalls', need('content', 'edit'), adminOnly, async (req, res) => {
  const b = stallFields.parse(req.body);
  if (!(await one(pool, 'SELECT 1 FROM canteens WHERE canteen_id = ? AND is_active = TRUE', [b.canteenId]))) throw invalid('That canteen does not exist.');
  const cols = stallColumns(b);
  try {
    const id = await withTx(async (conn) => {
      // New stalls start closed: the vendor (or admin) reopens it when ready.
      const r = await exec(conn, `INSERT INTO stalls (${cols.map((c) => c[0]).join(', ')}, status) VALUES (${cols.map(() => '?').join(', ')}, 'closed')`, cols.map((c) => c[1]));
      // Vendors linked to the whole canteen may open the new stall too.
      await exec(
        conn,
        `INSERT IGNORE INTO vendor_stall_access (user_id, stall_id)
         SELECT user_id, ? FROM users WHERE role = 'vendor' AND canteen_id = ? AND stall_id IS NULL`,
        [r.insertId, b.canteenId],
      );
      await audit(conn, actor(panelOf(req)), 'admin_stall_create', 'stalls', r.insertId, undefined, b);
      return r.insertId;
    });
    await bustMenuCache([b.canteenId]);
    res.status(201).json(toStall(await loadStall(id)));
  } catch (err) {
    if (isDuplicateKey(err)) throw conflict('exists', 'Another stall in this canteen already uses this bill prefix.');
    throw err;
  }
});

catalogRouter.patch('/admin/stalls/:id', need('content', 'edit'), adminOnly, async (req, res) => {
  const id = idOf(req.params.id, 'stall');
  const b = stallFields.omit({ canteenId: true }).partial().parse(req.body);
  const before = await loadStall(id);
  const cols = stallColumns(b);
  if (cols.length) {
    try {
      await withTx(async (conn) => {
        await exec(conn, `UPDATE stalls SET ${cols.map((c) => `${c[0]} = ?`).join(', ')} WHERE stall_id = ?`, [...cols.map((c) => c[1]), id]);
        await audit(conn, actor(panelOf(req)), 'admin_stall_update', 'stalls', id, toStall(before), b);
      });
    } catch (err) {
      if (isDuplicateKey(err)) throw conflict('exists', 'Another stall in this canteen already uses this bill prefix.');
      throw err;
    }
  }
  await bustMenuCache([before.canteen_id]);
  res.json(toStall(await loadStall(id)));
});

catalogRouter.delete('/admin/stalls/:id', need('content', 'edit'), adminOnly, async (req, res) => {
  const id = idOf(req.params.id, 'stall');
  const s = await loadStall(id);
  await withTx(async (conn) => {
    if (await one(conn, 'SELECT 1 FROM stall_orders WHERE stall_id = ? LIMIT 1', [id])) {
      throw conflict('has_history', 'This stall has orders, so it cannot be removed. Close it instead.');
    }
    await exec(conn, 'DELETE dm FROM daily_menu dm JOIN products p ON p.product_id = dm.product_id WHERE p.stall_id = ?', [id]);
    await exec(conn, 'DELETE FROM products WHERE stall_id = ?', [id]);
    await exec(conn, 'DELETE FROM vendor_stall_access WHERE stall_id = ?', [id]);
    await exec(conn, 'UPDATE refresh_tokens SET stall_id = NULL WHERE stall_id = ?', [id]);
    await exec(conn, 'UPDATE users SET stall_id = NULL WHERE stall_id = ?', [id]);
    await exec(conn, 'DELETE FROM stall_bill_counters WHERE stall_id = ?', [id]);
    await exec(conn, 'DELETE FROM stalls WHERE stall_id = ?', [id]);
    await audit(conn, actor(panelOf(req)), 'admin_stall_delete', 'stalls', id, toStall(s));
  });
  await bustMenuCache([s.canteen_id]);
  res.status(204).end();
});

/** Same controls as the vendor app, with a reason. Emergency stop cancels new bills and requests their refunds. */
catalogRouter.patch('/admin/stalls/:id/status', need('content', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'stall');
  const b = z
    .object({
      action: z.enum(['pause', 'close', 'reopen', 'emergency']),
      reason: z.string().trim().min(1, 'Give a reason').max(300),
      until: z.string().datetime({ offset: true }).optional(),
      confirmName: z.string().optional(),
    })
    .parse(req.body);
  const s = await loadStall(id);
  assertCanteen(p, s.canteen_id);
  if (b.action === 'emergency' && b.confirmName?.trim() !== s.stall_name) throw new AppError(422, 'confirm_mismatch', 'Type the stall name exactly to confirm.');
  if (b.action === 'pause') {
    if (!b.until || Date.parse(b.until) <= Date.now()) throw invalid('Pick a pause end time in the future.');
  }
  const refunded = await withTx(async (conn) => {
    await one(conn, 'SELECT stall_id FROM stalls WHERE stall_id = ? FOR UPDATE', [id]);
    let ids: number[] = [];
    if (b.action === 'pause') {
      await exec(conn, "UPDATE stalls SET status = 'paused', paused_until = ?, paused_at = UTC_TIMESTAMP() WHERE stall_id = ?", [new Date(b.until!), id]);
    } else if (b.action === 'reopen') {
      await exec(conn, "UPDATE stalls SET status = 'open', paused_until = NULL, paused_at = NULL WHERE stall_id = ?", [id]);
    } else {
      await exec(conn, "UPDATE stalls SET status = 'closed', paused_until = NULL, paused_at = NULL WHERE stall_id = ?", [id]);
      if (b.action === 'emergency') ids = await rejectNewBillsForEmergency(conn, id, p.id);
    }
    const action = b.action === 'reopen' ? 'resume' : b.action;
    await audit(conn, actor(p), `admin_stall_${action}`, 'stalls', id, { status: effectiveStallStatus(s as never) }, { ...b, refundedBills: ids });
    return ids;
  });
  await bustMenuCache([s.canteen_id]);
  if (refunded.length) await publishBills(refunded, 'bill.updated');
  res.json(toStall(await loadStall(id)));
});

// ---------------------------------------------------------------- products (PDF 8)

const PRODUCT_SORT: Record<string, string> = {
  name: 'p.product_name',
  stallName: 's.stall_name',
  category: 'p.category',
  price: 'p.price',
  stock: 'p.stock_quantity',
  available: 'p.stock_quantity',
  sortOrder: 'p.sort_order',
  approvalStatus: 'p.approval_status',
  active: 'p.is_active',
};

catalogRouter.get('/admin/products', (req, res) => listProducts(req, res));

export async function listProducts(req: Request, res: Response) {
  const p = panelOf(req);
  const { page, pageSize, limit, offset } = paging(req);
  const where = ['p.deleted_at IS NULL', 's.is_active = TRUE'];
  const params: unknown[] = [];
  const canteenId = scopeCanteen(p, req.query.canteenId);
  if (canteenId) (where.push('s.canteen_id = ?'), params.push(canteenId));
  if (q(req, 'stallId')) (where.push('p.stall_id = ?'), params.push(Number(q(req, 'stallId'))));
  const status = q(req, 'approvalStatus');
  // "pending" = new items waiting for approval AND live items with a vendor change request.
  if (status === 'pending') where.push("(p.approval_status IN ('pending','draft') OR p.pending_change IS NOT NULL)");
  else if (status) (where.push('p.approval_status = ?'), params.push(status));
  if (q(req, 'category')) (where.push('p.category = ?'), params.push(q(req, 'category')));
  if (q(req, 'available') === 'true') where.push('p.stock_quantity > 0');
  if (q(req, 'available') === 'false') where.push('p.stock_quantity <= 0');
  if (q(req, 'q')) (where.push('(p.product_name LIKE ? OR p.category LIKE ?)'), params.push(`%${q(req, 'q')}%`, `%${q(req, 'q')}%`));
  const w = where.join(' AND ');
  const total = (await one<{ n: number }>(pool, `SELECT COUNT(*) AS n FROM products p JOIN stalls s ON s.stall_id = p.stall_id WHERE ${w}`, params))!.n;
  const order = sortSql(req, PRODUCT_SORT, 'p.sort_order, p.product_name');
  const list = await rows(pool, `${PRODUCT_SELECT} WHERE ${w} ORDER BY ${order}, p.product_id LIMIT ? OFFSET ?`, [...params, limit, offset]);
  res.json({ items: list.map(toProduct), page, pageSize, total: Number(total) });
}

const productFields = z.object({
  stallId: zId,
  name: z.string().trim().min(2).max(150),
  description: z.string().trim().max(255).default(''),
  category: z.string().trim().min(1).max(50),
  price: z.number().min(0).max(100000),
  veg: z.boolean().default(true),
  tags: z.array(z.string().trim().toLowerCase().min(1).max(30)).max(10).default([]),
  imageUrl: z.string().url().nullable().optional(),
  available: z.boolean().optional(),
  stock: z.number().int().min(0).max(100000).default(0),
  dailyDefaultQty: z.number().int().min(0).max(100000).default(30),
  prepMinutes: z.number().int().min(0).max(120).default(5),
  sortOrder: z.number().int().min(0).max(100000).default(100),
  active: z.boolean().optional(),
});
type ProductInput = Partial<z.infer<typeof productFields>>;

/** "Available" is today's stock: sold out sets it to 0, back in stock refills it to the daily quantity. */
function stockFor(b: ProductInput, current: { stock: number; dailyDefaultQty: number }) {
  let stock = b.stock ?? current.stock;
  if (b.available === false) stock = 0;
  if (b.available === true && stock <= 0) stock = Math.max(1, b.dailyDefaultQty ?? current.dailyDefaultQty);
  return stock;
}

function productColumns(b: ProductInput, stock: number | undefined) {
  const map: Record<string, [string, unknown]> = {
    name: ['product_name', b.name],
    description: ['description', b.description],
    category: ['category', b.category],
    price: ['price', b.price],
    veg: ['is_veg', b.veg],
    tags: ['tags', b.tags === undefined ? undefined : JSON.stringify(b.tags)],
    imageUrl: ['image_url', b.imageUrl],
    dailyDefaultQty: ['daily_default_qty', b.dailyDefaultQty],
    prepMinutes: ['prep_minutes', b.prepMinutes],
    sortOrder: ['sort_order', b.sortOrder],
    active: ['is_active', b.active],
  };
  const cols = Object.entries(map).filter(([k]) => (b as Row)[k] !== undefined).map(([, v]) => v);
  if (stock !== undefined) cols.push(['stock_quantity', stock]);
  return cols;
}

/** A category typed on an item is added to the category list (so the app can order it). */
const ensureCategory = (db: typeof pool | import('mysql2/promise').PoolConnection, name: string | undefined) =>
  name ? exec(db, 'INSERT IGNORE INTO categories (category_name, sort_order) SELECT ?, COALESCE(MAX(sort_order), 0) + 10 FROM categories', [name]) : Promise.resolve();

/**
 * A newly published item goes on sale: it joins every daily menu of its canteen from today on (days that already
 * have a menu), or today's menu when the canteen has none yet (a new canteen). The Daily menu tab can change it.
 */
async function addToUpcomingMenus(db: import('mysql2/promise').PoolConnection, productId: number, canteenId: number, by: number) {
  const r = await exec(
    db,
    `INSERT IGNORE INTO daily_menu (menu_date, product_id, added_by)
     SELECT DISTINCT dm.menu_date, ?, ? FROM daily_menu dm
       JOIN products p ON p.product_id = dm.product_id JOIN stalls s ON s.stall_id = p.stall_id
      WHERE s.canteen_id = ? AND dm.menu_date >= ${IST_TODAY} AND dm.product_id <> ?`,
    [productId, by, canteenId, productId],
  );
  if (r.affectedRows === 0) await exec(db, `INSERT IGNORE INTO daily_menu (menu_date, product_id, added_by) VALUES (${IST_TODAY}, ?, ?)`, [productId, by]);
}

catalogRouter.post('/admin/products', need('content', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const b = productFields.parse(req.body);
  const stall = await loadStall(b.stallId);
  assertCanteen(p, stall.canteen_id);
  const stock = stockFor(b, { stock: b.stock ?? 0, dailyDefaultQty: b.dailyDefaultQty ?? 30 });
  const cols = productColumns(b, stock);
  const id = await withTx(async (conn) => {
    await ensureCategory(conn, b.category);
    // Items added from the panel are published straight away.
    const r = await exec(
      conn,
      `INSERT INTO products (stall_id, ${cols.map((c) => c[0]).join(', ')}, approval_status, created_by, approved_by, approved_at)
       VALUES (?, ${cols.map(() => '?').join(', ')}, 'published', ?, ?, UTC_TIMESTAMP())`,
      [b.stallId, ...cols.map((c) => c[1]), p.id, p.id],
    );
    await addToUpcomingMenus(conn, r.insertId, stall.canteen_id, p.id);
    await audit(conn, actor(p), 'admin_product_create', 'products', r.insertId, undefined, b);
    return r.insertId;
  });
  await bustMenuCache([stall.canteen_id]);
  res.status(201).json(toProduct(await loadProduct(id)));
});

catalogRouter.patch('/admin/products/:id', need('content', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'item');
  const b = productFields.omit({ stallId: true }).partial().parse(req.body);
  const before = await loadProduct(id);
  assertCanteen(p, before.canteen_id);
  const touchesStock = b.stock !== undefined || b.available !== undefined;
  const stock = touchesStock ? stockFor(b, { stock: before.stock_quantity, dailyDefaultQty: before.daily_default_qty }) : undefined;
  const cols = productColumns(b, stock);
  if (cols.length) {
    await withTx(async (conn) => {
      await ensureCategory(conn, b.category);
      await exec(conn, `UPDATE products SET ${cols.map((c) => `${c[0]} = ?`).join(', ')} WHERE product_id = ?`, [...cols.map((c) => c[1]), id]);
      await audit(conn, actor(p), 'admin_product_update', 'products', id, toProduct(before), b);
    });
  }
  await bustMenuCache([before.canteen_id]);
  res.json(toProduct(await loadProduct(id)));
});

catalogRouter.delete('/admin/products/:id', need('content', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'item');
  const before = await loadProduct(id);
  assertCanteen(p, before.canteen_id);
  await withTx(async (conn) => {
    // Kept as a row (past order items point at it) but gone from the panel, the menus and the apps.
    await exec(conn, 'UPDATE products SET deleted_at = UTC_TIMESTAMP(), is_active = FALSE, pending_change = NULL WHERE product_id = ?', [id]);
    await exec(conn, 'DELETE FROM daily_menu WHERE product_id = ?', [id]);
    await audit(conn, actor(p), 'admin_product_delete', 'products', id, toProduct(before));
  });
  await bustMenuCache([before.canteen_id]);
  res.status(204).end();
});

/** Bulk price change (set / add ₹ / %; rounded to ₹0.50) or sold out / in stock. One audit row with every change. */
catalogRouter.post('/admin/products/bulk', need('content', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const b = z
    .union([
      z.object({ ids: z.array(zId).min(1).max(500), op: z.enum(['set', 'add', 'pct']), value: z.number().min(-100000).max(100000) }),
      z.object({ ids: z.array(zId).min(1).max(500), available: z.boolean() }),
    ])
    .parse(req.body);
  const items = await rows(pool, `${PRODUCT_SELECT} WHERE p.product_id IN (?) AND p.deleted_at IS NULL ORDER BY p.product_id`, [b.ids]);
  if (items.length !== new Set(b.ids).size) throw notFound('not_found', 'Some items were not found');
  for (const it of items) assertCanteen(p, it.canteen_id);
  const changes: { id: number; from: number; to: number }[] = [];
  await withTx(async (conn) => {
    for (const it of items) {
      if ('available' in b) {
        const stock = stockFor({ available: b.available }, { stock: it.stock_quantity, dailyDefaultQty: it.daily_default_qty });
        await exec(conn, 'UPDATE products SET stock_quantity = ? WHERE product_id = ?', [stock, it.product_id]);
        changes.push({ id: it.product_id, from: it.stock_quantity, to: stock });
      } else {
        const price = Number(it.price);
        const raw = b.op === 'set' ? b.value : b.op === 'add' ? price + b.value : price * (1 + b.value / 100);
        const next = Math.max(0, Math.round(raw * 2) / 2);
        await exec(conn, 'UPDATE products SET price = ? WHERE product_id = ?', [next, it.product_id]);
        changes.push({ id: it.product_id, from: price, to: next });
      }
    }
    await audit(conn, actor(p), 'admin_product_bulk', 'products', items[0].product_id, undefined, { ...b, changes });
  });
  await bustMenuCache(items.map((i) => i.canteen_id));
  res.json({ updated: changes.length });
});

catalogRouter.post('/admin/products/:id/approve', need('content', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'item');
  const it = await loadProduct(id);
  assertCanteen(p, it.canteen_id);
  const change = parseJson<Record<string, unknown>>(it.pending_change);
  await withTx(async (conn) => {
    if (change) {
      // Apply the vendor's change request; the item stays published.
      const b = productFields.pick({ name: true, description: true, category: true, price: true, veg: true, tags: true, imageUrl: true }).partial().parse(
        Object.fromEntries(Object.entries(change).filter(([k]) => (PENDING_KEYS as readonly string[]).includes(k))),
      );
      const cols = productColumns(b, undefined);
      await ensureCategory(conn, b.category);
      await exec(conn, `UPDATE products SET ${[...cols.map((c) => `${c[0]} = ?`), 'pending_change = NULL', 'approved_by = ?', 'approved_at = UTC_TIMESTAMP()'].join(', ')} WHERE product_id = ?`, [
        ...cols.map((c) => c[1]),
        p.id,
        id,
      ]);
    } else if (['pending', 'draft', 'rejected'].includes(it.approval_status)) {
      await exec(
        conn,
        "UPDATE products SET approval_status = 'published', is_active = TRUE, rejection_reason = NULL, approved_by = ?, approved_at = UTC_TIMESTAMP() WHERE product_id = ?",
        [p.id, id],
      );
      await addToUpcomingMenus(conn, id, it.canteen_id, p.id);
    } else {
      throw conflict('invalid_state', 'This item has nothing waiting for approval.');
    }
    await audit(conn, actor(p), 'admin_product_approve', 'products', id, toProduct(it), change ?? { approvalStatus: 'published' });
  });
  await bustMenuCache([it.canteen_id]);
  res.json(toProduct(await loadProduct(id)));
});

catalogRouter.post('/admin/products/:id/reject', need('content', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'item');
  const { reason } = z.object({ reason: z.string().trim().min(1, 'Give a reason').max(255) }).parse(req.body);
  const it = await loadProduct(id);
  assertCanteen(p, it.canteen_id);
  await withTx(async (conn) => {
    if (it.pending_change) {
      // Change request turned down: the item stays on sale with its current values.
      await exec(conn, 'UPDATE products SET pending_change = NULL, rejection_reason = ? WHERE product_id = ?', [reason, id]);
    } else if (['pending', 'draft'].includes(it.approval_status)) {
      await exec(conn, "UPDATE products SET approval_status = 'rejected', is_active = FALSE, rejection_reason = ? WHERE product_id = ?", [reason, id]);
    } else {
      throw conflict('invalid_state', 'This item has nothing waiting for approval.');
    }
    await audit(conn, actor(p), 'admin_product_reject', 'products', id, toProduct(it), { reason });
  });
  await bustMenuCache([it.canteen_id]);
  res.json(toProduct(await loadProduct(id)));
});

// ---------------------------------------------------------------- categories

catalogRouter.get('/admin/categories', async (_req, res) => {
  const list = await rows(
    pool,
    `SELECT c.category_id, c.category_name, c.sort_order,
            (SELECT COUNT(*) FROM products p WHERE p.category = c.category_name AND p.deleted_at IS NULL) AS products
       FROM categories c ORDER BY c.sort_order, c.category_name`,
  );
  const items = list.map((c) => ({ id: c.category_id, name: c.category_name, sortOrder: c.sort_order, products: Number(c.products) }));
  res.json({ items, page: 1, pageSize: items.length, total: items.length });
});

const categoryName = z.object({ name: z.string().trim().min(1).max(50) });

catalogRouter.post('/admin/categories', need('content', 'edit'), async (req, res) => {
  const { name } = categoryName.parse(req.body);
  try {
    const r = await exec(pool, 'INSERT INTO categories (category_name, sort_order) SELECT ?, COALESCE(MAX(sort_order), 0) + 10 FROM categories', [name]);
    await audit(pool, actor(panelOf(req)), 'admin_category_create', 'categories', r.insertId, undefined, { name });
    res.status(201).json({ id: r.insertId, name, sortOrder: 0, products: 0 });
  } catch (err) {
    if (isDuplicateKey(err)) throw conflict('exists', 'This category already exists.');
    throw err;
  }
});

catalogRouter.patch('/admin/categories/:id', need('content', 'edit'), async (req, res) => {
  const id = idOf(req.params.id, 'category');
  const { name } = categoryName.parse(req.body);
  const c = await one(pool, 'SELECT * FROM categories WHERE category_id = ?', [id]);
  if (!c) throw notFound('not_found', 'Category not found');
  try {
    await withTx(async (conn) => {
      await exec(conn, 'UPDATE categories SET category_name = ? WHERE category_id = ?', [name, id]);
      // Renaming moves its items with it.
      await exec(conn, 'UPDATE products SET category = ? WHERE category = ?', [name, c.category_name]);
      await audit(conn, actor(panelOf(req)), 'admin_category_update', 'categories', id, { name: c.category_name }, { name });
    });
  } catch (err) {
    if (isDuplicateKey(err)) throw conflict('exists', 'This category already exists.');
    throw err;
  }
  await bustAllMenus();
  res.json({ id, name, sortOrder: c.sort_order });
});

catalogRouter.post('/admin/categories/reorder', need('content', 'edit'), async (req, res) => {
  const { ids } = z.object({ ids: z.array(zId).min(1).max(500) }).parse(req.body);
  await withTx(async (conn) => {
    for (const [i, id] of ids.entries()) await exec(conn, 'UPDATE categories SET sort_order = ? WHERE category_id = ?', [(i + 1) * 10, id]);
    await audit(conn, actor(panelOf(req)), 'admin_category_reorder', 'categories', ids[0], undefined, { ids });
  });
  res.json({ ok: true });
});

catalogRouter.delete('/admin/categories/:id', need('content', 'edit'), async (req, res) => {
  const id = idOf(req.params.id, 'category');
  const c = await one(pool, 'SELECT * FROM categories WHERE category_id = ?', [id]);
  if (!c) throw notFound('not_found', 'Category not found');
  if (await one(pool, 'SELECT 1 FROM products WHERE category = ? AND deleted_at IS NULL LIMIT 1', [c.category_name])) {
    throw conflict('in_use', 'Move the items of this category first.');
  }
  await exec(pool, 'DELETE FROM categories WHERE category_id = ?', [id]);
  await audit(pool, actor(panelOf(req)), 'admin_category_delete', 'categories', id, { name: c.category_name });
  res.status(204).end();
});

async function bustAllMenus() {
  const ids = await rows<{ canteen_id: number }>(pool, 'SELECT canteen_id FROM canteens');
  await bustMenuCache(ids.map((c) => c.canteen_id));
}

// ---------------------------------------------------------------- daily menu

catalogRouter.get('/admin/daily-menu', need('content'), async (req, res) => {
  const p = panelOf(req);
  const canteenId = Number(q(req, 'canteenId'));
  if (!Number.isInteger(canteenId) || canteenId <= 0) throw invalid('Pick a canteen.');
  assertCanteen(p, canteenId);
  const month = q(req, 'month');
  if (month) {
    if (!/^\d{4}-\d{2}$/.test(month)) throw invalid('month is YYYY-MM');
    const list = await rows<{ d: string; n: number }>(
      pool,
      `SELECT DATE_FORMAT(dm.menu_date, '%Y-%m-%d') AS d, COUNT(*) AS n FROM daily_menu dm
         JOIN products p ON p.product_id = dm.product_id JOIN stalls s ON s.stall_id = p.stall_id
        WHERE s.canteen_id = ? AND DATE_FORMAT(dm.menu_date, '%Y-%m') = ? GROUP BY dm.menu_date`,
      [canteenId, month],
    );
    res.json({ days: Object.fromEntries(list.map((r) => [r.d, Number(r.n)])) });
    return;
  }
  const date = zDate.parse(q(req, 'date'));
  const list = await rows<{ product_id: number }>(
    pool,
    `SELECT dm.product_id FROM daily_menu dm JOIN products p ON p.product_id = dm.product_id JOIN stalls s ON s.stall_id = p.stall_id
      WHERE s.canteen_id = ? AND dm.menu_date = ? ORDER BY dm.product_id`,
    [canteenId, date],
  );
  res.json({ productIds: list.map((r) => r.product_id) });
});

catalogRouter.put('/admin/daily-menu', need('content', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const b = z.object({ canteenId: zId, date: zDate, productIds: z.array(zId).max(1000) }).parse(req.body);
  assertCanteen(p, b.canteenId);
  const ids = [...new Set(b.productIds)];
  if (ids.length) {
    const ok = await rows(
      pool,
      `SELECT p.product_id FROM products p JOIN stalls s ON s.stall_id = p.stall_id
        WHERE p.product_id IN (?) AND s.canteen_id = ? AND p.deleted_at IS NULL AND p.approval_status = 'published'`,
      [ids, b.canteenId],
    );
    if (ok.length !== ids.length) throw invalid('Only published items of this canteen can go on its menu.');
  }
  await withTx(async (conn) => {
    await exec(
      conn,
      'DELETE dm FROM daily_menu dm JOIN products p ON p.product_id = dm.product_id JOIN stalls s ON s.stall_id = p.stall_id WHERE s.canteen_id = ? AND dm.menu_date = ?',
      [b.canteenId, b.date],
    );
    for (const id of ids) await exec(conn, 'INSERT INTO daily_menu (menu_date, product_id, added_by) VALUES (?, ?, ?)', [b.date, id, p.id]);
    await audit(conn, actor(p), 'admin_daily_menu', 'daily_menu', b.canteenId, undefined, { date: b.date, productIds: ids });
  });
  await bustMenuCache([b.canteenId]);
  res.json({ ok: true, count: ids.length });
});

// ---------------------------------------------------------------- photo uploads

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024, files: 1 },
});
const EXT: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };

/** The browser already resized/cropped the photo; the server checks it, stores it and returns its public URL. */
catalogRouter.post(
  '/admin/uploads',
  (req, _res, next) => {
    const p = panelOf(req);
    if (!can(p, 'content', 'edit') && !can(p, 'ads', 'edit') && !can(p, 'settings', 'edit')) throw forbidden('forbidden', 'Your account cannot upload images.');
    next();
  },
  (req, res, next) =>
    upload.single('file')(req, res, (err: unknown) => {
      if ((err as { code?: string })?.code === 'LIMIT_FILE_SIZE') return next(new AppError(413, 'too_large', 'The image is over 2 MB.'));
      next(err);
    }),
  async (req, res) => {
    const file = req.file;
    if (!file) throw invalid('Send the image in the "file" field.');
    const ext = EXT[file.mimetype];
    if (!ext || !looksLikeImage(file.buffer, ext)) throw invalid('Only JPG, PNG or WebP images can be uploaded.');
    const dir = path.resolve(config.UPLOADS_DIR);
    await mkdir(dir, { recursive: true });
    const name = `${Date.now()}-${randomBytes(6).toString('hex')}.${ext}`;
    await writeFile(path.join(dir, name), file.buffer);
    const base = config.PUBLIC_UPLOADS_URL.replace(/\/$/, '') || `${req.protocol}://${req.get('host')}/uploads`;
    res.status(201).json({ url: `${base}/${name}` });
  },
);

/** Checks the file's first bytes, so a renamed non-image is refused. */
function looksLikeImage(buf: Buffer, ext: string) {
  if (ext === 'jpg') return buf[0] === 0xff && buf[1] === 0xd8;
  if (ext === 'png') return buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  return buf.subarray(0, 4).toString('latin1') === 'RIFF' && buf.subarray(8, 12).toString('latin1') === 'WEBP';
}

