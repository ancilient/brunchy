import { randomBytes } from 'node:crypto';
import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { createApp } from '../src/app.js';
import { dropAll, migrate, seed } from '../src/db/migrate.js';
import { exec, one, pool } from '../src/db/pool.js';
import { type AuthUser, signAccessToken } from '../src/middleware/auth.js';
import { MOCK_SIGNATURE_HEADER, signMockBody } from '../src/payments/mockGateway.js';
import { attachRealtime, closeRealtime } from '../src/realtime.js';
import { redis } from '../src/redis.js';

const quiet = () => undefined;

/** Fresh schema + demo seed in the test database (brunchy_test), and an empty Redis db 1. */
export async function resetDb() {
  await dropAll(quiet);
  await migrate(quiet);
  await seed(quiet);
  await redis.flushdb();
}

/** Starts the real HTTP server (with Socket.IO) on a random port. */
export async function startServer() {
  const server: Server = createServer(createApp());
  attachRealtime(server);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address() as AddressInfo;
  return {
    url: `http://127.0.0.1:${port}`,
    close: async () => {
      closeRealtime();
      await new Promise((resolve) => server.close(resolve));
    },
  };
}

export async function closeAll() {
  await pool.end();
  redis.disconnect();
}

export const STUDENT_ID = 1; // Demo Student from the seed
export const VENDOR_BURGER = { id: 2, role: 'vendor', stallId: 1, canteenId: 1 } as const; // Burger Hub
export const VENDOR_JUICE = { id: 3, role: 'vendor', stallId: 2, canteenId: 1 } as const; // Juice Corner

export const tokenFor = (u: AuthUser) => signAccessToken(u);
export const studentToken = (id = STUDENT_ID) => tokenFor({ id, role: 'student', stallId: null, canteenId: null });

export async function createStudents(n: number) {
  const ids: number[] = [];
  for (let i = 0; i < n; i++) {
    const r = await exec(pool, "INSERT INTO users (name, phone, role) VALUES (?, ?, 'student')", [`Student ${i}`, `7${String(100000000 + i).slice(-9)}`]);
    ids.push(r.insertId);
  }
  return ids;
}

export const setStock = (productId: number, qty: number) => exec(pool, 'UPDATE products SET stock_quantity = ? WHERE product_id = ?', [qty, productId]);
export const stockOf = async (productId: number) =>
  (await one<{ stock_quantity: number }>(pool, 'SELECT stock_quantity FROM products WHERE product_id = ?', [productId]))!.stock_quantity;

/** Small fetch wrapper: api(url).post('/checkout', body, token) → { status, body } */
export function api(baseUrl: string) {
  const call = async (method: string, path: string, body?: unknown, token?: string, headers: Record<string, string> = {}) => {
    const res = await fetch(`${baseUrl}/api/v1${path}`, {
      method,
      headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers },
      body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
    });
    const text = await res.text();
    return { status: res.status, body: text ? JSON.parse(text) : null };
  };
  return {
    get: (path: string, token?: string) => call('GET', path, undefined, token),
    post: (path: string, body: unknown, token?: string, headers?: Record<string, string>) => call('POST', path, body, token, headers),
    patch: (path: string, body: unknown, token?: string) => call('PATCH', path, body, token),
  };
}

export const key = () => `test-${randomBytes(8).toString('hex')}`;

/** A signed mock-gateway webhook body, exactly as the gateway would send it. */
export function webhook(gatewayOrderRef: string, amountPaise: number, opts: { paymentRef?: string; type?: string } = {}) {
  const raw = JSON.stringify({
    type: opts.type ?? 'payment.captured',
    gatewayOrderRef,
    gatewayPaymentRef: opts.paymentRef ?? `pay_${randomBytes(6).toString('hex')}`,
    amountPaise,
    upiApp: 'gpay',
  });
  return { raw, headers: { [MOCK_SIGNATURE_HEADER]: signMockBody(raw) } };
}

/** Checks out one item and pays for it; returns the paid order. */
export async function placePaidOrder(client: ReturnType<typeof api>, token: string, items: { productId: string; qty: number }[], canteenId = '1') {
  const co = await client.post('/checkout', { canteenId, items, idempotencyKey: key() }, token);
  if (co.status !== 201) throw new Error(`checkout failed: ${JSON.stringify(co.body)}`);
  const pay = await client.post(`/payments/mock/${co.body.order.id}/pay`, {}, token);
  if (pay.body?.result !== 'paid') throw new Error(`payment failed: ${JSON.stringify(pay.body)}`);
  return (await client.get(`/orders/${co.body.order.id}`, token)).body.order;
}
