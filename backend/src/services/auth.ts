import { createHash, randomBytes } from 'node:crypto';
import { OAuth2Client } from 'google-auth-library';
import { config } from '../config.js';
import { exec, isDuplicateKey, one, pool } from '../db/pool.js';
import { AppError, badRequest, forbidden, notFound, unauthorized } from '../errors.js';
import { type AuthUser, type Role, signAccessToken } from '../middleware/auth.js';
import { idStr } from '../util.js';

const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

export type AppKind = 'student' | 'vendor';

export interface UserRow {
  user_id: number;
  name: string;
  phone: string | null;
  register_no: string | null;
  email: string | null;
  google_sub: string | null;
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
  email: u.email,
  phone: u.phone,
  registerNo: u.register_no,
  role: u.role,
  stallId: idStr(u.stall_id),
  canteenId: idStr(u.canteen_id),
  noShowCount: u.no_show_count,
  orderingPausedUntil: u.ordering_paused_until?.toISOString() ?? null,
});

export const findUserById = (id: number) => one<UserRow>(pool, 'SELECT * FROM users WHERE user_id = ? AND is_active = TRUE', [id]);

/**
 * What the apps need to draw the login screen. The Web client ID is public (it is in every Google sign-in request),
 * so serving it here means the apps don't need it built in.
 */
export const loginOptions = () => ({
  google: config.GOOGLE_CLIENT_IDS.length > 0,
  googleClientId: config.GOOGLE_CLIENT_IDS[0] ?? null,
  devLogin: config.DEV_LOGIN,
});

async function issueTokens(user: UserRow) {
  const refreshToken = randomBytes(32).toString('hex');
  await exec(pool, 'INSERT INTO refresh_tokens (token_hash, user_id, expires_at) VALUES (?, ?, UTC_TIMESTAMP() + INTERVAL ? DAY)', [
    sha256(refreshToken),
    user.user_id,
    config.JWT_REFRESH_DAYS,
  ]);
  return { accessToken: signAccessToken(toAuthUser(user)), refreshToken, user: serializeUser(user) };
}

/** A student account can't sign in to the vendor app and the other way round. */
function checkApp(user: UserRow, app: AppKind) {
  if (!user.is_active) throw new AppError(403, 'ACCOUNT_DISABLED', 'This account is disabled.');
  if (app === 'vendor' && user.role !== 'vendor') {
    throw forbidden('NOT_A_VENDOR', 'This Google account is not registered to a stall. Ask the canteen manager to add it.');
  }
  if (app === 'student' && user.role !== 'student') {
    throw forbidden('WRONG_APP', 'This account belongs to a stall. Please use the Brunchy Vendor app.');
  }
}

// ---------------------------------------------------------------- Google Sign-In

export interface GoogleIdentity {
  sub: string;
  email: string;
  emailVerified: boolean;
  name: string;
}

const googleClient = new OAuth2Client();

/** Checks the ID token's signature, expiry and audience with Google's public keys. Replaced in tests. */
let verifyGoogleToken = async (idToken: string): Promise<GoogleIdentity> => {
  if (!config.GOOGLE_CLIENT_IDS.length) throw new AppError(503, 'GOOGLE_NOT_CONFIGURED', 'Google sign-in is not set up on the server yet.');
  try {
    const ticket = await googleClient.verifyIdToken({ idToken, audience: config.GOOGLE_CLIENT_IDS });
    const p = ticket.getPayload();
    if (!p?.sub || !p.email) throw new Error('token has no sub/email');
    return { sub: p.sub, email: p.email.toLowerCase(), emailVerified: Boolean(p.email_verified), name: p.name ?? p.email.split('@')[0] };
  } catch {
    throw unauthorized('Google sign-in failed. Please try again.');
  }
};

export function setGoogleVerifierForTests(fn: typeof verifyGoogleToken) {
  verifyGoogleToken = fn;
}

/**
 * Sign in with Google (free, replaces phone + OTP).
 * The app sends Google's ID token; we verify it, then find the account by Google id, or by email for accounts the admin
 * created in advance (vendors). A new Google account becomes a student, but only from the student app.
 */
export async function signInWithGoogle(idToken: string, app: AppKind) {
  const g = await verifyGoogleToken(idToken);
  if (!g.emailVerified) throw forbidden('EMAIL_NOT_VERIFIED', 'Verify your Google account email first.');

  let user =
    (await one<UserRow>(pool, 'SELECT * FROM users WHERE google_sub = ?', [g.sub])) ??
    (await one<UserRow>(pool, 'SELECT * FROM users WHERE email = ?', [g.email]));

  if (user) {
    if (user.google_sub && user.google_sub !== g.sub) throw forbidden('ACCOUNT_MISMATCH', 'This email is linked to a different Google account.');
    checkApp(user, app);
    if (!user.google_sub || user.email !== g.email) {
      await exec(pool, 'UPDATE users SET google_sub = ?, email = ? WHERE user_id = ?', [g.sub, g.email, user.user_id]);
      user = (await findUserById(user.user_id))!;
    }
    return issueTokens(user);
  }

  if (app === 'vendor') {
    throw forbidden('NOT_A_VENDOR', 'This Google account is not registered to a stall. Ask the canteen manager to add it.');
  }
  const domain = g.email.split('@')[1];
  if (config.STUDENT_EMAIL_DOMAINS.length && !config.STUDENT_EMAIL_DOMAINS.includes(domain)) {
    throw forbidden('EMAIL_DOMAIN_NOT_ALLOWED', `Please sign in with your university email (${config.STUDENT_EMAIL_DOMAINS.map((d) => '@' + d).join(', ')}).`);
  }
  try {
    const r = await exec(pool, "INSERT INTO users (name, email, google_sub, role) VALUES (?, ?, ?, 'student')", [g.name, g.email, g.sub]);
    return issueTokens((await findUserById(r.insertId))!);
  } catch (err) {
    if (isDuplicateKey(err)) {
      // the same person signed in twice at the same moment: use the account the other request created
      const existing = await one<UserRow>(pool, 'SELECT * FROM users WHERE google_sub = ?', [g.sub]);
      if (existing) return issueTokens(existing);
    }
    throw err;
  }
}

// ---------------------------------------------------------------- development login

/**
 * DEVELOPMENT ONLY (DEV_LOGIN=true): sign in without Google, as the demo student or as the vendor of a stall.
 * Lets teammates and the automated tests work before the Google Cloud project exists. Refused in production.
 */
export async function devLogin(app: AppKind, stallId?: number) {
  if (!config.DEV_LOGIN) throw notFound('NOT_FOUND', 'No such endpoint');
  const user =
    app === 'vendor'
      ? await one<UserRow>(pool, "SELECT * FROM users WHERE role = 'vendor' AND stall_id = ? AND is_active = TRUE ORDER BY user_id LIMIT 1", [stallId ?? 1])
      : await one<UserRow>(pool, "SELECT * FROM users WHERE role = 'student' AND is_active = TRUE ORDER BY user_id LIMIT 1");
  if (!user) throw badRequest('NO_DEMO_ACCOUNT', 'No demo account found. Run npm run db:reset.');
  return issueTokens(user);
}

// ---------------------------------------------------------------- sessions

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
