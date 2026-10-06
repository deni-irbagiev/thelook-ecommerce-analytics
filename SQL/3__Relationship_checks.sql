/*
Chapter 3 - Relationship checks

Verify that linked records exist
confirm order and order-item consistency
detect broken relationships
*/

-- Orphaned records across every foreign-key relationship

SELECT
    'Orders without users' AS potential_issue,
    COUNT(*) AS affected_rows
FROM src.orders AS o
LEFT JOIN src.users AS u
    ON o.user_id = u.id
WHERE u.id IS NULL

UNION ALL

SELECT
    'Order items without orders',
    COUNT(*)
FROM src.order_items AS oi
LEFT JOIN src.orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'Order items without users',
    COUNT(*)
FROM src.order_items AS oi
LEFT JOIN src.users AS u
    ON oi.user_id = u.id
WHERE u.id IS NULL

UNION ALL

SELECT
    'Order items without products',
    COUNT(*)
FROM src.order_items AS oi
LEFT JOIN src.products AS p
    ON oi.product_id = p.id
WHERE p.id IS NULL

UNION ALL

SELECT
    'Order items without inventory items',
    COUNT(*)
FROM src.order_items AS oi
LEFT JOIN src.inventory_items AS i
    ON oi.inventory_item_id = i.id
WHERE i.id IS NULL

UNION ALL

SELECT
    'Products without distribution centers',
    COUNT(*)
FROM src.products AS p
LEFT JOIN src.distribution_centers AS dc
    ON p.distribution_center_id = dc.id
WHERE dc.id IS NULL

UNION ALL

SELECT
    'Inventory items without products',
    COUNT(*)
FROM src.inventory_items AS i
LEFT JOIN src.products AS  p
    ON i.product_id = p.id
WHERE p.id IS NULL;


-- Order items whose customer does not match the parent order

SELECT
    COUNT(*) AS mismatched_customer_rows
FROM src.order_items AS oi
JOIN src.orders AS o
    ON oi.order_id = o.order_id
WHERE oi.user_id <> o.user_id;


-- Order items whose status does not match the parent order

SELECT
    COUNT(*) AS mismatched_status_rows
FROM src.order_items AS oi
JOIN src.orders AS o
    ON oi.order_id = o.order_id
WHERE oi.status <> o.status;


-- Orders where num_of_item does not match the actual line count

WITH actual_item_counts AS
(
    SELECT
        order_id,
        COUNT(*) AS actual_items
    FROM src.order_items
    GROUP BY order_id
)
SELECT
    COUNT(*) AS orders_with_wrong_item_count
FROM src.orders AS o
JOIN actual_item_counts AS a
    ON o.order_id = a.order_id
WHERE o.num_of_item <> a.actual_items;


-- Order items whose product does not match the inventory item they reference

SELECT
    COUNT(*) AS mismatched_inventory_products
FROM src.order_items AS oi
JOIN src.inventory_items AS i
    ON oi.inventory_item_id = i.id
WHERE oi.product_id <> i.product_id;


-- Inventory items assigned to a different distribution center than their product

SELECT
    COUNT(*) AS mismatched_distribution_centers
FROM src.inventory_items AS i
JOIN src.products AS p
    ON i.product_id = p.id
WHERE i.product_distribution_center_id
      <> p.distribution_center_id;