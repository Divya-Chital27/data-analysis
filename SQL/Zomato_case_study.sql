/* ============================================================================
   ZOMATO SQL CASE STUDY
   ----------------------------------------------------------------------------
   A food-delivery analytics case study answering 13 real business questions —
   customer behavior, restaurant performance, revenue, and delivery partner
   payouts — using joins, subqueries, CTEs, and aggregate functions on a
   Zomato-style relational schema.

   Schema (inferred from the queries below):
     users(user_id, name)
     restaurants(r_id, r_name)
     food(f_id, f_name, type, price)
     menu(r_id, f_id)                                  -- which foods each restaurant sells
     orders(order_id, user_id, r_id, partner_id, date,
            amount, restaurant_rating, delivery_rating)
     order_details(order_id, f_id)                      -- line items within an order
     delivery_partner(partner_id, partner_name)

   Author: Divya Chital
   ============================================================================ */

CREATE DATABASE IF NOT EXISTS zomato;
USE zomato;


-- ============================================================================
-- Q1. How many orders has each customer placed?
-- Business use: identify high-frequency / loyal customers.
-- ============================================================================
SELECT
    u.name,
    COUNT(*) AS num_of_orders
FROM users u
JOIN orders o
    ON u.user_id = o.user_id
GROUP BY u.name;


-- ============================================================================
-- Q2. Which restaurant offers the most menu items?
-- Business use: benchmark restaurant catalog size / variety.
-- ============================================================================
SELECT
    r.r_name,
    COUNT(*) AS num_of_menu_items
FROM restaurants r
JOIN menu m
    ON r.r_id = m.r_id
GROUP BY r.r_name
ORDER BY num_of_menu_items DESC;


-- ============================================================================
-- Q3. What is the vote count and average rating for every restaurant?
-- Business use: quality benchmarking; feeds into restaurant ranking on the app.
-- ============================================================================
SELECT
    r.r_id,
    r.r_name,
    COUNT(*)                     AS votes,
    AVG(o.restaurant_rating)     AS avg_rating
FROM restaurants r
JOIN orders o
    ON r.r_id = o.r_id
WHERE o.restaurant_rating IS NOT NULL
GROUP BY r.r_id, r.r_name;


-- ============================================================================
-- Q4. Which food item is sold at the most restaurants?
-- Business use: identify the most universally-stocked / in-demand dish.
-- ============================================================================
SELECT
    f.f_id,
    f.f_name,
    COUNT(*) AS num_of_restaurants
FROM menu m
JOIN food f
    ON m.f_id = f.f_id
GROUP BY f.f_id, f.f_name
ORDER BY num_of_restaurants DESC
LIMIT 1;


-- ============================================================================
-- Q5. Which restaurant generated the most revenue in a given month? (May shown)
-- Business use: monthly performance leaderboard for partner restaurants.
-- ============================================================================
SELECT
    r.r_id,
    r.r_name,
    SUM(o.amount) AS revenue
FROM orders o
JOIN restaurants r
    ON o.r_id = r.r_id
WHERE MONTHNAME(o.date) = 'May'
GROUP BY r.r_id, r.r_name
ORDER BY revenue DESC;


-- ============================================================================
-- Q6. Which restaurants have total revenue above a given threshold (e.g. 2000)?
-- Business use: flag top-performing restaurants for partnership tiers / promotions.
-- ============================================================================
SELECT
    r.r_id,
    r.r_name,
    SUM(o.amount) AS revenue
FROM orders o
JOIN restaurants r
    ON o.r_id = r.r_id
GROUP BY r.r_id, r.r_name
HAVING revenue > 2000;


-- ============================================================================
-- Q7. Which customers have never placed an order?
-- Business use: target inactive / never-converted users for re-engagement campaigns.
-- ============================================================================
SELECT
    u.name
FROM users u
LEFT JOIN orders o
    ON u.user_id = o.user_id
WHERE o.order_id IS NULL;


-- ============================================================================
-- Q8. What did a specific customer order within a given date range?
-- Business use: customer support / order-history lookup.
-- ============================================================================
SELECT
    o.user_id,
    o.order_id,
    o.date,
    f.f_name
FROM orders o
JOIN order_details od
    ON o.order_id = od.order_id
JOIN food f
    ON od.f_id = f.f_id
WHERE o.user_id = 1
    AND o.date BETWEEN '2022-05-15' AND '2022-06-15'
ORDER BY MONTH(o.date);


-- ============================================================================
-- Q9. What is each customer's favorite (most-ordered) food item?
-- Business use: personalized recommendations / targeted promotions.
-- Technique: CTE + correlated subquery to find the max per customer.
-- ============================================================================
WITH fav_food AS (
    SELECT
        u.user_id,
        u.name,
        f.f_id,
        f.f_name,
        COUNT(*) AS num_of_orders
    FROM users u
    JOIN orders o
        ON u.user_id = o.user_id
    JOIN order_details od
        ON o.order_id = od.order_id
    JOIN food f
        ON od.f_id = f.f_id
    GROUP BY u.user_id, u.name, f.f_id, f.f_name
    ORDER BY num_of_orders DESC
)
SELECT *
FROM fav_food f1
WHERE num_of_orders = (
    SELECT MAX(num_of_orders)
    FROM fav_food f2
    WHERE f2.user_id = f1.user_id
);


-- ============================================================================
-- Q10. Which restaurant has the highest average price per dish?
-- Business use: identify premium / fine-dining restaurants on the platform.
-- ============================================================================
SELECT
    r.r_id,
    r.r_name,
    AVG(f.price) AS avg_price
FROM restaurants r
JOIN menu m
    ON r.r_id = m.r_id
JOIN food f
    ON m.f_id = f.f_id
GROUP BY r.r_id, r.r_name
ORDER BY avg_price DESC
LIMIT 1;


-- ============================================================================
-- Q11. What is each delivery partner's total compensation?
-- Formula: (num_deliveries * 100) + (1000 * avg_delivery_rating)
-- Business use: monthly/periodic payout calculation for delivery partners.
-- ============================================================================
SELECT
    dp.partner_id,
    dp.partner_name,
    (COUNT(*) * 100 + 1000 * AVG(o.delivery_rating)) AS compensation
FROM delivery_partner dp
JOIN orders o
    ON dp.partner_id = o.partner_id
GROUP BY dp.partner_id, dp.partner_name
ORDER BY compensation DESC;


-- ============================================================================
-- Q12. Which restaurants are purely vegetarian?
-- Business use: power a "Pure Veg" filter/badge on the app.
-- Technique: HAVING MIN(type) = MAX(type) = 'Veg' ensures every dish on the
-- menu is vegetarian — a restaurant with even one non-veg item is excluded.
-- ============================================================================
SELECT
    r.r_id,
    r.r_name
FROM restaurants r
JOIN menu m
    ON r.r_id = m.r_id
JOIN food f
    ON m.f_id = f.f_id
GROUP BY r.r_id, r.r_name
HAVING MIN(f.type) = 'Veg' AND MAX(f.type) = 'Veg';


-- ============================================================================
-- Q13. What is the min and max order value for every customer?
-- Business use: understand spending range per customer for segmentation.
-- ============================================================================
SELECT
    o.user_id,
    u.name,
    MIN(o.amount) AS min_order_value,
    MAX(o.amount) AS max_order_value
FROM orders o
JOIN users u
    ON o.user_id = u.user_id
GROUP BY o.user_id, u.name;
