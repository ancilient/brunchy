import { type Request, type RequestHandler, Router } from 'express';
import { z } from 'zod';
import { exec, one, pool } from '../db/pool.js';
import { badRequest, forbidden, unauthorized } from '../errors.js';
import { currentUser, requireAuth, requireRole } from '../middleware/auth.js';
import { type VendorPermissions, tokenRevoked, vendorPermissions } from '../services/access.js';
import { openVendorStallSession } from '../services/auth.js';
import * as bills from '../services/bills.js';
import { getVendorDashboard } from '../services/reports.js';
import { parseId } from '../util.js';

export const vendorRouter = Router();

/**
 * Every vendor request re-reads the account, so what the admin panel sets applies at once: a disabled vendor or one
 * whose sessions were ended is signed out, and the five vendor permissions are enforced. Also records "last active".
 */
const loadVendor: RequestHandler = async (req, _res, next) => {
  const user = currentUser(req);
  const row = await one<{ is_active: number; sessions_revoked_at: Date | null; permissions: unknown }>(
    pool,
    'SELECT is_active, sessions_revoked_at, permissions FROM users WHERE user_id = ?',
    [user.id],
  );
  if (!row || !row.is_active || tokenRevoked(req, row.sessions_revoked_at)) throw unauthorized('Your account was signed out by the canteen admin.');
  withPerms(req).vendorPermissions = vendorPermissions(row.permissions);
  await exec(pool, 'UPDATE users SET last_active_at = UTC_TIMESTAMP() WHERE user_id = ? AND (last_active_at IS NULL OR last_active_at < UTC_TIMESTAMP() - INTERVAL 1 MINUTE)', [user.id]);
  next();
};
const withPerms = (req: Request) => req as Request & { vendorPermissions?: VendorPermissions };

const allow =
  (perm: keyof VendorPermissions, what: string): RequestHandler =>
  (req, _res, next) => {
    if (!withPerms(req).vendorPermissions?.[perm]) throw forbidden('PERMISSION_DENIED', `Your account is not allowed to ${what}. Ask the canteen admin.`);
    next();
  };

vendorRouter.use('/vendor', requireAuth, requireRole('vendor'), loadVendor);

const idParam = (value: unknown, what: string) => {
  const id = parseId(value);
  if (!id) throw badRequest('INVALID_ID', `Invalid ${what} id`);
  return id;
};
const pickupCode = z.string().regex(/^[1-9]\d{2}$/, 'The pickup code has 3 digits');

/** ?status=active (default) | new | accepted | preparing | ready | collected | closed | all, and optional ?date=YYYY-MM-DD (IST) */
vendorRouter.get('/vendor/bills', async (req, res) => {
  const date =
    req.query.date === undefined ? undefined : z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'date is YYYY-MM-DD').parse(String(req.query.date));
  res.json(await bills.listVendorBills(currentUser(req), String(req.query.status ?? 'active'), date));
});

/**
 * Choose the stall to work at (vendor app, after picking a canteen). Returns a new token pair scoped to that stall;
 * every /vendor/* endpoint and the socket then use it. 403 STALL_NOT_ALLOWED without a vendor_stall_access row.
 */
vendorRouter.post('/vendor/session/stall', async (req, res) => {
  const body = z
    .object({
      stallId: z.union([z.string(), z.number()]),
      date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'date is YYYY-MM-DD').optional(), // informational
      forceTakeover: z.boolean().default(false),
    })
    .parse(req.body ?? {});
  res.json(await openVendorStallSession(currentUser(req), idParam(body.stallId, 'stall')));
});

/** My stall: name, canteen and current status. */
vendorRouter.get('/vendor/stall', async (req, res) => {
  res.json(await bills.getVendorStall(currentUser(req)));
});

/** Sales dashboard of my stall from real bills: today, this week (Mon-today) or this month, IST. */
vendorRouter.get('/vendor/reports/dashboard', allow('viewEarnings', 'see earnings'), async (req, res) => {
  const period = z.enum(['today', 'this_week', 'this_month']).parse(String(req.query.period ?? 'today'));
  res.json(await getVendorDashboard(currentUser(req), period));
});

/** Every item of my stall, including switched-off ones, with stock and daily default quantity. */
vendorRouter.get('/vendor/products', async (req, res) => {
  res.json(await bills.listVendorProducts(currentUser(req)));
});

vendorRouter.get('/vendor/bills/lookup', async (req, res) => {
  const code = pickupCode.parse(String(req.query.code ?? ''));
  res.json(await bills.findBillByCode(currentUser(req), code));
});

vendorRouter.patch('/vendor/bills/:id/status', allow('acceptOrders', 'accept or reject orders'), async (req, res) => {
  const body = z
    .object({
      status: z.enum(['accepted', 'preparing', 'ready', 'rejected']),
      reason: z.enum(bills.REJECT_REASONS).optional(),
      prepMinutes: z.number().int().min(1).max(60).optional(),
    })
    .parse(req.body);
  res.json(await bills.setBillStatus(currentUser(req), idParam(req.params.id, 'bill'), body));
});

vendorRouter.post('/vendor/bills/:id/handover', allow('acceptOrders', 'hand over orders'), async (req, res) => {
  const body = z.object({ code: pickupCode }).parse(req.body);
  res.json(await bills.handover(currentUser(req), idParam(req.params.id, 'bill'), body.code));
});

vendorRouter.patch('/vendor/products/:id', allow('editMenu', 'change the menu'), async (req, res) => {
  const body = z
    .object({ stockQuantity: z.number().int().min(0).max(10000).optional(), isActive: z.boolean().optional() })
    .refine((b) => b.stockQuantity !== undefined || b.isActive !== undefined, 'Send stockQuantity and/or isActive')
    .parse(req.body);
  res.json(await bills.updateProduct(currentUser(req), idParam(req.params.id, 'product'), body));
});

vendorRouter.post('/vendor/stall/status', async (req, res) => {
  const body = z
    .object({
      action: z.enum(['pause', 'close', 'resume', 'emergency']),
      minutes: z.union([z.literal(10), z.literal(15), z.literal(30)]).optional(),
      reason: z.enum(['GAS_CUT', 'POWER_FAILURE', 'SHORTAGE', 'OTHER']).optional(),
      detail: z.string().max(200).optional(),
    })
    .refine((b) => b.action !== 'emergency' || b.reason, 'Emergency stop needs a reason')
    .parse(req.body);
  res.json(await bills.setStallStatus(currentUser(req), body));
});
