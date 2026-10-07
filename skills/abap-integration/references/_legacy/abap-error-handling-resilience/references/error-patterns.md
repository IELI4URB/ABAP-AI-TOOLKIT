# Error Handling and Resilience — Complete ABAP Cloud Reference

> **Scope:** ABAP Cloud (BTP / S/4HANA Cloud / ABAP Platform 2023+).  
> Patterns comply with ABAP Cloud's restricted API surface: no `MESSAGE` standalone statement in logic classes, no `SY-MSGID` polling, no `CATCH SYSTEM-EXCEPTIONS`.

---

## 1. Exception Class Hierarchy

### 1.1 The Three Root Types

```
CX_ROOT  (abstract root — never catch this directly)
├── CX_STATIC_CHECK     (checked: caller MUST catch or declare RAISING)
├── CX_DYNAMIC_CHECK    (checked at runtime: optimizer may omit check at compile time)
└── CX_NO_CHECK         (unchecked: never declare in RAISING; never catch in business logic)
```

### 1.2 Decision Matrix

| Situation | Use | Rationale |
|-----------|-----|-----------|
| Business rule violation (invalid state, data error) | `CX_STATIC_CHECK` | Caller *must* handle it; it is part of the API contract |
| Pre-condition violation (programming error, wrong arg) | `CX_DYNAMIC_CHECK` | Caller may handle; optimizer skips check when condition cannot fail |
| System / infrastructure failure (OOM, DB down) | `CX_NO_CHECK` | Cannot be meaningfully recovered from in business logic |
| Wrapping a lower-level exception for re-raise | Extend `CX_STATIC_CHECK` | Preserves call chain via `PREVIOUS =>` |
| HTTP / RFC timeout that the caller should retry | `CX_STATIC_CHECK` | Caller needs to know to retry |
| Invalid method argument (developer mistake) | `CX_DYNAMIC_CHECK` | Like Java `IllegalArgumentException` |

### 1.3 Never Catch These Broadly

```abap
" WRONG — silences all exceptions including system errors
TRY.
  ...
CATCH cx_root.         " Never
CATCH cx_no_check.     " Never in business logic
ENDTRY.

" RIGHT — catch only what you can meaningfully handle
TRY.
  ...
CATCH cx_zpur_auth_failed INTO DATA(lx_auth).
  " Handle auth failure specifically
CATCH cx_zpur_db_error INTO DATA(lx_db).
  " Handle DB error specifically
ENDTRY.
```

---

## 2. Domain Exception Design

### 2.1 Full Exception Class Definition

