---
name: abap-released-classes
description: Quick reference for released ABAP classes available in ABAP Cloud. Comprehensive catalog of 50+ released classes organized by category with ready-to-use code examples.
---

# Released ABAP Classes Reference

Complete catalog of released classes available in **ABAP Cloud (BTP ABAP Environment, S/4HANA Public Cloud)** and on-premise S/4HANA systems. Use this skill to find the correct released class for your use case and get ready-to-use code examples.

> **Key:** Released classes (C1 contract) are guaranteed to remain available across ABAP Cloud upgrades. Use these instead of unreleased classes when available.

## SAP Help Syntax Grounding (Mandatory)

For ABAP/CDS syntax, use SAP Help as source of truth.

Rules:
- Do not provide unverified syntax for released classes or ABAP statements without SAP Help reference.
- For non-trivial syntax responses, add a short "Syntax references" section with SAP Help links used.
- If exact syntax is uncertain, explicitly mark it as draft and require SAP Help verification.

Core SAP Help references:
- https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/docs/abap-cloud/abap-released-apis/abap-released-apis
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model

Reference files:
- `references/released-classes-catalog.md` — extended catalog of 60+ released classes grouped by category (String, Date, HTTP, Log, XCO, JSON, UUID, Auth, Testing, etc.)

---

## Console & Output

| Class | Purpose | Example |
|-------|---------|---------|
| `IF_OO_ADT_CLASSRUN` | ADT class run interface (testing, debugging) | `INTERFACE if_oo_adt_classrun PUBLIC.` |
| `CL_DEMO_CLASSRUN` | Demo classrun implementation | Base class for executable tests |

**Example: Classrun for console output**
```abap
CLASS zcl_demo_classrun DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_demo_classrun IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( |Hello ABAP Cloud!| ).
  ENDMETHOD.
ENDCLASS.
```

---

## UUID & Identifiers

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_SYSTEM_UUID` | Generate UUIDs (version 4) | `CL_SYSTEM_UUID=>CREATE_UUID_C1( )` |
| `XCO_CP_UUID` | XCO UUID API (modern, recommended) | `XCO_CP_UUID=>CREATE_V4( )` |

**Example: Generate UUID**
```abap
DATA lv_uuid TYPE string.
lv_uuid = XCO_CP_UUID=>CREATE_V4( )->VALUE.

" Or classic approach:
DATA lv_uuid_c1 TYPE C VALUE 'C1'.
CL_SYSTEM_UUID=>CREATE_UUID_C1(
  IMPORTING uuid = lv_uuid_c1
).
```

---

## Time & Date

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_ABAP_CONTEXT_INFO` | Current user, system date/time | `CL_ABAP_CONTEXT_INFO=>GET_SYSTEM_TIME( )` |
| `CL_ABAP_UTCLONG` | UTC timestamp handling | `CL_ABAP_UTCLONG=>UTCLONG_CURRENT( )` |
| `XCO_CP_TIME` | XCO time/date API (modern) | `XCO_CP_TIME=>UTILITY=>GET_CURRENT_UTC_TIME( )` |

**Example: Get current UTC time and user**
```abap
DATA(lv_current_time) = CL_ABAP_CONTEXT_INFO=>GET_SYSTEM_TIME( ).
DATA(lv_current_user) = CL_ABAP_CONTEXT_INFO=>GET_USER_TECHNICAL_NAME( ).
DATA(lv_utc_timestamp) = XCO_CP_TIME=>UTILITY=>GET_CURRENT_UTC_TIME( ).
```

---

## String Processing

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_ABAP_STRING_UTILITIES` | String manipulation (split, replace) | `CL_ABAP_STRING_UTILITIES=>SPLIT( )` |
| `CL_HTTP_UTILITY` | URL encoding/decoding | `CL_HTTP_UTILITY=>ENCODE_UTF8( )` |
| `CL_SXML_STRING_WRITER` | XML string writer | Build XML documents |

**Example: String split and URL encoding**
```abap
" Split string by delimiter
DATA(parts) = CL_ABAP_STRING_UTILITIES=>SPLIT(
  EXPORTING
    string    = 'apple,banana,orange'
    separator = ','
).

