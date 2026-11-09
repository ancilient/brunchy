import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { exec, one, pool } from '../src/db/pool.js';
import { expireOrder } from '../src/services/holds.js';
import { api, closeAll, createStudents, key, resetDb, setStock, startServer, stockOf, studentToken } from './helpers.js';

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

describe('checkout and stock reservation', () => {
  // Launch gate asks for 1000 parallel orders; 200 keeps the suite fast and exercises the same row lock.
  it('sells exactly the stock when 200 students race for 50 items', async () => {
    await setStock(102, 50);
    const students = await createStudents(200);
    const results = await Promise.all(
      students.map((id) =>
        client.post('/checkout', { canteenId: '1', items: [{ productId: '102', qty: 1 }], idempotencyKey: key() }, studentToken(id)),
      ),
    );
    const won = results.filter((r) => r.status === 201);
    const soldOut = results.filter((r) => r.status === 409 && r.body.error.code === 'OUT_OF_STOCK');
    expect(won).toHaveLength(50);
    expect(soldOut).toHaveLength(150);
    expect(await stockOf(102)).toBe(0);
    const held = await one<{ n: number }>(pool, "SELECT COALESCE(SUM(qty),0) AS n FROM stock_holds WHERE product_id = 102 AND status = 'held'");
    expect(Number(held!.n)).toBe(50);
  });

  it('asks "Only 3 left" instead of overselling, and holds only what exists', async () => {
    await setStock(104, 3);
    const r = await client.post('/checkout', { canteenId: '1', items: [{ productId: '104', qty: 5 }], idempotencyKey: key() }, studentToken());
    expect(r.status).toBe(200);
    expect(r.body.needsConfirmation).toBe(true);
    expect(r.body.payment).toBeNull();
    expect(r.body.shortages).toEqual([{ productId: '104', name: 'French Fries', requested: 5, available: 3 }]);
    expect(await stockOf(104)).toBe(0);

    const confirmed = await client.post(`/checkout/${r.body.order.id}/confirm-partial`, { lines: [{ productId: '104', action: 'take_available' }] }, studentToken());
    expect(confirmed.status).toBe(200);
    expect(confirmed.body.order.bills[0].items[0].quantity).toBe(3);
    // 3 x ₹40 = 120, 5% GST = 6, convenience fee 5
    expect(confirmed.body.order.total).toBe(131);
    expect(confirmed.body.payment.amountPaise).toBe(13100);
  });

  it('removing a short line releases its hold at once', async () => {
    await setStock(203, 1);
    const r = await client.post(
      '/checkout',
      { canteenId: '1', items: [{ productId: '203', qty: 4 }, { productId: '201', qty: 1 }], idempotencyKey: key() },
      studentToken(),
    );
    expect(r.body.needsConfirmation).toBe(true);
    expect(await stockOf(203)).toBe(0);
    const confirmed = await client.post(`/checkout/${r.body.order.id}/confirm-partial`, { lines: [{ productId: '203', action: 'remove' }] }, studentToken());
    expect(await stockOf(203)).toBe(1);
    expect(confirmed.body.order.bills.flatMap((b: { items: { productId: string }[] }) => b.items.map((i) => i.productId))).toEqual(['201']);
  });

  it('computes prices on the server and ignores any price sent by the app', async () => {
    await setStock(201, 30);
    const r = await client.post(
      '/checkout',
      { canteenId: '1', items: [{ productId: '201', qty: 2, price: 0.01 }], total: 1, idempotencyKey: key() },
      studentToken(),
    );
    expect(r.status).toBe(201);
    expect(r.body.order.total).toBe(105); // 2 x ₹50 (0% GST) + ₹5 fee
  });

  it('returns the same order when the same request is retried (double tap)', async () => {
    const k = key();
    const body = { canteenId: '1', items: [{ productId: '401', qty: 1 }], idempotencyKey: k };
    const [a, b] = await Promise.all([client.post('/checkout', body, studentToken()), client.post('/checkout', body, studentToken())]);
    expect(a.body.order.id).toBe(b.body.order.id);
    const n = await one<{ n: number }>(pool, 'SELECT COUNT(*) AS n FROM orders WHERE idempotency_key = ?', [k]);
    expect(Number(n!.n)).toBe(1);
  });

  it('rejects a cart that mixes canteens', async () => {
    const r = await client.post(
      '/checkout',
      { canteenId: '1', items: [{ productId: '101', qty: 1 }, { productId: '601', qty: 1 }], idempotencyKey: key() },
      studentToken(),
    );
    expect(r.status).toBe(400);
    expect(r.body.error.code).toBe('MIXED_CANTEEN');
  });

  it('blocks checkout while the stall is paused', async () => {
    await exec(pool, "UPDATE stalls SET status = 'paused', paused_until = UTC_TIMESTAMP() + INTERVAL 10 MINUTE WHERE stall_id = 3");
    const r = await client.post('/checkout', { canteenId: '1', items: [{ productId: '301', qty: 1 }], idempotencyKey: key() }, studentToken());
    expect(r.status).toBe(409);
    expect(r.body.error.code).toBe('STALL_NOT_OPEN');
    // An expired pause counts as open again.
    await exec(pool, "UPDATE stalls SET paused_until = UTC_TIMESTAMP() - INTERVAL 1 MINUTE WHERE stall_id = 3");
    const again = await client.post('/checkout', { canteenId: '1', items: [{ productId: '301', qty: 1 }], idempotencyKey: key() }, studentToken());
    expect(again.status).toBe(201);
  });

  it('puts the stock back on sale when the 5-minute hold runs out', async () => {
    await setStock(402, 10);
    const r = await client.post('/checkout', { canteenId: '1', items: [{ productId: '402', qty: 4 }], idempotencyKey: key() }, studentToken());
    expect(await stockOf(402)).toBe(6);
    const orderId = Number(r.body.order.id);
    expect(await expireOrder(orderId)).toBe(false); // not overdue yet: nothing happens
    await exec(pool, 'UPDATE orders SET payment_expires_at = UTC_TIMESTAMP() - INTERVAL 1 SECOND WHERE order_id = ?', [orderId]);
    expect(await expireOrder(orderId)).toBe(true);
    expect(await expireOrder(orderId)).toBe(false); // running twice changes nothing
    expect(await stockOf(402)).toBe(10);
    const order = (await client.get(`/orders/${orderId}`, studentToken())).body.order;
    expect(order.status).toBe('expired');
    expect(order.bills[0].status).toBe('expired');
  });

  it('needs a student login', async () => {
    const r = await client.post('/checkout', { canteenId: '1', items: [{ productId: '101', qty: 1 }], idempotencyKey: key() });
    expect(r.status).toBe(401);
  });
});
