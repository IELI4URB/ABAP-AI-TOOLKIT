---
name: abap-application-jobs
description: 'Design, implement, schedule, and operate Application Jobs in SAP ABAP Cloud. Use for IF_APJ_DT_EXEC_OBJECT, IF_APJ_RT_EXEC_OBJECT, job catalogs, job templates, parameters, recurring or event-based scheduling, CL_APJ APIs, batch processing, Application Jobs monitoring, and SM36 or SM37 replacement.'
metadata:
  version: 2.0.0
  tags: abap application-jobs scheduling background batch monitoring abap-cloud
---

# ABAP Cloud Application Jobs

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

Use this skill as the background-processing router. The complete Application Jobs reference is inlined below; load only the relevant section.

## Ownership

This skill owns Application Job classes, catalogs, templates, scheduling, runtime lifecycle, and job monitoring. Use `abap-error-handling-resilience` for general exception and logging policy and `abap-performance-optimization` for deeper batch-volume analysis.

## Workflow

1. Establish landscape, release, workload, frequency, runtime window, restart requirements, volume, and operator ownership.
2. Inspect job interface signatures, parameter types, persistence boundaries, released APIs, and authorization requirements.
3. Design the class, catalog, template, schedule, package checkpoints, and log correlation as one lifecycle.
4. Read only the matching reference sections below.
5. Define idempotency, cancellation, partial progress, retry/restart, locking, and retention behavior.
6. Validate parameters, empty workload, large volume, concurrent runs, failure recovery, cancellation, and monitoring visibility.

## Reference Routing

| Request | Read sections in `jobs-complete.md` |
|---|---|
| Framework choice and lifecycle | 1, 2 |
| Job class and parameters | 3 |
| Catalog or template | 4, 5 |
| Scheduling | 6 |
| Application Log | 7 |
| Errors and failed status | 8 |
| Monitoring and cancellation | 9 |
| Performance and packaging | 10 |
| End-to-end example | 11 |

## Mandatory Gates

- Use Application Jobs for ABAP Cloud; do not present SM36/SM37 as a cloud implementation path.
- Verify parameter names, data types, ranges, defaults, and runtime conversion against interface contracts.
- Avoid unbounded reads and monolithic transactions; check package size, locks, memory, commits, and restartability.
- Correlate logs to the job run and include actionable business context without exposing sensitive data.
- Verify interfaces, classes, and syntax for the target release; report `Syntax confidence: verified` or block production use.
- Release guidance must include authorization, ATC/readiness, load and concurrency tests, rollback/cancellation, monitoring, and runbook evidence.

## Response Shape

For non-trivial requests, state workload assumptions, artifact list, parameter and execution contracts, package/recovery design, logging and monitoring, tests, and release evidence.

---

## Application Jobs — Complete Reference

> **Audience:** ABAP Cloud developers replacing classic background jobs (SM36/SM37) with
> cloud-compatible Application Jobs.  
> **Applies to:** BTP ABAP Environment, S/4HANA 2021+ (on-premise and cloud)

---

### 1. Classic vs Application Jobs

#### Why SM36/SM37 are blocked in ABAP Cloud

ABAP Cloud's clean-core principle forbids direct use of classic function modules and
RFC-based scheduling. The following classic APIs are **not released** in ABAP Cloud:

| Classic Object | Reason blocked |
|---|---|
| `JOB_OPEN` / `JOB_SUBMIT` / `JOB_CLOSE` | RFC-based, not cloud-safe |
| `SUBMIT ... VIA JOB` | Implicit background work process binding |
| Transaction `SM36` / `SM37` | GUI-only, no programmatic cloud API |
| `BP_JOB_*` function modules | Not in released API list |

#### Application Jobs — the replacement

Application Jobs are the **only supported background scheduling mechanism** in ABAP Cloud.
They provide:

- Type-safe parameter definition via ABAP objects
- Full Fiori-based monitoring (no SM37)
- Structured logging via `CL_BALI_LOG`
- Transport-capable catalog entries and templates
- Recurrence scheduling (daily/weekly/monthly/event-based)
- Authorization concept via `S_BTCH_ADM` / `S_BTCH_JOB`

#### Fiori app path

| Task | Fiori App |
|---|---|
| Schedule a job | **Application Jobs** (F2689) |
| Monitor running/completed jobs | **Manage Application Jobs** (F3146) |
| View job logs | **Display Application Logs** embedded in job detail |

