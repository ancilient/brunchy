import { type Db, one } from '../db/pool.js';
import { getSettings } from './settings.js';

/** Replaced in tests, so most tests can keep fees on while one test checks the free first orders. */
let freeOrdersOverride: number | null = null;
export function setFreeOrdersForTests(n: number | null) {
  freeOrdersOverride = n;
}

/** The fee rules as the apps show them (GET /app-config). Changed live from the admin panel (Fees & offers). */
export async function feeRules(db?: Db) {
  const s = await getSettings(db);
  return {
    platformPercent: s.platformFeePct,
    conveniencePercent: s.convenienceFeePct,
    freeOrdersPerStudent: freeOrdersOverride ?? s.freeFeeOrders,
  };
}

/** How many of the student's paid orders count towards the free first orders (excluding `exceptOrderId`). */
export async function paidOrderCount(db: Db, userId: number, exceptOrderId = 0) {
  const r = await one<{ n: number }>(db, "SELECT COUNT(*) AS n FROM orders WHERE user_id = ? AND status = 'paid' AND order_id <> ?", [
    userId,
    exceptOrderId,
  ]);
  return Number(r?.n ?? 0);
}

/** Free orders the student still has (for the cart preview and the profile). */
export async function freeOrdersLeft(db: Db, userId: number) {
  return Math.max(0, (await feeRules(db)).freeOrdersPerStudent - (await paidOrderCount(db, userId)));
}

/**
 * Platform and convenience fee for an item total (paise). Zero for a student's first N paid orders.
 * Decided when the order is created/recalculated (before payment), so a later settings change never re-prices it.
 */
export async function feesFor(db: Db, userId: number, orderId: number, subtotalPaise: number) {
  const rules = await feeRules(db); // db may be the caller's transaction connection
  const waived = (await paidOrderCount(db, userId, orderId)) < rules.freeOrdersPerStudent;
  if (waived) return { waived, platformPaise: 0, conveniencePaise: 0 };
  return {
    waived,
    platformPaise: Math.round((subtotalPaise * rules.platformPercent) / 100),
    conveniencePaise: Math.round((subtotalPaise * rules.conveniencePercent) / 100),
  };
}

/** Splits `totalPaise` across parts in proportion to `weights`; the last part takes the rounding. */
export function splitByWeight(totalPaise: number, weights: number[]) {
  const sum = weights.reduce((s, w) => s + w, 0);
  let left = totalPaise;
  return weights.map((w, i) => {
    const share = i === weights.length - 1 ? left : sum > 0 ? Math.floor((totalPaise * w) / sum) : 0;
    left -= share;
    return share;
  });
}
