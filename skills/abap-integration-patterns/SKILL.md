---
name: abap-integration-patterns
description: >-
  Integration patterns for SAP ABAP Cloud covering HTTP REST calls (CL_WEB_HTTP_CLIENT_MANAGER), SOAP proxy consumption, RFC wrapper pattern for unreleased FMs, Communication Scenarios and Arrangements, Event Mesh integration, AIF monitoring, inbound and outbound connectivity patterns, and error handling for remote calls. Triggers: HTTP, REST, SOAP, proxy, RFC, wrapper, communication scenario, communication arrangement, Event Mesh, AIF, outbound, inbound, destination, integration, external API, remote call, CL_WEB_HTTP_CLIENT_MANAGER.
metadata:
  version: 1.0.0
  tags: abap integration http soap rfc event-mesh communication-scenario abap-cloud
---

# Integration Patterns for ABAP Cloud

Expert guide for all inbound and outbound integration in SAP ABAP Cloud — HTTP, SOAP, RFC wrappers, Event Mesh, and Communication management.

**Golden rule: All outbound calls require a Communication Arrangement. Never hardcode URLs or credentials. Always handle timeouts and errors.**

Reference files:
- `references/integration-complete.md` — full implementation patterns with code for every integration type

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

## Integration Decision Matrix

| Scenario | Pattern | Protocol | Key Class/Object |
|---|---|---|---|
| Call external REST API | HTTP Client | HTTPS | `CL_WEB_HTTP_CLIENT_MANAGER` |
| Call external SOAP service | SOAP Proxy | HTTPS/SOAP | Generated proxy class |
| Call unreleased SAP FM | RFC Wrapper | RFC (internal) | Wrapper class (Tier 2) |
| Receive inbound webhook | HTTP Handler | HTTPS | `IF_HTTP_SERVICE_EXTENSION` |
| Publish event to external | Event Mesh | AMQP/HTTP | RAP Event Binding |
| File-based integration | Cloud Storage | HTTPS | BTP Object Store / DMS |
| Monitor interfaces | AIF | N/A | `/AIF/` framework |

---

## Communication Architecture (Required for ALL outbound)

```
┌─────────────────────────────────────────┐
│ Communication Scenario (dev artifact)    │
│ - Defines WHAT services are needed       │
│ - Contains inbound/outbound services     │
│ - Transportable                          │
├─────────────────────────────────────────┤
│ Communication System (runtime config)    │
│ - Defines WHERE (host, port, path)       │
│ - Created by administrator               │
├─────────────────────────────────────────┤
│ Communication Arrangement (runtime)      │
│ - Binds Scenario to System               │
│ - Contains credentials (OAuth, cert)     │
│ - Created by administrator               │
└─────────────────────────────────────────┘
```

---

## HTTP REST Client Pattern

```abap
METHOD call_external_api.
  " 1. Get HTTP client via Communication Arrangement
  DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
    comm_scenario  = 'Z_MY_COMM_SCENARIO'
    service_id     = 'Z_OUTBOUND_REST' ).

  DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).

  " 2. Build request
  DATA(lo_request) = lo_client->get_http_request( ).
  lo_request->set_uri_path( '/api/v1/orders' ).
  lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
  lo_request->set_text( lv_json_body ).

  " 3. Execute with error handling
  TRY.
      DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).
      DATA(lv_status) = lo_response->get_status( )-code.
      IF lv_status >= 200 AND lv_status < 300.
        DATA(lv_body) = lo_response->get_text( ).
      ELSE.
        RAISE EXCEPTION TYPE zcx_http_call_failed
          EXPORTING
            status_code = lv_status
            textid      = zcx_http_call_failed=>http_error.
      ENDIF.
    CATCH cx_web_http_client_error INTO DATA(lx_http).
      " Log and handle
    CLEANUP.
      lo_client->close( ).
  ENDTRY.
ENDMETHOD.
```

---

## SOAP Proxy Consumption

SOAP proxies are generated in ADT from a WSDL. The generated proxy class follows a consistent pattern.

