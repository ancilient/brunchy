-- Demo vendors may open the stall they belong to (migration 008 does the same for existing databases, but seeds
-- run after migrations on a fresh database, when there are no users yet).
INSERT INTO vendor_stall_access (user_id, stall_id)
SELECT user_id, stall_id FROM users WHERE role = 'vendor' AND stall_id IS NOT NULL;
