# ABAP SQL and AMDP — Complete Syntax Reference

> **Scope:** ABAP Cloud (BTP / S/4HANA Cloud / ABAP Platform 2023+).  
> All statements assume strict ABAP Cloud syntax rules (no EXEC SQL, no dynamic OPEN CURSOR without safeguards, no SELECT *).

---

## 1. ABAP Cloud SQL Constraints — Quick Reference Table

| Feature | Status in ABAP Cloud | Notes |
|---------|---------------------|-------|
| `@host variables` (`@lv_`, `@lt_`) | **Mandatory** | All literals in WHERE must use host variables |
| `EXEC SQL … ENDEXEC` | **Forbidden** | No native SQL passthrough |
| `EXECUTE IMMEDIATE` | **Forbidden** | No DDL at runtime |
| `SELECT *` | **Discouraged** (ATC warning) | Always list explicit fields |
| Window functions (`OVER(…)`) | **ABAP SQL only** | NOT available in CDS DDL views |
| Dynamic `WHERE` tokens | Requires `CL_ABAP_DYN_PRG` | Must whitelist-check every token |
| `FOR ALL ENTRIES IN` empty-table | **Bug** if no guard | Always check `IS NOT INITIAL` before FAE |
| `OPEN CURSOR` / `FETCH` | Allowed | Prefer SELECT … INTO TABLE for readability |
| `MODIFY` (upsert) | Allowed | INSERT OR UPDATE semantics |
| `INSERT … FROM TABLE` | Allowed | Bulk insert; check `sy-dbcnt` |
| Subqueries | Allowed | Scalar and table-valued; no correlated window |
| CTE (`WITH … AS ( SELECT … )`) | Allowed | Available since ABAP 7.57 |
| `OFFSET … ROWS` / `UP TO … ROWS` | Allowed | Pagination; requires `ORDER BY` |

---

## 2. SELECT Syntax Reference

### 2.1 SINGLE and DISTINCT

```abap
" Single row — fails silently (sy-subrc = 4) if not found
SELECT SINGLE OrderID, NetValue, PurchasingOrg
  FROM zpurchase_order
  WHERE OrderID = @lv_order_id
  INTO @DATA(ls_order).

IF sy-subrc <> 0.
  " Handle not found
ENDIF.

" Distinct values
SELECT DISTINCT PurchasingOrg
  FROM zpurchase_order
  WHERE CompanyCode = @lv_company_code
  ORDER BY PurchasingOrg
  INTO TABLE @DATA(lt_orgs).
```

### 2.2 INTO TABLE / APPENDING TABLE

```abap
" Full result set
SELECT OrderID, SupplierId, NetValue, Currency
  FROM zpurchase_order
  WHERE CompanyCode = @lv_bukrs
    AND OrderDate BETWEEN @lv_date_from AND @lv_date_to
  ORDER BY OrderDate DESCENDING
  INTO TABLE @DATA(lt_orders).

" Append to existing table (e.g. paging loop)
SELECT OrderID, NetValue
  FROM zpurchase_order
  WHERE ApprovalStatus = @lv_status
  ORDER BY OrderID
  OFFSET @lv_offset ROWS
  FETCH NEXT @lv_page_size ROWS ONLY
  APPENDING TABLE @lt_result.
```

### 2.3 JOIN Types

```abap
" INNER JOIN — only matched rows
SELECT ord~OrderID,
       ord~NetValue,
       sup~SupplierName,
       sup~Country
  FROM zpurchase_order  AS ord
  INNER JOIN zsupplier  AS sup
    ON ord~SupplierId = sup~SupplierId
  WHERE ord~PurchasingOrg = @lv_purch_org
  INTO TABLE @DATA(lt_result).

" LEFT OUTER JOIN — all orders, even without supplier master
SELECT ord~OrderID,
       ord~NetValue,
       sup~SupplierName
  FROM zpurchase_order AS ord
  LEFT OUTER JOIN zsupplier AS sup
    ON ord~SupplierId = sup~SupplierId
  WHERE ord~CompanyCode = @lv_bukrs
  INTO TABLE @DATA(lt_left).

" CROSS JOIN — rarely needed; produces Cartesian product
SELECT a~CurrencyCode, b~ExchangeRateType
  FROM tcurc AS a
  CROSS JOIN tcurv AS b
  INTO TABLE @DATA(lt_cross).
```

### 2.4 Subqueries

