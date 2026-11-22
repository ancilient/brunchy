import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { one, pool } from '../src/db/pool.js';
import { photoUrl, runCatalog } from '../src/db/catalog.js';
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

  it('turns an uploaded file name into the server photo URL', () => {
    process.env.API_DOMAIN = 'api.example.test';
    expect(photoUrl('veg-burger.jpg')).toBe('https://api.example.test/uploads/veg-burger.jpg');
    expect(photoUrl('none')).toBeNull();
    delete process.env.API_DOMAIN;
  });
});
