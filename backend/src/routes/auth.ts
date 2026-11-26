import type { CookieOptions, Request, Response } from 'express';
import { Router } from 'express';
import { z } from 'zod';
import { config, isProduction } from '../config.js';
import { pool } from '../db/pool.js';
import { notFound, unauthorized } from '../errors.js';
import { currentUser, requireAuth } from '../middleware/auth.js';
import { byIp, rateLimit } from '../middleware/rateLimit.js';
import { type PanelUserRow, sessionUser } from '../services/access.js';
import * as auth from '../services/auth.js';
import { feeRules, freeOrdersLeft } from '../services/fees.js';
import { getSettings } from '../services/settings.js';
import { one } from '../db/pool.js';

const app = z.enum(['student', 'vendor', 'admin']);

export const authRouter = Router();

// ---------------------------------------------------------------- admin panel session cookie
// The panel keeps its access token in memory and the refresh token in this httpOnly cookie (handover section 4);
// the apps keep sending refreshToken in the body as before.
const ADMIN_COOKIE = 'brunchy_admin_rt';

function cookieOptions(): CookieOptions {
  return {
    httpOnly: true,
    secure: isProduction || config.ADMIN_COOKIE_SAMESITE === 'none',
    sameSite: config.ADMIN_COOKIE_SAMESITE,
    path: '/api/v1/auth',
    maxAge: config.JWT_REFRESH_DAYS * 24 * 3600 * 1000,
  };
}

function readCookie(req: Request, name: string) {
  for (const part of (req.headers.cookie ?? '').split(';')) {
    const [k, ...v] = part.trim().split('=');
    if (k === name) return decodeURIComponent(v.join('='));
  }
  return undefined;
}

const loginMeta = (req: Request): auth.LoginMeta => ({
  device: String(req.headers['user-agent'] ?? ''),
  appVersion: String(req.headers['x-app-version'] ?? ''),
});

/** Panel sign-in answer: { accessToken, user } with the refresh token in the cookie only. */
async function panelSession(res: Response, tokens: { accessToken: string; refreshToken: string; user: { id: string } }) {
  const row = await one<PanelUserRow>(pool, 'SELECT * FROM users WHERE user_id = ?', [Number(tokens.user.id)]);
  res.cookie(ADMIN_COOKIE, tokens.refreshToken, cookieOptions());
  return { accessToken: tokens.accessToken, user: await sessionUser(row!) };
}

/** Which sign-in buttons the apps should show. */
authRouter.get('/auth/options', (_req, res) => {
  res.json(auth.loginOptions());
});

/** Public settings the student app shows: Customer Care contacts, the GST number on bills, and the fee rules. */
authRouter.get('/app-config', async (_req, res) => {
  const s = await getSettings();
  const now = Date.now();
  const t = s.festivalTheme;
  const themeLive = t.enabled && (!t.startAt || Date.parse(t.startAt) <= now) && (!t.endAt || Date.parse(t.endAt) > now);
  res.json({
    support: { email: s.supportEmail || null, phone: s.supportPhone || null, whatsapp: s.supportWhatsapp || null },
    gstin: s.gstin || null,
    fees: await feeRules(),
    // Switches from the admin panel (Fees & app settings). Older app versions ignore fields they don't know.
    maintenanceMode: s.maintenanceMode,
    orderingPaused: s.orderingPaused,
    forceUpdate: s.forceUpdate,
    minAppVersion: s.minAppVersion,
    minOrderValue: s.minOrderValue,
    festivalTheme: themeLive ? { name: t.name, primaryColor: t.primaryColor, bannerUrl: t.bannerUrl } : null,
  });
});

/** Sign in with Google: the app (or the admin panel) sends the ID token it got from Google Sign-In. */
authRouter.post('/auth/google', rateLimit('google', config.GOOGLE_SIGNINS_PER_IP, 600, byIp), async (req, res) => {
  const body = z.object({ idToken: z.string().min(20), app }).parse(req.body);
  const tokens = await auth.signInWithGoogle(body.idToken, body.app, loginMeta(req));
  res.json(body.app === 'admin' ? await panelSession(res, tokens) : tokens);
});

/** DEVELOPMENT ONLY (DEV_LOGIN=true): demo student, the vendor of a stall (stallId, default 1), or a panel account. */
authRouter.post('/auth/dev-login', async (req, res) => {
  const body = z
    .object({ app, stallId: z.number().int().positive().optional(), role: z.enum(['admin', 'manager']).optional() })
    .parse(req.body ?? {});
  const tokens = await auth.devLogin(body.app, body.stallId, body.role);
  res.json(body.app === 'admin' ? await panelSession(res, tokens) : tokens);
});

authRouter.post('/auth/refresh', async (req, res) => {
  const body = z.object({ refreshToken: z.string().min(10).optional(), app: app.optional() }).parse(req.body ?? {});
  if (body.app === 'admin') {
    const token = readCookie(req, ADMIN_COOKIE);
    if (!token) throw unauthorized('Please sign in.');
    res.json(await panelSession(res, await auth.refresh(token, 'admin')));
    return;
  }
  if (!body.refreshToken) throw unauthorized('Please log in again.');
  res.json(await auth.refresh(body.refreshToken));
});

authRouter.post('/auth/logout', async (req, res) => {
  const body = z.object({ refreshToken: z.string().min(10).optional() }).parse(req.body ?? {});
  const token = body.refreshToken ?? readCookie(req, ADMIN_COOKIE);
  if (token) await auth.logout(token);
  res.clearCookie(ADMIN_COOKIE, { ...cookieOptions(), maxAge: undefined });
  res.status(204).end();
});

/** A student deletes their own account (Profile → Delete my account). */
authRouter.delete('/me', requireAuth, async (req, res) => {
  res.json(await auth.deleteStudentAccount(currentUser(req).id));
});

authRouter.get('/me', requireAuth, async (req, res) => {
  const user = await auth.findUserById(currentUser(req).id);
  if (!user) throw notFound('USER_NOT_FOUND', 'Account not found');
  // Students: how many free orders (no platform or convenience fee) are left, for the cart preview.
  const free = user.role === 'student' ? await freeOrdersLeft(pool, user.user_id) : 0;
  res.json({ user: auth.serializeUser(user), freeOrdersLeft: free });
});