```abap
" Scalar subquery in SELECT list
SELECT OrderID,
       NetValue,
       ( SELECT COUNT(*)
           FROM zpurchase_order_item AS i
           WHERE i~OrderID = o~OrderID ) AS ItemCount
  FROM zpurchase_order AS o
  WHERE o~ApprovalStatus = 'APPROVED'
  INTO TABLE @DATA(lt_orders_with_count).

" EXISTS subquery in WHERE
SELECT OrderID, NetValue
  FROM zpurchase_order AS o
  WHERE EXISTS
    ( SELECT 1
        FROM zpurchase_order_item AS i
        WHERE i~OrderID = o~OrderID
          AND i~MaterialGroup = @lv_matgrp )
  INTO TABLE @DATA(lt_orders_with_item).

" IN subquery
SELECT SupplierID, SupplierName
  FROM zsupplier
  WHERE SupplierID IN
    ( SELECT SupplierId
        FROM zpurchase_order
        WHERE NetValue > @lv_threshold )
  INTO TABLE @DATA(lt_big_suppliers).
```

### 2.5 GROUP BY / HAVING / ORDER BY

```abap
SELECT PurchasingOrg,
       COUNT( * )          AS OrderCount,
       SUM( NetValue )     AS TotalValue,
       AVG( NetValue )     AS AvgValue,
       MAX( NetValue )     AS MaxValue,
       MIN( NetValue )     AS MinValue
  FROM zpurchase_order
  WHERE OrderDate >= @lv_date_from
  GROUP BY PurchasingOrg
  HAVING SUM( NetValue ) > @lv_min_total
  ORDER BY TotalValue DESCENDING
  INTO TABLE @DATA(lt_summary).
```

---

## 3. DML Statements

### 3.1 INSERT

```abap
" Single row
INSERT zpurchase_order FROM @ls_order.
IF sy-subrc <> 0.
  " Duplicate key or table error
  RAISE EXCEPTION TYPE cx_zpur_db_error
    MESSAGE e010(zpur_messages).
ENDIF.

" Bulk insert from internal table
INSERT zpurchase_order FROM TABLE @lt_orders.
DATA(lv_inserted) = sy-dbcnt.   " rows actually inserted
```

### 3.2 UPDATE

```abap
" Update with SET — efficient; does not require full row read
UPDATE zpurchase_order
  SET ApprovalStatus = @lv_new_status,
      ChangedAt      = @lv_timestamp,
      ChangedBy      = @sy-uname
  WHERE OrderID = @lv_order_id.

IF sy-dbcnt = 0.
  " Row not found
ENDIF.

" Bulk update from internal table (full row)
UPDATE zpurchase_order FROM TABLE @lt_orders.
```

### 3.3 DELETE

```abap
" Single row by key
DELETE zpurchase_order FROM @ls_order.

" Conditional bulk delete
DELETE FROM zpurchase_order
  WHERE ApprovalStatus = 'CANCELLED'
    AND ChangedAt < @lv_cutoff_date.
DATA(lv_deleted) = sy-dbcnt.
```

### 3.4 MODIFY (Upsert)

```abap
" INSERT if not exists, UPDATE if exists (by primary key)
MODIFY zpurchase_order FROM @ls_order.

" Bulk upsert
MODIFY zpurchase_order FROM TABLE @lt_orders.
```

---

## 4. Window Functions (ABAP SQL Only — NOT in CDS DDL)

> **Critical constraint:** Window functions (`OVER(…)`) are available in **ABAP SQL SELECT statements** only. They cannot be used in CDS DDL view definitions. To expose windowed calculations via CDS, use a **CDS Table Function** backed by an AMDP (see §8).

### 4.1 Ranking Functions

```abap
SELECT OrderID,
       PurchasingOrg,
       NetValue,
       ROW_NUMBER( )  OVER( PARTITION BY PurchasingOrg
                            ORDER BY NetValue DESCENDING ) AS RowNum,
       RANK( )        OVER( PARTITION BY PurchasingOrg
                            ORDER BY NetValue DESCENDING ) AS Rnk,
       DENSE_RANK( )  OVER( PARTITION BY PurchasingOrg
                            ORDER BY NetValue DESCENDING ) AS DenseRnk
  FROM zpurchase_order
  WHERE CompanyCode = @lv_bukrs
  INTO TABLE @DATA(lt_ranked).
```

### 4.2 Aggregate Window Functions

