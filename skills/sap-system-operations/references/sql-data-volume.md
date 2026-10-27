# SQL and Data Volume Issues — Production Resolution Guide

> **Scope:** ABAP SQL & data-volume production issues — root causes, diagnosis steps, fix patterns, and prevention rules.
> **Applies to:** SAP BTP ABAP Environment (Public Cloud ☁️), S/4HANA Private Cloud 🔒, S/4HANA On-Premise ⚙️

---

## §1 — Large Range / IN Clause Overflow

**Exception / Symptom:** `CX_SY_SQL_TOO_MANY_IN_VALUES` or `CX_SY_OPEN_SQL_DB`
**Landscapes:** ☁️ Public | 🔒 Private | ⚙️ OnPrem

### Root Cause
ABAP translates `SELECT … WHERE field IN @lt_range` into a SQL `IN (…)` predicate; SAP HANA enforces a hard limit of approximately 32,767 values per `IN` list, while older databases such as MaxDB cap out near 1,000. When an ALV selection screen, an uncontrolled range table, or a business process feeds more entries than the database allows, the Open SQL layer raises a short dump before a single row is returned.

> **Real-world incident example:** An ALV selection screen fed **77K+** entries into `WHERE field IN @lt_range`, which triggered `CX_SY_SQL_TOO_MANY_IN_VALUES` in production. Treat any unbounded selection-driven range table as high risk and apply chunking before execution.

### Diagnosis

| Step | Action | ☁️ Public (Fiori App) | ⚙️ OnPrem (T-Code) |
|------|--------|-----------------------|---------------------|
| 1 | Open the runtime error | *ABAP Runtime Errors* Fiori app (F2963) → filter by user / date | `ST22` → select today's dumps |
| 2 | Identify dump class | Look for `CX_SY_SQL_TOO_MANY_IN_VALUES` or `CX_SY_OPEN_SQL_DB` in the *Exception* field | Same class name in the short dump header |
| 3 | Read the error text | Long text will say **"too many values in IN predicate"** or **"maximum number of IN-values exceeded"** | Same text in `ST22` long text |
| 4 | Find the offending statement | Source line shown in *Active Calls / Call Stack* section | Source line + call stack in `ST22` |
| 5 | Measure range size | Add temporary `WRITE / lv_count` log before the `SELECT` | Use `ST05` SQL Trace to see the generated SQL and count literal values |

### Fix Pattern

#### Option A — Package (Chunk) Processing

```abap
CONSTANTS: lc_chunk_size TYPE i VALUE 5000.

DATA: lt_all_keys  TYPE TABLE OF matnr,
      lt_chunk     TYPE TABLE OF matnr,
      lt_result    TYPE TABLE OF mara,
      lt_all_mara  TYPE TABLE OF mara.

" Populate lt_all_keys (may contain 100K+ entries)
" ... fill from upstream source ...

DATA(lv_total) = lines( lt_all_keys ).
DATA(lv_offset) = 0.

WHILE lv_offset < lv_total.

  DATA(lv_from) = lv_offset + 1.                      " 1-based
  DATA(lv_to)   = nmin( val1 = lv_offset + lc_chunk_size val2 = lv_total ).

  " Build the chunk by copying a row range
  CLEAR lt_chunk.
  APPEND LINES OF lt_all_keys FROM lv_from TO lv_to TO lt_chunk.

  IF lt_chunk IS NOT INITIAL.
    SELECT matnr, mtart, mbrsh
      FROM mara
      FOR ALL ENTRIES IN @lt_chunk
      WHERE matnr = @lt_chunk-table_line
      INTO TABLE @lt_result.

    APPEND LINES OF lt_result TO lt_all_mara.
    CLEAR lt_result.
  ENDIF.

  lv_offset = lv_offset + lc_chunk_size.

ENDWHILE.
```

> **Why 5,000?** Keeps well below HANA's ~32K limit *and* below MaxDB's 1K limit when using the same codebase across landscapes.

#### Option B — EXISTS Subquery (avoids IN list entirely)

Use when the filter set lives in a transparent table you can reference:

```abap
" Instead of:
SELECT matnr, mtart FROM mara
  WHERE matnr IN @lt_filter_keys
  INTO TABLE @DATA(lt_result_bad).

" Use an EXISTS subquery — no IN list generated:
SELECT m~matnr, m~mtart
  FROM mara AS m
  WHERE EXISTS (
    SELECT 1 FROM zmy_filter_keys AS f
    WHERE f~matnr = m~matnr
  )
  INTO TABLE @DATA(lt_result_good).
```

