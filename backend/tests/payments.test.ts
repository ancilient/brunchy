import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { exec, one, pool } from '../src/db/pool.js';
import { expireOrder } from '../src/services/holds.js';
import { api, closeAll, key, placePaidOrder, resetDb, setStock, startServer, stockOf, studentToken, webhook } from './helpers.js';

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

async function checkoutOne(productId: string, qty = 1) {
  const r = await client.post('/checkout', { canteenId: '1', items: [{ productId, qty }], idempotencyKey: key() }, studentToken());
  expect(r.status).toBe(201);
  return r.body;
}

const sendWebhook = (w: ReturnType<typeof webhook>) => client.post('/payments/webhook', w.raw, undefined, w.headers);

describe('payment webhook', () => {
  it('a webhook replayed 5 times creates one paid order and changes stock once', async () => {
    await setStock(102, 20);
    const co = await checkoutOne('102', 2);
    const w = webhook(co.payment.gatewayOrderRef, co.payment.amountPaise, { paymentRef: 'pay_replay_1' });
    const results = await Promise.all(Array.from({ length: 5 }, () => sendWebhook(w)));
    expect(results.map((r) => r.body.result).sort()).toEqual(['paid', 'replay', 'replay', 'replay', 'replay']);
    expect(await stockOf(102)).toBe(18);
    const payments = await one<{ n: number }>(pool, 'SELECT COUNT(*) AS n FROM payments WHERE order_id = ?', [co.order.id]);
    expect(Number(payments!.n)).toBe(1);
  });

  it('rejects a webhook with a tampered body or a missing signature', async () => {
    const co = await checkoutOne('201');
    const w = webhook(co.payment.gatewayOrderRef, co.payment.amountPaise);
    const tampered = await client.post('/payments/webhook', w.raw.replace('"amountPaise":', '"amountPaise":1'), undefined, w.headers);
    expect(tampered.status).toBe(401);
    const unsigned = await client.post('/payments/webhook', w.raw);
    expect(unsigned.status).toBe(401);
    const order = (await client.get(`/orders/${co.order.id}`, studentToken())).body.order;
    expect(order.status).toBe('pending');
  });

  it('never accepts a payment for the wrong amount', async () => {
    const co = await checkoutOne('201');
    const r = await sendWebhook(webhook(co.payment.gatewayOrderRef, 100)); // ₹1 instead of the real total
    expect(r.body.result).toBe('refund');
    const order = (await client.get(`/orders/${co.order.id}`, studentToken())).body.order;
    expect(order.status).toBe('pending');
    const refund = await one(pool, 'SELECT reason_code FROM refunds WHERE order_id = ?', [co.order.id]);
    expect(refund?.reason_code).toBe('AMOUNT_MISMATCH');
  });

  it('one payment for two stalls gives two bills, each with its own number and pickup code', async () => {
    const order = await placePaidOrder(client, studentToken(), [
      { productId: '102', qty: 1 },
      { productId: '201', qty: 1 },
    ]);
    expect(order.status).toBe('paid');
    expect(order.bills).toHaveLength(2);
    const [bh, jc] = order.bills;
    expect(bh.billNo).toMatch(/^BH-\d{4}$/);
    expect(jc.billNo).toMatch(/^JC-\d{4}$/);
    for (const bill of order.bills) {
      expect(bill.status).toBe('new');
      expect(bill.pickupCode).toMatch(/^[1-9]\d{2}$/);
    }
  });

  it('bill numbers run in order per stall', async () => {
    const a = await placePaidOrder(client, studentToken(), [{ productId: '401', qty: 1 }]);
    const b = await placePaidOrder(client, studentToken(), [{ productId: '401', qty: 1 }]);
    const n = (o: { bills: { billNo: string }[] }) => Number(o.bills[0].billNo.split('-')[1]);
    expect(n(b)).toBe(n(a) + 1);
  });

  it('money that arrives after the hold expired: re-reserves if stock is left', async () => {
    await setStock(301, 5);
    const co = await checkoutOne('301', 2);
    await exec(pool, 'UPDATE orders SET payment_expires_at = UTC_TIMESTAMP() - INTERVAL 1 SECOND WHERE order_id = ?', [co.order.id]);
    await expireOrder(Number(co.order.id));
    expect(await stockOf(301)).toBe(5);
    const r = await sendWebhook(webhook(co.payment.gatewayOrderRef, co.payment.amountPaise));
    expect(r.body.result).toBe('paid');
    expect(await stockOf(301)).toBe(3);
    const order = (await client.get(`/orders/${co.order.id}`, studentToken())).body.order;
    expect(order.status).toBe('paid');
    expect(order.bills[0].status).toBe('new');
  });

  it('money that arrives after the hold expired: refunds automatically if the food is gone', async () => {
    await setStock(302, 2);
    const co = await checkoutOne('302', 2);
    await exec(pool, 'UPDATE orders SET payment_expires_at = UTC_TIMESTAMP() - INTERVAL 1 SECOND WHERE order_id = ?', [co.order.id]);
    await expireOrder(Number(co.order.id));
    await setStock(302, 0); // someone else bought it meanwhile
    const r = await sendWebhook(webhook(co.payment.gatewayOrderRef, co.payment.amountPaise));
    expect(r.body.result).toBe('refund');
    const refund = await one(pool, 'SELECT reason_code, amount FROM refunds WHERE order_id = ?', [co.order.id]);
    expect(refund?.reason_code).toBe('LATE_PAYMENT');
    expect(refund?.amount).toBe(co.order.total);
  });

  it('a failed payment leaves the order pending so the student can retry', async () => {
    const co = await checkoutOne('201');
    const r = await client.post(`/payments/mock/${co.order.id}/pay`, { fail: true }, studentToken());
    expect(r.body.result).toBe('failed');
    const retry = await client.post(`/payments/mock/${co.order.id}/pay`, {}, studentToken());
    expect(retry.body.result).toBe('paid');
  });
});