```abap
" Define in ADT: New → ABAP Class → Exception Class → Inherits CX_STATIC_CHECK
CLASS cx_zpur_order_error DEFINITION PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.

  PUBLIC SECTION.
    " Bind to T100 message for translatable text
    INTERFACES if_t100_message.

    " Named constants matching message IDs in message class ZPUR_MESSAGES
    CONSTANTS:
      BEGIN OF order_not_found,
        msgid TYPE symsgid  VALUE 'ZPUR_MESSAGES',
        msgno TYPE symsgno  VALUE '001',
        attr1 TYPE scx_attrname VALUE 'MV_ORDER_ID',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF order_not_found,

      BEGIN OF auth_failed,
        msgid TYPE symsgid  VALUE 'ZPUR_MESSAGES',
        msgno TYPE symsgno  VALUE '002',
        attr1 TYPE scx_attrname VALUE 'MV_ACTION',
        attr2 TYPE scx_attrname VALUE 'MV_PURCH_ORG',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF auth_failed,

      BEGIN OF invalid_status_transition,
        msgid TYPE symsgid  VALUE 'ZPUR_MESSAGES',
        msgno TYPE symsgno  VALUE '003',
        attr1 TYPE scx_attrname VALUE 'MV_OLD_STATUS',
        attr2 TYPE scx_attrname VALUE 'MV_NEW_STATUS',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF invalid_status_transition.

    " Public attributes bound to message placeholders (&1, &2, etc.)
    DATA mv_order_id   TYPE orderid_ext READ-ONLY.
    DATA mv_action     TYPE string      READ-ONLY.
    DATA mv_purch_org  TYPE ekorg       READ-ONLY.
    DATA mv_old_status TYPE char4       READ-ONLY.
    DATA mv_new_status TYPE char4       READ-ONLY.

    " Constructor — always support TEXTID and PREVIOUS for chaining
    METHODS constructor
      IMPORTING
        !textid    LIKE if_t100_message=>t100key OPTIONAL
        !previous  TYPE REF TO cx_root            OPTIONAL
        !order_id  TYPE orderid_ext               OPTIONAL
        !action    TYPE string                    OPTIONAL
        !purch_org TYPE ekorg                     OPTIONAL
        !old_status TYPE char4                    OPTIONAL
        !new_status TYPE char4                    OPTIONAL.

ENDCLASS.

CLASS cx_zpur_order_error IMPLEMENTATION.

  METHOD constructor.
    " Call super constructor — passes textid and previous up the chain
    CALL METHOD super->constructor
      EXPORTING
        textid   = COND #( WHEN textid IS INITIAL
                           THEN if_t100_message=>default_textid
                           ELSE textid )
        previous = previous.

    " Bind T100 message interface
    if_t100_message~t100key = COND #( WHEN textid IS INITIAL
                                      THEN if_t100_message=>default_textid
                                      ELSE textid ).

    " Store message variable values for T100 placeholder substitution
    mv_order_id   = order_id.
    mv_action     = action.
    mv_purch_org  = purch_org.
    mv_old_status = old_status.
    mv_new_status = new_status.
  ENDMETHOD.

ENDCLASS.
```

### 2.2 Raising with TEXTID and MESSAGE

```abap
" Raise 'order not found' with T100 text binding
RAISE EXCEPTION TYPE cx_zpur_order_error
  MESSAGE e001(zpur_messages) WITH lv_order_id
  EXPORTING
    textid   = cx_zpur_order_error=>order_not_found
    order_id = lv_order_id.

" Raise 'invalid status transition' chaining a previous exception
RAISE EXCEPTION TYPE cx_zpur_order_error
  EXPORTING
    textid     = cx_zpur_order_error=>invalid_status_transition
    previous   = lx_lower_level_exception
    old_status = lv_current_status
    new_status = lv_target_status.
```

---

## 3. Exception Propagation Rules

### 3.1 Decision Tree

```
Did an exception occur?
│
├─► Can THIS layer recover?
│   ├─► YES → catch, handle, continue (or return error result type)
│   └─► NO  → re-raise (either as-is, or wrapped with PREVIOUS =>)
│
├─► Is the exception a programming error (CX_DYNAMIC_CHECK)?
│   └─► Let it propagate; do NOT swallow
│
└─► Is it CX_NO_CHECK?
    └─► Let it propagate; NEVER catch in business logic
```

### 3.2 Wrapping with Root Cause Chaining

```abap
METHOD submit_for_approval.
  TRY.
      " Call persistence layer
      lo_persistence->update_status(
        iv_order_id    = lv_order_id
        iv_new_status  = 'SUBMITTED' ).

    CATCH cx_zpur_db_error INTO DATA(lx_db).
      " Translate infrastructure exception into domain exception
      " Preserve root cause via PREVIOUS =>
      RAISE EXCEPTION TYPE cx_zpur_order_error
        EXPORTING
          textid   = cx_zpur_order_error=>invalid_status_transition
          previous = lx_db              " <-- root cause preserved
          old_status = lv_current_status
          new_status = 'SUBMITTED'.
  ENDTRY.
ENDMETHOD.
```

### 3.3 Accessing the Exception Chain

