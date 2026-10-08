---
name: abap-released-classes
description: 'Find released ABAP classes and interfaces for ABAP Cloud. Use for XCO, UUID, JSON/XML, HTTP destinations, application logs, strings, dates, regex, hashing, email, PDF, testing, and communication arrangements when released API evidence is required.'
---

# Released ABAP Classes

Search the released-class catalog (included below) by capability.

## Workflow

1. Establish landscape, release/FPS, and required capability.
2. Find candidate classes in the catalog.
3. Verify release contract and exact method signature in the target system or current SAP Help.
4. Inspect input/output types and exceptions before producing code.
5. Validate activation and behavior in the target release.

## Gates

- Catalog presence is a discovery hint, not proof of release in every target.
- Never infer C1 status from a class name.
- Prefer target-system API-state evidence and generated signatures.
- Mark unverified examples as draft and do not call them production-ready.

## Output

Return capability, recommended released API, verified target/release, contract summary, minimal usage outline, alternatives, and evidence.

## Released ABAP Classes — Extended Catalog

Companion reference for the `abap-released-classes` skill. Lists additional released classes, interfaces, and key usage patterns for ABAP Cloud (BTP ABAP Environment, S/4HANA Public Cloud).

> **Discovery catalog only:** Verify each entry's API state, C1 contract, and visibility for the target language version/release. C0 means an extension contract, not "not released."

---

### String & Text Processing

| Class / Interface | Purpose | Key Methods |
|---|---|---|
| `CL_ABAP_STRING_UTILITIES` | String utilities | `SPLIT_BY_ANY_OF`, `JOIN` |
| `CL_ABAP_CONV_CODEPAGE` | Code-page conversion | `CREATE`, `CONVERT` |
| `CL_ABAP_REGEX` | Regular expressions | `CREATE_PCRE` |
| `CL_ABAP_MATCHER` | Regex matching | `FIND_ALL` |
| `CL_ABAP_FORMAT` | Numeric/date formatting | `PRINT_FLOAT` |

---

### Date, Time & Timestamps

| Class / Interface | Purpose | Key Methods |
|---|---|---|
| `CL_ABAP_CONTEXT_INFO` | System date/time/user context | `GET_SYSTEM_DATE`, `GET_SYSTEM_TIME`, `GET_USER_TECHNICAL_NAME` |
| `CL_ABAP_DATFM` | Date format conversion | `DATE_CONVERT_TO_DATS_FORMAT` |
| `CL_ABAP_TSTMP` | Timestamp arithmetic | `ADD_TO`, `SUBTRACT`, `GET_CURRENT_TIMESTAMPL` |
| `CL_ABAP_UTCLONG` | UTC long timestamp handling | `DIFF`, `GET` |

---

### Numbers, UUID & Hashing

| Class / Interface | Purpose | Key Methods |
|---|---|---|
| `CL_ABAP_RANDOM_INT` | Random integer generation | `CREATE`, `GET_NEXT` |
| `CL_ABAP_RANDOM` | Random float/packed | `CREATE`, `GET_NEXT` |
| `CL_SYSTEM_UUID` | UUID generation | `CREATE_UUID_X16_STATIC` |
| `CL_ABAP_HMAC` | HMAC hashing | `GET_INSTANCE` |
| `CL_ABAP_MESSAGE_DIGEST` | SHA hashing | `CREATE` |

---

### JSON & Serialization

| Class / Interface | Purpose | Key Methods |
|---|---|---|
| `CL_ABAP_CONV_IN_CE` | ABAP ↔ JSON (legacy) | `CREATE` |
| `/UI2/CL_JSON` | JSON serialization | `SERIALIZE`, `DESERIALIZE` |
| `CL_SXML_STRING_WRITER` | XML/JSON writer | `CREATE` |
| `CL_ABAP_CODEPAGE` | Code-page name handling | `CONVERT_FROM`, `CONVERT_TO` |

---

### HTTP & REST Client

| Class / Interface | Purpose | Key Methods |
|---|---|---|
| `CL_WEB_HTTP_CLIENT_MANAGER` | HTTP client factory (Cloud) | `CREATE_BY_COMMUNICATION_ARRANGEMENT`, `CREATE_BY_DESTINATION` |
| `IF_WEB_HTTP_CLIENT` | HTTP request/response | `EXECUTE`, `GET_HTTP_RESPONSE`, `CLOSE` |
| `IF_WEB_HTTP_REQUEST` | Set request parameters | `SET_HEADER_FIELD`, `SET_TEXT` |
| `IF_WEB_HTTP_RESPONSE` | Read response | `GET_STATUS_CODE`, `GET_TEXT` |
| `CL_HTTP_UTILITY` | URL encode/decode | `ESCAPE_URL`, `UNESCAPE_URL` |

