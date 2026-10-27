# Database Optimization — Indexing, Query Analysis, Archival

## Objective

Optimize database performance through intelligent indexing, query analysis, and data lifecycle management. Prevent slowdowns as data grows.

## Prerequisites

- Strong ABAP SQL/CDS fundamentals and execution-plan literacy.
- Performance baseline knowledge (profiling, runtime analysis).
- Clean Core and landscape constraints for safe implementation choices.

## SAP Reference & Standards

- ABAP SQL Reference: https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- ABAP Cloud Data Modeling Guidance: https://help.sap.com/docs/abap-cloud
- SAP HANA SQL and Performance Guidance: https://help.sap.com/docs

## Scope Note (ABAP Cloud)

Treat direct DDL samples in this document as conceptual patterns. In ABAP Cloud projects, index and schema changes must be modeled through approved ABAP artifacts and platform-governed transport processes, not ad-hoc SQL in application code.

## Snippet Execution Labels

- `COMPILE-READY`: ABAP SQL query-shaping examples that can compile in ABAP Cloud with local type/table bindings.
- `PROJECT-ADAPTED`: executable intent but requires project data model, CDS, and artifact naming.
- `CONCEPTUAL`: database-engine illustration only (especially DDL/index examples).

Default rule in this module:
- Any snippet containing DDL (`CREATE INDEX`, `CREATE TABLE`, partitioning DDL) is `CONCEPTUAL` and not application-code executable in ABAP Cloud.

---

## Indexing Strategy

### Pattern 1: Index Selection

Snippet label: `CONCEPTUAL`

```sql
" GOOD: Index on frequently queried columns
" Table: TRAVELS (travel_id PK, status, agency_id, created_at, amount)

" Index 1: Primary key (automatic)
CREATE UNIQUE INDEX pk_travels ON travels (travel_id);

" Index 2: Status lookups (common query)
CREATE INDEX idx_travel_status ON travels (status);
" Enables: SELECT * FROM travels WHERE status = 'APPROVED'

" Index 3: Agency lookups
CREATE INDEX idx_travel_agency ON travels (agency_id);
" Enables: SELECT * FROM travels WHERE agency_id = '001'

" Index 4: Date range queries
CREATE INDEX idx_travel_date ON travels (created_at);
" Enables: SELECT * FROM travels WHERE created_at BETWEEN date1 AND date2

" Index 5: Combined query (most common)
CREATE INDEX idx_travel_agency_status ON travels (agency_id, status);
" Enables: SELECT * FROM travels WHERE agency_id = '001' AND status = 'APPROVED'
" Faster than separate indexes
```

**Indexing Decision Matrix**

| Column | Query Pattern | Index Needed? | Why |
|---|---|---|---|
| **travel_id** | Exact match | ✅ YES (PK) | Primary key, always indexed |
| **status** | = 'APPROVED' | ✅ YES | High selectivity, common filter |
| **created_at** | BETWEEN dates | ✅ YES | Range query, improves performance |
| **description** | LIKE '%Paris%' | ❌ NO | Low selectivity, text search better |
| **last_modified** | Just tracking | ❌ NO | Rarely used in WHERE clause |
| **customer_name** | Exact match | ✅ YES | High selectivity |

**Rule:** Index columns used in WHERE, JOIN, ORDER BY. Don't index every column.

### Pattern 2: Composite Index (Multi-Column)

Snippet label: `CONCEPTUAL`

```sql
" BAD: Separate indexes
CREATE INDEX idx_status ON travels (status);
CREATE INDEX idx_agency ON travels (agency_id);

" Query: SELECT * FROM travels WHERE agency_id = '001' AND status = 'APPROVED'
" Uses one index, has to filter result with other column (slow)

" GOOD: Composite index
CREATE INDEX idx_agency_status ON travels (agency_id, status);
" Query can use entire index (fast)

" Order matters: Put most selective column first
" agency_id = '001' → 100 rows
" status = 'APPROVED' → 5000 rows
" Composite: (agency_id, status) filters to 5 rows (best)
```

