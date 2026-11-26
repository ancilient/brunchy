import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { exec, one, pool } from '../src/db/pool.js';
import { api, closeAll, placePaidOrder, resetDb, startServer, studentToken, tokenFor } from './helpers.js';

/**
 * Admin panel money screens: Payments & refunds, Vendor settlements, Reports & analytics and exports.
 * Seed: user 9 = admin, user 8 = Main Canteen manager (no payments access), stall 1 = Burger Hub (canteen 1).
 */
let server: Awaited<ReturnType<typeof startServer>>;
let client: ReturnType<typeof api>;
let admin: string;
let manager: string;
const yesterday = new Date(Date.now() + 330 * 60_000 - 86_400_000).toISOString().slice(0, 10);
const today = new Date(Date.now() + 330 * 60_000).toISOString().slice(0, 10);

const vendorToken = async (stallId = 1) => (await client.post('/auth/dev-login', { app: 'vendor', stallId })).body.accessToken as string;

/** A paid Burger Hub bill, accepted, ready and handed over by the vendor app. */
async function collectedBill(productId = '102', qty = 1) {
  const order = await placePaidOrder(client, studentToken(), [{ productId, qty }]);
  const bill = order.bills[0];
  const v = await vendorToken();
  await client.patch(`/vendor/bills/${bill.id}/status`, { status: 'ready' }, v);
  const h = await client.post(`/vendor/bills/${bill.id}/handover`, { code: bill.pickupCode }, v);
  expect(h.status).toBe(200);
  return { order, bill };
}

beforeAll(async () => {
  await resetDb();
  server = await startServer();
  client = api(server.url);
  admin = (await client.post('/auth/dev-login', { app: 'admin', role: 'admin' })).body.accessToken;
  manager = (await client.post('/auth/dev-login', { app: 'admin', role: 'manager' })).body.accessToken;
});
afterAll(async () => {
  await server.close();
  await closeAll();
});

describe('payments', () => {
  it('lists payment attempts with the success rate; searches by payment ID or order', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '104', qty: 1 }]);
    const r = await client.get('/admin/payments', admin);
    expect(r.status).toBe(200);
    expect(r.body.successRate).toBe(1);
    const row = r.body.items.find((x: { orderId: number }) => x.orderId === Number(order.id));
    expect(row).toMatchObject({ amount: 42.4, status: 'success', method: 'upi', studentName: 'Demo Student' });
    expect(row.billId).toBe(Number(order.bills[0].id));
    const found = await client.get(`/admin/payments?q=${row.gatewayRef}`, admin);
    expect(found.body.items.map((x: { id: number }) => x.id)).toEqual([row.id]);
    expect((await client.get('/admin/payments?status=failed', admin)).body.total).toBe(0);
    expect((await client.get('/admin/payments', manager)).status).toBe(403); // managers have no payments access
  });
});

describe('refunds', () => {
  let orderId: string;
  let billNo: string;

  it('initiates a refund by bill number; never more than the order total', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '201', qty: 1 }]); // ₹50 + 6% = ₹53
    orderId = order.id;
    billNo = order.bills[0].billNo;
    const r = await client.post('/admin/refunds', { bill: billNo, amount: 20, reasonCode: 'KITCHEN_ISSUE', note: 'Spilled' }, admin);
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ orderId: Number(orderId), billNo, amount: 20, status: 'requested', requestedByName: 'Ancilient Admin', note: 'Spilled' });
    const over = await client.post('/admin/refunds', { bill: orderId, amount: 40, reasonCode: 'KITCHEN_ISSUE' }, admin);
    expect(over.status).toBe(422);
    expect(over.body.error.message).toContain('33');
    expect((await client.post('/admin/refunds', { bill: 'ZZ-0001', amount: 1, reasonCode: 'KITCHEN_ISSUE' }, admin)).status).toBe(422);
  });

  it('requested → approved → completed with a reference; a completed refund cannot change', async () => {
    const list = await client.get(`/admin/refunds?status=requested&from=${today}&to=${today}`, admin);
    const r = list.body.items.find((x: { orderId: number }) => x.orderId === Number(orderId));
    expect((await client.post(`/admin/refunds/${r.id}/complete`, { reference: 'UTR123456' }, admin)).status).toBe(409); // not approved yet
    expect((await client.post(`/admin/refunds/${r.id}/approve`, {}, admin)).status).toBe(200);
    expect((await client.post(`/admin/refunds/${r.id}/complete`, { reference: 'UTR123456' }, admin)).status).toBe(200);
    const done = await client.get(`/admin/refunds?status=completed`, admin);
    expect(done.body.items.find((x: { id: number }) => x.id === r.id)).toMatchObject({ status: 'completed', gatewayRefundRef: 'UTR123456', approvedByName: 'Ancilient Admin' });
    expect((await client.post(`/admin/refunds/${r.id}/reject`, { note: 'x' }, admin)).status).toBe(409);
  });

  it('reject needs a note; managers without payments edit cannot act', async () => {
    const r = await client.post('/admin/refunds', { bill: orderId, amount: 5, reasonCode: 'ITEM_UNAVAILABLE' }, admin);
    expect((await client.post(`/admin/refunds/${r.body.id}/reject`, {}, admin)).status).toBe(400);
    expect((await client.post(`/admin/refunds/${r.body.id}/approve`, {}, manager)).status).toBe(403);
    expect((await client.post(`/admin/refunds/${r.body.id}/reject`, { note: 'Not our fault' }, admin)).status).toBe(200);
  });
});

