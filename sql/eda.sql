USE shopsmart_db;

-- 1. DATA OVERVIEW & HEALTH CHECK

-- Row counts across clean tables
SELECT 'customers_clean' AS table_name, COUNT(*) AS row_count FROM customers_clean
UNION ALL
SELECT 'products_clean' AS table_name, COUNT(*) AS row_count FROM products_clean
UNION ALL
SELECT 'orders_clean' AS table_name, COUNT(*) AS row_count FROM orders_clean
UNION ALL
SELECT 'order_items_clean' AS table_name, COUNT(*) AS row_count FROM order_items_clean;

-- Date range covered in orders
SELECT
    MIN(order_date) AS earliest_order,
    MAX(order_date) AS latest_order,
    DATEDIFF(MAX(order_date), MIN(order_date)) AS days_covered
FROM orders_clean;

-- Breakdown by order status
SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM orders_clean
GROUP BY order_status
ORDER BY total_orders DESC;

-- Overall cleaning flag distribution
SELECT
    data_quality_flag,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM orders_clean
GROUP BY data_quality_flag
ORDER BY total_orders DESC;

-- Flag types for problematic orders
SELECT
    data_quality_flag,
    COUNT(*) AS total_orders
FROM orders_clean
WHERE data_quality_flag != 'OK'
GROUP BY data_quality_flag
ORDER BY total_orders DESC;


-- 2. REVENUE & ORDER PERFORMANCE

-- High-level business metrics (Delivered + OK orders)
SELECT
    COUNT(DISTINCT o.order_id) AS total_delivered_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers_who_ordered,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(AVG(order_totals.order_revenue), 2) AS avg_order_value,
    SUM(oi.quantity) AS total_units_sold
FROM orders_clean o
JOIN order_items_clean oi ON o.order_id = oi.order_id
JOIN (
    SELECT
        order_id,
        SUM(line_total) AS order_revenue
    FROM order_items_clean
    GROUP BY order_id
) order_totals ON o.order_id = order_totals.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK';

-- Monthly revenue performance
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(AVG(oi.line_total), 2) AS avg_item_value
FROM orders_clean o
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;

-- Top 5 revenue months
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    ROUND(SUM(oi.line_total), 2) AS total_revenue
FROM orders_clean o
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY total_revenue DESC
LIMIT 5;

-- Lowest 5 revenue months
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    ROUND(SUM(oi.line_total), 2) AS total_revenue
FROM orders_clean o
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY total_revenue ASC
LIMIT 5;

-- Payment method breakdown
SELECT
    o.payment_method,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(AVG(oi.line_total), 2) AS avg_item_value,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / SUM(COUNT(DISTINCT o.order_id)) OVER (), 2) AS order_share_pct
FROM orders_clean o
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY o.payment_method
ORDER BY total_revenue DESC;

-- Delivery turnaround time (days)
SELECT
    ROUND(AVG(DATEDIFF(delivery_date, order_date)), 1) AS avg_delivery_days,
    MIN(DATEDIFF(delivery_date, order_date)) AS min_delivery_days,
    MAX(DATEDIFF(delivery_date, order_date)) AS max_delivery_days
FROM orders_clean
WHERE order_status = 'Delivered'
  AND data_quality_flag = 'OK'
  AND delivery_date IS NOT NULL
  AND delivery_date > order_date;