---

## Query Optimization

### Pattern 1: Execution Plan Analysis

Snippet label: `CONCEPTUAL`

```sql
" Before: Slow query (10 seconds)
SELECT * FROM travels
  WHERE status = 'PENDING'
    AND amount > 1000
    AND created_at > '20260101'
  INTO TABLE lt_travels.

" Analysis (ADT SQL Console → Explain Plan):
" - Full table scan (no index used!)
" - 500,000 rows examined
" - Result: 1,000 rows (0.2% selectivity)
" Problem: No index on (status, amount, created_at)

" Fix: Create composite index
CREATE INDEX idx_travel_filter ON travels (status, amount, created_at);

" After: Fast query (50ms)
" - Index used
" - 1,000 rows examined (matches result)
" - 200x faster!
```

### Pattern 2: Covering Index

Snippet label: `CONCEPTUAL`

```sql
" Query fetches specific columns
SELECT travel_id, status, amount FROM travels
  WHERE agency_id = '001'
  INTO TABLE lt_travels.

" Regular index on agency_id requires: index lookup → table lookup
" Covering index: index contains ALL needed columns (travel_id, status, amount, agency_id)
CREATE INDEX idx_travel_agency_covering ON travels 
  (agency_id) INCLUDE (travel_id, status, amount);

" Result: Index-only scan, never touches table (even faster!)
```

---

## Data Lifecycle Management

### Pattern 1: Archival Strategy

```abap
" As data grows, queries slow down
" Archive old, cold data to separate table

" Keep "hot" data (recent, frequently accessed)
DEFINE TABLE travels_active {
  travel_id UUID,
  created_at TIMESTAMP,
  ...
};

" Archive "cold" data (old, rarely accessed)
DEFINE TABLE travels_archive {
  travel_id UUID,
  created_at TIMESTAMP,
  ...
};

" Archival job (monthly)
METHODS archive_old_travels.
  " Move travels older than 2 years to archive
  INSERT INTO travels_archive
    SELECT * FROM travels_active
    WHERE created_at < DATE_SUB(TODAY, INTERVAL 2 YEAR);
  
  DELETE FROM travels_active
    WHERE created_at < DATE_SUB(TODAY, INTERVAL 2 YEAR);
  
  " Compress archive table
  ANALYZE TABLE travels_archive;
  OPTIMIZE TABLE travels_archive;
ENDMETHOD.

" Benefit:
" - travels_active: 1M rows (fast queries)
" - travels_archive: 50M rows (rarely queried)
" - Query on active table is 50x faster
```

### Pattern 2: Table Partitioning (Horizontal Splitting)

```abap
" Partition by date (for time-series data)
DEFINE TABLE travels (
  travel_id UUID,
  created_at TIMESTAMP,
  ...
) PARTITION BY RANGE (YEAR(created_at)) (
  PARTITION p2024 VALUES LESS THAN (2025),
  PARTITION p2025 VALUES LESS THAN (2026),
  PARTITION p2026 VALUES LESS THAN (2027),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

" Benefits:
" - Query for 2025 data only scans p2025 partition
" - Archival: Drop old partition (instant!)
" - Maintenance: Index on each partition separately

" Usage (automatic partition pruning)
SELECT * FROM travels WHERE created_at BETWEEN '2025-01-01' AND '2025-12-31'.
" Database only scans p2025, ignores p2024, p2026
```

---

## Query Patterns to Avoid

### Anti-Pattern 1: SELECT * (Fetch All Columns)

```abap
" BAD: Fetch 50 columns, use 3
SELECT * FROM travels INTO TABLE lt_travels.
" 50 columns × 1M rows = 500MB data transfer (slow)

" GOOD: Select only needed columns
SELECT travel_id, status, amount FROM travels
  INTO CORRESPONDING FIELDS OF TABLE lt_travels.
" 3 columns × 1M rows = 30MB (16x smaller!)
```

