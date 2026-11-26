import type { PoolConnection } from 'mysql2/promise';
import { type Request, type Response, Router } from 'express';
import { z } from 'zod';
import { exec, isDuplicateKey, one, pool, rows, withTx } from '../../db/pool.js';
import { AppError, conflict, forbidden, notFound } from '../../errors.js';
import {
  type Panel,
  SECTIONS,
  adminOnly,
  assertCanteen,
  can,
  contactAccessOf,
  invalid,
  maskEmail,
  maskPhone,
  need,
  panelOf,
  panelPermissions,
  scopeCanteen,
  vendorPermissions,
} from '../../services/access.js';
import { audit } from '../../services/audit.js';
import { iso } from '../../util.js';
import { idOf, paging, q, sortSql, zId } from './util.js';

export const peopleRouter = Router();

const actor = (p: Panel) => ({ id: p.id, role: p.role });
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Row = Record<string, any>;

const statusOf = (u: Row) => (u.is_active ? 'active' : u.account_status === 'active' ? 'suspended' : u.account_status);

function baseUser(u: Row, showContact: boolean) {
  return {
    id: u.user_id,
    name: u.name,
    email: showContact ? u.email : maskEmail(u.email),
    registerNo: u.register_no,
    role: u.role,
    canteenId: u.canteen_id,
    stallId: u.stall_id,
    active: Boolean(u.is_active),
    createdAt: iso(u.created_at),
    orderingPausedUntil: iso(u.ordering_paused_until),
    noShowCount: u.no_show_count,
    sessionsRevokedAt: iso(u.sessions_revoked_at),
    phone: showContact ? u.phone : maskPhone(u.phone),
    signInMethod: 'google' as const,
    status: statusOf(u),
    statusReason: u.status_reason,
    lastLoginAt: iso(u.last_login_at),
  };
}

/** Ends every session of the account at once (refresh tokens revoked, older access tokens refused). */
async function endSessions(conn: PoolConnection, userId: number) {
  await exec(conn, 'UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ? AND revoked_at IS NULL', [userId]);
  await exec(conn, 'UPDATE users SET sessions_revoked_at = UTC_TIMESTAMP() WHERE user_id = ?', [userId]);
}

async function loadAccount(id: number) {
  const u = await one(pool, 'SELECT * FROM users WHERE user_id = ?', [id]);
  if (!u) throw notFound('not_found', 'Account not found');
  return u;
}

/** Students need the users section, vendors the vendors section; managers only see their canteen's people. */
function checkAccess(p: Panel, u: Row, level: 'view' | 'edit') {
  if (u.role === 'student') {
    if (!can(p, 'users', level)) throw forbidden('forbidden', 'Your account cannot manage students.');
    if (p.role === 'manager') return; // students are checked against their orders where it matters
  } else if (u.role === 'vendor') {
    if (!can(p, 'vendors', level)) throw forbidden('forbidden', 'Your account cannot manage vendors.');
    assertCanteen(p, u.canteen_id);
  } else {
    throw forbidden('forbidden', 'Panel accounts are managed under Team & access.');
  }
}

// ---------------------------------------------------------------- lists

const USER_SORT: Record<string, string> = {
  name: 'u.name',
  email: 'u.email',
  createdAt: 'u.created_at',
  lastLoginAt: 'u.last_login_at',
  lastActiveAt: 'u.last_active_at',
  orders: 'orders',
  totalSpent: 'total_spent',
  failedLogins: 'failed_logins',
  status: 'u.is_active',
  canteenName: 'c.canteen_name',
  stallName: 's.stall_name',
};

peopleRouter.get('/admin/users', (req, res) => listUsers(req, res));

