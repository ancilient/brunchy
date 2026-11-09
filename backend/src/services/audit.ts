import { type Db, exec } from '../db/pool.js';

export interface Actor {
  id: number | null; // null = the system (webhook, background job)
  role: string;
}

export const SYSTEM: Actor = { id: null, role: 'system' };

/** Writes one audit_log row inside the caller's transaction. */
export async function audit(db: Db, actor: Actor, action: string, table: string, recordId: number, oldValue?: unknown, newValue?: unknown) {
  await exec(
    db,
    'INSERT INTO audit_log (actor_user_id, role, action, table_name, record_id, old_value, new_value) VALUES (?, ?, ?, ?, ?, ?, ?)',
    [
      actor.id,
      actor.role,
      action,
      table,
      recordId,
      oldValue === undefined ? null : JSON.stringify(oldValue),
      newValue === undefined ? null : JSON.stringify(newValue),
    ],
  );
}
