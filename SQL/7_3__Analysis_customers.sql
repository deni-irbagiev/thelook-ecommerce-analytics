/*
Chapter 7.3 - Customers analysis
Analyzes one-time and repeat customers, customer value,
countries, acquisition sources and demographic groups.
*/

-- One-time and repeat customers

WITH customer_totals AS
(
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS valid_orders,
        SUM(CASE WHEN item_status <> 'Returned' THEN item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN item_status <> 'Returned' THEN gross_profit_before_returns ELSE 0 END) AS gross_profit
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY customer_id
)
SELECT
    CASE WHEN valid_orders = 1 THEN 'One-time customer' ELSE 'Repeat customer' END AS customer_type,
    COUNT(*) AS total_customers,
    SUM(valid_orders) AS valid_orders,
    SUM(net_revenue) AS net_revenue,
    SUM(gross_profit) AS gross_profit,
    CAST(SUM(valid_orders) * 1.0 / NULLIF(COUNT(*), 0) AS decimal(12,2)) AS average_orders_per_customer,
    CAST(SUM(net_revenue) / NULLIF(COUNT(*), 0) AS decimal(12,2)) AS revenue_per_customer
FROM customer_totals
GROUP BY CASE WHEN valid_orders = 1 THEN 'One-time customer' ELSE 'Repeat customer' END
ORDER BY net_revenue DESC;

-- New and repeat customers 

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
customer_yearly AS
(
    SELECT
        YEAR(order_date) AS order_year,
        customer_id,
        COUNT(DISTINCT order_id) AS valid_orders,
        SUM(CASE WHEN item_status <> 'Returned' THEN item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN item_status <> 'Returned' THEN gross_profit_before_returns ELSE 0 END) AS gross_profit
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY YEAR(order_date), customer_id
)
SELECT
    cy.order_year,
    CASE WHEN cy.order_year = YEAR(fo.first_order_date) THEN 'New customer' ELSE 'Repeat customer' END AS customer_type,
    COUNT(*) AS total_customers,
    SUM(cy.valid_orders) AS valid_orders,
    SUM(cy.net_revenue) AS net_revenue,
    SUM(cy.gross_profit) AS gross_profit
FROM customer_yearly AS cy
JOIN first_orders AS fo ON cy.customer_id = fo.customer_id
GROUP BY
    cy.order_year,
    CASE WHEN cy.order_year = YEAR(fo.first_order_date) THEN 'New customer' ELSE 'Repeat customer' END
ORDER BY cy.order_year, customer_type;

-- Order-frequency distribution

WITH customer_orders AS
(
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS valid_orders
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY customer_id
)
SELECT
    valid_orders,
    COUNT(*) AS number_of_customers
FROM customer_orders
GROUP BY valid_orders
ORDER BY valid_orders;

-- Customer performance by country

WITH country_totals AS
(
    SELECT
        c.country,
        COUNT(DISTINCT f.customer_id) AS total_customers,
        COUNT(DISTINCT f.order_id) AS valid_orders,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.gross_profit_before_returns ELSE 0 END) AS gross_profit
    FROM analytics.fact_order_items AS f
    JOIN analytics.dim_customer AS c ON f.customer_id = c.customer_id
    WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
    GROUP BY c.country
)
SELECT
    country,
    total_customers,
    valid_orders,
    net_revenue,
    gross_profit,
    CAST(net_revenue / NULLIF(total_customers, 0) AS decimal(12,2)) AS revenue_per_customer,
    CAST(net_revenue / NULLIF(valid_orders, 0) AS decimal(12,2)) AS average_order_value
FROM country_totals
ORDER BY net_revenue DESC;

-- Customer performance by acquisition source

WITH source_totals AS
(
    SELECT
        c.acquisition_source,
        COUNT(DISTINCT f.customer_id) AS total_customers,
        COUNT(DISTINCT f.order_id) AS valid_orders,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.item_revenue ELSE 0 END) AS net_revenue,
        SUM(CASE WHEN f.item_status <> 'Returned' THEN f.gross_profit_before_returns ELSE 0 END) AS gross_profit
    FROM analytics.fact_order_items AS f
    JOIN analytics.dim_customer AS c ON f.customer_id = c.customer_id
    WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
    GROUP BY c.acquisition_source
)
SELECT
    acquisition_source,
    total_customers,
    valid_orders,
    net_revenue,
    gross_profit,
    CAST(net_revenue / NULLIF(total_customers, 0) AS decimal(12,2)) AS revenue_per_customer,
    CAST(net_revenue / NULLIF(valid_orders, 0) AS decimal(12,2)) AS average_order_value
FROM source_totals
ORDER BY net_revenue DESC;

-- Customer performance by age group 

WITH customer_data AS
(
    SELECT
        f.order_id,
        f.customer_id,
        f.item_status,
        f.item_revenue,
        f.gross_profit_before_returns,
        CASE
            WHEN c.age < 25 THEN 'Under 25'
            WHEN c.age BETWEEN 25 AND 34 THEN '25-34'
            WHEN c.age BETWEEN 35 AND 44 THEN '35-44'
            WHEN c.age BETWEEN 45 AND 54 THEN '45-54'
            WHEN c.age BETWEEN 55 AND 64 THEN '55-64'
            ELSE '65+'
        END AS age_group
    FROM analytics.fact_order_items AS f
    JOIN analytics.dim_customer AS c ON f.customer_id = c.customer_id
    WHERE f.order_date < '2024-01-01'
      AND f.item_status <> 'Cancelled'
)
SELECT
    age_group,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT order_id) AS valid_orders,
    SUM(CASE WHEN item_status <> 'Returned' THEN item_revenue ELSE 0 END) AS net_revenue,
    SUM(CASE WHEN item_status <> 'Returned' THEN gross_profit_before_returns ELSE 0 END) AS gross_profit
FROM customer_data
GROUP BY age_group
ORDER BY net_revenue DESC;

-- Customer performance by gender

SELECT
    c.gender,
    COUNT(DISTINCT f.customer_id) AS total_customers,
    COUNT(DISTINCT f.order_id) AS valid_orders,
    SUM(CASE WHEN f.item_status <> 'Returned' THEN f.item_revenue ELSE 0 END) AS net_revenue,
    SUM(CASE WHEN f.item_status <> 'Returned' THEN f.gross_profit_before_returns ELSE 0 END) AS gross_profit
FROM analytics.fact_order_items AS f
JOIN analytics.dim_customer AS c ON f.customer_id = c.customer_id
WHERE f.order_date < '2024-01-01'
  AND f.item_status <> 'Cancelled'
GROUP BY c.gender
ORDER BY net_revenue DESC;

-- Customer purchase sequence

WITH customer_order_revenue AS
(
    SELECT
        customer_id,
        order_id,
        MIN(order_date) AS order_date,
        SUM(CASE WHEN item_status <> 'Returned' THEN item_revenue ELSE 0 END) AS order_revenue
    FROM analytics.fact_order_items
    WHERE order_date < '2024-01-01'
      AND item_status <> 'Cancelled'
    GROUP BY
        customer_id,
        order_id
),
order_sequence AS
(
    SELECT
        customer_id,
        order_id,
        order_date,
        order_revenue,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS customer_order_number,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS previous_order_date
    FROM customer_order_revenue
)
SELECT
    customer_id,
    order_id,
    order_date,
    customer_order_number,
    previous_order_date,
    DATEDIFF(DAY,previous_order_date, order_date) AS days_since_previous_order,
    order_revenue
FROM order_sequence
ORDER BY
    customer_id,
    customer_order_number;