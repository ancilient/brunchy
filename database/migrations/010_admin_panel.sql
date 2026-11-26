-- Admin panel (admin_web): colleges, categories, live app settings, panel/vendor permissions, account status,
-- login history and internal bill notes. Everything the dashboard changes is read live by the apps.

CREATE TABLE colleges (
  college_id   INT AUTO_INCREMENT PRIMARY KEY,
  college_name VARCHAR(150) NOT NULL UNIQUE,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO colleges (college_name) VALUES ('Main campus');

ALTER TABLE canteens
  ADD COLUMN college_id       INT NULL AFTER canteen_id,
  ADD COLUMN location         VARCHAR(150) NOT NULL DEFAULT '' AFTER canteen_name,
  ADD COLUMN photo_url        VARCHAR(255) NULL,
  ADD COLUMN avg_prep_minutes INT NOT NULL DEFAULT 8,
  ADD COLUMN min_order        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN hidden           BOOLEAN NOT NULL DEFAULT FALSE,   -- hidden canteens keep their data but leave the student app
  ADD CONSTRAINT fk_canteens_college FOREIGN KEY (college_id) REFERENCES colleges (college_id);
UPDATE canteens SET college_id = (SELECT MIN(college_id) FROM colleges) WHERE college_id IS NULL;

ALTER TABLE stalls
  ADD COLUMN photo_url VARCHAR(255) NULL,
  ADD COLUMN paused_at DATETIME NULL AFTER paused_until;

-- Category names and their order in the app. products.category keeps the name (renaming updates the products).
CREATE TABLE categories (
  category_id   INT AUTO_INCREMENT PRIMARY KEY,
  category_name VARCHAR(50) NOT NULL UNIQUE,
  sort_order    INT NOT NULL DEFAULT 100,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO categories (category_name, sort_order)
SELECT category, ROW_NUMBER() OVER (ORDER BY category) * 10 FROM (SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category <> '') c;

ALTER TABLE products
  ADD COLUMN tags           JSON NULL,
  ADD COLUMN sort_order     INT NOT NULL DEFAULT 100,
  ADD COLUMN pending_change JSON NULL,       -- vendor-requested changes to a published item, waiting for approval
  ADD COLUMN deleted_at     DATETIME NULL;   -- deleted from the panel; kept because past order items point at it

-- permissions: panel accounts (admin/manager) {section: off|view|edit}; vendors {acceptOrders, editMenu, ...}.
-- NULL = the role's defaults. account_status: active | blocked | suspended (is_active is FALSE unless active).
ALTER TABLE users
  ADD COLUMN permissions         JSON NULL,
  ADD COLUMN contact_access      BOOLEAN NULL,
  ADD COLUMN account_status      ENUM('active','blocked','suspended') NOT NULL DEFAULT 'active',
  ADD COLUMN status_reason       VARCHAR(255) NULL,
  ADD COLUMN sessions_revoked_at DATETIME NULL,   -- access tokens issued before this stop working
  ADD COLUMN last_login_at       DATETIME NULL,
  ADD COLUMN last_active_at      DATETIME NULL;

-- One row: every setting the panel can change (fees, offers, switches, alerts). Missing keys use the server defaults.
CREATE TABLE app_settings (
  id         TINYINT PRIMARY KEY,
  data       JSON NOT NULL,
  updated_by INT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE login_history (
  login_id       BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id        INT NULL,
  app            VARCHAR(10) NOT NULL,
  device         VARCHAR(200) NOT NULL DEFAULT '',
  app_version    VARCHAR(20) NOT NULL DEFAULT '',
  success        BOOLEAN NOT NULL,
  failure_reason VARCHAR(60) NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_login_history_user (user_id, created_at)
);

-- Internal notes on a bill (admin panel only; the student and vendor never see them).
CREATE TABLE bill_notes (
  note_id        INT AUTO_INCREMENT PRIMARY KEY,
  stall_order_id INT NOT NULL,
  user_id        INT NOT NULL,
  note           VARCHAR(500) NOT NULL,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_bill_notes_bill FOREIGN KEY (stall_order_id) REFERENCES stall_orders (stall_order_id),
  KEY idx_bill_notes_bill (stall_order_id)
);