" URL encode
DATA(encoded) = CL_HTTP_UTILITY=>ENCODE_UTF8( 'hello world' ).
```

---

## JSON & XML Processing

| Class | Purpose | Example |
|-------|---------|---------|
| `XCO_CP_JSON` | XCO JSON API (modern, recommended) | `XCO_CP_JSON=>PARSER` |
| `/UI2/CL_JSON` | Classic JSON serialization | Still available in Cloud |
| `CL_SXML_DOCUMENT` | XML document builder | Create XML structures |
| `CL_SXML_STRING_WRITER` | XML string writer | Serialize to string |

**Example: Parse JSON (XCO)**
```abap
" Modern XCO approach
DATA(json_data) = XCO_CP_JSON=>PARSER=>PARSE( json_string ).
DATA(name) = json_data->get_child_by( name = 'name' )->to_string( ).

" Classic approach (still released)
/UI2/CL_JSON=>DESERIALIZE(
  EXPORTING
    json  = json_string
    jsonx = lv_jsonx
  IMPORTING
    data  = ls_data
).
```

**Example: Build XML**
```abap
DATA(doc) = CL_SXML_DOCUMENT=>NEW( ).
DATA(root) = doc->CREATE_ELEMENT( 'root' ).
doc->APPEND_CHILD( root ).

DATA(child) = doc->CREATE_ELEMENT_NS(
  NAME      = 'item'
  VALUE     = 'Hello'
).
root->APPEND_CHILD( child ).

DATA(xml_string) = doc->GET_MONOLITHIC_XML( ).
```

---

## HTTP & REST

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_WEB_HTTP_CLIENT_MANAGER` | Modern HTTP client (released, recommended) | GET, POST, PUT, DELETE, PATCH |
| `CL_HTTP_DESTINATION_PROVIDER` | Destination lookup for HTTP calls | Get HTTP destination by name |
| `CL_WEB_HTTP_UTILITY` | HTTP utility functions | Cookie handling, URL parsing |

**Example: HTTP GET with destination**
```abap
" Get destination
DATA(destination) = CL_HTTP_DESTINATION_PROVIDER=>CREATE_BY_LOGICAL_DESTINATION(
  i_logical_destination_name = 'EXTERNAL_API'
).

" Create HTTP client
DATA(client) = CL_WEB_HTTP_CLIENT_MANAGER=>CREATE_BY_HTTP_DESTINATION( destination ).

" GET request
DATA(response) = client->GET( '/api/v1/users' ).
DATA(status) = response->GET_STATUS( ).
DATA(body) = response->GET_TEXT( ).
```

**Example: POST with JSON body**
```abap
DATA(client) = CL_WEB_HTTP_CLIENT_MANAGER=>CREATE_BY_HTTP_DESTINATION( destination ).

DATA(request_body) = NEW cl_http_entity( ).
request_body->SET_DATA( |{ "name":"John", "age":30 }| ).

DATA(response) = client->POST(
  i_request_entity = request_body
  i_uri_path       = '/api/v1/users'
).

IF response->GET_STATUS( ) = '201'.
  out->write( 'User created successfully' ).
ENDIF.
```

---

## RAP & Business Object

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_ABAP_BEHV_AUX` | RAP auxiliary functions | Lock/unlock handling |
| `CL_ABAP_BEHAVIOR_HANDLER` | Behavior handler base class | Validation, determination, action |
| `CL_ABAP_BEHAVIOR_SAVER` | Saver handler base class | Custom save logic |

**Example: RAP validation handler**
```abap
CLASS zcl_travel_validation DEFINITION PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    
    METHODS validate_travel
      IMPORTING
        entities FOR READ TRAVEL
      EXPORTING
        failed   TYPE TABLE OF travel
        reported TYPE TABLE OF travel_message.
