import { config } from '../config.js';
import { mockGateway } from './mockGateway.js';

/** A payment event the gateway reports through its webhook, after the signature was verified. */
export interface PaymentEvent {
  type: 'payment.captured' | 'payment.failed';
  gatewayOrderRef: string;
  gatewayPaymentRef: string;
  amountPaise: number;
  upiApp?: string;
  failureReason?: string;
}

/**
 * Everything the backend needs from a payment gateway. The mock implements it now;
 * a Razorpay implementation (orders API + webhook signature) plugs in later without touching checkout.
 */
export interface PaymentGateway {
  name: string;
  /** Creates the gateway-side order the app pays against. Amount is in paise. */
  createOrder(input: { orderId: number; amountPaise: number }): Promise<{ gatewayOrderRef: string; clientPayload: Record<string, unknown> }>;
  /** Checks the webhook signature over the exact raw body. Never trust an unsigned body. */
  verifyWebhook(rawBody: Buffer, headers: Record<string, string | string[] | undefined>): boolean;
  /** Turns a verified webhook body into a PaymentEvent, or null for events we ignore. */
  parseWebhook(rawBody: Buffer): PaymentEvent | null;
}

export const gateway: PaymentGateway = { mock: mockGateway }[config.PAYMENT_GATEWAY];
