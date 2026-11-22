import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { periodRanges } from '../src/services/reports.js';
import { api, closeAll, placePaidOrder, resetDb, startServer, studentToken, tokenFor, VENDOR_BURGER } from './helpers.js';

let server: Awaited<ReturnType<typeof startServer>>;
let client: ReturnType<typeof api>;
const burger = () => tokenFor(VENDOR_BURGER);

beforeAll(async () => {
  await resetDb();
  server = await startServer();
  client = api(server.url);
});
afterAll(closeAll);

describe('vendor dashboard and sold-today figures come from real bills', () => {
  it('starts empty: no made-up revenue', async () => {
    const r = await client.get('/vendor/reports/dashboard?period=today', burger());
    expect(r.status).toBe(200);
    expect(r.body).toMatchObject({ totalRevenue: 0, orderCount: 0, revenueChangeIsNone: true, avgPrepMinutes: 0 });
    expect(r.body.chartData).toHaveLength(24);
    expect(r.body.peakHours).toHaveLength(24);
  });

  it('counts a bill once the stall takes it on, with the stall amount (not the platform fee)', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 2 }]);
    const bill = order.bills[0];
    // Paid but not accepted yet: not a sale on the dashboard, but the stock is already sold.
    const before = await client.get('/vendor/reports/dashboard?period=today', burger());
    expect(before.body.orderCount).toBe(0);
    const products = await client.get('/vendor/products', burger());
    expect(products.body.products.find((p: { id: string }) => p.id === '102').soldToday).toBe(2);

    await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'accepted' }, burger());
    await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'ready' }, burger());
    const r = await client.get('/vendor/reports/dashboard?period=today', burger());
    expect(r.body.orderCount).toBe(1);
    expect(r.body.totalRevenue).toBe(bill.total);
    expect(r.body.avgOrderValue).toBe(bill.total);
    expect(r.body.revenueChangeIsNew).toBe(true);
    expect(r.body.topItems[0]).toMatchObject({ qty: 2, orderCount: 1, revenue: bill.total });
    expect(r.body.chartData.reduce((s: number, p: { orders: number }) => s + p.orders, 0)).toBe(1);
    expect(r.body.statusSplit).toMatchObject({ accepted: 1, collected: 0 });
  });

  it('a cancelled bill is not a sale and its items are not "sold today"', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '104', qty: 1 }]);
    await client.post(`/bills/${order.bills[0].id}/cancel`, {}, studentToken());
    const products = await client.get('/vendor/products', burger());
    expect(products.body.products.find((p: { id: string }) => p.id === '104').soldToday).toBe(0);
    const r = await client.get('/vendor/reports/dashboard?period=today', burger());
    expect(r.body.orderCount).toBe(1);
    expect(r.body.statusSplit.cancelled).toBe(1);
  });

  it('week and month periods return weekday and day-of-month buckets', async () => {
    const week = await client.get('/vendor/reports/dashboard?period=this_week', burger());
    expect(week.body.chartData.map((p: { label: string }) => p.label)).toEqual(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
    expect(week.body.orderCount).toBe(1);
    const month = await client.get('/vendor/reports/dashboard?period=this_month', burger());
    expect(month.body.chartData.length).toBeGreaterThanOrEqual(28);
    const bad = await client.get('/vendor/reports/dashboard?period=yearly', burger());
    expect(bad.status).toBe(400);
  });

  it('a student cannot read a stall dashboard', async () => {
    const r = await client.get('/vendor/reports/dashboard?period=today', studentToken());
    expect(r.status).toBe(403);
  });
});

describe('periodRanges (IST days)', () => {
  const sunMorningIst = new Date('2026-11-22T01:30:00Z'); // Sunday 22 Nov, 07:00 IST
  const ymd = (d: Date) => d.toISOString().slice(0, 10);

  it('today and yesterday follow the Indian date, not UTC', () => {
    const r = periodRanges('today', new Date('2026-11-21T20:00:00Z')); // 22 Nov, 01:30 IST
    expect([ymd(r.from), ymd(r.prevFrom)]).toEqual(['2026-11-22', '2026-11-21']);
  });

  it('this week runs Monday to today; the previous week is the same span a week earlier', () => {
    const r = periodRanges('this_week', sunMorningIst);
    expect([ymd(r.from), ymd(r.to), ymd(r.prevFrom), ymd(r.prevTo)]).toEqual(['2026-11-16', '2026-11-22', '2026-11-09', '2026-11-15']);
  });

  it('this month runs from the 1st; the previous month stops at the same day (clamped)', () => {
    const r = periodRanges('this_month', new Date('2026-03-31T06:00:00Z'));
    expect([ymd(r.from), ymd(r.to), ymd(r.prevFrom), ymd(r.prevTo)]).toEqual(['2026-03-01', '2026-03-31', '2026-02-01', '2026-02-28']);
  });
});