> *Prerequisite:* The filter keys must be persisted in a DB table (`zmy_filter_keys`) or a CDS-exposed entity. Suitable for batch jobs that pre-populate the filter set.

### Landscape Notes

| Landscape | Specific Behaviour | Extra Steps |
|-----------|--------------------|-------------|
| ☁️ Public Cloud (HANA) | Hard IN-list limit ~32K; short dump is `CX_SY_SQL_TOO_MANY_IN_VALUES` | Chunk at 5,000. No access to DB config. |
| 🔒 Private Cloud (HANA) | Same HANA limit; system may run on HANA scale-out | Chunk at 5,000. Basis can confirm exact limit via HANA Studio. |
| ⚙️ OnPrem (MaxDB / other) | MaxDB limit is ~1,000; some Oracle/DB2 configs also restrict | **Always chunk at 1,000 if MaxDB possible** in the landscape. Verify via `ST05`. |

### Prevention
- **Count before SELECT:** `IF lines( lt_range ) > 5000. " package it ENDIF.`
- **Code review rule:** Any `SELECT … WHERE field IN @lt_xxx` where `lt_xxx` is filled from a parameter, ALV screen, or upstream table → mandatory package-processing pattern.
- **Static check:** Use the extended program check (tx `SLIN`) / ATC Performance checks to flag unbounded range / IN-list usage; add a custom ATC check if your variant lacks one.
- **ALV selection screens:** Wrap `SELECT-OPTIONS` ranges in a count guard in the `START-OF-SELECTION` event.

---

## §2 — FOR ALL ENTRIES with Empty Driver Table

**Exception / Symptom:** No exception raised — query silently reads the **entire** target table, producing millions of unexpected rows; a subsequent `TSV_TNEW_PAGE_ALLOC_FAILED` memory dump may follow, or business logic operates on completely wrong data.
**Landscapes:** ☁️ Public | 🔒 Private | ⚙️ OnPrem

### Root Cause
`FOR ALL ENTRIES IN` is ABAP Open SQL syntactic sugar that rewrites the query into one or more `IN (…)` predicates at runtime. When the driver table is **empty**, the ABAP kernel intentionally removes the `WHERE` clause derived from the driver table and **reads every row** of the target table. This is documented behaviour, not a bug — but it is a perennial source of production incidents. The resulting internal table can be hundreds of millions of rows, exhausting work-process memory within seconds.

### Diagnosis

| Step | Action | ☁️ Public (Fiori App) | ⚙️ OnPrem (T-Code) |
|------|--------|-----------------------|---------------------|
| 1 | Identify suspicious query | Review report logic; look for FAE without a guard | Same |
| 2 | Check memory dump (if present) | *ABAP Runtime Errors* → `TSV_TNEW_PAGE_ALLOC_FAILED` | `ST22` → look for table name and size at crash point |
| 3 | Check result set at runtime | Add temporary `WRITE lines( lt_result )` after the FAE SELECT | Same; or use `ST05` to see row count returned |
| 4 | Trace the driver table | Trace where `lt_driver` is populated; check for early-exit paths that leave it empty | Same |

### Fix Pattern

#### Always Guard with IS NOT INITIAL

```abap
DATA: lt_open_orders TYPE TABLE OF vbak,
      lt_items       TYPE TABLE OF vbap.

" Step 1: Fetch header keys
SELECT vbeln
  FROM vbak
  WHERE auart = 'ZOR'
    AND erdat = @sy-datum
  INTO TABLE @lt_open_orders.

" Step 2: Guard IS NOT INITIAL before FOR ALL ENTRIES
IF lt_open_orders IS NOT INITIAL.

  SELECT vbeln, posnr, matnr, kwmeng
    FROM vbap
    FOR ALL ENTRIES IN @lt_open_orders
    WHERE vbeln = @lt_open_orders-vbeln
    INTO TABLE @lt_items.

ELSE.
  " Driver table is empty — skip the read; lt_items remains empty (correct behaviour)
  RETURN.
ENDIF.
```

#### Deduplicate Driver Table Before FAE

`FOR ALL ENTRIES` deduplicates automatically at runtime, but duplicates in the driver table can inflate the generated IN list before deduplication occurs. Explicitly deduplicating is defensive and self-documenting:

```abap
" Remove duplicates from driver table before passing to FAE
SORT lt_open_orders BY vbeln.
DELETE ADJACENT DUPLICATES FROM lt_open_orders COMPARING vbeln.

IF lt_open_orders IS NOT INITIAL.
  SELECT vbeln, posnr, matnr
    FROM vbap
    FOR ALL ENTRIES IN @lt_open_orders
    WHERE vbeln = @lt_open_orders-vbeln
    INTO TABLE @lt_items.
ENDIF.
```