describe('reconciliation', () => {
  it('matches captured payments with orders and flags an amount mismatch', async () => {
    const ok = await client.get('/admin/reconciliation', admin);
    expect(ok.body.matched).toBeGreaterThan(0);
    expect(ok.body.rows).toEqual([]);
    const order = await placePaidOrder(client, studentToken(), [{ productId: '402', qty: 1 }]);
    await exec(pool, 'UPDATE payments SET amount = amount - 1 WHERE order_id = ?', [order.id]);
    const r = await client.get('/admin/reconciliation', admin);
    expect(r.body.rows).toEqual([expect.objectContaining({ kind: 'amount_mismatch', orderId: Number(order.id), paymentAmount: order.total, gatewayAmount: order.total - 1 })]);
  });
});

describe('vendor settlements', () => {
  let secondAdmin: string;
  let settlementId: number;
  let expectedNet: number;

  it('prepares one payout per stall for a finished day: items + GST − 10% commission − 18% GST on it + adjustments', async () => {
    await client.patch('/admin/settings', { vendorCommissionPct: 10 }, admin);
    const a = await collectedBill('102', 2); // ₹120
    const b = await collectedBill('104', 1); // ₹40
    await exec(pool, 'UPDATE stall_orders SET bill_date = ? WHERE stall_order_id IN (?)', [yesterday, [a.bill.id, b.bill.id]]);
    const adj = await client.post('/admin/settlements-adjustments', { stallId: 1, amount: 5, note: 'Bonus for the fest' }, admin);
    expect(adj.status).toBe(201);
    expect((await client.post('/admin/settlements/prepare', { date: today }, admin)).status).toBe(422); // day not finished

    const r = await client.post('/admin/settlements/prepare', { date: yesterday }, admin);
    expect(r.body).toEqual({ created: 1 });
    expect((await client.post('/admin/settlements/prepare', { date: yesterday }, admin)).body).toEqual({ created: 0 }); // never twice

    const list = await client.get(`/admin/settlements?from=${yesterday}&to=${yesterday}`, admin);
    const s = list.body.items[0];
    // 160 − 16 commission − 2.88 GST on commission + 5 adjustment = 146.12
    expectedNet = 146.12;
    expect(s).toMatchObject({ stallName: 'Burger Hub', orders: 2, gross: 160, commission: 16, commissionGst: 2.88, refunds: 0, adjustments: 5, netPayout: expectedNet, status: 'pending', preparedByName: 'Ancilient Admin' });
    expect(new Date(`${s.dueDate}T00:00:00Z`).getUTCDay()).not.toBe(0); // T+2 working days: never a Sunday
    expect(list.body.totals).toEqual({ pending: expectedNet, approved: 0, paid: 0 });
    settlementId = s.id;
  });

  it('statement detail uses the same net rule per bill', async () => {
    const d = await client.get(`/admin/settlements/${settlementId}`, admin);
    expect(d.body).toMatchObject({ commissionPct: 10, commissionGstPct: 18 });
    expect(d.body.bills.map((b: { subtotal: number; commission: number; net: number }) => [b.subtotal, b.commission, b.net])).toEqual([
      [120, 12, 105.84],
      [40, 4, 35.28],
    ]);
    expect(d.body.adjustments).toEqual([expect.objectContaining({ amount: 5, note: 'Bonus for the fest' })]);
  });

  it('four-eyes: the preparer cannot approve when another payments editor exists', async () => {
    const t = await client.post('/admin/team', { email: 'finance@brunchy.in', name: 'Finance', role: 'admin' }, admin);
    secondAdmin = tokenFor({ id: t.body.id, role: 'admin', stallId: null, canteenId: null });
    const self = await client.post(`/admin/settlements/${settlementId}/approve`, {}, admin);
    expect(self.status).toBe(409);
    expect(self.body.error.code).toBe('four_eyes');
    expect((await client.post(`/admin/settlements/${settlementId}/pay`, { bankRef: 'UTR999888' }, secondAdmin)).status).toBe(409); // not approved
    expect((await client.post(`/admin/settlements/${settlementId}/approve`, {}, secondAdmin)).body).toMatchObject({ status: 'approved', approvedByName: 'Finance' });
  });

  it('marking paid needs the bank reference; the ledger shows it', async () => {
    expect((await client.post(`/admin/settlements/${settlementId}/pay`, {}, admin)).status).toBe(400);
    expect((await client.post(`/admin/settlements/${settlementId}/pay`, { bankRef: 'UTR999888' }, admin)).body).toMatchObject({ status: 'paid', bankRef: 'UTR999888' });
    const ledger = await client.get('/admin/settlements-ledger?stallId=1', admin);
    expect(ledger.body.paid).toBe(expectedNet);
    expect(ledger.body.outstanding).toBe(0);
    expect(ledger.body.entries.map((e: { kind: string; status: string }) => `${e.kind}:${e.status}`)).toEqual(expect.arrayContaining(['payout:paid', 'adjustment:paid']));
  });

  it('a refund on a bill already paid out is charged in the next settlement', async () => {
    const paidOut = await one<{ stall_order_id: number; order_id: number }>(pool, 'SELECT so.stall_order_id, so.order_id FROM settlement_bills sb JOIN stall_orders so USING (stall_order_id) LIMIT 1');
    await exec(pool, "INSERT INTO refunds (order_id, stall_order_id, amount, reason_code, status, created_at) VALUES (?, ?, 10, 'KITCHEN_ISSUE', 'approved', UTC_TIMESTAMP() - INTERVAL 1 DAY)", [paidOut!.order_id, paidOut!.stall_order_id]);
    const c = await collectedBill('104', 1);
    const dayBefore = new Date(Date.now() + 330 * 60_000 - 2 * 86_400_000).toISOString().slice(0, 10);
    await exec(pool, 'UPDATE stall_orders SET bill_date = ? WHERE stall_order_id = ?', [dayBefore, c.bill.id]);
    await exec(pool, 'UPDATE refunds SET created_at = ? WHERE stall_order_id = ? AND amount = 10', [`${dayBefore} 06:00:00`, paidOut!.stall_order_id]);
    await client.post('/admin/settlements/prepare', { date: dayBefore }, admin);
    const s = (await client.get(`/admin/settlements?from=${dayBefore}&to=${dayBefore}`, admin)).body.items[0];
    expect(s).toMatchObject({ gross: 40, refunds: 10, netPayout: 40 - 4 - 0.72 - 10 });
    await client.patch('/admin/settings', { vendorCommissionPct: 0 }, admin);
  });
});

