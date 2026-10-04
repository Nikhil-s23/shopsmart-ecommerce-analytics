-- ShopSmart E-Commerce Analytics
-- Data Cleaning & Reporting Script

CREATE DATABASE IF NOT EXISTS shopsmart_db;
USE shopsmart_db;

-- 1. RAW TABLES SETUP

DROP TABLE IF EXISTS order_items_raw;
DROP TABLE IF EXISTS orders_raw;
DROP TABLE IF EXISTS products_raw;
DROP TABLE IF EXISTS customers_raw;

CREATE TABLE customers_raw (
    customer_id VARCHAR(20),
    full_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(50),
    city VARCHAR(50),
    country VARCHAR(50),
    gender VARCHAR(10),
    date_of_birth VARCHAR(20),
    registration_date VARCHAR(20)
);

CREATE TABLE products_raw (
    product_id VARCHAR(20),
    product_name VARCHAR(100),
    category VARCHAR(50),
    brand VARCHAR(50),
    cost_price VARCHAR(20),
    selling_price VARCHAR(20)
);

CREATE TABLE orders_raw (
    order_id VARCHAR(20),
    customer_id VARCHAR(20),
    order_date VARCHAR(50),
    delivery_date VARCHAR(50),
    order_status VARCHAR(20),
    payment_method VARCHAR(20),
    total_amount VARCHAR(20)
);

CREATE TABLE order_items_raw (
    item_id VARCHAR(20),
    order_id VARCHAR(20),
    product_id VARCHAR(20),
    quantity VARCHAR(10),
    unit_price VARCHAR(20),
    discount_percent VARCHAR(10)
);

-- 2. DATA INGESTION

-- Ingested data using MySQL's Table Data Import Wizard

-- 3. EXPLORATORY DATA ANALYSIS (RAW TABLES)

-- Customer data issues
-- NULL/empty count across all columns
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN customer_id IS NULL OR customer_id = '' THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN full_name IS NULL OR full_name = '' THEN 1 ELSE 0 END) AS null_full_name,
    SUM(CASE WHEN email IS NULL OR email = '' THEN 1 ELSE 0 END) AS null_email,
    SUM(CASE WHEN phone IS NULL OR phone = '' THEN 1 ELSE 0 END) AS null_phone,
    SUM(CASE WHEN city IS NULL OR city = '' THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN gender IS NULL OR gender = '' THEN 1 ELSE 0 END) AS null_gender,
    SUM(CASE WHEN date_of_birth IS NULL OR date_of_birth = '' THEN 1 ELSE 0 END) AS null_dob,
    SUM(CASE WHEN registration_date IS NULL OR registration_date = '' THEN 1 ELSE 0 END) AS null_reg_date
FROM customers_raw;

-- Duplicate customer_ids
SELECT customer_id, COUNT(*) 
FROM customers_raw 
GROUP BY customer_id 
HAVING COUNT(*) > 1;

SELECT DISTINCT city FROM customers_raw ORDER BY city;

SELECT gender, COUNT(*) 
FROM customers_raw 
GROUP BY gender;

-- Invalid emails
SELECT customer_id, email 
FROM customers_raw 
WHERE email NOT LIKE '%@%';

-- Phone format patterns present in the data
SELECT 
    CASE
        WHEN phone IS NULL OR TRIM(phone) = '' THEN 'NULL/Empty'
        WHEN phone LIKE '+91%' THEN 'Starts with +91'
        ELSE 'Other'
    END AS phone_format,
    COUNT(*)
FROM customers_raw
GROUP BY phone_format;

-- Date of birth format variety
SELECT
    CASE
        WHEN date_of_birth REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 'YYYY-MM-DD'
        WHEN date_of_birth REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$' THEN 'YYYY/MM/DD'
        WHEN date_of_birth LIKE '%/%' AND date_of_birth NOT REGEXP '^[0-9]{4}' THEN 'DD/MM/YYYY'
        WHEN date_of_birth LIKE '%-%' AND date_of_birth NOT REGEXP '^[0-9]{4}' THEN 'DD-MM-YYYY'
        WHEN date_of_birth IS NULL OR TRIM(date_of_birth) = '' THEN 'NULL/Empty'
        ELSE 'Unknown'
    END AS date_format,
    COUNT(*)
FROM customers_raw
GROUP BY date_format;

