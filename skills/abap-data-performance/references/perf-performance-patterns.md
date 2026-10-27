# Performance Optimization for ABAP Cloud — Decision Guide & Patterns

## Objective

Optimize query performance, data transfer, memory usage, and response times without sacrificing maintainability or Clean Core compliance.

## Prerequisites

- Working knowledge of ABAP SQL/CDS query design.
- Architecture-layering baseline to avoid local optimizations that break boundaries.
- Database modeling context for index and lifecycle decisions.

## SAP Reference & Standards

- ABAP SQL Reference: https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- ABAP CDS Performance Notes: https://help.sap.com/docs/abap-cloud
- ABAP Cloud Development Guidelines: https://help.sap.com/docs/abap-cloud

---

## Performance Anti-Patterns & Fixes

### 1. N+1 Query Problem (CRITICAL)

**Anti-Pattern:**

```abap
" BAD: Loop with SELECT inside = N+1 queries
LOOP AT travels INTO DATA(travel).
  SELECT * FROM bookings WHERE travel_id = travel-id
    INTO TABLE travel-bookings.
  ENDLOOP.
" If 1000 travels → 1001 DB queries! 💥
```

**Problem:**
- 1 query to fetch travels → N queries for bookings = N+1 queries
- Each query has overhead (network, parsing, locking)
- Database struggles under load

**Solution: Batch Fetch**

```abap
" GOOD: One query for all travels, one for all bookings
SELECT * FROM travels INTO TABLE lt_travels.

" Fetch ALL bookings at once with WHERE IN clause
SELECT * FROM bookings 
  WHERE travel_id IN (SELECT id FROM travels)
  INTO TABLE lt_bookings.

" Map manually or use GROUP BY
LOOP AT lt_travels INTO DATA(travel).
  travel-bookings = FILTER #( lt_bookings WHERE travel_id = travel-id ).
ENDLOOP.
```

**When to Apply:**
- ✅ Query inside loop (obvious red flag)
- ✅ Fetching related data (bookings for each travel)
- ✅ Collection of 10+ items

**Decision Matrix**

| Scenario | Fix | Performance |
|---|---|---|
| 1-2 related items | Keep simple query | Negligible impact |
| 10-100 items with related data | Batch fetch (WHERE IN) | 10x faster |
| 1000+ items with complex joins | Use CDS view + pushdown | 100x faster |
| Real-time lookup (single item) | Single SELECT OK | No overhead |

---

### 2. CDS Pushdown — Push Logic to Database

**Anti-Pattern:**

```abap
" BAD: Fetch all, calculate in ABAP
SELECT * FROM travels INTO TABLE lt_travels.

LOOP AT lt_travels INTO DATA(travel).
  travel-total_cost = travel-base_price * travel-quantity * travel-country_factor.
  travel-is_expensive = travel-total_cost > 10000.
ENDLOOP.
" If 100K travels → loops in ABAP, slow!
```

**Solution: Move Calculation to CDS**

```abap
" GOOD: CDS does calculation in database
DEFINE VIEW zv_travel_cost AS
  SELECT FROM travels AS t
  JOIN countries AS c ON t.country_id = c.id
  {
    t.id,
    t.base_price,
    t.quantity,
    c.factor,
    (t.base_price * t.quantity * c.factor) AS total_cost,
    CASE WHEN (t.base_price * t.quantity * c.factor) > 10000 
         THEN 1 ELSE 0 END AS is_expensive
  };

" ABAP: Just read, no calculation needed
SELECT * FROM zv_travel_cost WHERE is_expensive = 1
  INTO TABLE lt_expensive_travels.
" Database returns only 1000 expensive travels, not 100K!
```

**When to Apply:**
- ✅ Heavy calculations in loop (multiply, aggregate)
- ✅ Complex filtering (WHERE clause logic)
- ✅ Joining multiple tables

**Performance Gain:** 50-100x faster for large datasets

---

### 3. Pagination — Don't Fetch All

**Anti-Pattern:**

```abap
" BAD: Fetch all 1M records, paginate in ABAP
SELECT * FROM travels INTO TABLE lt_all_travels.
" 1M records in memory! App crashes or memory exhaustion.

DATA(first_page) = lt_all_travels[ 1 THRU 20 ].
```

**Solution: Pagination at Database Level**

```abap
" GOOD: Database returns only requested page
METHODS get_travels_page IMPORTING page_number TYPE integer RETURNING VALUE(result) TYPE travel_table.
  DATA(page_size) = 20.
  DATA(offset) = (page_number - 1) * page_size.
  
  " OData: Caller uses $skip and $top
  SELECT * FROM travels
    OFFSET offset
    ROWS page_size
    INTO TABLE result.
ENDMETHOD.

" API usage: /odata/Travels?$skip=40&$top=20
" Returns only 20 records, not all 1M
```

