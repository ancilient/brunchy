-- Vendor settlements (admin panel → Vendor settlements): one payout per stall per finished IST business day,
-- built from that day's picked-up bills, minus commission, GST on commission and refunds, plus adjustments.

CREATE TABLE settlements (
  settlement_id      INT AUTO_INCREMENT PRIMARY KEY,
  stall_id           INT NOT NULL,
  period_date        DATE NOT NULL,          -- IST business day
  due_date           DATE NOT NULL,          -- T+2 working days
  orders             INT NOT NULL,
  gross              DECIMAL(10,2) NOT NULL, -- items + GST of the picked-up bills
  gst                DECIMAL(10,2) NOT NULL,
  commission         DECIMAL(10,2) NOT NULL,
  commission_gst     DECIMAL(10,2) NOT NULL,
  refunds            DECIMAL(10,2) NOT NULL, -- refunds charged to the stall
  adjustments        DECIMAL(10,2) NOT NULL,
  net_payout         DECIMAL(10,2) NOT NULL,
  commission_pct     DECIMAL(5,2) NOT NULL,  -- the rates used, so later settings changes never re-price it
  commission_gst_pct DECIMAL(5,2) NOT NULL,
  status             ENUM('pending','approved','paid') NOT NULL DEFAULT 'pending',
  prepared_by        INT NULL,
  prepared_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  approved_by        INT NULL,
  approved_at        DATETIME NULL,
  paid_at            DATETIME NULL,
  bank_ref           VARCHAR(100) NULL,
  CONSTRAINT fk_settlements_stall FOREIGN KEY (stall_id) REFERENCES stalls (stall_id),
  UNIQUE KEY uq_settlements_stall_day (stall_id, period_date),
  KEY idx_settlements_period (period_date)
);

-- Which bills a settlement paid out (a bill is settled once).
CREATE TABLE settlement_bills (
  stall_order_id INT PRIMARY KEY,
  settlement_id  INT NOT NULL,
  commission     DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_settlement_bills_bill FOREIGN KEY (stall_order_id) REFERENCES stall_orders (stall_order_id),
  CONSTRAINT fk_settlement_bills_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (settlement_id),
  KEY idx_settlement_bills_settlement (settlement_id)
);

-- Manual corrections (+ bonus, − damage). Open until the next prepared settlement of the stall picks them up.
CREATE TABLE settlement_adjustments (
  adjustment_id INT AUTO_INCREMENT PRIMARY KEY,
  stall_id      INT NOT NULL,
  amount        DECIMAL(10,2) NOT NULL,
  note          VARCHAR(255) NOT NULL,
  created_by    INT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  settlement_id INT NULL,
  CONSTRAINT fk_settlement_adj_stall FOREIGN KEY (stall_id) REFERENCES stalls (stall_id),
  CONSTRAINT fk_settlement_adj_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (settlement_id),
  KEY idx_settlement_adj_open (stall_id, settlement_id)
);

-- Refunds: a note for the record, and which settlement charged a refund to the stall (charged once).
ALTER TABLE refunds
  ADD COLUMN note          VARCHAR(255) NULL,
  ADD COLUMN settlement_id INT NULL,
  ADD CONSTRAINT fk_refunds_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (settlement_id);
