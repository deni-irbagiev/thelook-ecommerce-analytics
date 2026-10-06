/*
Chapter 8 - Reporting layer views

Creates the views consumed by Power BI. Each view applies the date cutoff,
resolves status exclusions, and aggregates to the grain its dashboard page needs.
*/

-- Monthly sales performance 

CREATE OR ALTER VIEW reporting.sales_monthly AS
WITH valid_sales AS
(
    SELECT
        YEAR(order_date) AS order_year,
        MONTH(order_date) AS order_month,
        COUNT(DISTINCT order_id) AS valid_orders,
        COUNT(DISTINCT customer_id) AS total_customers,
        COUNT(*) AS valid_items,
        SUM(CASE WHEN item_status = 'Returned' THEN 1 ELSE 0 END) AS returned_items,
        SUM(CASE WHEN item_status <> 'Returned' THEN item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN item_status <> 'Returned' THEN gross_profit_before_returns ELSE 0 END) AS gross_profit,
        SUM(CASE WHEN item_status = 'Returned' THEN item_revenue ELSE 0 END) AS returned_revenue_value
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY YEAR(order_date), MONTH(order_date)
),
cancelled_sales AS
(
    SELECT
        YEAR(order_date) AS order_year,
        MONTH(order_date) AS order_month,
        COUNT(DISTINCT order_id) AS cancelled_orders,
        COUNT(*) AS cancelled_items,
        SUM(item_revenue) AS cancelled_revenue_value
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status = 'Cancelled'
    GROUP BY YEAR(order_date), MONTH(order_date)
),
total_orders AS
(
    SELECT
        YEAR(order_date) AS order_year,
        MONTH(order_date) AS order_month,
        COUNT(DISTINCT order_id) AS total_orders
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
    GROUP BY YEAR(order_date), MONTH(order_date)
)
SELECT
    v.order_year,
    v.order_month,
    v.valid_orders,
    v.total_customers,
    ISNULL(a.total_orders, 0) AS total_orders,
    v.valid_items,
    v.returned_items,
    ISNULL(c.cancelled_orders, 0) AS cancelled_orders,
    ISNULL(c.cancelled_items, 0) AS cancelled_items,
    v.net_revenue,
    v.gross_profit,
    v.returned_revenue_value,
    ISNULL(c.cancelled_revenue_value, 0) AS cancelled_revenue_value,
    CAST(v.gross_profit / NULLIF(v.net_revenue, 0) * 100 AS decimal(12,2)) AS gross_margin_percent,
    CAST(v.net_revenue / NULLIF(v.valid_orders, 0) AS decimal(12,2)) AS average_order_value,
    CAST(v.returned_items * 100.0 / NULLIF(v.valid_items, 0) AS decimal(12,2)) AS return_rate_percent
FROM valid_sales AS v
LEFT JOIN cancelled_sales AS c
    ON v.order_year = c.order_year
   AND v.order_month = c.order_month
LEFT JOIN total_orders AS a
    ON v.order_year = a.order_year
   AND v.order_month = a.order_month;
GO

-- Product performance 

CREATE OR ALTER VIEW reporting.product_performance AS

