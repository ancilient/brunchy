-- Which stalls a vendor account may open. After Google sign-in the vendor app asks for a canteen and a stall, and
-- POST /vendor/session/stall issues tokens scoped to the chosen stall, but only if a row here allows it.
CREATE TABLE vendor_stall_access (
  user_id    INT NOT NULL,
  stall_id   INT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, stall_id),
  CONSTRAINT fk_vendor_stall_access_user FOREIGN KEY (user_id) REFERENCES users (user_id),
  CONSTRAINT fk_vendor_stall_access_stall FOREIGN KEY (stall_id) REFERENCES stalls (stall_id),
  KEY idx_vendor_stall_access_stall (stall_id)
);

-- Every existing vendor keeps access to the stall they already work at.
INSERT INTO vendor_stall_access (user_id, stall_id)
SELECT user_id, stall_id FROM users WHERE role = 'vendor' AND stall_id IS NOT NULL;

-- The stall a session was opened for. NULL = the old behaviour: the token uses users.stall_id.
ALTER TABLE refresh_tokens
  ADD COLUMN stall_id INT NULL AFTER user_id,
  ADD CONSTRAINT fk_refresh_tokens_stall FOREIGN KEY (stall_id) REFERENCES stalls (stall_id);
