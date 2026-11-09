import { createHash } from 'node:crypto';
import { IST_TODAY, one, pool, rows } from '../db/pool.js';
import { notFound } from '../errors.js';
import { redis } from '../redis.js';
import { canteenTakesOrders, effectiveStallStatus, iso } from '../util.js';

const MENU_CACHE_SECONDS = 30;
const LOW_STOCK = 5;

interface CanteenRow {
  canteen_id: number;
  canteen_name: string;
  opening_time: string;
  closing_time: string;
  status: 'open' | 'closed';
  last_order_minutes: number;
  latitude: number | null;
  longitude: number | null;
}

const serializeCanteen = (c: CanteenRow) => ({
  id: String(c.canteen_id),
  name: c.canteen_name,
  openingTime: c.opening_time.slice(0, 5),
  closingTime: c.closing_time.slice(0, 5),
  status: c.status,
  takingOrders: canteenTakesOrders(c),
  lastOrderMinutes: c.last_order_minutes,
  latitude: c.latitude,
  longitude: c.longitude,
});

export async function listCanteens() {
  const list = await rows<CanteenRow>(pool, 'SELECT * FROM canteens WHERE is_active = TRUE ORDER BY canteen_name');
  return { canteens: list.map(serializeCanteen) };
}

const stockState = (n: number) => (n <= 0 ? 'sold_out' : n <= LOW_STOCK ? 'low' : 'in_stock');

/** Today's published menu of one canteen (blueprint query B), grouped by stall. */
async function buildMenu(canteenId: number) {
  const canteen = await one<CanteenRow>(pool, 'SELECT * FROM canteens WHERE canteen_id = ? AND is_active = TRUE', [canteenId]);
  if (!canteen) throw notFound('CANTEEN_NOT_FOUND', 'Canteen not found');
  const stalls = await rows(pool, 'SELECT * FROM stalls WHERE canteen_id = ? AND is_active = TRUE ORDER BY stall_name', [canteenId]);
  const products = await rows(
    pool,
    `SELECT p.* FROM products p
       JOIN stalls s ON s.stall_id = p.stall_id
       JOIN daily_menu dm ON dm.product_id = p.product_id AND dm.menu_date = ${IST_TODAY}
      WHERE s.canteen_id = ? AND s.is_active = TRUE AND p.is_active = TRUE AND p.approval_status = 'published'
      ORDER BY p.product_name`,
    [canteenId],
  );
  return {
    canteen: serializeCanteen(canteen),
    stalls: stalls.map((s) => ({
      id: String(s.stall_id),
      name: s.stall_name,
      billPrefix: s.bill_prefix,
      gstRate: s.gst_rate,
      status: effectiveStallStatus(s as never),
      pausedUntil: iso(s.paused_until),
      category: s.category,
      accentColor: s.accent_color,
      iconName: s.icon_name,
      avgPrepMinutes: s.avg_prep_minutes,
      products: products
        .filter((p) => p.stall_id === s.stall_id)
        .map((p) => ({
          id: String(p.product_id),
          stallId: String(p.stall_id),
          name: p.product_name,
          category: p.category,
          description: p.description,
          price: p.price,
          isVeg: Boolean(p.is_veg),
          imageUrl: p.image_url,
          prepMinutes: p.prep_minutes,
          stockQuantity: p.stock_quantity,
          stockState: stockState(p.stock_quantity),
        })),
    })),
    generatedAt: new Date().toISOString(),
  };
}

/**
 * Served from a short Redis cache (rush-hour rule: don't hit MySQL for every menu refresh).
 * Displayed stock may be a few seconds old; checkout always re-checks real stock in MySQL.
 */
export async function getMenu(canteenId: number) {
  const key = `menu:${canteenId}`;
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached) as { etag: string; body: unknown };
  const body = await buildMenu(canteenId);
  const etag = `"${createHash('sha1').update(JSON.stringify({ ...body, generatedAt: undefined })).digest('hex')}"`;
  const entry = { etag, body };
  await redis.set(key, JSON.stringify(entry), 'EX', MENU_CACHE_SECONDS);
  return entry;
}

/** Call after anything that changes what the menu shows (stock, stall status, availability). */
export async function bustMenuCache(canteenIds: number[]) {
  const keys = [...new Set(canteenIds)].map((id) => `menu:${id}`);
  if (keys.length) await redis.del(...keys);
}