### Landscape Notes

| Landscape | Specific Behaviour | Extra Steps |
|-----------|--------------------|-------------|
| ☁️ Public Cloud | Identical FAE empty-table behaviour; HANA returns full table scan in milliseconds — making the damage faster | None additional; IS NOT INITIAL guard is mandatory |
| 🔒 Private Cloud | Same | Same |
| ⚙️ OnPrem | Same documented behaviour since R/3; some older systems have slightly different chunk sizes internally | Same guard required |

### Prevention
- **ATC / Code Inspector check:** the Performance checks flag `FOR ALL ENTRIES` risks (empty-table full read). Enable the Performance category in your ATC variant as an **error** in all landscapes (verify the exact check in your release).
- **Code review gate:** `FOR ALL ENTRIES` without an immediately preceding or enclosing `IS NOT INITIAL` check is a **blocker** during pull request review.
- **Unit test:** Write a test that calls the method under test with an empty driver table and asserts that the result is empty.
- **Static analysis:** the extended program check (tx `SLIN`) also highlights risky SQL patterns.

---

## §3 — FOR ALL ENTRIES with Too Many Entries (50K+)

**Exception / Symptom:** No short dump initially — query appears to run but takes minutes instead of seconds; eventually produces a `TIME_OUT` or `TSV_TNEW_PAGE_ALLOC_FAILED` dump, or the dialog session is cancelled by the system.
**Landscapes:** ☁️ Public | 🔒 Private | ⚙️ OnPrem

### Root Cause
`FOR ALL ENTRIES` splits the driver table into chunks internally and fires multiple SQL statements. With 50,000+ entries, HANA must evaluate a massive IN predicate or a long series of OR conditions; the query optimizer may fall back to a full table scan on the target table, and the sheer volume of generated SQL traffic saturates the database connection. Memory pressure from materialising the full result set compounds the problem.

### Diagnosis

| Step | Action | ☁️ Public (Fiori App) | ⚙️ OnPrem (T-Code) |
|------|--------|-----------------------|---------------------|
| 1 | Identify slow report | Monitor long-running jobs | `SM50` / `SM66` — look for WP stuck in DB state |
| 2 | Trace SQL execution | *SQL Trace* Fiori app (if available) | `ST05` SQL Trace — count repetitions of the same SELECT pattern |
| 3 | Check driver table size | Add logging: `WRITE: / 'Driver size:', lines( lt_driver ).` | Same; or check in ABAP debugger |
| 4 | Check runtime | *Application Jobs* Fiori app for background jobs | `SM37` for background jobs; `SM50` for dialog |

### Fix Pattern

#### Package the Driver Table Before FOR ALL ENTRIES

```abap
CONSTANTS: lc_fae_chunk TYPE i VALUE 5000.

TYPES: tt_lifnr TYPE TABLE OF lifnr WITH DEFAULT KEY.

DATA: lt_all_suppliers TYPE tt_lifnr,
      lt_chunk         TYPE tt_lifnr,
      lt_ekko_chunk    TYPE TABLE OF ekko,
      lt_all_ekko      TYPE TABLE OF ekko.

" Scenario: 50,000 supplier numbers collected from a previous step
" lt_all_suppliers is already filled with 50K entries

" Guard: empty check first (see §2)
IF lt_all_suppliers IS INITIAL.
  RETURN.
ENDIF.

" Deduplicate
SORT lt_all_suppliers.
DELETE ADJACENT DUPLICATES FROM lt_all_suppliers.

DATA(lv_total)  = lines( lt_all_suppliers ).
DATA(lv_offset) = 1.  " ABAP table index is 1-based

WHILE lv_offset <= lv_total.

  DATA(lv_upper) = lv_offset + lc_fae_chunk - 1.
  IF lv_upper > lv_total.
    lv_upper = lv_total.
  ENDIF.

  " Extract chunk using table slice
  lt_chunk = lt_all_suppliers[ lv_offset .. lv_upper ].

  " IS NOT INITIAL guard is satisfied because lv_offset <= lv_total guarantees content
  SELECT ebeln, lifnr, bukrs, bedat
    FROM ekko
    FOR ALL ENTRIES IN @lt_chunk
    WHERE lifnr = @lt_chunk-table_line
    INTO TABLE @lt_ekko_chunk.

  APPEND LINES OF lt_ekko_chunk TO lt_all_ekko.
  CLEAR lt_ekko_chunk.

  lv_offset = lv_upper + 1.

ENDWHILE.

" lt_all_ekko now contains all purchase orders for all 50K suppliers
```

