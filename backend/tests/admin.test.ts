import { readdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { config } from '../src/config.js';
import { one, pool } from '../src/db/pool.js';
import { type GoogleIdentity, setGoogleVerifierForTests } from '../src/services/auth.js';
import { api, closeAll, createStudent, key, placePaidOrder, resetDb, startServer, studentToken } from './helpers.js';

/**
 * The admin panel (admin_web) working together with the student and vendor apps: everything an admin changes must
 * show up in the apps. Seed: canteen 1 (Main Canteen, stalls 1-4), canteen 2 (stalls 5-6), user 8 = Main Canteen
 * manager, user 9 = admin, user 1 = demo student.
 */
let server: Awaited<ReturnType<typeof startServer>>;
let client: ReturnType<typeof api>;
let admin: string;
let manager: string;
let adminCookie: string;

const identities: Record<string, GoogleIdentity> = {
  'token-new-vendor': { sub: 'g-v1', email: 'priya.stall@gmail.com', emailVerified: true, name: 'Priya' },
  'token-admin-google': { sub: 'g-a1', email: 'ops@brunchy.in', emailVerified: true, name: 'Ops' },
  'token-stranger': { sub: 'g-s1', email: 'someone@gmail.com', emailVerified: true, name: 'Someone' },
};
const google = (token: string, app: 'student' | 'vendor' | 'admin') => client.post('/auth/google', { idToken: 'x'.repeat(20) + token, app });

/** POST /admin/uploads with a real (tiny) JPEG, as the panel sends it after resizing in the browser. */
async function upload(token: string, bytes: Uint8Array, type = 'image/jpeg') {
  const fd = new FormData();
  fd.append('file', new Blob([bytes as BlobPart], { type }), 'photo.jpg');
  const res = await fetch(`${server.url}/api/v1/admin/uploads`, { method: 'POST', headers: { authorization: `Bearer ${token}` }, body: fd });
  return { status: res.status, body: await res.json() };
}
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0xff, 0xd9]);
const uploadsBefore = new Set<string>();

beforeAll(async () => {
  await resetDb();
  server = await startServer();
  client = api(server.url);
  for (const f of await readdir(path.resolve(config.UPLOADS_DIR)).catch(() => [])) uploadsBefore.add(f);
});
beforeEach(() => {
  setGoogleVerifierForTests(async (idToken) => {
    const id = identities[idToken.replace(/^x+/, '')];
    if (!id) throw new Error('bad token');
    return id;
  });
});
afterAll(async () => {
  // Remove the photos this test uploaded.
  const dir = path.resolve(config.UPLOADS_DIR);
  for (const f of await readdir(dir).catch(() => [])) if (!uploadsBefore.has(f)) await rm(path.join(dir, f));
  await server.close();
  await closeAll();
});