describe('reports and growth analytics', () => {
  it('every report answers for the last two weeks', async () => {
    for (const id of ['canteens', 'sales', 'stalls', 'items', 'peak', 'operations', 'students', 'payments', 'cancellations', 'settlement']) {
      const r = await client.get(`/admin/reports/${id}?from=${yesterday}&to=${today}`, admin);
      expect(r.status, id).toBe(200);
      expect(Array.isArray(r.body.rows), id).toBe(true);
    }
    expect((await client.get('/admin/reports/nope', admin)).status).toBe(404);
  });

  it('sales and stall numbers match the orders', async () => {
    const sales = await client.get(`/admin/reports/sales?from=${today}&to=${today}`, admin);
    const day = sales.body.rows.find((r: { period: string }) => r.period === today);
    const paid = await one<{ gross: number; n: number }>(
      pool,
      "SELECT SUM(so.total + so.platform_fee + so.convenience_fee) AS gross, COUNT(DISTINCT so.order_id) AS n FROM stall_orders so WHERE so.bill_date = ? AND so.bill_no IS NOT NULL",
      [today],
    );
    expect(day.grossSales).toBeCloseTo(Number(paid!.gross), 2);
    expect(day.paidOrders).toBe(Number(paid!.n));
    expect(day.refunds).toBeGreaterThan(0);
    const peak = await client.get(`/admin/reports/peak?from=${today}&to=${today}`, admin);
    expect(peak.body.rows).toHaveLength(168);
    const ops = await client.get(`/admin/reports/operations?from=${yesterday}&to=${today}`, admin);
    expect(ops.body.rows[0].stall).toBe('All stalls');
  });

  it('managers only get the cancellations report', async () => {
    expect((await client.get('/admin/reports/cancellations', manager)).status).toBe(200);
    expect((await client.get('/admin/reports/sales', manager)).status).toBe(403);
    expect((await client.get('/admin/analytics', manager)).status).toBe(403);
  });

  it('growth analytics', async () => {
    const a = await client.get(`/admin/analytics?from=${yesterday}&to=${today}`, admin);
    expect(a.status).toBe(200);
    expect(a.body.orders).toBeGreaterThan(0);
    expect(a.body.dau).toBe(1);
    expect(a.body.repeatRate).toBe(1);
    expect(a.body.aovTarget).toBe(150);
    expect(a.body.dailyActive.map((d: { day: string }) => d.day)).toEqual([yesterday, today]);
  });
});