-- Product data issues
SELECT category, COUNT(*) 
FROM products_raw 
GROUP BY category;

-- Products where cost_price > selling_price (data error)
SELECT product_id, product_name, cost_price, selling_price
FROM products_raw
WHERE CAST(cost_price AS DECIMAL(10,2)) > CAST(selling_price AS DECIMAL(10,2));

SELECT COUNT(*) FROM products_raw WHERE brand IS NULL OR TRIM(brand) = '';

-- Duplicate product_ids
SELECT product_id, COUNT(*) 
FROM products_raw 
GROUP BY product_id 
HAVING COUNT(*) > 1;

-- Order data issues
-- Negative total_amount
SELECT order_id, total_amount 
FROM orders_raw 
WHERE CAST(total_amount AS DECIMAL(10,2)) < 0;

-- Delivery date before order date (impossible)
SELECT order_id, order_date, delivery_date
FROM orders_raw
WHERE delivery_date IS NOT NULL
  AND TRIM(delivery_date) != ''
  AND order_date    REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND delivery_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
  AND STR_TO_DATE(delivery_date, '%Y-%m-%d') < STR_TO_DATE(order_date, '%Y-%m-%d');

-- Check orphan orders
SELECT o.order_id, o.customer_id
FROM orders_raw o
LEFT JOIN customers_raw c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- NULL delivery_date on Delivered orders
SELECT order_id, order_status, delivery_date
FROM orders_raw
WHERE UPPER(TRIM(order_status)) LIKE '%DELIVER%'
  AND (delivery_date IS NULL OR TRIM(delivery_date) = '');

SELECT order_status, COUNT(*) FROM orders_raw GROUP BY order_status;
SELECT payment_method, COUNT(*) FROM orders_raw GROUP BY payment_method;

-- Order items issues
-- Zero or negative quantity
SELECT item_id, order_id, quantity 
FROM order_items_raw 
WHERE CAST(quantity AS SIGNED) <= 0;

-- Discount percentage over 100 (impossible)
SELECT item_id, discount_percent 
FROM order_items_raw 
WHERE CAST(discount_percent AS DECIMAL(5,2)) > 100;

-- Duplicate item entries
SELECT item_id, order_id, product_id, COUNT(*) 
FROM order_items_raw 
GROUP BY item_id, order_id, product_id 
HAVING COUNT(*) > 1;

-- 4. CLEANING & TRANSFORMATION

-- Clean Customers
DROP TABLE IF EXISTS customers_clean;

CREATE TABLE customers_clean AS
WITH ranked_customers AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY registration_date DESC) AS rn
    FROM customers_raw
)
SELECT
    TRIM(customer_id) AS customer_id,
    TRIM(full_name) AS full_name,
    LOWER(TRIM(email)) AS email,
    CASE
        WHEN phone IS NULL OR TRIM(phone) = '' THEN 'Unknown'
        WHEN phone LIKE '+91%' AND LENGTH(TRIM(phone)) >= 13
            THEN CONCAT('+91 ', SUBSTRING(TRIM(phone), 4, 10))
        ELSE TRIM(phone)
    END AS phone,
    CONCAT(
        UPPER(SUBSTRING(LOWER(TRIM(city)), 1, 1)),
        SUBSTRING(LOWER(TRIM(city)), 2)
    ) AS city,
    CONCAT(
        UPPER(SUBSTRING(LOWER(TRIM(country)), 1, 1)),
        SUBSTRING(LOWER(TRIM(country)), 2)
    ) AS country,
    CASE
        WHEN UPPER(TRIM(gender)) IN ('M', 'MALE') THEN 'M'
        WHEN UPPER(TRIM(gender)) IN ('F', 'FEMALE') THEN 'F'
        WHEN gender IS NULL OR TRIM(gender) = '' THEN 'Unknown'
        ELSE 'Other'
    END AS gender,
    CASE
        WHEN date_of_birth REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(date_of_birth, '%Y-%m-%d')
        WHEN date_of_birth LIKE '%/%'
             AND CAST(SUBSTRING_INDEX(date_of_birth, '/', 1) AS SIGNED) > 12
            THEN STR_TO_DATE(date_of_birth, '%d/%m/%Y')
        WHEN date_of_birth LIKE '%/%'
             AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(date_of_birth, '/', 2), '/', -1) AS SIGNED) > 12
            THEN STR_TO_DATE(date_of_birth, '%m/%d/%Y')
        WHEN date_of_birth LIKE '%/%'
            THEN STR_TO_DATE(date_of_birth, '%d/%m/%Y')
        WHEN date_of_birth LIKE '%-%'
             AND CAST(SUBSTRING_INDEX(date_of_birth, '-', 1) AS SIGNED) > 12
            THEN STR_TO_DATE(date_of_birth, '%d-%m-%Y')
        WHEN date_of_birth LIKE '%-%'
             AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(date_of_birth, '-', 2), '-', -1) AS SIGNED) > 12
            THEN STR_TO_DATE(date_of_birth, '%m-%d-%Y')
        WHEN date_of_birth LIKE '%-%'
            THEN STR_TO_DATE(date_of_birth, '%d-%m-%Y')
        ELSE NULL
    END AS date_of_birth,
    STR_TO_DATE(registration_date, '%Y-%m-%d') AS registration_date
