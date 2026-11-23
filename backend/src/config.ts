import 'dotenv/config';
import { z } from 'zod';

const bool = (fallback: boolean) =>
  z
    .enum(['true', 'false'])
    .default(fallback ? 'true' : 'false')
    .transform((v) => v === 'true');

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().default(4000),
  LOG_LEVEL: z.string().default('info'),

  DB_HOST: z.string().default('127.0.0.1'),
  DB_PORT: z.coerce.number().int().default(3307), // docker-compose publishes MySQL on host port 3307
  DB_USER: z.string().default('brunchy'),
  DB_PASSWORD: z.string().default('brunchy'),
  DB_NAME: z.string().default('brunchy'),

  REDIS_URL: z.string().default('redis://127.0.0.1:6379/0'),

  JWT_ACCESS_SECRET: z.string().min(16, 'JWT_ACCESS_SECRET must be at least 16 characters'),
  JWT_ACCESS_MINUTES: z.coerce.number().int().positive().default(15),
  JWT_REFRESH_DAYS: z.coerce.number().int().positive().default(30),

  HOLD_MINUTES: z.coerce.number().positive().default(5),
  /** Old flat convenience fee (₹). No longer used: the convenience fee is CONVENIENCE_FEE_PERCENT of the items. */
  CONVENIENCE_FEE: z.coerce.number().min(0).default(0),
  /** Payable = item total + platform fee + convenience fee, each this % of the item total (no separate stall GST). */
  PLATFORM_FEE_PERCENT: z.coerce.number().min(0).default(3),
  CONVENIENCE_FEE_PERCENT: z.coerce.number().min(0).default(3),
  /** A student's first N paid orders have no platform or convenience fee. */
  FREE_ORDERS_PER_STUDENT: z.coerce.number().int().min(0).default(2),

  // Customer Care in the student app (served by GET /app-config, so they change without a new app). Empty = hidden.
  SUPPORT_EMAIL: z.string().default(''),
  SUPPORT_PHONE: z.string().default(''), // e.g. +919876543210
  SUPPORT_WHATSAPP: z.string().default(''), // e.g. 919876543210 (country code, digits only)
  /** GST number printed on bills. Empty = the bill shows a placeholder until it is registered. */
  GSTIN: z.string().default(''),

  PAYMENT_GATEWAY: z.enum(['mock', 'razorpay']).default('mock'),
  MOCK_GATEWAY_SECRET: z.string().min(16).optional(),
  // Razorpay Dashboard → API Keys (use rzp_test_* for test mode). Webhook secret is optional for local
  // checkout confirmation; set it when you expose /payments/webhook publicly.
  RAZORPAY_KEY_ID: z.string().optional(),
  RAZORPAY_KEY_SECRET: z.string().optional(),
  RAZORPAY_WEBHOOK_SECRET: z.string().optional(),

  // Google Sign-In: the OAuth "Web application" client ID(s) the apps request ID tokens for (comma separated).
  // Empty = Google sign-in is switched off (only the development login works, if enabled).
  GOOGLE_CLIENT_IDS: z
    .string()
    .default('')
    .transform((v) => v.split(',').map((s) => s.trim()).filter(Boolean)),
  // Optional: only these email domains may create student accounts (comma separated, e.g. "sathyabama.ac.in"). Empty = any.
  STUDENT_EMAIL_DOMAINS: z
    .string()
    .default('')
    .transform((v) => v.split(',').map((s) => s.trim().toLowerCase().replace(/^@/, '')).filter(Boolean)),
  // Development only: POST /auth/dev-login signs in as a demo student or a stall's vendor without Google.
  DEV_LOGIN: bool(false),
  IGNORE_CANTEEN_HOURS: bool(false),
  JOBS_ENABLED: bool(true),
  RATE_LIMIT_ENABLED: bool(true),
  // Google sign-ins per 10 minutes. Per internet address it is high on purpose: a whole campus on one Wi-Fi network
  // shares one public address. Per Google account it stays tight, which is what stops abuse.
  GOOGLE_SIGNINS_PER_IP: z.coerce.number().int().positive().default(600),
  GOOGLE_SIGNINS_PER_ACCOUNT: z.coerce.number().int().positive().default(10),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid backend settings (check backend/.env):');
  for (const issue of parsed.error.issues) console.error(`  ${issue.path.join('.')}: ${issue.message}`);
  process.exit(1);
}

export const config = {
  ...parsed.data,
  MOCK_GATEWAY_SECRET: parsed.data.MOCK_GATEWAY_SECRET ?? 'change-me-mock-gateway-secret',
  RAZORPAY_KEY_ID: parsed.data.RAZORPAY_KEY_ID ?? '',
  RAZORPAY_KEY_SECRET: parsed.data.RAZORPAY_KEY_SECRET ?? '',
  RAZORPAY_WEBHOOK_SECRET: parsed.data.RAZORPAY_WEBHOOK_SECRET ?? '',
};
export const isProduction = config.NODE_ENV === 'production';

if (config.PAYMENT_GATEWAY === 'mock' && config.MOCK_GATEWAY_SECRET.length < 16) {
  console.error('MOCK_GATEWAY_SECRET must be at least 16 characters when PAYMENT_GATEWAY=mock.');
  process.exit(1);
}
if (config.PAYMENT_GATEWAY === 'razorpay' && (!config.RAZORPAY_KEY_ID || !config.RAZORPAY_KEY_SECRET)) {
  console.error('RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are required when PAYMENT_GATEWAY=razorpay.');
  process.exit(1);
}

if (isProduction && (config.DEV_LOGIN || config.IGNORE_CANTEEN_HOURS)) {
  console.error('DEV_LOGIN and IGNORE_CANTEEN_HOURS must be false in production.');
  process.exit(1);
}
