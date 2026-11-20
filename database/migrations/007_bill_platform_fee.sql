-- Each bill's share of the order's platform fee (orders.additional_fee), split by item subtotal.
-- The bill total stays the stall's item total (what the vendor earns); the student paid total + platform_fee.
-- Used to show the student what they paid per bill, and to refund the share when the stall rejects the bill.
ALTER TABLE stall_orders
  ADD COLUMN platform_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER tax;

-- Existing orders: proportional share (old orders with several bills may be off by a paisa in total).
UPDATE stall_orders so
  JOIN orders o ON o.order_id = so.order_id
   SET so.platform_fee = ROUND(o.additional_fee * so.subtotal / o.subtotal, 2)
 WHERE o.subtotal > 0 AND o.additional_fee > 0;