```abap
SELECT OrderID,
       PurchasingOrg,
       NetValue,
       SUM(  NetValue ) OVER( PARTITION BY PurchasingOrg ) AS OrgTotal,
       AVG(  NetValue ) OVER( PARTITION BY PurchasingOrg ) AS OrgAvg,
       COUNT(*)         OVER( PARTITION BY PurchasingOrg ) AS OrgCount,
       MAX(  NetValue ) OVER( PARTITION BY PurchasingOrg ) AS OrgMax,
       MIN(  NetValue ) OVER( PARTITION BY PurchasingOrg ) AS OrgMin
  FROM zpurchase_order
  INTO TABLE @DATA(lt_agg_win).
```

### 4.3 Lag / Lead / Frame Functions

```abap
SELECT OrderDate,
       NetValue,
       LAG(  NetValue, 1, 0 ) OVER( ORDER BY OrderDate ) AS PrevValue,
       LEAD( NetValue, 1, 0 ) OVER( ORDER BY OrderDate ) AS NextValue,
       FIRST_VALUE( NetValue ) OVER( ORDER BY OrderDate
                                     ROWS BETWEEN UNBOUNDED PRECEDING
                                              AND CURRENT ROW ) AS FirstInWindow,
       LAST_VALUE(  NetValue ) OVER( ORDER BY OrderDate
                                     ROWS BETWEEN CURRENT ROW
                                              AND UNBOUNDED FOLLOWING ) AS LastInWindow,
       SUM( NetValue ) OVER( ORDER BY OrderDate
                             ROWS BETWEEN 6 PRECEDING
                                      AND CURRENT ROW ) AS Rolling7DaySum
  FROM zpurchase_order
  WHERE PurchasingOrg = @lv_purch_org
  ORDER BY OrderDate
  INTO TABLE @DATA(lt_windowed).
```

---

## 5. FOR ALL ENTRIES

### 5.1 Standard Pattern with Mandatory Empty-Check Guard

```abap
" Step 1: Retrieve the driving table
SELECT OrderID, PurchasingOrg
  FROM zpurchase_order
  WHERE ApprovalStatus = 'SUBMITTED'
  INTO TABLE @DATA(lt_orders).

" Step 2: MANDATORY guard — FAE with empty driver table returns ALL rows!
IF lt_orders IS NOT INITIAL.
  SELECT OrderID, ItemID, MaterialID, Quantity, NetPrice
    FROM zpurchase_order_item
    FOR ALL ENTRIES IN @lt_orders
    WHERE OrderID = @lt_orders-OrderID
    INTO TABLE @DATA(lt_items).
ENDIF.
```

> **Bug pattern:** Omitting the `IS NOT INITIAL` check causes the inner SELECT to return **every row** in the table when the driving table is empty, because FAE with empty input is treated as "no filter". This is the #1 FAE mistake in ABAP.

### 5.2 Chunking for 5,000+ Entry Tables

For very large driving tables, the database IN-list can exceed limits. Chunk into batches:

```abap
CONSTANTS: lc_chunk_size TYPE i VALUE 5000.

DATA(lv_offset) = 0.
DATA(lv_total)  = lines( lt_driving_table ).

DO.
  DATA(lt_chunk) = lt_driving_table[ lv_offset + 1
                                     TO MIN( lv_offset + lc_chunk_size, lv_total ) ].

  IF lt_chunk IS INITIAL. EXIT. ENDIF.

  SELECT ItemID, OrderID, NetPrice
    FROM zpurchase_order_item
    FOR ALL ENTRIES IN @lt_chunk
    WHERE OrderID = @lt_chunk-OrderID
    APPENDING TABLE @lt_items.

  lv_offset += lc_chunk_size.
  IF lv_offset >= lv_total. EXIT. ENDIF.
ENDDO.
```

### 5.3 When to Prefer JOIN over FAE

| Scenario | Prefer |
|----------|--------|
| Both tables are database tables | `INNER JOIN` / `LEFT OUTER JOIN` |
| Driving table is an internal table from a previous SELECT | `FOR ALL ENTRIES IN` |
| Driving table has complex ABAP-computed rows | `FOR ALL ENTRIES IN` |
| Need aggregated columns across both tables | `JOIN` + `GROUP BY` |
| Driving table may be empty | `JOIN` (FAE requires empty-check guard) |

---

## 6. Dynamic SQL — Safe Pattern

Never concatenate user input directly into a dynamic WHERE clause. Use `CL_ABAP_DYN_PRG` to whitelist every token.

