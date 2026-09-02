/* ============================================================================
   FLIGHTS DATASET — SQL CASE STUDY
   ----------------------------------------------------------------------------
   A domestic flights dataset (route, airline, schedule, and price) analyzed
   entirely in SQL — seasonality, pricing patterns, route durations, and
   time-of-day demand — after first engineering proper datetime fields out
   of raw date/time/duration text columns.

   Covers:
     1. Feature engineering — building real datetime & duration fields
     2. Time-based patterns (busiest month, costliest weekday, weekend volume)
     3. Route & duration analysis (longest routes, multi-day flights)
     4. Airline-level analysis (monthly/quarterly volume, longest flights)
     5. Stop-based duration comparison (non-stop vs. with-stop)
     6. Weekday × time-of-day demand and pricing grids

   Author: Divya Chital
   ============================================================================ */

USE flights;

SELECT * FROM flightsdata;


-- ============================================================================
-- 1. FEATURE ENGINEERING — Building Real Datetime Fields
-- ============================================================================
-- The raw table only has `date_of_journey` (date), `dep_time` (time as text),
-- and `duration` (free text like "2h 50m"). None of that supports arrival-time
-- or duration-based analysis directly, so we derive three new fields first:
--   - departure       : a true DATETIME combining date + departure time
--   - duration_mins    : duration converted to a single numeric minute value
--   - arrival          : departure + duration, giving a true arrival DATETIME

ALTER TABLE flightsdata ADD COLUMN departure DATETIME;

UPDATE flightsdata
SET departure = STR_TO_DATE(CONCAT(date_of_journey, ' ', dep_time), '%Y-%m-%d %H:%i');

ALTER TABLE flightsdata
ADD COLUMN duration_mins INTEGER,
ADD COLUMN arrival DATETIME;

-- Parses formats like "2h 50m", "2h", or "50m" into a single minute value
UPDATE flightsdata
SET duration_mins = CASE
    WHEN duration LIKE '%h%' THEN
        REPLACE(SUBSTRING_INDEX(duration, ' ', 1), 'h', '') * 60
        + CASE
            WHEN duration LIKE '%m' THEN REPLACE(SUBSTRING_INDEX(duration, ' ', -1), 'm', '')
            ELSE 0
          END
    ELSE REPLACE(duration, 'm', '')
END;

UPDATE flightsdata
SET arrival = DATE_ADD(departure, INTERVAL duration_mins MINUTE);

SELECT
    TIME(arrival) AS arrival_time,
    DATE(arrival)  AS arrival_date
FROM flightsdata;

-- How many flights actually cross midnight and land on a different date
-- than they departed on?
SELECT COUNT(*) AS overnight_flight_count
FROM flightsdata
WHERE DATE(departure) != DATE(arrival);


-- ============================================================================
-- 2. TIME-BASED PATTERNS
-- ============================================================================

-- Which month has the most flights scheduled?
SELECT
    MONTHNAME(date_of_journey) AS month,
    COUNT(*) AS freq_of_months
FROM flightsdata
GROUP BY MONTHNAME(date_of_journey)
ORDER BY freq_of_months DESC
LIMIT 1;

-- Which day of the week has the highest average ticket price?
SELECT
    DAYNAME(date_of_journey) AS weekday,
    AVG(price) AS avg_cost
FROM flightsdata
GROUP BY DAYNAME(date_of_journey)
ORDER BY avg_cost DESC
LIMIT 1;

-- How many IndiGo flights run each month?
SELECT
    MONTHNAME(date_of_journey) AS month,
    COUNT(*) AS num_of_flights
FROM flightsdata
WHERE airline = 'indigo'
GROUP BY MONTHNAME(date_of_journey);

-- Flights from Bangalore to Delhi departing between 10 AM and 2 PM
SELECT *
FROM flightsdata
WHERE source = 'Banglore'
  AND destination = 'Delhi'
  AND dep_time > '10:00:00'
  AND dep_time < '14:00:00';

-- Weekend flight volume out of Bangalore
SELECT COUNT(*) AS num_of_flights_on_weekend
FROM flightsdata
WHERE source = 'Banglore'
  AND DAYNAME(date_of_journey) IN ('Saturday', 'Sunday');


-- ============================================================================
-- 3. ROUTE & DURATION ANALYSIS
-- ============================================================================

