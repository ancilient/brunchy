import { z } from 'zod';
import { config } from '../config.js';
import { type Db, exec, one, pool } from '../db/pool.js';

/**
 * Live app settings, changed from the admin panel (Fees & app settings). Stored as one JSON row; any key that was
 * never saved uses the default below (which comes from backend/.env, so nothing changes until an admin saves).
 * The apps read them through GET /app-config and checkout; no app release is needed.
 */
export function defaultSettings() {
  return {
    /** % of the item total, kept by Brunchy. */
    convenienceFeePct: config.CONVENIENCE_FEE_PERCENT,
    /** % of the item total, kept by Brunchy (covers the platform fee and its GST). Not on the panel's form yet. */
    platformFeePct: config.PLATFORM_FEE_PERCENT,
    canteenFeePerOrder: 0,
    vendorCommissionPct: 0,
    commissionGstPct: 18,
    minOrderValue: 0,
    freeFeeOrders: config.FREE_ORDERS_PER_STUDENT,
    instagramFreeOrder: 0,
    holdMinutes: config.HOLD_MINUTES,
    alertNewBillMinutes: 5,
    alertReadyBillMinutes: 15,
    alertPausedStallMinutes: 30,
    alertPaymentFailurePct: 20,
    alertVendorOfflineMinutes: 10,
    allowedEmailDomains: config.STUDENT_EMAIL_DOMAINS,
    maintenanceMode: false,
    orderingPaused: false,
    forceUpdate: false,
    minAppVersion: '1.0.0',
    festivalTheme: { enabled: false, name: 'Festival', primaryColor: '#FF6332', bannerUrl: null as string | null, startAt: null as string | null, endAt: null as string | null },
    adFallback: { featured: 'default', square1: 'default', square2: 'default' } as Record<'featured' | 'square1' | 'square2', 'admob' | 'default'>,
    adminIdleMinutes: 30,
    rateLimitPerMinute: 120,
    testMode: false,
    /** GST number printed on bills. Not on the panel's form yet. */
    gstin: config.GSTIN,
    supportEmail: config.SUPPORT_EMAIL,
    supportPhone: config.SUPPORT_PHONE,
    supportWhatsapp: config.SUPPORT_WHATSAPP,
  };
}

export type AppSettings = ReturnType<typeof defaultSettings>;

const num = (max?: number) => (max === undefined ? z.number().min(0) : z.number().min(0).max(max));
const isoOrNull = z.string().datetime({ offset: true }).nullable();

/** What PATCH /admin/settings accepts (every field optional). Limits from the handover (section 6.12). */
export const settingsPatch = z
  .object({
    convenienceFeePct: num(25),
    platformFeePct: num(25),
    canteenFeePerOrder: num(),
    vendorCommissionPct: num(50),
    commissionGstPct: num(28),
    minOrderValue: num(),
    freeFeeOrders: z.number().int().min(0).max(100),
    instagramFreeOrder: z.number().int().min(0).max(100),
    holdMinutes: z.number().min(1).max(30),
    alertNewBillMinutes: num(),
    alertReadyBillMinutes: num(),
    alertPausedStallMinutes: num(),
    alertPaymentFailurePct: num(100),
    alertVendorOfflineMinutes: num(),
    allowedEmailDomains: z.array(z.string().trim().toLowerCase().regex(/^[a-z0-9.-]+\.[a-z]{2,}$/, 'Domains look like college.ac.in')).max(20),
    maintenanceMode: z.boolean(),
    orderingPaused: z.boolean(),
    forceUpdate: z.boolean(),
    minAppVersion: z.string().regex(/^\d+\.\d+\.\d+$/, 'Minimum app version looks like 1.4.0'),
    festivalTheme: z
      .object({
        enabled: z.boolean(),
        name: z.string().trim().min(1).max(60),
        primaryColor: z.string().regex(/^#[0-9a-fA-F]{6}$/),
        bannerUrl: z.string().url().nullable(),
        startAt: isoOrNull,
        endAt: isoOrNull,
      })
      .refine((t) => !t.startAt || !t.endAt || Date.parse(t.endAt) > Date.parse(t.startAt), 'The festival theme must end after it starts'),
    adFallback: z.object({ featured: z.enum(['admob', 'default']), square1: z.enum(['admob', 'default']), square2: z.enum(['admob', 'default']) }),
    adminIdleMinutes: z.number().int().min(1).max(480),
    rateLimitPerMinute: z.number().int().min(1).max(10000),
    testMode: z.boolean(),
    gstin: z.string().trim().toUpperCase().regex(/^$|^[0-9]{2}[A-Z0-9]{13}$/, 'A GSTIN has 15 characters, e.g. 33ABCDE1234F1Z5'),
    supportEmail: z.string().trim().email().or(z.literal('')),
    supportPhone: z.string().trim().max(20),
    supportWhatsapp: z.string().trim().regex(/^\d{0,15}$/, 'WhatsApp number: country code and digits only'),
  })
  .partial()
  .strict();

const CACHE_MS = 5000;
let cache: { at: number; value: AppSettings } | null = null;

/**
 * Current settings (saved values over the defaults). Cached for a few seconds; saving clears the cache.
 * Code inside a transaction must pass its connection: asking the pool for a second connection while holding one can
 * exhaust the pool during a lunch rush (every checkout waiting for a connection that never frees up).
 */
export async function getSettings(db: Db = pool): Promise<AppSettings> {
  if (cache && Date.now() - cache.at < CACHE_MS) return cache.value;
  const row = await one<{ data: Partial<AppSettings> | string }>(db, 'SELECT data FROM app_settings WHERE id = 1');
  const saved = (typeof row?.data === 'string' ? JSON.parse(row.data) : row?.data) ?? {};
  const value = { ...defaultSettings(), ...saved } as AppSettings;
  cache = { at: Date.now(), value };
  return value;
}

/** Saves the changed keys (merged into the stored row) and returns old and new settings. */
export async function saveSettings(db: Db, patch: Partial<AppSettings>, userId: number) {
  const before = await getSettings(db);
  const row = await one<{ data: Partial<AppSettings> | string }>(db, 'SELECT data FROM app_settings WHERE id = 1 FOR UPDATE');
  const saved = (typeof row?.data === 'string' ? JSON.parse(row.data) : row?.data) ?? {};
  const next = { ...saved, ...patch };
  await exec(db, 'INSERT INTO app_settings (id, data, updated_by) VALUES (1, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)', [
    JSON.stringify(next),
    userId,
  ]);
  cache = null;
  return { before, after: { ...defaultSettings(), ...next } as AppSettings };
}

export function clearSettingsCache() {
  cache = null;
}
