/* ============================================================================
   LAPTOP DATASET — SQL DATA CLEANING
   ----------------------------------------------------------------------------
   Raw laptop specification data (as scraped/exported from an e-commerce or
   Kaggle-style source) arrives with everything crammed into free-text
   columns — "8GB", "1.5Kg", "256GB SSD + 1TB HDD", "1920x1080 IPS Touch",
   "Intel Core i5 2.3GHz". None of that is queryable or chart-ready as-is.

   This script takes the raw `laptop` table and, working on a backup copy,
   turns it into a clean, typed, analysis-ready table by:
     1. Backing up the raw data before touching anything
     2. Fixing structural issues (bad column names, fully-null rows)
     3. Correcting data types (text → decimal/int)
     4. Standardizing inconsistent category labels (OS names)
     5. Splitting compound text columns into separate structured fields
        (GPU, CPU, screen resolution, memory)
     6. Dropping the now-redundant raw columns

   Author: Divya Chital
   ============================================================================ */

CREATE DATABASE cleaning;
USE cleaning;

SELECT * FROM laptop;


-- ============================================================================
-- 1. BACKUP — never clean the only copy of the raw data
-- ============================================================================
CREATE TABLE laptops LIKE laptop;

INSERT INTO laptops
SELECT * FROM laptop;

-- Sanity checks: row count and storage footprint of the working copy
SELECT * FROM laptops;

SELECT COUNT(*) FROM laptops;

SELECT DATA_LENGTH
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'cleaning'
  AND TABLE_NAME   = 'laptops';


-- ============================================================================
-- 2. STRUCTURAL CLEANUP
-- ============================================================================

-- The CSV export left a stray pandas index column named "Unnamed: 0" —
-- rename it to something meaningful.
ALTER TABLE laptops
RENAME COLUMN `Unnamed: 0` TO `index`;

SELECT * FROM laptops;

-- Drop any row that is completely empty across every meaningful column
-- (guards against blank rows carried over from the export).
DELETE FROM laptops
WHERE Company IS NULL
  AND TypeName IS NULL
  AND Inches IS NULL
  AND ScreenResolution IS NULL
  AND `Cpu` IS NULL
  AND Ram IS NULL
  AND `Memory` IS NULL
  AND `Gpu` IS NULL
  AND OpSys IS NULL
  AND Weight IS NULL
  AND Price IS NULL;


-- ============================================================================
-- 3. DATA TYPE CORRECTIONS
-- ============================================================================

-- Quick look at categorical spread before deciding how to type/clean them
SELECT DISTINCT Company  FROM laptops;
SELECT DISTINCT TypeName FROM laptops;
SELECT DISTINCT Inches   FROM laptops;

-- Screen size: text → decimal
ALTER TABLE laptops
MODIFY COLUMN Inches DECIMAL(10,1);

-- RAM: strip the "GB" suffix so it becomes a pure numeric value ("8GB" → 8)
UPDATE laptops
SET Ram = REPLACE(Ram, 'GB', '');

SELECT * FROM laptops;
DESCRIBE laptops;

ALTER TABLE laptops
MODIFY COLUMN Ram INT;

-- Weight: strip the "Kg" suffix ("1.5Kg" → 1.5)
-- NOTE: fixed a copy-paste bug from the original draft, which referenced the
-- Ram column instead of Weight here — that would have silently overwritten
-- Weight with Ram's numeric value.
UPDATE laptops
SET Weight = REPLACE(Weight, 'Kg', '');

ALTER TABLE laptops
MODIFY COLUMN Weight DECIMAL(10,1);

-- Price: round to whole currency units and store as an integer
UPDATE laptops
SET Price = ROUND(Price);

ALTER TABLE laptops
MODIFY COLUMN Price INT;


-- ============================================================================
-- 4. STANDARDIZING CATEGORICAL VALUES — Operating System
-- ============================================================================

-- Preview the mapping before committing it: collapse every macOS/Windows/
-- Linux variant (and "No OS") into a clean, consistent label set.
SELECT
    OpSys,
    CASE
        WHEN OpSys LIKE '%mac%'    THEN 'macos'
        WHEN OpSys LIKE 'window%'  THEN 'windows'
        WHEN OpSys LIKE '%linux%'  THEN 'linux'
        WHEN OpSys = 'No OS'       THEN 'N/A'
        ELSE 'other'
    END AS os_brand
FROM laptops;

UPDATE laptops
SET OpSys = CASE
    WHEN OpSys LIKE '%mac%'    THEN 'macos'
    WHEN OpSys LIKE 'window%'  THEN 'windows'
    WHEN OpSys LIKE '%linux%'  THEN 'linux'
    WHEN OpSys = 'No OS'       THEN 'N/A'
    ELSE 'other'
END;


-- ============================================================================
-- 5. FEATURE EXTRACTION — GPU
-- ============================================================================
-- Raw values look like "Intel HD Graphics 620" or "Nvidia GeForce GTX 1050".
-- Split into a queryable brand column; the free-text model name is dropped
-- later since brand alone drives the intended analysis.
ALTER TABLE laptops
ADD COLUMN gpu_brand VARCHAR(255) AFTER Gpu,
ADD COLUMN gpu_name  VARCHAR(255) AFTER gpu_brand;

