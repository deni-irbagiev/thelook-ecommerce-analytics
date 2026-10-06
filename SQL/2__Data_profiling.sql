/*
Chapter 2 - Data profiling

Checked for:
1. PK duplicates
2. Some missing values
3. Date coverage 
4. Categorial distributions
5. Basic numeric ranges
*/


-- 1) PK duplicates check 

SELECT 
	'Users' AS table_name,
	COUNT(*) AS duplicate_keys
FROM (
	SELECT id
	FROM src.users 
	GROUP BY id
	HAVING COUNT(*) > 1
) AS t 

UNION ALL

SELECT 
	'Products',
	COUNT(*)
FROM (
	SELECT id
	FROM src.products
	GROUP BY id
	HAVING COUNT(*) > 1
) AS t 

UNION ALL

SELECT 
	'Orders',
	COUNT(*) 
FROM (
	SELECT order_id
	FROM src.orders 
	GROUP BY order_id
	HAVING COUNT(*) > 1
) AS t 

UNION ALL

SELECT 
	'Order_items',
	COUNT(*) 
FROM (
	SELECT id
	FROM src.order_items 
	GROUP BY id
	HAVING COUNT(*) > 1
) AS t 

UNION ALL

SELECT 
	'Inventory_items',
	COUNT(*)
FROM (
	SELECT id
	FROM src.inventory_items
	GROUP BY id
	HAVING COUNT(*) > 1
) AS t 

UNION ALL

SELECT 
	'Distribution_centers',
	COUNT(*)
FROM (
	SELECT id
	FROM src.distribution_centers
	GROUP BY id
	HAVING COUNT(*) > 1
) AS t 

UNION ALL

SELECT 
	'Events',
	COUNT(*)
FROM (
	SELECT id
	FROM src.events
	GROUP BY id
	HAVING COUNT(*) > 1
) AS t;
-- no duplicates


-- 2) Missing values 
-- In table Users

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN id IS NULL THEN 1 ELSE 0 END) AS missing_id,
    SUM(CASE WHEN created_at IS NULL THEN 1 ELSE 0 END) AS missing_created_at,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS missing_country,
    SUM(CASE WHEN traffic_source IS NULL THEN 1 ELSE 0 END)
        AS missing_traffic_source
FROM src.users;

-- In table Products

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN id IS NULL THEN 1 ELSE 0 END) AS missing_id,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS missing_category,
    SUM(CASE WHEN cost IS NULL THEN 1 ELSE 0 END) AS missing_cost,
    SUM(CASE WHEN retail_price IS NULL THEN 1 ELSE 0 END)
        AS missing_retail_price,
    SUM(CASE WHEN distribution_center_id IS NULL THEN 1 ELSE 0 END)
        AS missing_distribution_center_id
FROM src.products;
-- brand and department are not checked here; chapter 4 finds 24 products with a null brand.


-- In table Orders

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(order_id) AS missing_order_id,
    COUNT(*) - COUNT(user_id) AS missing_user_id,
    COUNT(*) - COUNT(status) AS missing_status,
    COUNT(*) - COUNT(created_at) AS missing_created_at,
    COUNT(*) - COUNT(num_of_item) AS missing_item_count
FROM src.orders;


-- In table Order items

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id) AS missing_id,
    COUNT(*) - COUNT(order_id) AS missing_order_id,
    COUNT(*) - COUNT(user_id) AS missing_user_id,
    COUNT(*) - COUNT(product_id) AS missing_product_id,
    COUNT(*) - COUNT(inventory_item_id) AS missing_inventory_item_id,
    COUNT(*) - COUNT(status) AS missing_status,
    COUNT(*) - COUNT(created_at) AS missing_created_at,
    COUNT(*) - COUNT(sale_price) AS missing_sale_price
FROM src.order_items;


-- In table inventory

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id) AS missing_id,
    COUNT(*) - COUNT(product_id) AS missing_product_id,
    COUNT(*) - COUNT(created_at) AS missing_created_at,
    COUNT(*) - COUNT(cost) AS missing_cost,
    COUNT(*) - COUNT(product_category) AS missing_category,
    COUNT(*) - COUNT(product_retail_price) AS missing_retail_price,
    COUNT(*) - COUNT(product_distribution_center_id)
        AS missing_distribution_center_id
FROM src.inventory_items;


-- In table Events 

SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(id) AS missing_id,
    COUNT(*) - COUNT(session_id) AS missing_session_id,
    COUNT(*) - COUNT(sequence_number) AS missing_sequence_number,
    COUNT(*) - COUNT(created_at) AS missing_created_at,
    COUNT(*) - COUNT(event_type) AS missing_event_type,
    COUNT(*) - COUNT(traffic_source) AS missing_traffic_source
FROM src.events;
-- None of the checked columns have missing values


-- 3) Date coverage: earliest and latest dates in each table
-- Data coverage - Jan 2019 to Jan 2024. Inventory begins a bit earlier in Nov 2018

SELECT
    'users' AS table_name,
    MIN(created_at) AS earliest_date,
    MAX(created_at) AS latest_date
FROM src.users

UNION ALL

SELECT
    'orders',
    MIN(created_at),
    MAX(created_at)
FROM src.orders

UNION ALL

SELECT
    'inventory_items',
    MIN(created_at),
    MAX(created_at)
FROM src.inventory_items

UNION ALL

SELECT
    'events',
    MIN(created_at),
    MAX(created_at)
FROM src.events;

-- 4) Important categorial distributions 
SELECT
    status,
    COUNT(*) AS order_count
FROM src.orders
GROUP BY status
ORDER BY order_count DESC;

SELECT
    event_type,
    COUNT(*) AS event_count
FROM src.events
GROUP BY event_type
ORDER BY event_count DESC;

SELECT
    country,
    COUNT(*) AS customer_count
FROM src.users
GROUP BY country
ORDER BY customer_count DESC;

SELECT
    traffic_source,
    COUNT(*) AS customer_count
FROM src.users
GROUP BY traffic_source
ORDER BY customer_count DESC;

SELECT
    category,
    COUNT(*) AS product_count
FROM src.products
GROUP BY category
ORDER BY product_count DESC;

-- 5) Some numeric ranges 

SELECT
    MIN(age) AS minimum_age,
    MAX(age) AS maximum_age,
    CAST(AVG(age * 1.0) AS decimal(12,2)) AS average_age
FROM src.users;

SELECT
    MIN(cost) AS minimum_cost,
    MAX(cost) AS maximum_cost,
    ROUND(AVG(cost), 2) AS average_cost,

    MIN(retail_price) AS minimum_retail_price,
    MAX(retail_price) AS maximum_retail_price,
    ROUND(AVG(retail_price), 2) AS average_retail_price
FROM src.products;

SELECT
    MIN(sale_price) AS minimum_sale_price,
    MAX(sale_price) AS maximum_sale_price,
    CAST(AVG(sale_price) AS decimal(12,2)) AS average_sale_price
FROM src.order_items;


SELECT
    MIN(num_of_item) AS minimum_items,
    MAX(num_of_item) AS maximum_items,
    CAST(AVG(num_of_item * 1.0) AS decimal(12,2)) AS average_items
FROM src.orders;