describe('admin panel sign-in', () => {
  it('dev login gives a panel session and sets the refresh cookie (no refresh token in the body)', async () => {
    const res = await fetch(`${server.url}/api/v1/auth/dev-login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', origin: 'http://localhost:5173' },
      body: JSON.stringify({ app: 'admin', role: 'admin' }),
    });
    const body = await res.json();
    expect(res.status).toBe(200);
    expect(body.refreshToken).toBeUndefined();
    expect(body.user).toMatchObject({ id: 9, role: 'admin', canteenId: null, contactAccess: true, twoFactor: false });
    expect(body.user.permissions).toEqual({ orders: 'edit', payments: 'edit', users: 'edit', vendors: 'edit', ads: 'edit', content: 'edit', settings: 'edit' });
    expect(res.headers.get('access-control-allow-origin')).toBe('http://localhost:5173');
    expect(res.headers.get('access-control-allow-credentials')).toBe('true');
    const cookie = res.headers.get('set-cookie') ?? '';
    expect(cookie).toMatch(/brunchy_admin_rt=[0-9a-f]{64}/);
    expect(cookie).toMatch(/HttpOnly/i);
    adminCookie = cookie.split(';')[0];
    admin = body.accessToken;
  });

  it('page reload: POST /auth/refresh with the cookie signs the admin in again', async () => {
    const res = await fetch(`${server.url}/api/v1/auth/refresh`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', cookie: adminCookie },
      body: JSON.stringify({ app: 'admin' }),
    });
    expect(res.status).toBe(200);
    expect((await res.json()).user.role).toBe('admin');
    // Without the cookie: signed out (the page shows sign-in).
    expect((await client.post('/auth/refresh', { app: 'admin' })).status).toBe(401);
  });

  it('other websites never get the cookie answer (no credentials CORS for unknown origins)', async () => {
    const res = await fetch(`${server.url}/api/v1/auth/options`, { headers: { origin: 'https://evil.example' } });
    expect(res.headers.get('access-control-allow-origin')).toBe('*');
    expect(res.headers.get('access-control-allow-credentials')).toBeNull();
  });

  it('manager session: own canteen only, no payments or settings', async () => {
    const r = await client.post('/auth/dev-login', { app: 'admin', role: 'manager' });
    expect(r.body.user).toMatchObject({ id: 8, role: 'manager', canteenId: 1, contactAccess: false });
    expect(r.body.user.permissions).toMatchObject({ payments: 'off', settings: 'off', content: 'edit', orders: 'edit' });
    manager = r.body.accessToken;
  });

  it('students, vendors and unknown Google accounts cannot open the panel', async () => {
    expect((await client.get('/admin/canteens', studentToken())).status).toBe(403);
    expect((await google('token-stranger', 'admin')).status).toBe(403);
  });

  it('an admin added under Team & access signs in with Google', async () => {
    const r = await client.post('/admin/team', { email: 'ops@brunchy.in', name: 'Ops', role: 'admin', contactAccess: false }, admin);
    expect(r.status).toBe(201);
    const g = await google('token-admin-google', 'admin');
    expect(g.status).toBe(200);
    expect(g.body.user).toMatchObject({ email: 'ops@brunchy.in', role: 'admin', contactAccess: false });
    expect((await google('token-admin-google', 'student')).status).toBe(403); // panel accounts can't use the student app
  });
});

describe('canteen, stall, vendor, item, price and GST: admin → vendor app → student app', () => {
  let canteenId: number;
  let stallId: number;
  let vendorToken: string;
  let productId: number;
  let photoUrl: string;

  it('creates a canteen (shows in the student app)', async () => {
    const r = await client.post(
      '/admin/canteens',
      { name: 'Hostel Canteen', collegeId: '1', location: 'Hostel block', openingTime: '07:00', closingTime: '22:00', lastOrderMinutes: 10, avgPrepMinutes: 8, minOrder: 0, status: 'open', requiresApproval: true, hidden: false },
      admin,
    );
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ name: 'Hostel Canteen', openingTime: '07:00', closingTime: '22:00', collegeId: 1, hidden: false });
    canteenId = r.body.id;
    const apps = await client.get('/canteens', studentToken());
    expect(apps.body.canteens.map((c: { name: string }) => c.name)).toContain('Hostel Canteen');
    expect((await client.post('/admin/canteens', { ...r.body, collegeId: 1 }, admin)).status).toBe(409); // same name
  });

  it('managers cannot create canteens or edit another canteen', async () => {
    expect((await client.post('/admin/canteens', { name: 'X', collegeId: 1, openingTime: '08:00', closingTime: '18:00' }, manager)).status).toBe(403);
    expect((await client.patch(`/admin/canteens/2`, { status: 'closed' }, manager)).status).toBe(403);
    expect((await client.patch(`/admin/canteens/1`, { name: 'Renamed' }, manager)).status).toBe(403);
    expect((await client.get('/admin/canteens', manager)).body.items.map((c: { id: number }) => c.id)).toEqual([1]);
  });

  it('creates a stall with its GST rate (starts closed); bill prefix is unique in the canteen', async () => {
    const r = await client.post('/admin/stalls', { canteenId: String(canteenId), name: 'Dosa Den', billPrefix: 'dd', gstRate: 5, category: 'South Indian', avgPrepMinutes: 6, colour: '#0d9488', icon: 'soup' }, admin);
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ name: 'Dosa Den', billPrefix: 'DD', gstRate: 5, status: 'closed', canteenId });
    stallId = r.body.id;
    expect((await client.post('/admin/stalls', { canteenId, name: 'Other', billPrefix: 'DD', gstRate: 0 }, admin)).status).toBe(409);
  });

  it('edits the stall GST rate', async () => {
    const r = await client.patch(`/admin/stalls/${stallId}`, { gstRate: 12 }, admin);
    expect(r.status).toBe(200);
    expect(r.body.gstRate).toBe(12);
  });

  it('creates a vendor account; the vendor signs in with Google and can open only that stall', async () => {
    const r = await client.post(
      '/admin/vendors',
      { email: 'Priya.Stall@gmail.com', name: 'Priya', canteenId: String(canteenId), stallId: String(stallId), permissions: { acceptOrders: true, editMenu: true, changePrices: false, uploadPhotos: true, viewEarnings: true } },
      admin,
    );
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ email: 'priya.stall@gmail.com', role: 'vendor', stallName: 'Dosa Den', canteenName: 'Hostel Canteen' });
    expect((await client.post('/admin/vendors', { email: 'priya.stall@gmail.com', name: 'Again', canteenId, stallId: null }, admin)).status).toBe(409);

    const g = await google('token-new-vendor', 'vendor');
    expect(g.status).toBe(200);
    const stalls = await client.get(`/canteens/${canteenId}/stalls`, g.body.accessToken);
    expect(stalls.body.stalls).toEqual([{ id: String(stallId), canteenId: String(canteenId), name: 'Dosa Den' }]);
    const session = await client.post('/vendor/session/stall', { stallId: String(stallId) }, g.body.accessToken);
    expect(session.status).toBe(200);
    vendorToken = session.body.accessToken;
    // The vendor opens the stall from the vendor app.
    expect((await client.post('/vendor/stall/status', { action: 'resume' }, vendorToken)).body.stall.status).toBe('open');
    const vendors = await client.get(`/admin/users?role=vendor&canteenId=${canteenId}`, admin);
    expect(vendors.body.items[0]).toMatchObject({ name: 'Priya', status: 'active' });
    expect(vendors.body.items[0].lastLoginAt).not.toBeNull();
  });

  it('uploads a photo (JPEG only, 2 MB max)', async () => {
    const r = await upload(admin, JPEG);
    expect(r.status).toBe(201);
    expect(r.body.url).toMatch(/\/uploads\/\d+-[0-9a-f]{12}\.jpg$/);
    photoUrl = r.body.url;
    const served = await fetch(photoUrl);
    expect(served.status).toBe(200);
    expect((await upload(admin, new TextEncoder().encode('not an image'))).status).toBe(422);
    expect((await upload(admin, new Uint8Array(2 * 1024 * 1024 + 10).fill(0xff))).status).toBe(413);
  });

  it('adds a food item with the photo: it is on sale in the student app and the vendor app at once', async () => {
    const r = await client.post(
      '/admin/products',
      { stallId: String(stallId), name: 'Ghee Roast', description: 'Crispy ghee dosa', category: 'Dosa', price: 70, veg: true, tags: ['popular'], imageUrl: photoUrl, stock: 20, dailyDefaultQty: 30, prepMinutes: 6, sortOrder: 10, available: true },
      admin,
    );
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ name: 'Ghee Roast', price: 70, approvalStatus: 'published', available: true, imageUrl: photoUrl, stallName: 'Dosa Den', tags: ['popular'] });
    productId = r.body.id;

    const menu = await client.get(`/canteens/${canteenId}/menu`, studentToken());
    const item = menu.body.stalls.find((s: { id: string }) => s.id === String(stallId)).products[0];
    expect(item).toMatchObject({ name: 'Ghee Roast', price: 70, imageUrl: photoUrl, stockQuantity: 20 });
    const vendorMenu = await client.get('/vendor/products', vendorToken);
    expect(vendorMenu.body.products[0]).toMatchObject({ name: 'Ghee Roast', onTodaysMenu: true });
    // The new category joins the category list.
    expect((await client.get('/admin/categories', admin)).body.items.map((c: { name: string }) => c.name)).toContain('Dosa');
  });

  it('changes the price: the student app shows it and checkout charges it; the bill keeps the stall GST rate', async () => {
    expect((await client.patch(`/admin/products/${productId}`, { price: 75.5 }, admin)).body.price).toBe(75.5);
    const menu = await client.get(`/canteens/${canteenId}/menu`, studentToken());
    expect(menu.body.stalls.find((s: { id: string }) => s.id === String(stallId)).products[0].price).toBe(75.5);

    const student = await createStudent();
    const order = await placePaidOrder(client, studentToken(student), [{ productId: String(productId), qty: 2 }], String(canteenId));
    expect(order.subtotal).toBe(151);
    const item = await one(pool, 'SELECT price, gst_rate FROM order_items WHERE product_id = ?', [productId]);
    expect(item).toMatchObject({ price: 75.5, gst_rate: 12 });
  });

  it('bulk price change rounds to ₹0.50 and is audited', async () => {
    const r = await client.post('/admin/products/bulk', { ids: [productId], op: 'pct', value: 10 }, admin); // 75.50 + 10% = 83.05 → 83.00
    expect(r.body).toEqual({ updated: 1 });
    expect((await client.get(`/admin/products?stallId=${stallId}`, admin)).body.items[0].price).toBe(83);
    const log = await client.get(`/admin/audit?table=products&recordId=${productId}`, admin);
    expect(log.body.items.map((a: { action: string }) => a.action)).toEqual(expect.arrayContaining(['admin_product_create', 'admin_product_update', 'admin_product_bulk']));
  });

  it('sold out from the panel shows sold out in the student app', async () => {
    await client.patch(`/admin/products/${productId}`, { available: false }, admin);
    const menu = await client.get(`/canteens/${canteenId}/menu`, studentToken());
    expect(menu.body.stalls.find((s: { id: string }) => s.id === String(stallId)).products[0].stockState).toBe('sold_out');
    await client.patch(`/admin/products/${productId}`, { available: true }, admin);
  });

  it('vendor permissions are enforced in the vendor app; disabling the vendor signs them out at once', async () => {
    const vendor = (await one<{ user_id: number }>(pool, "SELECT user_id FROM users WHERE email = 'priya.stall@gmail.com'"))!.user_id;
    await client.patch(`/admin/users/${vendor}`, { permissions: { acceptOrders: true, editMenu: false, changePrices: false, uploadPhotos: false, viewEarnings: false }, reason: 'Trainee' }, admin);
    expect((await client.patch(`/vendor/products/${productId}`, { stockQuantity: 5 }, vendorToken)).status).toBe(403);
    expect((await client.get('/vendor/reports/dashboard', vendorToken)).status).toBe(403);
    expect((await client.get('/vendor/bills', vendorToken)).status).toBe(200);

    const off = await client.patch(`/admin/users/${vendor}`, { status: 'suspended', reason: 'Left the job' }, admin);
    expect(off.body).toMatchObject({ status: 'suspended', active: false });
    expect((await client.get('/vendor/bills', vendorToken)).status).toBe(401);
    expect((await google('token-new-vendor', 'vendor')).status).toBe(403);
    await client.patch(`/admin/users/${vendor}`, { status: 'active', reason: 'Back' }, admin);
    expect((await google('token-new-vendor', 'vendor')).status).toBe(200);
  });

  it('daily menu: save and read a day; deleting an item removes it from the menus', async () => {
    const today = new Date(Date.now() + 330 * 60_000).toISOString().slice(0, 10);
    expect((await client.get(`/admin/daily-menu?canteenId=${canteenId}&date=${today}`, admin)).body.productIds).toEqual([productId]);
    expect((await client.put('/admin/daily-menu', { canteenId, date: today, productIds: [] }, admin)).body).toEqual({ ok: true, count: 0 });
    let menu = await client.get(`/canteens/${canteenId}/menu`, studentToken());
    expect(menu.body.stalls.find((s: { id: string }) => s.id === String(stallId)).products).toEqual([]);
    await client.put('/admin/daily-menu', { canteenId, date: today, productIds: [productId] }, admin);
    expect((await client.get(`/admin/daily-menu?canteenId=${canteenId}&month=${today.slice(0, 7)}`, admin)).body.days[today]).toBe(1);

    expect((await client.delete(`/admin/products/${productId}`, admin)).status).toBe(204);
    menu = await client.get(`/canteens/${canteenId}/menu`, studentToken());
    expect(menu.body.stalls.find((s: { id: string }) => s.id === String(stallId)).products).toEqual([]);
    expect((await client.get(`/admin/products?stallId=${stallId}`, admin)).body.total).toBe(0);
  });

  it('hiding a canteen removes it from the student app (vendors still see it)', async () => {
    await client.patch(`/admin/canteens/${canteenId}`, { hidden: true }, admin);
    expect((await client.get('/canteens', studentToken())).body.canteens.map((c: { name: string }) => c.name)).not.toContain('Hostel Canteen');
    await client.patch(`/admin/canteens/${canteenId}`, { hidden: false }, admin);
  });

  it('a stall with orders cannot be removed; a canteen with stalls cannot be deleted', async () => {
    expect((await client.delete(`/admin/stalls/${stallId}`, admin)).status).toBe(409);
    expect((await client.delete(`/admin/canteens/${canteenId}`, admin)).body.error.code).toBe('has_history');
  });
});

describe('fees, GST number and app switches (Fees & app settings)', () => {
  it('changing the convenience fee changes the next checkout and GET /app-config, not past orders', async () => {
    const before = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }]); // ₹60, 3% + 3%
    expect(before.total).toBe(63.6);
    const r = await client.patch('/admin/settings', { convenienceFeePct: 5 }, admin);
    expect(r.status).toBe(200);
    expect(r.body.convenienceFeePct).toBe(5);
    const after = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }]); // 3% + 5%
    expect(after.total).toBe(64.8);
    expect((await client.get('/app-config')).body.fees.conveniencePercent).toBe(5);
    expect((await client.get(`/orders/${before.id}`, studentToken())).body.order.total).toBe(63.6);
  });

  it('sets the GST number printed on bills (served to the student app)', async () => {
    expect((await client.patch('/admin/settings', { gstin: '33abcde1234f1z5' }, admin)).body.gstin).toBe('33ABCDE1234F1Z5');
    expect((await client.get('/app-config')).body.gstin).toBe('33ABCDE1234F1Z5');
    expect((await client.patch('/admin/settings', { gstin: '123' }, admin)).status).toBe(400);
  });

  it('refuses out-of-range values and unknown fields; managers cannot change settings', async () => {
    expect((await client.patch('/admin/settings', { convenienceFeePct: 30 }, admin)).status).toBe(400);
    expect((await client.patch('/admin/settings', { somethingElse: 1 }, admin)).status).toBe(400);
    expect((await client.patch('/admin/settings', { convenienceFeePct: 4 }, manager)).status).toBe(403);
  });

  it('ordering paused and the minimum order are enforced at checkout', async () => {
    await client.patch('/admin/settings', { orderingPaused: true }, admin);
    expect((await client.post('/checkout', { canteenId: '1', items: [{ productId: '102', qty: 1 }], idempotencyKey: key() }, studentToken())).body.error.code).toBe('ORDERING_PAUSED_GLOBAL');
    await client.patch('/admin/settings', { orderingPaused: false, minOrderValue: 100 }, admin);
    expect((await client.post('/checkout', { canteenId: '1', items: [{ productId: '102', qty: 1 }], idempotencyKey: key() }, studentToken())).body.error.code).toBe('BELOW_MIN_ORDER');
    await client.patch('/admin/settings', { minOrderValue: 0, convenienceFeePct: 3 }, admin);
  });
});

describe('orders & bills', () => {
  let billId: number;
  let code: string;

  it('lists today\'s bills with what the student paid, and opens one', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '104', qty: 1 }]); // French Fries ₹40 at Burger Hub
    billId = Number(order.bills[0].id);
    code = order.bills[0].pickupCode;
    const list = await client.get(`/admin/bills?q=${order.bills[0].billNo}`, admin);
    expect(list.body.items[0]).toMatchObject({ id: billId, stallName: 'Burger Hub', status: 'new', paymentStatus: 'paid', total: 42.4, itemCount: 1 });
    const d = await client.get(`/admin/bills/${billId}`, admin);
    expect(d.body.items[0]).toMatchObject({ name: 'French Fries', price: 40, quantity: 1, status: 'ok' });
    expect(d.body.breakdown).toMatchObject({ itemTotal: 40, convenienceFee: 2.4, orderTotal: 42.4, netToVendor: 40 });
    expect(d.body.payments[0].status).toBe('success');
  });

  it('managers see their canteen only', async () => {
    expect((await client.get(`/admin/bills/${billId}`, manager)).status).toBe(200);
    const other = await placePaidOrder(client, studentToken(), [{ productId: '601', qty: 1 }], '2');
    expect((await client.get(`/admin/bills/${other.bills[0].id}`, manager)).status).toBe(403);
    const list = await client.get('/admin/bills?canteenId=2', manager);
    expect(list.body.items.every((b: { canteenId: number }) => b.canteenId === 1)).toBe(true);
  });

  it('change status, note, and mark picked up with the student\'s code (the vendor app sees it)', async () => {
    expect((await client.post(`/admin/bills/${billId}/status`, { status: 'ready', reason: 'Vendor app offline' }, admin)).status).toBe(200);
    expect((await client.post(`/admin/bills/${billId}/notes`, { text: 'Called the stall' }, admin)).status).toBe(200);
    expect((await client.post(`/admin/bills/${billId}/collect`, { code: code === '999' ? '998' : '999', reason: 'x' }, admin)).status).toBe(422);
    expect((await client.post(`/admin/bills/${billId}/collect`, { code, reason: 'Vendor app offline at handover' }, admin)).status).toBe(200);
    const d = await client.get(`/admin/bills/${billId}`, admin);
    expect(d.body.bill.status).toBe('collected');
    expect(d.body.notes[0]).toMatchObject({ text: 'Called the stall', byName: 'Ancilient Admin' });
    expect(d.body.timeline.map((t: { label: string }) => t.label).join(' | ')).toContain('admin: collect');
    const vendor = await client.get('/vendor/bills?status=collected', (await client.post('/auth/dev-login', { app: 'vendor', stallId: 1 })).body.accessToken);
    expect(vendor.body.bills.map((b: { id: string }) => b.id)).toContain(String(billId));
  });

  it('cancel and refund (needs payments edit: managers cannot)', async () => {
    const order = await placePaidOrder(client, studentToken(), [{ productId: '102', qty: 1 }]);
    const id = order.bills[0].id;
    expect((await client.post(`/admin/bills/${id}/cancel`, { reasonCode: 'KITCHEN_ISSUE', reason: 'Gas' }, manager)).status).toBe(403);
    expect((await client.post(`/admin/bills/${id}/cancel`, { reasonCode: 'KITCHEN_ISSUE', reason: 'Gas' }, admin)).status).toBe(200);
    const d = await client.get(`/admin/bills/${id}`, admin);
    expect(d.body.bill.status).toBe('cancelled');
    expect(d.body.refunds[0]).toMatchObject({ amount: 63.6, status: 'requested', reasonCode: 'KITCHEN_ISSUE' });
    expect((await client.get(`/orders/${order.id}`, studentToken())).body.order.bills[0].status).toBe('cancelled');
  });

  it('dashboard overview has today\'s numbers; money is hidden from accounts without payments access', async () => {
    const o = await client.get('/admin/overview', admin);
    expect(o.status).toBe(200);
    expect(o.body.kpis.paidOrders.today).toBeGreaterThan(0);
    expect(o.body.kpis.grossSales.today).toBeGreaterThan(0);
    expect(o.body.canteenSnapshot.length).toBeGreaterThanOrEqual(3);
    const m = await client.get('/admin/overview', manager);
    expect(m.body.kpis.grossSales).toBeNull();
    expect(m.body.canteenSnapshot.map((c: { id: number }) => c.id)).toEqual([1]);
  });
});

describe('students list', () => {
  it('masks contact data for accounts without contact access', async () => {
    await pool.query("UPDATE users SET email = 'demo.student@college.in' WHERE user_id = 1");
    const a = await client.get('/admin/users?role=student&q=Demo', admin);
    expect(a.body.items[0]).toMatchObject({ name: 'Demo Student', email: 'demo.student@college.in' });
    expect(a.body.items[0].orders).toBeGreaterThan(0);
    const m = await client.get('/admin/users?role=student&q=Demo', manager);
    expect(m.body.items[0].email).toBe('d•••@college.in');
  });

  it('blocking a student ends their sessions and stops sign-in', async () => {
    const id = await createStudent();
    const r = await client.patch(`/admin/users/${id}`, { status: 'blocked', reason: 'Abuse' }, admin);
    expect(r.body).toMatchObject({ status: 'blocked', active: false, statusReason: 'Abuse' });
    const log = await client.get(`/admin/audit?table=users&recordId=${id}`, admin);
    expect(log.body.items[0]).toMatchObject({ action: 'admin_user_update', actorName: 'Ancilient Admin' });
  });
});
