import { Router } from 'express';
import { z } from 'zod';
import { badRequest } from '../errors.js';
import { currentUser, requireAuth, requireRole } from '../middleware/auth.js';
import { byUser, rateLimit } from '../middleware/rateLimit.js';
import { cancelPendingOrder, checkout, confirmPartial } from '../services/checkout.js';
import { parseId } from '../util.js';

const id = z.union([z.string(), z.number()]).transform((v, ctx) => {
  const n = parseId(v);
  if (!n) ctx.addIssue({ code: 'custom', message: 'Invalid id' });
  return n ?? 0;
});

export const checkoutRouter = Router();
checkoutRouter.use('/checkout', requireAuth, requireRole('student'));

/** Prices are never accepted from the app: only product ids and quantities. */
checkoutRouter.post('/checkout', rateLimit('checkout', 10, 60, byUser), async (req, res) => {
  const body = z
    .object({
      canteenId: id,
      items: z.array(z.object({ productId: id, qty: z.number().int().min(1).max(20) })).min(1).max(30),
      idempotencyKey: z.string().min(8).max(64),
    })
    .parse(req.body);
  const result = await checkout(currentUser(req).id, body);
  res.status(result.needsConfirmation ? 200 : 201).json(result);
});

/** Closing the payment sheet: the held stock goes back on sale immediately. Only for unpaid (pending) orders. */
checkoutRouter.post('/checkout/:orderId/cancel', async (req, res) => {
  const orderId = parseId(req.params.orderId);
  if (!orderId) throw badRequest('INVALID_ID', 'Invalid order id');
  res.json(await cancelPendingOrder(currentUser(req).id, orderId));
});

checkoutRouter.post('/checkout/:orderId/confirm-partial', async (req, res) => {
  const orderId = parseId(req.params.orderId);
  if (!orderId) throw badRequest('INVALID_ID', 'Invalid order id');
  const body = z
    .object({ lines: z.array(z.object({ productId: id, action: z.enum(['take_available', 'remove']) })).default([]) })
    .parse(req.body ?? {});
  res.json(await confirmPartial(currentUser(req).id, orderId, body.lines));
});
