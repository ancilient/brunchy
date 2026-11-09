-- Users of every role, and refresh tokens for OTP login (blueprint 10.3, 11).
-- OTP codes themselves live only in Redis with a short expiry, never in MySQL.

CREATE TABLE users (
  user_id               INT AUTO_INCREMENT PRIMARY KEY,
  name                  VARCHAR(100) NOT NULL,
  register_no           VARCHAR(30) NULL UNIQUE,
  email                 VARCHAR(150) NULL UNIQUE,
  phone                 VARCHAR(15) NULL UNIQUE,
  role                  ENUM('student','vendor','manager','admin') NOT NULL DEFAULT 'student',
  stall_id              INT NULL,   -- vendors: the one stall they work at
  canteen_id            INT NULL,   -- managers: their canteen; students: last used canteen
  no_show_count         INT NOT NULL DEFAULT 0,
  ordering_paused_until DATETIME NULL,
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_users_stall FOREIGN KEY (stall_id) REFERENCES stalls (stall_id),
  CONSTRAINT fk_users_canteen FOREIGN KEY (canteen_id) REFERENCES canteens (canteen_id)
);

CREATE TABLE refresh_tokens (
  token_id    INT AUTO_INCREMENT PRIMARY KEY,
  token_hash  CHAR(64) NOT NULL UNIQUE,   -- sha256 of the token; the token itself is never stored
  user_id     INT NOT NULL,
  expires_at  DATETIME NOT NULL,
  revoked_at  DATETIME NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users (user_id),
  KEY idx_refresh_tokens_user (user_id)
);