```abap
METHOD build_dynamic_where.
  " Allowed column names for this entity
  DATA(lt_allowed_columns) = VALUE string_table(
    ( `OrderID` ) ( `PurchasingOrg` ) ( `CompanyCode` )
    ( `ApprovalStatus` ) ( `SupplierId` ) ).

  DATA(lt_allowed_ops) = VALUE string_table(
    ( `=` ) ( `<>` ) ( `>` ) ( `<` ) ( `>=` ) ( `<=` ) ).

  " Validate caller-supplied column name and operator
  TRY.
      CL_ABAP_DYN_PRG=>check_whitelist_str(
        val       = iv_column_name
        whitelist = lt_allowed_columns ).

      CL_ABAP_DYN_PRG=>check_whitelist_str(
        val       = iv_operator
        whitelist = lt_allowed_ops ).
    CATCH cx_abap_not_in_whitelist INTO DATA(lx_wl).
      RAISE EXCEPTION TYPE cx_zpur_invalid_filter
        MESSAGE e020(zpur_messages)
        EXPORTING previous => lx_wl.
  ENDTRY.

  " Build safe dynamic WHERE token — value is always a host variable
  DATA(lv_where) = |{ iv_column_name } { iv_operator } @lv_filter_value|.

  SELECT OrderID, NetValue
    FROM zpurchase_order
    WHERE (lv_where)
    INTO TABLE @DATA(lt_result).
ENDMETHOD.
```

---

## 7. AMDP — ABAP-Managed Database Procedures

### 7.1 Full AMDP Class Structure

```abap
CLASS zcl_po_analytics_amdp DEFINITION PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Marker interface — mandatory for AMDP
    INTERFACES if_amdp_marker_hdb.

    TYPES:
      BEGIN OF ty_order_rank,
        order_id     TYPE zpurchase_order-orderid,
        purch_org    TYPE zpurchase_order-purchasingorg,
        net_value    TYPE zpurchase_order-netvalue,
        rank_in_org  TYPE i,
        org_total    TYPE zpurchase_order-netvalue,
      END OF ty_order_rank,
      tt_order_rank TYPE STANDARD TABLE OF ty_order_rank
                    WITH DEFAULT KEY.

    " AMDP method signature: only elementary/flat types + DB tables allowed
    CLASS-METHODS get_ranked_orders
      IMPORTING
        VALUE(iv_company_code) TYPE bukrs
        VALUE(iv_min_value)    TYPE netwr_ap
      EXPORTING
        VALUE(et_result)       TYPE tt_order_rank
      RAISING
        cx_amdp_error.

ENDCLASS.

CLASS zcl_po_analytics_amdp IMPLEMENTATION.

  METHOD get_ranked_orders
      BY DATABASE PROCEDURE
      FOR HDB
      LANGUAGE SQLSCRIPT
      OPTIONS READ-ONLY
      USING zpurchase_order.            " <-- declare all DB objects referenced

    " SQLScript implementation runs natively on HANA
    et_result = SELECT
        orderid          AS order_id,
        purchasingorg    AS purch_org,
        netvalue         AS net_value,
        RANK() OVER (
            PARTITION BY purchasingorg
            ORDER BY netvalue DESC
        )                AS rank_in_org,
        SUM( netvalue ) OVER (
            PARTITION BY purchasingorg
        )                AS org_total
      FROM zpurchase_order
      WHERE companycode = :iv_company_code
        AND netvalue    > :iv_min_value
      ORDER BY purchasingorg, rank_in_org;

  ENDMETHOD.

ENDCLASS.
```

### 7.2 Calling AMDP from ABAP

```abap
METHOD analyze_orders.
  TRY.
      zcl_po_analytics_amdp=>get_ranked_orders(
        EXPORTING
          iv_company_code = lv_bukrs
          iv_min_value    = 10000
        IMPORTING
          et_result       = DATA(lt_ranked) ).

      " Process results in ABAP
      LOOP AT lt_ranked INTO DATA(ls_row)
        WHERE rank_in_org <= 10.       " Top 10 per org
        " ... business logic
      ENDLOOP.

    CATCH cx_amdp_error INTO DATA(lx_amdp).
      RAISE EXCEPTION TYPE cx_zpur_analytics_error
        MESSAGE e030(zpur_messages)
        EXPORTING previous => lx_amdp.
  ENDTRY.
ENDMETHOD.
```

---

## 8. CDS Table Function — Exposing AMDP Results in CDS