FROM ranked_customers
WHERE rn = 1
  AND customer_id IS NOT NULL 
  AND TRIM(customer_id) != ''
  AND email LIKE '%@%';

-- Clean Products
DROP TABLE IF EXISTS products_clean;

CREATE TABLE products_clean AS
WITH ranked_products AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS rn
    FROM products_raw
)
SELECT
    TRIM(product_id) AS product_id,
    TRIM(product_name) AS product_name,
    CASE
        WHEN LOWER(TRIM(category)) LIKE '%electr%' THEN 'Electronics'
        WHEN LOWER(TRIM(category)) LIKE '%cloth%' THEN 'Clothing'
        WHEN LOWER(TRIM(category)) LIKE '%home%' THEN 'Home & Kitchen'
        WHEN LOWER(TRIM(category)) LIKE '%sport%' THEN 'Sports'
        WHEN LOWER(TRIM(category)) LIKE '%book%' THEN 'Books'
        WHEN LOWER(TRIM(category)) LIKE '%beaut%' THEN 'Beauty'
        ELSE NULL
    END AS category,
    CASE
        WHEN brand IS NULL OR TRIM(brand) = '' THEN 'Unknown'
        ELSE TRIM(brand)
    END AS brand,
    CAST(cost_price AS DECIMAL(10,2)) AS cost_price,
    CAST(selling_price AS DECIMAL(10,2)) AS selling_price,
    CASE
        WHEN CAST(cost_price AS DECIMAL(10,2)) > CAST(selling_price AS DECIMAL(10,2))
        THEN 'Yes' ELSE 'No'
    END AS pricing_error_flag
FROM ranked_products
WHERE rn = 1
  AND product_id IS NOT NULL 
  AND TRIM(product_id) != '';

-- Clean Orders
DROP TABLE IF EXISTS orders_clean;

CREATE TABLE orders_clean AS
WITH deduplicated AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_date DESC) AS rn
    FROM orders_raw
    WHERE order_id IS NOT NULL AND TRIM(order_id) != ''
),
parsed_orders AS (
    SELECT
        TRIM(order_id) AS order_id,
        TRIM(customer_id) AS customer_id,
        CASE
            WHEN order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                THEN STR_TO_DATE(order_date, '%Y-%m-%d')
            WHEN order_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
                THEN STR_TO_DATE(order_date, '%d/%m/%Y')
            ELSE NULL
        END AS order_date,
        CASE
            WHEN delivery_date IS NULL OR TRIM(delivery_date) = '' THEN NULL
            WHEN delivery_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                THEN STR_TO_DATE(delivery_date, '%Y-%m-%d')
            WHEN delivery_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
                THEN STR_TO_DATE(delivery_date, '%d/%m/%Y')
            ELSE NULL
        END AS delivery_date,
        CONCAT(
            UPPER(SUBSTRING(LOWER(TRIM(order_status)), 1, 1)),
            SUBSTRING(LOWER(TRIM(order_status)), 2)
        ) AS order_status,
        UPPER(TRIM(payment_method)) AS payment_method,
        CAST(total_amount AS DECIMAL(10,2)) AS total_amount
    FROM deduplicated
    WHERE rn = 1
      AND customer_id IN (SELECT customer_id FROM customers_clean)
)
SELECT
    order_id,
    customer_id,
    order_date,
    delivery_date,
    order_status,
    payment_method,
    total_amount,
    CASE
        WHEN total_amount < 0 THEN 'Negative Amount'
        WHEN delivery_date IS NOT NULL AND delivery_date < order_date THEN 'Delivery Before Order'
        ELSE 'OK'
    END AS data_quality_flag