UPDATE laptops
SET gpu_brand = SUBSTRING_INDEX(Gpu, ' ', 1);

UPDATE laptops
SET gpu_name = REPLACE(Gpu, gpu_brand, '');

ALTER TABLE laptops DROP COLUMN Gpu;


-- ============================================================================
-- 6. FEATURE EXTRACTION — CPU
-- ============================================================================
-- Raw values look like "Intel Core i5 7200U 2.5GHz". Split into brand,
-- model name, and clock speed as its own numeric field.
ALTER TABLE laptops
ADD COLUMN cpu_brand VARCHAR(255)  AFTER Cpu,
ADD COLUMN cpu_name  VARCHAR(255)  AFTER cpu_brand,
ADD COLUMN cpu_speed DECIMAL(10,1) AFTER cpu_name;

UPDATE laptops
SET cpu_brand = SUBSTRING_INDEX(Cpu, ' ', 1);

UPDATE laptops
SET cpu_speed = CAST(REPLACE(SUBSTRING_INDEX(Cpu, ' ', -1), 'GHz', '') AS DECIMAL(10,1));

UPDATE laptops
SET cpu_name = REGEXP_REPLACE(
    REPLACE(Cpu, CONCAT(cpu_brand, ' '), ''),
    ' [0-9.]+GHz$',
    ''
);

SELECT * FROM laptops;

ALTER TABLE laptops DROP COLUMN Cpu;

-- Trim the model name down to its first two tokens (e.g. "Core i5" rather
-- than the full "Core i5 7200U") for a cleaner, lower-cardinality field.
UPDATE laptops
SET cpu_name = SUBSTRING_INDEX(cpu_name, ' ', 2);


-- ============================================================================
-- 7. FEATURE EXTRACTION — Screen Resolution
-- ============================================================================
-- Raw values look like "IPS Panel Full HD / Touchscreen 1920x1080".
-- Extract numeric width/height and a boolean touchscreen flag.
ALTER TABLE laptops
ADD COLUMN resolution_width  INT AFTER ScreenResolution,
ADD COLUMN resolution_height INT AFTER resolution_width;

UPDATE laptops
SET resolution_width  = SUBSTRING_INDEX(SUBSTRING_INDEX(ScreenResolution, ' ', -1), 'x', 1),
    resolution_height = SUBSTRING_INDEX(SUBSTRING_INDEX(ScreenResolution, ' ', -1), 'x', -1);

ALTER TABLE laptops
ADD COLUMN touchscreen INT AFTER resolution_height;

UPDATE laptops
SET touchscreen = ScreenResolution LIKE '%Touch%';

ALTER TABLE laptops DROP COLUMN ScreenResolution;


-- ============================================================================
-- 8. FEATURE EXTRACTION — Memory
-- ============================================================================
-- Raw values look like "256GB SSD +  1TB HDD" or "128GB Flash Storage".
-- Split into storage type (SSD/HDD/Hybrid/Flash Storage), and separate
-- primary/secondary capacity fields, normalizing TB values to GB.
ALTER TABLE laptops
ADD COLUMN memory_type       VARCHAR(255) AFTER `Memory`,
ADD COLUMN primary_storage   INT          AFTER memory_type,
ADD COLUMN secondary_storage INT          AFTER primary_storage;

UPDATE laptops
SET memory_type = CASE
    WHEN `Memory` LIKE '%SSD%' AND `Memory` LIKE '%HDD%'   THEN 'Hybrid'
    WHEN `Memory` LIKE '%SSD%'                              THEN 'SSD'
    WHEN `Memory` LIKE '%HDD%'                              THEN 'HDD'
    WHEN `Memory` LIKE '%Flash Storage%' AND `Memory` LIKE '%HDD%' THEN 'Hybrid'
    WHEN `Memory` LIKE '%Flash Storage%'                    THEN 'Flash Storage'
    WHEN `Memory` LIKE '%Hybrid%'                           THEN 'Hybrid'
    ELSE NULL
END;

UPDATE laptops
SET primary_storage   = REGEXP_SUBSTR(SUBSTRING_INDEX(`Memory`, '+', 1), '[0-9]+'),
    secondary_storage = CASE
        WHEN `Memory` LIKE '%+%'
            THEN REGEXP_SUBSTR(SUBSTRING_INDEX(`Memory`, '+', -1), '[0-9]+')
        ELSE 0
    END;

SELECT * FROM laptops;

-- Normalize capacity units: values of 2 or less are treated as TB and
-- converted to GB (e.g. "1TB" parsed as 1 → 1024GB, "2TB" → 2048GB),
-- while values already in the hundreds/thousands are assumed to be GB.
SELECT
    primary_storage,
    CASE WHEN primary_storage <= 2 THEN primary_storage * 1024 ELSE primary_storage END
FROM laptops;

UPDATE laptops
SET primary_storage   = CASE WHEN primary_storage   <= 2 THEN primary_storage   * 1024 ELSE primary_storage   END,
    secondary_storage = CASE WHEN secondary_storage <= 2 THEN secondary_storage * 1024 ELSE secondary_storage END;


-- ============================================================================
-- 9. FINAL CLEANUP — drop the now-redundant raw / intermediate columns
-- ============================================================================
ALTER TABLE laptops DROP COLUMN `Memory`;
ALTER TABLE laptops DROP COLUMN gpu_name;
