---
name: abap-error-handling-resilience
description: >-
  Error handling and resilience patterns for SAP ABAP Cloud. Covers exception class hierarchy design (CX_STATIC_CHECK, CX_DYNAMIC_CHECK, CX_NO_CHECK), structured error handling, retry with exponential backoff, circuit breaker pattern, Application Log API (CL_BALI_LOG), RAP message handling, error recovery strategies, and observability. Triggers: exception, error handling, CX_, TRY CATCH, retry, circuit breaker, CL_BALI_LOG, application log, resilience, error recovery, message, RAISE EXCEPTION, logging, observability, SLG1.
metadata:
  version: 1.0.0
  tags: abap error-handling exceptions resilience logging cl-bali-log abap-cloud retry
---

# Error Handling and Resilience for ABAP Cloud

Expert guide for designing robust error handling, structured logging, and resilience patterns in ABAP Cloud.

**Golden rule: Fail fast, fail loud, fail safe. Never swallow exceptions silently. Always log with business context.**

Reference files:
- `references/error-patterns.md` — complete patterns for exceptions, retry, circuit breaker, and logging

## SAP Help Syntax Grounding (Mandatory)

For ABAP/CDS/BDL/EML syntax, use SAP Help as source of truth.

Rules:
- Do not provide unverified syntax for ABAP statements, CDS DDL, behavior definitions, EML, or RAP annotations/options.
- For non-trivial syntax responses, add a short "Syntax references" section with SAP Help links used.
- If exact syntax is uncertain, explicitly mark it as draft and require SAP Help verification.
- Never invent statement additions, annotation names, or behavior options.

Core SAP Help references:
- https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/cbb86e63a8464e63bbdd43b7bfa5fc4f.html
- https://help.sap.com/docs/ABAP_Cloud/bbcee501b99848bdadecd4e290db3ae4/404edb8b4c0648dca4d8f5a2fdfa6c58.html
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/c35896101f8c417482fd040d477bbbe1.html

Syntax verification steps:
1. Validate keywords and clause names against ABAP Keyword Documentation terminology.
2. Validate RAP strict mode and BDEF/BDL constructs against RAP docs.
3. Validate CDS form and annotation usage against CDS docs.
4. Validate EML operation form and response handling pattern.
5. Reconfirm clean-core and released-object constraints.
Syntax output contract (mandatory when providing ABAP/CDS/BDL/EML syntax):
1. Add `Syntax confidence` with exactly one value: `verified`, `partial`, or `draft`.
2. Add `Syntax references` with SAP Help links for each non-trivial syntax area used.
3. If confidence is `partial` or `draft`, add `Verification required` with unresolved syntax items.
4. Do not provide final production code when confidence is `draft`.


---

## Exception Class Hierarchy

| Base Class | Check Type | Use When |
|---|---|---|
| `CX_STATIC_CHECK` | Checked (compiler enforced) | Caller MUST handle: validation failures, business rule violations |
| `CX_DYNAMIC_CHECK` | Checked at runtime | Caller SHOULD handle: data conversion, parsing errors |
| `CX_NO_CHECK` | Unchecked (propagates freely) | System errors, programming bugs, unrecoverable states |

### Design Rules
- Custom exceptions ALWAYS inherit from one of these three
- Business exceptions → `CX_STATIC_CHECK` (force caller to handle)
- Technical exceptions → `CX_DYNAMIC_CHECK` or `CX_NO_CHECK`
- NEVER use generic `CX_ROOT` directly

---

## Exception Design Pattern

```abap
" GOOD: Domain-specific exception with context
CLASS cx_travel_validation DEFINITION FINAL
  INHERITING FROM cx_static_check.
  PUBLIC SECTION.
    INTERFACES if_t100_message.
    METHODS constructor
      IMPORTING travel_id TYPE travel_id OPTIONAL
                textid    TYPE scx_t100key OPTIONAL
                previous  TYPE REF TO cx_root OPTIONAL.
    DATA travel_id TYPE travel_id READ-ONLY.
    
    CONSTANTS: BEGIN OF missing_agency,
      msgid TYPE symsgid VALUE 'ZTRAVEL',
      msgno TYPE symsgno VALUE '001',
      attr1 TYPE scx_attrname VALUE 'TRAVEL_ID',
    END OF missing_agency.
ENDCLASS.
```

---

## Application Log (CL_BALI_LOG) — ABAP Cloud Pattern

