import { config } from './config.js';

/** Money is handled in whole paise inside the server, so ₹84.00000001 can never happen. */
export const toPaise = (rupees: number) => Math.round(rupees * 100);
export const toRupees = (paise: number) => Math.round(paise) / 100;

/** Bill tax per blueprint 10.3: sum of price x qty x gst_rate / 100, rounded to 2 decimals. Returned in paise. */
export function billTaxPaise(lines: { pricePaise: number; quantity: number; gstRate: number }[]) {
  const raw = lines.reduce((sum, l) => sum + (l.pricePaise * l.quantity * l.gstRate) / 100, 0);
  return Math.round(raw);
}

const IST_OFFSET_MINUTES = 5 * 60 + 30;

/** Minutes since midnight in India for the given UTC instant. */
export function istMinutesOfDay(now = new Date()) {
  const m = now.getUTCHours() * 60 + now.getUTCMinutes() + IST_OFFSET_MINUTES;
  return m % (24 * 60);
}

const timeToMinutes = (t: string) => {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + m;
};

export interface CanteenHours {
  status: 'open' | 'closed';
  opening_time: string;
  closing_time: string;
  last_order_minutes: number;
}

/** A canteen takes orders when it is open and before closing time minus the last-order window. */
export function canteenTakesOrders(c: CanteenHours, now = new Date()) {
  if (c.status !== 'open') return false;
  if (config.IGNORE_CANTEEN_HOURS) return true;
  const minute = istMinutesOfDay(now);
  return minute >= timeToMinutes(c.opening_time) && minute < timeToMinutes(c.closing_time) - c.last_order_minutes;
}

export interface StallState {
  status: 'open' | 'paused' | 'closed';
  paused_until: Date | null;
}

/** A paused stall reopens by itself when paused_until has passed. */
export function effectiveStallStatus(s: StallState, now = new Date()): 'open' | 'paused' | 'closed' {
  if (s.status === 'paused' && s.paused_until && s.paused_until.getTime() <= now.getTime()) return 'open';
  return s.status;
}

export const iso = (d: Date | null | undefined) => (d ? d.toISOString() : null);
export const idStr = (n: number | null | undefined) => (n === null || n === undefined ? null : String(n));

/** Converts a path/body id ("42") to a positive integer, or null. */
export function parseId(value: unknown): number | null {
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : null;
}