-- Average flight duration for every source–destination pair
SELECT
    source,
    destination,
    TIME_FORMAT(SEC_TO_TIME(AVG(duration_mins) * 60), '%kh %im') AS avg_duration
FROM flightsdata
GROUP BY source, destination;

-- The single longest route in India by average duration
SELECT
    source,
    destination,
    AVG(duration_mins) AS avg_duration
FROM flightsdata
GROUP BY source, destination
ORDER BY avg_duration DESC
LIMIT 1;

-- All source–destination pairs averaging more than 3 hours in the air
SELECT
    source,
    destination,
    AVG(duration_mins) / 60 AS avg_duration
FROM flightsdata
GROUP BY source, destination
HAVING avg_duration > 3
ORDER BY avg_duration DESC;

-- All Air India flights from Delhi within a given date range
SELECT *
FROM flightsdata
WHERE airline = 'Air India'
  AND source = 'Delhi'
  AND DATE(departure) BETWEEN '2019-01-03' AND '2019-01-06';


-- ============================================================================
-- 4. AIRLINE-LEVEL ANALYSIS
-- ============================================================================

-- Quarter-wise flight volume per airline
SELECT
    airline,
    QUARTER(departure) AS quarter,
    COUNT(*) AS num_of_flights
FROM flightsdata
GROUP BY airline, QUARTER(departure);

-- Longest single flight operated by each airline
-- (fixed: originally sorted by the raw text `duration` column instead of
-- the numeric `duration_mins` used to compute max_duration, which would
-- have produced an incorrectly ordered result)
SELECT
    airline,
    MAX(duration_mins) AS max_duration
FROM flightsdata
GROUP BY airline
ORDER BY max_duration DESC;


-- ============================================================================
-- 5. STOP-BASED DURATION COMPARISON
-- ============================================================================

-- Average duration for non-stop flights vs. flights with one or more stops
WITH temp_table AS (
    SELECT
        *,
        CASE
            WHEN total_stops = 'non-stop' THEN 'non-stop'
            ELSE 'with-stop'
        END AS stop_type
    FROM flightsdata
)
SELECT
    stop_type,
    TIME_FORMAT(SEC_TO_TIME(AVG(duration_mins) * 60), '%kh %im') AS avg_time
FROM temp_table
GROUP BY stop_type;


-- ============================================================================
-- 6. WEEKDAY × TIME-OF-DAY GRIDS (Bangalore → Delhi)
-- ============================================================================
-- (fixed: the final time slot was mislabeled '6pm-12pm' in the original —
-- hours 18–23 correctly span 6pm to 12am)

-- Flight frequency by weekday and departure time slot
SELECT
    DAYNAME(departure) AS weekday,
    SUM(CASE WHEN HOUR(departure) BETWEEN 0  AND 5  THEN 1 ELSE 0 END) AS `12am-6am`,
    SUM(CASE WHEN HOUR(departure) BETWEEN 6  AND 11 THEN 1 ELSE 0 END) AS `6am-12pm`,
    SUM(CASE WHEN HOUR(departure) BETWEEN 12 AND 17 THEN 1 ELSE 0 END) AS `12pm-6pm`,
    SUM(CASE WHEN HOUR(departure) BETWEEN 18 AND 23 THEN 1 ELSE 0 END) AS `6pm-12am`
FROM flightsdata
WHERE source = 'Banglore'
  AND destination = 'Delhi'
GROUP BY DAYNAME(departure);

-- Average price by weekday and departure time slot
SELECT
    DAYNAME(departure) AS weekday,
    AVG(CASE WHEN HOUR(departure) BETWEEN 0  AND 5  THEN price ELSE NULL END) AS `12am-6am`,
    AVG(CASE WHEN HOUR(departure) BETWEEN 6  AND 11 THEN price ELSE NULL END) AS `6am-12pm`,
    AVG(CASE WHEN HOUR(departure) BETWEEN 12 AND 17 THEN price ELSE NULL END) AS `12pm-6pm`,
    AVG(CASE WHEN HOUR(departure) BETWEEN 18 AND 23 THEN price ELSE NULL END) AS `6pm-12am`
FROM flightsdata
WHERE source = 'Banglore'
  AND destination = 'Delhi'
GROUP BY DAYNAME(departure);
