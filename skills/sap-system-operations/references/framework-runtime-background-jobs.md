# Framework and Runtime Issues — Background Jobs

## §5 — Background Job FAILED / Stuck ACTIVE

**Exception / Symptom:** A scheduled background job shows **FAILED** (red) or is perpetually **ACTIVE** (appears to be running but never completes) in the job monitoring app. The last successful run timestamp is old. No output was produced; downstream processes that depend on the job have stalled.

**Landscapes:** Public Cloud — Application Jobs (APJ / `CL_APJ_*`) · Private Cloud · On-Premise — ABAP Job Scheduler (`SM36`/`SM37`)

---

### Root Cause

| Root Cause ID | Status Seen | Description |
|---------------|-------------|-------------|
| **A** | FAILED | Unhandled exception in the `execute( )` method of the job class; no `TRY/CATCH`; exception propagates to scheduler which marks the job FAILED |
| **B** | ACTIVE (stuck) | Work process crashed, server restarted, or network outage during job execution; scheduler did not receive the job completion signal; job remains ACTIVE indefinitely |
| **C** | FAILED | Job catalog entry or template missing/incomplete after transport; job cannot find its class or parameter definitions |
| **D** | FAILED | Job class `execute( )` method reads typed parameters but parameter type has changed; type mismatch causes runtime error |
| **E** | FAILED | Job class calls `COMMIT WORK` directly; in cloud environments this may conflict with the APJ scheduler's implicit LUW management |

---

### Diagnosis

| Step | Fiori App (Public Cloud) | T-Code (On-Premise / Private Cloud) |
|------|--------------------------|--------------------------------------|
| 1 — Find failed job | **Application Jobs** Fiori app → filter by job template / status | `SM37` → filter by job name / status FAILED |
| 2 — View job log | Select job → *View Log* → read `CL_BALI_LOG` entries | `SM37` → select job → *Job Log* |
| 3 — Short dump | **Analyze ABAP Runtime Errors** → filter by timestamp | `ST22` → filter by timestamp of job failure |
| 4 — Application log | **Application Logs** → filter by job log object | `SLG1` → filter by log object written in `execute( )` |
| 5 — Stuck ACTIVE check | Application Jobs → check *Last Changed* — not updating? → Cancel | `SM37` → check *Started* time vs now; `SM50`/`SM66` to see if WP is running |
| 6 — Work process check | Not directly accessible | `SM50` → check if a WP is consuming CPU for this job's user |
| 7 — Job catalog/template | **Maintain Job Catalogs and Templates** Fiori app | `SE38`/`SE24` → check class exists; `SWI5`/`SM36` → check job definition |

**Distinguishing FAILED (crash) from FAILED (business error):**
- If `ST22` / *Analyze ABAP Runtime Errors* shows a dump at the job's execution time → Root Cause A (unhandled exception → use Fix B below)
- If `SLG1` / *Application Logs* shows business error messages → the job ran to completion but logged errors → the job class itself marked the run as failed
- If neither — the job log in `SM37` or Application Jobs shows only "Job started" and "Job cancelled" with no interim messages → Root Cause B (stuck ACTIVE that was eventually killed) or Root Cause C (configuration)

---

### Fix Pattern (ABAP code)

**Fix A — Cancel a stuck ACTIVE job**

```abap
"════════════════════════════════════════════════════════════════
" Public Cloud — Application Jobs Fiori app:
"   1. Open Application Jobs Fiori app
"   2. Find the stuck ACTIVE job
"   3. Select it → click "Cancel Job" action button
"      (available if the job has been active > expected duration)
"   4. If Cancel is grayed out: raise an incident to SAP Basis /
"      BTP operations to clear the job at framework level
"
" On-Premise (SM37):
"   1. SM37 → find job with status ACTIVE
"   2. Check SM50/SM66 — is a work process still running for it?
"      If YES: let it finish or coordinate with Basis to cancel WP
"      If NO:  job is orphaned
"   3. For orphaned ACTIVE jobs: SM37 → select job →
"      Job menu → Delete  (this removes the job run record)
"   4. Alternatively: SM37 → select job → Job → Cancel Active Job
"      (if the menu option is available for your release)
"════════════════════════════════════════════════════════════════
" Programmatic cancel via APJ API (Public Cloud / Private Cloud):
DATA(lo_apj) = cl_apj_rt_api=>get_instance( ).

TRY.
    lo_apj->cancel_job(
      EXPORTING
        iv_job_id = lv_stuck_job_id ).     " from Application Jobs app

    MESSAGE |Job { lv_stuck_job_id } cancellation requested| TYPE 'S'.

  CATCH cx_apj_rt INTO DATA(lx_apj).
    MESSAGE lx_apj->get_text( ) TYPE 'E'.
ENDTRY.
```

**Fix B — Robust `execute()` implementation with `CL_BALI_LOG` error logging**