export async function listUsers(req: Request, res: Response) {
  const p = panelOf(req);
  const role = q(req, 'role') === 'vendor' ? 'vendor' : 'student';
  if (!can(p, role === 'vendor' ? 'vendors' : 'users')) throw forbidden('forbidden', 'Your account cannot see this list.');
  const { page, pageSize, limit, offset } = paging(req);
  const where = ['u.role = ?'];
  const params: unknown[] = [role];
  const text = q(req, 'q');
  if (text) {
    // Without contact access, search never matches email or phone.
    const contact = role === 'vendor' || p.contactAccess;
    where.push(contact ? '(u.name LIKE ? OR u.register_no LIKE ? OR u.email LIKE ?)' : '(u.name LIKE ? OR u.register_no LIKE ?)');
    params.push(`%${text}%`, `%${text}%`, ...(contact ? [`%${text}%`] : []));
  }
  const status = q(req, 'status');
  if (status === 'active') where.push('u.is_active = TRUE');
  else if (status) (where.push("u.is_active = FALSE AND (u.account_status = ? OR (u.account_status = 'active' AND ? = 'suspended'))"), params.push(status, status));
  const canteenId = scopeCanteen(p, req.query.canteenId);
  if (canteenId) {
    if (role === 'vendor') (where.push('u.canteen_id = ?'), params.push(canteenId));
    else (where.push('EXISTS (SELECT 1 FROM orders oc WHERE oc.user_id = u.user_id AND oc.canteen_id = ?)'), params.push(canteenId));
  }
  const w = where.join(' AND ');
  const from = `FROM users u LEFT JOIN canteens c ON c.canteen_id = u.canteen_id LEFT JOIN stalls s ON s.stall_id = u.stall_id`;
  const total = (await one<{ n: number }>(pool, `SELECT COUNT(*) AS n ${from} WHERE ${w}`, params))!.n;
  const list = await rows(
    pool,
    `SELECT u.*, c.canteen_name, s.stall_name,
            (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.user_id AND o.status = 'paid') AS orders,
            (SELECT COALESCE(SUM(o.total), 0) FROM orders o WHERE o.user_id = u.user_id AND o.status = 'paid') AS total_spent,
            (SELECT COUNT(*) FROM login_history l WHERE l.user_id = u.user_id AND l.success = FALSE) AS failed_logins
       ${from} WHERE ${w} ORDER BY ${sortSql(req, USER_SORT, 'u.name')}, u.user_id LIMIT ? OFFSET ?`,
    [...params, limit, offset],
  );
  const items = list.map((u) =>
    role === 'vendor'
      ? {
          ...baseUser(u, true),
          stallName: u.stall_name,
          canteenName: u.canteen_name,
          failedLogins: Number(u.failed_logins),
          permissions: vendorPermissions(u.permissions),
          lastActiveAt: iso(u.last_active_at),
        }
      : { ...baseUser(u, p.contactAccess), orders: Number(u.orders), totalSpent: Number(u.total_spent), failedLogins: Number(u.failed_logins) },
  );
  res.json({ items, page, pageSize, total: Number(total) });
}

peopleRouter.get('/admin/users/:id/logins', async (req, res) => {
  const p = panelOf(req);
  const u = await loadAccount(idOf(req.params.id, 'user'));
  if (u.role === 'student' || u.role === 'vendor') checkAccess(p, u, 'view');
  else if (!can(p, 'settings')) throw forbidden('forbidden', 'Your account cannot see this.');
  const { page, pageSize, limit, offset } = paging(req);
  const total = (await one<{ n: number }>(pool, 'SELECT COUNT(*) AS n FROM login_history WHERE user_id = ?', [u.user_id]))!.n;
  const list = await rows(pool, 'SELECT * FROM login_history WHERE user_id = ? ORDER BY login_id DESC LIMIT ? OFFSET ?', [u.user_id, limit, offset]);
  res.json({
    items: list.map((l) => ({
      id: l.login_id,
      userId: l.user_id,
      at: iso(l.created_at),
      device: l.device || '—',
      appVersion: l.app_version || l.app,
      success: Boolean(l.success),
      failureReason: l.failure_reason,
    })),
    page,
    pageSize,
    total: Number(total),
  });
});

// ---------------------------------------------------------------- changes

