/*
Chapter 6 - Data modelling

Created analytical dimension and fact tables from the cleaned views.
Kept columns needed for business analysis, added calculated flags, assigned primary keys. 
The source and cleaned layers were not modified.
*/


-- Drop existing analytical tables so the chapter can be re-run

DROP TABLE IF EXISTS analytics.fact_events;
DROP TABLE IF EXISTS analytics.fact_inventory;
DROP TABLE IF EXISTS analytics.fact_order_items;
DROP TABLE IF EXISTS analytics.fact_orders;
DROP TABLE IF EXISTS analytics.dim_distribution_center;
DROP TABLE IF EXISTS analytics.dim_product;
DROP TABLE IF EXISTS analytics.dim_customer;
GO


-- Customer dimension

SELECT
    id AS customer_id,
    age,
    gender,
    city,
    state,
    country,
    traffic_source AS acquisition_source,
    created_at AS customer_created_at,
    CAST(created_at AS date) AS customer_created_date
INTO analytics.dim_customer
FROM cleaned.users;

ALTER TABLE analytics.dim_customer
ADD CONSTRAINT PK_dim_customer
PRIMARY KEY (customer_id);
GO


-- Product dimension

SELECT
    id AS product_id,
    name AS product_name,
    category,
    brand,
    department,
    sku,
    CAST(retail_price AS decimal(12,2)) AS retail_price
INTO analytics.dim_product
FROM cleaned.products;
 
ALTER TABLE analytics.dim_product
ADD CONSTRAINT PK_dim_product
PRIMARY KEY (product_id);
GO


-- Distribution centers dimension

SELECT
    id AS distribution_center_id,
    name AS distribution_center_name,
    latitude,
    longitude
INTO analytics.dim_distribution_center
FROM cleaned.distribution_centers;
 
ALTER TABLE analytics.dim_distribution_center
ADD CONSTRAINT PK_dim_distribution_center
PRIMARY KEY (distribution_center_id);
GO


-- Orders fact

SELECT
    order_id,
    user_id AS customer_id,
    status AS order_status,
    created_at AS order_created_at,
    CAST(created_at AS date) AS order_date,
    shipped_at AS order_shipped_at,
    CAST(shipped_at AS date) AS shipped_date,
    delivered_at AS order_delivered_at,
    CAST(delivered_at AS date) AS delivered_date,
    returned_at AS order_returned_at,
    CAST(returned_at AS date) AS returned_date,
    num_of_item AS item_count,
    CASE
        WHEN shipped_at IS NOT NULL THEN 1
        ELSE 0
    END AS shipped_flag,
    CASE
        WHEN delivered_at IS NOT NULL THEN 1
        ELSE 0
    END AS delivered_flag,
    CASE
        WHEN status = 'Returned' THEN 1
        ELSE 0
    END AS returned_flag,
    CASE
        WHEN status = 'Cancelled' THEN 1
        ELSE 0
    END AS cancelled_flag,
    DATEDIFF(DAY, created_at, shipped_at) AS days_to_ship,
    DATEDIFF(DAY, created_at, delivered_at) AS days_to_deliver
INTO analytics.fact_orders
FROM cleaned.orders;

ALTER TABLE analytics.fact_orders
ADD CONSTRAINT PK_fact_orders
PRIMARY KEY (order_id);
GO


-- Order item fact

