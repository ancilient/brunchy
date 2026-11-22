import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { one, pool } from '../src/db/pool.js';
import { setFreeOrdersForTests } from '../src/services/fees.js';
import { api, closeAll, key, placePaidOrder, resetDb, startServer, studentToken, tokenFor, VENDOR_BURGER } from './helpers.js';

let server: Awaited<ReturnType<typeof startServer>>;
let client: ReturnType<typeof api>;
const burger = () => tokenFor(VENDOR_BURGER);

beforeAll(async () => {
  await resetDb();
  setFreeOrdersForTests(2); // the real rule: a student's first two paid orders are free of both fees
  server = await startServer();
  client = api(server.url);
});
afterAll(async () => {
  setFreeOrdersForTests(null);
  await server.close();
  await closeAll();
});

describe('fees: platform 3% + convenience 3%, first two orders free', () => {
  it('app-config serves the fee rules, support contacts and GST number', async () => {
    const r = await client.get('/app-config');
    expect(r.status).toBe(200);
    expect(r.body.fees).toEqual({ platformPercent: 3, conveniencePercent: 3, freeOrdersPerStudent: 2 });
    expect(r.body).toHaveProperty('support');
    expect(r.body).toHaveProperty('gstin');
  });

  it("a student's first two paid orders have no fees; the third pays items + 3% + 3%", async () => {
    expect((await client.get('/me', studentToken())).body.freeOrdersLeft).toBe(2);

    const first = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 2 }]);
    expect(first).toMatchObject({ feesWaived: true, additionalFee: 0, convenienceFee: 0, total: first.subtotal });
    expect((await client.get('/me', studentToken())).body.freeOrdersLeft).toBe(1);

    const second = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }]);
    expect(second.feesWaived).toBe(true);
    expect(second.total).toBe(second.subtotal);
    expect((await client.get('/me', studentToken())).body.freeOrdersLeft).toBe(0);

    const third = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 2 }]);
    const fee = Math.round(third.subtotal * 3) / 100; // 3% of the items, in rupees
    expect(third).toMatchObject({ feesWaived: false, additionalFee: fee, convenienceFee: fee });
    expect(third.total).toBe(Math.round((third.subtotal + 2 * fee) * 100) / 100);
    // What the gateway is asked to charge matches
    const row = await one<{ total: number }>(pool, 'SELECT total FROM orders WHERE order_id = ?', [Number(third.id)]);
    expect(row?.total).toBe(third.total);
  });

  it('an unpaid checkout does not use up a free order', async () => {
    const student = (await pool.query("INSERT INTO users (name, phone, role) VALUES ('Fresh', '7000000099', 'student')")) as unknown as [
      { insertId: number },
    ];
    const token = studentToken(student[0].insertId);
    const co = await client.post('/checkout', { canteenId: '1', items: [{ productId: '102', qty: 1 }], idempotencyKey: key() }, token);
    expect(co.body.order.feesWaived).toBe(true);
    expect((await client.get('/me', token)).body.freeOrdersLeft).toBe(2); // still two: nothing was paid
  });

  it('bills carry the Order ID (not the pickup code) and both fee shares; a stall rejection refunds both', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }]);
    const bill = order.bills[0];
    expect(order.orderCode).toBe(`ORD-${order.id.padStart(5, '0')}`);
    expect(bill.orderCode).toBe(order.orderCode);
    expect(bill.orderCode).not.toBe(bill.pickupCode);
    expect(bill.platformFee).toBeGreaterThan(0);
    expect(bill.convenienceFee).toBeGreaterThan(0);

    const r = await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'rejected', reason: 'KITCHEN_ISSUE' }, burger());
    const paid = Math.round((bill.total + bill.platformFee + bill.convenienceFee) * 100) / 100;
    expect(r.body.bill.refundedAmount).toBe(paid);
    expect(paid).toBe(order.total);
  });
});
