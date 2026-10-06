/*
Chapter 5 - Cleaned views

Blank text is converted to NULL
Country names are standardized
Important text fields are trimmed
Invalid order-item date sequences are flagged
*/

-- Cleaned users
CREATE OR ALTER VIEW cleaned.users AS
SELECT
    id,
    NULLIF(TRIM(first_name), '') AS first_name,
    NULLIF(TRIM(last_name), '') AS last_name,
    NULLIF(TRIM(email), '') AS email,
    age,
    NULLIF(TRIM(gender), '') AS gender,
    NULLIF(TRIM(state), '') AS state,
    NULLIF(TRIM(street_address), '') AS street_address,
    NULLIF(TRIM(postal_code), '') AS postal_code,
    NULLIF(TRIM(city), '') AS city,
    CASE
        WHEN TRIM(country) = 'Deutschland' THEN 'Germany'
        WHEN TRIM(country) = 'España' THEN 'Spain'
        WHEN TRIM(country) = 'Brasil' THEN 'Brazil'
        ELSE NULLIF(TRIM(country), '')
    END AS country,
    latitude,
    longitude,
    NULLIF(TRIM(traffic_source), '') AS traffic_source,
    created_at
FROM src.users;
GO

-- Products
CREATE OR ALTER VIEW cleaned.products AS
SELECT
    id,
    cost,
    NULLIF(TRIM(category), '') AS category,
    NULLIF(TRIM(name), '') AS name,
    NULLIF(TRIM(brand), '') AS brand,
    retail_price,
    NULLIF(TRIM(department), '') AS department,
    NULLIF(TRIM(sku), '') AS sku,
    distribution_center_id
FROM src.products;
GO

-- Orders
CREATE OR ALTER VIEW cleaned.orders AS
SELECT
    order_id,
    user_id,
    NULLIF(TRIM(status), '') AS status,
    NULLIF(TRIM(gender), '') AS gender,
    created_at,
    returned_at,
    shipped_at,
    delivered_at,
    num_of_item
FROM src.orders;
GO

-- Order items
CREATE OR ALTER VIEW cleaned.order_items AS
SELECT
    id,
    order_id,
    user_id,
    product_id,
    inventory_item_id,
    NULLIF(TRIM(status), '') AS status,
    created_at,
    shipped_at,
    delivered_at,
    returned_at,
    sale_price,
    CASE
        WHEN shipped_at < created_at
          OR delivered_at < shipped_at
          OR returned_at < delivered_at
        THEN 1
        ELSE 0
    END AS invalid_date_sequence_flag
FROM src.order_items;
GO

-- Inventory items
CREATE OR ALTER VIEW cleaned.inventory_items AS
SELECT
    id,
    product_id,
    created_at,
    sold_at,
    cost,
    NULLIF(TRIM(product_category), '') AS product_category,
    NULLIF(TRIM(product_name), '') AS product_name,
    NULLIF(TRIM(product_brand), '') AS product_brand,
    product_retail_price,
    NULLIF(TRIM(product_department), '') AS product_department,
    NULLIF(TRIM(product_sku), '') AS product_sku,
    product_distribution_center_id
FROM src.inventory_items;
GO

-- Distribution centers
CREATE OR ALTER VIEW cleaned.distribution_centers AS
SELECT
    id,
    NULLIF(TRIM(name), '') AS name,
    latitude,
    longitude
FROM src.distribution_centers;
GO

-- Events
CREATE OR ALTER VIEW cleaned.events AS
SELECT
    id,
    user_id,
    sequence_number,
    NULLIF(TRIM(session_id), '') AS session_id,
    created_at,
    NULLIF(TRIM(ip_address), '') AS ip_address,
    NULLIF(TRIM(city), '') AS city,
    NULLIF(TRIM(state), '') AS state,
    NULLIF(TRIM(postal_code), '') AS postal_code,
    NULLIF(TRIM(browser), '') AS browser,
    NULLIF(TRIM(traffic_source), '') AS traffic_source,
    NULLIF(TRIM(uri), '') AS uri,
    NULLIF(TRIM(event_type), '') AS event_type
FROM src.events;
GO

SELECT
    TABLE_NAME
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'cleaned'
ORDER BY TABLE_NAME;

SELECT
    country,
    COUNT(*) AS user_count
FROM cleaned.users
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