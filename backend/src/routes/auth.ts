import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config.js';
import { pool } from '../db/pool.js';
import { notFound } from '../errors.js';
import { currentUser, requireAuth } from '../middleware/auth.js';
import { byIp, rateLimit } from '../middleware/rateLimit.js';
import * as auth from '../services/auth.js';
import { feeRules, freeOrdersLeft } from '../services/fees.js';

const app = z.enum(['student', 'vendor']);

export const authRouter = Router();

/** Which sign-in buttons the apps should show. */
authRouter.get('/auth/options', (_req, res) => {
  res.json(auth.loginOptions());
});

/** Public settings the student app shows: Customer Care contacts, the GST number on bills, and the fee rules. */
authRouter.get('/app-config', (_req, res) => {
  res.json({
    support: { email: config.SUPPORT_EMAIL || null, phone: config.SUPPORT_PHONE || null, whatsapp: config.SUPPORT_WHATSAPP || null },
    gstin: config.GSTIN || null,
    fees: feeRules(),
  });
});

/** Sign in with Google: the app sends the ID token it got from Google Sign-In. */
authRouter.post('/auth/google', rateLimit('google', 20, 600, byIp), async (req, res) => {
  const body = z.object({ idToken: z.string().min(20), app }).parse(req.body);
  res.json(await auth.signInWithGoogle(body.idToken, body.app));
});

/** DEVELOPMENT ONLY (DEV_LOGIN=true): demo student, or the vendor of a stall (stallId, default 1). */
authRouter.post('/auth/dev-login', async (req, res) => {
  const body = z.object({ app, stallId: z.number().int().positive().optional() }).parse(req.body ?? {});
  res.json(await auth.devLogin(body.app, body.stallId));
});

authRouter.post('/auth/refresh', async (req, res) => {
  const body = z.object({ refreshToken: z.string().min(10) }).parse(req.body);
  res.json(await auth.refresh(body.refreshToken));
});

authRouter.post('/auth/logout', async (req, res) => {
  const body = z.object({ refreshToken: z.string().min(10) }).parse(req.body);
  await auth.logout(body.refreshToken);
  res.status(204).end();
});

authRouter.get('/me', requireAuth, async (req, res) => {
  const user = await auth.findUserById(currentUser(req).id);
  if (!user) throw notFound('USER_NOT_FOUND', 'Account not found');
  // Students: how many free orders (no platform or convenience fee) are left, for the cart preview.
  const free = user.role === 'student' ? await freeOrdersLeft(pool, user.user_id) : 0;
  res.json({ user: auth.serializeUser(user), freeOrdersLeft: free });
});
