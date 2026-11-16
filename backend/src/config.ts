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
  DB_PORT: z.coerce.number().int().default(3306),
  DB_USER: z.string().default('brunchy'),
  DB_PASSWORD: z.string().default('brunchy'),
  DB_NAME: z.string().default('brunchy'),

  REDIS_URL: z.string().default('redis://127.0.0.1:6379/0'),

  JWT_ACCESS_SECRET: z.string().min(16, 'JWT_ACCESS_SECRET must be at least 16 characters'),
  JWT_ACCESS_MINUTES: z.coerce.number().int().positive().default(15),
  JWT_REFRESH_DAYS: z.coerce.number().int().positive().default(30),

  HOLD_MINUTES: z.coerce.number().positive().default(5),
  CONVENIENCE_FEE: z.coerce.number().min(0).default(5),

  PAYMENT_GATEWAY: z.enum(['mock']).default('mock'),
  MOCK_GATEWAY_SECRET: z.string().min(16, 'MOCK_GATEWAY_SECRET must be at least 16 characters'),

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
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error('Invalid backend settings (check backend/.env):');
  for (const issue of parsed.error.issues) console.error(`  ${issue.path.join('.')}: ${issue.message}`);
  process.exit(1);
}

export const config = parsed.data;
export const isProduction = config.NODE_ENV === 'production';

if (isProduction && (config.DEV_LOGIN || config.IGNORE_CANTEEN_HOURS)) {
  console.error('DEV_LOGIN and IGNORE_CANTEEN_HOURS must be false in production.');
  process.exit(1);
}