WITH product_sales AS
(
    SELECT
        product_id,
        COUNT(*) AS ordered_items,

        SUM(CASE
                WHEN item_status <> 'Cancelled' THEN 1
                ELSE 0
            END) AS valid_items,

        SUM(CASE
                WHEN item_status = 'Returned' THEN 1
                ELSE 0
            END) AS returned_items,

        SUM(CASE
                WHEN item_status = 'Cancelled' THEN 1
                ELSE 0
            END) AS cancelled_items,

        SUM(CASE
                WHEN item_status NOT IN ('Returned', 'Cancelled') THEN item_revenue
                ELSE 0
            END) AS net_revenue,

        SUM(CASE
                WHEN item_status NOT IN ('Returned', 'Cancelled') THEN gross_profit_before_returns
                ELSE 0
            END) AS gross_profit,

        SUM(CASE
                WHEN item_status = 'Returned' THEN item_revenue
                ELSE 0
            END) AS returned_revenue_value,

        SUM(CASE
                WHEN item_status = 'Cancelled' THEN item_revenue
                ELSE 0
            END) AS cancelled_revenue_value

    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
    GROUP BY product_id
),
inventory_status AS
(
    SELECT
        product_id,
        inventory_cost,

        CASE
            WHEN inventory_sold_date < '2024-01-01' THEN 1
            ELSE 0
        END AS sold_flag,

        CASE
            WHEN inventory_sold_date IS NULL
              OR inventory_sold_date >= '2024-01-01' THEN 1
            ELSE 0
        END AS unsold_flag,

        DATEDIFF(DAY, inventory_created_date, '2024-01-01') AS inventory_age_days

    FROM analytics.fact_inventory
    WHERE inventory_created_date < '2024-01-01'
),
product_inventory AS
(
    SELECT
        product_id,
        COUNT(*) AS total_inventory_items,
        SUM(sold_flag) AS sold_items,
        SUM(unsold_flag) AS unsold_items,
        SUM(CASE
                WHEN unsold_flag = 1 THEN inventory_cost
                ELSE 0
            END) AS unsold_inventory_cost,
        SUM(CASE
                WHEN unsold_flag = 1
                 AND inventory_age_days >= 180 THEN 1
                ELSE 0
            END) AS unsold_items_180_plus_days,
        SUM(CASE
                WHEN unsold_flag = 1
                 AND inventory_age_days >= 180 THEN inventory_cost
                ELSE 0
            END) AS old_inventory_cost,
        CAST(AVG(CASE
                    WHEN unsold_flag = 1 THEN CAST(inventory_age_days AS decimal(12,2))
                END) AS decimal(12,2)) AS average_unsold_age_days
    FROM inventory_status
    GROUP BY product_id
)
SELECT
    p.product_id,
    ISNULL(p.product_name, 'Unknown product') AS product_name,
    ISNULL(p.category, 'Unknown category') AS category,
    ISNULL(p.brand, 'Unknown brand') AS brand,
    ISNULL(p.department, 'Unknown department') AS department,
    p.retail_price,
    ISNULL(s.ordered_items, 0) AS ordered_items,
    ISNULL(s.valid_items, 0) AS valid_items,
    ISNULL(s.returned_items, 0) AS returned_items,
    ISNULL(s.cancelled_items, 0) AS cancelled_items,
    ISNULL(s.net_revenue, 0) AS net_revenue,
    ISNULL(s.gross_profit, 0) AS gross_profit,
    ISNULL(s.returned_revenue_value, 0) AS returned_revenue_value,
    ISNULL(s.cancelled_revenue_value, 0) AS cancelled_revenue_value,
    ISNULL(i.total_inventory_items, 0) AS total_inventory_items,
    ISNULL(i.sold_items, 0) AS sold_items,
    ISNULL(i.unsold_items, 0) AS unsold_items,
    ISNULL(i.unsold_inventory_cost, 0) AS unsold_inventory_cost,
    ISNULL(i.unsold_items_180_plus_days, 0) AS unsold_items_180_plus_days,
    ISNULL(i.old_inventory_cost, 0) AS old_inventory_cost,
    i.average_unsold_age_days,
    CAST(ISNULL(s.gross_profit, 0) / NULLIF(ISNULL(s.net_revenue, 0), 0) * 100 AS decimal(12,2)) AS gross_margin_percent,
    CAST(ISNULL(s.returned_items, 0) * 100.0 / NULLIF(ISNULL(s.valid_items, 0), 0) AS decimal(12,2)) AS return_rate_percent,
    CAST(ISNULL(s.cancelled_items, 0) * 100.0 / NULLIF(ISNULL(s.ordered_items, 0), 0) AS decimal(12,2)) AS cancellation_rate_percent,
    CAST(ISNULL(i.sold_items, 0) * 100.0 / NULLIF(ISNULL(i.total_inventory_items, 0), 0) AS decimal(12,2)) AS sell_through_rate_percent
FROM analytics.dim_product AS p
LEFT JOIN product_sales AS s
    ON p.product_id = s.product_id
LEFT JOIN product_inventory AS i
    ON p.product_id = i.product_id;
GO

-- Customer performance 

CREATE OR ALTER VIEW reporting.customer_performance AS

WITH customer_totals AS
(
    SELECT
        c.customer_id,
        c.age,
        c.gender,
        c.city,
        c.state,
        c.country,
        c.acquisition_source,
        COUNT(DISTINCT f.order_id) AS valid_orders,
        COUNT(*) AS total_items,
        MIN(f.order_date) AS first_order_date,
        MAX(f.order_date) AS last_order_date,
        SUM(CASE
                WHEN f.item_status = 'Returned' THEN 1
                ELSE 0
            END) AS returned_items,
        SUM(CASE
                WHEN f.item_status <> 'Returned' THEN f.item_revenue
                ELSE 0
            END) AS net_revenue,
        SUM(CASE
                WHEN f.item_status <> 'Returned' THEN f.gross_profit_before_returns
                ELSE 0
            END) AS gross_profit
    FROM analytics.fact_order_items AS f
    INNER JOIN analytics.dim_customer AS c
        ON f.customer_id = c.customer_id
    WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
    GROUP BY
        c.customer_id,
        c.age,
        c.gender,
        c.city,
        c.state,
        c.country,
        c.acquisition_source
)
SELECT
    customer_id,
    age,
    gender,
    city,
    state,
    country,
    acquisition_source,
    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END AS age_group,
    CASE
        WHEN valid_orders = 1 THEN 'One-time customer'
        ELSE 'Repeat customer'
    END AS customer_type,
    valid_orders,
    total_items,
    returned_items,
    first_order_date,
    last_order_date,
    net_revenue,
    gross_profit,
    CAST(net_revenue / NULLIF(valid_orders, 0) AS decimal(12,2)) AS average_order_value,
    CAST(returned_items * 100.0 / NULLIF(total_items, 0) AS decimal(12,2)) AS return_rate_percent
