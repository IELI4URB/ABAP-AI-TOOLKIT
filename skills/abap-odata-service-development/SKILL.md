---
name: abap-odata-service-development
description: >-
  OData V2 and V4 service development for SAP ABAP Cloud and on-premise. Covers OData protocol differences (V2 vs V4), RAP-based V4 services (service definition, service binding types), legacy SEGW V2 services, OData query options ($filter, $expand, $select, $orderby, $count, $batch), deep operations, actions vs functions (bound/unbound), OData consumption from ABAP (proxy generation, CL_WEB_HTTP_CLIENT), ETags and concurrency, error response formats, pagination ($skip/$top vs server-driven), and OData debugging/testing patterns. Triggers: OData, V2, V4, service binding, SEGW, $filter, $expand, batch, deep insert, action, function, ETags, OData consumption, gateway, /IWBEP/, OData error, $metadata, navigation property, entity set.
metadata:
  version: 2.0.0
  tags: abap odata v2 v4 service-binding segw gateway rest abap-cloud
---

# OData V2 and V4 Service Development for ABAP

Expert guide for building and consuming OData services in SAP ABAP, covering protocol differences, RAP-native V4, legacy SEGW V2, query operations, actions and functions, and consumption patterns.

**Golden rule: New development equals OData V4 via RAP. V2 only for backward compatibility with existing consumers. Never build new SEGW services in ABAP Cloud.**

Reference files:
- `references/odata-complete-patterns.md` - full protocol comparison, query options, batch, consumption, and debugging patterns

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

## V2 vs V4 Decision Matrix

| Criterion | OData V2 | OData V4 |
|---|---|---|
| New ABAP Cloud development | NO (legacy only) | YES (default) |
| RAP native support | Via compatibility binding | Native |
| Draft handling | Manual (complex) | Built-in (RAP managed) |
| Actions | Function Imports only | Bound and unbound actions/functions |
| Batch | `$batch` with changesets | `$batch` with JSON payload |
| Deep operations | Limited | Full deep create/update |
| Metadata format | EDMX/XML (CSDL 2.0) | JSON (CSDL 4.0) |
| Fiori Elements support | V2 templates (legacy) | V4 templates (current) |
| Protocol | AtomPub/XML or JSON | JSON only |
| Aggregate/analytics | `$apply` not available | `$apply` with transformations |
| ETag | `If-Match` header | `If-Match` header + `@odata.etag` |
| Key format in URL | `EntitySet(Key='value')` | `EntitySet('value')` or `EntitySet(key=value)` |

---

## Query Options Quick Guide

### `$filter`

### Comparison Operators
| Operator | V2 | V4 | Example |
|---|---|---|---|
| Equal | `eq` | `eq` | `$filter=Status eq 'A'` |
| Not equal | `ne` | `ne` | `$filter=Status ne 'X'` |
| Greater than | `gt` | `gt` | `$filter=Amount gt 5000` |
| Greater or equal | `ge` | `ge` | `$filter=Amount ge 5000` |
| Less than | `lt` | `lt` | `$filter=Amount lt 1000` |
| Less or equal | `le` | `le` | `$filter=Amount le 1000` |

### Logical Operators
| Operator | Example |
|---|---|
| `and` | `$filter=Status eq 'A' and Amount gt 5000` |
| `or` | `$filter=Status eq 'A' or Status eq 'O'` |
| `not` | `$filter=not contains(Description,'test')` |

### String Functions (V4)
| Function | Example |
|---|---|
| `contains()` | `$filter=contains(Description,'Paris')` |
| `startswith()` | `$filter=startswith(Name,'SAP')` |
| `endswith()` | `$filter=endswith(Email,'.com')` |
| `length()` | `$filter=length(Name) gt 10` |
| `tolower()` | `$filter=tolower(Name) eq 'sap'` |
| `toupper()` | `$filter=toupper(Status) eq 'A'` |
| `trim()` | `$filter=trim(Name) eq 'SAP'` |
| `concat()` | `$filter=concat(FirstName,' ',LastName) eq 'John Doe'` |

### Collection Operators (V4 only)
| Operator | Example |
|---|---|
| `in` | `$filter=Status in ('A','O','D')` |
| `any` (lambda) | `$filter=_Booking/any(b:b/FlightDate gt 2026-09-01)` |
| `all` (lambda) | `$filter=_Booking/all(b:b/Status eq 'A')` |