const vendorPerms = z.object({
  acceptOrders: z.boolean(),
  editMenu: z.boolean(),
  changePrices: z.boolean(),
  uploadPhotos: z.boolean(),
  viewEarnings: z.boolean(),
});
const reason = z.string().trim().min(1, 'Give a reason').max(255);

/** Gives a vendor the stalls they may open: one stall, or every stall of the canteen (stallId null). */
async function setVendorAccess(conn: PoolConnection, userId: number, canteenId: number, stallId: number | null) {
  await exec(conn, 'DELETE FROM vendor_stall_access WHERE user_id = ?', [userId]);
  if (stallId) await exec(conn, 'INSERT INTO vendor_stall_access (user_id, stall_id) VALUES (?, ?)', [userId, stallId]);
  else await exec(conn, 'INSERT INTO vendor_stall_access (user_id, stall_id) SELECT ?, stall_id FROM stalls WHERE canteen_id = ? AND is_active = TRUE', [userId, canteenId]);
}

async function checkPlacement(canteenId: number, stallId: number | null) {
  if (!(await one(pool, 'SELECT 1 FROM canteens WHERE canteen_id = ? AND is_active = TRUE', [canteenId]))) throw invalid('That canteen does not exist.');
  if (stallId) {
    const s = await one(pool, 'SELECT canteen_id FROM stalls WHERE stall_id = ? AND is_active = TRUE', [stallId]);
    if (!s) throw invalid('That stall does not exist.');
    if (s.canteen_id !== canteenId) throw invalid('That stall is in a different canteen.');
  }
}

peopleRouter.patch('/admin/users/:id', async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'user');
  const b = z
    .union([
      z.object({ status: z.enum(['active', 'blocked', 'suspended']), reason }),
      z.object({ permissions: vendorPerms, reason }),
      z.object({ canteenId: zId, stallId: zId.nullable(), reason }),
      z.object({ orderingPausedUntil: z.null(), reason }),
    ])
    .parse(req.body);
  const u = await loadAccount(id);
  checkAccess(p, u, 'edit');
  if (u.role === 'student' && p.role === 'manager') {
    if (!(await one(pool, 'SELECT 1 FROM orders WHERE user_id = ? AND canteen_id = ? LIMIT 1', [id, p.canteenId]))) {
      throw forbidden('forbidden', 'This student has not ordered at your canteen.');
    }
  }
  await withTx(async (conn) => {
    if ('status' in b) {
      // active === (status == active), on every change. Blocking or suspending ends the sessions at once.
      await exec(conn, 'UPDATE users SET account_status = ?, is_active = ?, status_reason = ? WHERE user_id = ?', [
        b.status,
        b.status === 'active',
        b.status === 'active' ? null : b.reason,
        id,
      ]);
      if (b.status !== 'active') await endSessions(conn, id);
    } else if ('permissions' in b) {
      if (u.role !== 'vendor') throw invalid('Only vendor accounts have these permissions.');
      await exec(conn, 'UPDATE users SET permissions = ? WHERE user_id = ?', [JSON.stringify(b.permissions), id]);
    } else if ('canteenId' in b) {
      if (u.role !== 'vendor') throw invalid('Only vendor accounts are linked to a canteen or stall.');
      assertCanteen(p, b.canteenId);
      await checkPlacement(b.canteenId, b.stallId);
      await exec(conn, 'UPDATE users SET canteen_id = ?, stall_id = ? WHERE user_id = ?', [b.canteenId, b.stallId, id]);
      await setVendorAccess(conn, id, b.canteenId, b.stallId);
      await endSessions(conn, id); // the vendor app asks for the canteen and stall again
    } else {
      await exec(conn, 'UPDATE users SET ordering_paused_until = NULL, no_show_count = 0 WHERE user_id = ?', [id]);
    }
    await audit(conn, actor(p), u.role === 'vendor' ? 'admin_vendor_update' : 'admin_user_update', 'users', id, { status: statusOf(u) }, b);
  });
  const after = await loadAccount(id);
  res.json(baseUser(after, u.role === 'vendor' || p.contactAccess));
});

