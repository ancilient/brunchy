import { createHmac, timingSafeEqual } from 'node:crypto';
import { config } from '../config.js';
import type { PaymentEvent, PaymentGateway } from './gateway.js';

const ORDERS_URL = 'https://api.razorpay.com/v1/orders';

function basicAuth() {
  return `Basic ${Buffer.from(`${config.RAZORPAY_KEY_ID}:${config.RAZORPAY_KEY_SECRET}`).toString('base64')}`;
}

function headerValue(headers: Record<string, string | string[] | undefined>, name: string) {
  const v = headers[name] ?? headers[name.toLowerCase()];
  return Array.isArray(v) ? v[0] : v;
}

/** HMAC-SHA256 hex digest Razorpay expects for checkout and webhook signatures. */
export function razorpayHmac(payload: string, secret: string) {
  return createHmac('sha256', secret).update(payload).digest('hex');
}

export function verifyCheckoutSignature(orderId: string, paymentId: string, signature: string) {
  const expected = razorpayHmac(`${orderId}|${paymentId}`, config.RAZORPAY_KEY_SECRET);
  if (!/^[0-9a-f]+$/i.test(signature) || signature.length !== expected.length) return false;
  return timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}

/**
 * Razorpay Orders API + webhook/checkout verification.
 * Test mode uses rzp_test_* keys from the Razorpay dashboard; no real money moves.
 */
export const razorpayGateway: PaymentGateway = {
  name: 'razorpay',

  async createOrder({ orderId, amountPaise }) {
    const res = await fetch(ORDERS_URL, {
      method: 'POST',
      headers: {
        Authorization: basicAuth(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency: 'INR',
        receipt: `brunchy_${orderId}`,
        notes: { brunchyOrderId: String(orderId) },
      }),
    });
    const body = (await res.json()) as { id?: string; error?: { description?: string } };
    if (!res.ok || !body.id) {
      throw new Error(body.error?.description ?? `Razorpay order create failed (${res.status})`);
    }
    return {
      gatewayOrderRef: body.id,
      clientPayload: {
        gateway: 'razorpay',
        keyId: config.RAZORPAY_KEY_ID,
        gatewayOrderRef: body.id,
        amountPaise,
        currency: 'INR',
        name: 'Brunchy',
        description: `Order #${orderId}`,
      },
    };
  },

  verifyWebhook(rawBody, headers) {
    const given = headerValue(headers, 'x-razorpay-signature');
    if (typeof given !== 'string' || !config.RAZORPAY_WEBHOOK_SECRET) return false;
    const expected = razorpayHmac(rawBody.toString('utf8'), config.RAZORPAY_WEBHOOK_SECRET);
    if (!/^[0-9a-f]+$/i.test(given) || given.length !== expected.length) return false;
    return timingSafeEqual(Buffer.from(given), Buffer.from(expected));
  },

  parseWebhook(rawBody) {
    const body = JSON.parse(rawBody.toString('utf8')) as {
      event?: string;
      payload?: { payment?: { entity?: Record<string, unknown> } };
    };
    const payment = body.payload?.payment?.entity;
    if (!payment || typeof payment.id !== 'string' || typeof payment.order_id !== 'string') return null;
    if (typeof payment.amount !== 'number') return null;

    if (body.event === 'payment.captured' || (body.event === 'payment.authorized' && payment.status === 'captured')) {
      return {
        type: 'payment.captured',
        gatewayOrderRef: payment.order_id,
        gatewayPaymentRef: payment.id,
        amountPaise: payment.amount,
        upiApp: typeof payment.method === 'string' ? payment.method : undefined,
      } satisfies PaymentEvent;
    }
    if (body.event === 'payment.failed') {
      const error = payment.error_description ?? payment.error_reason;
      return {
        type: 'payment.failed',
        gatewayOrderRef: payment.order_id,
        gatewayPaymentRef: payment.id,
        amountPaise: payment.amount,
        failureReason: typeof error === 'string' ? error : 'PAYMENT_FAILED',
      } satisfies PaymentEvent;
    }
    return null;
  },
};