-- Cancellation vs return rates
SELECT
    COUNT(*) AS total_valid_orders,
    SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END) AS returned_orders,
    ROUND(SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS cancellation_rate_pct,
    ROUND(SUM(CASE WHEN order_status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM orders_clean
WHERE data_quality_flag = 'OK';


-- 3. CUSTOMER ANALYSIS

-- Active vs inactive accounts
SELECT
    COUNT(DISTINCT c.customer_id) AS total_registered_customers,
    COUNT(DISTINCT o.customer_id) AS customers_who_ordered,
    COUNT(DISTINCT c.customer_id) - COUNT(DISTINCT o.customer_id) AS customers_never_ordered
FROM customers_clean c
LEFT JOIN orders_clean o 
       ON c.customer_id = o.customer_id
      AND o.order_status = 'Delivered'
      AND o.data_quality_flag = 'OK';

-- Top 10 customer spenders
SELECT
    c.customer_id,
    c.full_name,
    c.city,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.quantity) AS total_units_bought,
    ROUND(SUM(oi.line_total), 2) AS total_spent,
    ROUND(AVG(oi.line_total), 2) AS avg_item_spend
FROM customers_clean c
JOIN orders_clean o ON c.customer_id = o.customer_id
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY c.customer_id, c.full_name, c.city
ORDER BY total_spent DESC
LIMIT 10;

-- Top 10 cities by total revenue
SELECT
    c.city,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(SUM(oi.line_total) / COUNT(DISTINCT c.customer_id), 2) AS revenue_per_customer
FROM customers_clean c
JOIN orders_clean o ON c.customer_id = o.customer_id
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
  AND c.city IS NOT NULL
  AND TRIM(c.city) != ''
GROUP BY c.city
ORDER BY total_revenue DESC
LIMIT 10;

-- Gender split
SELECT
    gender,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER (), 2) AS percentage
FROM customers_clean
GROUP BY gender
ORDER BY total_customers DESC;

-- Monthly user registrations
SELECT
    DATE_FORMAT(registration_date, '%Y-%m') AS month,
    COUNT(customer_id) AS new_customers
FROM customers_clean
WHERE registration_date IS NOT NULL
GROUP BY DATE_FORMAT(registration_date, '%Y-%m')
ORDER BY month;

-- Average orders per active customer
SELECT
    ROUND(AVG(order_count), 2) AS avg_orders_per_customer,
    MIN(order_count) AS min_orders,
    MAX(order_count) AS max_orders
FROM (
    SELECT
        customer_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM orders_clean
    WHERE order_status = 'Delivered'
      AND data_quality_flag = 'OK'
    GROUP BY customer_id
) customer_order_counts;


-- 4. PRODUCT PERFORMANCE

-- Revenue & volume by category
SELECT
    p.category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(AVG(oi.unit_price), 2) AS avg_unit_price,
    ROUND(AVG(oi.discount_percent), 2) AS avg_discount_pct,
    ROUND(SUM(oi.line_total) * 100.0 / SUM(SUM(oi.line_total)) OVER (), 2) AS revenue_share_pct
FROM order_items_clean oi
JOIN products_clean p ON oi.product_id = p.product_id
JOIN orders_clean o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY p.category
ORDER BY total_revenue DESC;

-- Top 10 products by volume sold
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(AVG(oi.discount_percent), 2) AS avg_discount_pct
FROM order_items_clean oi
JOIN products_clean p ON oi.product_id = p.product_id
JOIN orders_clean o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY p.product_id, p.product_name, p.category, p.brand
ORDER BY units_sold DESC
LIMIT 10;

-- Top 10 products by gross revenue
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue,
    ROUND(p.selling_price, 2) AS listed_price
FROM order_items_clean oi
JOIN products_clean p ON oi.product_id = p.product_id
JOIN orders_clean o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY p.product_id, p.product_name, p.category, p.brand, p.selling_price
ORDER BY total_revenue DESC
LIMIT 10;

-- Category discount statistics
SELECT
    p.category,
    ROUND(AVG(oi.discount_percent), 2) AS avg_discount_pct,
    MIN(oi.discount_percent) AS min_discount_pct,
    MAX(oi.discount_percent) AS max_discount_pct,
    SUM(oi.quantity) AS units_sold
FROM order_items_clean oi
JOIN products_clean p ON oi.product_id = p.product_id
JOIN orders_clean o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY p.category
ORDER BY avg_discount_pct DESC;

-- Cost higher than selling price check
SELECT
    product_id,
    product_name,
    category,
    brand,
    cost_price,
    selling_price,
    ROUND(selling_price - cost_price, 2) AS margin,
    pricing_error_flag
FROM products_clean
WHERE pricing_error_flag = 'Yes'
ORDER BY margin ASC;

-- Margin analysis by category (valid products only)
SELECT
    p.category,
    ROUND(AVG(p.selling_price - p.cost_price), 2) AS avg_margin_per_unit,
    ROUND(AVG((p.selling_price - p.cost_price) / NULLIF(p.cost_price, 0) * 100), 2) AS avg_margin_pct
FROM products_clean p
WHERE p.pricing_error_flag = 'No'
GROUP BY p.category
ORDER BY avg_margin_pct DESC;


-- 5. RFM CUSTOMER SEGMENTATION

-- Raw metrics preview
SELECT
    c.customer_id,
    c.full_name,
    c.city,
    MAX(o.order_date) AS last_order_date,
    DATEDIFF('2024-06-30', MAX(o.order_date)) AS recency_days,
    COUNT(DISTINCT o.order_id) AS frequency,
    ROUND(SUM(oi.line_total), 2) AS monetary
FROM customers_clean c
JOIN orders_clean o ON c.customer_id = o.customer_id
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY c.customer_id, c.full_name, c.city
ORDER BY monetary DESC
LIMIT 20;

-- RFM customer classification
WITH rfm_base AS (
    SELECT
        c.customer_id,
        c.full_name,
        c.city,
        DATEDIFF('2024-06-30', MAX(o.order_date)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(oi.line_total), 2) AS monetary
    FROM customers_clean c
    JOIN orders_clean o ON c.customer_id = o.customer_id
    JOIN order_items_clean oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Delivered'
      AND o.data_quality_flag = 'OK'
    GROUP BY c.customer_id, c.full_name, c.city
),
rfm_scored AS (
    SELECT
        customer_id,
        full_name,
        city,
        recency_days,
        frequency,
        monetary,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_base
)
SELECT
    customer_id,
    full_name,
    city,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) AS rfm_total,
    CASE
        WHEN (r_score + f_score + m_score) >= 10 THEN 'Champions'
        WHEN (r_score + f_score + m_score) >= 7 THEN 'Loyal Customers'
        WHEN (r_score + f_score + m_score) >= 5 THEN 'At Risk'
        ELSE 'Lost / Churned'
    END AS customer_segment