peopleRouter.post('/admin/users/:id/revoke-sessions', async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'user');
  const b = z.object({ reason }).parse(req.body);
  const u = await loadAccount(id);
  checkAccess(p, u, 'edit');
  await withTx(async (conn) => {
    await endSessions(conn, id);
    await audit(conn, actor(p), 'admin_revoke_sessions', 'users', id, undefined, b);
  });
  res.json({ ok: true });
});

/**
 * Vendors sign in with Google, so there is no password or link to send: access is reset by ending every session.
 * The vendor signs in again with the same Google account (or an admin changes the email first).
 */
peopleRouter.post('/admin/users/:id/reset-access', need('vendors', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'user');
  const b = z.object({ reason }).parse(req.body);
  const u = await loadAccount(id);
  if (u.role !== 'vendor') throw invalid('Only vendor accounts can be reset here.');
  checkAccess(p, u, 'edit');
  await withTx(async (conn) => {
    await endSessions(conn, id);
    await audit(conn, actor(p), 'admin_vendor_reset_access', 'users', id, undefined, b);
  });
  res.json({ ok: true, sentTo: `${u.email ?? 'their Google account'} (sign in again with Google in the vendor app)` });
});

/** Links a Google email to a canteen or one stall. The vendor signs in with Google in the vendor app. */
peopleRouter.post('/admin/vendors', need('vendors', 'edit'), async (req, res) => {
  const p = panelOf(req);
  const b = z
    .object({
      email: z.string().trim().toLowerCase().email(),
      name: z.string().trim().min(2).max(100),
      canteenId: zId,
      stallId: zId.nullable().default(null),
      permissions: vendorPerms.optional(),
    })
    .parse(req.body);
  assertCanteen(p, b.canteenId);
  await checkPlacement(b.canteenId, b.stallId);
  try {
    const id = await withTx(async (conn) => {
      const r = await exec(conn, "INSERT INTO users (name, email, role, canteen_id, stall_id, permissions) VALUES (?, ?, 'vendor', ?, ?, ?)", [
        b.name,
        b.email,
        b.canteenId,
        b.stallId,
        JSON.stringify(vendorPermissions(b.permissions ?? null)),
      ]);
      await setVendorAccess(conn, r.insertId, b.canteenId, b.stallId);
      await audit(conn, actor(p), 'admin_vendor_create', 'users', r.insertId, undefined, b);
      return r.insertId;
    });
    const u = await one(pool, 'SELECT u.*, c.canteen_name, s.stall_name FROM users u LEFT JOIN canteens c ON c.canteen_id = u.canteen_id LEFT JOIN stalls s ON s.stall_id = u.stall_id WHERE u.user_id = ?', [id]);
    res.status(201).json({ ...baseUser(u!, true), canteenName: u!.canteen_name, stallName: u!.stall_name, permissions: vendorPermissions(u!.permissions), failedLogins: 0, lastActiveAt: null });
  } catch (err) {
    if (isDuplicateKey(err)) throw conflict('exists', 'This email already has a Brunchy account.');
    throw err;
  }
});

// ---------------------------------------------------------------- team & access (panel accounts)

const toMember = (u: Row) => ({
  id: u.user_id,
  name: u.name,
  email: u.email,
  role: u.role,
  canteenId: u.canteen_id,
  canteenName: u.canteen_name ?? null,
  active: Boolean(u.is_active),
  permissions: panelPermissions(u.role, u.permissions),
  contactAccess: contactAccessOf(u.role, u.contact_access),
  twoFactor: false,
  lastLoginAt: iso(u.last_login_at),
  createdAt: iso(u.created_at),
});

const permissionsSchema = z.object(Object.fromEntries(SECTIONS.map((s) => [s, z.enum(['off', 'view', 'edit'])])) as Record<(typeof SECTIONS)[number], z.ZodEnum<['off', 'view', 'edit']>>);