---

### Application Log (SLG1 replacement in Cloud)

| Class / Interface | Purpose | Key Methods |
|---|---|---|
| `CL_BALI_LOG` | Create/open log | `CREATE`, `CREATE_WITH_HEADER` |
| `CL_BALI_LOG_FILTER` | Filter log reads | `CREATE` |
| `CL_BALI_FREE_TEXT_ITEM` | Free-text log item | `CREATE` |
| `CL_BALI_EXCEPTION_ITEM` | Exception log item | `CREATE` |
| `CL_BALI_LOG_DB` | Persist/read log to DB | `SAVE_LOG`, `LOAD_LOG_WITH_ITEMS` |
| `IF_BALI_LOG` | Log instance interface | `ADD_ITEM`, `GET_ALL_ITEMS` |

---

### XCO (Extension Components — Cloud-only)

| Class | Purpose | Key Usage |
|---|---|---|
| `XCO_CP` | Cloud Programming utilities | `XCO_CP=>CURRENT->TIME_ZONE` |
| `XCO_CP_ABAP` | ABAP value helpers | Table type helpers |
| `XCO_CP_JSON` | JSON transformation | `XCO_CP_JSON=>TRANSFORMATION` |
| `XCO_CP_SYSTEM` | System info | `XCO_CP_SYSTEM=>TIMEZONE` |
| `XCO_CP_ABAP_DICTIONARY` | DDIC access | Read table/field metadata |

---

### Communication & Email

| Class / Interface | Purpose | Key Methods |
|---|---|---|
| `CL_BCS` | Business Communication Services (email) | `CREATE_PERSISTENT` |
| `CL_DOCUMENT_BCS` | Email document | `CREATE_DOCUMENT` |
| `CL_SAPUSER_BCS` | SAP user as recipient | `CREATE` |
| `CL_INTERNET_MAIL_ADDRESS` | Email address recipient | `CREATE` |
| `IF_FINS_COMM_DESTINATION` | Communication destination (Cloud) | `CREATE_BY_COMM_ARRANGEMENT` |

---

### ABAP Unit Testing Support

| Class / Interface | Purpose | Key Methods |
|---|---|---|
| `CL_ABAP_TESTDOUBLE` | Dynamic test double (mock) | `CREATE`, `CONFIGURE->EXPECT` |
| `CL_OSQL_TEST_ENVIRONMENT` | Open SQL double | `CREATE`, `INSERT`, `CLEAR_DOUBLES` |
| `CL_CDS_TEST_ENVIRONMENT` | CDS view double | `CREATE`, `INSERT`, `CLEAR_DOUBLES` |

---

### Error Handling & Exceptions

| Class | Purpose |
|---|---|
| `CX_STATIC_CHECK` | Base for checked exceptions (declare in signature) |
| `CX_DYNAMIC_CHECK` | Base for runtime-checked exceptions |
| `CX_NO_CHECK` | Base for unchecked exceptions (do not declare) |
| `CX_SY_OPEN_SQL_DB` | DB error base class |
| `CX_HTTP_NO_SUCCESS` | HTTP non-2xx response |

---

### Authorization

| Class / Interface | Purpose |
|---|---|
| `CL_ABAP_AUTHORITY_CHECK` | Programmatic authority-check (Cloud alternative to `AUTHORITY-CHECK`) |
| `IF_AUTH_AUTHORIZATION_DATA` | Authorization data interface |

---

### Number Ranges

| Class | Purpose | Key Methods |
|---|---|---|
| `CL_NUMBERRANGE_RUNTIME` | Read next number from range | `NUMBER_GET_NEXT` |
| `CL_NROBJ` | Number range object helper | — |

---

### SAP Help References

- Released ABAP APIs: https://help.sap.com/docs/abap-cloud/abap-released-apis/abap-released-apis
- ABAP Keyword Docs (Cloud): https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm
- XCO library: https://help.sap.com/docs/abap-cloud/abap-xco-library/xco-library
- Application Log (BALI): https://help.sap.com/docs/ABAP_Cloud/bbcee501b99848bdadecd4e290db3ae4/b1b65e7a6b904e8b98ca58e85eb0c4af.html
- HTTP Client Manager: https://help.sap.com/docs/abap-cloud/abap-rap/outbound-connectivity