> **Chunk size guidance:** 5,000 per chunk is a conservative safe default. On dedicated HANA landscapes with profiling evidence, you may increase to 10,000 — but never remove chunking above that threshold.

### Landscape Notes

| Landscape | Specific Behaviour | Extra Steps |
|-----------|--------------------|-------------|
| ☁️ Public Cloud (HANA) | HANA handles large IN lists better than MaxDB, but optimizer still degrades above ~10K entries per chunk; dialog timeout is stricter | Keep chunk at 5K; move reports over 10K to background via APJ |
| 🔒 Private Cloud (HANA) | Same HANA characteristics; Basis may have tuned HANA memory allocators | Confirm chunk behaviour with Basis; consider HANA-specific hints if approved |
| ⚙️ OnPrem (MaxDB / Oracle) | MaxDB is far less tolerant; chunk must be ≤1,000 on MaxDB; Oracle performs better but still benefits from chunking | Use `sy-dbsys` to switch chunk size at runtime if multi-DB landscape exists |

### Prevention
- **Architect for volume:** Any process that collects keys from a business transaction (orders, invoices, deliveries) must assume unbounded growth. Chunked FAE must be the default pattern, not an afterthought.
- **Performance test with 10× projected data volume** before go-live.
- **Combine with §2 guard:** The IS NOT INITIAL check and deduplication must always accompany the chunking pattern.
- **Consider CDS JOIN alternative:** If both the driver and target tables are dictionary objects, a CDS view with a `JOIN` pushed entirely to the database eliminates the FAE round-trip overhead.

---

## §4 — TIME_OUT Dump

**Exception / Symptom:** `TIME_OUT` runtime error (non-catchable; max dialog runtime exceeded) or `DYNPRO_SEND_IN_BACKGROUND` dump; user sees *"Maximum system runtime exceeded"* or the session is terminated without a message.
**Landscapes:** ☁️ Public | 🔒 Private | ⚙️ OnPrem

### Root Cause
Every ABAP work process is assigned a maximum CPU/wall-clock runtime: typically 300 seconds for dialog work processes and configurable (but often 600–3600 seconds) for background work processes. When a report, function module, or method call crosses this boundary — typically because of an unoptimised SELECT, a LOOP over millions of rows, or a missing database index — the kernel raises `TIME_OUT` and rolls back the current logical unit of work.

### Diagnosis

| Step | Action | ☁️ Public (Fiori App) | ⚙️ OnPrem (T-Code) |
|------|--------|-----------------------|---------------------|
| 1 | Locate the dump | *ABAP Runtime Errors* Fiori app → filter `TIME_OUT` | `ST22` → filter by exception class `TIME_OUT` |
| 2 | Identify the bottleneck statement | *Active Calls / Call Stack* shows the line that was executing at timeout | Same in `ST22` call stack |
| 3 | Trace the SQL | *SQL Trace* Fiori app (Public Cloud) | `ST05` → activate SQL trace → reproduce → deactivate → analyse |
| 4 | Check runtime profile | *ABAP Profiler* Fiori app or *Performance Trace* | `SE30` ABAP runtime analysis; `SAT` transaction |
| 5 | Check DB-level execution plan | Not available in Public Cloud directly | `ST05` → display execution plan for the slow SELECT |
| 6 | Monitor live processes | *Work Process Overview* equivalent in BTP cockpit | `SM50` (single server) / `SM66` (all servers) |

### Fix Pattern

#### Option A — Move Long-Running Logic to Background Job

```abap
" Public Cloud: use Application Jobs (cl_apj_rt_api)
" Schedule report class ZCL_MY_HEAVY_REPORT as an APJ template

" In the job implementation class (implementing IF_APJ_DT_EXEC_OBJECT):
METHOD if_apj_rt_exec_object~execute.

  " All processing happens here — no dialog timeout applies
  " APJ duration limit is configured in the job template

  DATA lt_result TYPE TABLE OF zmy_result.

  " ... heavy processing ...

  " Write results to a persistence table or spool
  MODIFY zmy_result_table FROM TABLE @lt_result.

ENDMETHOD.
```

#### Option B — Pagination with FETCH NEXT ROWS ONLY