FROM rfm_scored
ORDER BY rfm_total DESC;

-- Segment aggregated summary
WITH rfm_base AS (
    SELECT
        c.customer_id,
        DATEDIFF('2024-06-30', MAX(o.order_date)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(oi.line_total), 2) AS monetary
    FROM customers_clean c
    JOIN orders_clean o ON c.customer_id = o.customer_id
    JOIN order_items_clean oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Delivered'
      AND o.data_quality_flag = 'OK'
    GROUP BY c.customer_id
),
rfm_scored AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_base
),
rfm_segmented AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        (r_score + f_score + m_score) AS rfm_total,
        CASE
            WHEN (r_score + f_score + m_score) >= 10 THEN 'Champions'
            WHEN (r_score + f_score + m_score) >= 7 THEN 'Loyal Customers'
            WHEN (r_score + f_score + m_score) >= 5 THEN 'At Risk'
            ELSE 'Lost / Churned'
        END AS customer_segment
    FROM rfm_scored
)
SELECT
    customer_segment,
    COUNT(customer_id) AS total_customers,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_orders,
    ROUND(AVG(monetary), 2) AS avg_spend,
    ROUND(SUM(monetary), 2) AS total_segment_revenue,
    ROUND(COUNT(customer_id) * 100.0 / SUM(COUNT(customer_id)) OVER (), 2) AS pct_of_customers
FROM rfm_segmented
GROUP BY customer_segment
ORDER BY
    CASE customer_segment
        WHEN 'Champions' THEN 1
        WHEN 'Loyal Customers' THEN 2
        WHEN 'At Risk' THEN 3
        WHEN 'Lost / Churned' THEN 4
    END;
