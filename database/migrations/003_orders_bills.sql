-- One order per payment, one bill (stall_order) per stall, item snapshot (blueprint 4.2, 10.3).
-- Change from the blueprint: the QR token is replaced by a 3-digit pickup code
-- (Brunchy OTP Workflow Team Guide; both apps already use a 3-digit code).

CREATE TABLE orders (
  order_id           INT AUTO_INCREMENT PRIMARY KEY,
  user_id            INT NOT NULL,
  canteen_id         INT NOT NULL,
  idempotency_key    VARCHAR(64) NOT NULL,
  subtotal           DECIMAL(10,2) NOT NULL,
  tax                DECIMAL(10,2) NOT NULL,
  convenience_fee    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total              DECIMAL(10,2) NOT NULL,   -- sum of bill totals + convenience fee
  status             ENUM('pending','paid','cancelled','expired') NOT NULL DEFAULT 'pending',
  gateway_order_ref  VARCHAR(100) NULL UNIQUE,
  payment_expires_at DATETIME NOT NULL,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at            DATETIME NULL,
  updated_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users (user_id),
  CONSTRAINT fk_orders_canteen FOREIGN KEY (canteen_id) REFERENCES canteens (canteen_id),
  UNIQUE KEY uq_orders_idempotency (user_id, idempotency_key),
  KEY idx_orders_canteen_paid (canteen_id, paid_at),
  KEY idx_orders_status_expiry (status, payment_expires_at)
);

CREATE TABLE stall_orders (
  stall_order_id     INT AUTO_INCREMENT PRIMARY KEY,
  order_id           INT NOT NULL,
  stall_id           INT NOT NULL,
  canteen_id         INT NOT NULL,
  bill_date          DATE NULL,          -- IST date, set on payment
  bill_no            VARCHAR(20) NULL,   -- e.g. BH-0117, set on payment; restarts every day
  subtotal           DECIMAL(10,2) NOT NULL,
  tax                DECIMAL(10,2) NOT NULL,
  total              DECIMAL(10,2) NOT NULL,
  status             ENUM('awaiting_payment','new','accepted','preparing','ready','collected',
                          'rejected','cancelled','expired','refunded') NOT NULL DEFAULT 'awaiting_payment',
  pickup_code        CHAR(3) NULL,       -- 100-999, set on payment
  code_attempts      TINYINT NOT NULL DEFAULT 0,
  code_locked_until  DATETIME NULL,
  -- The pickup code only needs to be unique among this stall's open bills of the day.
  active_code        CHAR(3) AS (CASE WHEN status IN ('new','accepted','preparing','ready') THEN pickup_code END) STORED,
  estimated_ready_at DATETIME NULL,
  accepted_at        DATETIME NULL,
  preparing_at       DATETIME NULL,
  ready_at           DATETIME NULL,
  collected_at       DATETIME NULL,
  collected_by       INT NULL,
  expired_at         DATETIME NULL,
  cancelled_at       DATETIME NULL,
  cancel_reason      VARCHAR(40) NULL,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_stall_orders_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
  CONSTRAINT fk_stall_orders_stall FOREIGN KEY (stall_id) REFERENCES stalls (stall_id),
  CONSTRAINT fk_stall_orders_canteen FOREIGN KEY (canteen_id) REFERENCES canteens (canteen_id),
  UNIQUE KEY uq_stall_orders_bill_no (stall_id, bill_date, bill_no),
  UNIQUE KEY uq_stall_orders_active_code (stall_id, bill_date, active_code),
  KEY idx_stall_orders_stall_status (stall_id, status),
  KEY idx_stall_orders_order (order_id)
);

-- Invoice snapshot: name, price and GST are copied at checkout and never change.
CREATE TABLE order_items (
  item_id        INT AUTO_INCREMENT PRIMARY KEY,
  stall_order_id INT NOT NULL,
  product_id     INT NOT NULL,
  product_name   VARCHAR(150) NOT NULL,
  price          DECIMAL(10,2) NOT NULL,
  gst_rate       DECIMAL(5,2) NOT NULL,
  qty_requested  INT NOT NULL,
  quantity       INT NOT NULL,    -- what was actually reserved
  item_status    ENUM('active','unavailable_refunded') NOT NULL DEFAULT 'active',
  CONSTRAINT fk_order_items_bill FOREIGN KEY (stall_order_id) REFERENCES stall_orders (stall_order_id),
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products (product_id),
  KEY idx_order_items_bill (stall_order_id)
);

-- Running bill numbers per stall per IST day, incremented atomically.
CREATE TABLE stall_bill_counters (
  stall_id  INT NOT NULL,
  bill_date DATE NOT NULL,
  last_no   INT NOT NULL,
  PRIMARY KEY (stall_id, bill_date)
);