```abap
CONSTANTS: lc_page_size TYPE i VALUE 1000.

DATA: lv_offset    TYPE i VALUE 0,
      lt_page      TYPE TABLE OF vbak,
      lv_continue  TYPE abap_bool VALUE abap_true.

WHILE lv_continue = abap_true.

  SELECT vbeln, erdat, auart, netwr
    FROM vbak
    WHERE erdat >= @(sy-datum - 365)
    ORDER BY vbeln
    UP TO @lc_page_size ROWS OFFSET @lv_offset
    INTO TABLE @lt_page.

  IF lt_page IS INITIAL.
    lv_continue = abap_false.
    EXIT.
  ENDIF.

  " Process this page
  LOOP AT lt_page ASSIGNING FIELD-SYMBOL(<ls_order>).
    " ... per-row processing ...
  ENDLOOP.

  lv_offset = lv_offset + lc_page_size.

  " Yield control / commit if appropriate
  COMMIT WORK.

  CLEAR lt_page.

ENDWHILE.
```

> **Note:** `UP TO @n ROWS OFFSET @o` (ABAP 7.50+) is the standard pagination syntax. On earlier releases use `PACKAGE SIZE` with cursor-based processing (see §5).

#### Option C — Optimise the Slow Query

```abap
" Bad: no index on ERDAT+AUART → full table scan on VBAK
SELECT vbeln FROM vbak
  WHERE erdat = @sy-datum
    AND auart = 'ZOR'
  INTO TABLE @DATA(lt_result).

" Good: ensure a secondary index exists on (AUART, ERDAT) in SE11
" Then the same SELECT uses the index — execution plan changes from FullScan to IndexLookup
" Request index creation via transport (OnPrem) or Extensibility (Cloud must use CDS index annotation)
```

#### Option D — Increase Background Job Duration (Public Cloud APJ)

In the APJ job template configuration (Transaction `SJOBREPO` equivalent in Public Cloud or the *Application Jobs* Fiori configuration app), set the `Maximum Duration` field on the job template to an appropriate value (e.g., 3600 seconds). Dialog jobs cannot be extended.

### Landscape Notes

| Landscape | Specific Behaviour | Extra Steps |
|-----------|--------------------|-------------|
| ☁️ Public Cloud | Dialog timeout is typically **300 s** (non-configurable by customer); APJ background jobs can be configured up to the template limit; no `SM50` or `SE30` access | Use *ABAP Profiler* Fiori app; schedule via APJ; use `OFFSET … UP TO` pagination |
| 🔒 Private Cloud | Dialog timeout configurable by Basis via `rdisp/max_wprun_time`; APJ or classic background jobs available | Basis team can raise dialog limit temporarily for investigation |
| ⚙️ OnPrem | `rdisp/max_wprun_time` profile parameter controls dialog timeout; `SM36`/`SM37` for background scheduling | Use `ST05` + `SE30`/`SAT` for root-cause; apply DB index via `SE11` |

### Prevention
- **Rule:** Any report processing more than 10,000 records **must** run as a background job or use pagination.
- **Dev-time:** Run with representative data volume in the sandbox; if it exceeds 60 seconds, refactor before transport.
- **Monitoring:** Set up *Application Log* or *Business Application Log* (Public Cloud) entries at page boundaries so you can see progress if a job does time out.
- **CDS push-down:** Aggregation, filtering, and sorting logic pushed to a CDS view eliminates large ABAP-side loops.

---

## §5 — TSV_TNEW_PAGE_ALLOC_FAILED (Memory Dump)

**Exception / Symptom:** `TSV_TNEW_PAGE_ALLOC_FAILED` — the ABAP kernel cannot allocate another memory page for an internal table; the work process is terminated immediately.
**Landscapes:** ☁️ Public | 🔒 Private | ⚙️ OnPrem

### Root Cause
Each ABAP work process runs in a single OS process with a memory ceiling (commonly 2 GB effective per work process; exact value depends on profile parameter `abap/heap_area_wp` and OS limits). When an internal table grows beyond this limit — typically by reading millions of rows into a flat internal table, building nested deep structures, or accumulating results across loop iterations without release — the kernel cannot extend the table's page chain and raises `TSV_TNEW_PAGE_ALLOC_FAILED`. The dump is unrecoverable by the application; the WP is restarted by the dispatcher.

### Diagnosis

| Step | Action | ☁️ Public (Fiori App) | ⚙️ OnPrem (T-Code) |
|------|--------|-----------------------|---------------------|
| 1 | Open the dump | *ABAP Runtime Errors* Fiori app → `TSV_TNEW_PAGE_ALLOC_FAILED` | `ST22` → same exception text |
| 2 | Identify the table | Dump shows the **internal table name** and its **size in bytes** at crash point | Same in `ST22` *Internal Table* section |
| 3 | Find row count | Calculate: `table_size_bytes / row_width_bytes` | Same; or add `lines( lt_xxx )` log before the crash line |
| 4 | Monitor live memory | No direct equivalent in Public Cloud | `SM50` → *Work Process Detail* → Heap column; `SM66` for all servers |
| 5 | Check query driving the fill | Identify the SELECT or LOOP that populates the oversized table | `ST05` to see row counts returned by the SELECT |