```abap
TRY.
  lo_service->submit_for_approval( lv_order_id ).
CATCH cx_zpur_order_error INTO DATA(lx_domain).
  " Walk the PREVIOUS chain for root cause logging
  DATA(lx_cause) = lx_domain->previous.
  WHILE lx_cause IS BOUND.
    " lx_cause->get_text( ) returns the T100 message
    DATA(lx_next) = lx_cause->previous.
    lx_cause = lx_next.
  ENDWHILE.
ENDTRY.
```

---

## 4. CL_BALI_LOG — Full Application Log Pattern

### 4.1 Write Phase: Create, Populate, Save

```abap
METHOD run_procurement_job.
  " --- 1. Create the log instance ---
  DATA(lo_log) = cl_bali_log=>create( ).

  " --- 2. Set log header ---
  DATA(lo_header) = cl_bali_header_setter=>create(
    object    = 'ZPURCHASE'       " Application log object (SLG0)
    subobject = 'BATCH_SUBMIT'    " Sub-object
    program   = sy-repid ).

  lo_header->set_expiry_date( sy-datum + 30 ).  " Keep log 30 days
  lo_log->set_header( lo_header ).

  " --- 3. Process records and write messages ---
  LOOP AT lt_order_keys INTO DATA(ls_key).
    TRY.
        process_single_order( ls_key-order_id ).

        " Info: success
        lo_log->add_item(
          cl_bali_message_setter=>create(
            severity   = if_bali_constants=>c_severity_status
            id         = 'ZPUR_MESSAGES'
            number     = '010'
            variable_1 = ls_key-order_id ) ).

      CATCH cx_zpur_order_error INTO DATA(lx_order).
        " Error: domain exception — log with full T100 message
        lo_log->add_item(
          cl_bali_exception_setter=>create(
            severity  = if_bali_constants=>c_severity_error
            exception = lx_order ) ).

      CATCH cx_zpur_db_error INTO DATA(lx_db).
        " Critical: DB error — log and abort
        lo_log->add_item(
          cl_bali_exception_setter=>create(
            severity  = if_bali_constants=>c_severity_error
            exception = lx_db ) ).

        " Log warning that processing was aborted
        lo_log->add_item(
          cl_bali_message_setter=>create(
            severity   = if_bali_constants=>c_severity_warning
            id         = 'ZPUR_MESSAGES'
            number     = '099'
            variable_1 = ls_key-order_id ) ).
        RETURN.
    ENDTRY.
  ENDLOOP.

  " --- 4. Save to database ---
  TRY.
      cl_bali_log_db=>get_instance( )->save_log( lo_log ).
    CATCH cx_bali_runtime_error INTO DATA(lx_bali).
      " Fallback: write to syslog if BALI unavailable
      MESSAGE lx_bali->get_text( ) TYPE 'S' DISPLAY LIKE 'W'.
  ENDTRY.
ENDMETHOD.
```

### 4.2 Read Phase: Retrieve for Programmatic Access

```abap
METHOD display_job_log.
  " Retrieve saved log by handle
  TRY.
      DATA(lo_log) = cl_bali_log_db=>get_instance(
                       )->load_log( iv_log_handle = lv_log_handle ).

      " Iterate over items
      DATA(lt_items) = lo_log->get_all_items( ).
      LOOP AT lt_items INTO DATA(ls_item).
        DATA(lv_severity) = ls_item-item->get_severity( ).
        DATA(lv_text)     = ls_item-item->get_message_text( ).

        CASE lv_severity.
          WHEN if_bali_constants=>c_severity_error.
            " Render as error in UI
          WHEN if_bali_constants=>c_severity_warning.
            " Render as warning
          WHEN if_bali_constants=>c_severity_status.
            " Render as success
        ENDCASE.
      ENDLOOP.

    CATCH cx_bali_runtime_error INTO DATA(lx).
      " Log handle invalid or log purged
  ENDTRY.
ENDMETHOD.
```

### 4.3 Severity Constants Reference

