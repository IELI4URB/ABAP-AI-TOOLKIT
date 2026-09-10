---
name: abap-application-jobs
description: >-
  Application Jobs architecture and operations for SAP ABAP Cloud. Covers IF_APJ_DT_EXEC_OBJECT interface implementation, job catalog entries, job templates, scheduling (one-time, recurring, event-based), parameter passing, error handling in jobs, monitoring via Application Jobs app, and the complete lifecycle from development to productive scheduling. Triggers: application job, background job, scheduling, job catalog, job template, IF_APJ_DT_EXEC_OBJECT, CL_APJ, recurring job, batch processing, background processing, SM36, SM37 replacement, job monitor.
metadata:
  version: 1.0.0
  tags: abap application-jobs scheduling background batch abap-cloud monitoring
---

# Application Jobs Architecture for ABAP Cloud

Expert guide for designing and implementing background processing in ABAP Cloud using the Application Jobs framework.

**Golden rule: No SM36/SM37 in ABAP Cloud. Use Application Jobs framework: Class → Catalog → Template → Schedule.**

Reference files:
- `references/jobs-complete.md` — full implementation patterns with class, catalog, template, and scheduling examples

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

## Application Jobs vs Classic (SM36/SM37)

| Classic (NOT in ABAP Cloud) | Application Jobs (ABAP Cloud) |
|---|---|
| SM36 (define job) | Job Catalog Entry (dev artifact) |
| SM37 (monitor) | Application Jobs Fiori app |
| Reports/programs | Class implementing `IF_APJ_DT_EXEC_OBJECT` |
| Variants | Job Template (parameters) |
| Periodicity in SM36 | Scheduling in Fiori app or API |

---

## Development Lifecycle

```
1. Create ABAP class implementing IF_APJ_DT_EXEC_OBJECT
2. Create Job Catalog Entry (development artifact, transportable)
3. Create Job Template (defines parameters + defaults)
4. Administrator schedules via Application Jobs Fiori app
5. Monitor execution and results
```

---

## Job Class Implementation

```abap
CLASS zcl_travel_cleanup_job DEFINITION FINAL
  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
ENDCLASS.

CLASS zcl_travel_cleanup_job IMPLEMENTATION.
  METHOD if_apj_dt_exec_object~get_parameters.
    " Define parameters available in job template
    et_parameter_def = VALUE #(
      ( selname = 'P_DAYS' kind = if_apj_dt_exec_object=>parameter
        datatype = 'INT4' length = 10
        param_text = 'Days to keep' changeable_ind = abap_true )
      ( selname = 'P_SIMUL' kind = if_apj_dt_exec_object=>parameter
        datatype = 'CHAR' length = 1
        param_text = 'Simulation mode' changeable_ind = abap_true )
    ).
    et_parameter_val = VALUE #(
      ( selname = 'P_DAYS' sign = 'I' option = 'EQ' low = '90' )
      ( selname = 'P_SIMUL' sign = 'I' option = 'EQ' low = 'X' )
    ).
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.
    " Runtime execution logic
    DATA(lv_days) = VALUE i( ).
    DATA(lv_simul) = VALUE abap_bool( ).

    LOOP AT it_parameters INTO DATA(ls_param).
      CASE ls_param-selname.
        WHEN 'P_DAYS'. lv_days = ls_param-low.
        WHEN 'P_SIMUL'. lv_simul = ls_param-low.
      ENDCASE.
    ENDLOOP.

    " Business logic
    DATA(lv_cutoff) = cl_abap_context_info=>get_system_date( ) - lv_days.
    
    IF lv_simul = abap_false.
      DELETE FROM ztravel WHERE created_at < @lv_cutoff.
    ENDIF.

    " Log results
    DATA(lo_log) = cl_bali_log=>create_with_header(
      header = cl_bali_header_setter=>create(
        object = 'ZTRAVEL' subobject = 'CLEANUP' ) ).
    lo_log->add_item( cl_bali_message_setter=>create_from_sy( ) ).
    cl_bali_log=>get_instance( )->save_log( lo_log ).
  ENDMETHOD.
ENDCLASS.
```

---

## Job Catalog Entry (ADT)
```
New → Other ABAP Repository Object → Application Jobs → Application Job Catalog Entry
- Name: ZJC_TRAVEL_CLEANUP
- Class: ZCL_TRAVEL_CLEANUP_JOB
- Package: ZTRAVEL_APP
```

---

## Response Rules

### "How do I create a background job?" questions
→ Show full lifecycle: class → catalog → template → schedule
→ Always include IF_APJ_DT_EXEC_OBJECT + IF_APJ_RT_EXEC_OBJECT

### "How do I schedule recurring?" questions
→ Show Application Jobs Fiori app scheduling options
→ Include: daily, weekly, monthly, event-based triggers

### "How do I monitor job failures?" questions
→ Show CL_BALI_LOG integration for structured logging
→ Reference Application Jobs monitoring app

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
