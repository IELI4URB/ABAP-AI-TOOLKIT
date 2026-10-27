---
name: abap-integration-patterns
description: 'Design and review SAP ABAP Cloud integrations. Use for outbound HTTP or REST, SOAP proxies, communication scenarios and arrangements, inbound HTTP services, OAuth or JWT, RFC Tier 2 wrappers, Event Mesh connectivity, AIF, remote calls, and external API failures.'
metadata:
  version: 2.0.0
  tags: abap integration http rest soap rfc event-mesh communication-arrangement abap-cloud
---

# ABAP Cloud Integration Patterns

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

Use this skill as the integration router. The complete integration reference is inlined below.

## Ownership

This skill owns protocol choice, communication-management artifacts, remote contracts, connectivity, and integration observability. Use `abap-error-handling-resilience` for reusable retry, circuit-breaker, and logging policy; use `abap-events-and-enhancements` for RAP event semantics; use `abap-iam-authorization` for authorization design.

## Workflow

1. Establish landscape, release, direction, protocol, trust boundary, volume, latency, and delivery guarantees.
2. Inspect the provider contract, generated proxy or client signatures, payload schema, authentication, errors, limits, and released API status.
3. Select the pattern and communication artifacts before writing caller code.
4. Read only the matching reference sections below.
5. Define timeout, retry/idempotency, monitoring, credential rotation, and failure recovery.
6. Validate success, protocol errors, malformed payloads, authorization failure, timeout, duplicate delivery, and unavailable downstream behavior.

## Reference Routing

| Request | Read sections in `integration-complete.md` |
|---|---|
| Pattern selection | 1, 2, 10 |
| HTTP or REST | 3, 4, 11 |
| SOAP | 5, 11 |
| RFC Tier 2 wrapper | 6 |
| Inbound HTTP | 7 |
| OAuth or JWT | 8 |
| Event Mesh connectivity | 9 |
| Review or quick lookup | 10, 11, 12 |

## Mandatory Gates

- Never hardcode endpoints or credentials; use target-supported communication management.
- RFC wrappers are Private Cloud Tier 2 options only and require released C1 contracts plus Clean Core governance.
- Verify request/response types, lengths, optionality, status mapping, serialization, and exception contracts.
- Confirm every SAP API/class is released for the exact landscape and release.
- For syntax-bearing output, verify against current SAP Help and report `Syntax confidence: verified`; unresolved syntax blocks production use.
- Release guidance must include security, performance/volume, ATC, contract tests, rollback, credential operations, and monitoring evidence.

## Response Shape

For non-trivial requests, state landscape and contract assumptions, selected pattern, required artifacts, data/error flow, resilience and security controls, validation, and residual risks.

## ABAP Cloud Integration Patterns — Complete Reference

> **Audience:** Senior ABAP Cloud developers building outbound/inbound integrations on SAP BTP ABAP Environment, S/4HANA Public Cloud, and S/4HANA Private Cloud (2023+).
> **Last updated:** 2025 | **Syntax:** ABAP Cloud (Tier 1 / Tier 2 where noted)

---

### 1. Integration Decision Matrix

Use this matrix to select the correct integration technology before writing a single line of code.

