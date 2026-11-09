import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { config } from '../config.js';
import { exec, one, pool } from '../db/pool.js';
import { AppError, badRequest, unauthorized } from '../errors.js';
import { logger } from '../logger.js';
import { type AuthUser, type Role, signAccessToken } from '../middleware/auth.js';
import { redis } from '../redis.js';
import { idStr } from '../util.js';

const OTP_TTL_SECONDS = 300;
const OTP_MAX_ATTEMPTS = 5;
const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

export interface UserRow {
  user_id: number;
  name: string;
  phone: string | null;
  register_no: string | null;
  email: string | null;
  role: Role;
  stall_id: number | null;
  canteen_id: number | null;
  no_show_count: number;
  ordering_paused_until: Date | null;
  is_active: number;
}

export const toAuthUser = (u: UserRow): AuthUser => ({ id: u.user_id, role: u.role, stallId: u.stall_id, canteenId: u.canteen_id });

export const serializeUser = (u: UserRow) => ({
  id: String(u.user_id),
  name: u.name,
  phone: u.phone,
  registerNo: u.register_no,
  role: u.role,
  stallId: idStr(u.stall_id),
  canteenId: idStr(u.canteen_id),
  noShowCount: u.no_show_count,
  orderingPausedUntil: u.ordering_paused_until?.toISOString() ?? null,
});

export const findUserById = (id: number) => one<UserRow>(pool, 'SELECT * FROM users WHERE user_id = ? AND is_active = TRUE', [id]);

/** Creates a one-time code for the phone. Milestone 1 logs it instead of sending an SMS. */
export async function requestOtp(phone: string) {
  const code = String(randomInt(100000, 1000000));
  await redis.set(`otp:${phone}`, JSON.stringify({ hash: sha256(code), attempts: 0 }), 'EX', OTP_TTL_SECONDS);
  // TODO(SMS milestone): send via the SMS provider instead of logging.
  logger.info({ phone }, `OTP for ${phone}: ${code}`);
  return { expiresInSeconds: OTP_TTL_SECONDS, ...(config.OTP_DEV_ECHO ? { devCode: code } : {}) };
}

async function checkOtp(phone: string, code: string) {
  const key = `otp:${phone}`;
  const raw = await redis.get(key);
  if (!raw) throw badRequest('OTP_EXPIRED', 'This code has expired. Ask for a new one.');
  const entry = JSON.parse(raw) as { hash: string; attempts: number };
  const ok = timingSafeEqual(Buffer.from(entry.hash), Buffer.from(sha256(code)));
  if (!ok) {
    entry.attempts += 1;
    if (entry.attempts >= OTP_MAX_ATTEMPTS) {
      await redis.del(key);
      throw badRequest('OTP_LOCKED', 'Too many wrong codes. Ask for a new one.');
    }
    await redis.set(key, JSON.stringify(entry), 'KEEPTTL');
    throw badRequest('OTP_WRONG', 'That code is not right. Please check and try again.', {
      attemptsLeft: OTP_MAX_ATTEMPTS - entry.attempts,
    });
  }
  await redis.del(key);
}

async function issueTokens(user: UserRow) {
  const refreshToken = randomBytes(32).toString('hex');
  await exec(pool, 'INSERT INTO refresh_tokens (token_hash, user_id, expires_at) VALUES (?, ?, UTC_TIMESTAMP() + INTERVAL ? DAY)', [
    sha256(refreshToken),
    user.user_id,
    config.JWT_REFRESH_DAYS,
  ]);
  return { accessToken: signAccessToken(toAuthUser(user)), refreshToken, user: serializeUser(user) };
}

/** Verifies the code. A new phone number becomes a student account (name required); vendors are created by the admin. */
export async function verifyOtp(input: { phone: string; code: string; name?: string; registerNo?: string }) {
  await checkOtp(input.phone, input.code);
  let user = await one<UserRow>(pool, 'SELECT * FROM users WHERE phone = ?', [input.phone]);
  if (user && !user.is_active) throw new AppError(403, 'ACCOUNT_DISABLED', 'This account is disabled.');
  if (!user) {
    if (!input.name) throw badRequest('NAME_REQUIRED', 'Please enter your name to create your account.');
    try {
      const result = await exec(pool, "INSERT INTO users (name, phone, register_no, role) VALUES (?, ?, ?, 'student')", [
        input.name.trim(),
        input.phone,
        input.registerNo?.trim() || null,
      ]);
      user = await findUserById(result.insertId);
    } catch (err) {
      if ((err as { code?: string }).code === 'ER_DUP_ENTRY') throw badRequest('REGISTER_NO_TAKEN', 'This register number is already used.');
      throw err;
    }
  }
  return issueTokens(user!);
}

/** Swaps a refresh token for a new pair. The old refresh token stops working (rotation). */
export async function refresh(refreshToken: string) {
  const hash = sha256(refreshToken);
  const result = await exec(
    pool,
    'UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE token_hash = ? AND revoked_at IS NULL AND expires_at > UTC_TIMESTAMP()',
    [hash],
  );
  if (result.affectedRows !== 1) throw unauthorized('Your session has expired. Please log in again.');
  const row = await one<{ user_id: number }>(pool, 'SELECT user_id FROM refresh_tokens WHERE token_hash = ?', [hash]);
  const user = await findUserById(row!.user_id);
  if (!user) throw unauthorized();
  return issueTokens(user);
}

export async function logout(refreshToken: string) {
  await exec(pool, 'UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE token_hash = ? AND revoked_at IS NULL', [
    sha256(refreshToken),
  ]);
}
