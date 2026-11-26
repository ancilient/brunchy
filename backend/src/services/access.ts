import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { exec, one, pool } from '../db/pool.js';
import { AppError, forbidden, unauthorized } from '../errors.js';
import { currentUser } from '../middleware/auth.js';
import { getSettings } from './settings.js';

/** Panel sections an account can be given (admin_web src/lib/types.ts). */
export const SECTIONS = ['orders', 'payments', 'users', 'vendors', 'ads', 'content', 'settings'] as const;
export type Section = (typeof SECTIONS)[number];
export type Level = 'off' | 'view' | 'edit';
export type Permissions = Record<Section, Level>;

const ALL_EDIT = Object.fromEntries(SECTIONS.map((s) => [s, 'edit'])) as Permissions;
/** A canteen manager runs their canteen: orders, menu, stalls and vendors. Money and settings stay with admins. */
const MANAGER_DEFAULT: Permissions = { orders: 'edit', payments: 'off', users: 'view', vendors: 'edit', ads: 'off', content: 'edit', settings: 'off' };

export interface VendorPermissions {
  acceptOrders: boolean;
  editMenu: boolean;
  changePrices: boolean;
  uploadPhotos: boolean;
  viewEarnings: boolean;
}
export const VENDOR_DEFAULT: VendorPermissions = { acceptOrders: true, editMenu: true, changePrices: false, uploadPhotos: true, viewEarnings: true };

export const parseJson = <T>(v: unknown): T | null => (v == null ? null : typeof v === 'string' ? (JSON.parse(v) as T) : (v as T));

export function panelPermissions(role: string, stored: unknown): Permissions {
  const base = role === 'admin' ? ALL_EDIT : MANAGER_DEFAULT;
  const saved = parseJson<Partial<Permissions>>(stored) ?? {};
  return Object.fromEntries(SECTIONS.map((s) => [s, saved[s] ?? base[s]])) as Permissions;
}

export function vendorPermissions(stored: unknown): VendorPermissions {
  return { ...VENDOR_DEFAULT, ...(parseJson<Partial<VendorPermissions>>(stored) ?? {}) };
}

/** Admins see contact data unless switched off; managers only when given it. */
export const contactAccessOf = (role: string, stored: number | boolean | null) => (stored == null ? role === 'admin' : Boolean(stored));

export interface PanelUserRow {
  user_id: number;
  name: string;
  email: string | null;
  role: string;
  canteen_id: number | null;
  permissions: unknown;
  contact_access: number | null;
  is_active: number;
  sessions_revoked_at: Date | null;
}

/** The `user` part of a panel Session (admin_web src/lib/api.ts). */
export async function sessionUser(u: PanelUserRow) {
  return {
    id: u.user_id,
    name: u.name,
    email: u.email,
    role: u.role as 'admin' | 'manager',
    canteenId: u.canteen_id,
    permissions: panelPermissions(u.role, u.permissions),
    contactAccess: contactAccessOf(u.role, u.contact_access),
    twoFactor: false, // email OTP for panel accounts is not built yet
    idleMinutes: (await getSettings()).adminIdleMinutes,
  };
}

export interface Panel {
  id: number;
  name: string;
  role: 'admin' | 'manager';
  /** Managers: their canteen. Admins: null (every canteen). */
  canteenId: number | null;
  permissions: Permissions;
  contactAccess: boolean;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      panel?: Panel;
    }
  }
}

/** Access tokens carry `iat` (seconds); a token issued before the account's sessions were ended is refused. */
export function tokenRevoked(req: Request, revokedAt: Date | null) {
  if (!revokedAt) return false;
  const iat = Number(req.user?.iat ?? 0);
  // iat and DATETIME both have whole seconds: a token from the same second as the revocation is refused too.
  return iat * 1000 <= revokedAt.getTime();
}

/** Loads the panel account behind the access token on every /admin request (so blocking works at once). */
export const loadPanel: RequestHandler = async (req: Request, _res: Response, next: NextFunction) => {
  const user = currentUser(req);
  if (user.role !== 'admin' && user.role !== 'manager') throw forbidden('forbidden', 'This account does not have dashboard access.');
  const row = await one<PanelUserRow>(pool, 'SELECT * FROM users WHERE user_id = ?', [user.id]);
  if (!row || !row.is_active || tokenRevoked(req, row.sessions_revoked_at)) throw unauthorized('Your session has ended. Please sign in again.');
  req.panel = {
    id: row.user_id,
    name: row.name,
    role: row.role as 'admin' | 'manager',
    canteenId: row.role === 'manager' ? row.canteen_id : null,
    permissions: panelPermissions(row.role, row.permissions),
    contactAccess: contactAccessOf(row.role, row.contact_access),
  };
  // Last active (at most one write a minute).
  await exec(pool, 'UPDATE users SET last_active_at = UTC_TIMESTAMP() WHERE user_id = ? AND (last_active_at IS NULL OR last_active_at < UTC_TIMESTAMP() - INTERVAL 1 MINUTE)', [row.user_id]);
  next();
};

export const panelOf = (req: Request): Panel => {
  if (!req.panel) throw unauthorized();
  return req.panel;
};

export function can(p: Panel, section: Section, level: 'view' | 'edit' = 'view') {
  const have = p.permissions[section];
  return level === 'edit' ? have === 'edit' : have !== 'off';
}

/** Route guard: GET needs view, writes need edit (handover section 5). Any of the listed sections is enough. */
export const need =
  (sections: Section | Section[], level?: 'view' | 'edit'): RequestHandler =>
  (req, _res, next) => {
    const p = panelOf(req);
    const lvl = level ?? (req.method === 'GET' ? 'view' : 'edit');
    const list = Array.isArray(sections) ? sections : [sections];
    if (!list.some((s) => can(p, s, lvl))) throw forbidden('forbidden', `Your account cannot ${lvl === 'edit' ? 'change' : 'see'} this.`);
    next();
  };

/** Admin-only routes (creating canteens and stalls, team). */
export const adminOnly: RequestHandler = (req, _res, next) => {
  if (panelOf(req).role !== 'admin') throw forbidden('forbidden', 'Only admins can do this.');
  next();
};

/** Managers may only touch their own canteen: 403 for any record elsewhere. */
export function assertCanteen(p: Panel, canteenId: number | null | undefined) {
  if (p.role === 'manager' && canteenId !== p.canteenId) throw forbidden('forbidden', 'This belongs to another canteen.');
}

/** The canteen filter a list must use: managers are forced to theirs. */
export function scopeCanteen(p: Panel, requested: unknown): number | null {
  if (p.role === 'manager') return p.canteenId ?? -1;
  const n = Number(requested);
  return Number.isInteger(n) && n > 0 ? n : null;
}

/** a•••@college.in, •••••43210 */
export function maskEmail(email: string | null) {
  if (!email) return null;
  const [name, domain] = email.split('@');
  return `${name.slice(0, 1)}•••@${domain ?? ''}`;
}
export const maskPhone = (phone: string | null) => (phone ? `•••••${phone.slice(-5)}` : null);

export const invalid = (message: string) => new AppError(422, 'invalid', message);
