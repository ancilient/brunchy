-- Stores the computed platform fee (₹) for an order: PLATFORM_FEE_PERCENT of (items + stall GST).
-- The percent is GST-inclusive; this column holds the rupee amount charged at checkout.
ALTER TABLE orders
  ADD COLUMN additional_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER convenience_fee;
