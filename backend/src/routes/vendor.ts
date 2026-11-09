import { Router } from 'express';
import { z } from 'zod';
import { badRequest } from '../errors.js';
import { currentUser, requireAuth, requireRole } from '../middleware/auth.js';
import * as bills from '../services/bills.js';
import { parseId } from '../util.js';

export const vendorRouter = Router();
vendorRouter.use('/vendor', requireAuth, requireRole('vendor'));

const idParam = (value: unknown, what: string) => {
  const id = parseId(value);
  if (!id) throw badRequest('INVALID_ID', `Invalid ${what} id`);
  return id;
};
const pickupCode = z.string().regex(/^[1-9]\d{2}$/, 'The pickup code has 3 digits');

/** ?status=active (default) | new | accepted | preparing | ready | collected | closed | all */
vendorRouter.get('/vendor/bills', async (req, res) => {
  res.json(await bills.listVendorBills(currentUser(req), String(req.query.status ?? 'active')));
});

vendorRouter.get('/vendor/bills/lookup', async (req, res) => {
  const code = pickupCode.parse(String(req.query.code ?? ''));
  res.json(await bills.findBillByCode(currentUser(req), code));
});

vendorRouter.patch('/vendor/bills/:id/status', async (req, res) => {
  const body = z
    .object({
      status: z.enum(['accepted', 'preparing', 'ready', 'rejected']),
      reason: z.enum(bills.REJECT_REASONS).optional(),
      prepMinutes: z.number().int().min(1).max(60).optional(),
    })
    .parse(req.body);
  res.json(await bills.setBillStatus(currentUser(req), idParam(req.params.id, 'bill'), body));
});

vendorRouter.post('/vendor/bills/:id/handover', async (req, res) => {
  const body = z.object({ code: pickupCode }).parse(req.body);
  res.json(await bills.handover(currentUser(req), idParam(req.params.id, 'bill'), body.code));
});

vendorRouter.patch('/vendor/products/:id', async (req, res) => {
  const body = z
    .object({ stockQuantity: z.number().int().min(0).max(10000).optional(), isActive: z.boolean().optional() })
    .refine((b) => b.stockQuantity !== undefined || b.isActive !== undefined, 'Send stockQuantity and/or isActive')
    .parse(req.body);
  res.json(await bills.updateProduct(currentUser(req), idParam(req.params.id, 'product'), body));
});

vendorRouter.post('/vendor/stall/status', async (req, res) => {
  const body = z
    .object({
      action: z.enum(['pause', 'close', 'resume']),
      minutes: z.union([z.literal(10), z.literal(15), z.literal(30)]).optional(),
    })
    .parse(req.body);
  res.json(await bills.setStallStatus(currentUser(req), body));
});
