/* ============================================================================
   LAPTOP DATASET — EXPLORATORY DATA ANALYSIS (SQL)
   ----------------------------------------------------------------------------
   Follow-up to the data cleaning stage (see Laptopdata_cleaning_sql.sql):
   once the `laptops` table has typed, structured columns, this script
   explores it directly in SQL — no BI tool required.

   Covers:
     1. Quick data previews (head / tail / random sample)
     2. Univariate analysis on `price` (spread, missing values, outliers)
     3. ASCII histograms — visualizing distribution shape in pure SQL
     4. Univariate analysis on a categorical column (`Company`)
     5. Bivariate analysis (price vs. CPU speed, touchscreen, company)
     6. Missing value treatment — three imputation strategies compared
     7. Feature engineering — PPI, screen-size buckets, GPU one-hot preview

   Author: Divya Chital
   ============================================================================ */

USE cleaning;


-- ============================================================================
-- 1. QUICK PREVIEWS — head, tail, and a random sample
-- ============================================================================

-- Head: first 5 rows by index
SELECT * FROM laptops
ORDER BY `index` LIMIT 5;

-- Tail: last 5 rows by index
SELECT * FROM laptops
ORDER BY `index` DESC LIMIT 5;

-- Random sample: 5 arbitrary rows, useful for a quick sanity check on data quality
SELECT * FROM laptops
ORDER BY RAND() LIMIT 5;


-- ============================================================================
-- 2. UNIVARIATE ANALYSIS — Price
-- ============================================================================

-- Core summary stats: count, min, max, average
SELECT
    COUNT(price) AS price_count,
    MIN(price)   AS min_price,
    MAX(price)   AS max_price,
    AVG(price)   AS avg_price
FROM laptops;

-- Missing values check
SELECT COUNT(*) AS missing_price_count
FROM laptops
WHERE price IS NULL;


-- ============================================================================
-- 3. OUTLIER / DISTRIBUTION CHECK — ASCII Histograms
-- ============================================================================
-- SQL has no native charting, so we approximate a histogram using REPEAT()
-- to draw a bar of asterisks proportional to each price bucket's frequency.
-- Both orientations answer the same question: where is price mass concentrated,
-- and are there thin high-price buckets that suggest outliers?

-- Horizontal histogram: one row per bucket
SELECT
    t.bucket,
    REPEAT('*', COUNT(t.bucket) / 5) AS frequency
FROM (
    SELECT
        price,
        CASE
            WHEN price BETWEEN 0 AND 25000       THEN '0-25k'
            WHEN price BETWEEN 25000 AND 50000    THEN '25k-50k'
            WHEN price BETWEEN 50000 AND 75000    THEN '50k-75k'
            WHEN price BETWEEN 75000 AND 100000   THEN '75k-100k'
            WHEN price > 100000                   THEN '>100k'
        END AS bucket
    FROM laptops
) t
GROUP BY t.bucket;

-- Vertical histogram: one row overall, one column per bucket
SELECT
    REPEAT('*', SUM(CASE WHEN price BETWEEN 0 AND 25000     THEN 1 ELSE 0 END)) AS `0-25k`,
    REPEAT('*', SUM(CASE WHEN price BETWEEN 25000 AND 50000  THEN 1 ELSE 0 END)) AS `25k-50k`,
    REPEAT('*', SUM(CASE WHEN price BETWEEN 50000 AND 75000  THEN 1 ELSE 0 END)) AS `50k-75k`,
    REPEAT('*', SUM(CASE WHEN price BETWEEN 75000 AND 100000 THEN 1 ELSE 0 END)) AS `75k-100k`,
    REPEAT('*', SUM(CASE WHEN price > 100000                 THEN 1 ELSE 0 END)) AS `>100k`
FROM laptops;


-- ============================================================================
-- 4. UNIVARIATE ANALYSIS — Categorical (Company)
-- ============================================================================
-- How many listings does each brand have? Establishes which brands have
-- enough sample size to be meaningful in later group comparisons.
SELECT
    Company,
    COUNT(Company) AS num_listings
