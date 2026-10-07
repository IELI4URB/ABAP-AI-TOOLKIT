# Framework and Runtime Issues — Production Resolution Guide

> **Scope:** RAP/OData · AIF · HTTP/SOAP Outbound · Background Jobs
> **Applies to:** SAP BTP ABAP Environment (Public Cloud) · S/4HANA Private Cloud · S/4HANA On-Premise
> **Format:** Each section follows — Exception/Symptom → Diagnosis → Fix Pattern → Landscape Notes → Prevention

---

## §1 — OData HTTP 500 / Internal Server Error

**Exception / Symptom:** HTTP 500 returned from OData service endpoint; Fiori app displays generic "An error occurred. Please contact your system administrator." toast or dialog. No actionable field-level message is shown to the user. The backend short dump or gateway error log contains the real cause.

**Landscapes:** Public Cloud (BTP ABAP) · Private Cloud · On-Premise S/4HANA

---

### Root Cause

An ABAP exception propagated upward through the call stack without being caught and converted into a proper OData error response. In RAP-based services the most common causes are:

1. A `RAISE EXCEPTION TYPE cx_*` statement inside a behavior implementation method (validate, determine, action, read, query) that is not caught and re-raised as a RAP message via `REPORTED`/`FAILED`.
2. A class-based exception raised inside a legacy OData handler class (DPC_EXT) that is not caught inside `REDEFINE_*` methods.
3. A missing or incorrectly typed `CX_` hierarchy entry — the framework cannot map the exception to an HTTP error category and falls back to 500.
4. A runtime error (division by zero, field-symbol not assigned, dynamic ASSIGN failing) that was never wrapped.

---

### Diagnosis

| Step | Fiori App (Public Cloud) | T-Code (On-Premise / Private Cloud) |
|------|--------------------------|--------------------------------------|
| 1 — Find the short dump | **Analyze ABAP Runtime Errors** | `ST22` |
| 2 — Filter by time/user | Filter panel → timestamp range + user | `ST22` → Own Dumps / All Dumps → Date+Time filter |
| 3 — Gateway error log | **Application Logs** (object `SXMS_LOG`) | `/IWFND/ERROR_LOG` |
| 4 — OData request trace | **ADT → OData Client** → reproduce call | `/IWFND/TRACES` → set trace level 2 for service |
| 5 — Structured app log | **Application Logs** (object `SBAL`) | `SLG1` → object/sub-object filter |
| 6 — System log | Not directly accessible | `SM21` → filter 60 minutes around incident |

**Reading the gateway error log (On-Premise):**
Navigate to `/IWFND/ERROR_LOG` → select the error timestamp entry → *Display Details* → the *Inner Error* tab shows the original ABAP exception class and message, which is often more informative than ST22 alone.

**Reading OData trace (On-Premise):**
`/IWFND/TRACES` → *Activate Trace* → set trace level **2** (request/response) for the specific user and service → reproduce the error → *Read Trace* → locate the request that returned 500 → expand the response XML to read the `error/innererror` block.

---

### Fix Pattern (ABAP code)

**Fix A — Unhandled exception in RAP validation (incorrect vs. correct pattern)**

```abap
"════════════════════════════════════════════════════════════════
" ❌  WRONG — raises cx_abap_invalid_value; framework cannot
"     convert this to a user-facing message; becomes HTTP 500
"════════════════════════════════════════════════════════════════
METHOD validate_travel.
  IF ls_travel-agency_id IS INITIAL.
    RAISE EXCEPTION TYPE cx_abap_invalid_value.   " HTTP 500
  ENDIF.
ENDMETHOD.


"════════════════════════════════════════════════════════════════
" ✅  CORRECT — use REPORTED + FAILED; framework converts these
"     into a structured OData error response (HTTP 422 / 400)
"     with field-level highlighting in the Fiori UI
"════════════════════════════════════════════════════════════════
METHOD validate_travel.
  " Read active/draft entities passed to validation
  READ ENTITIES OF zi_travel_tp IN LOCAL MODE
    ENTITY Travel
      ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_travel)
    FAILED DATA(lt_read_failed).

  LOOP AT lt_travel INTO DATA(ls_travel).

    " ── Validation rule 1: Agency ID must be filled ──────────
    IF ls_travel-agency_id IS INITIAL.
      APPEND VALUE #(
        %tky              = ls_travel-%tky
        %msg              = new_message_with_text(
                              severity = if_abap_behv_message=>severity-error
                              text     = 'Agency ID is required' )
        %element-agency_id = if_abap_behv=>mk-on     " highlights field in UI
      ) TO reported-travel.

      APPEND VALUE #( %tky = ls_travel-%tky ) TO failed-travel.
    ENDIF.

    " ── Validation rule 2: Begin date must precede end date ──
    IF ls_travel-begin_date >= ls_travel-end_date.
      APPEND VALUE #(
        %tky                = ls_travel-%tky
        %msg                = new_message(
                                id       = 'ZTRAVEL_MSG'
                                number   = '002'
                                severity = if_abap_behv_message=>severity-error
                                v1       = ls_travel-begin_date
                                v2       = ls_travel-end_date )
        %element-begin_date = if_abap_behv=>mk-on
        %element-end_date   = if_abap_behv=>mk-on
      ) TO reported-travel.

      APPEND VALUE #( %tky = ls_travel-%tky ) TO failed-travel.
    ENDIF.

  ENDLOOP.
ENDMETHOD.
```

