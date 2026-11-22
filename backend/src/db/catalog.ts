/**
 * Change canteen, stall and food names, prices and food photos from the command line, until the admin dashboard
 * exists. On the server (in /opt/brunchy/deploy):
 *   docker compose -f docker-compose.prod.yml exec api node dist/db/catalog.js <command> ...
 * Locally:  npx tsx src/db/catalog.ts <command> ...
 *
 *   list                                  canteens, stalls and food items with their ids
 *   canteen:rename <canteenId> "<name>"
 *   stall:rename <stallId> "<name>"
 *   item:rename <productId> "<name>"
 *   item:price <productId> <price>        e.g. 85 or 85.50
 *   item:photo <productId> <url|none>     a full https:// URL, or a file name in deploy/uploads (see docs/admin-guide.md)
 *   item:veg <productId> <yes|no>
 *
 * Every change is written to the audit log, and the menu cache is cleared so the apps show it within seconds.
 */
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { redis } from '../redis.js';
import { audit } from '../services/audit.js';
import { exec, one, pool, rows } from './pool.js';

const ADMIN = { id: null, role: 'admin_cli' };

const fail = (message: string): never => {
  throw new Error(message);
};
const id = (v: string | undefined, what: string) => {
  const n = Number(v);
  return Number.isInteger(n) && n > 0 ? n : fail(`${what} id must be a positive number`);
};
const text = (v: string | undefined, what: string) => {
  const t = (v ?? '').trim();
  if (t.length < 2 || t.length > 100) fail(`${what} must be 2-100 characters (put it in quotes)`);
  return t;
};

async function bustMenus() {
  const keys = await redis.keys('menu:*');
  if (keys.length) await redis.del(...keys);
}

/** A bare file name becomes the server's /uploads URL (files copied to deploy/uploads, served by Caddy). */
export function photoUrl(value: string) {
  if (value === 'none') return null;
  if (/^https:\/\/\S+$/i.test(value)) return value;
  if (/^[\w.-]+\.(jpe?g|png|webp)$/i.test(value)) {
    const domain = process.env.API_DOMAIN;
    return domain ? `https://${domain}/uploads/${value}` : fail('API_DOMAIN is not set, so use a full https:// URL');
  }
  return fail('Use a full https:// URL, a file name like burger.jpg (jpg/png/webp), or none');
}

async function rename(table: 'canteens' | 'stalls' | 'products', column: string, key: string, recordId: number, name: string) {
  const before = await one(pool, `SELECT ${column} AS name FROM ${table} WHERE ${key} = ?`, [recordId]);
  if (!before) fail(`No ${table.slice(0, -1)} with id ${recordId}`);
  await exec(pool, `UPDATE ${table} SET ${column} = ? WHERE ${key} = ?`, [name, recordId]);
  await audit(pool, ADMIN, `admin_rename`, table, recordId, { name: before!.name }, { name });
  return `${before!.name} -> ${name}`;
}

export async function runCatalog(args: string[]): Promise<string> {
  const [command, a, b] = args;
  switch (command) {
    case 'list': {
      const lines: string[] = [];
      for (const c of await rows(pool, 'SELECT canteen_id, canteen_name FROM canteens WHERE is_active = TRUE ORDER BY canteen_id')) {
        lines.push(`Canteen ${c.canteen_id}: ${c.canteen_name}`);
        for (const s of await rows(pool, 'SELECT stall_id, stall_name FROM stalls WHERE canteen_id = ? AND is_active = TRUE ORDER BY stall_id', [c.canteen_id])) {
          lines.push(`  Stall ${s.stall_id}: ${s.stall_name}`);
          for (const p of await rows(pool, 'SELECT product_id, product_name, price, image_url FROM products WHERE stall_id = ? AND is_active = TRUE ORDER BY product_id', [s.stall_id])) {
            lines.push(`    Item ${p.product_id}: ${p.product_name}  Rs ${Number(p.price).toFixed(2)}${p.image_url ? '  [photo]' : ''}`);
          }
        }
      }
      return lines.join('\n');
    }
    case 'canteen:rename':
      return rename('canteens', 'canteen_name', 'canteen_id', id(a, 'Canteen'), text(b, 'Name'));
    case 'stall:rename':
      return rename('stalls', 'stall_name', 'stall_id', id(a, 'Stall'), text(b, 'Name'));
    case 'item:rename':
      return rename('products', 'product_name', 'product_id', id(a, 'Item'), text(b, 'Name'));
    case 'item:price': {
      const productId = id(a, 'Item');
      const price = Number(b);
      if (!Number.isFinite(price) || price <= 0 || price > 10000 || Math.round(price * 100) !== price * 100) fail('Price must be like 85 or 85.50');
      const before = await one(pool, 'SELECT price FROM products WHERE product_id = ?', [productId]);
      if (!before) fail(`No item with id ${productId}`);
      await exec(pool, 'UPDATE products SET price = ? WHERE product_id = ?', [price, productId]);
      await audit(pool, ADMIN, 'admin_price', 'products', productId, { price: before!.price }, { price });
      return `Item ${productId}: Rs ${before!.price} -> Rs ${price} (orders already placed keep their old price)`;
    }
    case 'item:photo': {
      const productId = id(a, 'Item');
      const url = photoUrl((b ?? '').trim());
      const before = await one(pool, 'SELECT image_url FROM products WHERE product_id = ?', [productId]);
      if (!before) fail(`No item with id ${productId}`);
      await exec(pool, 'UPDATE products SET image_url = ? WHERE product_id = ?', [url, productId]);
      await audit(pool, ADMIN, 'admin_photo', 'products', productId, { imageUrl: before!.image_url }, { imageUrl: url });
      return url ? `Item ${productId} photo: ${url}` : `Item ${productId}: photo removed (the app shows an emoji)`;
    }
    case 'item:veg': {
      const productId = id(a, 'Item');
      if (b !== 'yes' && b !== 'no') fail('Use yes or no');
      const r = await exec(pool, 'UPDATE products SET is_veg = ? WHERE product_id = ?', [b === 'yes', productId]);
      if (!r.affectedRows) fail(`No item with id ${productId}`);
      await audit(pool, ADMIN, 'admin_veg', 'products', productId, undefined, { isVeg: b === 'yes' });
      return `Item ${productId}: ${b === 'yes' ? 'veg' : 'non-veg'}`;
    }
    default:
      return fail('Commands: list | canteen:rename | stall:rename | item:rename | item:price | item:photo | item:veg (see docs/admin-guide.md)');
  }
}

const isCli = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isCli) {
  runCatalog(process.argv.slice(2))
    .then(async (out) => {
      if (process.argv[2] !== 'list') await bustMenus();
      console.log(out);
    })
    .catch((err: Error) => {
      console.error(`Error: ${err.message}`);
      process.exitCode = 1;
    })
    .finally(async () => {
      await pool.end();
      redis.disconnect();
    });
}