ENDCLASS.

CLASS zcl_travel_validation IMPLEMENTATION.
  METHOD validate_travel.
    " Validation logic
  ENDMETHOD.
ENDCLASS.
```

---

## Email & Notifications

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_BCS_MAIL_MESSAGE` | Email message creation | Build and send emails |
| `CL_ABAP_MAIL` | Simple mail sending (legacy) | Basic email |

**Example: Send email**
```abap
" Create mail message
DATA(mail) = cl_bcs_mail_message=>new( ).

" Add recipient
mail->add_recipient(
  i_address_string = 'user@example.com'
  i_copy           = if_bcs=>cc
).

" Set subject and body
mail->set_subject( 'Hello ABAP Cloud' ).
mail->set_main(
  cl_bcs_message_body_text=>new(
    i_text = 'This is a test email'
  )
).

" Send
TRY.
    mail->send( ).
  CATCH cx_bcs INTO DATA(ex).
    out->write( ex->get_longtext( ) ).
ENDTRY.
```

---

## Application Logs & Observability

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_BALI_LOG` | Application log API (released, recommended) | Structured logging |
| `CL_BALI_BATCH_MANAGER` | Batch log management | Log persistence |
| `CL_BALI_MESSAGE` | Log message building | Create log entries |

**Example: Application logging**
```abap
" Create application log
DATA(log) = cl_bali_log=>create(
  i_object   = 'ZCUSTOM_OBJ'
  i_subobject = 'EXECUTION'
).

" Add message
log->add_message(
  severity = if_bali_constants=>c_severity_information
  text     = |Processing started at { sy-timlo }|
).

" Save log
DATA(batch_manager) = cl_bali_batch_manager=>get_default_instance( ).
batch_manager->add_log( log ).
batch_manager->persist( ).
```

---

## Unit Testing

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_ABAP_UNIT_ASSERT` | Assertion methods | `assert_equals`, `assert_true`, etc. |
| `CL_ABAP_TESTDOUBLE` | Test double factory | Mock objects dynamically |
| `CL_OSQL_TEST_ENVIRONMENT` | SQL test environment | Stub database tables |
| `CL_CDS_TEST_ENVIRONMENT` | CDS test environment | Stub CDS views |

**Example: Unit test with assertions**
```abap
CLASS ztc_calculator DEFINITION FOR TESTING.
  PRIVATE SECTION.
    METHODS:
      test_add FOR TESTING,
      test_subtract FOR TESTING.
ENDCLASS.

CLASS ztc_calculator IMPLEMENTATION.
  METHOD test_add.
    DATA(calc) = NEW zcl_calculator( ).
    DATA(result) = calc->add( 5 10 ).
    cl_abap_unit_assert=>assert_equals(
      EXPORTING
        act = result
        exp = 15
    ).
  ENDMETHOD.
ENDCLASS.
```

---

## Random Numbers & Hashing

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_RANDOM` | Random number generation | Seed-based random numbers |
| `CL_ABAP_MESSAGE_DIGEST` | Hash functions (MD5, SHA1, SHA256) | Message digests |

**Example: Generate hash**
```abap
" SHA256 hash
DATA(hasher) = CL_ABAP_MESSAGE_DIGEST=>CREATE_SHA256( ).
hasher->ADD_STRING( 'password123' ).
DATA(hash_value) = hasher->GET_DIGEST( ).
```

---

## Regular Expressions

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_ABAP_REGEX` | Regular expression matching | Pattern matching, validation |

**Example: Email validation via regex**
```abap
DATA(regex) = CL_ABAP_REGEX=>CREATE_FROM_PATTERN(
  i_pattern = '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'
).

IF regex->IS_MATCHING( 'user@example.com' ).
  out->write( 'Valid email' ).
ENDIF.
```

---

