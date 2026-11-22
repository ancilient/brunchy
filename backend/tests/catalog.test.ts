import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { one, pool } from '../src/db/pool.js';
import { clockTime, photoUrl, runCatalog } from '../src/db/catalog.js';
import { closeAll, resetDb } from './helpers.js';

beforeAll(resetDb);
afterAll(closeAll);

describe('catalog commands (names, prices, photos until the admin dashboard)', () => {
  it('lists canteens, stalls and items with ids', async () => {
    const out = await runCatalog(['list']);
    expect(out).toContain('Canteen 1: Main Canteen');
    expect(out).toContain('Stall 1: Burger Hub');
    expect(out).toMatch(/Item 101: .+ Rs \d+\.\d\d/);
  });

  it('renames a stall, a canteen and an item, and writes the audit log', async () => {
    expect(await runCatalog(['stall:rename', '1', 'Burger Hub Express'])).toBe('Burger Hub -> Burger Hub Express');
    expect((await one(pool, 'SELECT stall_name FROM stalls WHERE stall_id = 1'))?.stall_name).toBe('Burger Hub Express');
    await runCatalog(['canteen:rename', '2', 'Block 3 Canteen']);
    await runCatalog(['item:rename', '101', 'Classic Cheese Burger']);
    expect((await one(pool, 'SELECT product_name FROM products WHERE product_id = 101'))?.product_name).toBe('Classic Cheese Burger');
    const a = await one(pool, "SELECT COUNT(*) AS n FROM audit_log WHERE action = 'admin_rename'");
    expect(Number(a?.n)).toBe(3);
  });

  it('changes a price and sets or removes a photo', async () => {
    await runCatalog(['item:price', '101', '95.50']);
    expect((await one(pool, 'SELECT price FROM products WHERE product_id = 101'))?.price).toBe(95.5);
    await runCatalog(['item:photo', '101', 'https://example.com/burger.jpg']);
    expect((await one(pool, 'SELECT image_url FROM products WHERE product_id = 101'))?.image_url).toBe('https://example.com/burger.jpg');
    await runCatalog(['item:photo', '101', 'none']);
    expect((await one(pool, 'SELECT image_url FROM products WHERE product_id = 101'))?.image_url).toBeNull();
  });

  it('refuses bad input', async () => {
    await expect(runCatalog(['item:price', '101', '-5'])).rejects.toThrow('Price');
    await expect(runCatalog(['stall:rename', '999', 'Nowhere'])).rejects.toThrow('No stall');
    await expect(runCatalog(['item:photo', '101', 'http://insecure.example/x.jpg'])).rejects.toThrow();
    await expect(runCatalog(['nonsense'])).rejects.toThrow('Commands');
  });

  it('changes canteen hours, accepting 12-hour or 24-hour times', async () => {
    expect(clockTime('7:30am')).toBe('07:30:00');
    expect(clockTime('10pm')).toBe('22:00:00');
    expect(clockTime('12am')).toBe('00:00:00');
    expect(clockTime('12:15 PM')).toBe('12:15:00');
    expect(clockTime('22:00')).toBe('22:00:00');
    expect(() => clockTime('10')).toThrow();
    expect(() => clockTime('13pm')).toThrow();
    expect(await runCatalog(['canteen:hours', '1', '7:30am', '10pm'])).toBe('Canteen 1 hours: 7:30 AM - 10:00 PM');
    const c = await one(pool, 'SELECT opening_time, closing_time FROM canteens WHERE canteen_id = 1');
    expect([c?.opening_time, c?.closing_time]).toEqual(['07:30:00', '22:00:00']);
    expect(await runCatalog(['list'])).toContain('(7:30 AM - 10:00 PM)');
    await expect(runCatalog(['canteen:hours', '1', '10pm', '9am'])).rejects.toThrow('after opening');
  });

  it('turns an uploaded file name into the server photo URL', () => {
    process.env.API_DOMAIN = 'api.example.test';
    expect(photoUrl('veg-burger.jpg')).toBe('https://api.example.test/uploads/veg-burger.jpg');
    expect(photoUrl('none')).toBeNull();
    delete process.env.API_DOMAIN;
  });
});
