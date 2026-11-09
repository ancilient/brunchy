import mysql, { type PoolConnection, type ResultSetHeader, type RowDataPacket } from 'mysql2/promise';
import { config } from '../config.js';

export const pool = mysql.createPool({
  host: config.DB_HOST,
  port: config.DB_PORT,
  user: config.DB_USER,
  password: config.DB_PASSWORD,
  database: config.DB_NAME,
  connectionLimit: 20,
  timezone: 'Z', // DATETIME values are UTC (blueprint 10.1)
  decimalNumbers: true, // DECIMAL(10,2) comes back as a JS number
  dateStrings: false,
});

// Every connection works in UTC, so NOW()/CURRENT_TIMESTAMP are UTC too.
pool.on('connection', (conn) => {
  conn.query("SET time_zone = '+00:00'");
});

export type Db = Pick<PoolConnection, 'query' | 'execute'>;
export type Row = RowDataPacket;

export async function rows<T = Row>(db: Db, sql: string, params: unknown[] = []): Promise<T[]> {
  const [result] = await db.query<RowDataPacket[]>(sql, params);
  return result as T[];
}

export async function one<T = Row>(db: Db, sql: string, params: unknown[] = []): Promise<T | undefined> {
  return (await rows<T>(db, sql, params))[0];
}

export async function exec(db: Db, sql: string, params: unknown[] = []): Promise<ResultSetHeader> {
  const [result] = await db.query<ResultSetHeader>(sql, params);
  return result;
}

/** Runs `fn` inside one transaction; commits if it returns, rolls back if it throws. */
export async function withTx<T>(fn: (conn: PoolConnection) => Promise<T>): Promise<T> {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const result = await fn(conn);
    await conn.commit();
    return result;
  } catch (err) {
    await conn.rollback().catch(() => undefined);
    throw err;
  } finally {
    conn.release();
  }
}

export const isDuplicateKey = (err: unknown) => (err as { code?: string })?.code === 'ER_DUP_ENTRY';

/** Today's date in India (bill numbers and the daily menu restart every IST day). */
export const IST_TODAY = "DATE(CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '+05:30'))";
