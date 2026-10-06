/*
Chapter 4 - Data quality checks

Checks:
1. Blank or missing analytical dimensions
2. Invalid numeric and business values
3. Impossible date sequences
4. Status/date inconsistencies
5. Event sequence integrity
6. Inconsistent country names
7. Session attribute consistency
*/


-- Blank or missing analytical dimensions

SELECT COUNT(*) AS users_with_blank_dimensions
FROM src.users
WHERE NULLIF(TRIM(country), '') IS NULL
   OR NULLIF(TRIM(traffic_source), '') IS NULL;

SELECT COUNT(*) AS products_with_blank_dimensions
FROM src.products
WHERE NULLIF(TRIM(category), '') IS NULL
   OR NULLIF(TRIM(brand), '') IS NULL
   OR NULLIF(TRIM(department), '') IS NULL;

SELECT COUNT(*) AS orders_with_blank_status
FROM src.orders
WHERE NULLIF(TRIM(status), '') IS NULL;

SELECT COUNT(*) AS events_with_blank_dimensions
FROM src.events
WHERE NULLIF(TRIM(session_id), '') IS NULL
   OR NULLIF(TRIM(event_type), '') IS NULL
   OR NULLIF(TRIM(traffic_source), '') IS NULL
   OR NULLIF(TRIM(browser), '') IS NULL;


-- Which dimension is missing

SELECT
    COUNT(*) AS total_products,
    SUM(CASE WHEN NULLIF(TRIM(category), '') IS NULL THEN 1 ELSE 0 END) AS missing_category,
    SUM(CASE WHEN NULLIF(TRIM(brand), '') IS NULL THEN 1 ELSE 0 END) AS missing_brand,
    SUM(CASE WHEN NULLIF(TRIM(department), '') IS NULL THEN 1 ELSE 0 END) AS missing_department,
    SUM(CASE WHEN NULLIF(TRIM(name), '') IS NULL THEN 1 ELSE 0 END) AS missing_name
FROM src.products;


-- Invalid numeric and business values

SELECT COUNT(*) AS invalid_ages
FROM src.users
WHERE age < 0
   OR age > 120;

SELECT COUNT(*) AS products_with_invalid_prices
FROM src.products
WHERE cost < 0
   OR retail_price <= 0
   OR cost > retail_price;

SELECT COUNT(*) AS invalid_sale_prices
FROM src.order_items
WHERE sale_price <= 0;

SELECT COUNT(*) AS invalid_item_counts
FROM src.orders
WHERE num_of_item <= 0;

SELECT COUNT(*) AS inventory_with_invalid_prices
FROM src.inventory_items
WHERE cost < 0
   OR product_retail_price <= 0
   OR cost > product_retail_price;

SELECT COUNT(*) AS invalid_event_sequences
FROM src.events
WHERE sequence_number <= 0;


-- Impossible dates

SELECT COUNT(*) AS orders_with_invalid_date_sequence
FROM src.orders
WHERE shipped_at < created_at
   OR delivered_at < shipped_at
   OR returned_at < delivered_at;

SELECT COUNT(*) AS order_items_with_invalid_date_sequence
FROM src.order_items
WHERE shipped_at < created_at
   OR delivered_at < shipped_at
   OR returned_at < delivered_at;

-- 35872 order_items_with_invalid_date_sequence, separate checks are needed 

SELECT COUNT(*) AS shipped_before_created
FROM src.order_items
WHERE shipped_at < created_at;

SELECT COUNT(*) AS delivered_before_shipped
FROM src.order_items
WHERE delivered_at < shipped_at;

SELECT COUNT(*) AS returned_before_delivered
FROM src.order_items
WHERE returned_at < delivered_at;

SELECT TOP 20
    id,
    order_id,
    created_at,
    shipped_at,
    DATEDIFF(HOUR, created_at, shipped_at) AS hours_to_ship
FROM src.order_items
WHERE shipped_at < created_at
ORDER BY hours_to_ship;
/*
35,872 order-item records have shipping dates earlier than their creation dates. 
Order-level dates are used for fulfilment analysis, while order_items is retained 
for product and financial analysis.
*/


-- Inventory items sold before they were created

SELECT COUNT(*) AS inventory_sold_before_creation
FROM src.inventory_items
WHERE sold_at < created_at;


-- Status and date consistency

SELECT COUNT(*) AS orders_with_status_date_issues
FROM src.orders
WHERE
       (status = 'Shipped'
        AND shipped_at IS NULL)

    OR (status = 'Complete'
        AND (
               shipped_at IS NULL
            OR delivered_at IS NULL
        ))

    OR (status = 'Returned'
        AND (
               shipped_at IS NULL
            OR delivered_at IS NULL
            OR returned_at IS NULL
        ))

    OR (status IN ('Processing', 'Cancelled')
        AND (
               shipped_at IS NOT NULL
            OR delivered_at IS NOT NULL
            OR returned_at IS NOT NULL
        ));

SELECT COUNT(*) AS order_items_with_status_date_issues
FROM src.order_items
WHERE
       (status = 'Shipped'
        AND shipped_at IS NULL)

    OR (status = 'Complete'
        AND (
               shipped_at IS NULL
            OR delivered_at IS NULL
        ))

    OR (status = 'Returned'
        AND (
               shipped_at IS NULL
            OR delivered_at IS NULL
            OR returned_at IS NULL
        ))

    OR (status IN ('Processing', 'Cancelled')
        AND (
               shipped_at IS NOT NULL
            OR delivered_at IS NOT NULL
            OR returned_at IS NOT NULL
        ));


-- Event sequence integrity

SELECT COUNT(*) AS duplicate_session_sequences
FROM
(
    SELECT
        session_id,
        sequence_number
    FROM src.events
    GROUP BY
        session_id,
        sequence_number
    HAVING COUNT(*) > 1
) AS duplicates;

SELECT COUNT(*) AS sessions_with_sequence_gaps
FROM
(
    SELECT session_id
    FROM src.events
    WHERE session_id IS NOT NULL
      AND sequence_number IS NOT NULL
    GROUP BY session_id
    HAVING MIN(sequence_number) <> 1
        OR MAX(sequence_number) <> COUNT(*)
) AS invalid_sessions;

-- Inconsistent country names

SELECT
    country,
    COUNT(*) AS user_count
FROM src.users
WHERE country IN
(
    'Germany',
    'Deutschland',
    'Spain',
    'España',
    'Brazil',
    'Brasil'
)
GROUP BY country
ORDER BY country;

-- Sessions with inconsistent traffic source or browser

SELECT COUNT(*) AS sessions_with_multiple_attributes
FROM
(
    SELECT session_id
    FROM src.events
    WHERE session_id IS NOT NULL
    GROUP BY session_id
    HAVING COUNT(DISTINCT traffic_source) > 1
        OR COUNT(DISTINCT browser) > 1
) AS inconsistent_sessions;