```abap
" 1. Get logical port via communication arrangement
DATA(lo_destination) = cl_soap_destination_provider=>create_by_comm_arrangement(
  comm_scenario = 'ZSCEN_MY_SOAP_SERVICE' ).

" 2. Instantiate the generated proxy stub
DATA(lo_proxy) = NEW zco_my_soap_service_port( lo_destination ).

" 3. Prepare request structure (generated types from WSDL)
DATA(ls_request)  TYPE zsdt_my_soap_request.
DATA(ls_response) TYPE zsdt_my_soap_response.
ls_request-field1 = 'value'.

" 4. Call the service operation
TRY.
    lo_proxy->my_operation(
      EXPORTING input  = ls_request
      IMPORTING output = ls_response ).
    " Process ls_response
  CATCH cx_ai_system_fault INTO DATA(lx_system).
    " System-level fault (connectivity, timeout)
    RAISE EXCEPTION TYPE zcx_integration_error
      EXPORTING previous = lx_system.
  CATCH cx_ai_application_fault INTO DATA(lx_app).
    " Application-level fault returned by the service
    RAISE EXCEPTION TYPE zcx_integration_error
      EXPORTING previous = lx_app.
ENDTRY.
```
> SOAP proxy classes are generated by ADT. Right-click the Enterprise Service → Generate Proxy. The generated class name follows the pattern `ZCO_<SERVICE_NAME>_PORT`.

---

## RFC Wrapper / Tier 2 Pattern

Use a Tier 2 wrapper to make unreleased function modules accessible from ABAP Cloud (Tier 1) code. The wrapper lives in **Standard ABAP** (Tier 2) and exposes a **released C1 interface**.

```
Architecture:
  [ABAP Cloud - Tier 1]  →  calls  →  [Released C1 Interface]
                                            ↓
                                  [Tier 2 Wrapper Class — Standard ABAP]
                                            ↓
                                  [Unreleased Function Module]
```

### Tier 2 Wrapper Implementation
```abap
" In Standard ABAP package (NOT ABAP Cloud package):
CLASS zcl_mm_goods_movement_wrap DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_mm_goods_movement.  " Released C1 interface
    METHODS post
      IMPORTING is_header  TYPE bapi2017_gm_head_01
                it_items   TYPE bapi2017_gm_item_create
      EXPORTING et_messages TYPE bapiret2_tab
      RAISING   zcx_goods_movement_error.
ENDCLASS.

CLASS zcl_mm_goods_movement_wrap IMPLEMENTATION.
  METHOD post.
    CALL FUNCTION 'BAPI_GOODSMVT_CREATE'  " unreleased FM — only callable from Tier 2
      EXPORTING  goodsmvt_header = is_header
      TABLES     goodsmvt_item   = it_items
                 return          = et_messages.

    " Check BAPI return
    DATA(lt_errors) = FILTER #( et_messages WHERE type = 'E' OR type = 'A' ).
    IF lt_errors IS NOT INITIAL.
      RAISE EXCEPTION TYPE zcx_goods_movement_error
        EXPORTING messages = lt_errors.
    ENDIF.
    COMMIT WORK.  " BAPIs require explicit COMMIT — only valid in Tier 2
  ENDMETHOD.
ENDCLASS.
```

### Key Rules for Tier 2 Wrappers
1. **Package type:** Wrapper class must be in a Standard ABAP package (not ABAP Cloud)
2. **Release contract:** The INTERFACE (`zif_mm_goods_movement`) must be released as C1
3. **No business logic:** Wrapper only translates — no business rules in the wrapper class
4. **COMMIT WORK:** Only the Tier 2 wrapper may call `COMMIT WORK` — never from ABAP Cloud Tier 1 code
5. **Testing:** Mock the interface in unit tests — do not test through the wrapper

---

## Response Rules

### "How do I call an external API?" questions
→ Show Communication Scenario + Arrangement setup first
→ Then show CL_WEB_HTTP_CLIENT_MANAGER pattern
→ Always include error handling + close in CLEANUP

### "How do I wrap an unreleased FM?" questions
→ Show Tier 2 wrapper pattern (Standard ABAP class → release as C1 → consume from ABAP Cloud)
→ Reference Clean Core skill for wrapper governance

### "How do I receive inbound calls?" questions
→ Show IF_HTTP_SERVICE_EXTENSION implementation
→ Include authentication check pattern

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