SELECT
    oi.id AS order_item_id,
    oi.order_id,
    oi.user_id AS customer_id,
    oi.product_id,
    oi.inventory_item_id,
    ii.product_distribution_center_id AS distribution_center_id,
    oi.status AS item_status,
    oi.created_at AS item_created_at,
    oi.shipped_at AS item_shipped_at,
    oi.delivered_at AS item_delivered_at,
    oi.returned_at AS item_returned_at,
    oi.invalid_date_sequence_flag, -- Flag showing whether the item-level date sequence is unreliable
    o.created_at AS order_created_at,
    CAST(o.created_at AS date) AS order_date,
    o.shipped_at AS order_shipped_at,
    CAST(o.shipped_at AS date) AS shipped_date,
    o.delivered_at AS order_delivered_at,
    CAST(o.delivered_at AS date) AS delivered_date,
    o.returned_at AS order_returned_at,
    CAST(o.returned_at AS date) AS returned_date,
    CAST(oi.sale_price AS decimal(12,2)) AS item_revenue,
    CAST(ii.cost AS decimal(12,2)) AS item_cost,
    CAST(oi.sale_price AS decimal(12,2))
        - CAST(ii.cost AS decimal(12,2)) AS gross_profit_before_returns,
    CASE
        WHEN oi.status = 'Returned' THEN 1
        ELSE 0
    END AS returned_flag,
    CASE
        WHEN oi.status = 'Cancelled' THEN 1
        ELSE 0
    END AS cancelled_flag,
    DATEDIFF(DAY, o.created_at, o.shipped_at) AS days_to_ship,
    DATEDIFF(DAY, o.created_at, o.delivered_at) AS days_to_deliver
INTO analytics.fact_order_items
FROM cleaned.order_items AS oi
JOIN cleaned.orders AS o
    ON oi.order_id = o.order_id
JOIN cleaned.inventory_items AS ii
    ON oi.inventory_item_id = ii.id;
 
ALTER TABLE analytics.fact_order_items
ADD CONSTRAINT PK_fact_order_items
PRIMARY KEY (order_item_id);
GO


-- Inventory fact

SELECT
    id AS inventory_item_id,
    product_id,
    product_distribution_center_id AS distribution_center_id,
    created_at AS inventory_created_at,
    CAST(created_at AS date) AS inventory_created_date,
    sold_at AS inventory_sold_at,
    CAST(sold_at AS date) AS inventory_sold_date,
    CAST(cost AS decimal(12,2)) AS inventory_cost,
    CAST(product_retail_price AS decimal(12,2)) AS product_retail_price,
    CASE
        WHEN sold_at IS NOT NULL THEN 1
        ELSE 0
    END AS ever_sold_flag, -- Sold at any point. Chapter 8 applies its own cutoff instead
    DATEDIFF(DAY, created_at, sold_at) AS days_to_sell
INTO analytics.fact_inventory
FROM cleaned.inventory_items;
 
ALTER TABLE analytics.fact_inventory
ADD CONSTRAINT PK_fact_inventory
PRIMARY KEY (inventory_item_id);
GO


-- Events fact
 
SELECT
    id AS event_id,
    user_id AS customer_id,
    session_id,
    sequence_number,
    created_at AS event_created_at,
    CAST(created_at AS date) AS event_date,
    event_type,
    traffic_source,
    browser,
    uri
INTO analytics.fact_events
FROM cleaned.events;
 
ALTER TABLE analytics.fact_events
ADD CONSTRAINT PK_fact_events
PRIMARY KEY (event_id);
GO


-- Check created tables

SELECT
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'analytics'
ORDER BY TABLE_NAME;


-- Check row counts of each table

SELECT
    'dim_customer' AS table_name,
    COUNT(*) AS row_count
FROM analytics.dim_customer

UNION ALL

SELECT
    'dim_product',
    COUNT(*)
FROM analytics.dim_product

UNION ALL

SELECT
    'dim_distribution_center',
    COUNT(*)
FROM analytics.dim_distribution_center

UNION ALL

SELECT
    'fact_orders',
    COUNT(*)
FROM analytics.fact_orders

UNION ALL

SELECT
    'fact_order_items',
    COUNT(*)
FROM analytics.fact_order_items

UNION ALL

SELECT
    'fact_inventory',
    COUNT(*)
FROM analytics.fact_inventory

UNION ALL

SELECT
    'fact_events',
    COUNT(*)
FROM analytics.fact_events;


-- Revenue impact of the flagged order items

SELECT
    invalid_date_sequence_flag,
    COUNT(*) AS total_items,
    SUM(item_revenue) AS item_revenue,
    CAST(SUM(item_revenue) * 100.0 / SUM(SUM(item_revenue)) OVER () AS decimal(12,2)) AS revenue_share_percent
FROM analytics.fact_order_items
WHERE order_date < '2024-01-01'
GROUP BY invalid_date_sequence_flag;