---

### 2. Development Sequence

```
Step 1 ─ Implementation Class
          CLASS ZCL_MYJOB implements IF_APJ_DT_EXEC_OBJECT, IF_APJ_RT_EXEC_OBJECT
          ↓
Step 2 ─ Job Catalog Entry (ADT: New → Application Jobs → Job Catalog Entry)
          Links class name, description, transport request
          ↓
Step 3 ─ Job Template (ADT: New → Application Jobs → Job Template)
          Stores default parameter values, links to catalog entry
          ↓
Step 4 ─ Schedule
          Via Fiori App "Application Jobs" or programmatically via CL_APJ_RT_API
```

---

### 3. Implementation Class — Full Pattern

#### Interface responsibilities

| Interface | Methods | Purpose |
|---|---|---|
| `IF_APJ_DT_EXEC_OBJECT` | `GET_PARAMETERS` | Design-time: declare parameter schema |
| `IF_APJ_RT_EXEC_OBJECT` | `EXECUTE` | Runtime: run the job logic |

#### `GET_PARAMETERS` — parameter declaration

```abap
METHOD if_apj_dt_exec_object~get_parameters.

  " Each parameter needs: name, text_element, datatype_name, length,
  "   is_mandatory, default_value, parameter_kind

  et_parameter_def = VALUE #(

    " Boolean / checkbox parameter
    ( selname       = 'P_SIM'           " ABAP-style param name (max 8 chars)
      kind          = if_apj_dt_exec_object=>c_parameter_kind-selection
      datatype_name = 'ABAP_BOOL'
      changeable_ind = abap_true
      is_mandatory  = abap_false
      default_value = abap_false
      text_element  = '001' )          " sy-msid text element ID from SE63 / message class

    " Date range — Low value
    ( selname       = 'P_DATFR'
      kind          = if_apj_dt_exec_object=>c_parameter_kind-selection
      datatype_name = 'D'
      length        = 8
      is_mandatory  = abap_true
      default_value = ''
      text_element  = '002' )

    " Date range — High value
    ( selname       = 'P_DATTO'
      kind          = if_apj_dt_exec_object=>c_parameter_kind-selection
      datatype_name = 'D'
      length        = 8
      is_mandatory  = abap_true
      default_value = ''
      text_element  = '003' )

    " Free-text company code filter
    ( selname       = 'P_BUKRS'
      kind          = if_apj_dt_exec_object=>c_parameter_kind-selection
      datatype_name = 'BUKRS'
      is_mandatory  = abap_false
      default_value = ''
      text_element  = '004' )
  ).

ENDMETHOD.
```

#### `EXECUTE` — full working implementation

