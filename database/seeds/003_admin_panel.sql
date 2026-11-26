-- Admin panel demo data (a fresh database gets the seed after the migrations, when there were no canteens yet).
UPDATE canteens SET college_id = (SELECT MIN(college_id) FROM colleges) WHERE college_id IS NULL;
UPDATE canteens SET location = 'Ground floor, main block' WHERE canteen_id = 1;
UPDATE canteens SET location = 'Advance block' WHERE canteen_id = 2;

INSERT IGNORE INTO categories (category_name, sort_order)
SELECT category, ROW_NUMBER() OVER (ORDER BY category) * 10 FROM (SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category <> '') c;
