/*
Chapter 7.4 - Marketing funnel analysis
Analyzes website sessions, funnel conversion, traffic sources and browsers.
*/

-- Event types check

SELECT
    event_type,
    COUNT(*) AS total_events
FROM analytics.fact_events
WHERE event_date < '2024-01-01'
GROUP BY event_type
ORDER BY total_events DESC;

-- Creating temp table one row per website session 

SELECT
    session_id,
    traffic_source,
    browser,
    MIN(event_date) AS session_date,
    MAX(CASE WHEN event_type = 'product' THEN 1 ELSE 0 END) AS product_view_flag,
    MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS cart_flag,
    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_flag
INTO #session_funnel
FROM analytics.fact_events
WHERE event_date < '2024-01-01'
  AND session_id IS NOT NULL
GROUP BY
    session_id,
    traffic_source,
    browser;


-- Check for cart sessions without a product view 

SELECT COUNT(*) AS cart_without_product
FROM #session_funnel
WHERE cart_flag = 1
  AND product_view_flag = 0;

-- Check for purchase sessions without a cart event

SELECT COUNT(*) AS purchase_without_cart
FROM #session_funnel
WHERE purchase_flag = 1
  AND cart_flag = 0;

-- Overall funnel
SELECT
    COUNT(*) AS total_sessions,
    SUM(product_view_flag) AS product_view_sessions,
    SUM(cart_flag) AS cart_sessions,
    SUM(purchase_flag) AS purchase_sessions,
    SUM(product_view_flag) - SUM(cart_flag) AS product_to_cart_dropoff,
    SUM(cart_flag) - SUM(purchase_flag) AS cart_to_purchase_dropoff,
    CAST(SUM(cart_flag) * 100.0 / NULLIF(SUM(product_view_flag), 0) AS decimal(12,2)) AS product_to_cart_rate,
    CAST(SUM(purchase_flag) * 100.0 / NULLIF(SUM(cart_flag), 0) AS decimal(12,2)) AS cart_to_purchase_rate,
    CAST(SUM(purchase_flag) * 100.0 / NULLIF(COUNT(*), 0) AS decimal(12,2)) AS session_conversion_rate
FROM #session_funnel;


-- Funnel performance by traffic source

SELECT
    traffic_source,
    COUNT(*) AS total_sessions,
    SUM(product_view_flag) AS product_view_sessions,
    SUM(cart_flag) AS cart_sessions,
    SUM(purchase_flag) AS purchase_sessions,
    CAST(SUM(cart_flag) * 100.0 / NULLIF(SUM(product_view_flag), 0) AS decimal(12,2)) AS product_to_cart_rate,
    CAST(SUM(purchase_flag) * 100.0 / NULLIF(SUM(cart_flag), 0) AS decimal(12,2)) AS cart_to_purchase_rate,
    CAST(SUM(purchase_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS session_conversion_rate
FROM #session_funnel
GROUP BY traffic_source
ORDER BY session_conversion_rate DESC;

-- Funnel performance by browser

SELECT
    browser,
    COUNT(*) AS total_sessions,
    SUM(product_view_flag) AS product_view_sessions,
    SUM(cart_flag) AS cart_sessions,
    SUM(purchase_flag) AS purchase_sessions,
    CAST(SUM(cart_flag) * 100.0 / NULLIF(SUM(product_view_flag), 0) AS decimal(12,2)) AS product_to_cart_rate,
    CAST(SUM(purchase_flag) * 100.0 / NULLIF(SUM(cart_flag), 0) AS decimal(12,2)) AS cart_to_purchase_rate,
    CAST(SUM(purchase_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS session_conversion_rate
FROM #session_funnel
GROUP BY browser
ORDER BY session_conversion_rate DESC;

-- Monthly funnel trend

SELECT
    YEAR(session_date) AS session_year,
    MONTH(session_date) AS session_month,
    COUNT(*) AS total_sessions,
    SUM(product_view_flag) AS product_view_sessions,
    SUM(cart_flag) AS cart_sessions,
    SUM(purchase_flag) AS purchase_sessions,
    CAST(SUM(purchase_flag) * 100.0 / COUNT(*) AS decimal(12,2)) AS session_conversion_rate
FROM #session_funnel
GROUP BY
    YEAR(session_date),
    MONTH(session_date)
ORDER BY
    session_year,
    session_month;

DROP TABLE #session_funnel;
