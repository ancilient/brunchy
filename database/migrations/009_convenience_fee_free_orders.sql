-- Fees are now two percentages of the item total: platform fee (orders.additional_fee) and convenience fee
-- (orders.convenience_fee, which used to be a flat amount). A student's first orders can be free of both.
-- Each bill keeps its share of both fees, so a bill the stall rejects can refund them.
ALTER TABLE stall_orders
  ADD COLUMN convenience_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER platform_fee;

-- TRUE when the order was one of the student's free first orders (no platform or convenience fee).
ALTER TABLE orders
  ADD COLUMN fees_waived BOOLEAN NOT NULL DEFAULT FALSE AFTER additional_fee;
