# ABAP SQL Complete Reference — Syntax, Window Functions, AMDP

## Objective

Complete ABAP SQL syntax reference for ABAP Cloud, including all SELECT clauses, DML statements, window functions, AMDP, CDS table functions, and dynamic SQL patterns.

---

## ABAP Cloud SQL Constraints

| Feature | Status | Notes |
|---|---|---|
| `@` host variable prefix | MANDATORY | All literals/variables need `@` |
| `SELECT *` | Allowed | Discouraged — always project fields |
| `EXEC SQL` / `ENDEXEC` | FORBIDDEN | Not available in ABAP Cloud |
| `EXECUTE IMMEDIATE` | FORBIDDEN | HANA SQLScript only |
| Window functions (`OVER`) | ABAP SQL ONLY | NOT in CDS DDL |
| `FOR ALL ENTRIES` | Available | Prefer JOINs or subqueries |
| Dynamic WHERE `(lv_where)` | Available | Must validate with CL_ABAP_DYN_PRG |
| `INTO CORRESPONDING` | Available | Standard mapping |
| `OFFSET @n` | Available (7.51+) | REQUIRES `ORDER BY` |
| Client handling | Automatic | `USING CLIENT @sy-mandt` to override |

---

## SELECT — Full Syntax

```abap
SELECT [SINGLE] [DISTINCT]
  field1 [AS alias1],
  field2,
  expression AS computed_alias,
  aggregate_function( field ) AS agg_alias
  FROM data_source
  [INNER JOIN | LEFT OUTER JOIN | CROSS JOIN] other_source
    ON join_condition
  WHERE where_condition
  [GROUP BY field1, field2]
  [HAVING aggregate_condition]
  [ORDER BY field1 [ASCENDING | DESCENDING]]
  [OFFSET @lv_offset]
  [UP TO @lv_rows ROWS]
  INTO [TABLE] @target
  [APPENDING TABLE @target]
  [INDICATORS SET STRUCTURE @ind].
```

---

## JOIN Patterns

```abap
" INNER JOIN (only matching rows)
SELECT t~travel_id, t~description, b~booking_id, b~flight_date
  FROM ztravel AS t
  INNER JOIN zbooking AS b ON t~travel_id = b~travel_id
  INTO TABLE @DATA(lt_result).

" LEFT OUTER JOIN (all left rows, NULL for unmatched right)
SELECT t~travel_id, t~description, b~booking_id
  FROM ztravel AS t
  LEFT OUTER JOIN zbooking AS b ON t~travel_id = b~travel_id
  INTO TABLE @DATA(lt_all_travels).

" Multiple JOINs
SELECT t~travel_id, a~name AS agency_name, c~name AS customer_name
  FROM ztravel AS t
  INNER JOIN zagency AS a ON t~agency_id = a~agency_id
  LEFT OUTER JOIN zcustomer AS c ON t~customer_id = c~customer_id
  WHERE t~status = @lc_active
  INTO TABLE @DATA(lt_full).
```

---

## Subqueries

```abap
" EXISTS subquery (most performant for existence check)
SELECT * FROM ztravel AS t
  WHERE EXISTS ( SELECT 1 FROM zbooking AS b
                 WHERE b~travel_id = t~travel_id
                   AND b~flight_date > @sy-datum )
  INTO TABLE @DATA(lt_with_future_bookings).

" NOT EXISTS
SELECT * FROM ztravel AS t
  WHERE NOT EXISTS ( SELECT 1 FROM zbooking AS b
                     WHERE b~travel_id = t~travel_id )
  INTO TABLE @DATA(lt_no_bookings).

" IN subquery
SELECT * FROM zbooking
  WHERE travel_id IN ( SELECT travel_id FROM ztravel
                       WHERE agency_id = @lv_agency )
  INTO TABLE @DATA(lt_bookings).

" Scalar subquery (single value)
SELECT travel_id, total_price,
  ( SELECT AVG( total_price ) FROM ztravel ) AS avg_price
  FROM ztravel
  INTO TABLE @DATA(lt_with_avg).
```

---

## Aggregations

```abap
" Basic aggregations
SELECT agency_id,
  COUNT( * ) AS travel_count,
  SUM( total_price ) AS total_revenue,
  AVG( total_price ) AS avg_price,
  MIN( begin_date ) AS earliest,
  MAX( begin_date ) AS latest
  FROM ztravel
  GROUP BY agency_id
  HAVING COUNT( * ) > @lv_min_count
  ORDER BY total_revenue DESCENDING
  INTO TABLE @DATA(lt_agency_stats).

" COUNT DISTINCT
SELECT agency_id,
  COUNT( DISTINCT customer_id ) AS unique_customers
  FROM ztravel
  GROUP BY agency_id
  INTO TABLE @DATA(lt_distinct).
```

