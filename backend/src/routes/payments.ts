import { randomBytes } from 'node:crypto';
import express, { Router } from 'express';
import { z } from 'zod';
import { config, isProduction } from '../config.js';
import { one, pool } from '../db/pool.js';
import { AppError, badRequest, conflict, notFound } from '../errors.js';
import { currentUser, requireAuth, requireRole } from '../middleware/auth.js';
import { MOCK_SIGNATURE_HEADER, signMockBody } from '../payments/mockGateway.js';
import { verifyCheckoutSignature } from '../payments/razorpayGateway.js';
import { applyVerifiedPayment, handleWebhook } from '../services/payments.js';
import { parseId, toPaise } from '../util.js';

export const paymentsRouter = Router();

/** Called by the payment gateway. Needs the exact raw bytes to check the signature, so it skips the JSON parser. */
paymentsRouter.post('/payments/webhook', express.raw({ type: '*/*', limit: '100kb' }), async (req, res) => {
  const raw = Buffer.isBuffer(req.body) ? req.body : Buffer.from('');
  res.json(await handleWebhook(raw, req.headers));
});

/**
 * After Razorpay Checkout succeeds on the phone/browser: verify order_id|payment_id signature with the
 * key secret, then mark the order paid (same path as the webhook). Needed for local test without a public URL.
 */
paymentsRouter.post('/payments/razorpay/confirm', express.json(), requireAuth, requireRole('student'), async (req, res) => {
  if (config.PAYMENT_GATEWAY !== 'razorpay') {
    throw badRequest('GATEWAY_MISMATCH', 'Server is not using the Razorpay gateway');
  }
  const body = z
    .object({
      orderId: z.union([z.number().int().positive(), z.string().regex(/^\d+$/)]),
      razorpayOrderId: z.string().min(1),
      razorpayPaymentId: z.string().min(1),
      razorpaySignature: z.string().min(1),
    })
    .parse(req.body ?? {});
  const orderId = typeof body.orderId === 'number' ? body.orderId : parseId(body.orderId);
  if (!orderId) throw badRequest('INVALID_ID', 'Invalid order id');

  if (!verifyCheckoutSignature(body.razorpayOrderId, body.razorpayPaymentId, body.razorpaySignature)) {
    throw new AppError(401, 'INVALID_SIGNATURE', 'Razorpay payment signature is not valid');
  }

  const order = await one(pool, 'SELECT * FROM orders WHERE order_id = ? AND user_id = ?', [orderId, currentUser(req).id]);
  if (!order) throw notFound('ORDER_NOT_FOUND', 'Order not found');
  if (!order.gateway_order_ref) throw conflict('NO_PAYMENT_ORDER', 'Confirm the shortage prompt before paying');
  if (order.gateway_order_ref !== body.razorpayOrderId) {
    throw conflict('ORDER_MISMATCH', 'This Razorpay order does not match the Brunchy order');
  }

  res.json(
    await applyVerifiedPayment({
      type: 'payment.captured',
      gatewayOrderRef: body.razorpayOrderId,
      gatewayPaymentRef: body.razorpayPaymentId,
      amountPaise: toPaise(order.total as number),
      upiApp: 'razorpay',
    }),
  );
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
