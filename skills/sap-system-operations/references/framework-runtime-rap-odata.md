# Framework and Runtime Issues — RAP / OData

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

RAP has no standalone "lock" statement. The framework acquires the lock **implicitly** on the first modifying EML operation (or, for draft BOs, the standard `Edit` action). A collision surfaces in the EML `FAILED` table with cause `if_abap_behv=>cause-locked`:

```abap
MODIFY ENTITIES OF zi_travel
  ENTITY travel
  UPDATE FROM VALUE #( ( %tky-travel_id = lv_travel_id
                         overall_status  = 'A'
                         %control-overall_status = if_abap_behv=>mk-on ) )
  FAILED   DATA(failed)
  REPORTED DATA(reported).

LOOP AT failed-travel INTO DATA(ls_failed) WHERE cause = if_abap_behv=>cause-locked.
  " Another session holds the lock — do not proceed
  MESSAGE 'Record is locked by another session' TYPE 'W'.
ENDLOOP.
```

> Classic on-premise only: `ENQUEUE_READ` (reads the lock table by `garg`) exists in Standard ABAP but is **not** released for ABAP Cloud.

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