---

## Window Functions (ABAP SQL ONLY — NOT CDS DDL)

```abap
" ROW_NUMBER, RANK, DENSE_RANK
SELECT travel_id, agency_id, total_price,
  ROW_NUMBER( ) OVER( ORDER BY total_price DESC ) AS row_num,
  RANK( )       OVER( ORDER BY total_price DESC ) AS price_rank,
  DENSE_RANK( ) OVER( ORDER BY total_price DESC ) AS dense_rank
  FROM ztravel
  INTO TABLE @DATA(lt_ranked).

" Partition + Aggregate windows
SELECT travel_id, agency_id, total_price,
  SUM( total_price ) OVER( PARTITION BY agency_id ) AS agency_total,
  COUNT( * )         OVER( PARTITION BY agency_id ) AS agency_count,
  AVG( total_price ) OVER( PARTITION BY agency_id ) AS agency_avg
  FROM ztravel
  INTO TABLE @DATA(lt_partitioned).

" LAG / LEAD (previous/next row values)
SELECT travel_id, begin_date, total_price,
  LAG( total_price, 1 ) OVER( ORDER BY begin_date ) AS prev_price,
  LEAD( total_price, 1 ) OVER( ORDER BY begin_date ) AS next_price
  FROM ztravel
  WHERE agency_id = @lv_agency
  INTO TABLE @DATA(lt_sequential).

" FIRST_VALUE / LAST_VALUE
SELECT travel_id, agency_id, total_price,
  FIRST_VALUE( total_price ) OVER( PARTITION BY agency_id ORDER BY begin_date ) AS first_price,
  LAST_VALUE( total_price )  OVER( PARTITION BY agency_id ORDER BY begin_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) AS last_price
  FROM ztravel
  INTO TABLE @DATA(lt_first_last).

" Running total (cumulative sum)
SELECT travel_id, begin_date, total_price,
  SUM( total_price ) OVER( ORDER BY begin_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS running_total
  FROM ztravel
  INTO TABLE @DATA(lt_running).
```

**Available window functions:**
- **Aggregate:** `SUM`, `COUNT`, `AVG`, `MIN`, `MAX`
- **Ranking:** `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE`
- **Navigation:** `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE`, `NTH_VALUE`
- **Frame:** `ROWS BETWEEN x PRECEDING AND y FOLLOWING`, `UNBOUNDED PRECEDING`, `CURRENT ROW`, `UNBOUNDED FOLLOWING`

---

## DML Statements

```abap
" INSERT
INSERT INTO ztravel VALUES @( VALUE #(
  travel_id = lv_id
  agency_id = lv_agency
  status    = 'N'
  created_at = utclong_current( ) ) ).

" INSERT from SELECT
INSERT ztravel_archive FROM ( SELECT * FROM ztravel WHERE status = 'X' ).

" UPDATE
UPDATE ztravel SET status = @lv_new_status
  WHERE travel_id = @lv_id.

" UPDATE with calculation
UPDATE ztravel SET total_price = total_price * @lv_factor
  WHERE agency_id = @lv_agency.

" DELETE
DELETE FROM ztravel WHERE travel_id = @lv_id.

" DELETE with subquery
DELETE FROM zbooking WHERE travel_id NOT IN
  ( SELECT travel_id FROM ztravel ).

" MODIFY (upsert)
MODIFY ztravel FROM TABLE @lt_travels.
```

---

## FOR ALL ENTRIES

```abap
" Correct usage (check not initial!)
IF lt_keys IS NOT INITIAL.
  SELECT * FROM zbooking
    FOR ALL ENTRIES IN @lt_keys
    WHERE travel_id = @lt_keys-travel_id
    INTO TABLE @DATA(lt_bookings).
ENDIF.

" WARNING: If lt_keys is EMPTY, ALL rows are returned!
" Always check IS NOT INITIAL before FOR ALL ENTRIES.
```

**Prefer over FOR ALL ENTRIES:**
```abap
" Better: JOIN or IN subquery
SELECT * FROM zbooking
  WHERE travel_id IN ( SELECT travel_id FROM @lt_keys AS k )
  INTO TABLE @DATA(lt_bookings).
```

---

## AMDP (ABAP Managed Database Procedures)