**Fix B — Catching unexpected exceptions in a RAP action (defensive wrapper)**

```abap
METHOD execute_approve.
  TRY.
      " ... business logic here ...
      MODIFY ENTITIES OF zi_travel_tp IN LOCAL MODE
        ENTITY Travel
          UPDATE FIELDS ( overall_status )
          WITH VALUE #( (
            %tky           = keys[ 1 ]-%tky
            overall_status = 'A'
          ) )
        FAILED   failed
        REPORTED reported.

    CATCH cx_sy_zerodivide
          cx_sy_ref_is_initial
          cx_abap_invalid_value
          INTO DATA(lx_unexpected).

      " Convert technical exception → RAP user message
      APPEND VALUE #(
        %tky = keys[ 1 ]-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-error
                 text     = |Unexpected error: { lx_unexpected->get_text( ) }| )
      ) TO reported-travel.

      APPEND VALUE #( %tky = keys[ 1 ]-%tky ) TO failed-travel.
  ENDTRY.
ENDMETHOD.
```

**Fix C — Temporarily enable detailed OData error response (On-Premise)**

```abap
" This is a profile-level setting, not code — for reference:
" /IWFND/TRACES → Add entry:
"   System Alias : LOCAL
"   Service Name : <your service, e.g. ZTRAVEL_SRV>
"   User         : <reproducing user or *>
"   Trace Level  : 2
"
" After reproducing, navigate to Read Trace and look for:
"   <error>
"     <code>...</code>
"     <message>...</message>
"     <innererror>
"       <errordetails> ← field-level errors from REPORTED
"     </innererror>
"   </error>
```

---

### Landscape Notes

| Aspect | Public Cloud (BTP ABAP) | Private Cloud / On-Premise |
|--------|-------------------------|----------------------------|
| Short dump viewer | *Analyze ABAP Runtime Errors* Fiori app | `ST22` |
| Gateway error log | *Application Logs* (`/IWFND/` log objects) | `/IWFND/ERROR_LOG` |
| OData trace | ADT OData Client → reproduce with verbose output | `/IWFND/TRACES` level 2 |
| Direct system log access | Not available to app teams | `SM21` |
| Error response verbosity | Controlled by system profile `icm/HTTP/error_handling_mode` | Same + `/IWFND/` service settings |

> **Public Cloud note:** Direct access to `/IWFND/TRACES` is restricted. Use the *ADT OData Client* (Eclipse) to replay the failing request; ADT displays the full error XML including `innererror/errordetails`. Alternatively, activate *Application Log* writing in the behavior implementation for persistent diagnostic output.

---

### Prevention

- **Never** let a `RAISE EXCEPTION` escape a RAP method unhandled. Establish a team coding rule: every behavior implementation method that calls external code must have a `CATCH cx_root` safety net that maps to `REPORTED`.
- Add ABAP Unit tests for all validators. A validator that only uses `REPORTED`/`FAILED` is trivially testable with `cl_abap_behv_test_environment`.
- Register the application in `SLG1`/Application Logs so that warnings are written before exceptions occur, giving a breadcrumb trail.
- In CI/CD pipelines, run ATC check `RAP_BO_EXCEPTION_HANDLING` (if available in your release) to flag unprotected exception paths statically.

---

---

## §2 — RAP Draft Activation Failure / Action Error

**Exception / Symptom:** User clicks *Save* (draft activation) or an action button in a Fiori Elements app → an error dialog or toast appears but the message is generic ("An internal error occurred", "Action could not be executed", "Object is locked by another user"). No field is highlighted. The draft remains open and unsaved, or the action silently has no effect.

**Landscapes:** Public Cloud (BTP ABAP) · Private Cloud · On-Premise S/4HANA (RAP with managed or unmanaged draft)

---

### Root Cause

