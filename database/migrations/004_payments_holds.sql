-- Payment attempts, 5-minute stock holds and refunds (blueprint 4.1, 4.3, 10.3).

CREATE TABLE payments (
  payment_id          INT AUTO_INCREMENT PRIMARY KEY,
  order_id            INT NOT NULL,
  gateway_payment_ref VARCHAR(100) NOT NULL UNIQUE,   -- a replayed webhook hits this and changes nothing
  upi_app             VARCHAR(30) NULL,
  amount              DECIMAL(10,2) NOT NULL,
  payment_status      ENUM('created','success','failed') NOT NULL,
  failure_reason      VARCHAR(60) NULL,
  webhook_received_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
  KEY idx_payments_order (order_id)
);

CREATE TABLE stock_holds (
  hold_id    INT AUTO_INCREMENT PRIMARY KEY,
  order_id   INT NOT NULL,
  item_id    INT NOT NULL,
  product_id INT NOT NULL,
  qty        INT NOT NULL,
  expires_at DATETIME NOT NULL,
  status     ENUM('held','confirmed','released') NOT NULL DEFAULT 'held',
  CONSTRAINT fk_stock_holds_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
  CONSTRAINT fk_stock_holds_item FOREIGN KEY (item_id) REFERENCES order_items (item_id),
  CONSTRAINT fk_stock_holds_product FOREIGN KEY (product_id) REFERENCES products (product_id),
  KEY idx_stock_holds_status_expiry (status, expires_at),
  KEY idx_stock_holds_order (order_id)
);

-- Refunds are recorded here in milestone 1; sending them to the gateway comes with the Razorpay milestone.
-- Reason codes: OUT_OF_STOCK, ITEM_UNAVAILABLE, KITCHEN_ISSUE, STALL_EMERGENCY, STALL_REJECTED,
-- CANCELLED_BY_USER, PAYMENT_TIMEOUT, LATE_PAYMENT, DUPLICATE_PAYMENT.
CREATE TABLE refunds (
  refund_id          INT AUTO_INCREMENT PRIMARY KEY,
  order_id           INT NOT NULL,
  stall_order_id     INT NULL,    -- NULL = refund for the whole order (e.g. late or duplicate payment)
  item_id            INT NULL,    -- item-level refund
  payment_id         INT NULL,
  amount             DECIMAL(10,2) NOT NULL,
  destination        ENUM('original','wallet') NOT NULL DEFAULT 'original',
  reason_code        VARCHAR(30) NOT NULL,
  requested_by       INT NULL,
  approved_by        INT NULL,
  gateway_refund_ref VARCHAR(100) NULL,
  status             ENUM('requested','approved','processing','completed','failed','rejected') NOT NULL DEFAULT 'requested',
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at       DATETIME NULL,
  CONSTRAINT fk_refunds_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
  CONSTRAINT fk_refunds_bill FOREIGN KEY (stall_order_id) REFERENCES stall_orders (stall_order_id),
  CONSTRAINT fk_refunds_payment FOREIGN KEY (payment_id) REFERENCES payments (payment_id),
  KEY idx_refunds_bill (stall_order_id),
  KEY idx_refunds_order (order_id)
);