### Date/Time Functions (V4)
| Function | Example |
|---|---|
| `year()` | `$filter=year(BeginDate) eq 2026` |
| `month()` | `$filter=month(BeginDate) eq 9` |
| `day()` | `$filter=day(BeginDate) eq 1` |

---

## `$expand` Navigation and Nested Queries

### V4 patterns

```http
GET /Travel?$expand=_Booking
GET /Travel?$expand=_Booking($select=BookingID,FlightDate,Amount)
GET /Travel?$expand=_Booking($filter=FlightDate gt 2026-09-01)
GET /Travel?$expand=_Booking($orderby=FlightDate desc)
GET /Travel?$expand=_Booking($top=5)
GET /Travel?$expand=_Booking($expand=_Supplement)
GET /Travel?$expand=_Booking,_Agency
```

### V2 limitations

```http
GET /TravelSet?$expand=to_Booking
GET /TravelSet?$expand=to_Booking,to_Agency
```

No nested query options in V2 `$expand`.

---

## `$apply` Analytics (V4 only)

```http
GET /Travel?$apply=groupby((AgencyID),aggregate(TotalPrice with sum as TotalRevenue))
GET /Travel?$apply=groupby((Status),aggregate($count as Count))
GET /Travel?$apply=filter(Status eq 'A')/groupby((AgencyID),aggregate(TotalPrice with sum as Revenue))
GET /Travel?$apply=groupby((AgencyID),aggregate(TotalPrice with sum as Revenue))&$orderby=Revenue desc&$top=5
```

---

## Pagination Patterns

### Client-driven paging

```http
GET /Travel?$top=25&$skip=0&$count=true&$orderby=TravelID
GET /Travel?$top=25&$skip=25&$count=true&$orderby=TravelID
```

### Server-driven paging

```json
{
  "value": ["..."],
  "@odata.nextLink": "/Travel?$skiptoken=25"
}
```

RAP framework supports paging automatically based on service configuration.

---

## Service Consumption Model in ADT

1. New -> Other -> Service Consumption Model
2. Select OData V2 or V4
3. Provide `$metadata` URL or upload EDMX
4. Generate proxy classes
5. Configure Communication Scenario and Arrangement

---

## Common OData Errors

| HTTP Status | Meaning | Common Cause | Fix |
|---|---|---|---|
| 400 | Invalid payload/query | Malformed `$filter`, wrong field | Validate with `$metadata` |
| 401 | Authentication failed | Missing/expired token | Refresh OAuth/check auth |
| 403 | Authorization denied | Missing privileges | Verify IAM and RAP authorization |
| 404 | Entity/service missing | Wrong URL or key | Check binding activation and keys |
| 405 | Method not allowed | Operation not exposed | Verify BDEF operations |
| 409 | Conflict | Draft lock/concurrency | Resolve lock and retry |
| 412 | Precondition failed | ETag mismatch | Re-read entity and send new ETag |
| 428 | Precondition required | Missing `If-Match` | Include `If-Match` header |
| 500 | Server exception | Unhandled backend error | Check logs/dumps and handler code |
| 501 | Not implemented | Option not supported | Remove unsupported query option |

---

## RAP V2 Compatibility Binding Notes

When exposing RAP BOs as V2 for legacy consumers:

1. Create `OData V2 - UI` or `OData V2 - Web API` binding
2. RAP translates V4 behavior to V2 protocol
3. Navigation properties often use `to_` prefix (`_Booking` -> `to_Booking`)
4. Actions map to Function Imports
5. Draft uses V2-specific draft model

Limitations:
- No `$apply`
- No nested options in `$expand`
- No bound actions
- No lambda operators in `$filter`

---

## Response Rules

### "OData V2 or V4?"
Use the decision matrix. New development should be V4 via RAP.

### "How do I call an action?"
For V4, use bound action POST on entity/action URL; for V2 use Function Import pattern.

### "`$expand` not working?"
Check association exposure in service definition and correct navigation naming for V2 vs V4.

### "Batch request?"
Use `$batch` with changeset for writes and isolate transactional boundaries.

### "ETag error 412?"
Client must send current ETag in `If-Match`; fetch entity first and retry with fresh ETag.

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