| Technology | Direction | Protocol | ABAP Cloud Tier | Public Cloud | Private Cloud | BTP ABAP Env | Best For |
|---|---|---|---|---|---|---|---|
| **HTTP REST Client** (`CL_WEB_HTTP_CLIENT_MANAGER`) | Outbound | HTTP/S + JSON/XML | Tier 1 | ✅ | ✅ (2022+) | ✅ | Calling external REST APIs, microservices |
| **SOAP Proxy** (SPROXY generated class) | Outbound | SOAP/WSDL | Tier 1 | ✅ | ✅ | ✅ | SAP-to-SAP SOAP services, legacy enterprise services |
| **RFC Wrapper (Tier 2)** | Outbound/Internal | RFC shim → released API | Tier 2 | ❌ | ✅ | ❌ | Accessing unreleased BAPIs/FMs in Private Cloud only |
| **HTTP Service (Inbound)** (`IF_HTTP_SERVICE_EXTENSION`) | Inbound | HTTP/S + JSON | Tier 1 | ✅ | ✅ | ✅ | Webhooks, custom REST endpoints, event ingestion |
| **OData Service (RAP-based)** | Inbound | OData v4 | Tier 1 | ✅ | ✅ | ✅ | UI consumption, standard CRUD via Fiori |
| **Event Mesh / Enterprise Events** | Outbound (async) | AMQP/MQTT | Tier 1 | ✅ | ✅ (2023+) | ✅ | Loose coupling, cross-system notifications |
| **AIF (Application Interface Framework)** | Both | Any | Tier 1 (monitor only) | ✅ | ✅ | ❌ | Monitoring/reprocessing existing iDocs/proxies |
| **IDoc / EDI** | Both | IDoc segments | Not cloud-native | ❌ | ✅ (legacy) | ❌ | EDI B2B, legacy SAP integration |

> **Golden Rule #0:** If an HTTP REST API exists for your target system, prefer it over RFC/IDoc in all cloud scenarios.

---

### 2. Communication Architecture

ABAP Cloud enforces a strict separation between **connection topology** (managed by Basis/administrators) and **developer code** (which stays credential-agnostic).

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Developer Artifacts                          │
│  ABAP Class  ──calls──►  Communication Scenario (SCEN_ID)          │
│                          └─ declares which outbound services exist  │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │ bound at runtime by admin
┌──────────────────────────────────▼──────────────────────────────────┐
│                       Administrator Artifacts                       │
│  Communication System   (target host, cert/OAuth metadata)          │
│  Communication Arrangement  (binds scenario ↔ system + credentials) │
└─────────────────────────────────────────────────────────────────────┘
```

#### Artifact Responsibilities

| Artifact | Created by | Purpose | Contains credentials? |
|---|---|---|---|
| **Communication Scenario** | Developer (ADT) | Declares outbound service IDs and required auth types | No |
| **Communication System** | Admin (Fiori) | Stores host, port, TLS certificates, OAuth metadata | Yes |
| **Communication Arrangement** | Admin (Fiori) | Binds a scenario to a system; activates the connection | Yes (user/password or OAuth token endpoint) |

#### How Developer Code Stays Agnostic

```abap
" Developer only references the Communication Scenario ID.
" Credentials and host are resolved at runtime from the active arrangement.
DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
    comm_scenario  = 'ZSCEN_MY_EXTERNAL_API'   " <-- only this is hardcoded
    service_id     = 'ZSCEN_MY_EXTERNAL_API_REST'
    comm_system_id = DATA(lv_system_id) ).       " optional: multi-system routing
```

---

### 3. HTTP REST Client Pattern

#### 3.1 Full GET with JSON Response

```abap
CLASS zcl_integration_http_client DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_product,
             product_id   TYPE string,
             description  TYPE string,
             price        TYPE decfloat34,
             currency     TYPE waers,
           END OF ty_product.

    METHODS get_product
      IMPORTING iv_product_id TYPE string
      RETURNING VALUE(rs_product) TYPE ty_product
      RAISING   cx_web_http_client_error
                cx_http_no_service.

ENDCLASS.

