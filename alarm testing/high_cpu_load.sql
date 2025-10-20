SELECT cpu_stress(100000000); -- Use 100 million iterations for severe load
-- For even more severe load, increase the iteration number or run more sessions.

--  Step 3: Simulate High Memory (Run in **2-3 Concurrent Sessions**)

-- This query forces PostgreSQL to allocate substantial `work_mem` to sort and aggregate a massive dataset.

-- ```sql
-- This complex query maximizes sorting and hashing memory usage
SELECT
    random_int,
    COUNT(DISTINCT filler_data) -- Forces aggregation and unique check
FROM
    load_test_data
GROUP BY
    random_int
ORDER BY
    COUNT(DISTINCT filler_data) DESC
LIMIT 100;

--  Step 4: Simulate High Disk I/O (Run in **5-10 Concurrent Sessions**)

--  A. High Read I/O (Sequential Scans)

-- Run this query repeatedly in many sessions to force the database to read the massive table from disk, stressing the storage layer.

--  sql
-- Forces a full sequential scan and returns the row count
SELECT COUNT(*) FROM load_test_data;

--  B. High Write I/O (Dead Tuples/WAL)

-- Run this command repeatedly to stress the RDS's I/O provisioned IOPS limit. `UPDATE`s in PostgreSQL generate a lot of "dead tuples" and heavy WAL traffic (write I/O).

-- sql
-- Update the entire table in batches to generate high write I/O
UPDATE load_test_data SET random_int = random_int + 1;

---

-- ### When you are finished, be sure to run the `DROP TABLE` and `DROP FUNCTION` commands listed in the `CLEANUP COMMAND` section of the script to free up the allocated disk space. Good luck with your testing!