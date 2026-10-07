# OData Complete Patterns

This reference is the deep-dive companion for OData architecture, design, and troubleshooting in ABAP Cloud and SAP S/4HANA landscapes.

## 1. URL and Key Patterns

### OData V2

```http
GET /sap/opu/odata/sap/Z_SALES_ORDER_SRV/SalesOrderSet('5000000010')
GET /sap/opu/odata/sap/Z_SALES_ORDER_SRV/SalesOrderSet?$top=20&$skip=0
```

### OData V4

```http
GET /sap/opu/odata4/sap/zui_sales_order_o4/srvd_a2x/sap/salesorder/0001/SalesOrder('5000000010')
GET /sap/opu/odata4/sap/zui_sales_order_o4/srvd_a2x/sap/salesorder/0001/SalesOrder?$top=20&$skip=0
```

Design rule:
- Use stable business keys in APIs where possible.
- Avoid exposing technical surrogate keys unless required for internal integration.

## 2. Query Design Patterns

### Filter + Select + OrderBy

```http
GET /SalesOrder?$filter=OverallStatus eq 'O'&$select=SalesOrder,Buyer,TotalAmount&$orderby=CreationDate desc
```

Guidance:
- Always combine paging with deterministic ordering.
- Avoid broad unfiltered entity reads in production integrations.

### Expand with nested options (V4)

```http
GET /SalesOrder?$expand=_Item($select=SalesOrderItem,Material,NetAmount;$orderby=SalesOrderItem asc)
```

Guidance:
- Keep expand depth shallow for transactional APIs.
- For heavy analytics, expose dedicated projection endpoints.

### Apply for aggregations (V4)

```http
GET /SalesOrder?$apply=groupby((Buyer),aggregate(TotalAmount with sum as TotalByBuyer))
```

Guidance:
- Validate expected data volume and index support before exposing `$apply` to external consumers.

## 3. Actions and Functions

### Bound Action (V4)

```http
POST /SalesOrder('5000000010')/SAP__self.SubmitForApproval
Content-Type: application/json

{
	"Comment": "Ready for approval"
}
```

### Unbound Function (V4)

```http
GET /GetOpenOrderCount(Plant='1010')
```

Design rule:
- Use actions for side effects.
- Use functions for read-only calculations.

## 4. Batch and Transaction Boundaries

### V4 batch with one atomic changeset

```http
POST /$batch
Content-Type: multipart/mixed; boundary=batch_001

--batch_001
Content-Type: multipart/mixed; boundary=changeset_001

--changeset_001
Content-Type: application/http
Content-Transfer-Encoding: binary

POST SalesOrder HTTP/1.1
Content-Type: application/json

{"Buyer":"1000001","Currency":"EUR"}

--changeset_001
Content-Type: application/http
Content-Transfer-Encoding: binary

POST SalesOrder('TMP')/_Item HTTP/1.1
Content-Type: application/json

{"Material":"TG11","OrderQuantity":"2"}

--changeset_001--
--batch_001--
```

Guidance:
- Keep independent business transactions in separate changesets.
- Avoid large mixed batch payloads that are difficult to retry idempotently.

## 5. Concurrency and ETag

### Read ETag then update

```http
GET /SalesOrder('5000000010')

ETag: W/"2026-08-05T11:22:33Z"
```

```http
PATCH /SalesOrder('5000000010')
If-Match: W/"2026-08-05T11:22:33Z"
Content-Type: application/json

{"BuyerReference":"PO-4451"}
```

Failure handling:
- HTTP 412 means stale representation.
- Re-read entity, merge changes, retry with fresh ETag.

## 6. RAP Binding Strategy

Choose service binding based on consumer type:
- OData V4 UI: Fiori Elements and interactive UX.
- OData V4 Web API: system-to-system integration.
- OData V2 compatibility: legacy consumers only, migration bridge.

Guidance:
- Keep one canonical RAP behavior model.
- Publish multiple projections only when contract separation is required.

## 7. ABAP Consumption Patterns

### Service Consumption Model (preferred)

Use generated proxy classes for typed calls, compile-time checks, and cleaner testability.

### HTTP client fallback for dynamic or cross-platform APIs

```abap
DATA(lo_dest) = cl_http_destination_provider=>create_by_url(
	i_url = 'https://api.example.com/odata/v4' ).

DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
	i_destination = lo_dest ).

DATA(lo_request) = lo_client->get_http_request( ).
lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
lo_request->set_uri_path( '/SalesOrder?$top=10&$orderby=CreationDate desc' ).

DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
DATA(lv_status) = lo_response->get_status( ).
```

Guidance:
- Keep credential management in Communication Arrangements/Destinations.
- Do not hardcode tokens or secrets.

## 8. Error Mapping Matrix

| HTTP | Typical cause | Backend action | Client action |
|---|---|---|---|
| 400 | invalid query/payload | validation message with field context | fix payload/query |
| 401 | missing/expired auth | check IAS/XSUAA or destination trust | renew token/session |
| 403 | authorization denied | verify RAP auth + IAM role assignment | request proper role |
| 404 | wrong endpoint/key | verify service binding and key structure | correct URL/key |
| 409 | semantic conflict | check draft lock or state transitions | refresh state and retry |
| 412 | stale ETag | provide latest version token | re-read and retry |
| 500 | unhandled backend error | inspect logs, dump, and error mapping | retry only if idempotent |

## 9. Troubleshooting Checklist

1. Confirm service binding type and activation state.
2. Compare payload fields with `$metadata` contract.
3. Verify association exposure for failing `$expand` paths.
4. Ensure paging requests include stable `$orderby`.
5. Validate ETag and If-Match behavior for updates.
6. Reproduce in isolation with minimal query options.
7. Check IAM role assignment and RAP authorization logic.
8. Review release notes for changed/deprecated OData behavior.

## 10. Versioning and Migration Guidance

- Prefer additive evolution within one major contract.
- For breaking changes, publish a new projection and binding version.
- Keep V2 compatibility endpoints during migration windows only.
- Communicate deprecation timeline and migration examples.

Use this file when requests involve protocol edge cases, performance-sensitive query patterns, migration decisions, or production incident diagnosis.

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
