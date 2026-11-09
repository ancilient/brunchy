-- Demo data for local development and tests. Generated from frontend/web_prototype/src/data/mockData.ts
-- so the API serves the same canteens, stalls and menu the apps show today. Times are UTC; canteen hours are IST.

INSERT INTO canteens (canteen_id, canteen_name, opening_time, closing_time, status, requires_approval, last_order_minutes, latitude, longitude) VALUES
  (1, 'Main Canteen', '07:30:00', '18:00:00', 'open', TRUE, 10, 12.9716, 77.5946),
  (2, 'Advance Block Canteen', '08:00:00', '17:30:00', 'open', TRUE, 10, 12.9732, 77.596);

INSERT INTO stalls (stall_id, canteen_id, stall_name, bill_prefix, gst_rate, status, category, accent_color, icon_name, avg_prep_minutes) VALUES
  (1, 1, 'Burger Hub', 'BH', 5.00, 'open', 'Burgers & Fries', '#FF6332', 'Sandwich', 5),
  (2, 1, 'Juice Corner', 'JC', 0.00, 'open', 'Fresh Juices & Shakes', '#059669', 'CupSoda', 3),
  (3, 1, 'Parotta Point', 'PP', 5.00, 'open', 'Hot Breads & Curries', '#D97706', 'UtensilsCrossed', 6),
  (4, 1, 'Chai & Snacks', 'CS', 0.00, 'open', 'Tea, Coffee & Puffs', '#9333EA', 'Coffee', 2),
  (5, 2, 'Grill Point', 'GP', 5.00, 'open', 'Grilled Sandwiches', '#DC2626', 'Flame', 7),
  (6, 2, 'South Kitchen', 'SK', 5.00, 'open', 'Dosas & Meals', '#0D9488', 'Soup', 6);

INSERT INTO products (product_id, stall_id, product_name, category, description, price, stock_quantity, daily_default_qty, prep_minutes, image_url, is_veg, approval_status, is_active) VALUES
  (101, 1, 'Cheese Burger', 'Burger', 'Crispy patty, melted cheddar cheese slice, fresh lettuce & signature burger sauce.', 80.00, 3, 40, 5, NULL, FALSE, 'published', TRUE),
  (102, 1, 'Veg Burger', 'Burger', 'Golden spiced potato & peas patty with crisp veggies and creamy dressing.', 60.00, 25, 50, 4, NULL, TRUE, 'published', TRUE),
  (103, 1, 'Chicken Burger', 'Burger', 'Juicy crumb-fried chicken fillet with crunchy slaw and spicy dressing.', 90.00, 0, 35, 5, NULL, FALSE, 'published', TRUE),
  (104, 1, 'French Fries', 'Sides', 'Golden crispy salted french fries served with ketchup dip.', 40.00, 40, 60, 3, NULL, TRUE, 'published', TRUE),
  (201, 2, 'Mango Juice', 'Juice', 'Chilled freshly extracted Alphonso mango pulp with mint splash.', 50.00, 30, 50, 2, NULL, TRUE, 'published', TRUE),
  (202, 2, 'Cold Coffee', 'Beverage', 'Creamy cold brewed coffee blended with chilled milk and chocolate drizzle.', 45.00, 20, 35, 2, NULL, TRUE, 'published', TRUE),
  (203, 2, 'Watermelon Juice', 'Juice', 'Hydrating fresh crushed watermelon with lemon drop and rock salt.', 40.00, 18, 40, 2, NULL, TRUE, 'published', TRUE),
  (301, 3, 'Malabar Parotta (2 pcs)', 'Parotta', 'Two hot flaky layered Malabar parottas with rich veg kurma gravy.', 30.00, 50, 80, 4, NULL, TRUE, 'published', TRUE),
  (302, 3, 'Egg Parotta', 'Parotta', 'Crispy shredded parotta tossed with eggs, onions, green chillies & curry leaves.', 35.00, 15, 40, 5, NULL, FALSE, 'published', TRUE),
  (401, 4, 'Masala Chai', 'Beverage', 'Hot brewed ginger & cardamom spiced tea in traditional glass.', 15.00, 75, 120, 1, NULL, TRUE, 'published', TRUE),
  (402, 4, 'Veg Samosa (2 pcs)', 'Snacks', 'Crisp pastry triangles stuffed with spiced potatoes and peas.', 20.00, 30, 50, 1, NULL, TRUE, 'published', TRUE),
  (601, 6, 'Crispy Masala Dosa', 'Dosa', 'Golden fermented rice-lentil crepe stuffed with potato masala, sambar & chutneys.', 55.00, 35, 60, 5, NULL, TRUE, 'published', TRUE),
  (602, 6, 'South Veg Thali', 'Meals', 'Steaming basmati rice, sambar, rasam, curd, poriyal, appalam, and pickle.', 85.00, 20, 40, 4, NULL, TRUE, 'published', TRUE),
  (501, 5, 'Cheese Corn Grill Sandwich', 'Sandwich', 'Toasted jumbo bread loaded with sweet corn, mozzarella and Italian herbs.', 85.00, 14, 30, 6, NULL, TRUE, 'published', TRUE);

-- Demo accounts. Log in with POST /api/v1/auth/otp + /auth/verify using these phone numbers.
-- One vendor phone per stall (build guide: phone + OTP for vendors linked to one stall).
INSERT INTO users (user_id, name, phone, register_no, role, stall_id, canteen_id) VALUES
  (1, 'Demo Student', '9876543210', '41110001', 'student', NULL, 1),
  (2, 'Burger Hub Staff', '9000000001', NULL, 'vendor', 1, 1),
  (3, 'Juice Corner Staff', '9000000002', NULL, 'vendor', 2, 1),
  (4, 'Parotta Point Staff', '9000000003', NULL, 'vendor', 3, 1),
  (5, 'Chai & Snacks Staff', '9000000004', NULL, 'vendor', 4, 1),
  (6, 'Grill Point Staff', '9000000005', NULL, 'vendor', 5, 2),
  (7, 'South Kitchen Staff', '9000000006', NULL, 'vendor', 6, 2),
  (8, 'Main Canteen Manager', '9000000011', NULL, 'manager', NULL, 1),
  (9, 'Ancilient Admin', '9000000099', NULL, 'admin', NULL, NULL);

-- Put every published product on the menu for the next 30 IST days, so local development works without the manager screens.
INSERT INTO daily_menu (menu_date, product_id, added_by)
WITH RECURSIVE days (n) AS (SELECT 0 UNION ALL SELECT n + 1 FROM days WHERE n < 29)
SELECT DATE(CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '+05:30')) + INTERVAL days.n DAY, p.product_id, 8
FROM days CROSS JOIN products p
WHERE p.approval_status = 'published' AND p.is_active = TRUE;
