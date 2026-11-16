import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { exec, one, pool } from '../src/db/pool.js';
import { type GoogleIdentity, setGoogleVerifierForTests } from '../src/services/auth.js';
import { api, closeAll, resetDb, startServer } from './helpers.js';

let server: Awaited<ReturnType<typeof startServer>>;
let client: ReturnType<typeof api>;

/** Stand-in for Google: the "ID token" names an identity defined here. Real tokens are checked with Google's keys. */
const identities: Record<string, GoogleIdentity> = {
  'token-new-student': { sub: 'g-111', email: 'asha.kumar@gmail.com', emailVerified: true, name: 'Asha Kumar' },
  'token-burger-vendor': { sub: 'g-222', email: 'burger.vendor@example.com', emailVerified: true, name: 'Burger Hub' },
  'token-unverified': { sub: 'g-333', email: 'someone@gmail.com', emailVerified: false, name: 'Someone' },
  'token-other-sub-same-email': { sub: 'g-999', email: 'asha.kumar@gmail.com', emailVerified: true, name: 'Asha' },
  'token-stranger': { sub: 'g-444', email: 'stranger@gmail.com', emailVerified: true, name: 'Stranger' },
};

beforeAll(async () => {
  await resetDb();
  // Burger Hub's vendor (user 2) is registered by email, like `npm run vendor:email -- 1 burger.vendor@example.com`.
  await exec(pool, "UPDATE users SET email = 'burger.vendor@example.com' WHERE user_id = 2");
  server = await startServer();
  client = api(server.url);
});
beforeEach(() => {
  setGoogleVerifierForTests(async (idToken) => {
    const id = identities[idToken.replace(/^x+/, '')];
    if (!id) throw Object.assign(new Error('bad token'), {});
    return id;
  });
});
afterAll(async () => {
  await server.close();
  await closeAll();
});

const google = (token: string, app: 'student' | 'vendor') => client.post('/auth/google', { idToken: 'x'.repeat(20) + token, app });

describe('Sign in with Google', () => {
  it('tells the apps which sign-in buttons to show', async () => {
    const r = await client.get('/auth/options');
    expect(r.body).toEqual({ google: true, googleClientId: 'test-web-client-id.apps.googleusercontent.com', devLogin: true });
  });

  it('a new Google account becomes a student (student app only)', async () => {
    const r = await google('token-new-student', 'student');
    expect(r.status).toBe(200);
    expect(r.body.user).toMatchObject({ role: 'student', name: 'Asha Kumar', email: 'asha.kumar@gmail.com' });
    const me = await client.get('/me', r.body.accessToken);
    expect(me.body.user.email).toBe('asha.kumar@gmail.com');
    // Signing in again finds the same account.
    const again = await google('token-new-student', 'student');
    expect(again.body.user.id).toBe(r.body.user.id);
  });

  it('a vendor signs in with the Google account registered for the stall; the Google id is linked', async () => {
    const r = await google('token-burger-vendor', 'vendor');
    expect(r.status).toBe(200);
    expect(r.body.user).toMatchObject({ role: 'vendor', stallId: '1', id: '2' });
    const row = await one(pool, 'SELECT google_sub FROM users WHERE user_id = 2');
    expect(row?.google_sub).toBe('g-222');
  });

  it('a student account cannot sign in to the vendor app, and a vendor account not to the student app', async () => {
    const studentInVendorApp = await google('token-new-student', 'vendor');
    expect(studentInVendorApp.body.error.code).toBe('NOT_A_VENDOR');
    const vendorInStudentApp = await google('token-burger-vendor', 'student');
    expect(vendorInStudentApp.body.error.code).toBe('WRONG_APP');
  });

  it('an unknown Google account cannot become a vendor', async () => {
    const r = await google('token-stranger', 'vendor');
    expect(r.status).toBe(403);
    expect(r.body.error.code).toBe('NOT_A_VENDOR');
    const created = await one(pool, "SELECT COUNT(*) AS n FROM users WHERE email = 'stranger@gmail.com'");
    expect(Number(created?.n)).toBe(0);
  });

  it('refuses unverified Google emails and a different Google account using a known email', async () => {
    expect((await google('token-unverified', 'student')).body.error.code).toBe('EMAIL_NOT_VERIFIED');
    expect((await google('token-other-sub-same-email', 'student')).body.error.code).toBe('ACCOUNT_MISMATCH');
  });

  it('rejects a token Google does not accept', async () => {
    const r = await google('token-forged', 'student');
    expect(r.status).toBeGreaterThanOrEqual(400);
  });
});

describe('sessions and development login', () => {
  it('dev login gives the demo student or a stall vendor (development only)', async () => {
    const s = await client.post('/auth/dev-login', { app: 'student' });
    expect(s.body.user).toMatchObject({ role: 'student', name: 'Demo Student' });
    const v = await client.post('/auth/dev-login', { app: 'vendor', stallId: 2 });
    expect(v.body.user).toMatchObject({ role: 'vendor', stallId: '2' });
  });

  it('rotates refresh tokens: an old one stops working', async () => {
    const login = await client.post('/auth/dev-login', { app: 'student' });
    const first = await client.post('/auth/refresh', { refreshToken: login.body.refreshToken });
    expect(first.status).toBe(200);
    const reused = await client.post('/auth/refresh', { refreshToken: login.body.refreshToken });
    expect(reused.status).toBe(401);
  });

  it('rejects requests without a valid token', async () => {
    expect((await client.get('/canteens')).status).toBe(401);
    expect((await client.get('/canteens', 'not-a-token')).status).toBe(401);
  });

  it("serves canteens and today's menu", async () => {
    const { body } = await client.post('/auth/dev-login', { app: 'student' });
    const canteens = await client.get('/canteens', body.accessToken);
    expect(canteens.body.canteens.map((c: { name: string }) => c.name)).toEqual(['Advance Block Canteen', 'Main Canteen']);
    const menu = await client.get('/canteens/1/menu', body.accessToken);
    const burgerHub = menu.body.stalls.find((s: { name: string }) => s.name === 'Burger Hub');
    expect(burgerHub.products.find((p: { name: string }) => p.name === 'Chicken Burger').stockState).toBe('sold_out');
  });
});