| Constant | Display | Use When |
|----------|---------|----------|
| `if_bali_constants=>c_severity_status` | Green ✓ | Successful processing of a single record |
| `if_bali_constants=>c_severity_warning` | Yellow ⚠ | Non-fatal issue; processing continued |
| `if_bali_constants=>c_severity_error` | Red ✗ | Failure; processing of this item aborted |
| `if_bali_constants=>c_severity_abort` | Red ✗✗ | Fatal; entire job aborted |

---

## 5. Retry with Exponential Backoff

### 5.1 Full Pattern

```abap
METHOD call_external_service_with_retry.
  " -----------------------------------------------------------
  " Retry an HTTP call with exponential backoff.
  " Retries: 0 → 1s, 1 → 2s, 2 → 4s, 3 → 8s (2^n seconds)
  " -----------------------------------------------------------
  CONSTANTS: lc_max_retries TYPE i VALUE 4.

  DATA: lv_current_retry TYPE i VALUE 0,
        lv_wait_seconds  TYPE i,
        lo_response      TYPE REF TO if_web_http_response,
        lv_last_error    TYPE REF TO cx_web_http_client_error.

  DO lc_max_retries TIMES.
    TRY.
        " Build HTTP client via destination
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
          cl_http_destination_provider=>create_by_comm_arrangement(
            comm_scenario  = 'ZPUR_HTTP_SCENARIO'
            service_id     = 'ZPURCHASE_API'
            outbound_service = 'ZPURCHASE_API_REST' ) ).

        DATA(lo_request) = lo_client->get_http_request( ).
        lo_request->set_method( if_web_http_client=>post ).
        lo_request->set_header_field(
          i_name  = 'Content-Type'
          i_value = 'application/json' ).
        lo_request->set_text( lv_request_body ).

        lo_response = lo_client->execute( if_web_http_client=>post ).

        CASE lo_response->get_status( )-code.
          WHEN 200 OR 201.
            " Success — extract result and exit retry loop
            rv_response_body = lo_response->get_text( ).
            RETURN.
          WHEN 429 OR 503.
            " Rate-limited or service unavailable — retry
            RAISE EXCEPTION TYPE cx_web_http_client_error
              MESSAGE e050(zpur_messages) WITH lo_response->get_status( )-code.
          WHEN OTHERS.
            " Non-retryable error (4xx client error)
            RAISE EXCEPTION TYPE cx_zpur_api_error
              MESSAGE e051(zpur_messages)
              WITH lo_response->get_status( )-code lv_request_body.
        ENDCASE.

      CATCH cx_web_http_client_error INTO DATA(lx_http).
        lv_last_error = lx_http.

        " Calculate backoff: 2^current_retry seconds, capped at 60s
        lv_wait_seconds = MIN( ipow( base = 2 exp = lv_current_retry ), 60 ).

        " Log the transient failure
        MESSAGE |Retry { lv_current_retry + 1 }/{ lc_max_retries }: | &&
                |waiting { lv_wait_seconds }s. Error: { lx_http->get_text( ) }|
          TYPE 'S' DISPLAY LIKE 'W'.

        IF lv_current_retry < lc_max_retries - 1.
          " Wait before next attempt (only if not the last retry)
          WAIT UP TO lv_wait_seconds SECONDS.
        ENDIF.

        lv_current_retry += 1.
    ENDTRY.
  ENDDO.

  " All retries exhausted — raise with last error chained
  RAISE EXCEPTION TYPE cx_zpur_api_error
    MESSAGE e052(zpur_messages)
    EXPORTING
      previous = lv_last_error.
ENDMETHOD.
```

### 5.2 Backoff Schedule Reference

| Attempt | Formula `2^(attempt-1)` | Wait (seconds) |
|---------|------------------------|----------------|
| 1 (immediate) | `2^0 = 1` | 1 |
| 2 | `2^1 = 2` | 2 |
| 3 | `2^2 = 4` | 4 |
| 4 | `2^3 = 8` | 8 |
| 5 | `2^4 = 16` | 16 |
| … | … | Capped at 60 |

