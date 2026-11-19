import { createHmac, timingSafeEqual } from 'node:crypto';
import { config } from '../config.js';
import { AppError } from '../errors.js';
import { logger } from '../logger.js';
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
async function razorpayPost(body: Record<string, unknown>) {
  let lastErr: unknown;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const res = await fetch(ORDERS_URL, {
        method: 'POST',
        headers: {
          Authorization: basicAuth(),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(25_000),
      });
      const json = (await res.json()) as { id?: string; error?: { description?: string; reason?: string } };
      if (res.status === 401 || res.status === 403) {
        throw new AppError(502, 'PAYMENT_CONFIG_INVALID', 'Razorpay rejected the API keys. Check RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in backend/.env');
      }
      if (!res.ok || !json.id) {
        const detail = json.error?.description ?? json.error?.reason ?? `HTTP ${res.status}`;
        throw new AppError(502, 'PAYMENT_GATEWAY_ERROR', `Razorpay could not start payment: ${detail}`);
      }
      return json;
    } catch (err) {
      if (err instanceof AppError) throw err;
      lastErr = err;
      if (attempt === 0) {
        logger.warn({ err, attempt }, 'Razorpay API call failed, retrying');
        continue;
      }
    }
  }
  logger.error({ err: lastErr }, 'Razorpay API unreachable');
  throw new AppError(
    503,
    'PAYMENT_GATEWAY_UNAVAILABLE',
    'Could not reach Razorpay. Check your internet connection and try checkout again.',
  );
}

export const razorpayGateway: PaymentGateway = {
  name: 'razorpay',

  async createOrder({ orderId, amountPaise }) {
    if (amountPaise < 100) {
      throw new AppError(400, 'PAYMENT_AMOUNT_TOO_LOW', 'Order total is too low to pay online (minimum ₹1).');
    }
    const json = await razorpayPost({
      amount: amountPaise,
      currency: 'INR',
      receipt: `brunchy_${orderId}`,
      notes: { brunchyOrderId: String(orderId) },
    });
    return {
      gatewayOrderRef: json.id!,
      clientPayload: {
        gateway: 'razorpay',
        keyId: config.RAZORPAY_KEY_ID,
        gatewayOrderRef: json.id,
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
