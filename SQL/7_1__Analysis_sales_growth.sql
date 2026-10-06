/*
Chapter 7.1 - Sales and growth analysis

Analyzes revenue, gross profit, orders and customers over time.
Cancelled and returned items are excluded from revenue and profit.
January 2024 is excluded. Reason - incomplete month
*/

-- Item statuses

SELECT
    item_status,
    COUNT(*) AS item_count
FROM analytics.fact_order_items
GROUP BY item_status
ORDER BY item_count DESC;

-- Overall KPIs and gross margin 

WITH totals AS
(
    SELECT
        COUNT(DISTINCT order_id) AS valid_orders,
        COUNT(DISTINCT customer_id) AS total_customers,
        SUM(CASE WHEN item_status <> 'Returned' THEN item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN item_status <> 'Returned' THEN gross_profit_before_returns ELSE 0 END) AS gross_profit
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
)
SELECT
    valid_orders,
    total_customers,
    net_revenue,
    gross_profit,
    CAST(gross_profit / NULLIF(net_revenue, 0) * 100.0 AS decimal(12,2)) AS gross_margin_percent
FROM totals;

-- Annual performance

SELECT
    YEAR(order_date) AS order_year,
    COUNT(DISTINCT order_id) AS valid_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(CASE WHEN item_status <> 'Returned' THEN item_revenue ELSE 0 END) AS net_revenue,
    SUM(CASE WHEN item_status <> 'Returned' THEN gross_profit_before_returns ELSE 0 END) AS gross_profit
FROM analytics.fact_order_items
WHERE order_date < '2024-01-01'
  AND item_status <> 'Cancelled'
GROUP BY YEAR(order_date)
ORDER BY order_year;

-- Monthly sales trend

WITH monthly_sales AS
(
    SELECT
        YEAR(order_date) AS order_year,
        MONTH(order_date) AS order_month,
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
        MONTH(order_date)
),
monthly_comparison AS
(
    SELECT
        order_year,
        order_month,
        valid_orders,
        net_revenue,
        gross_profit,
        LAG(net_revenue) OVER (ORDER BY order_year, order_month) AS previous_month_revenue,
        LAG(gross_profit) OVER (ORDER BY order_year, order_month) AS previous_month_profit,
        SUM(net_revenue) OVER (ORDER BY order_year, order_month) AS cumulative_revenue,
        SUM(gross_profit) OVER (ORDER BY order_year, order_month) AS cumulative_profit
    FROM monthly_sales
)
SELECT
    order_year,
    order_month,
    valid_orders,
    net_revenue,
    previous_month_revenue,
    CAST((net_revenue - previous_month_revenue) * 100.0 / NULLIF(previous_month_revenue, 0) AS decimal(12,2)) AS monthly_revenue_growth_percent,
    gross_profit,
    previous_month_profit,
    CAST((gross_profit - previous_month_profit) * 100.0 / NULLIF(previous_month_profit, 0) AS decimal(12,2)) AS monthly_profit_growth_percent,
    cumulative_revenue,
    cumulative_profit
FROM monthly_comparison
ORDER BY
    order_year,
    order_month;

-- YoY growth

WITH yearly_performance AS
(
    SELECT
        YEAR(order_date) AS order_year,
        SUM(CASE WHEN item_status <> 'Returned' THEN item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN item_status <> 'Returned' THEN gross_profit_before_returns ELSE 0 END) AS gross_profit
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY YEAR(order_date)
),
yearly_comparison AS
(
    SELECT
        order_year,
        net_revenue,
        gross_profit,
        LAG(net_revenue) OVER (ORDER BY order_year) AS previous_year_revenue,
        LAG(gross_profit) OVER (ORDER BY order_year) AS previous_year_profit
    FROM yearly_performance
)
SELECT
    order_year,
    net_revenue,
    gross_profit,
    CAST((net_revenue - previous_year_revenue) / NULLIF(previous_year_revenue, 0) * 100.0 AS decimal(12,2)) AS revenue_growth_percent,
    CAST((gross_profit - previous_year_profit) / NULLIF(previous_year_profit, 0) * 100.0 AS decimal(12,2)) AS profit_growth_percent
FROM yearly_comparison
ORDER BY order_year;

-- Avg order value by year

WITH yearly_totals AS
(
    SELECT
        YEAR(order_date) AS order_year,
        SUM(CASE WHEN item_status <> 'Returned' THEN item_revenue ELSE 0 END) AS net_revenue,
        COUNT(DISTINCT order_id) AS valid_orders
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY YEAR(order_date)
)
SELECT
    order_year,
    net_revenue,
    valid_orders,
    CAST(net_revenue / NULLIF(valid_orders, 0) AS decimal(12,2)) AS average_order_value
FROM yearly_totals
ORDER BY order_year;