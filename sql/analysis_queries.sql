-- =============================================================
-- Retail Profitability Analysis: key SQL (DuckDB dialect)
-- Run against the orders_clean table built in notebooks/01
-- =============================================================

-- 1. Year-on-year growth with a window function (LAG)
WITH y AS (
    SELECT order_year, SUM(sales) AS sales, SUM(profit) AS profit
    FROM orders_clean
    GROUP BY order_year
)
SELECT order_year,
       ROUND(sales)                                                        AS sales,
       ROUND(100 * profit / sales, 1)                                      AS margin_pct,
       ROUND(100 * (sales / LAG(sales) OVER (ORDER BY order_year) - 1), 1) AS sales_growth_pct
FROM y
ORDER BY order_year;

-- 2. Loss-making sub-categories
SELECT category, sub_category,
       ROUND(SUM(sales))                        AS sales,
       ROUND(SUM(profit))                       AS profit,
       ROUND(100 * SUM(profit) / SUM(sales), 1) AS margin_pct,
       ROUND(100 * AVG(discount), 1)            AS avg_discount_pct
FROM orders_clean
GROUP BY category, sub_category
HAVING SUM(profit) < 0
ORDER BY profit;

-- 3. Margin and share of loss-making lines by discount band
SELECT discount_band,
       COUNT(*)                                 AS order_lines,
       ROUND(100 * SUM(profit) / SUM(sales), 1) AS margin_pct,
       ROUND(100 * AVG(is_loss::INT), 1)        AS pct_lines_at_a_loss
FROM orders_clean
GROUP BY discount_band
ORDER BY MIN(discount);

-- 4. Worst state in each region (RANK inside a partition)
WITH s AS (
    SELECT region, state, SUM(profit) AS profit, AVG(discount) AS avg_discount
    FROM orders_clean
    GROUP BY region, state
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY region ORDER BY profit) AS worst_rank
    FROM s
)
SELECT region, state, ROUND(profit) AS profit, ROUND(100 * avg_discount, 1) AS avg_discount_pct
FROM ranked
WHERE worst_rank = 1
ORDER BY profit;

-- 5. Profit per order by segment (aggregate to order level first)
WITH order_totals AS (
    SELECT segment, order_id, SUM(sales) AS order_sales, SUM(profit) AS order_profit
    FROM orders_clean
    GROUP BY segment, order_id
)
SELECT segment, COUNT(*) AS orders, ROUND(AVG(order_profit), 2) AS profit_per_order
FROM order_totals
GROUP BY segment
ORDER BY profit_per_order DESC;

-- 6. Top 3 loss-making products per category (ROW_NUMBER)
WITH p AS (
    SELECT category, product_name, SUM(profit) AS profit
    FROM orders_clean
    GROUP BY category, product_name
)
SELECT *
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY category ORDER BY profit) AS rn FROM p)
WHERE rn <= 3
ORDER BY category, rn;

-- 7. Scenario: cap discounts at 20%
SELECT COUNT(*)                                   AS lines_above_20pct,
       ROUND(SUM(profit))                         AS current_profit_on_them,
       ROUND(-SUM(profit))                        AS worst_case_gain,  -- sales lost entirely
       ROUND(SUM(list_price_sales * 0.8 - sales)) AS best_case_gain    -- volume holds at 20% off
FROM orders_clean
WHERE discount > 0.2;
