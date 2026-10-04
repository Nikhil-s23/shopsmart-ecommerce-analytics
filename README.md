# shopsmart-ecommerce-sql
End-to-end SQL project: data cleaning and exploratory analysis on a fictional e-commerce dataset using MySQL. Covers duplicate handling, NULL treatment, RFM customer segmentation, and revenue analytics.

# ShopSmart E-Commerce Analytics

An end-to-end data analytics project focused on SQL data cleaning and exploratory data analysis for a fictional Indian e-commerce business.

---

## Tools Used
- **MySQL** — data cleaning, EDA
- **MySQL Workbench** — query execution

---

## Project Structure

```
shopsmart-ecommerce-analytics/
│
├── data/
│   ├── customers.csv
│   ├── products.csv
│   ├── orders.csv
│   └── order_items.csv
│
├── sql/
│   ├── data_cleaning.sql
│   └── eda.sql
│
└── README.md
```

---

## Business Context

ShopSmart is a fictional Indian e-commerce company. The raw data came across 4 tables i.e customers, products, orders, and order items with a variety of real world data quality issues that needed to be resolved before any analysis could be done.

---

## Data Cleaning

The raw data had the following issues across all 4 tables:

**Customers**
- Duplicate customer records
- Inconsistent city casing (mumbai, MUMBAI, Mumbai)
- Mixed date formats in date of birth (YYYY-MM-DD, DD/MM/YYYY, DD-MM-YYYY)
- Invalid emails missing @ symbol
- NULL values in phone, city, gender

**Products**
- Inconsistent category casing (electronics, ELECTRONICS, Electronics)
- Products where cost price exceeded selling price
- NULL brand names

**Orders**
- Negative order amounts
- Delivery dates recorded before order dates
- Orders referencing customer IDs that don't exist
- Mixed date formats in order and delivery dates

**Order Items**
- Zero and negative quantities
- Discount percentages above 100%
- Duplicate line item entries

### Cleaning Approach
- All cleaning was done in MySQL, raw tables were never modified
- Created separate `_clean` tables from raw data
- Used CTEs with `ROW_NUMBER()` for deduplication
- Flagged bad records (negative amounts, impossible dates) rather than silently deleting them
- Used `COALESCE` to handle NULL discounts safely

---

## Exploratory Data Analysis

**1 — Data Health Check**
- Confirmed row counts across all 4 clean tables
- Verified date range of the dataset
- Reviewed data quality flag breakdown post-cleaning

**2 — Revenue & Performance**
- Overall KPIs: total revenue, delivered orders, average order value, units sold
- Monthly revenue trend
- Cancellation and return rates

**3 — Customer Analysis**
- Active vs inactive customers (registered but never ordered)
- Top 10 customers by total spend
- Top 10 cities by revenue and revenue per customer

**4 — Product Performance**
- Revenue and units sold by category
- Top 10 best-selling products by volume
- Products with pricing errors (cost price exceeds selling price)

**5 — RFM Segmentation**
- Scored every customer on Recency, Frequency and Monetary value
- Segmented customers into Champions, Loyal, At Risk, and Lost/Churned
- Summarised average spend, order count and recency per segment

---

## Key Findings

- Delivered orders accounted for **50.9%** of all orders placed
- **Electronics** and **Sports** were the top two revenue-generating categories
- **Chennai** generated the highest total revenue across all cities
- **38.8%** of customers were classified as At Risk or Lost/Churned through RFM segmentation
- **5** products had cost prices higher than their selling prices

---

## Dataset

Synthetically generated for this project. Contains ~205 customers, 50 products, ~500 orders and ~1,277 order line items with intentionally introduced data quality issues for cleaning practice.
