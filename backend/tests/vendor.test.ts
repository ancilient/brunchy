import { io as connect } from 'socket.io-client';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { exec, one, pool } from '../src/db/pool.js';
import {
  VENDOR_BURGER,
  VENDOR_JUICE,
  api,
  closeAll,
  key,
  placePaidOrder,
  resetDb,
  setStock,
  startServer,
  stockOf,
  studentToken,
  tokenFor,
} from './helpers.js';

let server: Awaited<ReturnType<typeof startServer>>;
let client: ReturnType<typeof api>;
const burger = () => tokenFor(VENDOR_BURGER);
const juice = () => tokenFor(VENDOR_JUICE);

beforeAll(async () => {
  await resetDb();
  await setStock(102, 100);
  server = await startServer();
  client = api(server.url);
});
afterAll(async () => {
  await server.close();
  await closeAll();
});

async function readyBill() {
  const order = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }]);
  const bill = order.bills[0];
  await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'accepted' }, burger());
  const ready = await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'ready' }, burger());
  expect(ready.body.bill.status).toBe('ready');
  return bill as { id: string; pickupCode: string };
}

describe('vendor board and handover', () => {
  it('shows only paid bills of the vendor\'s own stall', async () => {
    const order = await placePaidOrder(client, studentToken(), [
      { productId: '102', qty: 1 },
      { productId: '201', qty: 1 },
    ]);
    const board = await client.get('/vendor/bills', burger());
    expect(board.status).toBe(200);
    const ids = board.body.bills.map((b: { id: string }) => b.id);
    expect(ids).toContain(order.bills.find((b: { stallId: string }) => b.stallId === '1').id);
    expect(ids).not.toContain(order.bills.find((b: { stallId: string }) => b.stallId === '2').id);
    expect(board.body.bills.every((b: { stallId: string }) => b.stallId === '1')).toBe(true);
  });

  it('a student can never use vendor actions', async () => {
    const r = await client.get('/vendor/bills', studentToken());
    expect(r.status).toBe(403);
  });

  it('handover before Ready is blocked', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }]);
    const bill = order.bills[0];
    const r = await client.post(`/vendor/bills/${bill.id}/handover`, { code: bill.pickupCode }, burger());
    expect(r.status).toBe(409);
    expect(r.body.error.code).toBe('ORDER_NOT_READY');
  });

  it('a Burger Hub bill at the Juice counter says wrong stall', async () => {
    const bill = await readyBill();
    const r = await client.post(`/vendor/bills/${bill.id}/handover`, { code: bill.pickupCode }, juice());
    expect(r.status).toBe(403);
    expect(r.body.error.code).toBe('WRONG_STALL');
  });

  it('the right code completes the bill once; a second try says already collected', async () => {
    const bill = await readyBill();
    const ok = await client.post(`/vendor/bills/${bill.id}/handover`, { code: bill.pickupCode }, burger());
    expect(ok.status).toBe(200);
    expect(ok.body.bill.status).toBe('collected');
    const again = await client.post(`/vendor/bills/${bill.id}/handover`, { code: bill.pickupCode }, burger());
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('ALREADY_COLLECTED');
    expect(again.body.error.details.collectedAt).toBeTruthy();
  });

  it('two simultaneous handovers: only one succeeds', async () => {
    const bill = await readyBill();
    const results = await Promise.all(
      Array.from({ length: 5 }, () => client.post(`/vendor/bills/${bill.id}/handover`, { code: bill.pickupCode }, burger())),
    );
    expect(results.filter((r) => r.status === 200)).toHaveLength(1);
    expect(results.filter((r) => r.body?.error?.code === 'ALREADY_COLLECTED')).toHaveLength(4);
  });

  it('locks the bill after 4 wrong codes', async () => {
    const bill = await readyBill();
    const wrong = bill.pickupCode === '999' ? '998' : '999';
    for (let i = 0; i < 3; i++) {
      const r = await client.post(`/vendor/bills/${bill.id}/handover`, { code: wrong }, burger());
      expect(r.body.error.code).toBe('CODE_WRONG');
      expect(r.body.error.details.attemptsLeft).toBe(3 - i);
    }
    const fourth = await client.post(`/vendor/bills/${bill.id}/handover`, { code: wrong }, burger());
    expect(fourth.status).toBe(423);
    expect(fourth.body.error.code).toBe('CODE_LOCKED');
    const evenRight = await client.post(`/vendor/bills/${bill.id}/handover`, { code: bill.pickupCode }, burger());
    expect(evenRight.body.error.code).toBe('CODE_LOCKED');
  });

  it('finds a bill by its pickup code', async () => {
    const bill = await readyBill();
    const r = await client.get(`/vendor/bills/lookup?code=${bill.pickupCode}`, burger());
    expect(r.status).toBe(200);
    expect(r.body.bill.id).toBe(bill.id);
  });

  it('rejecting a bill records a refund and needs a reason', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 2 }]);
    const bill = order.bills[0];
    const noReason = await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'rejected' }, burger());
    expect(noReason.body.error.code).toBe('REASON_REQUIRED');
    const before = await stockOf(102);
    const r = await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'rejected', reason: 'KITCHEN_ISSUE' }, burger());
    expect(r.body.bill.status).toBe('rejected');
    expect(await stockOf(102)).toBe(before + 2);
    const refund = await one(pool, 'SELECT reason_code, amount, status FROM refunds WHERE stall_order_id = ?', [bill.id]);
    expect(refund).toMatchObject({ reason_code: 'KITCHEN_ISSUE', amount: bill.total, status: 'requested' });
  });

  it('a student can cancel a bill before it is being prepared, not after', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }]);
    const bill = order.bills[0];
    const ok = await client.post(`/bills/${bill.id}/cancel`, {}, studentToken());
    expect(ok.body.bill.status).toBe('cancelled');
    const ready = await readyBill();
    const late = await client.post(`/bills/${ready.id}/cancel`, {}, studentToken());
    expect(late.body.error.code).toBe('CANNOT_CANCEL');
  });

  it('pausing the stall blocks new checkouts until resumed', async () => {
    const paused = await client.post('/vendor/stall/status', { action: 'pause', minutes: 10 }, burger());
    expect(paused.body.stall.status).toBe('paused');
    const blocked = await client.post('/checkout', { canteenId: '1', items: [{ productId: '102', qty: 1 }], idempotencyKey: key() }, studentToken());
    expect(blocked.body.error.code).toBe('STALL_NOT_OPEN');
    await client.post('/vendor/stall/status', { action: 'resume' }, burger());
    const ok = await client.post('/checkout', { canteenId: '1', items: [{ productId: '102', qty: 1 }], idempotencyKey: key() }, studentToken());
    expect(ok.status).toBe(201);
  });

  it('vendor can change stock only for their own items', async () => {
    const mine = await client.patch('/vendor/products/104', { stockQuantity: 12 }, burger());
    expect(mine.body.product.stockQuantity).toBe(12);
    const other = await client.patch('/vendor/products/201', { stockQuantity: 12 }, burger());
    expect(other.body.error.code).toBe('WRONG_STALL');
  });

  it('undo Ready works only right after marking Ready', async () => {
    const bill = await readyBill();
    const undo = await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'preparing' }, burger());
    expect(undo.body.bill.status).toBe('preparing');
    await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'ready' }, burger());
    await exec(pool, 'UPDATE stall_orders SET ready_at = UTC_TIMESTAMP() - INTERVAL 1 MINUTE WHERE stall_order_id = ?', [bill.id]);
    const late = await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'preparing' }, burger());
    expect(late.body.error.code).toBe('UNDO_WINDOW_EXPIRED');
  });

  it('shows my stall and all its items', async () => {
    const stall = await client.get('/vendor/stall', burger());
    expect(stall.body.stall).toMatchObject({ id: '1', name: 'Burger Hub', canteenName: 'Main Canteen' });
    const products = await client.get('/vendor/products', burger());
    expect(products.body.products.map((p: { name: string }) => p.name)).toEqual(['Cheese Burger', 'Chicken Burger', 'French Fries', 'Veg Burger']);
    expect(products.body.products.every((p: { stallId: string }) => p.stallId === '1')).toBe(true);
  });

  it('emergency stop closes the stall and refunds orders not yet started; cooking ones stay', async () => {
    const waiting = (await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }])).bills[0];
    const cooking = (await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }])).bills[0];
    await client.patch(`/vendor/bills/${cooking.id}/status`, { status: 'accepted' }, burger());
    const r = await client.post('/vendor/stall/status', { action: 'emergency', reason: 'GAS_CUT' }, burger());
    expect(r.body.stall.status).toBe('closed');
    expect(r.body.refundedBillIds).toContain(waiting.id);
    expect(r.body.preparingBillIds).toContain(cooking.id);
    const refund = await one(pool, 'SELECT reason_code FROM refunds WHERE stall_order_id = ?', [waiting.id]);
    expect(refund?.reason_code).toBe('STALL_EMERGENCY');
    await client.post('/vendor/stall/status', { action: 'resume' }, burger());
  });

  it('the vendor gets the new bill live over the socket within moments of payment', async () => {
    const socket = connect(server.url, { auth: { token: burger() }, transports: ['websocket'] });
    await new Promise<void>((resolve, reject) => {
      socket.on('connect', () => resolve());
      socket.on('connect_error', reject);
    });
    const received = new Promise<{ stallId: string; status: string; billNo: string }>((resolve) => socket.on('bill.new', resolve));
    const started = Date.now();
    const order = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }]);
    const bill = await received;
    expect(Date.now() - started).toBeLessThan(2000); // launch gate: vendor sees a new order within 2 seconds
    expect(bill).toMatchObject({ stallId: '1', status: 'new', billNo: order.bills[0].billNo });
    socket.disconnect();
  });
});
