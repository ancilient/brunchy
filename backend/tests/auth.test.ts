import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { api, closeAll, resetDb, startServer } from './helpers.js';

let server: Awaited<ReturnType<typeof startServer>>;
let client: ReturnType<typeof api>;

beforeAll(async () => {
  await resetDb();
  server = await startServer();
  client = api(server.url);
});
afterAll(async () => {
  await server.close();
  await closeAll();
});

async function otp(phone: string) {
  const r = await client.post('/auth/otp', { phone });
  expect(r.status).toBe(200);
  return r.body.devCode as string;
}

describe('OTP login', () => {
  it('logs in an existing vendor with the stall in the token', async () => {
    const code = await otp('9000000001');
    const r = await client.post('/auth/verify', { phone: '9000000001', code });
    expect(r.status).toBe(200);
    expect(r.body.user).toMatchObject({ role: 'vendor', stallId: '1' });
    const me = await client.get('/me', r.body.accessToken);
    expect(me.body.user.name).toBe('Burger Hub Staff');
  });

  it('creates a student account for a new phone, asking for a name', async () => {
    const code = await otp('8123456789');
    const noName = await client.post('/auth/verify', { phone: '8123456789', code });
    expect(noName.body.error.code).toBe('NAME_REQUIRED');
    const code2 = await otp('8123456789');
    const r = await client.post('/auth/verify', { phone: '8123456789', code: code2, name: 'Asha Kumar', registerNo: '41119999' });
    expect(r.body.user).toMatchObject({ role: 'student', name: 'Asha Kumar' });
  });

  it('a wrong code is refused and the code works only once', async () => {
    const code = await otp('9876543210');
    const wrong = await client.post('/auth/verify', { phone: '9876543210', code: code === '111111' ? '222222' : '111111' });
    expect(wrong.body.error.code).toBe('OTP_WRONG');
    const ok = await client.post('/auth/verify', { phone: '9876543210', code });
    expect(ok.status).toBe(200);
    const reuse = await client.post('/auth/verify', { phone: '9876543210', code });
    expect(reuse.body.error.code).toBe('OTP_EXPIRED');
  });

  it('rotates refresh tokens: an old one stops working', async () => {
    const code = await otp('9876543210');
    const login = await client.post('/auth/verify', { phone: '9876543210', code });
    const first = await client.post('/auth/refresh', { refreshToken: login.body.refreshToken });
    expect(first.status).toBe(200);
    const reused = await client.post('/auth/refresh', { refreshToken: login.body.refreshToken });
    expect(reused.status).toBe(401);
  });

  it('rejects requests without a valid token', async () => {
    expect((await client.get('/canteens')).status).toBe(401);
    expect((await client.get('/canteens', 'not-a-token')).status).toBe(401);
  });

  it('serves canteens and today\'s menu', async () => {
    const code = await otp('9876543210');
    const { body } = await client.post('/auth/verify', { phone: '9876543210', code });
    const canteens = await client.get('/canteens', body.accessToken);
    expect(canteens.body.canteens.map((c: { name: string }) => c.name)).toEqual(['Advance Block Canteen', 'Main Canteen']);
    const menu = await client.get('/canteens/1/menu', body.accessToken);
    expect(menu.body.stalls.map((s: { name: string }) => s.name)).toContain('Burger Hub');
    const burgerHub = menu.body.stalls.find((s: { name: string }) => s.name === 'Burger Hub');
    expect(burgerHub.products.find((p: { name: string }) => p.name === 'Chicken Burger').stockState).toBe('sold_out');
  });
});
