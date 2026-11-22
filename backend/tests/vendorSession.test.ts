import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { exec, one, pool } from '../src/db/pool.js';
import { verifyAccessToken } from '../src/middleware/auth.js';
import { api, closeAll, placePaidOrder, resetDb, startServer, studentToken } from './helpers.js';

let server: Awaited<ReturnType<typeof startServer>>;
let client: ReturnType<typeof api>;

// Seed: user 2 is Burger Hub's vendor (stall 1, canteen 1). Canteen 2 has Grill Point (stall 5) and South Kitchen (6).
const VENDOR = 2;
const STALL_A = '1'; // Burger Hub, canteen 1 (users.stall_id)
const STALL_B = '5'; // Grill Point, canteen 2: access granted below
const STALL_NO_ACCESS = '6'; // South Kitchen, canteen 2: no access

/** Normal vendor login (refresh_tokens.stall_id = NULL), like Google sign-in. */
const login = async () => (await client.post('/auth/dev-login', { app: 'vendor', stallId: 1 })).body as { accessToken: string; refreshToken: string };

beforeAll(async () => {
  await resetDb();
  await exec(pool, 'INSERT INTO vendor_stall_access (user_id, stall_id) VALUES (?, ?)', [VENDOR, Number(STALL_B)]);
  server = await startServer();
  client = api(server.url);
});
afterAll(async () => {
  await server.close();
  await closeAll();
});

describe('vendor chooses a canteen and a stall', () => {
  it('seeded vendors can open their own stall', async () => {
    const row = await one(pool, 'SELECT 1 AS ok FROM vendor_stall_access WHERE user_id = ? AND stall_id = 1', [VENDOR]);
    expect(row?.ok).toBe(1);
  });

  it('a) lists only the stalls of the canteen the vendor may open', async () => {
    const { accessToken } = await login();
    const c2 = await client.get('/canteens/2/stalls', accessToken);
    expect(c2.status).toBe(200);
    expect(c2.body.stalls).toEqual([{ id: STALL_B, canteenId: '2', name: 'Grill Point' }]);
    expect(c2.body.stalls.map((s: { id: string }) => s.id)).not.toContain(STALL_NO_ACCESS);
    const c1 = await client.get('/canteens/1/stalls', accessToken);
    expect(c1.body.stalls.map((s: { id: string }) => s.id)).toEqual([STALL_A]);
  });

  it('b, c, d) the session for stall B is scoped to B everywhere, and stays on B after refresh', async () => {
    const { accessToken } = await login();
    const r = await client.post('/vendor/session/stall', { stallId: STALL_B, date: '2026-11-22' }, accessToken);
    expect(r.status).toBe(200);
    expect(r.body.stall).toEqual({ id: STALL_B, name: 'Grill Point', canteenId: '2', canteenName: expect.any(String) });
    // b) the token carries the chosen stall and its canteen
    expect(verifyAccessToken(r.body.accessToken)).toMatchObject({ id: VENDOR, role: 'vendor', stallId: 5, canteenId: 2 });

    // c) /vendor/stall and /vendor/bills answer for stall B, not stall A
    const stall = await client.get('/vendor/stall', r.body.accessToken);
    expect(stall.body.stall).toMatchObject({ id: STALL_B, canteenId: '2' });
    const order = await placePaidOrder(client, studentToken(), [{ productId: '501', qty: 1 }], '2'); // Grill Point item
    const billsB = await client.get('/vendor/bills', r.body.accessToken);
    expect(billsB.body.bills.map((b: { id: string }) => b.id)).toContain(order.bills[0].id);
    expect(billsB.body.bills.every((b: { stallId: string }) => b.stallId === STALL_B)).toBe(true);
    const billsA = await client.get('/vendor/bills', accessToken);
    expect(billsA.body.bills.map((b: { id: string }) => b.id)).not.toContain(order.bills[0].id);

    // d) refresh keeps the session on stall B
    const refreshed = await client.post('/auth/refresh', { refreshToken: r.body.refreshToken });
    expect(refreshed.status).toBe(200);
    expect(verifyAccessToken(refreshed.body.accessToken)).toMatchObject({ stallId: 5, canteenId: 2 });
    const again = await client.post('/auth/refresh', { refreshToken: refreshed.body.refreshToken });
    expect(verifyAccessToken(again.body.accessToken)).toMatchObject({ stallId: 5, canteenId: 2 });

    const audited = await one(pool, "SELECT actor_user_id FROM audit_log WHERE action = 'vendor_session_stall' AND record_id = 5");
    expect(audited?.actor_user_id).toBe(VENDOR);
  });

  it('e) a stall without access is refused; an unknown stall is not found', async () => {
    const { accessToken } = await login();
    const denied = await client.post('/vendor/session/stall', { stallId: STALL_NO_ACCESS }, accessToken);
    expect(denied.status).toBe(403);
    expect(denied.body.error).toEqual({ code: 'STALL_NOT_ALLOWED', message: 'You are not allowed to open this stall' });
    const missing = await client.post('/vendor/session/stall', { stallId: '999' }, accessToken);
    expect(missing.status).toBe(404);
    expect(missing.body.error.code).toBe('STALL_NOT_FOUND');
    const bad = await client.post('/vendor/session/stall', { stallId: 'abc' }, accessToken);
    expect(bad.body.error.code).toBe('INVALID_ID');
  });

  it('f) a refresh token from a normal login still refreshes to users.stall_id', async () => {
    const { refreshToken } = await login();
    const r = await client.post('/auth/refresh', { refreshToken });
    expect(verifyAccessToken(r.body.accessToken)).toMatchObject({ stallId: 1, canteenId: 1 });
  });

  it('if access to the chosen stall is removed, refresh falls back to users.stall_id', async () => {
    const { accessToken } = await login();
    const session = await client.post('/vendor/session/stall', { stallId: STALL_B }, accessToken);
    await exec(pool, 'DELETE FROM vendor_stall_access WHERE user_id = ? AND stall_id = ?', [VENDOR, Number(STALL_B)]);
    try {
      const r = await client.post('/auth/refresh', { refreshToken: session.body.refreshToken });
      expect(verifyAccessToken(r.body.accessToken)).toMatchObject({ stallId: 1, canteenId: 1 });
    } finally {
      await exec(pool, 'INSERT INTO vendor_stall_access (user_id, stall_id) VALUES (?, ?)', [VENDOR, Number(STALL_B)]);
    }
  });

  it('g) a student gets 403 on both new endpoints', async () => {
    expect((await client.get('/canteens/2/stalls', studentToken())).status).toBe(403);
    expect((await client.post('/vendor/session/stall', { stallId: STALL_B }, studentToken())).status).toBe(403);
  });

  it("h) unknown canteen: 404 CANTEEN_NOT_FOUND (never the app's 'endpoint missing' code)", async () => {
    const { accessToken } = await login();
    const r = await client.get('/canteens/999/stalls', accessToken);
    expect(r.status).toBe(404);
    expect(r.body.error.code).toBe('CANTEEN_NOT_FOUND');
    expect(r.body.error.code).not.toBe('NOT_FOUND');
    expect((await client.get('/canteens/x/stalls', accessToken)).body.error.code).toBe('INVALID_ID');
  });
});