```abap
CLASS zcl_travel_amdp DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES if_amdp_marker_hdb.

    CLASS-METHODS get_travel_analytics
      IMPORTING VALUE(iv_year) TYPE gjahr
      EXPORTING VALUE(et_result) TYPE tt_travel_analytics.

    CLASS-METHODS get_ranked_tf FOR TABLE FUNCTION ztf_travel_ranked.
ENDCLASS.

CLASS zcl_travel_amdp IMPLEMENTATION.
  METHOD get_travel_analytics BY DATABASE PROCEDURE
    FOR HDB LANGUAGE SQLSCRIPT
    OPTIONS READ-ONLY
    USING ztravel zagency.

    et_result = SELECT
      a.name AS agency_name,
      COUNT(*) AS travel_count,
      SUM(t.total_price) AS total_revenue,
      AVG(t.total_price) AS avg_price,
      ROW_NUMBER() OVER (ORDER BY SUM(t.total_price) DESC) AS revenue_rank
    FROM ztravel AS t
    INNER JOIN zagency AS a ON t.agency_id = a.agency_id
    WHERE YEAR(t.begin_date) = :iv_year
    GROUP BY a.name;
  ENDMETHOD.

  METHOD get_ranked_tf BY DATABASE FUNCTION
    FOR HDB LANGUAGE SQLSCRIPT
    OPTIONS READ-ONLY
    USING ztravel.

    RETURN SELECT
      travel_id,
      agency_id,
      total_price,
      ROW_NUMBER() OVER (PARTITION BY agency_id ORDER BY total_price DESC) AS rank
    FROM ztravel
    WHERE mandt = :p_client;
  ENDMETHOD.
ENDCLASS.
```

---

## CDS Table Function Definition

```sql
define table function ZTF_TravelRanked
  with parameters @Environment.systemField: #CLIENT
                  p_client : abap.clnt
  returns {
    travel_id   : travel_id;
    agency_id   : agency_id;
    total_price : amount;
    rank        : abap.int4;
  }
  implemented by method zcl_travel_amdp=>get_ranked_tf;
```

---

## Dynamic SQL (Safe Pattern)

```abap
" SAFE: Validate with CL_ABAP_DYN_PRG
DATA(lv_field) = cl_abap_dyn_prg=>check_column_name( lv_user_field ).
DATA(lv_table) = cl_abap_dyn_prg=>check_table_name_str( lv_user_table ).
DATA(lv_value) = cl_abap_dyn_prg=>check_whitelist_str(
  val = lv_user_input
  whitelist = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_' ).

DATA(lv_where) = |{ lv_field } = '{ lv_value }'|.
SELECT * FROM (lv_table)
  WHERE (lv_where)
  INTO TABLE @DATA(lt_result).

" UNSAFE — NEVER do this:
" SELECT * FROM (user_input) WHERE (user_input2) ...
" → SQL injection vulnerability!
```

---

## Pagination Pattern

```abap
" OFFSET requires ORDER BY — always!
DATA(lv_page) = 2.
DATA(lv_page_size) = 25.
DATA(lv_offset) = ( lv_page - 1 ) * lv_page_size.

SELECT travel_id, description, total_price
  FROM ztravel
  WHERE status = @lc_active
  ORDER BY travel_id
  OFFSET @lv_offset
  UP TO @lv_page_size ROWS
  INTO TABLE @DATA(lt_page).
```

---

## Useful Expressions

```abap
" CASE expression
SELECT travel_id,
  CASE status
    WHEN 'A' THEN 'Accepted'
    WHEN 'R' THEN 'Rejected'
    WHEN 'X' THEN 'Cancelled'
    ELSE 'Open'
  END AS status_text
  FROM ztravel
  INTO TABLE @DATA(lt_with_text).

" COALESCE (NULL handling)
SELECT travel_id,
  COALESCE( description, 'No Description' ) AS safe_desc
  FROM ztravel
  INTO TABLE @DATA(lt_coalesce).

" String functions
SELECT travel_id,
  CONCAT( first_name, CONCAT( ' ', last_name ) ) AS full_name,
  LENGTH( description ) AS desc_length,
  UPPER( status ) AS upper_status
  FROM ztravel
  INTO TABLE @DATA(lt_strings).

" Date functions
SELECT travel_id,
  DATS_DAYS_BETWEEN( begin_date, end_date ) AS duration_days,
  DATS_ADD_DAYS( begin_date, 7 ) AS week_later
  FROM ztravel
  INTO TABLE @DATA(lt_dates).

" Type casting
SELECT travel_id,
  CAST( total_price AS CHAR( 20 ) ) AS price_text
  FROM ztravel
  INTO TABLE @DATA(lt_cast).
```

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
