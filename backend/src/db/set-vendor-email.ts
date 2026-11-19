/**
 * Registers the Google account (email) that signs in to the vendor app for a stall.
 *   npm run vendor:email -- <stallId> <email>
 *   npm run vendor:email -- 1 someone@gmail.com      # Burger Hub's vendor signs in with that Google account
 * Kept out of the seed file on purpose: real email addresses don't belong in the (public) repository.
 */
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { exec, isDuplicateKey, one, pool } from './pool.js';

async function main() {
  const [stallArg, emailArg] = process.argv.slice(2);
  const stallId = Number(stallArg);
  const email = (emailArg ?? '').trim().toLowerCase();
  if (!Number.isInteger(stallId) || stallId < 1 || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    console.error('usage: npm run vendor:email -- <stallId> <email>');
    process.exit(1);
  }
  const vendor = await one<{ user_id: number; name: string }>(pool, "SELECT user_id, name FROM users WHERE role = 'vendor' AND stall_id = ? ORDER BY user_id LIMIT 1", [stallId]);
  if (!vendor) {
    console.error(`No vendor account for stall ${stallId}. Run npm run db:reset for the demo data.`);
    process.exit(1);
  }
  try {
    // google_sub is cleared so the new Google account links itself on its first sign-in.
    await exec(pool, 'UPDATE users SET email = ?, google_sub = NULL WHERE user_id = ?', [email, vendor.user_id]);
  } catch (err) {
    if (isDuplicateKey(err)) {
      console.error(`${email} is already used by another account (one Google account = one student or one vendor).`);
      process.exit(1);
    }
    throw err;
  }
  console.log(`${vendor.name} (stall ${stallId}) now signs in with Google account ${email}`);
}

const isCli = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isCli) {
  main()
    .then(() => pool.end())
    .catch(async (err) => {
      console.error(err);
      await pool.end();
      process.exit(1);
    });
}