```abap
METHOD if_apj_rt_exec_object~execute.

  " ── 1. Read parameters ─────────────────────────────────────────────
  DATA lv_simulation TYPE abap_bool.
  DATA lv_date_from  TYPE d.
  DATA lv_date_to    TYPE d.
  DATA lv_bukrs      TYPE bukrs.

  LOOP AT it_parameters INTO DATA(ls_param).
    CASE ls_param-selname
      WHEN 'P_SIM'.
        lv_simulation = ls_param-low.
      WHEN 'P_DATFR'.
        lv_date_from  = ls_param-low.
      WHEN 'P_DATTO'.
        lv_date_to    = ls_param-low.
      WHEN 'P_BUKRS'.
        lv_bukrs      = ls_param-low.
    ENDCASE.
  ENDLOOP.

  " ── 2. Validate parameters ─────────────────────────────────────────
  IF lv_date_from > lv_date_to.
    RAISE EXCEPTION TYPE cx_apj_rt_content
      EXPORTING
        textid = cx_apj_rt_content=>parameter_error
        msgv1  = 'Start date must not be after end date'.
  ENDIF.

  " ── 3. Create structured log (BAL OO API) ─────────────────────────
  DATA(lo_log) = cl_bali_log=>create_with_header(
    cl_bali_header_setter=>create(
      object      = 'ZJOB'          " Must exist as BAL log object (SLG0)
      subobject   = 'INVOICES'
      external_id = |Invoice Post { sy-datum } { sy-uzeit }| ) ).

  lo_log->add_item( cl_bali_free_text_setter=>create(
    severity = if_bali_constants=>c_severity_status
    text     = |Job started. DateFrom={ lv_date_from } DateTo={ lv_date_to }| ) ).

  IF lv_simulation = abap_true.
    lo_log->add_item( cl_bali_free_text_setter=>create(
      severity = if_bali_constants=>c_severity_status
      text     = 'SIMULATION MODE — no database changes will be committed' ) ).
  ENDIF.

  " ── 4. Business logic — package-based processing ───────────────────
  CONSTANTS c_package_size TYPE i VALUE 100.
  DATA lv_offset     TYPE i VALUE 0.
  DATA lv_processed  TYPE i VALUE 0.
  DATA lv_errors     TYPE i VALUE 0.

  DO.
    " Fetch next package
    SELECT sales_order_id, net_amount, currency
      FROM zsalesorder
      WHERE creation_date BETWEEN @lv_date_from AND @lv_date_to
        AND ( @lv_bukrs = '' OR company_code = @lv_bukrs )
        AND posting_status = 'O'
      ORDER BY sales_order_id
      UP TO @c_package_size ROWS OFFSET @lv_offset
      INTO TABLE @DATA(lt_orders).

    IF sy-subrc <> 0 OR lt_orders IS INITIAL.
      EXIT.  " No more data
    ENDIF.

    " Process each record
    LOOP AT lt_orders INTO DATA(ls_order).
      TRY.
          " ─ Your business logic here ─
          IF lv_simulation = abap_false.
            " Perform actual DB changes
          ENDIF.

          lv_processed += 1.

          lo_log->add_item( cl_bali_free_text_setter=>create(
            severity = if_bali_constants=>c_severity_status
            text     = |Processed order { ls_order-sales_order_id }| ) ).

        CATCH cx_root INTO DATA(lx_any).
          lv_errors += 1.
          lo_log->add_item( cl_bali_exception_setter=>create(
            severity  = if_bali_constants=>c_severity_error
            exception = lx_any ) ).
      ENDTRY.
    ENDLOOP.

    lv_offset += c_package_size.
    IF lines( lt_orders ) < c_package_size.
      EXIT.  " Last package was smaller than batch — done
    ENDIF.
  ENDDO.

  " ── 5. Final summary log entry ─────────────────────────────────────
  lo_log->add_item( cl_bali_free_text_setter=>create(
    severity = if_bali_constants=>c_severity_status
    text     = |Completed. Processed: { lv_processed } Errors: { lv_errors }| ) ).

  " ── 6. Save log; assign_to_current_appl_job surfaces it in App Jobs ─
  cl_bali_log_db=>get_instance( )->save_log(
    log                        = lo_log
    assign_to_current_appl_job = abap_true ).

  " ── 7. Raise exception to mark job as FAILED if errors occurred ────
  IF lv_errors > 0.
    RAISE EXCEPTION TYPE cx_apj_rt_content
      EXPORTING
        textid = cx_apj_rt_content=>processing_error
        msgv1  = |{ lv_errors } orders could not be posted — see log|.
  ENDIF.

ENDMETHOD.
```

#### Complete class definition skeleton

```abap
CLASS zcl_invoice_post_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PROTECTED SECTION.
  PRIVATE SECTION.
    " Internal helper methods
    METHODS process_order
      IMPORTING is_order     TYPE zsalesorder
                iv_simulate  TYPE abap_bool
      RAISING   cx_apj_rt_content.
ENDCLASS.
```

---

### 4. Job Catalog Entry

The **Job Catalog Entry** is a repository object that links your implementation class to a
schedulable job identity. It has its own transport request.

#### Creation in ADT

1. **File → New → Other ABAP Repository Object**
2. Navigate to **Application Jobs → Job Catalog Entry**
3. Fill in:
   - **Name**: `ZINVOICE_POST_JC` (max 32 chars, convention `Z<NAME>_JC`)
   - **Description**: `Post Open Invoices`
   - **Implementation Class**: `ZCL_INVOICE_POST_JOB`
4. Assign to a transport request
5. **Activate**

#### Programmatic check

```abap
" Verify catalog entry exists at runtime
cl_apj_rt_api=>get_job_catalog_entry(
  EXPORTING
    iv_catalog_entry_name = 'ZINVOICE_POST_JC'
  IMPORTING
    es_catalog_entry      = DATA(ls_catalog) ).

WRITE: / ls_catalog-catalog_entry_name,
       / ls_catalog-implementation_class.
```

