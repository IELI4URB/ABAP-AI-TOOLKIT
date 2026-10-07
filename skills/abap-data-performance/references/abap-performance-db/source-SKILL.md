---
name: abap-performance-db
description: ABAP database performance best practices for both ECC/traditional DBs (Oracle, DB2, MSSQL, MaxDB) and S/4HANA/HANA in one skill. Use the SAP system info tool first to detect DB type, then apply the matching branch — ECC: minimize round-trips, buffer aggressively, keep SQL simple. HANA: push aggregations/joins/CASE/window functions down to SQL, use CDS/AMDP. Also covers shared rules: internal table type selection, string ops, authorization-check ordering, ALV, and parallel processing. Triggers: performance, slow query, ECC, HANA, S/4HANA, buffering, pushdown, CDS, AMDP, SELECT, database, Oracle, DB2, MaxDB, N+1, internal table.
argument-hint: '[ABAP code to optimize]'
user-invocable: true
disable-model-invocation: false
---

# ABAP Performance — Database Tuning (ECC & HANA)

SAP Help baseline: https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm

**Before using this skill:** Call the SAP system info tool to determine the DB type, then jump to the matching branch below. Do not apply HANA pushdown patterns on a traditional DB, or ECC-style buffering caution on HANA.

---

## Branch: ECC / Traditional Database (Oracle, DB2, MSSQL, MaxDB)

**Core philosophy:** Minimize database round-trips. Keep SQL simple — traditional DBs don't optimize complex expressions well. Buffer aggressively. Move complex logic to ABAP.

- Select only needed fields; never `SELECT *`. Always use a WHERE clause.
- Prefer JOINs over nested SELECTs, but keep JOINs to 3-4 tables max — traditional optimizers generate poor plans for larger JOINs. Split into two SELECTs if needed.
- Use `FOR ALL ENTRIES` when JOINs aren't possible; always check the driver table is not empty first (it removes duplicate result rows).
- Avoid subqueries, CASE expressions, and complex SQL functions in SELECT — fetch and process in ABAP instead.
- Be careful with `ORDER BY` on large result sets; sort in ABAP or use a SORTED table type instead if expensive.
- **Buffering is critical on ECC** (more so than HANA): know full/generic/single-record buffering types. Use `SELECT SINGLE` to hit the buffer — `UP TO 1 ROWS` bypasses it. JOINs, aggregates, `DISTINCT`, `GROUP BY`, `ORDER BY`, subqueries all bypass the buffer.
- For frequently accessed config data, consider an application-level cache (read once into an internal table) rather than repeated buffer hits.
- Check secondary indexes exist and that WHERE clauses match index field order — the ECC optimizer depends on this more than HANA does.

## Branch: S/4HANA / HANA Database

**Core philosophy:** Push data-intensive operations to the database. HANA is columnar in-memory, optimized for set-based operations. Keep ABAP for business logic, authorization, and exceptions.

**Code pushdown — push down to HANA:** aggregations (SUM/COUNT/AVG/MIN/MAX), filtering, sorting, JOINs (5+ tables is fine), string ops/arithmetic in SQL, CASE expressions, GROUP BY/HAVING, window functions (OVER/PARTITION BY), UNION/INTERSECT/EXCEPT.

**Keep in ABAP:** complex branchy business logic, authority checks/messages/exceptions, small datasets where pushdown overhead exceeds benefit, RFC/file-I/O-dependent operations.

**Avoid:** reading all rows to ABAP to filter/aggregate in loops; internal tables as intermediate storage for what one SQL statement can do; multiple sequential SELECTs that could be a single JOIN.

- Always use `@`-escaped host variables in SELECT.
- Use aggregate functions/GROUP BY, CASE expressions, and string functions (`CONCAT`, etc.) directly in SQL — let HANA calculate.
- **Prefer CDS views** for complex, reusable data models (joins, calculated fields, aggregations, associations, access control) — the primary pushdown mechanism.
- **AMDP** for very complex, HANA-only calculations (full SQLScript access) — not portable to other DBs, use only when the system is guaranteed to stay on HANA.
- Buffering matters less than on ECC (in-memory) but still reduces network round-trips for tiny lookups; same `SELECT SINGLE` vs `UP TO 1 ROWS` buffer rule applies.
- Before writing an ABAP loop that aggregates/filters/transforms, ask "can this be a single SQL statement instead?"
- Consider CDS access control (DCL) for row-level authorization built into the data model.

---

## Shared Rules (Both Branches)

**Internal table type selection** — the single biggest ABAP-side performance lever:
- **HASHED**: O(1) lookup — large tables, unique key, read-heavy, filled once.
- **SORTED**: O(log n) lookup — non-unique key, range access, incremental fill.
- **STANDARD**: O(n) unless sorted + binary search — small tables or sequential-only.
```abap
DATA materials TYPE HASHED TABLE OF mara WITH UNIQUE KEY matnr.
READ TABLE materials WITH TABLE KEY matnr = input INTO DATA(mat).
```
- Use `ASSIGNING FIELD-SYMBOL(<fs>)` for fastest loop processing (no data copy).
- Avoid nested loops O(n*m) — use a HASHED lookup table for the inner data instead.
- Use `FILTER #( ... )` for extracting subsets from SORTED/HASHED tables.
- Never SELECT the same data twice — read once into a HASHED/SORTED lookup table and reuse with `READ TABLE`, instead of `SELECT SINGLE` inside a loop.

**String operations:**
- Use string templates `| |`, not `CONCATENATE`.
- Avoid repeated concatenation in loops (quadratic reallocation) — build a string table and join once with `concat_lines_of( )`.

**Authorization checks:**
- Check authority **before** expensive data retrieval, never after:
```abap
AUTHORITY-CHECK OBJECT 'M_MATE_WRK' ID 'WERKS' FIELD plant.
IF sy-subrc <> 0. RAISE EXCEPTION NEW zcx_no_auth( ). ENDIF.
SELECT ... " now fetch data
```

**ALV / UI:** pass data by reference to avoid copying large tables; use `CL_SALV_TABLE` for read-only display; paginate large result sets (on S/4HANA, prefer Fiori/RAP over classical ALV).

**Parallel processing:** `aRFC` for independent long-running tasks, `SPTA` for parallelized mass processing, background jobs for very long tasks — each unit self-contained, no shared state. On HANA, check first whether a single efficient SQL statement outperforms parallelizing ABAP work.

---

## Anti-Patterns

| Anti-Pattern | Fix | Applies to |
|---|---|---|
| `SELECT *` | Select only needed fields | Both |
| SELECT in a LOOP | JOINs or `FOR ALL ENTRIES` | Both |
| Nested LOOPs on STANDARD tables | HASHED lookup for inner data | Both |
| String concat in loops with `&&` | Build string table, concat once (or push to SQL on HANA) | Both |
| `UP TO 1 ROWS` on buffered table | `SELECT SINGLE` to use buffer | Both |
| Authority check after data retrieval | Check before SELECT (or CDS DCL on HANA) | Both |
| Complex SQL (many JOINs, subqueries, CASE) | Simplify SQL, move logic to ABAP | ECC |
| WHERE clause not matching secondary index | Design WHERE to use the index | ECC |
| Aggregating in ABAP loops | Acceptable if data volume is small; else simple GROUP BY | ECC |
| Aggregating/filtering in ABAP loops | SUM/COUNT/AVG/WHERE pushed to SQL | HANA |
| Multiple SELECTs that could be one JOIN | Combine into a single JOIN | HANA |
| Complex ABAP transformations on large data | CDS view or AMDP | HANA |
| Ignoring CDS views for reusable models | Use CDS views | HANA |
