import { createHash, randomBytes } from 'node:crypto';
import { OAuth2Client } from 'google-auth-library';
import { config } from '../config.js';
import { exec, isDuplicateKey, one, pool, rows } from '../db/pool.js';
import { AppError, badRequest, forbidden, notFound, unauthorized } from '../errors.js';
import { type AuthUser, type Role, signAccessToken } from '../middleware/auth.js';
import { hitRateLimit } from '../middleware/rateLimit.js';
import { idStr } from '../util.js';
import { audit } from './audit.js';

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

/** The stall a vendor session is opened for (POST /vendor/session/stall). Without it, users.stall_id is used. */
export interface StallScope {
  stallId: number;
  canteenId: number;
}

async function issueTokens(user: UserRow, scope?: StallScope) {
  const refreshToken = randomBytes(32).toString('hex');
  await exec(
    pool,
    'INSERT INTO refresh_tokens (token_hash, user_id, stall_id, expires_at) VALUES (?, ?, ?, UTC_TIMESTAMP() + INTERVAL ? DAY)',
    [sha256(refreshToken), user.user_id, scope?.stallId ?? null, config.JWT_REFRESH_DAYS],
  );
  const authUser = scope ? { ...toAuthUser(user), stallId: scope.stallId, canteenId: scope.canteenId } : toAuthUser(user);
  const userJson = scope ? { ...serializeUser(user), stallId: String(scope.stallId), canteenId: String(scope.canteenId) } : serializeUser(user);
  return { accessToken: signAccessToken(authUser), refreshToken, user: userJson };
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
  // Counted per Google account once Google has confirmed who it is (the per-address limit is set high for campuses).
  await hitRateLimit('google-account', config.GOOGLE_SIGNINS_PER_ACCOUNT, 600, g.sub);
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
  const row = await one<{ user_id: number; stall_id: number | null }>(pool, 'SELECT user_id, stall_id FROM refresh_tokens WHERE token_hash = ?', [hash]);
  const user = await findUserById(row!.user_id);
  if (!user) throw unauthorized();
  // A session opened for a chosen stall stays on that stall while the vendor may still open it (and it is active);
  // otherwise (old tokens, or access removed) it falls back to users.stall_id as before.
  const stall = row!.stall_id ? await accessibleStall(user.user_id, row!.stall_id) : undefined;
  return issueTokens(user, stall ? { stallId: stall.stall_id, canteenId: stall.canteen_id } : undefined);
}

// ---------------------------------------------------------------- vendor: choose canteen and stall

interface AccessibleStallRow {
  stall_id: number;
  stall_name: string;
  canteen_id: number;
  canteen_name: string;
}

/** The stall, if it is active and this vendor has a vendor_stall_access row for it. */
const accessibleStall = (userId: number, stallId: number) =>
  one<AccessibleStallRow>(
    pool,
    `SELECT s.stall_id, s.stall_name, s.canteen_id, c.canteen_name
       FROM vendor_stall_access a
       JOIN stalls s ON s.stall_id = a.stall_id
       JOIN canteens c ON c.canteen_id = s.canteen_id
      WHERE a.user_id = ? AND a.stall_id = ? AND s.is_active = TRUE`,
    [userId, stallId],
  );

/** GET /canteens/:id/stalls: the active stalls of the canteen this vendor may open. 404 for an unknown canteen. */
export async function listVendorStalls(userId: number, canteenId: number) {
  // Never the generic 'NOT_FOUND' code: the vendor app reads 404 + NOT_FOUND as "this endpoint does not exist yet".
  const canteen = await one(pool, 'SELECT canteen_id FROM canteens WHERE canteen_id = ? AND is_active = TRUE', [canteenId]);
  if (!canteen) throw notFound('CANTEEN_NOT_FOUND', 'Canteen not found');
  const stalls = await rows<{ stall_id: number; canteen_id: number; stall_name: string }>(
    pool,
    `SELECT s.stall_id, s.canteen_id, s.stall_name
       FROM stalls s JOIN vendor_stall_access a ON a.stall_id = s.stall_id AND a.user_id = ?
      WHERE s.canteen_id = ? AND s.is_active = TRUE
      ORDER BY s.stall_name`,
    [userId, canteenId],
  );
  return { stalls: stalls.map((s) => ({ id: String(s.stall_id), canteenId: String(s.canteen_id), name: s.stall_name })) };
}

/**
 * POST /vendor/session/stall: a new token pair scoped to the chosen stall. Every /vendor/* endpoint, the reports and
 * the socket room read stallId from the access token, so they follow the choice without changes.
 * forceTakeover is accepted for the app's "Take over?" flow; stalls are not exclusively claimed yet.
 */
export async function openVendorStallSession(user: AuthUser, stallId: number) {
  const stall = await one<{ stall_id: number; is_active: number }>(pool, 'SELECT stall_id, is_active FROM stalls WHERE stall_id = ?', [stallId]);
  if (!stall || !stall.is_active) throw notFound('STALL_NOT_FOUND', 'Stall not found');
  const allowed = await accessibleStall(user.id, stallId);
  if (!allowed) throw forbidden('STALL_NOT_ALLOWED', 'You are not allowed to open this stall');
  const row = await findUserById(user.id);
  if (!row) throw unauthorized();
  const tokens = await issueTokens(row, { stallId: allowed.stall_id, canteenId: allowed.canteen_id });
  await audit(pool, { id: user.id, role: user.role }, 'vendor_session_stall', 'stalls', stallId, { stallId: user.stallId }, { stallId });
  return {
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    stall: {
      id: String(allowed.stall_id),
      name: allowed.stall_name,
      canteenId: String(allowed.canteen_id),
      canteenName: allowed.canteen_name,
    },
  };
}

export async function logout(refreshToken: string) {
  await exec(pool, 'UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE token_hash = ? AND revoked_at IS NULL', [
    sha256(refreshToken),
  ]);
}
