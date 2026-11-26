import type { Request } from 'express';
import { z } from 'zod';
import { badRequest } from '../../errors.js';
import { parseId } from '../../util.js';

/** Paged<T> = { items, page, pageSize, total } (handover section 3.2). */
export function paging(req: Request, defaultSize = 50) {
  // Exports (GET /admin/exports/:dataset) reuse the list functions and need every matching row.
  if ((req as Request & { exportAll?: boolean }).exportAll) return { page: 1, pageSize: 100000, limit: 100000, offset: 0 };
  const page = Math.max(1, Number.parseInt(String(req.query.page ?? '1'), 10) || 1);
  const size = Math.min(500, Math.max(1, Number.parseInt(String(req.query.pageSize ?? defaultSize), 10) || defaultSize));
  return { page, pageSize: size, limit: size, offset: (page - 1) * size };
}

/**
 * sort=field:asc|desc on camelCase row fields, mapped to SQL through a whitelist (never user text in SQL).
 * Nulls sort last either way.
 */
export function sortSql(req: Request, columns: Record<string, string>, fallback: string) {
  const raw = String(req.query.sort ?? '');
  const [field, dir] = raw.split(':');
  const col = columns[field];
  if (!col) return fallback;
  const d = dir === 'desc' ? 'DESC' : 'ASC';
  return `(${col}) IS NULL, ${col} ${d}`;
}

export const q = (req: Request, name: string) => {
  const v = req.query[name];
  return v === undefined || v === '' ? undefined : String(v);
};

export const idOf = (value: unknown, what = 'record') => {
  const id = parseId(value);
  if (!id) throw badRequest('invalid', `Invalid ${what} id`);
  return id;
};

/** Numeric strings from <select> fields are accepted wherever an id is expected (section 3.2). */
export const zId = z.union([z.number(), z.string().regex(/^\d+$/)]).transform(Number).pipe(z.number().int().positive());

export const zDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Dates are YYYY-MM-DD');

/** HH:MM or HH:MM:SS → HH:MM:00 */
export const zTime = z
  .string()
  .regex(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/, 'Times are HH:MM (24-hour)')
  .transform((t) => `${t.slice(0, 5)}:00`);

export const istDay = (d = new Date()) => new Date(d.getTime() + 330 * 60_000).toISOString().slice(0, 10);

export function addDays(day: string, n: number) {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