---

### 5. Job Template

A **Job Template** stores a pre-configured set of default parameter values, associated with
a catalog entry. End users can further adjust parameters when scheduling from the Fiori app.

#### Creation in ADT

1. **File → New → Other ABAP Repository Object → Application Jobs → Job Template**
2. Fill in:
   - **Name**: `ZINVOICE_POST_JT` (convention `Z<NAME>_JT`)
   - **Catalog Entry**: `ZINVOICE_POST_JC`
   - **Description**: `Post Invoices — Default Template`
3. Set default parameter values in the wizard table
4. Activate and transport

#### Programmatic template creation (for automated setup)

```abap
DATA lt_parameters TYPE cl_apj_rt_api=>tt_job_parameter_value.

lt_parameters = VALUE #(
  ( selname = 'P_SIM'   sign = 'I' option = 'EQ' low = abap_false )
  ( selname = 'P_DATFR' sign = 'I' option = 'EQ' low = '20240101' )
  ( selname = 'P_DATTO' sign = 'I' option = 'EQ' low = '20241231' )
).

cl_apj_rt_api=>create_template(
  EXPORTING
    iv_template_name  = 'ZINVOICE_POST_JT'
    iv_catalog_name   = 'ZINVOICE_POST_JC'
    iv_description    = 'Post Invoices — Default Template'
    it_parameters     = lt_parameters ).
```

---

### 6. Scheduling Options

#### Scheduling via API — Full Example

```abap
CLASS zcl_invoice_job_scheduler DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS schedule_daily
      IMPORTING iv_start_time TYPE timestampl
                iv_bukrs      TYPE bukrs OPTIONAL
      RAISING   cx_apj_rt_content.
ENDCLASS.

CLASS zcl_invoice_job_scheduler IMPLEMENTATION.

  METHOD schedule_daily.

    " ── Build start condition ─────────────────────────────────────────
    DATA(ls_start_info) = VALUE cl_apj_rt_api=>s_start_info(
      start_immediately = abap_false
      planned_start     = iv_start_time   " UTC timestamp
    ).

    " ── Build recurrence rule (daily, for 1 year) ─────────────────────
    DATA(ls_recurrence) = VALUE cl_apj_rt_api=>s_recurrence_info(
      is_recurring     = abap_true
      recurrence_type  = cl_apj_rt_api=>c_recurrence_type-daily
      interval_days    = 1
      end_type         = cl_apj_rt_api=>c_end_type-end_date
      end_date         = cl_abap_context_info=>get_system_date( ) + 365
    ).

    " ── Build parameter values ────────────────────────────────────────
    DATA lv_today TYPE d.
    lv_today = cl_abap_context_info=>get_system_date( ).

    DATA lt_params TYPE cl_apj_rt_api=>tt_job_parameter_value.
    lt_params = VALUE #(
      ( selname = 'P_SIM'   sign = 'I' option = 'EQ' low = abap_false )
      ( selname = 'P_DATFR' sign = 'I' option = 'EQ' low = lv_today )
      ( selname = 'P_DATTO' sign = 'I' option = 'EQ' low = lv_today )
    ).

    IF iv_bukrs IS NOT INITIAL.
      INSERT VALUE #( selname = 'P_BUKRS' sign = 'I' option = 'EQ'
                      low = iv_bukrs ) INTO TABLE lt_params.
    ENDIF.

    " ── Schedule the job ─────────────────────────────────────────────
    cl_apj_rt_api=>schedule_job(
      EXPORTING
        iv_catalog_name       = 'ZINVOICE_POST_JC'
        iv_template_name      = 'ZINVOICE_POST_JT'
        iv_job_name           = |Invoice Post { lv_today }|
        is_start_info         = ls_start_info
        is_recurrence_info    = ls_recurrence
        it_parameters         = lt_params
      IMPORTING
        ev_job_id             = DATA(lv_job_id) ).

    WRITE: / |Job scheduled. ID = { lv_job_id }|.

  ENDMETHOD.
ENDCLASS.
```

#### Scheduling option cheat sheet