### Fix Pattern

#### Option A — Package Processing (Never Read All at Once)

```abap
" Bad: reads 10 million rows into memory at once
SELECT * FROM ekpo INTO TABLE @DATA(lt_all_ekpo).  " NEVER do this on large tables

" Good: process in packages
DATA lt_ekpo_pkg TYPE TABLE OF ekpo.

SELECT ebeln, ebelp, matnr, menge, netpr
  FROM ekpo
  WHERE werks = '1000'
  INTO TABLE @lt_ekpo_pkg
  PACKAGE SIZE 5000.                          " PACKAGE SIZE keyword triggers package mode

  " Process the current package
  LOOP AT lt_ekpo_pkg ASSIGNING FIELD-SYMBOL(<ls_item>).
    " ... business logic per item ...
  ENDLOOP.

  CLEAR lt_ekpo_pkg.

ENDSELECT.
```

#### Option B — Cursor-Based Streaming (OPEN CURSOR / FETCH)

Use when you need fine-grained control over fetch size or when the SELECT is complex:

```abap
DATA: lo_cursor   TYPE cursor,
      lt_batch    TYPE TABLE OF ekpo,
      lv_done     TYPE abap_bool VALUE abap_false.

CONSTANTS lc_fetch_size TYPE i VALUE 2000.

" Open a server-side cursor — no data transferred yet
OPEN CURSOR WITH HOLD @lo_cursor FOR
  SELECT ebeln, ebelp, matnr, menge
  FROM ekpo
  WHERE werks = '1000'
  ORDER BY ebeln, ebelp.

WHILE lv_done = abap_false.

  " Fetch the next batch from the cursor
  FETCH NEXT CURSOR @lo_cursor
    INTO TABLE @lt_batch
    PACKAGE SIZE @lc_fetch_size.

  IF sy-subrc <> 0.
    " No more rows — cursor is exhausted
    lv_done = abap_true.
  ENDIF.

  " Process this batch even if it is the last (partial) batch
  IF lt_batch IS NOT INITIAL.
    LOOP AT lt_batch ASSIGNING FIELD-SYMBOL(<ls_item>).
      " ... process row ...
    ENDLOOP.
    CLEAR lt_batch.
  ENDIF.

ENDWHILE.

CLOSE CURSOR @lo_cursor.
```

> **Key difference vs PACKAGE SIZE SELECT:** `OPEN CURSOR` keeps the cursor open on the DB server between fetches, which avoids repeated full-scan starts. Use it when processing order matters or when you need to interleave fetches with writes.

#### Option C — Push Aggregation to the Database

```abap
" Bad: reads 5 million order items into ABAP, then COLLECT
DATA: lt_all_items  TYPE TABLE OF ekpo,
      lt_totals     TYPE TABLE OF zmy_total_s.

SELECT * FROM ekpo INTO TABLE @lt_all_items.   " 5M rows in memory

LOOP AT lt_all_items ASSIGNING FIELD-SYMBOL(<ls>).
  DATA(ls_total) = VALUE zmy_total_s(
    matnr = <ls>-matnr
    total = <ls>-menge ).
  COLLECT ls_total INTO lt_totals.             " ABAP-side aggregation
ENDLOOP.

" -------------------------------------------------------

" Good: let the database GROUP BY — returns only the summary rows
SELECT matnr, SUM( menge ) AS total_qty
  FROM ekpo
  WHERE werks = '1000'
  GROUP BY matnr
  INTO TABLE @DATA(lt_totals_db).             " Only one row per material
```

### Landscape Notes

| Landscape | Specific Behaviour | Extra Steps |
|-----------|--------------------|-------------|
| ☁️ Public Cloud | Work process memory limit is managed by SAP; customers cannot raise `abap/heap_area_wp`; limit is typically 2 GB | Package processing and DB aggregation are the only remediation options |
| 🔒 Private Cloud | Memory parameters may be adjustable by Basis as a temporary workaround | Raise a ticket for Basis to increase WP heap as stopgap; fix root cause as permanent solution |
| ⚙️ OnPrem | `abap/heap_area_wp` and `abap/heap_area_total` are configurable | `SM50` gives real-time heap visibility; consider Extended Memory configuration review if dumps are frequent |