CLASS zcl_integration_http_client IMPLEMENTATION.

  METHOD get_product.
    " 1. Resolve destination via Communication Arrangement (no hardcoded URL)
    DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
        comm_scenario = 'ZSCEN_PRODUCT_API'
        service_id    = 'ZSCEN_PRODUCT_API_REST' ).

    " 2. Obtain HTTP client from manager
    DATA(lo_client) = cl_web_http_client_manager=>create_by_destination(
        i_destination = lo_dest ).

    " 3. Build request
    DATA(lo_request) = lo_client->get_http_request( ).
    lo_request->set_uri_path( iv_uri_path = |/products/{ iv_product_id }| ).
    lo_request->set_header_field(
        i_name  = 'Accept'
        i_value = 'application/json' ).
    lo_request->set_header_field(
        i_name  = 'X-Correlation-ID'
        i_value = cl_system_uuid=>create_uuid_c32_static( ) ).

    " 4. Execute and check status
    DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
    DATA(lv_status)   = lo_response->get_status( ).

    IF lv_status-code <> 200.
      RAISE EXCEPTION TYPE cx_web_http_client_error
        MESSAGE e001(zintegration_msg)
          WITH lv_status-code lv_status-reason.
    ENDIF.

    " 5. Deserialize JSON response
    DATA(lv_json) = lo_response->get_text( ).
    /ui2/cl_json=>deserialize(
        EXPORTING json        = lv_json
                  pretty_name = /ui2/cl_json=>pretty_mode-camel_case
        CHANGING  data        = rs_product ).
  ENDMETHOD.

ENDCLASS.
```

#### 3.2 HTTP POST with Retry Logic

```abap
CLASS zcl_http_post_with_retry DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_order_request,
             order_type   TYPE string,
             sales_org    TYPE vkorg,
             items        TYPE STANDARD TABLE OF string WITH DEFAULT KEY,
           END OF ty_order_request.

    TYPES: BEGIN OF ty_order_response,
             order_id TYPE string,
             status   TYPE string,
             message  TYPE string,
           END OF ty_order_response.

    CLASS-METHODS post_order
      IMPORTING is_request        TYPE ty_order_request
                iv_max_retries    TYPE i DEFAULT 3
      RETURNING VALUE(rs_response) TYPE ty_order_response
      RAISING   cx_web_http_client_error.

ENDCLASS.