```abap
" Create log
DATA(lo_log) = cl_bali_log=>create_with_header(
  header = cl_bali_header_setter=>create(
    object    = 'ZTRAVEL'
    subobject = 'CREATE'
    external_id = CONV #( travel_id ) ) ).

" Add messages
lo_log->add_item( cl_bali_message_setter=>create(
  severity = if_bali_constants=>c_severity_error
  id = 'ZTRAVEL' number = '001'
  variable_1 = CONV #( travel_id ) ) ).

" Save
cl_bali_log=>get_instance( )->save_log( lo_log ).
```

---

## Retry Pattern (Exponential Backoff)

```abap
CONSTANTS: max_retries TYPE i VALUE 3,
           base_delay  TYPE i VALUE 1.

DO max_retries TIMES.
  TRY.
      result = external_api->call( request ).
      EXIT. " Success — stop retrying
    CATCH cx_web_http_client_error INTO DATA(lx).
      IF sy-index = max_retries.
        RAISE EXCEPTION TYPE cx_integration_failed
          EXPORTING previous = lx.
      ENDIF.
      " Exponential backoff: 1s, 2s, 4s
      WAIT UP TO ( base_delay * ipow( base = 2 exp = sy-index - 1 ) ) SECONDS.
  ENDTRY.
ENDDO.
```

---

## Circuit Breaker Pattern

```abap
" States: CLOSED (normal) → OPEN (failing) → HALF-OPEN (testing)
CLASS zcl_circuit_breaker DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS call
      IMPORTING operation  TYPE REF TO zif_operation
      RETURNING VALUE(result) TYPE string
      RAISING   cx_circuit_open.
  PRIVATE SECTION.
    DATA: failure_count TYPE i,
          state         TYPE string VALUE 'CLOSED',  " CLOSED/OPEN/HALF-OPEN
          last_failure  TYPE timestamp.
    CONSTANTS: threshold   TYPE i VALUE 5,
               timeout_sec TYPE i VALUE 30.
ENDCLASS.

CLASS zcl_circuit_breaker IMPLEMENTATION.
  METHOD call.
    IF state = 'OPEN'.
      DATA(lv_now) = cl_abap_context_info=>get_system_date( ).
      " Check if timeout elapsed → try HALF-OPEN
      IF failure_count >= threshold.
        RAISE EXCEPTION TYPE cx_circuit_open.
      ENDIF.
      state = 'HALF-OPEN'.
    ENDIF.
    TRY.
        result = operation->execute( ).
        " Success → reset
        failure_count = 0.
        state = 'CLOSED'.
      CATCH cx_root.
        failure_count += 1.
        IF failure_count >= threshold.
          state = 'OPEN'.
        ENDIF.
        RAISE EXCEPTION TYPE cx_circuit_open.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
```

**When to use:** Wrap any external API call that can have sustained failure periods (e.g. downstream system down). Pair with retry pattern: retry handles transient failures, circuit breaker handles sustained outages.

---

## Response Rules

### "How do I handle errors?" questions
→ Determine: business error or technical error?
→ Business → CX_STATIC_CHECK with message class
→ Technical → CX_DYNAMIC_CHECK or CX_NO_CHECK
→ Always show TRY/CATCH with proper cleanup

### "How do I log in ABAP Cloud?" questions
→ Show CL_BALI_LOG pattern (replaces classic SLG1)
→ Include: object/subobject/external_id for traceability
→ Emphasize: log business context, not just "error occurred"

### "How do I make this resilient?" questions
→ Show retry with exponential backoff
→ For repeated failures: circuit breaker pattern
→ Always log each attempt for observability

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. Context and landscape assumptions (Public Cloud, Private Cloud ABAP Cloud, or BTP ABAP Environment)
2. Recommended approach with rationale and Clean Core impact
3. Implementation outline (objects, APIs, contracts, and constraints)
4. Validation plan (tests, checks, and rollback considerations)
5. Evidence and risk notes (source references, version sensitivity, and open assumptions)

Hard rules:
- Do not invent SAP objects, APIs, CDS entities, annotations, or transactions.
- Prefer released APIs and upgrade-safe extension mechanisms.
- Flag version-sensitive guidance explicitly when release context is uncertain.

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Architecture or design trade-offs | decision matrix + constraints + target-state blueprint |
| New implementation | modeling flow + API contract + test strategy |
| Performance issue | hotspot isolation + pushdown/pagination/index strategy |
| Security or authorization | threat points + authorization model + hardening controls |
| Integration behavior | protocol contract + resilience patterns + observability |
| Code review or readiness | findings first + risk ranking + concrete remediation steps |