| Scenario | API fields |
|---|---|
| One-time, immediate | `start_immediately = abap_true` |
| One-time, specific date/time | `start_immediately = abap_false`, `planned_start = <timestamp>` |
| Daily at fixed time | `is_recurring = abap_true`, `recurrence_type = #DAILY`, `interval_days = 1` |
| Weekly on Monday | `recurrence_type = #WEEKLY`, `interval_weeks = 1`, `day_of_week = cl_apj_rt_api=>c_day_of_week-monday` |
| Monthly on day 1 | `recurrence_type = #MONTHLY`, `day_of_month = 1` |
| End after N runs | `end_type = #NUMBER_OF_RUNS`, `max_runs = N` |
| End by date | `end_type = #END_DATE`, `end_date = <date>` |

---

### 7. `CL_BALI_LOG` in Job Context

Structured application logs (BAL) are the correct logging mechanism inside jobs. Classic
`MESSAGE` statements do NOT write to the job log in ABAP Cloud.

#### Log lifecycle

```abap
" ── Create log ───────────────────────────────────────────────────────
DATA(lo_log) = cl_bali_log=>create_with_header(
  cl_bali_header_setter=>create(
    object      = 'ZJOB'     " SLG0 object — must exist in SLG0
    subobject   = 'PROCESS'
    external_id = |Run { sy-datum }-{ sy-uzeit }| ) ).

" ── Add free text ────────────────────────────────────────────────────
lo_log->add_item( cl_bali_free_text_setter=>create(
  severity = if_bali_constants=>c_severity_status
  text     = 'Processing company code 1000' ) ).

" ── Add a message (from a message class) ──────────────────────────────
lo_log->add_item( cl_bali_message_setter=>create_from_sy( ) ).  " after MESSAGE ... INTO

" ── Add exception ────────────────────────────────────────────────────
TRY.
    " ... risky code ...
  CATCH cx_root INTO DATA(lx).
    lo_log->add_item( cl_bali_exception_setter=>create(
      severity  = if_bali_constants=>c_severity_error
      exception = lx ) ).
ENDTRY.

" ── Save log to DB; link it to the running job ───────────────────────
cl_bali_log_db=>get_instance( )->save_log(
  log                        = lo_log
  assign_to_current_appl_job = abap_true ).
```

#### Linking the log to the job

`save_log( ... assign_to_current_appl_job = abap_true )` links the log to the current Application Job so it appears in the Fiori job monitor. The job runtime also exposes `cl_apj_rt_api=>get_log_handle( )` if you need the handle explicitly.

---

### 8. Error Handling in Jobs

#### Marking a job as FAILED

Raise `CX_APJ_RT_CONTENT` from the `execute` method. Any unhandled exception causes the job
status to transition to **Failed** and the message appears in the job log.

```abap
" Hard failure — aborts immediately
RAISE EXCEPTION TYPE cx_apj_rt_content
  EXPORTING
    textid = cx_apj_rt_content=>processing_error
    msgv1  = 'Critical error in invoice posting'
    msgv2  = lv_detail.

" Conditional failure at end — partial success
IF lv_errors > 0 AND lv_processed = 0.
  RAISE EXCEPTION TYPE cx_apj_rt_content
    EXPORTING
      textid = cx_apj_rt_content=>processing_error
      msgv1  = 'All records failed — check application log'.
ELSEIF lv_errors > 0.
  " Partial success: job status = WARNING (not Failed)
  " No exception raised; just write warning to log
  lo_log->add_item( cl_bali_free_text_setter=>create(
    severity = if_bali_constants=>c_severity_warning
    text     = |{ lv_errors } records failed but job completed partially| ) ).
ENDIF.
```

#### Exception class hierarchy

```
CX_ROOT
  └─ CX_STATIC_CHECK
       └─ CX_APJ_RT_CONTENT        ← Raised to signal job-level failures
            ├─ processing_error     ← Business logic error
            └─ parameter_error      ← Invalid input parameters
```

---

### 9. Monitoring

#### Job status transitions

```
Scheduled
    │
    ▼ (start condition met)
Running
    │
    ├──────────────► Completed   (exit without exception)
    │
    ├──────────────► Completed with Warnings  (log has warnings, no exception)
    │
    └──────────────► Failed      (cx_apj_rt_content raised or unhandled cx_root)
```

#### Fiori Monitoring App — key fields