describe('exports', () => {
  it('CSV with BOM, CRLF, IST times and money without ₹; every row, not one page', async () => {
    const res = await fetch(`${server.url}/api/v1/admin/exports/bills?from=${yesterday}&to=${today}&format=csv`, { headers: { authorization: `Bearer ${admin}` } });
    expect(res.headers.get('content-type')).toContain('text/csv');
    const text = new TextDecoder('utf-8', { ignoreBOM: true }).decode(await res.arrayBuffer());
    expect(text.charCodeAt(0)).toBe(0xfeff);
    const lines = text.slice(1).trimEnd().split('\r\n');
    expect(lines[0]).toBe('Bill no,Stall,Canteen,Student,Register no,Email,Items,Total,Status,Payment status,Offer applied,Paid at,Accepted,Ready,Collected,Prep time (s),Wait time (s),Cancel reason');
    const total = (await client.get(`/admin/bills?from=${yesterday}&to=${today}`, admin)).body.total;
    expect(lines.length - 1).toBe(total);
    expect(lines.slice(1).join('\n')).toMatch(/,\d+\.\d{2},/);
    expect(lines.slice(1).join('\n')).toMatch(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/);
  });

  it('JSON exports (Excel) for payments, settlements and the Zoho Books layout; each export is audited', async () => {
    const pay = await client.get('/admin/exports/payments?format=json', admin);
    expect(pay.body.columns[0]).toEqual({ key: 'createdAt', label: 'Time', type: 'datetime' });
    expect(pay.body.rows.length).toBeGreaterThan(0);
    expect((await client.get('/admin/exports/settlements?format=json', admin)).body.rows.length).toBe(2);
    const zoho = await client.get(`/admin/exports/zoho_books?format=json&from=${yesterday}&to=${today}`, admin);
    expect(zoho.body.rows[0]).toMatchObject({ paymentMode: 'UPI', invoiceNumber: expect.stringMatching(/^[A-Z]+-\d{4}$/) });
    const log = await client.get('/admin/audit?action=export', admin);
    expect(log.body.total).toBeGreaterThanOrEqual(4);
    expect((await client.get('/admin/exports/payments?format=json', manager)).status).toBe(403);
    expect((await client.get('/admin/exports/nope', admin)).status).toBe(404);
  });
});