| Root Cause ID | Description |
|---------------|-------------|
| **A** | Validation or determination method appends to `FAILED` but omits the corresponding `REPORTED` entry → framework has no user-readable message to display, falls back to generic text |
| **B** | `COMMIT ENTITIES` fails due to a lock collision (another user's draft on the same key) or a database constraint violation (unique index, foreign key) |
| **C** | Stale draft table entry — a draft was never discarded (e.g. app crashed mid-session); the key is locked in the draft table (`ZTRAVELTP_D` or equivalent) but no active session holds it |
| **D** | An action implementation raises a non-RAP exception or calls `COMMIT WORK` directly inside the RAP transaction, corrupting the implicit save sequence |
| **E** | Draft is enabled on the BO but the draft table is missing or has an incompatible structure after a transport |

---

### Diagnosis

| Step | Fiori App (Public Cloud) | T-Code (On-Premise / Private Cloud) |
|------|--------------------------|--------------------------------------|
| 1 — Check REPORTED content | Enable *Application Logs* write in behavior class; read in *Application Logs* Fiori app | `SLG1` → object written by behavior class |
| 2 — Short dump | **Analyze ABAP Runtime Errors** | `ST22` |
| 3 — Lock table inspection | **Draft Administration** Fiori app | `SM12` → check for lock entries on draft table |
| 4 — Draft table content | Direct SQL read via ABAP (ADT Data Preview) | `SE16` / `SE16N` → open draft table (e.g. `ZTRAVEL_D`) |
| 5 — App log from action | **Application Logs** | `SLG1` → sub-object = action/validation name |
| 6 — Gateway error log | **Application Logs** | `/IWFND/ERROR_LOG` |

**Identifying a FAILED-without-REPORTED situation:**
In On-Premise `/IWFND/ERROR_LOG`, if the `<errordetails>` block inside `<innererror>` is empty but the HTTP status is 4xx, the behavior class is appending `FAILED` without a matching `REPORTED` entry.

---

### Fix Pattern (ABAP code)

**Fix A — Always pair FAILED and REPORTED (mandatory pattern)**

```abap
"════════════════════════════════════════════════════════════════
" ❌  WRONG — FAILED is set but REPORTED is not; Fiori receives
"     no message text → shows generic error
"════════════════════════════════════════════════════════════════
METHOD validate_booking.
  LOOP AT keys INTO DATA(ls_key).
    IF <booking>-flight_price <= 0.
      APPEND VALUE #( %tky = ls_key-%tky ) TO failed-booking.
      " ← missing REPORTED entry!
    ENDIF.
  ENDLOOP.
ENDMETHOD.


"════════════════════════════════════════════════════════════════
" ✅  CORRECT — every FAILED entry has exactly one REPORTED entry
"════════════════════════════════════════════════════════════════
METHOD validate_booking.
  READ ENTITIES OF zi_travel_tp IN LOCAL MODE
    ENTITY Booking
      ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(lt_booking).

  LOOP AT lt_booking INTO DATA(ls_booking).

    IF ls_booking-flight_price <= 0.
      " 1️⃣  User-visible message
      APPEND VALUE #(
        %tky                  = ls_booking-%tky
        %msg                  = new_message(
                                  id       = 'ZTRAVEL_MSG'
                                  number   = '010'
                                  severity = if_abap_behv_message=>severity-error )
        %element-flight_price = if_abap_behv=>mk-on  " field highlighting
      ) TO reported-booking.

      " 2️⃣  Failure marker (always add AFTER reported)
      APPEND VALUE #( %tky = ls_booking-%tky ) TO failed-booking.
    ENDIF.

    IF ls_booking-carrier_id IS INITIAL.
      APPEND VALUE #(
        %tky               = ls_booking-%tky
        %msg               = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Carrier ID must be provided' )
        %element-carrier_id = if_abap_behv=>mk-on
      ) TO reported-booking.
      APPEND VALUE #( %tky = ls_booking-%tky ) TO failed-booking.
    ENDIF.

  ENDLOOP.
ENDMETHOD.
```

**Fix B — Programmatic discard of stale draft (admin/recovery)**

```abap
"════════════════════════════════════════════════════════════════
" Use when a draft is stuck and cannot be discarded via the UI
" (e.g. app crashed, browser tab closed without discard)
" Run as a one-off utility report or from an admin action
"════════════════════════════════════════════════════════════════
REPORT zr_discard_stale_draft.

PARAMETERS: p_trvid TYPE /dmo/travel_id.

START-OF-SELECTION.

  " Discard the draft for the given travel ID
  MODIFY ENTITIES OF zi_travel_tp
    ENTITY Travel
    EXECUTE Discard
    FROM VALUE #( ( TravelID = p_trvid ) )
    FAILED   DATA(lt_failed)
    REPORTED DATA(lt_reported).

  COMMIT ENTITIES
    RESPONSE OF zi_travel_tp
    FAILED   DATA(lt_commit_failed)
    REPORTED DATA(lt_commit_reported).

  IF lt_failed IS INITIAL AND lt_commit_failed IS INITIAL.
    MESSAGE 'Draft discarded successfully' TYPE 'S'.
  ELSE.
    " Report all messages from lt_reported + lt_commit_reported
    LOOP AT lt_commit_reported-travel INTO DATA(ls_msg).
      MESSAGE ls_msg-%msg->if_message~get_text( ) TYPE 'E'.
    ENDLOOP.
  ENDIF.
```

**Fix C — Prevent COMMIT WORK inside RAP action (critical rule)**

```abap
"════════════════════════════════════════════════════════════════
" ❌  WRONG — explicit COMMIT WORK inside RAP action corrupts
"     the implicit save sequence; can cause partial saves,
"     lock issues, and draft activation failures
"════════════════════════════════════════════════════════════════
METHOD execute_submit_travel.
  UPDATE ztraveldb SET status = 'S' WHERE travel_id = ls_key-travelid.
  COMMIT WORK.   " ← NEVER do this in a RAP method
ENDMETHOD.


"════════════════════════════════════════════════════════════════
" ✅  CORRECT — use MODIFY ENTITIES; let the RAP framework
"     handle the commit via COMMIT ENTITIES at the caller level
"════════════════════════════════════════════════════════════════
METHOD execute_submit_travel.
  MODIFY ENTITIES OF zi_travel_tp IN LOCAL MODE
    ENTITY Travel
      UPDATE FIELDS ( overall_status )
      WITH VALUE #( (
        %tky           = keys[ 1 ]-%tky
        overall_status = 'S'   " Submitted
      ) )
    FAILED   failed
    REPORTED reported.
ENDMETHOD.
```

**Fix D — Identifying a lock collision programmatically**

```abap
" Check if a draft lock exists before attempting activation
" Useful in batch / migration scenarios
DATA(lv_lock_key) = CONV sesenqkey( |ZTRAVEL_TP{ lv_travel_id }| ).

CALL FUNCTION 'ENQUEUE_READ'
  EXPORTING
    garg    = lv_lock_key
  IMPORTING
    number  = DATA(lv_lock_count).

IF lv_lock_count > 0.
  " Another session holds the draft lock — do not attempt activation
  MESSAGE 'Draft is locked by another session' TYPE 'W'.
ENDIF.
```

---

### Landscape Notes

| Aspect | Public Cloud (BTP ABAP) | Private Cloud / On-Premise |
|--------|-------------------------|----------------------------|
| Lock table viewer | **Draft Administration** Fiori app | `SM12` → table `<BO_DRAFT_TABLE>` |
| Draft cleanup (UI) | *Draft Administration* Fiori app → select stuck draft → *Discard* | `SM12` → delete lock + `SE16N` → delete draft row (last resort) |
| Draft cleanup (code) | `MODIFY ENTITIES … EXECUTE Discard` + `COMMIT ENTITIES` | Same ABAP pattern, or direct table delete in emergency |
| Lock type | Enqueue via RAP framework (no SM12 in Public Cloud) | Standard ABAP enqueue visible in SM12 |
| Draft table location | Managed by framework; accessible via ADT Data Preview | Accessible via `SE16N` on `<entity>_D` table |

> **Public Cloud — no SM12:** There is no `SM12` transaction in the Public Cloud. Stuck draft locks must be resolved via the **Draft Administration** Fiori app (search for *Draft Administration* in the Fiori Launchpad) or programmatically via `EXECUTE Discard`. If neither works, open an incident with SAP to have the lock cleared at the framework level.

---

### Prevention

- Establish a code review rule: every `APPEND … TO failed-*` must be immediately preceded or followed by a matching `APPEND … TO reported-*`. Consider an ABAP formatter / ATC rule to enforce this.
- Implement `FINALIZE` and `CHECK_BEFORE_SAVE` handlers that validate completeness of the draft entity before activation, rather than relying on the generic OData error.
- Set an appropriate draft expiry time in the behavior definition (`draft determine action Prepare`) so that abandoned drafts are auto-expired.
- Never call `COMMIT WORK`, `ROLLBACK WORK`, or direct DML (`INSERT`, `UPDATE`, `DELETE`) inside RAP behavior methods. Use `MODIFY ENTITIES` exclusively.

---

---

## §3 — AIF Message in Error Status / Stuck Queue

**Exception / Symptom:** SAP Application Interface Framework (AIF) interface monitor displays messages with status **ERROR** or **QUEUED** (stuck, not being processed). The interface pipeline has stalled; downstream system is not receiving data. Operations team receives alert or discovers backlog on morning check.

**Landscapes:** On-Premise S/4HANA · Private Cloud (AIF installed) · Public Cloud (limited AIF availability; SAP Integration Suite often used instead — see Landscape Notes)

---

### Root Cause

| Root Cause ID | Type | Description |
|---------------|------|-------------|
| **A** | Data error | Wrong, missing, or out-of-range field value in the message payload; AIF mapping or validation BAdI rejects the message |
| **B** | Connectivity error | Target system unavailable (RFC/HTTP timeout, destination unreachable); message processed but delivery failed |
| **C** | Code error | Custom BAdI implementation raised an unhandled exception during processing |
| **D** | Configuration error | Namespace/structure version mismatch between sender and AIF interface definition; message cannot be deserialized |
| **E** | Queue saturation | High message volume or previous processing failure caused queue backlog; messages are valid but not yet processed |

---

### Diagnosis

| Step | Fiori App (Public Cloud / Private Cloud) | T-Code (On-Premise) |
|------|------------------------------------------|----------------------|
| 1 — Open interface monitor | **Interface Monitor** Fiori app (`/AIF/IFMON` Fiori equivalent) | `/AIF/IFMON` |
| 2 — Filter by interface/date | Use filter panel: Namespace, Interface Name, Version, Date range, Status = ERROR | Same filter options in `/AIF/IFMON` |
| 3 — Read error detail | Select failed message → *Error Log* tab → read exception class + message | Select message → *Error Info* → read error text and stack |
| 4 — Distinguish data vs. system error | Data error: error in mapping/validation step; System error: error in send/deliver step | Same — note which processing step failed |
| 5 — Check queue status | **Queue Monitor** Fiori app | `/AIF/QMON` |
| 6 — Check RFC/HTTP destination | Communication Arrangements (cloud) | `SM59` → connection test |
| 7 — Check custom BAdI code | ADT → find BAdI implementation class | `SE18`/`SE19` → locate BAdI impl |

**Reading error detail in `/AIF/IFMON`:**
Select a failed message → click *Error Log* (bottom panel). The log entry shows:
- **Error Class:** the exception class (e.g. `CX_AIF_MAPPING_ERROR`, custom `ZCX_*`)
- **Error Text:** the exception message text
- **Processing Step:** which AIF step failed (Mapping, Validation, Send, Post)
- **Stack Trace:** (if a dump occurred) link to ST22

---

### Fix Pattern (ABAP code)

**Fix A — Reprocess a correctable data error message**

```abap
"════════════════════════════════════════════════════════════════
" Option 1 (preferred for single messages):
" No code needed — use the AIF message editor
"
" /AIF/IFMON or Interface Monitor Fiori app:
"   1. Select the failed message
"   2. Click "Edit Message" (pencil icon)
"   3. Correct the offending field value
"   4. Click "Reprocess" (green arrow)
"
" This is the recommended path for business-user-correctable
" data errors (wrong cost center, missing plant code, etc.)
"════════════════════════════════════════════════════════════════


"════════════════════════════════════════════════════════════════
" Option 2 — Programmatic reprocess (for batch recovery scripts
" or when messages must be corrected and reprocessed en masse)
"════════════════════════════════════════════════════════════════
REPORT zr_aif_reprocess.

PARAMETERS:
  p_ns      TYPE /aif/namespace   DEFAULT '/ZNAM/',
  p_ifname  TYPE /aif/ifname      DEFAULT 'ZINTERFACE',
  p_ifver   TYPE /aif/ifversion   DEFAULT 1,
  p_guid    TYPE /aif/msg_guid.

START-OF-SELECTION.

  " Get the AIF message API instance
  DATA(lo_api) = cl_aif_message_api=>get_instance( ).

  TRY.
      " Reprocess the message identified by its GUID
      lo_api->reprocess_message(
        EXPORTING
          iv_namespace  = p_ns
          iv_ifname     = p_ifname
          iv_ifversion  = p_ifver
          iv_msg_guid   = p_guid ).

      MESSAGE |Message { p_guid } submitted for reprocessing| TYPE 'S'.

    CATCH cx_aif_api_error INTO DATA(lx_aif).
      MESSAGE lx_aif->get_text( ) TYPE 'E'.
  ENDTRY.
```

**Fix B — Catching exceptions in a custom AIF BAdI implementation (prevention of Root Cause C)**

```abap
"════════════════════════════════════════════════════════════════
" ❌  WRONG — unhandled exception in BAdI causes message ERROR
"     status with no useful error text; the exception class name
"     appears in the AIF error log but no corrective info is given
"════════════════════════════════════════════════════════════════
METHOD if_aif_application_check~check.
  DATA(lo_service) = NEW zcl_vendor_service( ).
  lo_service->validate( iv_vendor_id = is_payload-vendor_id ).
  " ← if validate( ) raises ZCX_VENDOR_NOT_FOUND, message → ERROR
ENDMETHOD.


"════════════════════════════════════════════════════════════════
" ✅  CORRECT — catch expected exceptions; write to AIF message log
"     so the operator sees a meaningful error and can correct/retry
"════════════════════════════════════════════════════════════════
METHOD if_aif_application_check~check.
  TRY.
      DATA(lo_service) = NEW zcl_vendor_service( ).
      lo_service->validate( iv_vendor_id = is_payload-vendor_id ).

    CATCH zcx_vendor_not_found INTO DATA(lx_vendor).
      " Write correctable error to AIF message log
      " The operator will see this text in the Error Log tab
      mo_msg_log->add_msg(
        EXPORTING
          iv_msg_type = /aif/if_aif_message_log=>gc_msg_type_error
          iv_msg_text = |Vendor { is_payload-vendor_id } not found in system. |
                     && |Please correct vendor ID and reprocess.|
          iv_msg_class = 'ZVENDOR'
          iv_msg_no    = '001' ).

      " Set return code so AIF marks message as ERROR (not DONE)
      ev_check_passed = abap_false.

    CATCH cx_root INTO DATA(lx_unexpected).
      " Unexpected technical error — log details for developer
      mo_msg_log->add_msg(
        EXPORTING
          iv_msg_type = /aif/if_aif_message_log=>gc_msg_type_error
          iv_msg_text = |Technical error in vendor validation: |
                     && lx_unexpected->get_text( ) ).

      ev_check_passed = abap_false.
  ENDTRY.
ENDMETHOD.
```

**Fix C — Restart a stuck queue after connectivity is restored**

```abap
"════════════════════════════════════════════════════════════════
" Via transaction (On-Premise / Private Cloud):
"   /AIF/QMON → Queue Monitor
"   → Filter by Interface / Status = STUCK or WAITING
"   → Select queue entries
"   → Click "Restart Queue" button
"
" Programmatic queue restart (for automation / post-failover):
"════════════════════════════════════════════════════════════════
REPORT zr_aif_restart_queue.

PARAMETERS:
  p_ns     TYPE /aif/namespace DEFAULT '/ZNAM/',
  p_ifname TYPE /aif/ifname    DEFAULT 'ZINTERFACE',
  p_ifver  TYPE /aif/ifversion DEFAULT 1.

START-OF-SELECTION.

  TRY.
      " Restart all waiting/stuck queue items for the interface
      /aif/cl_queue_api=>restart_queue(
        EXPORTING
          iv_namespace  = p_ns
          iv_ifname     = p_ifname
          iv_ifversion  = p_ifver ).

      MESSAGE 'Queue restart triggered' TYPE 'S'.

    CATCH /aif/cx_queue_error INTO DATA(lx_q).
      MESSAGE lx_q->get_text( ) TYPE 'E'.
  ENDTRY.
```

**Fix D — Configuring AIF alert for automatic error notification**

```abap
"════════════════════════════════════════════════════════════════
" AIF alert configuration is done via Customizing (no direct ABAP
" required), but the relevant path is:
"
" SPRO → SAP Application Interface Framework
"        → Error Handling → Define Alerts
"        → Assign Alert to Interface
"
" Alert types available:
"   • Email notification to responsible team
"   • System message / workflow item
"   • Connection to SAP Alert Framework (/SALERT/)
"
" Programmatic check of alert status (for monitoring reports):
"════════════════════════════════════════════════════════════════
DATA(lo_alert_api) = cl_aif_alert_api=>get_instance( ).

DATA(lt_alerts) = lo_alert_api->get_open_alerts(
  iv_namespace = '/ZNAM/'
  iv_ifname    = 'ZINTERFACE' ).

IF lt_alerts IS NOT INITIAL.
  " Send summary to operations team distribution list
  LOOP AT lt_alerts INTO DATA(ls_alert).
    WRITE: / ls_alert-alert_id, ls_alert-alert_text, ls_alert-created_at.
  ENDLOOP.
ENDIF.
```

---

### Landscape Notes

| Aspect | Public Cloud (BTP ABAP) | Private Cloud (AIF installed) | On-Premise |
|--------|-------------------------|-------------------------------|------------|
| AIF availability | Limited / not standard — use **SAP Integration Suite** (CPI) for new integrations | Available if installed | Full AIF available |
| Interface Monitor | **Interface Monitor** Fiori app | `/AIF/IFMON` + Fiori app | `/AIF/IFMON` |
| Queue Monitor | **Queue Monitor** Fiori app | `/AIF/QMON` + Fiori app | `/AIF/QMON` |
| Lock entries | Not accessible directly | `SM12` (if applicable) | `SM12` |
| Message editor | Fiori app *Edit Message* | Fiori app or `/AIF/IFMON` | `/AIF/IFMON` |
| RFC destination check | Communication Arrangements | `SM59` | `SM59` |
| Recommended new integrations | SAP Integration Suite (CPI flows) | AIF or Integration Suite | AIF |

> **Public Cloud — AIF vs. Integration Suite:** For greenfield Public Cloud implementations, SAP recommends **SAP Integration Suite** (Cloud Integration / CPI) for process-to-process integration rather than AIF. AIF may still be present via compatibility add-ons or private cloud extensions. For monitoring CPI flows: **Integration Operations** monitoring app in the BTP Integration Suite cockpit. Error handling and reprocess patterns differ from AIF — use the *Integration Flow Monitor* and *Message Processing Log* instead.

---

### Prevention

- Implement and test all BAdI methods with `TRY/CATCH cx_root` wrappers. Write meaningful error text to the AIF message log so that operators can self-service correct and reprocess without developer involvement.
- Configure AIF alerts (SPRO) to send email notifications to the interface operations team immediately when a message enters ERROR status — do not rely on manual monitoring.
- For connectivity-type errors (B), implement a retry scheduler: configure the AIF queue to auto-retry N times with a backoff interval before alerting. This avoids false alarms during short target-system maintenance windows.
- Maintain a **Message Error Catalog** in your operations wiki: for each interface, document the top 10 expected data errors, their AIF error text pattern, and the correction steps. This enables Level 1 support to resolve without developer escalation.
- After any transport that changes AIF interface structure or version, run a smoke-test message through the interface in the target system before declaring the transport complete.

---

---

## §4 — HTTP Outbound: 401 Unauthorized / 403 Forbidden / Timeout

**Exception / Symptom:** An outbound HTTP call from ABAP to an external system fails. The ABAP exception `CX_WEB_HTTP_CLIENT_ERROR` is raised, or the response status code is 401, 403, 408, 503, or 504. The interface stops working after a weekend or after a password rotation. No data reaches the target system; downstream process stalls.

**Landscapes:** Public Cloud (BTP ABAP) · Private Cloud · On-Premise S/4HANA

---

### Root Cause

| Status | Root Cause | Typical Trigger |
|--------|-----------|-----------------|
| **401** | Authentication failed — credentials rejected | Password rotated in target system; OAuth token expired; wrong username in destination |
| **403** | Authenticated but not authorized for the resource | Service user missing role/scope in target; IP allowlist changed; API key revoked |
| **408 / 504** | Request timeout | Target system under load; network latency spike; connection pool exhausted |
| **503** | Service unavailable | Target system in maintenance; load balancer returning 503 |
| `CX_WEB_HTTP_CLIENT_ERROR` (network) | TCP connection refused or DNS failure | Destination host unreachable; firewall rule change; wrong port in destination config |

**Most common real-world cause:** An OAuth2 client credentials flow token is cached and used beyond its expiry (`expires_in`). Over a weekend the token expires, the first Monday-morning call returns 401, and the interface appears to have "stopped working by itself."

---

### Diagnosis

| Step | Fiori App (Public Cloud) | T-Code (On-Premise / Private Cloud) |
|------|--------------------------|--------------------------------------|
| 1 — Confirm status code | Read from exception / log | Read from `lo_response->get_status( )-code` in error log / ST22 |
| 2 — Test destination manually | **Communication Arrangements** Fiori app → select arrangement → *Check Connection* | `SM59` → select destination → *Connection Test* |
| 3 — Check service user (401) | **Communication Arrangements** → service user → check locked/expired | `SU01` → check user status; `SM59` → Logon & Security tab |
| 4 — Check authorization (403) | Target system admin: check role/scope assigned to service user | Target system: `SU53` for the service user; check API gateway authorization |
| 5 — Check network timeout | BTP Connectivity service logs; check target system response time | `SMICM` → *Goto → Active Services* to verify ICM; network team |
| 6 — App log of HTTP call | **Application Logs** Fiori app | `SLG1` → filter by interface application log object |

---

### Fix Pattern (ABAP code)

**Fix A — Complete HTTP client with status-code-based error routing**

```abap
"════════════════════════════════════════════════════════════════
" Production-grade outbound HTTP call with explicit status routing
" Uses IF_WEB_HTTP_CLIENT (Public Cloud compatible)
"════════════════════════════════════════════════════════════════
METHOD call_external_service.

  DATA: lo_client   TYPE REF TO if_web_http_client,
        lo_response TYPE REF TO if_web_http_response,
        lv_status   TYPE i,
        lv_body     TYPE string.

  TRY.
      " ── Create HTTP client from destination ──────────────────
      " On Public Cloud: destination = Communication Arrangement
      " On-Premise:      destination = SM59 RFC/HTTP destination
      DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                        comm_scenario = 'ZEXTERNAL_SYSTEM_CS'
                        service_id    = 'ZEXTERNAL_HTTP_SRV'  ).

      lo_client = cl_web_http_client_manager=>create_by_http_destination(
                    i_destination = lo_dest ).

      " ── Set headers and request body ─────────────────────────
      lo_client->get_http_request( )->set_header_fields(
        VALUE #(
          ( name = 'Content-Type' value = 'application/json' )
          ( name = 'Accept'       value = 'application/json' )
        ) ).

      lo_client->get_http_request( )->set_text( iv_text ).

      " ── Execute and route on status code ─────────────────────
      lo_response = lo_client->execute( if_web_http_client=>post ).
      lv_status   = lo_response->get_status( )-code.

      CASE lv_status.

        WHEN 200 OR 201 OR 204.
          " Success
          IF lv_status <> 204.  " 204 = No Content
            lv_body = lo_response->get_text( ).
          ENDIF.
          ev_response_body = lv_body.

        WHEN 400.
          " Bad Request — our payload is malformed; do not retry
          DATA(lv_err_body) = lo_response->get_text( ).
          RAISE EXCEPTION TYPE zcx_http_bad_request
            EXPORTING
              status_code   = lv_status
              response_body = lv_err_body.

        WHEN 401.
          " Unauthorized — token/credential issue
          " Alert operations; do NOT retry immediately (will lock account)
          me->write_app_log(
            iv_severity = 'E'
            iv_text     = |HTTP 401 from { iv_endpoint }: |
                       && |credentials rejected. Manual intervention required.| ).

          RAISE EXCEPTION TYPE zcx_http_auth_error
            EXPORTING status_code = lv_status.

        WHEN 403.
          " Forbidden — authenticated but no authorization for resource
          me->write_app_log(
            iv_severity = 'E'
            iv_text     = |HTTP 403 from { iv_endpoint }: |
                       && |service user lacks authorization for this resource.| ).

          RAISE EXCEPTION TYPE zcx_http_forbidden
            EXPORTING status_code = lv_status.

        WHEN 408 OR 502 OR 503 OR 504.
          " Transient error — safe to retry with exponential backoff
          RAISE EXCEPTION TYPE zcx_http_transient_error
            EXPORTING
              status_code = lv_status
              retry_after = COND #( WHEN lv_status = 503
                                    THEN CONV i(
                                           lo_response->get_header_field( 'Retry-After' ) )
                                    ELSE 30 ).

        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_http_call_failed
            EXPORTING
              status_code   = lv_status
              response_body = lo_response->get_text( ).

      ENDCASE.

    CATCH cx_web_http_client_error INTO DATA(lx_http).
      " Network-level failure (TCP refused, DNS error, TLS error)
      me->write_app_log(
        iv_severity = 'E'
        iv_text     = |HTTP client error connecting to { iv_endpoint }: |
                   && lx_http->get_text( ) ).

      RAISE EXCEPTION TYPE zcx_connectivity_error
        EXPORTING previous = lx_http.

    CLEANUP.
      " Always release the HTTP client to avoid connection pool exhaustion
      IF lo_client IS BOUND.
        lo_client->close( ).
      ENDIF.
  ENDTRY.

ENDMETHOD.
```

**Fix B — OAuth2 token refresh via Communication Arrangement (Public Cloud — never hardcode tokens)**

```abap
"════════════════════════════════════════════════════════════════
" ✅  CORRECT — let the Communication Arrangement / BTP
"     Destination Service manage token lifecycle automatically.
"     cl_http_destination_provider handles token caching and
"     refresh transparently when the destination is typed as
"     OAuth2 Client Credentials in the Communication Arrangement.
"════════════════════════════════════════════════════════════════
DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                  comm_scenario = 'ZEXTERNAL_OAUTH_CS'
                  service_id    = 'ZEXTERNAL_OAUTH_SRV' ).
" The framework fetches and caches the token automatically.
" Token refresh on expiry is handled by the framework — no
" manual token management needed.
DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                    i_destination = lo_dest ).


"════════════════════════════════════════════════════════════════
" ❌  WRONG — manual token fetch and caching in a static variable
"     Token will expire and calls will return 401 until restart
"════════════════════════════════════════════════════════════════
" CLASS-DATA: gv_token TYPE string,
"             gv_token_expiry TYPE timestamp.
"
" IF sy-uzeit > gv_token_expiry.  " ← unreliable; use framework!
"   gv_token = fetch_new_oauth_token( ).
" ENDIF.
" lo_request->set_header_field( name = 'Authorization'
"                                value = |Bearer { gv_token }| ).
```

**Fix C — Retry with exponential backoff for transient errors**

```abap
METHOD call_with_retry.

  CONSTANTS: c_max_retries TYPE i VALUE 3,
             c_base_wait   TYPE i VALUE 5.   " seconds

  DATA: lv_attempt    TYPE i VALUE 1,
        lv_wait_secs  TYPE i.

  DO c_max_retries TIMES.
    lv_attempt = sy-index.

    TRY.
        me->call_external_service(
          EXPORTING iv_endpoint      = iv_endpoint
                    iv_text          = iv_request_body
          IMPORTING ev_response_body = DATA(lv_response) ).

        " Success — exit retry loop
        ev_response_body = lv_response.
        RETURN.

      CATCH zcx_http_transient_error INTO DATA(lx_transient).
        IF lv_attempt < c_max_retries.
          " Exponential backoff: 5s, 10s, 20s
          lv_wait_secs = c_base_wait * ( 2 ** ( lv_attempt - 1 ) ).
          me->write_app_log(
            iv_severity = 'W'
            iv_text     = |Transient HTTP { lx_transient->status_code } — |
                       && |retry { lv_attempt }/{ c_max_retries } |
                       && |in { lv_wait_secs }s| ).
          WAIT UP TO lv_wait_secs SECONDS.
        ELSE.
          " Max retries exhausted — re-raise for caller to handle
          RAISE EXCEPTION lx_transient.
        ENDIF.

      CATCH zcx_http_auth_error
            zcx_http_forbidden
            zcx_http_bad_request
            zcx_connectivity_error.
        " Non-transient errors — do not retry; re-raise immediately
        RAISE.
    ENDTRY.
  ENDDO.

ENDMETHOD.
```

---

### Landscape Notes

| Aspect | Public Cloud (BTP ABAP) | Private Cloud / On-Premise |
|--------|-------------------------|----------------------------|
| Destination management | **Communication Arrangements** Fiori app | `SM59` (HTTP destinations) |
| Credential update (401) | Communication Arrangements → select arrangement → update service user credentials | `SM59` → destination → *Logon & Security* tab → update password |
| Service user lock check | **Communication Arrangements** → service user → check active/locked | `SU01` → user → check locked/password expired |
| OAuth2 token management | Framework handles via Communication Arrangement type = OAuth2 | Custom token management via `CL_HTTP_UTILITY` or ABAP OAuth library |
| Timeout configuration | Communication Arrangement connection timeout settings | `SM59` → *Special Options* → timeout values |
| TLS certificate errors | Managed by BTP; upload trusted CA in BTP Cockpit if needed | `STRUST` → SSL client identity → import CA certificate |
| Network routing | BTP Connectivity Service + Cloud Connector for on-premise targets | Direct network routing; check with basis for firewall rules |

> **On-Premise SM59 quick fix for 401:** Navigate to `SM59` → double-click the destination → *Logon & Security* tab → update the *Password* field → *Save* → click *Connection Test* to verify. The change takes effect immediately for new HTTP calls (no restart required).

> **Private/Public Cloud credential rotation process:** When a target system rotates its service account password, the standard process is: target system admin rotates password → sends new password to integration team via secure channel → integration admin updates Communication Arrangement or SM59 → confirms with connection test. Automate this notification with a runbook to prevent the "works on Friday, broken on Monday" pattern.

---

### Prevention

- Use the Communication Arrangement framework (Public Cloud) or SM59 (On-Premise) for all credentials — never hardcode passwords, tokens, or API keys in ABAP programs.
- Implement a **connection health-check report** that runs daily and performs a lightweight HEAD or OPTIONS request to each external HTTP endpoint; alert if status is not 2xx/401. This surfaces connectivity issues before they affect business processes.
- Design retry logic (as shown in Fix C) for all outbound integrations so that brief target-system maintenance windows do not cause data loss.
- For OAuth2 integrations, confirm the `expires_in` value of the token with the target API team and ensure the Communication Arrangement is configured with the correct token endpoint and scope.
- Establish a **credential rotation runbook**: define who is responsible for updating ABAP destination credentials when a target system rotates passwords, how quickly it must be done, and how to test. Set a calendar reminder 1 week before known password expiry dates.

---

---

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