CLASS zcl_http_post_with_retry IMPLEMENTATION.

  METHOD post_order.
    DATA(lo_dest)   = cl_http_destination_provider=>create_by_comm_arrangement(
        comm_scenario = 'ZSCEN_ORDER_MGMT'
        service_id    = 'ZSCEN_ORDER_MGMT_REST' ).
    DATA(lo_client) = cl_web_http_client_manager=>create_by_destination( lo_dest ).
    DATA(lo_request) = lo_client->get_http_request( ).
    lo_request->set_uri_path( '/orders' ).
    lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).

    " Serialize request payload
    DATA(lv_body) = /ui2/cl_json=>serialize(
        data        = is_request
        pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
    lo_request->set_text( lv_body ).

    " Retry loop with exponential back-off
    DATA lv_attempt  TYPE i VALUE 0.
    DATA lv_delay_ms TYPE i VALUE 500.
    DATA lo_response TYPE REF TO if_web_http_response.

    DO iv_max_retries TIMES.
      lv_attempt += 1.
      TRY.
          lo_response = lo_client->execute( if_web_http_client=>post ).
          DATA(lv_status) = lo_response->get_status( ).
          CASE lv_status-code.
            WHEN 200 OR 201.
              /ui2/cl_json=>deserialize(
                  EXPORTING json        = lo_response->get_text( )
                            pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                  CHANGING  data        = rs_response ).
              RETURN.   " success — exit retry loop
            WHEN 429 OR 503.
              " Rate-limited or service unavailable — wait and retry
              IF lv_attempt < iv_max_retries.
                cl_abap_progress_indicator=>progress_indicate(
                    i_text               = |Retry { lv_attempt }/{ iv_max_retries }...|
                    i_output_immediately = abap_true ).
                " In production use a proper async wait; here we simulate with a tight loop
                lv_delay_ms = lv_delay_ms * 2.
              ENDIF.
            WHEN OTHERS.
              RAISE EXCEPTION TYPE cx_web_http_client_error.
          ENDCASE.
        CATCH cx_web_http_client_error INTO DATA(lx_http).
          IF lv_attempt >= iv_max_retries.
            RAISE EXCEPTION lx_http.
          ENDIF.
      ENDTRY.
    ENDDO.
  ENDMETHOD.

ENDCLASS.
```

---

### 4. HTTP with JSON Serialization

#### Using CL_WEB_HTTP_UTILITY (newer API, 2023+)

```abap
" GET_CANONICAL_JSON_BODY: serializes any ABAP structure/table to canonical JSON
DATA: ls_payload  TYPE zcl_my_class=>ty_request_payload,
      lo_response TYPE REF TO if_web_http_response.

ls_payload-action    = 'CREATE'.
ls_payload-entity_id = lv_id.

DATA(lo_client) = cl_web_http_client_manager=>create_by_destination( lo_dest ).
DATA(lo_req)    = lo_client->get_http_request( ).

" Serialize with canonical helper
cl_web_http_utility=>set_request_json_body(
    io_request = lo_req
    iv_json    = cl_web_http_utility=>get_canonical_json_body( ls_payload ) ).

lo_response = lo_client->execute( if_web_http_client=>post ).

" Deserialize response
DATA ls_result TYPE zcl_my_class=>ty_response_payload.
cl_web_http_utility=>get_response_json_body(
    io_response = lo_response
    ev_json     = DATA(lv_json_out) ).

/ui2/cl_json=>deserialize(
    EXPORTING json        = lv_json_out
              pretty_name = /ui2/cl_json=>pretty_mode-camel_case
    CHANGING  data        = ls_result ).
```

#### JSON Field Mapping Tips

| Scenario | Technique |
|---|---|
| Snake_case JSON ↔ CamelCase ABAP | `/UI2/CL_JSON pretty_name = camel_case` |
| Nested objects | Use nested ABAP structures; `/UI2/CL_JSON` maps recursively |
| Arrays | Use `STANDARD TABLE OF` with `DEFAULT KEY` |
| Date/time (ISO 8601) | Convert with `CL_ABAP_UTCLONG_UTILS` after deserialization |
| Null values | Use `REF TO` or string `'null'` check post-deserialization |

---

### 5. SOAP Proxy Pattern

#### 5.1 Generating the Stub

1. Open **SPROXY** transaction (Private Cloud) or **ADT → New → Service Consumption Model** (Public Cloud / BTP).
2. Provide the WSDL URL or import the `.wsdl` file.
3. ABAP Workbench generates: stub class `ZCO_<SERVICE>`, message classes, and the associated data dictionary types.
4. The generated proxy class implements `IF_WSADMIN_STUB`.

#### 5.2 Calling the Stub

```abap
METHOD call_external_credit_check.
  DATA(lo_proxy) = NEW zco_credit_check_service( ).

  " Bind the logical port (maps to Communication Arrangement)
  lo_proxy->set_logical_port( 'ZPORT_CREDIT_CHECK' ).

  DATA ls_request  TYPE zco_credit_check_req.
  DATA ls_response TYPE zco_credit_check_resp.

  ls_request-customer_id   = iv_customer_id.
  ls_request-credit_amount = iv_amount.
  ls_request-currency      = iv_currency.

  TRY.
      lo_proxy->check_credit(
          EXPORTING input  = ls_request
          IMPORTING output = ls_response ).

      rv_approved = ls_response-approved.

    CATCH cx_ai_system_fault INTO DATA(lx_fault).
      " Transient system error — log and raise application error
      MESSAGE lx_fault->get_text( ) TYPE 'E'.

    CATCH cx_ai_application_fault INTO DATA(lx_app).
      " Business exception from the remote service
      RAISE EXCEPTION TYPE zcx_credit_check_rejected
        EXPORTING text = lx_app->get_text( ).
  ENDTRY.
ENDMETHOD.
```

#### 5.3 Communication Arrangement for SOAP

- Create a **Communication Scenario** in ADT that references the SOAP logical port.
- Admin binds the **Communication Arrangement** → **Communication System** containing the SOAP endpoint URL and WS-Security credentials (Basic Auth or X.509).

---

### 6. RFC Wrapper (Tier 2) — Private Cloud Only

> ⚠️ **Tier 2 only.** RFC wrappers access unreleased APIs and are therefore **not available** in Public Cloud or BTP ABAP Environment. Use this pattern exclusively in S/4HANA Private Cloud where no Tier 1 API exists.

#### 6-Step Wrapping Process

| Step | Action | Notes |
|---|---|---|
| 1 | Identify the unreleased FM/BAPI | Check for C1-released OData/BAPI alternative first |
| 2 | Create `PRIVATE` wrapper class in a custom package | Class cannot be subclassed; prevents misuse |
| 3 | Implement method that calls FM via `CALL FUNCTION` | Keep the method signature clean (no raw RFC data types leaking out) |
| 4 | Map RFC return codes/BAPIRET2 to clean ABAP exceptions | Never return BAPIRET2 raw to callers |
| 5 | Add unit test with mock using `CL_ABAP_TESTDOUBLE_CLASS` | Mock the FM call in test class |
| 6 | Release wrapper class as **C1** in ADT | Only then can other Tier 1 code call it |

#### RFC Wrapper Skeleton

```abap
CLASS zcl_rfc_material_wrapper DEFINITION
  PUBLIC FINAL CREATE PRIVATE.   " PRIVATE: use factory method

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_material_data,
             matnr   TYPE matnr,
             maktx   TYPE maktx,
             meins   TYPE meins,
             mtart   TYPE mtart,
           END OF ty_material_data.

    CLASS-METHODS get_instance
      RETURNING VALUE(ro_instance) TYPE REF TO zcl_rfc_material_wrapper.

    METHODS get_material
      IMPORTING iv_matnr          TYPE matnr
                iv_language       TYPE spras DEFAULT sy-langu
      RETURNING VALUE(rs_material) TYPE ty_material_data
      RAISING   zcx_material_not_found
                zcx_rfc_wrapper_error.

ENDCLASS.

CLASS zcl_rfc_material_wrapper IMPLEMENTATION.

  METHOD get_instance.
    ro_instance = NEW #( ).
  ENDMETHOD.

  METHOD get_material.
    DATA: ls_headdata    TYPE bapi_mara,
          lt_makt        TYPE STANDARD TABLE OF bapi_makt,
          lt_return      TYPE bapiret2_t.

    " Call unreleased BAPI (Tier 2 only — never in Public Cloud)
    CALL FUNCTION 'BAPI_MATERIAL_GET_DETAIL'
      EXPORTING
        material       = iv_matnr
        plant          = space
      IMPORTING
        material_general_data = ls_headdata
      TABLES
        materialdescription   = lt_makt
        return                = lt_return.

    " Map BAPIRET2 errors to typed exceptions
    LOOP AT lt_return ASSIGNING FIELD-SYMBOL(<ls_ret>)
        WHERE type = 'E' OR type = 'A'.
      IF <ls_ret>-id = 'MM' AND <ls_ret>-number = '007'.
        RAISE EXCEPTION TYPE zcx_material_not_found
          EXPORTING matnr = iv_matnr.
      ELSE.
        RAISE EXCEPTION TYPE zcx_rfc_wrapper_error
          EXPORTING
            msgid  = <ls_ret>-id
            msgno  = <ls_ret>-number
            msgv1  = <ls_ret>-message_v1.
      ENDIF.
    ENDLOOP.

    " Map to clean output structure
    rs_material-matnr = iv_matnr.
    rs_material-mtart = ls_headdata-mtart.
    rs_material-meins = ls_headdata-base_uom.

    READ TABLE lt_makt ASSIGNING FIELD-SYMBOL(<ls_makt>)
        WITH KEY language = iv_language.
    IF sy-subrc = 0.
      rs_material-maktx = <ls_makt>-matl_desc.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

---

### 7. Inbound HTTP Handler

#### 7.1 Implementing the Handler Class

```abap
CLASS zcl_inbound_webhook_handler DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

ENDCLASS.

CLASS zcl_inbound_webhook_handler IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.
    " 1. Route by HTTP method
    DATA(lv_method) = request->get_header_field( '~request_method' ).

    CASE lv_method.
      WHEN 'POST'.
        handle_post( request = request response = response ).
      WHEN 'GET'.
        handle_get( request = request response = response ).
      WHEN OTHERS.
        response->set_status( 405 ).
        response->set_header_field( i_name = 'Allow' i_value = 'GET, POST' ).
    ENDCASE.
  ENDMETHOD.

  METHOD handle_post.
    " 2. Read and validate body
    DATA(lv_body) = request->get_text( ).
    IF lv_body IS INITIAL.
      response->set_status( 400 ).
      response->set_text( '{"error":"Empty request body"}' ).
      RETURN.
    ENDIF.

    " 3. Deserialize event payload
    TYPES: BEGIN OF ty_event,
             event_type   TYPE string,
             entity_id    TYPE string,
             timestamp    TYPE string,
             payload      TYPE string,
           END OF ty_event.
    DATA ls_event TYPE ty_event.

    /ui2/cl_json=>deserialize(
        EXPORTING json        = lv_body
                  pretty_name = /ui2/cl_json=>pretty_mode-camel_case
        CHANGING  data        = ls_event ).

    " 4. Business logic — hand off to service class
    DATA(lo_processor) = NEW zcl_webhook_event_processor( ).
    lo_processor->process_event(
        iv_event_type = ls_event-event_type
        iv_entity_id  = ls_event-entity_id
        iv_payload    = ls_event-payload ).

    " 5. Return 202 Accepted (async processing)
    TYPES: BEGIN OF ty_ack,
             status     TYPE string,
             request_id TYPE string,
           END OF ty_ack.
    DATA ls_ack TYPE ty_ack.
    ls_ack-status     = 'ACCEPTED'.
    ls_ack-request_id = cl_system_uuid=>create_uuid_c32_static( ).

    response->set_status( 202 ).
    response->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
    response->set_text( /ui2/cl_json=>serialize( data = ls_ack ) ).
  ENDMETHOD.

  METHOD handle_get.
    " Read query parameter: /health?detail=true
    DATA(lv_detail) = request->get_form_field( 'detail' ).

    TYPES: BEGIN OF ty_health,
             status   TYPE string,
             version  TYPE string,
             detail   TYPE string,
           END OF ty_health.
    DATA ls_health TYPE ty_health.
    ls_health-status  = 'UP'.
    ls_health-version = '1.0.0'.
    IF lv_detail = 'true'.
      ls_health-detail = |System: { sy-sysid } / Client: { sy-mandt }|.
    ENDIF.

    response->set_status( 200 ).
    response->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
    response->set_text( /ui2/cl_json=>serialize( data = ls_health ) ).
  ENDMETHOD.

ENDCLASS.
```

#### 7.2 Registration in ADT

1. **ADT → New → HTTP Service** — set the handler class to `ZCL_INBOUND_WEBHOOK_HANDLER`.
2. Activate; ADT generates a URL pattern `/sap/bc/http/sap/<service_name>`.
3. Expose via **Communication Scenario** (inbound) so admin can create an arrangement granting external access.

---

### 8. OAuth 2.0 / JWT Authentication (2025)

#### Auth Type Mapping

| Flow | Communication Arrangement Setting | When to Use |
|---|---|---|
| **Client Credentials** | OAuth 2.0 Client Credentials Grant | Machine-to-machine, background jobs |
| **Authorization Code + PKCE** | OAuth 2.0 Authorization Code | User-delegated, Fiori-launched integrations |
| **JWT Client Auth (RFC 7523)** | OAuth 2.0 JWT Bearer Token | High-security, certificate-based client auth |
| **Basic Auth** | User ID + Password | Legacy systems only; avoid for new development |
| **mTLS / X.509** | Client Certificate | SAP BTP service bindings, zero-trust patterns |

#### Client Credentials Flow — Code Impact

```abap
" No token management in ABAP code! The Communication Arrangement
" holds the client_id, client_secret, and token endpoint.
" CL_WEB_HTTP_CLIENT_MANAGER fetches and caches the token transparently.

DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
    comm_scenario = 'ZSCEN_OAUTH_API'
    service_id    = 'ZSCEN_OAUTH_API_REST' ).

" From developer perspective, this is identical to Basic Auth usage.
" OAuth token negotiation happens inside the framework.
DATA(lo_client) = cl_web_http_client_manager=>create_by_destination( lo_dest ).
DATA(lo_req)    = lo_client->get_http_request( ).
lo_req->set_uri_path( '/protected-resource' ).
DATA(lo_resp)   = lo_client->execute( if_web_http_client=>get ).
```

#### JWT-Based Client Authentication (2025 Pattern)

For scenarios where the target system requires a signed JWT assertion instead of a client secret:
- Set **Auth Method = JWT Bearer** in Communication System.
- Upload the private key certificate to the Communication System's **Client Certificate** section.
- The framework signs the JWT assertion using `RS256` and exchanges it for a Bearer token at the token endpoint — all transparent to ABAP code.

---

### 9. Event Mesh Integration

#### 9.1 Architecture Overview

```
ABAP Cloud System
  └─► RAP BO raises Business Event (RAISE ENTITY EVENT)
        └─► Enterprise Event Enablement framework
              └─► SAP Event Mesh / Advanced Event Mesh
                    └─► Subscriber (BTP, external system, ABAP tenant)
```

#### 9.2 Communication Arrangement for Event Mesh

| Setting | Value |
|---|---|
| Communication Scenario | `SAP_COM_0092` (Enterprise Messaging) |
| Queue prefix | Configured in SAP Event Mesh service instance |
| Topic naming | `sap/s4/beh/<module>/<version>/<Entity>/<EventType>/<version>` |

**Example topic:** `sap/s4/beh/salesorder/v1/SalesOrder/Created/v1`

#### 9.3 Enabling Event Binding in ADT

1. **ADT → New → Event Binding** — select the RAP BO and the event type.
2. Specify the topic namespace (prefix assigned by admin, e.g., `default/sap.s4.beh/`).
3. The binding artifact links the BDEF event to the Communication Arrangement channel.
4. Activate and transport.

#### 9.4 Monitoring

- **Fiori app:** *Enterprise Event Enablement — Event Monitor* (`/n/IWXBE/MON`).
- Shows: event queue depth, failed deliveries, retry count.
- **Failed events** can be replayed from the monitor without code change.

---

### 9A. Data Integration — Federation vs Replication

Process integration (HTTP/SOAP/RFC/Event, above) moves *messages*. **Data integration** gives external tools direct access to CDS view-entity data. Two modes:

| Characteristic | Data Federation | Data Replication |
|---|---|---|
| Data location | Stays in source; requests delegated and run there | Copied to a target system; requests run locally on the copy |
| Consistency | Stateful (transactions span multiple statements), live access | Stateless; data often transformed in transit (enrich, clean, consolidate) |
| Access control | Checked locally per system; business-user **or** privileged mode | Runs in **privileged mode**; auths replicated or redefined on consumer side |
| Technical impl | **SQL service over ODBC** | **SQL service over ODBC** (SAP Datasphere: replication middleware) |

Source: SAP Help, ABAP Cloud Develop Integration Services.

- **Federation** — use when live access to the most recent source data is required, or to rely on the source system's own data-access control.
- **Replication** — use when it is more efficient to move business data to the target before access (e.g. a data warehouse).
- Both expose **released CDS view entities** via the **SQL service** (ODBC) — never direct table reads.

---

### 10. Golden Rules for ABAP Cloud Integration

| # | Rule | Anti-Pattern (Never Do) |
|---|---|---|
| 1 | Always resolve connections via **Communication Arrangement** | `CALL FUNCTION 'HTTP_GET' EXPORTING host = 'https://api.example.com'` |
| 2 | **Never hardcode credentials** | Storing API keys in constants or Customizing tables |
| 3 | Always **check HTTP status codes** before processing response | Calling `get_text()` without checking `get_status()` |
| 4 | Always handle **`CX_WEB_HTTP_CLIENT_ERROR`** | Letting network exceptions surface as ABAP runtime errors |
| 5 | Use **typed exceptions** in wrapper methods | Exposing raw BAPIRET2 or SYSUBRC to callers |
| 6 | **Log correlation IDs** on all outbound calls | Debugging production issues without a trace |
| 7 | Use **`/UI2/CL_JSON pretty_mode-camel_case`** for SAP API payloads | Manual string concatenation to build JSON |
| 8 | Keep **retry logic** at the infrastructure layer, not business logic | Retry loops inside RAP action methods |
| 9 | **RFC Wrapper → Tier 2 only** | Calling unreleased FMs from Tier 1 code in Public Cloud |
| 10 | Always set **`Content-Type: application/json`** on POST/PATCH/PUT | Sending JSON without a content type header |

---

### 11. Exception Handling Reference

```abap
" Canonical TRY/CATCH pattern for all HTTP outbound calls
TRY.
    DATA(lo_dest)   = cl_http_destination_provider=>create_by_comm_arrangement(
        comm_scenario = lc_scenario
        service_id    = lc_service_id ).
    DATA(lo_client) = cl_web_http_client_manager=>create_by_destination( lo_dest ).

    " ... build request ...

    DATA(lo_resp) = lo_client->execute( if_web_http_client=>get ).
    DATA(ls_stat) = lo_resp->get_status( ).

    CASE ls_stat-code.
      WHEN 200 OR 201 OR 202.
        " happy path
      WHEN 400.
        RAISE EXCEPTION TYPE zcx_integration_bad_request
            EXPORTING body = lo_resp->get_text( ).
      WHEN 401 OR 403.
        RAISE EXCEPTION TYPE zcx_integration_auth_error.
      WHEN 404.
        RAISE EXCEPTION TYPE zcx_integration_not_found.
      WHEN 429.
        " too many requests — propagate for retry by caller
        RAISE EXCEPTION TYPE zcx_integration_rate_limited
            EXPORTING retry_after = lo_resp->get_header_field( 'Retry-After' ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_integration_server_error
            EXPORTING status_code = ls_stat-code
                      reason      = ls_stat-reason.
    ENDCASE.

  CATCH cx_http_no_service INTO DATA(lx_no_svc).
    " No active Communication Arrangement found — config problem
    RAISE EXCEPTION TYPE zcx_integration_config_error
        EXPORTING prev = lx_no_svc.

  CATCH cx_web_http_client_error INTO DATA(lx_http).
    " Network-level failure (timeout, TLS, DNS)
    RAISE EXCEPTION TYPE zcx_integration_network_error
        EXPORTING prev = lx_http.
ENDTRY.
```

---

### 12. Quick-Reference Card

```
OUTBOUND REST:    cl_http_destination_provider=>create_by_comm_arrangement( )
                  cl_web_http_client_manager=>create_by_destination( )
                  lo_req->set_uri_path / set_header_field / set_text
                  lo_client->execute( if_web_http_client=>get/post/patch/delete )
                  lo_resp->get_status( ) / get_text( )

INBOUND HTTP:     IMPLEMENT if_http_service_extension~handle_request
                  request->get_header_field / get_form_field / get_text
                  response->set_status / set_header_field / set_text

JSON:             /ui2/cl_json=>serialize( data = ... )
                  /ui2/cl_json=>deserialize( json = ... CHANGING data = ... )

SOAP:             NEW zco_<service>( )->set_logical_port( 'ZPORT_...' )
                  CATCH cx_ai_system_fault / cx_ai_application_fault

EVENT MESH:       RAISE ENTITY EVENT in SAVE_MODIFIED
                  Event Binding artifact → SAP_COM_0092 arrangement
```