| Column | Meaning |
|---|---|
| Job Name | Free-text name given at scheduling |
| Catalog Entry | Technical ID of the job definition |
| Status | Scheduled / Running / Completed / Failed |
| Start Time | Actual start (UTC) |
| Duration | Wall-clock time in seconds |
| Log Available | ✓ if BAL log was saved with job handle |

#### Canceling a running job programmatically

```abap
cl_apj_rt_api=>cancel_job(
  EXPORTING iv_job_id = lv_job_id ).
```

---

### 10. Performance in Jobs

#### Package-based processing pattern (recommended)

Always process data in packages to:
- Avoid memory overflow on large datasets
- Enable partial progress logging
- Allow the runtime to manage resources between packages

```abap
CONSTANTS c_pkg TYPE i VALUE 500.
DATA lv_off TYPE i VALUE 0.

DO.
  SELECT * FROM ztable
    WHERE status = 'O'
    ORDER BY PRIMARY KEY
    UP TO @c_pkg ROWS OFFSET @lv_off
    INTO TABLE @DATA(lt_pkg).

  IF lt_pkg IS INITIAL. EXIT. ENDIF.

  " Process lt_pkg ...

  lv_off += c_pkg.
  IF lines( lt_pkg ) < c_pkg. EXIT. ENDIF.
ENDDO.
```

#### COMMIT WORK in jobs

| Context | `COMMIT WORK` allowed? |
|---|---|
| Classic background job (non-RAP) | ✅ Yes — after each package |
| RAP-managed scenario | ❌ No — framework manages commit boundaries |
| Inside `MODIFY ENTITIES` | ❌ No — implicit COMMIT only via `SAVE_MODIFIED` |
| Job calling a RAP action via EML | ✅ Yes — `COMMIT ENTITIES` after EML block |

```abap
" Correct: Commit after each package in a classic job
LOOP AT lt_orders INTO DATA(ls_order).
  UPDATE ztable SET status = 'P' WHERE order_id = ls_order-order_id.
ENDLOOP.
COMMIT WORK AND WAIT.   " AND WAIT ensures DB consistency before next package
```

#### Lock escalation prevention

- Never hold exclusive locks across packages
- Use optimistic locking where possible (`ENQUEUE` → process → `DEQUEUE` immediately)
- If using SAP Lock Objects, set `_SCOPE = '1'` (enqueue owner = current work process only)

#### Memory management

```abap
" Free large internal tables after each package
FREE lt_pkg.
CLEAR lt_result.
```

---

### 11. Complete Example — Full Implementation Class (Production Quality)