```abap
"════════════════════════════════════════════════════════════════
" ✅  Production-ready APJ job class execute() implementation
"     • TRY/CATCH around all business logic
"     • CL_BALI_LOG for structured logging (visible in App Jobs)
"     • Explicit success/failure status written to log
"     • No COMMIT WORK (let APJ framework manage LUW)
"════════════════════════════════════════════════════════════════
CLASS zcl_my_background_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES: if_apj_rt_exec_object.

  PRIVATE SECTION.
    DATA: mo_log        TYPE REF TO if_bali_log,
          mv_log_handle TYPE balloghndl.

ENDCLASS.

CLASS zcl_my_background_job IMPLEMENTATION.

  METHOD if_apj_rt_exec_object~execute.
    "──────────────────────────────────────────────────────────
    " 1. Initialise BAL application log
    "──────────────────────────────────────────────────────────
    mo_log = cl_bali_log=>create_with_header(
               i_object    = 'ZJOB_LOG'
               i_subobject = 'ZMYJOB'
               i_description = |Job run { sy-datum } { sy-uzeit }| ).

    TRY.
        "──────────────────────────────────────────────────────
        " 2. Read typed job parameters safely
        "──────────────────────────────────────────────────────
        DATA(ls_params) = CAST zif_my_job_params(
                            cl_apj_rt_api=>get_parameters( ) ).

        mo_log->add_free_text(
          i_severity = if_bali_constants=>c_severity_info
          i_text     = |Job started with variant: { ls_params->variant_name }| ).

        "──────────────────────────────────────────────────────
        " 3. Business logic — wrap entirely in TRY/CATCH
        "──────────────────────────────────────────────────────
        DATA(lo_processor) = NEW zcl_my_job_processor( ).

        lo_processor->process(
          EXPORTING
            is_params = ls_params->get_params( )
          IMPORTING
            ev_records_processed = DATA(lv_count)
            et_errors            = DATA(lt_errors) ).

        "──────────────────────────────────────────────────────
        " 4. Log business errors (non-fatal) and results
        "──────────────────────────────────────────────────────
        LOOP AT lt_errors INTO DATA(ls_error).
          mo_log->add_free_text(
            i_severity = if_bali_constants=>c_severity_warning
            i_text     = |Record { ls_error-key }: { ls_error-message }| ).
        ENDLOOP.

        mo_log->add_free_text(
          i_severity = if_bali_constants=>c_severity_info
          i_text     = |Processing complete. Records processed: { lv_count }. |
                    && |Errors: { lines( lt_errors ) }.| ).

      CATCH zcx_my_job_config_error INTO DATA(lx_config).
        "──────────────────────────────────────────────────────
        " 5a. Expected configuration error — log and exit cleanly
        "     The job will show FAILED with a readable message
        "──────────────────────────────────────────────────────
        mo_log->add_free_text(
          i_severity = if_bali_constants=>c_severity_error
          i_text     = |Configuration error: { lx_config->get_text( ) }. |
                    && |Check job template parameters.| ).

      CATCH cx_root INTO DATA(lx_unexpected).
        "──────────────────────────────────────────────────────
        " 5b. Unexpected exception — log full details for developer
        "──────────────────────────────────────────────────────
        mo_log->add_free_text(
          i_severity = if_bali_constants=>c_severity_error
          i_text     = |Unexpected error in job execution: |
                    && lx_unexpected->get_text( ) ).

        mo_log->add_free_text(
          i_severity = if_bali_constants=>c_severity_error
          i_text     = |Exception class: { cl_abap_classdescr=>get_class_name(
                            lx_unexpected ) }| ).

    ENDTRY.

    "──────────────────────────────────────────────────────────
    " 6. Persist the log — ALWAYS in CLEANUP to ensure it is
    "    written even if a fatal error bypassed the CATCH blocks
    "──────────────────────────────────────────────────────────
    TRY.
        cl_bali_log_db=>get_instance( )->save_log(
          i_log = mo_log ).
        mv_log_handle = mo_log->get_handle( ).
      CATCH cx_bali_runtime.
        " If even log persistence fails, write to syslog as last resort
        CALL FUNCTION 'SYSTEM_MESSAGE'
          EXPORTING msgty = 'E'
                    msgid = 'SY'
                    msgnr = '499'
                    msgv1 = 'Job log persistence failed'.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
```

**Fix C — Read job log programmatically (for admin utilities or alert integrations)**