**When to Apply:**
- ✅ List views, reports (10K+ records possible)
- ✅ Export/import operations (batch in chunks of 100-1000)
- ✅ API endpoints returning collections

**Performance Gain:** Prevents memory exhaustion, response time consistent

---

### 4. Field Projection — Select Only Needed Columns

**Anti-Pattern:**

```abap
" BAD: SELECT * = fetch 50 columns, use only 3
SELECT * FROM travels INTO TABLE lt_travels.
" 50 columns × 100K records = huge data transfer (50MB+)

LOOP AT lt_travels INTO DATA(travel).
  WRITE travel-id.
  WRITE travel-status.
  WRITE travel-total_cost.
ENDLOOP.
```

**Solution: Select Only Required Fields**

```abap
" GOOD: Select only 3 needed columns
SELECT id, status, total_cost FROM travels
  INTO CORRESPONDING FIELDS OF TABLE lt_travels.
" 3 columns × 100K records = 1MB (50x smaller!)
```

**When to Apply:**
- ✅ Fetching 100+ records
- ✅ Network-bound operation (OData, REST)
- ✅ Report generation, export

**Decision Matrix**

| Count | All Columns | Projected | Gain |
|---|---|---|---|
| 1-10 | OK | Overkill | Negligible |
| 100 | Slow | Good | 10x |
| 1K | Bad | Good | 30x |
| 10K | Very bad | Good | 50x |

---

### 5. Caching — Avoid Repeated Queries

**Anti-Pattern:**

```abap
" BAD: Query same data repeatedly in request
CLASS zcl_travel_service.
  METHODS process_travels.
    LOOP AT travels INTO DATA(travel).
      DATA(country) = read_country( travel-country_id ).  " Queries DB every loop!
      travel-country_name = country-name.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

**Solution: Cache Within Request**

```abap
" GOOD: Fetch once, reuse
METHODS process_travels.
  " Fetch all countries at start
  SELECT * FROM countries INTO TABLE lt_countries.
  
  LOOP AT travels INTO DATA(travel).
    DATA(country) = lt_countries[ country_id = travel-country_id ].
    travel-country_name = country-name.
  ENDLOOP.
ENDMETHOD.

" Performance: 1 query for 1000 travels, not 1000 queries!
```

**Caching Levels**

| Level | Scope | Duration | Use Case |
|---|---|---|---|
| **In-Memory (local)** | Single request | Request lifetime | Lookup tables, reference data |
| **Session Cache** | Single user | Session lifetime | User preferences, permissions |
| **Application Cache** | All users | Process lifetime | Static config, master data |
| **Database Cache** | All systems | Depends | (Managed by SAP) |

**When to Apply:**
- ✅ Lookup tables (countries, status values)
- ✅ Reference data queried multiple times
- ✅ Read-heavy, write-rare data

**Caution:** Cache invalidation is hard. Don't cache:
- ❌ Frequently changing data
- ❌ Large datasets (entire travel table)
- ❌ Sensitive data (passwords, PII)

---

## Query Optimization Patterns

### Pattern 1: CDS View with Calculated Fields

```abap
" Define calculation once in CDS, reuse everywhere
DEFINE VIEW zv_travel_summary AS
  SELECT FROM travels AS t
  JOIN agencies AS a ON t.agency_id = a.id
  {
    t.id,
    t.status,
    t.base_price,
    COUNT(*) OVER (PARTITION BY t.agency_id) AS travel_count_by_agency,
    SUM(t.base_price) OVER (PARTITION BY t.agency_id) AS total_revenue_by_agency,
    ROW_NUMBER() OVER (ORDER BY t.base_price DESC) AS price_rank,
    CASE WHEN t.status = 'APPROVED' THEN 1 ELSE 0 END AS is_approved
  };

" Usage: All calculations already done
SELECT * FROM zv_travel_summary WHERE is_approved = 1
  INTO TABLE lt_approved_travels.
```

### Pattern 2: Pre-Aggregation

```abap
" BAD: Calculate totals in ABAP
SELECT * FROM travels INTO TABLE lt_travels.

DATA(total_amount) = 0.
LOOP AT lt_travels INTO DATA(travel).
  total_amount += travel-amount.
ENDLOOP.

" GOOD: Database does aggregation
SELECT SUM(amount) AS total_amount FROM travels
  INTO total_amount.
```

### Pattern 3: Lazy Loading (For Large Related Data)

```abap
" BAD: Load all relationships eagerly
SELECT * FROM travels INTO TABLE lt_travels.
SELECT * FROM bookings WHERE travel_id IN (SELECT id FROM travels)
  INTO TABLE lt_bookings.  " Load all, even if user views only 1 travel

