import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { config } from '../config.js';
import type { PaymentEvent, PaymentGateway } from './gateway.js';

export const MOCK_SIGNATURE_HEADER = 'x-mock-signature';

export const signMockBody = (rawBody: string | Buffer) =>
  createHmac('sha256', config.MOCK_GATEWAY_SECRET).update(rawBody).digest('hex');

/**
 * Fake gateway for development: same flow as a real one (create order → app pays → signed webhook),
 * but nothing is charged. The dev-only route POST /payments/mock/:orderId/pay plays the "student paid" part.
 */
export const mockGateway: PaymentGateway = {
  name: 'mock',

  async createOrder({ orderId, amountPaise }) {
    const gatewayOrderRef = `mock_order_${orderId}_${randomBytes(4).toString('hex')}`;
    return { gatewayOrderRef, clientPayload: { gateway: 'mock', gatewayOrderRef, amountPaise, currency: 'INR' } };
  },

  verifyWebhook(rawBody, headers) {
    const given = headers[MOCK_SIGNATURE_HEADER];
    if (typeof given !== 'string' || !/^[0-9a-f]{64}$/.test(given)) return false;
    return timingSafeEqual(Buffer.from(given, 'hex'), Buffer.from(signMockBody(rawBody), 'hex'));
  },

  parseWebhook(rawBody) {
    const body = JSON.parse(rawBody.toString('utf8')) as Partial<PaymentEvent>;
    if (body.type !== 'payment.captured' && body.type !== 'payment.failed') return null;
    if (!body.gatewayOrderRef || !body.gatewayPaymentRef || typeof body.amountPaise !== 'number') return null;
    return body as PaymentEvent;
  },
};