### 8.1 CDS DDL Definition

```cds
@EndUserText.label: 'Ranked Purchase Orders by Org'
@ClientHandling.algorithm: #SESSION_VARIABLE   " Passes sy-mandt automatically
define table function ZPURCHASE_ORDER_RANKED
  with parameters
    @Environment.systemField: #CLIENT
    p_client       : abap.clnt,
    p_company_code : bukrs,
    p_min_value    : netwr_ap
returns {
  client      : abap.clnt;
  order_id    : orderid_ext;
  purch_org   : ekorg;
  net_value   : netwr_ap;
  rank_in_org : abap.int4;
  org_total   : netwr_ap;
}
implemented by method
  zcl_po_analytics_amdp=>get_ranked_orders_cds;
```

### 8.2 Corresponding AMDP Method for CDS Table Function

```abap
" The method name must match 'implemented by method' exactly (lowercase dot notation)
CLASS-METHODS get_ranked_orders_cds
  IMPORTING
    VALUE(clnt)          TYPE abap.clnt     " Injected by @ClientHandling
    VALUE(p_company_code) TYPE bukrs
    VALUE(p_min_value)    TYPE netwr_ap
  EXPORTING
    VALUE(result)         TYPE tt_order_rank   " 'result' is reserved name for TF
  RAISING
    cx_amdp_error.
```

> **Naming contract:** The exporting parameter for a CDS Table Function AMDP method must always be named `result`. CDS framework passes client automatically via `@ClientHandling.algorithm: #SESSION_VARIABLE`.

---

## 9. Aggregation Patterns

### 9.1 Standard Aggregation

```abap
SELECT PurchasingOrg,
       CompanyCode,
       COUNT( DISTINCT SupplierId ) AS SupplierCount,
       COUNT( * )                   AS OrderCount,
       SUM(   NetValue )            AS TotalValue,
       AVG(   NetValue )            AS AvgOrderValue,
       MAX(   NetValue )            AS LargestOrder,
       MIN(   NetValue )            AS SmallestOrder
  FROM zpurchase_order
  WHERE OrderDate >= @lv_year_start
    AND ApprovalStatus = 'APPROVED'
  GROUP BY PurchasingOrg, CompanyCode
  HAVING COUNT( * ) > 5
     AND SUM( NetValue ) > @lv_min_portfolio
  ORDER BY TotalValue DESCENDING
  INTO TABLE @DATA(lt_agg).
```

### 9.2 Common Table Expressions (CTEs)

```abap
" WITH clause — available from ABAP 7.57
WITH
  +approved_orders AS (
    SELECT OrderID, PurchasingOrg, NetValue, SupplierId
      FROM zpurchase_order
      WHERE ApprovalStatus = 'APPROVED'
        AND CompanyCode    = @lv_bukrs
  ),
  +supplier_totals AS (
    SELECT SupplierId,
           COUNT( * )      AS OrderCount,
           SUM( NetValue ) AS TotalSpend
      FROM +approved_orders
      GROUP BY SupplierId
  )
SELECT st~SupplierId,
       sup~SupplierName,
       st~OrderCount,
       st~TotalSpend
  FROM +supplier_totals AS st
  INNER JOIN zsupplier  AS sup
    ON st~SupplierId = sup~SupplierId
  WHERE st~TotalSpend > @lv_threshold
  ORDER BY st~TotalSpend DESCENDING
  INTO TABLE @DATA(lt_top_suppliers).
```

---

## 10. Performance Quick Reference

| Pattern | Performance Impact | Recommendation |
|---------|-------------------|----------------|
| `SELECT *` | Transfers unnecessary data | Always list fields explicitly |
| FAE without empty guard | Full table scan risk | Always guard with `IS NOT INITIAL` |
| FAE > 5,000 entries | DB IN-list overflow | Chunk into ≤ 5,000 batches |
| Correlated subquery in SELECT list | N+1 queries | Rewrite as JOIN or CTE |
| Missing `ORDER BY` with `OFFSET` | Non-deterministic pagination | Always pair `OFFSET` with `ORDER BY` |
| Window function in ABAP SQL on large table | HANA native; generally fast | Prefer AMDP for complex multi-window queries |
| Dynamic WHERE without whitelist | SQL injection risk + parse overhead | Use `CL_ABAP_DYN_PRG` + bind variables |
| `MODIFY` for high-volume upsert | Slower than INSERT when inserts are bulk-only | Use INSERT for known new rows |
