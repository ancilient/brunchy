-- Strict hierarchy: canteens > stalls > products (blueprint 10.1-10.3).
-- Money is DECIMAL(10,2), ids are INT, all DATETIMEs are UTC, soft deletes via is_active.

CREATE TABLE canteens (
  canteen_id         INT AUTO_INCREMENT PRIMARY KEY,
  canteen_name       VARCHAR(100) NOT NULL UNIQUE,
  opening_time       TIME NOT NULL,
  closing_time       TIME NOT NULL,
  status             ENUM('open','closed') NOT NULL DEFAULT 'open',
  requires_approval  BOOLEAN NOT NULL DEFAULT TRUE,
  last_order_minutes INT NOT NULL DEFAULT 10,
  latitude           DECIMAL(9,6) NULL,
  longitude          DECIMAL(9,6) NULL,
  is_active          BOOLEAN NOT NULL DEFAULT TRUE,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE stalls (
  stall_id          INT AUTO_INCREMENT PRIMARY KEY,
  canteen_id        INT NOT NULL,
  stall_name        VARCHAR(100) NOT NULL,
  bill_prefix       VARCHAR(5) NOT NULL,
  gst_rate          DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  status            ENUM('open','paused','closed') NOT NULL DEFAULT 'open',
  paused_until      DATETIME NULL,
  category          VARCHAR(100) NULL,
  accent_color      VARCHAR(9) NULL,
  icon_name         VARCHAR(40) NULL,
  avg_prep_minutes  INT NOT NULL DEFAULT 5,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_stalls_canteen FOREIGN KEY (canteen_id) REFERENCES canteens (canteen_id),
  UNIQUE KEY uq_stalls_prefix (canteen_id, bill_prefix),
  KEY idx_stalls_canteen (canteen_id)
);

CREATE TABLE products (
  product_id        INT AUTO_INCREMENT PRIMARY KEY,
  stall_id          INT NOT NULL,
  product_name      VARCHAR(150) NOT NULL,
  category          VARCHAR(50) NULL,
  description       VARCHAR(255) NULL,
  price             DECIMAL(10,2) NOT NULL,
  stock_quantity    INT NOT NULL DEFAULT 0,
  daily_default_qty INT NOT NULL DEFAULT 0,
  prep_minutes      INT NULL,
  image_url         VARCHAR(255) NULL,
  is_veg            BOOLEAN NOT NULL DEFAULT TRUE,
  approval_status   ENUM('draft','pending','published','rejected') NOT NULL DEFAULT 'draft',
  rejection_reason  VARCHAR(255) NULL,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_by        INT NULL,
  approved_by       INT NULL,
  approved_at       DATETIME NULL,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_products_stall FOREIGN KEY (stall_id) REFERENCES stalls (stall_id),
  CONSTRAINT chk_products_stock CHECK (stock_quantity >= 0),
  CONSTRAINT chk_products_price CHECK (price >= 0),
  KEY idx_products_stall (stall_id, is_active)
);

-- Which published products are on the menu on a given (IST) date. Chosen by the canteen manager.
CREATE TABLE daily_menu (
  menu_date   DATE NOT NULL,
  product_id  INT NOT NULL,
  added_by    INT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (menu_date, product_id),
  CONSTRAINT fk_daily_menu_product FOREIGN KEY (product_id) REFERENCES products (product_id),
  KEY idx_daily_menu_product (product_id)
);