FROM customer_totals;
GO

-- New and repeat customers by year

CREATE OR ALTER VIEW reporting.customer_yearly AS

WITH first_orders AS
(
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY customer_id
),
yearly_totals AS
(
    SELECT
        YEAR(order_date) AS order_year,
        customer_id,
        COUNT(DISTINCT order_id) AS valid_orders,
        SUM(CASE
                WHEN item_status <> 'Returned' THEN item_revenue
                ELSE 0
            END) AS net_revenue,
        SUM(CASE
                WHEN item_status <> 'Returned' THEN gross_profit_before_returns
                ELSE 0
            END) AS gross_profit
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY
        YEAR(order_date),
        customer_id
)
SELECT
    y.order_year,
    y.customer_id,
    CASE
        WHEN y.order_year = YEAR(f.first_order_date) THEN 'New customer'
        ELSE 'Repeat customer'
    END AS customer_type,
    y.valid_orders,
    y.net_revenue,
    y.gross_profit
FROM yearly_totals AS y
INNER JOIN first_orders AS f
    ON y.customer_id = f.customer_id;
GO

-- Website session funnel

CREATE OR ALTER VIEW reporting.session_funnel AS

WITH session_totals AS
(
    SELECT
        session_id,
        traffic_source,
        browser,
        MIN(event_date) AS session_date,
        COUNT(*) AS total_events,
        MAX(CASE
                WHEN event_type = 'product' THEN 1
                ELSE 0
            END) AS product_view_flag,
        MAX(CASE
                WHEN event_type = 'cart' THEN 1
                ELSE 0
            END) AS cart_flag,
        MAX(CASE
                WHEN event_type = 'purchase' THEN 1
                ELSE 0
            END) AS purchase_flag
    FROM analytics.fact_events
    WHERE event_date < '2024-01-01'
      AND session_id IS NOT NULL
    GROUP BY
        session_id,
        traffic_source,
        browser
)
SELECT
    session_id,
    traffic_source,
    browser,
    session_date,
    YEAR(session_date) AS session_year,
    MONTH(session_date) AS session_month,
    total_events,
    product_view_flag,
    cart_flag,
    purchase_flag,
    CASE
        WHEN product_view_flag = 1
         AND cart_flag = 0 THEN 1
        ELSE 0
    END AS product_to_cart_dropoff_flag,
    CASE
        WHEN cart_flag = 1
         AND purchase_flag = 0 THEN 1
        ELSE 0
    END AS cart_to_purchase_dropoff_flag
FROM session_totals;
GO

-- Distribution-center performance

CREATE OR ALTER VIEW reporting.distribution_center_performance AS