> **Note:** `WAIT UP TO n SECONDS` releases the work process during the wait in ABAP. Use it only in background jobs; do **not** use it in synchronous dialog steps as it blocks the dialog work process and leads to timeout.

---

## 6. Circuit Breaker Pattern

### 6.1 State Machine

```
          [success]           [failure threshold exceeded]
CLOSED ──────────────────────►  OPEN
  ▲                              │
  │ [probe succeeds]             │ [timeout window elapses]
  │                              ▼
HALF-OPEN ◄──────────────── OPEN (cooling down)
```

| State | Behaviour | Transition |
|-------|-----------|------------|
| `CLOSED` | All calls pass through | → `OPEN` after N consecutive failures |
| `OPEN` | All calls fail-fast (no attempt) | → `HALF-OPEN` after timeout window |
| `HALF-OPEN` | One probe call allowed | → `CLOSED` on success; → `OPEN` on failure |

### 6.2 ABAP Class Outline

```abap
CLASS zcl_circuit_breaker DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ENUM ty_state,
             closed,
             open,
             half_open,
           END OF ENUM ty_state.

    METHODS constructor
      IMPORTING
        iv_failure_threshold TYPE i DEFAULT 5
        iv_timeout_seconds   TYPE i DEFAULT 30.

    " Returns abap_true if the call should be allowed; abap_false = fail-fast
    METHODS is_call_allowed RETURNING VALUE(rv_allowed) TYPE abap_bool.
    METHODS record_success.
    METHODS record_failure.
    METHODS get_state    RETURNING VALUE(rv_state) TYPE ty_state.

  PRIVATE SECTION.
    DATA mv_state             TYPE ty_state VALUE closed.
    DATA mv_failure_count     TYPE i        VALUE 0.
    DATA mv_failure_threshold TYPE i.
    DATA mv_timeout_seconds   TYPE i.
    DATA mv_open_since        TYPE timestampl.
ENDCLASS.

CLASS zcl_circuit_breaker IMPLEMENTATION.

  METHOD constructor.
    mv_failure_threshold = iv_failure_threshold.
    mv_timeout_seconds   = iv_timeout_seconds.
  ENDMETHOD.

  METHOD is_call_allowed.
    CASE mv_state.
      WHEN closed.
        rv_allowed = abap_true.

      WHEN open.
        " Check if cooling-down window has elapsed
        DATA(lv_now) = utclong_current( ).
        DATA(lv_elapsed_sec) = cl_abap_tstmp=>subtract(
          tstmp1 = lv_now
          tstmp2 = mv_open_since ).

        IF lv_elapsed_sec >= mv_timeout_seconds.
          mv_state   = half_open.
          rv_allowed = abap_true.   " Allow one probe call
        ELSE.
          rv_allowed = abap_false.  " Fail-fast
        ENDIF.

      WHEN half_open.
        rv_allowed = abap_true.   " Single probe in flight
    ENDCASE.
  ENDMETHOD.

  METHOD record_success.
    mv_state         = closed.
    mv_failure_count = 0.
  ENDMETHOD.

  METHOD record_failure.
    mv_failure_count += 1.
    IF mv_state = half_open OR mv_failure_count >= mv_failure_threshold.
      mv_state      = open.
      mv_open_since = utclong_current( ).
    ENDIF.
  ENDMETHOD.

  METHOD get_state.
    rv_state = mv_state.
  ENDMETHOD.

ENDCLASS.
```

### 6.3 Using the Circuit Breaker

```abap
" Shared instance — store in application singleton or class attribute
DATA(lo_cb) = NEW zcl_circuit_breaker(
  iv_failure_threshold = 3
  iv_timeout_seconds   = 60 ).

IF lo_cb->is_call_allowed( ) = abap_false.
  RAISE EXCEPTION TYPE cx_zpur_service_unavailable
    MESSAGE e060(zpur_messages).
ENDIF.

TRY.
  DATA(lv_result) = call_external_api( ).
  lo_cb->record_success( ).
CATCH cx_web_http_client_error INTO DATA(lx).
  lo_cb->record_failure( ).
  RAISE EXCEPTION TYPE cx_zpur_api_error EXPORTING previous = lx.
ENDTRY.
```