FROM laptops
GROUP BY Company;


-- ============================================================================
-- 5. BIVARIATE ANALYSIS
-- ============================================================================

-- Price vs. CPU speed: raw pairs, ready to be plotted as a scatter plot
-- in Excel/Power BI/Python to check for a positive relationship.
SELECT cpu_speed, price
FROM laptops;

-- Touchscreen adoption by brand
SELECT
    Company,
    SUM(CASE WHEN touchscreen = 1 THEN 1 ELSE 0 END) AS touchscreen_yes,
    SUM(CASE WHEN touchscreen = 0 THEN 1 ELSE 0 END) AS touchscreen_no
FROM laptops
GROUP BY Company;

SELECT * FROM laptops;

-- Categorical → Numerical: full price distribution per brand
-- (min/max shows range, avg shows positioning, std shows pricing consistency)
SELECT
    Company,
    MIN(price)  AS min_price,
    MAX(price)  AS max_price,
    AVG(price)  AS avg_price,
    STD(price)  AS price_std
FROM laptops
GROUP BY Company;


-- ============================================================================
-- 6. MISSING VALUE TREATMENT — three imputation strategies compared
-- ============================================================================
-- These are three alternative strategies for filling missing `price` values,
-- shown in increasing order of granularity. In practice you'd pick ONE —
-- running them back-to-back on the same table is a no-op after the first,
-- since no NULLs remain once it runs. They're kept side by side here to
-- compare the logic.

SELECT * FROM laptops
WHERE price IS NULL;

-- Strategy 1 — Global mean: simplest, but ignores brand/spec differences
-- entirely, so it can understate premium brands and overstate budget ones.
UPDATE laptops
SET price = (SELECT AVG(price) FROM laptops)
WHERE price IS NULL;

-- Strategy 2 — Company mean: fills each missing price with the average
-- price for that specific brand, a more realistic estimate than a flat
-- global average.
UPDATE laptops l1
SET price = (
    SELECT AVG(price) FROM laptops l2
    WHERE l2.Company = l1.Company
)
WHERE price IS NULL;

-- Strategy 3 — Company + CPU mean: the most granular estimate, matching
-- on both brand and processor model so the fill reflects a laptop's actual
-- performance tier, not just its badge.
UPDATE laptops l1
SET price = (
    SELECT AVG(price) FROM laptops l2
    WHERE l2.Company  = l1.Company
      AND l2.cpu_name = l1.cpu_name
)
WHERE price IS NULL;


-- ============================================================================
-- 7. FEATURE ENGINEERING
-- ============================================================================

-- PPI (pixels per inch): a single density metric that combines resolution
-- and screen size — more informative for comparing display quality than
-- resolution or screen size alone.
ALTER TABLE laptops ADD COLUMN ppi INTEGER;

UPDATE laptops
SET ppi = ROUND(
    SQRT(resolution_width * resolution_width + resolution_height * resolution_height) / inches
);

-- Screen size bucket: groups the continuous `inches` field into small/
-- medium/large categories, useful for simpler categorical comparisons.
ALTER TABLE laptops ADD COLUMN screen_size VARCHAR(255) AFTER inches;

UPDATE laptops
SET screen_size = CASE
    WHEN inches < 14.0                      THEN 'small'
    WHEN inches >= 14.0 AND inches < 17.0   THEN 'medium'
    ELSE 'large'
END;

SELECT * FROM laptops;

-- GPU brand one-hot preview: a SELECT-only preview of what one-hot encoded
-- GPU brand flags would look like, ready to be materialized as new columns
-- if needed for downstream modeling.
SELECT
    gpu_brand,
    CASE WHEN gpu_brand = 'Intel'   THEN 1 ELSE 0 END AS intel,
    CASE WHEN gpu_brand = 'AMD'     THEN 1 ELSE 0 END AS amd,
    CASE WHEN gpu_brand = 'nvidia'  THEN 1 ELSE 0 END AS nvidia,
    CASE WHEN gpu_brand = 'arm'     THEN 1 ELSE 0 END AS arm
FROM laptops;
