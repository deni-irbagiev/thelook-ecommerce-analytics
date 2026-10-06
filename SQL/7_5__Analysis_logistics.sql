/*
Chapter 7.5 - Logistics and inventory analysis

Analyzes shipping speed, delivery speed, cancellations, returns,
distribution-center performance, sell-through and slow-moving inventory.
*/


-- Overall logistics performance 

SELECT
    COUNT(*) AS total_orders,
    SUM(shipped_flag) AS shipped_orders,
    SUM(delivered_flag) AS delivered_orders,
    SUM(returned_flag) AS returned_orders,
    SUM(cancelled_flag) AS cancelled_orders,
    AVG(CAST(days_to_ship AS decimal(12,2))) AS average_days_to_ship,
    AVG(CAST(days_to_deliver AS decimal(12,2))) AS average_days_to_deliver,
    CAST(SUM(delivered_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS delivery_rate_percent,
    CAST(SUM(returned_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS return_rate_percent,
    CAST(SUM(cancelled_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS cancellation_rate_percent
FROM analytics.fact_orders
WHERE order_date < '2024-01-01';

-- Logistics performance by year 

SELECT
    YEAR(order_date) AS order_year,
    COUNT(*) AS total_orders,
    AVG(CAST(days_to_ship AS decimal(12,2))) AS average_days_to_ship,
    AVG(CAST(days_to_deliver AS decimal(12,2))) AS average_days_to_deliver,
    CAST(SUM(delivered_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS delivery_rate_percent,
    CAST(SUM(returned_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS return_rate_percent,
    CAST(SUM(cancelled_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS cancellation_rate_percent
FROM analytics.fact_orders
WHERE order_date < '2024-01-01'
GROUP BY YEAR(order_date)
ORDER BY order_year;

-- Logistics performance by distribution center

WITH distribution_center_orders AS
(
    SELECT
        distribution_center_id,
        order_id,
        MAX(days_to_ship) AS days_to_ship,
        MAX(days_to_deliver) AS days_to_deliver,
        MAX(returned_flag) AS returned_order_flag,
        MAX(cancelled_flag) AS cancelled_order_flag
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
    GROUP BY distribution_center_id, order_id
)
SELECT
    d.distribution_center_name,
    COUNT(*) AS orders_handled,
    AVG(CAST(o.days_to_ship AS decimal(12,2))) AS average_days_to_ship,
    AVG(CAST(o.days_to_deliver AS decimal(12,2))) AS average_days_to_deliver,
    CAST(SUM(o.returned_order_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS return_rate_percent,
    CAST(SUM(o.cancelled_order_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS cancellation_rate_percent
FROM distribution_center_orders AS o
JOIN analytics.dim_distribution_center AS d ON o.distribution_center_id = d.distribution_center_id
GROUP BY d.distribution_center_name
ORDER BY orders_handled DESC;

-- Overall inventory performance

WITH inventory_overall AS
(
    SELECT
        inventory_cost,
        product_retail_price,
        CASE WHEN inventory_sold_date < '2024-01-01' THEN 1 ELSE 0 END AS sold_before_cutoff
    FROM analytics.fact_inventory
    WHERE inventory_created_date < '2024-01-01'
)
SELECT
    COUNT(*) AS total_inventory_items,
    SUM(sold_before_cutoff) AS sold_items,
    COUNT(*) - SUM(sold_before_cutoff) AS unsold_items,
    CAST(SUM(sold_before_cutoff) * 100.0 / COUNT(*) AS decimal(12,2)) AS sell_through_rate_percent,
    SUM(CASE WHEN sold_before_cutoff = 0 THEN inventory_cost ELSE 0 END) AS unsold_inventory_cost,
    SUM(CASE WHEN sold_before_cutoff = 0 THEN product_retail_price ELSE 0 END) AS unsold_retail_value
FROM inventory_overall;

-- Inventory performance by distribution center

WITH inventory_by_center AS
(
    SELECT
        distribution_center_id,
        inventory_cost,
        product_retail_price,
        CASE WHEN inventory_sold_date < '2024-01-01' THEN 1 ELSE 0 END AS sold_before_cutoff
    FROM analytics.fact_inventory
    WHERE inventory_created_date < '2024-01-01'
)
SELECT
    d.distribution_center_name,
    COUNT(*) AS total_inventory_items,
    SUM(i.sold_before_cutoff) AS sold_items,
    COUNT(*) - SUM(i.sold_before_cutoff) AS unsold_items,
    CAST(SUM(i.sold_before_cutoff) * 100.0 / COUNT(*) AS decimal(12,2)) AS sell_through_rate_percent,
    SUM(CASE WHEN i.sold_before_cutoff = 0 THEN i.inventory_cost ELSE 0 END) AS unsold_inventory_cost,
    SUM(CASE WHEN i.sold_before_cutoff = 0 THEN i.product_retail_price ELSE 0 END) AS unsold_retail_value
FROM inventory_by_center AS i
JOIN analytics.dim_distribution_center AS d ON i.distribution_center_id = d.distribution_center_id
GROUP BY d.distribution_center_name
ORDER BY unsold_inventory_cost DESC;

-- Unsold inventory 

WITH unsold_aging AS
(
    SELECT
        inventory_cost,
        DATEDIFF(DAY, inventory_created_date, '2024-01-01') AS inventory_age_days
    FROM analytics.fact_inventory
    WHERE inventory_created_date < '2024-01-01'
      AND (inventory_sold_date IS NULL OR inventory_sold_date >= '2024-01-01')
),
inventory_aging AS
(
    SELECT
        inventory_cost,
        CASE
            WHEN inventory_age_days < 30 THEN 'Under 30 days'
            WHEN inventory_age_days < 90 THEN '30-89 days'
            WHEN inventory_age_days < 180 THEN '90-179 days'
            ELSE '180+ days'
        END AS age_group,
        CASE
            WHEN inventory_age_days < 30 THEN 1
            WHEN inventory_age_days < 90 THEN 2
            WHEN inventory_age_days < 180 THEN 3
            ELSE 4
        END AS age_order
    FROM unsold_aging
)
SELECT
    age_group,
    COUNT(*) AS unsold_items,
    SUM(inventory_cost) AS unsold_inventory_cost
FROM inventory_aging
GROUP BY age_group, age_order
ORDER BY age_order;

-- Top 10 slow-moving products

WITH unsold_inventory AS
(
    SELECT
        product_id,
        inventory_cost,
        DATEDIFF(DAY, inventory_created_date, '2024-01-01') AS inventory_age_days
    FROM analytics.fact_inventory
    WHERE inventory_created_date < '2024-01-01'
      AND (inventory_sold_date IS NULL OR inventory_sold_date >= '2024-01-01')
)
SELECT TOP 10
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    COUNT(*) AS unsold_items,
    SUM(i.inventory_cost) AS unsold_inventory_cost,
    AVG(CAST(i.inventory_age_days AS decimal(12,2))) AS average_inventory_age_days
FROM unsold_inventory AS i
JOIN analytics.dim_product AS p ON i.product_id = p.product_id
WHERE i.inventory_age_days >= 180
GROUP BY
    p.product_id,
    p.product_name,
    p.category,
    p.brand
ORDER BY unsold_inventory_cost DESC;


-- Check for unsold inventory by year 

SELECT
    YEAR(inventory_created_date) AS inventory_year,
    COUNT(*) AS total_items,
    SUM(CASE WHEN inventory_sold_date < '2024-01-01' THEN 1 ELSE 0 END) AS sold_items,
    COUNT(*) - SUM(CASE WHEN inventory_sold_date < '2024-01-01' THEN 1 ELSE 0 END) AS unsold_items
FROM analytics.fact_inventory
WHERE inventory_created_date < '2024-01-01'
GROUP BY YEAR(inventory_created_date)
ORDER BY inventory_year;