FROM parsed_orders;

-- Clean Order Items
DROP TABLE IF EXISTS order_items_clean;

CREATE TABLE order_items_clean AS
WITH deduplicated AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY item_id, order_id, product_id
            ORDER BY item_id
        ) AS rn
    FROM order_items_raw
)
SELECT
    TRIM(item_id) AS item_id,
    TRIM(order_id) AS order_id,
    TRIM(product_id) AS product_id,
    CAST(quantity AS UNSIGNED) AS quantity,
    CAST(unit_price AS DECIMAL(10,2)) AS unit_price,
    COALESCE(CAST(discount_percent AS DECIMAL(5,2)), 0.00) AS discount_percent,
    ROUND(
        CAST(unit_price AS DECIMAL(10,2))
        * CAST(quantity AS UNSIGNED)
        * (1 - COALESCE(CAST(discount_percent AS DECIMAL(5,2)), 0.00) / 100),
    2) AS line_total
FROM deduplicated
WHERE rn = 1
  AND CAST(quantity AS SIGNED) > 0
  AND COALESCE(CAST(discount_percent AS DECIMAL(5,2)), 0.00) <= 100
  AND order_id IN (SELECT order_id FROM orders_clean);

-- Cleaning Verification
SELECT COUNT(*) AS clean_customers FROM customers_clean;
SELECT COUNT(*) AS clean_products FROM products_clean;
SELECT COUNT(*) AS clean_orders FROM orders_clean;
SELECT COUNT(*) AS clean_items FROM order_items_clean;

-- 5. BUSINESS REPORTING & ANALYTICS

-- Monthly revenue trend
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.line_total), 2) AS total_revenue
FROM orders_clean o
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;

-- Top 10 customers by spend
SELECT
    c.customer_id,
    c.full_name,
    c.city,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.line_total), 2) AS total_spent
FROM customers_clean c
JOIN orders_clean o ON c.customer_id = o.customer_id
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY c.customer_id, c.full_name, c.city
ORDER BY total_spent DESC
LIMIT 10;

-- Revenue by category
SELECT
    p.category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue
FROM order_items_clean oi
JOIN products_clean p ON oi.product_id = p.product_id
JOIN orders_clean o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY p.category
ORDER BY total_revenue DESC;

-- Order status breakdown
SELECT
    order_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM orders_clean
WHERE data_quality_flag = 'OK'
GROUP BY order_status
ORDER BY total_orders DESC;

-- Payment method split (Delivered orders)
SELECT
    o.payment_method,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.line_total), 2) AS total_revenue
FROM orders_clean o
JOIN order_items_clean oi ON o.order_id = oi.order_id
WHERE o.data_quality_flag = 'OK'
  AND o.order_status = 'Delivered'
GROUP BY o.payment_method
ORDER BY total_orders DESC;

-- Customer count by city
SELECT
    city,
    COUNT(DISTINCT customer_id) AS total_customers
FROM customers_clean
WHERE city IS NOT NULL AND TRIM(city) != ''
GROUP BY city
ORDER BY total_customers DESC
LIMIT 10;

-- Best-selling products
SELECT
    p.product_name,
    p.category,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.line_total), 2) AS total_revenue
FROM order_items_clean oi
JOIN products_clean p ON oi.product_id = p.product_id
JOIN orders_clean o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
  AND o.data_quality_flag = 'OK'
GROUP BY p.product_name, p.category
ORDER BY units_sold DESC
LIMIT 10;

-- RFM Customer Segmentation
WITH rfm_base AS (
    SELECT
        c.customer_id,
        c.full_name,
        DATEDIFF('2024-06-30', MAX(o.order_date)) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(oi.line_total), 2) AS monetary
    FROM customers_clean c
    JOIN orders_clean o ON c.customer_id = o.customer_id
    JOIN order_items_clean oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'Delivered'
      AND o.data_quality_flag = 'OK'
    GROUP BY c.customer_id, c.full_name
),
rfm_scored AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_base
)
SELECT
    customer_id,
    full_name,
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