### Anti-Pattern 2: SELECT in Loop (N+1)

```abap
" BAD: N+1 queries
LOOP AT agencies INTO DATA(agency).
  SELECT * FROM travels WHERE agency_id = agency-id
    INTO TABLE agency-travels.
  " 1 query to fetch agencies → N queries for travels = N+1 total
ENDLOOP.

" GOOD: Single batch query
SELECT * FROM travels INTO TABLE lt_travels.

LOOP AT agencies INTO DATA(agency).
  agency-travels = FILTER #( lt_travels WHERE agency_id = agency-id ).
  " 1 query to fetch travels, N filter operations (way faster)
ENDLOOP.
```

### Anti-Pattern 3: Subquery Without Index

```abap
" BAD: Inefficient subquery
SELECT * FROM travels
  WHERE agency_id IN (SELECT id FROM agencies WHERE country = 'DE')
  INTO TABLE lt_travels.
" Database has to evaluate subquery for each row (slow)

" GOOD: Join or pre-fetch
SELECT * FROM travels AS t
  INNER JOIN agencies AS a ON t.agency_id = a.id
  WHERE a.country = 'DE'
  INTO TABLE lt_travels.
" Join is optimized by database (fast)

" Alternative: Pre-fetch
SELECT id FROM agencies WHERE country = 'DE'
  INTO TABLE lt_de_agencies.

SELECT * FROM travels
  WHERE agency_id IN (SELECT id FROM lt_de_agencies)
  INTO TABLE lt_travels.
" Evaluate once, reuse result (fast)
```

---

## Performance Monitoring

### Pattern 1: Slow Query Logging

```abap
" Log known business queries that exceed threshold
METHODS load_pending_travels.
  DATA(start_time) = cl_abap_runtime=>get_cpu_time( ).

  SELECT travel_id, status, amount
    FROM travels
    WHERE status = 'PENDING'
    INTO TABLE @DATA(lt_pending).
  
  DATA(duration) = cl_abap_runtime=>get_cpu_time( ) - start_time.
  
  IF duration > 1000.  " 1 second threshold
    logger->log(
      severity = 'WARN'
      message = 'Slow query detected'
      context = VALUE #(
        query_name = 'LOAD_PENDING_TRAVELS'
        duration_ms = duration
        threshold_exceeded_by = duration - 1000
        rows = lines( lt_pending )
      )
    );
  ENDIF.
ENDMETHOD.

" Monitor slow query log daily
" Identify patterns: same queries slow repeatedly?
" Add index to fix
```

### Pattern 2: Index Effectiveness Monitoring

```abap
" Which indexes are used vs which are unused?

" SAP Performance DB (SAPDBSTATS)
SELECT index_name, access_count FROM sapdbstats
  WHERE table_name = 'TRAVELS'
  ORDER BY access_count DESC.

" Indexes with 0 access: Remove (waste space)
" Indexes with low access: Maybe remove or combine

" Benefit: Keep only effective indexes, remove dead weight
```

---

## Database Optimization Checklist

- [ ] Primary key defined
- [ ] Frequently queried columns indexed (WHERE, JOIN, ORDER BY)
- [ ] Composite indexes for common multi-column filters
- [ ] Covering indexes for SELECT-only columns
- [ ] Execution plans reviewed (no full table scans)
- [ ] SELECT * avoided (specify needed columns)
- [ ] N+1 queries eliminated (batch fetch)
- [ ] Subqueries optimized (JOIN where possible)
- [ ] Archival strategy for old data
- [ ] Table partitioning for large, time-series tables
- [ ] Slow queries logged and monitored
- [ ] Unused indexes identified and removed
- [ ] Index maintenance scheduled (rebuild, defragment)
- [ ] Statistics up-to-date (helps optimizer)
- [ ] Regular ANALYZE/OPTIMIZE runs
