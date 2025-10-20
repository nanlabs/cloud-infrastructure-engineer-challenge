-- =================================================================
-- PostgreSQL RDS Load Simulation Script
-- This script contains functions and commands to simulate High CPU,
-- High Memory, and High Storage (Disk I/O) on an RDS instance.
-- WARNING: Running the execution commands below concurrently will
-- place significant stress on your RDS instance and may incur cost.
-- =================================================================

-- 1. SETUP: Create the table used for Storage/I/O and Memory testing.
-- The 'filler_data' column uses a large string to ensure rows consume more space.
CREATE TABLE load_test_data (
id BIGSERIAL PRIMARY KEY,
random_int INT NOT NULL,
filler_data TEXT DEFAULT repeat('A very long string to fill up space for disk I/O and storage simulation purposes. ', 100)
);

-- 2. STORAGE (DISK SPACE) & DATA GENERATION LOAD
-- This DO block inserts 1,000,000 rows. You can adjust the 'num_rows' variable
-- inside the loop to insert more (e.g., 5000000 for 5 million).
-- This will rapidly consume disk space and generate transaction logs (WAL).
DO $$
DECLARE
num_rows INT := 10000000; -- Change this value to increase/decrease the load
i INT := 1;
BEGIN
RAISE NOTICE 'Starting data insertion of % rows...', num_rows;
WHILE i <= num_rows LOOP
INSERT INTO load_test_data (random_int)
VALUES (floor(random() * 1000000 + 1)); -- Insert a random integer
i := i + 1;
END LOOP;
RAISE NOTICE 'Finished data insertion.';
END $$;

-- 3. HIGH CPU STRESS FUNCTION
-- This function performs repeated, non-cached mathematical operations (SQRT, MOD)
-- inside a loop to burn CPU cycles.
CREATE OR REPLACE FUNCTION cpu_stress(iterations INT DEFAULT 10000000)
RETURNS BIGINT AS $$
DECLARE
i INT := 0;
result NUMERIC := 1.0;
BEGIN
RAISE NOTICE 'Starting CPU stress test with % iterations...', iterations;
WHILE i < iterations LOOP
-- Perform computationally heavy, non-indexable math
result := MOD(result + CAST(SQRT(i) AS NUMERIC), 13.0);
i := i + 1;
END LOOP;
RAISE NOTICE 'CPU stress test finished.';
RETURN i;
END;
$$ LANGUAGE plpgsql;

-- 4. HIGH MEMORY STRESS QUERY (Requires large result set and sorting)
-- This query performs a non-indexed sort and aggregation over the large
-- 'load_test_data' table, forcing PostgreSQL to use temporary memory
-- (work_mem) for sorting before potentially resorting to disk.

-- NOTE: The actual command to run is provided in the execution guide below.
-- RDS instances often have 'work_mem' set dynamically, so this query will
-- maximize memory use for the session.

-- 5. STORAGE (DISK I/O) STRESS QUERY
-- This query forces a sequential scan over the entire large table repeatedly.
-- Running this multiple times in parallel will generate high read I/O.
-- We also run an aggressive UPDATE to generate "dead tuples" and high write I/O (WAL).

-- NOTE: The actual commands to run are provided in the execution guide below.

-- =================================================================
-- CLEANUP COMMAND (Run this when you are done with testing)
-- =================================================================
-- DROP TABLE IF EXISTS load_test_data;
-- DROP FUNCTION IF EXISTS cpu_stress(INT);
-- =================================================================