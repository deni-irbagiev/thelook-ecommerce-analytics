/*
Chapter 7.2  - Product performance

Analyzes category, brand and product performance using revenue,
gross profit, margin and return rate.
*/

-- category performance 

WITH category_totals AS
(
    SELECT
        p.category,
        COUNT(*) AS total_items,
        SUM(CASE WHEN f.item_status = 'Returned' THEN 1 ELSE 0 END) AS returned_items,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.gross_profit_before_returns ELSE 0 END) AS gross_profit
    FROM analytics.fact_order_items AS f
    JOIN analytics.dim_product AS p ON f.product_id = p.product_id
    WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
    GROUP BY p.category
)
SELECT
    category,
    total_items,
    returned_items,
    net_revenue,
    gross_profit,
    CAST(gross_profit / NULLIF(net_revenue, 0) * 100.0 AS decimal(12,2)) AS gross_margin_percent,
    CAST(returned_items * 100.0 / NULLIF(total_items, 0) AS decimal(12,2)) AS return_rate_percent
FROM category_totals
ORDER BY net_revenue DESC;

-- Brand performance

WITH brand_totals AS
(
    SELECT
        p.brand,
        COUNT(*) AS total_items,
        SUM(CASE WHEN f.item_status = 'Returned' THEN 1 ELSE 0 END) AS returned_items,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.gross_profit_before_returns ELSE 0 END) AS gross_profit
    FROM analytics.fact_order_items AS f
    JOIN analytics.dim_product AS p ON f.product_id = p.product_id
    WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
    GROUP BY p.brand
)
SELECT
    brand,
    total_items,
    returned_items,
    net_revenue,
    gross_profit,
    CAST(gross_profit / NULLIF(net_revenue, 0) * 100.0 AS decimal(12,2)) AS gross_margin_percent,
    CAST(returned_items * 100.0 / NULLIF(total_items, 0) AS decimal(12,2)) AS return_rate_percent
FROM brand_totals
ORDER BY net_revenue DESC;

-- Top 10 products by revenue 

WITH product_revenue_totals AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.brand,
        COUNT(*) AS total_items,
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
    JOIN analytics.dim_product AS p ON f.product_id = p.product_id
    WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        p.brand
)
SELECT TOP 10
    product_id,
    product_name,
    category,
    brand,
    total_items,
    net_revenue,
    gross_profit,
    CAST(gross_profit / NULLIF(net_revenue, 0) * 100.0 AS decimal(12,2)) AS gross_margin_percent,
    CAST(returned_items * 100.0 / NULLIF(total_items, 0) AS decimal(12,2)) AS return_rate_percent
FROM product_revenue_totals
ORDER BY net_revenue DESC;

-- Product ranking within category

WITH product_sales AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        COUNT(*) AS total_items,
        SUM(CASE
                WHEN f.item_status <> 'Returned' THEN f.item_revenue
                ELSE 0
            END) AS net_revenue,
        SUM(CASE
                WHEN f.item_status <> 'Returned' THEN f.gross_profit_before_returns
                ELSE 0
            END) AS gross_profit
    FROM analytics.fact_order_items AS f
    INNER JOIN analytics.dim_product AS p
        ON f.product_id = p.product_id
     WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
    GROUP BY
        p.product_id,
        p.product_name,
        p.category
)
SELECT
    product_id,
    product_name,
    category,
    total_items,
    net_revenue,
    gross_profit,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY net_revenue DESC) AS revenue_rank_in_category,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY gross_profit DESC) AS profit_rank_in_category,
    CAST(net_revenue * 100.0 / NULLIF(SUM(net_revenue) OVER (PARTITION BY category), 0) AS decimal(12,4)) AS category_revenue_share_percent
FROM product_sales
ORDER BY
    category,
    revenue_rank_in_category;


-- High-revenue with low margins

WITH product_margin_totals AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.brand,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.gross_profit_before_returns ELSE 0 END) AS gross_profit
    FROM analytics.fact_order_items AS f
    JOIN analytics.dim_product AS p ON f.product_id = p.product_id
    WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        p.brand
),
top_revenue_products AS
(
    SELECT TOP 50
        product_id,
        product_name,
        category,
        brand,
        net_revenue,
        gross_profit,
        CAST(gross_profit / NULLIF(net_revenue, 0) * 100.0 AS decimal(12,2)) AS gross_margin_percent
    FROM product_margin_totals
    ORDER BY net_revenue DESC
)
SELECT TOP 10
    product_id,
    product_name,
    category,
    brand,
    net_revenue,
    gross_profit,
    gross_margin_percent
FROM top_revenue_products
ORDER BY gross_margin_percent, net_revenue DESC;

-- Highest return rates products

WITH product_returns AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        p.brand,
        COUNT(*) AS total_items,
        SUM(CASE WHEN f.item_status = 'Returned' THEN 1 ELSE 0 END) AS returned_items
    FROM analytics.fact_order_items AS f
    JOIN analytics.dim_product AS p ON f.product_id = p.product_id
    WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        p.brand
)
SELECT TOP 10
    product_id,
    product_name,
    category,
    brand,
    total_items,
    returned_items,
    CAST(returned_items * 100.0 / NULLIF(total_items, 0) AS decimal(12,2)) AS return_rate_percent
FROM product_returns
WHERE total_items >= 10
ORDER BY return_rate_percent DESC, total_items DESC;

-- Revenue and profit lost due to returns and cancellations

SELECT
    item_status,
    COUNT(*) AS affected_items,
    SUM(item_revenue) AS potential_revenue_lost,
    SUM(gross_profit_before_returns) AS potential_gross_profit_lost
FROM analytics.fact_order_items
WHERE order_date < '2024-01-01'
  AND item_status IN ('Returned', 'Cancelled')
GROUP BY item_status
ORDER BY potential_revenue_lost DESC;


-- Distribution of products by number of items sold

WITH product_item_counts AS
(
    SELECT
        product_id,
        COUNT(*) AS total_items
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY product_id
)
SELECT 
    total_items,
    COUNT(*) AS number_of_products
FROM product_item_counts
GROUP BY total_items
ORDER BY total_items;