const TEAM_SELECT = `SELECT u.*, c.canteen_name FROM users u LEFT JOIN canteens c ON c.canteen_id = u.canteen_id`;

peopleRouter.get('/admin/team', need(['settings', 'users']), async (_req, res) => {
  const list = await rows(pool, `${TEAM_SELECT} WHERE u.role IN ('admin','manager') ORDER BY u.role, u.name`);
  res.json({ items: list.map(toMember), page: 1, pageSize: list.length, total: list.length });
});

peopleRouter.post('/admin/team', need('settings', 'edit'), adminOnly, async (req, res) => {
  const p = panelOf(req);
  const b = z
    .object({
      email: z.string().trim().toLowerCase().email(),
      name: z.string().trim().min(2).max(100),
      role: z.enum(['admin', 'manager']),
      canteenId: zId.nullable().optional(),
      permissions: permissionsSchema.optional(),
      contactAccess: z.boolean().default(false),
      twoFactor: z.boolean().default(false),
    })
    .parse(req.body);
  if (b.role === 'manager' && !b.canteenId) throw invalid('A manager needs a canteen.');
  try {
    const id = await withTx(async (conn) => {
      const r = await exec(conn, 'INSERT INTO users (name, email, role, canteen_id, permissions, contact_access) VALUES (?, ?, ?, ?, ?, ?)', [
        b.name,
        b.email,
        b.role,
        b.role === 'manager' ? b.canteenId : null,
        b.permissions ? JSON.stringify(b.permissions) : null,
        b.contactAccess,
      ]);
      await audit(conn, actor(p), b.role === 'manager' ? 'admin_manager_create' : 'admin_team_create', 'users', r.insertId, undefined, b);
      return r.insertId;
    });
    res.status(201).json(toMember((await one(pool, `${TEAM_SELECT} WHERE u.user_id = ?`, [id]))!));
  } catch (err) {
    if (isDuplicateKey(err)) throw conflict('exists', 'This email already has a Brunchy account.');
    throw err;
  }
});

peopleRouter.patch('/admin/team/:id', need('settings', 'edit'), adminOnly, async (req, res) => {
  const p = panelOf(req);
  const id = idOf(req.params.id, 'account');
  const b = z
    .object({
      permissions: permissionsSchema.optional(),
      contactAccess: z.boolean().optional(),
      twoFactor: z.boolean().optional(),
      canteenId: zId.nullable().optional(),
      active: z.boolean().optional(),
      reason: z.string().trim().max(255).optional(),
    })
    .parse(req.body);
  const u = await one(pool, `${TEAM_SELECT} WHERE u.user_id = ? AND u.role IN ('admin','manager')`, [id]);
  if (!u) throw notFound('not_found', 'Account not found');
  if (id === p.id && (b.active === false || (b.permissions && b.permissions.settings !== 'edit'))) {
    throw new AppError(422, 'self_lockout', 'You cannot disable your own account or remove your own settings access.');
  }
  await withTx(async (conn) => {
    const sets: string[] = [];
    const vals: unknown[] = [];
    if (b.permissions) (sets.push('permissions = ?'), vals.push(JSON.stringify(b.permissions)));
    if (b.contactAccess !== undefined) (sets.push('contact_access = ?'), vals.push(b.contactAccess));
    if (b.canteenId !== undefined && u.role === 'manager') (sets.push('canteen_id = ?'), vals.push(b.canteenId));
    if (b.active !== undefined) (sets.push('is_active = ?', 'account_status = ?'), vals.push(b.active, b.active ? 'active' : 'suspended'));
    if (sets.length) await exec(conn, `UPDATE users SET ${sets.join(', ')} WHERE user_id = ?`, [...vals, id]);
    if (b.active === false) await endSessions(conn, id);
    await audit(conn, actor(p), 'admin_team_update', 'users', id, toMember(u), b);
  });
  res.json(toMember((await one(pool, `${TEAM_SELECT} WHERE u.user_id = ?`, [id]))!));
});