```abap
"════════════════════════════════════════════════════════════════
" Read CL_BALI_LOG entries written during execute()
" Useful for: monitoring reports, automatic alerting,
"             post-job result processing
"════════════════════════════════════════════════════════════════
REPORT zr_read_job_log.

PARAMETERS: p_handle TYPE balloghndl.

START-OF-SELECTION.

  TRY.
      " Load the persisted log by its handle
      " (handle is stored in your job run tracking table)
      DATA(lo_log) = cl_bali_log_db=>get_instance( )->load_log(
                       i_log_handle = p_handle ).

      " Iterate over all log items
      DATA(lt_items) = lo_log->get_all_items( ).

      LOOP AT lt_items INTO DATA(lo_item).

        " Cast to free-text or message item and read content
        TRY.
            DATA(lo_msg_item) = CAST if_bali_item_getter( lo_item ).

            DATA(ls_msg_data) = lo_msg_item->get_message( ).

            WRITE: /
              ls_msg_data-timestamp,
              ls_msg_data-severity,    " E/W/I/S
              ls_msg_data-variable_1.  " message text

          CATCH cx_sy_move_cast_error.
            " Item is not a standard message — skip
        ENDTRY.

      ENDLOOP.

    CATCH cx_bali_runtime INTO DATA(lx_bali).
      WRITE: / 'Could not load log:', lx_bali->get_text( ).
  ENDTRY.
```

**Fix D — Job catalog and template registration (Public Cloud / APJ)**

```abap
"════════════════════════════════════════════════════════════════
" Job class must implement IF_APJ_RT_EXEC_OBJECT and be
" registered in the job catalog. This is done via Customizing or
" the Maintain Job Catalogs and Templates Fiori app.
"
" Checklist after transport to verify configuration:
"════════════════════════════════════════════════════════════════
" ✅ Job catalog entry exists:
"    Maintain Job Catalogs → find entry for ZCL_MY_BACKGROUND_JOB
"
" ✅ Job template exists with correct parameter types:
"    Maintain Job Templates → find template → check parameter
"    binding matches current implementation of get_parameters()
"
" ✅ Job class is activated (not inactive/locked):
"    ADT → find ZCL_MY_BACKGROUND_JOB → verify Active state
"
" ✅ Authorization: scheduling user has S_BTCH_JOB authorization
"    object with correct JOBACTION values

" Programmatic check that job class is instantiable:
TRY.
    DATA(lo_test) = NEW zcl_my_background_job( ).
    WRITE: / 'Job class instantiation: OK'.
  CATCH cx_sy_create_object_error INTO DATA(lx_inst).
    WRITE: / 'Job class instantiation FAILED:', lx_inst->get_text( ).
ENDTRY.
```

---

### Landscape Notes

| Aspect | Public Cloud (BTP ABAP / APJ) | Private Cloud / On-Premise |
|--------|-------------------------------|----------------------------|
| Job monitoring app | **Application Jobs** Fiori app | `SM37` + **Application Jobs** Fiori app (if available) |
| Job scheduling | **Application Jobs** Fiori app; `CL_APJ_RT_API` | `SM36` (direct scheduling); `CL_APJ_*` for APJ if configured |
| Job log viewer | Application Jobs → *View Log* (reads `CL_BALI_LOG`) | `SM37` → *Job Log*; `SLG1` for BALI logs |
| Short dump on failure | **Analyze ABAP Runtime Errors** | `ST22` |
| Cancel stuck ACTIVE job | Application Jobs → *Cancel Job* action | `SM37` → Job → Cancel; `SM50` to check WP |
| Work process visibility | Not available to app teams | `SM50` (local), `SM66` (all servers) |
| Job template/catalog management | **Maintain Job Catalogs and Templates** Fiori app | SPRO → SAP Basis → Background Processing; or `SE38` for report-based jobs |
| Maximum job duration setting | Job template → *Duration* field in APJ | `SM36` → job definition → time limit |

> **Public Cloud — no SM37:** There is no `SM37` in the Public Cloud ABAP environment. All job monitoring, log viewing, and cancellation is done via the **Application Jobs** Fiori app. The job log displayed in the app is populated exclusively by `CL_BALI_LOG` entries written in `execute()` — if the job class does not write to `CL_BALI_LOG`, the log will be empty and diagnosis is impossible. This makes `CL_BALI_LOG` implementation **mandatory**, not optional.

> **ACTIVE stuck jobs on Public Cloud:** If the *Cancel Job* button is not available (grayed out) in the Application Jobs app, open a support incident (component `BC-SRV-APS-APJ`) providing the job ID and the timestamp it became stuck. SAP can reset the job status at the framework level. Document the expected maximum job duration in the job template so that the framework can automatically flag jobs that exceed it.

---

### Prevention

- **Always** implement `TRY/CATCH cx_root` in the `execute()` method. An uncaught exception in `execute()` causes an immediate FAILED status with minimal diagnostic information. With the catch block, the job can log detailed error information before exiting gracefully.
- **Always** write to `CL_BALI_LOG` at job start (with variant/parameter summary), at key processing milestones, and at job end (with record counts and error totals). This log is the primary diagnostic tool in the Public Cloud and makes the difference between a 5-minute diagnosis and a 2-hour investigation.
- Set a **maximum duration** in the job template (`if_apj_rt_catalog_entry~get_constraints`): this allows the scheduler to automatically detect and alert on jobs that run longer than expected, surfacing stuck-ACTIVE situations proactively.

---

*End of Framework and Runtime Issues — Production Resolution Guide*