---

## 7. RAP Message Handling

### 7.1 The Three Response Tables

| Table | Purpose | Populated By |
|-------|---------|--------------|
| `FAILED` | Record-level failure; framework suppresses the operation for this key | Behavior pool when operation cannot proceed |
| `REPORTED` | Diagnostic messages shown in Fiori MessagePopover | Behavior pool; always include `%msg` |
| `MAPPED` | Key remapping for draft/create (client key → UUID) | Behavior pool during CREATE |

### 7.2 Correct FAILED + REPORTED Pattern

```abap
METHOD validate_order.
  " Called by the RAP framework during the validation phase
  READ ENTITIES OF zpurchase_order IN LOCAL MODE
    ENTITY PurchaseOrder
      FIELDS ( PurchasingOrg NetValue OrderDate )
      WITH CORRESPONDING #( keys )
    RESULT DATA(lt_orders)
    FAILED DATA(lt_read_failed).

  " Propagate read failures
  failed-purchaseorder = CORRESPONDING #( lt_read_failed-purchaseorder ).

  LOOP AT lt_orders INTO DATA(ls_order).

    " Rule 1: NetValue must be positive
    IF ls_order-NetValue <= 0.
      APPEND VALUE #(
        %tky = ls_order-%tky
      ) TO failed-purchaseorder.

      APPEND VALUE #(
        %tky      = ls_order-%tky
        %msg      = new_message(
                      id       = 'ZPUR_MESSAGES'
                      number   = '020'
                      severity = if_abap_behv_message=>severity-error
                      v1       = |{ ls_order-NetValue }| )
        %validate = if_abap_behv=>mk-on   " <-- marks message as from validation
      ) TO reported-purchaseorder.
    ENDIF.

    " Rule 2: OrderDate cannot be in the past
    IF ls_order-OrderDate < cl_abap_context_info=>get_system_date( ).
      APPEND VALUE #(
        %tky = ls_order-%tky
      ) TO failed-purchaseorder.

      APPEND VALUE #(
        %tky      = ls_order-%tky
        %msg      = new_message(
                      id       = 'ZPUR_MESSAGES'
                      number   = '021'
                      severity = if_abap_behv_message=>severity-error
                      v1       = |{ ls_order-OrderDate }| )
        %validate = if_abap_behv=>mk-on
      ) TO reported-purchaseorder.
    ENDIF.

  ENDLOOP.
ENDMETHOD.
```

### 7.3 T100 Message in RAP — `new_message` Helper

```abap
" new_message() is available in behavior pool via cl_abap_behavior_handler
DATA(lo_msg) = new_message(
  id       = 'ZPUR_MESSAGES'   " Message class
  number   = '001'             " Message number
  severity = if_abap_behv_message=>severity-error    " E
  v1       = lv_order_id       " &1 placeholder
  v2       = lv_purch_org      " &2 placeholder
  v3       = ''
  v4       = '' ).

" Severity values:
" if_abap_behv_message=>severity-success   'S'
" if_abap_behv_message=>severity-info      'I'
" if_abap_behv_message=>severity-warning   'W'
" if_abap_behv_message=>severity-error     'E'
```

### 7.4 MAPPED — Key Remapping for Draft

```abap
" During CREATE action handler — map client UUID to DB UUID
APPEND VALUE #(
  %cid      = ls_create_order-%cid           " Client correlation ID
  %key      = VALUE #( OrderID = lv_new_uuid ) " Server-assigned UUID
) TO mapped-purchaseorder.
```

---

## 8. Fail-Fast vs Fail-Safe

### 8.1 Decision Guide