## PDF Rendering

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_DOCUMENT_CONVERTER` | Document format conversion | PDF rendering from HTML |
| `CL_OO_PDF` | PDF document builder | Create PDF documents programmatically |

**Example: Convert HTML to PDF**
```abap
DATA(converter) = CL_DOCUMENT_CONVERTER=>CREATE( ).
DATA(pdf_data) = converter->CONVERT(
  EXPORTING
    i_type   = CL_DOCUMENT_CONVERTER=>FILETYPE_HTML
    i_source = html_content
).
```

---

## Parallel Processing & Threading

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_ABAP_PARALLEL` | Parallel processing framework | Execute tasks in parallel |
| `CL_ABAP_PARALLEL_PROVIDER` | Parallel execution provider | Manage parallel operations |

**Example: Parallel task execution**
```abap
" Define parallel task
CLASS zcl_parallel_task DEFINITION.
  PUBLIC SECTION.
    INTERFACES if_abap_parallel~task.
ENDCLASS.

" Execute in parallel
DATA(parallel) = CL_ABAP_PARALLEL=>CREATE( ).
parallel->SUBMIT_TASK( zcl_parallel_task ).
DATA(results) = parallel->GET_RESULTS( ).
```

---

## Advanced: Communication Arrangements

| Class | Purpose | Example |
|-------|---------|---------|
| `CL_COM_ARRANGEMENT_FACTORY` | Lookup communication arrangements | Get inbound destinations |
| `CL_HTTP_DESTINATION_PROVIDER` | HTTP destination resolver | By logical name or comm arrangement |

**Example: Resolve outbound destination from communication arrangement**
```abap
DATA(destination) = CL_HTTP_DESTINATION_PROVIDER=>CREATE_BY_COMM_ARRANGEMENT(
  i_comm_arrangement = 'EXTERNAL_REST_API'
  i_comm_system      = 'TARGET_SYSTEM'
).

DATA(client) = CL_WEB_HTTP_CLIENT_MANAGER=>CREATE_BY_HTTP_DESTINATION( destination ).
DATA(response) = client->GET( '/api/v1/data' ).
```

---

## Quick Decision Matrix

**Choosing the right class:**

| Use Case | Recommended Class | Notes |
|----------|-------------------|-------|
| Generate unique ID | `XCO_CP_UUID=>CREATE_V4( )` | Modern, XCO recommended |
| Get current time | `CL_ABAP_CONTEXT_INFO=>GET_SYSTEM_TIME( )` | Returns system time |
| Parse JSON | `XCO_CP_JSON=>PARSER` | Modern XCO API |
| HTTP REST call | `CL_WEB_HTTP_CLIENT_MANAGER` | Released, production-ready |
| Logging | `CL_BALI_LOG` | Structured, persistent |
| Unit test assertions | `CL_ABAP_UNIT_ASSERT` | Full assertion suite |
| Email | `CL_BCS_MAIL_MESSAGE` | Complete email builder |
| URL encoding | `CL_HTTP_UTILITY=>ENCODE_UTF8` | Safe URL encoding |
| Regex validation | `CL_ABAP_REGEX` | Pattern matching |
| Hash/digest | `CL_ABAP_MESSAGE_DIGEST` | MD5, SHA1, SHA256 |

---

## Tips

- ✅ Always prefer XCO (`XCO_CP_*`) and modern classes for new development
- ✅ Check SAP documentation for each class's full interface
- ✅ All listed classes are **released (C1)** in ABAP Cloud
- ✅ Use `/UI2/CL_JSON` when XCO JSON is not available (rare)
- ✅ Communication Arrangements > HTTP Destinations for credential management
- ❌ Never hardcode credentials; use destinations or communication arrangements

---

## References

- SAP Help: ABAP Cloud Released APIs
- SAP Fiori: Communication Arrangements (transaction `/n/IWFND/MAINT_SERVICE`)
- ADT: Released Objects Browser in Eclipse


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