### Prevention
- **Rule:** No `SELECT … INTO TABLE @DATA(lt_xxx)` on tables with more than 100K rows without a `PACKAGE SIZE` or `UP TO n ROWS` constraint.
- **Code review gate:** Any `SELECT *` or `SELECT … INTO TABLE` on a wide or high-volume table is a **blocker**.
- **Performance test:** Load-test with 10× expected data; confirm memory stays below 500 MB per WP.
- **DB-side aggregation first:** Prefer `GROUP BY`, `SUM`, `COUNT`, `MAX` in the SELECT rather than ABAP-side `COLLECT` or `LOOP` accumulation.
- **Selective column projection:** `SELECT col1, col2` instead of `SELECT *` reduces row width and proportionally raises the effective row budget before the memory ceiling is reached.

---

## §6 — N+1 SELECT Pattern (SELECT Inside LOOP)

**Exception / Symptom:** No dump — pure performance degradation. A report that processed 10,000 records in 2 minutes now takes 45 minutes with 100,000 records; each order of magnitude increase in data causes a proportional collapse in throughput.
**Landscapes:** ☁️ Public | 🔒 Private | ⚙️ OnPrem

### Root Cause
A `SELECT` statement placed inside an `ABAP LOOP` issues one database round-trip per loop iteration. For N rows in the outer result set, the application generates N+1 database calls (1 for the outer query, 1 per row for the inner). Each call incurs network latency, DB parse/plan overhead, and context-switch cost. At 100,000 outer rows with 1 ms round-trip per inner SELECT, the inner queries alone consume ~100 seconds — regardless of how fast HANA processes each individual statement.

### Diagnosis

| Step | Action | ☁️ Public (Fiori App) | ⚙️ OnPrem (T-Code) |
|------|--------|-----------------------|---------------------|
| 1 | Confirm the N+1 pattern | *SQL Trace* Fiori app → sort by *Count*; look for a SELECT with thousands of identical executions against the same table | `ST05` SQL Trace → *Statement Summary* → look for same SELECT repeated N times |
| 2 | Map trace to source | *SQL Trace* → drill into statement → *Source Position* | `ST05` → *Display Trace* → source line shown per statement |
| 3 | Quantify the overhead | N × avg_duration = wasted time visible in trace | Same formula from `ST05` durations |
| 4 | Profile overall runtime | *ABAP Profiler* Fiori app → call hierarchy shows `SELECT` dominating | `SE30`/`SAT` → hit list shows the SELECT as the top cost item |

### Fix Pattern

#### BEFORE — N+1 Anti-Pattern (DO NOT USE)

```abap
DATA: lt_orders  TYPE TABLE OF vbak,
      ls_partner TYPE vbpa.

" Outer query: fetch sales orders
SELECT vbeln, erdat, auart
  FROM vbak
  WHERE erdat = @sy-datum
  INTO TABLE @lt_orders.                  " Returns 50,000 rows

" N+1 PROBLEM: 50,000 individual SELECT statements follow
LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_order>).

  " One SELECT PER order — 50,000 round trips to the database
  SELECT SINGLE parvw, kunnr
    FROM vbpa
    WHERE vbeln = @<ls_order>-vbeln
      AND parvw = 'AG'
    INTO @ls_partner.

  IF sy-subrc = 0.
    " ... process partner data ...
  ENDIF.

ENDLOOP.
```

#### AFTER — Option A: Collect Keys, Then Single FOR ALL ENTRIES

```abap
DATA: lt_orders   TYPE TABLE OF vbak,
      lt_vbeln    TYPE TABLE OF vbak-vbeln,
      lt_partners TYPE TABLE OF vbpa.

" Step 1: Fetch headers (unchanged)
SELECT vbeln, erdat, auart
  FROM vbak
  WHERE erdat = @sy-datum
  INTO TABLE @lt_orders.

IF lt_orders IS INITIAL.
  RETURN.
ENDIF.

" Step 2: Collect all keys from the outer result
lt_vbeln = CORRESPONDING #( lt_orders MAPPING table_line = vbeln ).
SORT lt_vbeln.
DELETE ADJACENT DUPLICATES FROM lt_vbeln.

" Step 3: Single SELECT for ALL partner records — 1 database call total
SELECT vbeln, parvw, kunnr
  FROM vbpa
  FOR ALL ENTRIES IN @lt_vbeln
  WHERE vbeln = @lt_vbeln-table_line
    AND parvw = 'AG'
  INTO TABLE @lt_partners.

" Step 4: Build lookup hash for O(1) access in the loop
DATA lt_partner_map TYPE HASHED TABLE OF vbpa
  WITH UNIQUE KEY vbeln parvw.

lt_partner_map = lt_partners.

" Step 5: Loop with hash access — zero additional DB calls
LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_order>).

  READ TABLE lt_partner_map
    WITH TABLE KEY vbeln = <ls_order>-vbeln parvw = 'AG'
    ASSIGNING FIELD-SYMBOL(<ls_partner>).

  IF sy-subrc = 0.
    " ... process partner data using <ls_partner> ...
  ENDIF.

ENDLOOP.
```

