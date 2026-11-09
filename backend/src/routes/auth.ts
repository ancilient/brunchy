import { Router } from 'express';
import { z } from 'zod';
import { notFound } from '../errors.js';
import { currentUser, requireAuth } from '../middleware/auth.js';
import { byIp, rateLimit } from '../middleware/rateLimit.js';
import * as auth from '../services/auth.js';

const phone = z.string().regex(/^[6-9]\d{9}$/, 'Enter a 10-digit Indian mobile number');

export const authRouter = Router();

authRouter.post(
  '/auth/otp',
  rateLimit('otp', 5, 600, (req) => `${byIp(req)}:${req.body?.phone}`),
  async (req, res) => {
    const body = z.object({ phone }).parse(req.body);
    res.json(await auth.requestOtp(body.phone));
  },
);

authRouter.post('/auth/verify', rateLimit('verify', 20, 600, byIp), async (req, res) => {
  const body = z
    .object({
      phone,
      code: z.string().regex(/^\d{6}$/, 'The code has 6 digits'),
      name: z.string().trim().min(2).max(100).optional(),
      registerNo: z.string().trim().max(30).optional(),
    })
    .parse(req.body);
  res.json(await auth.verifyOtp(body));
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
  res.json({ user: auth.serializeUser(user) });
});