```abap
"! <p class="shorttext synchronized">Post Open Invoices — Application Job</p>
CLASS zcl_invoice_post_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PRIVATE SECTION.
    CONSTANTS:
      c_package_size TYPE i       VALUE 100,
      c_log_object   TYPE balobj  VALUE 'ZJOB',
      c_log_subobj   TYPE balsubobj VALUE 'INVOICE'.

    DATA mo_log      TYPE REF TO if_bali_log.
    DATA mv_simulate TYPE abap_bool.

    METHODS log_message
      IMPORTING iv_text  TYPE string
                iv_level TYPE balnrchar DEFAULT '1'.

    METHODS post_invoice
      IMPORTING is_invoice TYPE zsalesorder
      RAISING   cx_apj_rt_content.
ENDCLASS.

CLASS zcl_invoice_post_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname = 'P_SIM'   kind = if_apj_dt_exec_object=>c_parameter_kind-selection
        datatype_name = 'ABAP_BOOL'  is_mandatory = abap_false
        default_value = abap_false   text_element = '001' )
      ( selname = 'P_DATFR' kind = if_apj_dt_exec_object=>c_parameter_kind-selection
        datatype_name = 'D' length = 8 is_mandatory = abap_true text_element = '002' )
      ( selname = 'P_DATTO' kind = if_apj_dt_exec_object=>c_parameter_kind-selection
        datatype_name = 'D' length = 8 is_mandatory = abap_true text_element = '003' )
      ( selname = 'P_BUKRS' kind = if_apj_dt_exec_object=>c_parameter_kind-selection
        datatype_name = 'BUKRS'       is_mandatory = abap_false text_element = '004' )
    ).
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.

    " ── Read parameters ────────────────────────────────────────────────
    DATA lv_date_from TYPE d.
    DATA lv_date_to   TYPE d.
    DATA lv_bukrs     TYPE bukrs.

    LOOP AT it_parameters INTO DATA(ls_p).
      CASE ls_p-selname
        WHEN 'P_SIM'.   mv_simulate  = ls_p-low.
        WHEN 'P_DATFR'. lv_date_from = ls_p-low.
        WHEN 'P_DATTO'. lv_date_to   = ls_p-low.
        WHEN 'P_BUKRS'. lv_bukrs     = ls_p-low.
      ENDCASE.
    ENDLOOP.

    IF lv_date_from > lv_date_to.
      RAISE EXCEPTION TYPE cx_apj_rt_content
        EXPORTING textid = cx_apj_rt_content=>parameter_error
                  msgv1  = 'Date range invalid'.
    ENDIF.

    " ── Init log ──────────────────────────────────────────────────────
    mo_log = cl_bali_log=>create_with_header(
      cl_bali_header_setter=>create(
        object      = c_log_object
        subobject   = c_log_subobj
        external_id = |{ lv_date_from }-{ lv_date_to }| ) ).

    log_message( |Start posting. DateFrom={ lv_date_from } To={ lv_date_to }| &
                 COND #( WHEN mv_simulate = abap_true THEN ' [SIMULATION]' ELSE '' ) ).

    " ── Package loop ─────────────────────────────────────────────────
    DATA lv_offset    TYPE i VALUE 0.
    DATA lv_processed TYPE i VALUE 0.
    DATA lv_errors    TYPE i VALUE 0.

    DO.
      SELECT sales_order_id, company_code, net_amount, currency
        FROM zsalesorder
        WHERE creation_date   BETWEEN @lv_date_from AND @lv_date_to
          AND posting_status  = 'O'
          AND ( @lv_bukrs = '' OR company_code = @lv_bukrs )
        ORDER BY sales_order_id
        UP TO @c_package_size ROWS OFFSET @lv_offset
        INTO TABLE @DATA(lt_pkg).

      IF lt_pkg IS INITIAL. EXIT. ENDIF.

      LOOP AT lt_pkg INTO DATA(ls_inv).
        TRY.
            post_invoice( ls_inv ).
            lv_processed += 1.
          CATCH cx_apj_rt_content INTO DATA(lx).
            lv_errors += 1.
            mo_log->add_item( cl_bali_exception_setter=>create(
              severity  = if_bali_constants=>c_severity_error
              exception = lx ) ).
        ENDTRY.
      ENDLOOP.

      " Commit after each package (non-RAP context)
      IF mv_simulate = abap_false.
        COMMIT WORK AND WAIT.
      ENDIF.

      lv_offset += c_package_size.
      IF lines( lt_pkg ) < c_package_size. EXIT. ENDIF.
    ENDDO.

    " ── Final log entry ───────────────────────────────────────────────
    log_message( |Done. OK={ lv_processed } ERR={ lv_errors }| ).

    " Save log linked to the running job
    cl_bali_log_db=>get_instance( )->save_log(
      log                        = mo_log
      assign_to_current_appl_job = abap_true ).

    " Mark job failed if errors
    IF lv_errors > 0 AND lv_processed = 0.
      RAISE EXCEPTION TYPE cx_apj_rt_content
        EXPORTING textid = cx_apj_rt_content=>processing_error
                  msgv1  = |All { lv_errors } records failed|.
    ENDIF.

  ENDMETHOD.

  METHOD log_message.
    mo_log->add_item( cl_bali_free_text_setter=>create(
      severity = if_bali_constants=>c_severity_status
      text     = iv_text ) ).
  ENDMETHOD.

  METHOD post_invoice.
    " Simulate posting logic
    IF mv_simulate = abap_false.
      UPDATE zsalesorder
        SET posting_status = 'P',
            posted_at      = cl_abap_context_info=>get_system_time( )
        WHERE sales_order_id = is_invoice-sales_order_id.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE cx_apj_rt_content
          EXPORTING textid = cx_apj_rt_content=>processing_error
                    msgv1  = is_invoice-sales_order_id
                    msgv2  = 'UPDATE failed'.
      ENDIF.
    ELSE.
      log_message( |SIM: Would post { is_invoice-sales_order_id }| iv_level = '2' ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

---

*End of Application Jobs Complete Reference*