> **Result:** 50,000 individual SELECT calls replaced by **1** `FOR ALL ENTRIES` call. Runtime drops from ~50 seconds (at 1 ms/call) to milliseconds.

#### AFTER — Option B: Push the JOIN to a CDS View

When both entities are stable dictionary tables, a CDS view with a JOIN eliminates the ABAP-side join entirely and lets HANA apply its columnar execution engine:

```cds
// ZI_OrderWithPartner.ddls
@AbapCatalog.sqlViewName: 'ZV_ORD_PARTNER'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view ZI_OrderWithPartner
  as select from vbak as ord
    left outer join vbpa as prt
      on  prt.vbeln = ord.vbeln
      and prt.parvw = 'AG'
{
  ord.vbeln,
  ord.erdat,
  ord.auart,
  prt.kunnr as sold_to_party
}
where ord.erdat = $session.system_date
```

```abap
" Consume the CDS view — single SQL statement, all data in one shot
SELECT vbeln, erdat, auart, sold_to_party
  FROM zi_orderwithpartner
  INTO TABLE @DATA(lt_result).

LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<ls>).
  " ... process directly — no further DB calls needed ...
ENDLOOP.
```

### Landscape Notes

| Landscape | Specific Behaviour | Extra Steps |
|-----------|--------------------|-------------|
| ☁️ Public Cloud | HANA's columnar engine makes individual selects *faster* per call, which can **mask** the N+1 problem during low-volume testing — it only becomes obvious at scale. Use *SQL Trace* Fiori app to detect early | CDS views are the preferred fix; `FOR ALL ENTRIES` chunking (§3) required if driver table > 50K |
| 🔒 Private Cloud | Same HANA characteristics; `ST05` available via standard GUI | Same remediation options |
| ⚙️ OnPrem | Older DB platforms (MaxDB, Oracle) show N+1 pain much earlier (even at 1,000 rows) because per-call overhead is higher | `ST05` is the primary diagnostic; adding DB indexes on JOIN columns in the target table can reduce individual call cost as a stopgap |

### Prevention
- **Code review rule:** Any `SELECT` (including `SELECT SINGLE`) inside a `LOOP … ENDLOOP` is a **blocker** unless the loop is explicitly bounded to ≤ 10 iterations by design.
- **Code Inspector check:** `CL_CI_TEST_SELECT_NESTED` ("SELECTs in Loops") flags SELECT-inside-LOOP. Enable it (Performance category) as an **error** in all landscapes.
- **Design principle:** Fetch all required data **before** the processing loop, not inside it. Build in-memory lookup structures (hashed tables, sorted tables with binary search) for O(1) access during the loop.
- **CDS-first architecture:** Model related entities as CDS views with JOINs; consumers call the view once and receive a pre-joined result set.
- **Performance test baseline:** Establish a performance test that runs with 10× production data volume before every transport to production. N+1 issues are invisible at small data volumes and catastrophic at large ones.

---

## Quick-Reference Summary

| § | Issue | Exception / Symptom | Landscapes | Primary Fix |
|---|-------|---------------------|------------|-------------|
| 1 | Large Range / IN Overflow | `CX_SY_SQL_TOO_MANY_IN_VALUES` | ☁️🔒⚙️ | Chunk at 5,000; EXISTS subquery |
| 2 | FAE Empty Driver Table | No exception — full table read | ☁️🔒⚙️ | `IS NOT INITIAL` guard always |
| 3 | FAE 50K+ Driver Table | Timeout / memory dump | ☁️🔒⚙️ | Chunk driver table before FAE |
| 4 | TIME_OUT Dump | `TIME_OUT` / `DYNPRO_SEND_IN_BACKGROUND` | ☁️🔒⚙️ | Background job; pagination; index |
| 5 | Memory Dump | `TSV_TNEW_PAGE_ALLOC_FAILED` | ☁️🔒⚙️ | PACKAGE SIZE; OPEN CURSOR; GROUP BY |
| 6 | N+1 SELECT in LOOP | Extreme slowness at scale | ☁️🔒⚙️ | FAE batch; CDS JOIN |

---

*Last updated: see file history. Maintainer: Architecture & Performance Guild.*