WITH order_center AS
(
    SELECT
        distribution_center_id,
        order_id,
        MAX(days_to_ship) AS days_to_ship,
        MAX(days_to_deliver) AS days_to_deliver,
        MAX(CASE
                WHEN days_to_deliver IS NOT NULL THEN 1
                ELSE 0
            END) AS delivered_flag,
        MAX(returned_flag) AS returned_flag,
        MAX(cancelled_flag) AS cancelled_flag,
        SUM(CASE
                WHEN item_status NOT IN ('Returned', 'Cancelled') THEN item_revenue
                ELSE 0
            END) AS net_revenue,
        SUM(CASE
                WHEN item_status NOT IN ('Returned', 'Cancelled') THEN gross_profit_before_returns
                ELSE 0
            END) AS gross_profit
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
    GROUP BY
        distribution_center_id,
        order_id
),
logistics AS
(
    SELECT
        distribution_center_id,
        COUNT(*) AS orders_handled,
        SUM(delivered_flag) AS delivered_orders,
        SUM(returned_flag) AS returned_orders,
        SUM(cancelled_flag) AS cancelled_orders,
        AVG(CAST(days_to_ship AS decimal(12,2))) AS average_days_to_ship,
        AVG(CAST(days_to_deliver AS decimal(12,2))) AS average_days_to_deliver,
        SUM(net_revenue) AS net_revenue,
        SUM(gross_profit) AS gross_profit
    FROM order_center
    GROUP BY distribution_center_id
),
inventory_status AS
(
    SELECT
        distribution_center_id,
        inventory_cost,
        days_to_sell,
        CASE
            WHEN inventory_sold_date < '2024-01-01' THEN 1
            ELSE 0
        END AS sold_flag,
        CASE
            WHEN inventory_sold_date IS NULL
              OR inventory_sold_date >= '2024-01-01' THEN 1
            ELSE 0
        END AS unsold_flag,
        DATEDIFF(DAY, inventory_created_date, '2024-01-01') AS inventory_age_days
    FROM analytics.fact_inventory
    WHERE inventory_created_date < '2024-01-01'
),
inventory AS
(
    SELECT
        distribution_center_id,
        COUNT(*) AS total_inventory_items,
        SUM(sold_flag) AS sold_items,
        SUM(unsold_flag) AS unsold_items,
        SUM(CASE
                WHEN unsold_flag = 1 THEN inventory_cost
                ELSE 0
            END) AS unsold_inventory_cost,
        SUM(CASE
                WHEN unsold_flag = 1
                 AND inventory_age_days >= 180 THEN 1
                ELSE 0
            END) AS unsold_items_180_plus_days,
        SUM(CASE
                WHEN unsold_flag = 1
                 AND inventory_age_days >= 180 THEN inventory_cost
                ELSE 0
            END) AS old_inventory_cost,
        CAST(AVG(CASE
                    WHEN sold_flag = 1 THEN CAST(days_to_sell AS decimal(12,2))
                END) AS decimal(12,2)) AS average_days_to_sell,
        CAST(AVG(CASE
                    WHEN unsold_flag = 1 THEN CAST(inventory_age_days AS decimal(12,2))
                END) AS decimal(12,2)) AS average_unsold_age_days
    FROM inventory_status
    GROUP BY distribution_center_id
)
SELECT
    d.distribution_center_id,
    d.distribution_center_name,
    d.latitude,
    d.longitude,
    ISNULL(l.orders_handled, 0) AS orders_handled,
    ISNULL(l.delivered_orders, 0) AS delivered_orders,
    ISNULL(l.returned_orders, 0) AS returned_orders,
    ISNULL(l.cancelled_orders, 0) AS cancelled_orders,
    l.average_days_to_ship,
    l.average_days_to_deliver,
    CAST(ISNULL(l.delivered_orders, 0) * 100.0 / NULLIF(ISNULL(l.orders_handled, 0), 0) AS decimal(12,2)) AS delivered_order_share_percent,
    CAST(ISNULL(l.returned_orders, 0) * 100.0 / NULLIF(ISNULL(l.orders_handled, 0), 0) AS decimal(12,2)) AS return_rate_percent,
    CAST(ISNULL(l.cancelled_orders, 0) * 100.0 / NULLIF(ISNULL(l.orders_handled, 0), 0) AS decimal(12,2)) AS cancellation_rate_percent,
    ISNULL(l.net_revenue, 0) AS net_revenue,
    ISNULL(l.gross_profit, 0) AS gross_profit,
    ISNULL(i.total_inventory_items, 0) AS total_inventory_items,
    ISNULL(i.sold_items, 0) AS sold_items,
    ISNULL(i.unsold_items, 0) AS unsold_items,
    CAST(ISNULL(i.sold_items, 0) * 100.0 / NULLIF(ISNULL(i.total_inventory_items, 0), 0) AS decimal(12,2)) AS sell_through_rate_percent,
    ISNULL(i.unsold_inventory_cost, 0) AS unsold_inventory_cost,
    ISNULL(i.unsold_items_180_plus_days, 0) AS unsold_items_180_plus_days,
    ISNULL(i.old_inventory_cost, 0) AS old_inventory_cost,
    i.average_days_to_sell,
    i.average_unsold_age_days
FROM analytics.dim_distribution_center AS d
LEFT JOIN logistics AS l
    ON d.distribution_center_id = l.distribution_center_id
LEFT JOIN inventory AS i
    ON d.distribution_center_id = i.distribution_center_id;
GO

CREATE OR ALTER VIEW reporting.order_fulfilment AS
SELECT
    order_id,
    COUNT(DISTINCT distribution_center_id) AS distribution_center_count,
    MAX(days_to_ship) AS days_to_ship,
    MAX(days_to_deliver) AS days_to_deliver,
    MAX(returned_flag) AS returned_flag,
    MAX(cancelled_flag) AS cancelled_flag
FROM analytics.fact_order_items
WHERE order_date < '2024-01-01'
GROUP BY order_id;

GO


SELECT
    TABLE_NAME
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'reporting'
ORDER BY TABLE_NAME;

SELECT TOP 60 order_year, order_month, valid_orders, cancelled_orders, total_orders
FROM reporting.sales_monthly
ORDER BY order_year, order_month;