| Scenario | Strategy | Rationale |
|----------|----------|-----------|
| Invalid input parameter to a method | **Fail-Fast** (raise immediately) | Surface developer error immediately; don't propagate garbage data |
| Required external service unavailable | **Fail-Fast** (raise; let caller retry) | Processing without the service produces incorrect results |
| Optional enrichment service unavailable | **Fail-Safe** (continue without enrichment) | Core operation must not fail for optional data |
| Auth check fails on a bulk operation item | **Fail-Safe** (skip item, log, continue others) | One bad record should not abort the batch |
| DB constraint violation on a single record | **Fail-Fast** | Indicates business rule violated |
| BALI log save fails | **Fail-Safe** (fallback to syslog) | Job completion is more important than perfect logging |

### 8.2 When NOT to Use TRY…CATCH

```abap
" WRONG — using exception handling as flow control
TRY.
    DATA(ls_item) = lt_items[ KEY primary_key COMPONENTS id = lv_id ].
CATCH cx_sy_itab_line_not_found.
    " This is flow control, not exception handling
ENDTRY.

" RIGHT — check existence first; use READ TABLE
READ TABLE lt_items
  WITH KEY id = lv_id
  INTO DATA(ls_item).

IF sy-subrc = 0.
  " Use ls_item
ENDIF.

" ALSO RIGHT (ABAP 7.50+) — use line_exists / VALUE #( OPTIONAL )
IF line_exists( lt_items[ KEY primary_key COMPONENTS id = lv_id ] ).
  DATA(ls_found) = lt_items[ KEY primary_key COMPONENTS id = lv_id ].
ENDIF.
```

### 8.3 Fail-Safe with Partial Result Collection

```abap
METHOD process_order_batch.
  DATA: lt_successes TYPE TABLE OF orderid_ext,
        lt_failures  TYPE TABLE OF orderid_ext.

  LOOP AT lt_order_ids INTO DATA(lv_id).
    TRY.
        process_single_order( lv_id ).
        APPEND lv_id TO lt_successes.

      CATCH cx_zpur_order_error INTO DATA(lx).
        " Log but do not abort
        APPEND lv_id TO lt_failures.
        log_exception( iv_order_id = lv_id  io_exception = lx ).
    ENDTRY.
  ENDLOOP.

  " Report summary
  rv_success_count = lines( lt_successes ).
  rv_failure_count = lines( lt_failures ).
ENDMETHOD.
```

---

## 9. Anti-Patterns Checklist

| # | Anti-Pattern | Risk | Correct Approach |
|---|-------------|------|-----------------|
| 1 | `CATCH cx_root INTO … .  " do nothing` | Swallows ALL exceptions silently | Catch only specific types; always re-raise or log |
| 2 | Raising `CX_STATIC_CHECK` in a constructor | Constructor RAISING is not supported in all contexts | Move validation to a factory method |
| 3 | `MESSAGE e001 ... RAISING` in a class (non-function-module) | `MESSAGE ... RAISING` is FM-only syntax | Use `RAISE EXCEPTION TYPE ... MESSAGE ...` |
| 4 | Checking `sy-subrc` after `RAISE EXCEPTION` | `sy-subrc` is unreliable for exceptions | Use `TRY...CATCH` |
| 5 | Creating a new log per-record in a loop | Thousands of log handles created; performance issue | Create ONE log before the loop; add items inside |
| 6 | `WAIT UP TO` in dialog step | Blocks dialog work process; timeout | Only use in background (batch) context |
| 7 | Circuit breaker as instance variable on short-lived object | Resets on every call; no memory effect | Store on class-static attribute or application singleton |
| 8 | `APPEND ... TO failed` without corresponding `APPEND ... TO reported` | Fiori shows no message on reject; user confused | Always pair FAILED with at least one REPORTED `%msg` entry |
| 9 | `new_message( severity = 'E' )` as a literal | Typo-prone; not refactor-safe | Use `if_abap_behv_message=>severity-error` constant |
| 10 | `lx->previous` navigation without BOUND check | Short dump if chain is shorter than expected | `WHILE lx_cause IS BOUND` before dereferencing |
