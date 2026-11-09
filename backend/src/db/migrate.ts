/**
 * Tiny migration runner. SQL files live in ../database (repo root), applied in file-name order.
 *   npm run db:migrate   apply new files from database/migrations
 *   npm run db:seed      load database/seeds (demo data; only into an empty database)
 *   npm run db:reset     drop every table, then migrate + seed (refused in production)
 */
import { readdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import mysql from 'mysql2/promise';
import { config, isProduction } from '../config.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const databaseDir = path.resolve(here, '../../../database');

async function connect() {
  const conn = await mysql.createConnection({
    host: config.DB_HOST,
    port: config.DB_PORT,
    user: config.DB_USER,
    password: config.DB_PASSWORD,
    database: config.DB_NAME,
    multipleStatements: true,
    timezone: 'Z',
  });
  await conn.query("SET time_zone = '+00:00'");
  return conn;
}

async function sqlFiles(dir: string) {
  const names = (await readdir(path.join(databaseDir, dir))).filter((f) => f.endsWith('.sql')).sort();
  return Promise.all(names.map(async (name) => ({ name, sql: await readFile(path.join(databaseDir, dir, name), 'utf8') })));
}

export async function migrate(log = console.log) {
  const conn = await connect();
  try {
    await conn.query(
      'CREATE TABLE IF NOT EXISTS schema_migrations (name VARCHAR(200) PRIMARY KEY, applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)',
    );
    const [done] = await conn.query<mysql.RowDataPacket[]>('SELECT name FROM schema_migrations');
    const applied = new Set(done.map((r) => r.name as string));
    for (const file of await sqlFiles('migrations')) {
      if (applied.has(file.name)) continue;
      // MySQL commits DDL immediately, so a failed file must be fixed by hand; keep each file small.
      await conn.query(file.sql);
      await conn.query('INSERT INTO schema_migrations (name) VALUES (?)', [file.name]);
      log(`applied ${file.name}`);
    }
  } finally {
    await conn.end();
  }
}

export async function seed(log = console.log) {
  const conn = await connect();
  try {
    const [existing] = await conn.query<mysql.RowDataPacket[]>('SELECT COUNT(*) AS n FROM canteens');
    if (Number(existing[0].n) > 0) {
      log('database already has data; seed skipped (use db:reset to start over)');
      return;
    }
    for (const file of await sqlFiles('seeds')) {
      await conn.query(file.sql);
      log(`seeded ${file.name}`);
    }
  } finally {
    await conn.end();
  }
}

export async function dropAll(log = console.log) {
  if (isProduction) throw new Error('db:reset is not allowed in production');
  const conn = await connect();
  try {
    const [tables] = await conn.query<mysql.RowDataPacket[]>(
      'SELECT table_name AS t FROM information_schema.tables WHERE table_schema = ? AND table_type = "BASE TABLE"',
      [config.DB_NAME],
    );
    await conn.query('SET FOREIGN_KEY_CHECKS = 0');
    for (const { t } of tables) await conn.query(`DROP TABLE \`${t}\``);
    await conn.query('SET FOREIGN_KEY_CHECKS = 1');
    log(`dropped ${tables.length} tables from ${config.DB_NAME}`);
  } finally {
    await conn.end();
  }
}

export async function reset(log = console.log) {
  await dropAll(log);
  await migrate(log);
  await seed(log);
}

const isCli = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isCli) {
  const command = process.argv[2];
  const run = { migrate, seed, reset }[command as 'migrate' | 'seed' | 'reset'];
  if (!run) {
    console.error('usage: tsx src/db/migrate.ts <migrate|seed|reset>');
    process.exit(1);
  }
  run()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
