import { randomBytes } from 'node:crypto';
import express, { Router } from 'express';
import { z } from 'zod';
import { config, isProduction } from '../config.js';
import { one, pool } from '../db/pool.js';
import { badRequest, conflict, notFound } from '../errors.js';
import { currentUser, requireAuth, requireRole } from '../middleware/auth.js';
import { MOCK_SIGNATURE_HEADER, signMockBody } from '../payments/mockGateway.js';
import { handleWebhook } from '../services/payments.js';
import { parseId, toPaise } from '../util.js';

export const paymentsRouter = Router();

/** Called by the payment gateway. Needs the exact raw bytes to check the signature, so it skips the JSON parser. */
paymentsRouter.post('/payments/webhook', express.raw({ type: '*/*', limit: '100kb' }), async (req, res) => {
  const raw = Buffer.isBuffer(req.body) ? req.body : Buffer.from('');
  res.json(await handleWebhook(raw, req.headers));
});

/**
 * DEVELOPMENT ONLY: pretend the student paid with a UPI app. Builds the same signed webhook the gateway
 * would send and runs it through the normal webhook handler. Body: { "fail": false, "upiApp": "gpay" }.
 */
if (!isProduction && config.PAYMENT_GATEWAY === 'mock') {
  paymentsRouter.post('/payments/mock/:orderId/pay', express.json(), requireAuth, requireRole('student'), async (req, res) => {
    const orderId = parseId(req.params.orderId);
    if (!orderId) throw badRequest('INVALID_ID', 'Invalid order id');
    const body = z.object({ fail: z.boolean().default(false), upiApp: z.string().max(30).default('gpay') }).parse(req.body ?? {});
    const order = await one(pool, 'SELECT * FROM orders WHERE order_id = ? AND user_id = ?', [orderId, currentUser(req).id]);
    if (!order) throw notFound('ORDER_NOT_FOUND', 'Order not found');
    if (!order.gateway_order_ref) throw conflict('NO_PAYMENT_ORDER', 'Confirm the shortage prompt before paying');
    const raw = JSON.stringify({
      type: body.fail ? 'payment.failed' : 'payment.captured',
      gatewayOrderRef: order.gateway_order_ref,
      gatewayPaymentRef: `mock_pay_${randomBytes(6).toString('hex')}`,
      amountPaise: toPaise(order.total),
      upiApp: body.upiApp,
      ...(body.fail ? { failureReason: 'USER_CANCELLED' } : {}),
    });
    res.json(await handleWebhook(Buffer.from(raw), { [MOCK_SIGNATURE_HEADER]: signMockBody(raw) }));
  });
}