" GOOD: Load only when needed (lazy loading)
CLASS zcl_travel.
  PRIVATE SECTION.
    DATA bookings TYPE bookings_table.
    DATA bookings_loaded TYPE abap_bool VALUE abap_false.
  PUBLIC SECTION.
    METHODS get_bookings RETURNING VALUE(result) TYPE bookings_table.
ENDCLASS.

CLASS zcl_travel IMPLEMENTATION.
  METHOD get_bookings.
    IF bookings_loaded = abap_false.
      SELECT * FROM bookings WHERE travel_id = me->id
        INTO TABLE me->bookings.
      bookings_loaded = abap_true.
    ENDIF.
    result = me->bookings.
  ENDMETHOD.
ENDCLASS.
```

---

## Non-Query Performance Patterns

### Pattern 1: Bulk Operations Instead of Loop

```abap
" BAD: Update in loop (100 separate SQL statements)
LOOP AT travels INTO DATA(travel).
  UPDATE travels SET status = 'PROCESSED'
    WHERE id = travel-id.
ENDLOOP.

" GOOD: Single bulk update
UPDATE travels SET status = 'PROCESSED'
  WHERE status = 'PENDING'.
```

### Pattern 2: String Concatenation in Loop

```abap
" BAD: String concatenation in loop is slow
DATA result TYPE string.
LOOP AT items INTO DATA(item).
  result = result && item-value && ','.  " String rebuild every iteration!
ENDLOOP.

" GOOD: Use internal table buffer, concatenate once
DATA result_parts TYPE string_table.
LOOP AT items INTO DATA(item).
  APPEND item-value TO result_parts.
ENDLOOP.
DATA(result) = CONCAT_LINES_OF( result_parts SEP ',' ).
```

### Pattern 3: Asynchronous Processing for Heavy Operations

```abap
" BAD: Synchronous export blocks user
METHODS export_travels.
  " Generate 1M rows → takes 10 minutes, user waits
  DATA(file) = generate_large_export( ).
  download_file( file ).
ENDMETHOD.

" GOOD: Queue for background processing
METHODS export_travels.
  " Queue job, return immediately
  DATA(job_id) = queue_export_job( ).
  RETURN job_id.  " User gets job ID, continues working
  
  " Background job runs asynchronously
  " Notify user when done via notification
ENDMETHOD.
```

---

## Performance Testing & Monitoring

### Rule 1: Measure Before Optimizing

```abap
" GOOD: Profile your code to find bottlenecks
DATA(start_time) = cl_abap_runtime=>get_cpu_time( ).

" Code under test
SELECT * FROM travels INTO TABLE lt_travels.

DATA(elapsed) = cl_abap_runtime=>get_cpu_time( ) - start_time.
IF elapsed > 1000.  " 1 second
  LOG-write( severity = 'WARNING'
    message = |Slow query: { elapsed }ms for { lines( lt_travels ) } records| ).
ENDIF.
```

### Rule 2: Set Performance Benchmarks

| Operation | Acceptable Time | Alert Threshold |
|---|---|---|
| **Single row fetch** | <50ms | >100ms |
| **List (100 rows)** | <200ms | >500ms |
| **List (1K rows)** | <500ms | >1s |
| **Export (10K rows)** | <5s | >10s |
| **Batch operation (1K updates)** | <2s | >5s |

### Rule 3: Use Database Explain Plan

```abap
" Before optimizing, check execution plan
" ADT → SQL Console → Explain Plan
SELECT * FROM travels WHERE status = 'PENDING' AND amount > 1000.

" Database shows:
" - Index used? (GOOD)
" - Full table scan? (BAD, add index)
" - Rows examined? (Should be small)
" - Filtering power? (Should be high)
```

---

## Performance Checklist

- [ ] No N+1 queries (loop with SELECT inside)
- [ ] CDS pushdown used for calculations
- [ ] Pagination implemented for collections (OData `$skip`/`$top`)
- [ ] Field projection: SELECT only needed columns
- [ ] Caching used for lookup tables
- [ ] Bulk operations instead of loops
- [ ] Asynchronous processing for heavy workloads
- [ ] Query execution plan reviewed (no full scans)
- [ ] Performance monitored (logging for >1s queries)
- [ ] Benchmarks defined and tracked

---

## Decision Matrix: When to Optimize

| Scenario | Action | Effort | Impact |
|---|---|---|---|
| **New feature, simple query** | Not yet | N/A | Optimize if >1s |
| **List report, 10K rows** | Use pagination + projection | Low | High (prevents OOM) |
| **Calculation in loop** | CDS pushdown | Medium | 50-100x faster |
| **Lookup in loop** | Cache in memory | Low | 10x faster |
| **Slow response (>5s)** | Profile + fix | High | Critical |
| **User reports slowness** | Investigate with SQL plan | High | Must fix |

**Key Rule:** **Don't optimize prematurely, but don't ignore obvious patterns (N+1, SELECT *).**
