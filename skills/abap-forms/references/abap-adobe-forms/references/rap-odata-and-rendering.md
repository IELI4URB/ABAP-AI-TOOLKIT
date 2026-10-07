# RAP, OData, and Adobe PDF Rendering

Last source review: 2026-09-24

This reference covers developer-owned form generation. It does not replace the SAP-delivered form data provider used by S/4HANA Output Management.

## Supported Architecture Patterns

### Pattern A: RAP Action Starts PDF Generation

```text
Fiori elements / API consumer
        |
        | bound action: RequestPDF
        v
RAP BO authorization + validation
        |
        | create request/status, commit business transaction
        v
supported background processing
        |
        | read dedicated form data model
        | resolve text/logo/template/language
        | call verified ADS rendering API
        v
PDF stored as attachment/media/document
        |
        v
RAP status + download/navigation reference
```

Use when users explicitly request a PDF for a RAP business object.

Design rules:

- The action authorizes the requested instance.
- Do not perform a long remote ADS call inside a RAP save handler or hidden commit path.
- Create an idempotent request key from document, version, form type, language, and template version.
- Use supported background processing for slow or bulk rendering.
- Store status transitions such as requested, processing, completed, failed, and expired.
- Store or reference the generated document using a verified attachment/media/document API.
- Recheck download authorization; action authorization alone may not be sufficient later.

SAP's `abap-platform-reuse-services` sample demonstrates a RAP action/save flow that schedules background processing and stores the generated PDF as an attachment. Treat its custom classes as sample code, not standard APIs.

The sample's exact transaction path is not a universal recipe: its save implementation detects a status-like field, schedules `CL_BGMC_PROCESS_FACTORY` with a transactionally uncontrolled operation, and the background operation later uses EML and `COMMIT ENTITIES`. Never copy this into an action/save handler. Verify bgPF availability and controlled/uncontrolled operation support in the exact product release, and commit only inside a separate background operation whose declared transaction contract permits it.

The sample reads active data and updates the active instance. A draft-triggered request can therefore render stale active data. Reject final output for drafts unless the form data service explicitly selects draft data; define preview and final-output behavior separately.

### Pattern B: Synchronous Preview

Use only when:

- One small document is rendered.
- ADS latency is bounded and acceptable.
- The target RAP/OData/API mechanism supports binary streaming or a documented PDF response.
- No transactional save is held open.
- Timeouts and cancellation are acceptable.

Prefer a dedicated preview endpoint/action or temporary document reference. Avoid embedding a large Base64 PDF in a generic JSON action result.

### Pattern C: Batch/Application Job

Use for mass generation, scheduled statements, invoices, labels, or archive output:

- Select documents with stable pagination/order.
- Partition work into restartable units.
- Limit concurrency against ADS quotas.
- Record per-document status and template version.
- Retry transient failures with limits and jitter.
- Do not regenerate completed legal outputs unless the business process permits reissue/versioning.

### Pattern D: SAP Output Management

Do not add a custom RAP action merely to reproduce an output already owned by SAP S/4HANA Output Management. Trigger or configure the application's supported output process instead.

## Developer Form Data Contract

A robust custom form model usually has:

```text
FormRoot
|- Document identity and version
|- Organization / company / sales area
|- Recipient and address
|- Language, locale, timezone
|- Dates and output metadata
|- Amounts + currency codes
|- Quantities + units
|- Status/display texts
|- Dynamic text blocks
|- Logo/image content + MIME type (when embedded)
|- Items[]
|  |- keys, descriptions, quantities, amounts, taxes
|- Totals[]
|- Partners[]
|- Notes[]
```

Rules:

- Use a dedicated read model; do not bind the template directly to persistence tables.
- Keep stable external element names once XDP bindings exist.
- Preserve exact DDIC/CDS lengths and decimal semantics through generated XML/XSD.
- Include currency/unit fields in the same logical node as their values.
- Resolve language-dependent descriptions before rendering or use the form data model's documented localization mechanism.
- Avoid cyclic associations and unbounded child collections.
- Define deterministic ordering for items and texts.
- Represent optional values explicitly and test absent nodes.

## Service Definition as Form Data Source

SAP's official ABAP sample uses a service definition and a leading/root entity to derive form data:

- `CL_FP_FDP_SERVICES=>GET_INSTANCE` obtains an `IF_FP_FDP_API` instance for a service definition/root node.
- The sample uses `GET_XSD` to derive the schema.
- `GET_KEYS` returns the service's key descriptors, which the application populates with document values.
- `READ_TO_XML` reads the selected hierarchy into XML.
- `CL_FP_ADS_UTIL=>RENDER_PDF` renders XML with an XDP layout.

Evidence status: `SAP-sample-confirmed` in the SAP-owned `abap-platform-reuse-services` repository.

Before using these objects:

1. Verify they exist in the target system/release.
2. Verify API State/contract for the package's ABAP language version.
3. Verify current signatures and exceptions in ADT.
4. Verify Forms service/ADS configuration.
5. Activate a minimal form and render test.

Do not copy the sample's custom template-store class name. `ZREUSECL_FP_TMPL_STORE_CLIENT` is application sample code that calls the template-store REST API; it is not a standard SAP API.

The SAP-owned sample uses a hybrid architecture: custom HTTP access to the `adsrestapi` template store retrieves the XDP, while standard ABAP ADS rendering generates the PDF. This optional dual-service sample is not the default ABAP-connection path and the repository contains no Forms Object artifact. In the documented ABAP connection use case, templates remain in the ABAP repository and rendering uses the `ads` connection.

## Template and Schema Flow

```text
CDS/service definition
        |
        | verified form data API
        v
XSD generated from data model
        |
        | imported as data connection
        v
XDP designed in Adobe LiveCycle Designer
        |
        | repository Forms Object or template store
        v
Runtime keys -> XML payload + XDP -> ADS -> PDF XSTRING
```

Compatibility controls:

- Treat XSD as a versioned contract.
- Regenerate and compare XSD after CDS/service changes.
- Review deleted/renamed/moved nodes as breaking template changes.
- Do not assume optional additions are harmless; scripts or subforms may depend on node order/presence.
- Render every supported template-language pair after schema changes.
- Record the schema/template versions used for production documents.

SAP Forms service template store allows one schema per form and multiple versions, but does not validate that the selected schema matches a template.

## RAP Action Contract

Recommended logical inputs:

- Business-object key(s).
- Form/output type.
- Language/locale where user-selectable.
- Preview versus final/reissue intent.
- Optional idempotency/request token.

Recommended logical result:

- Request/document ID.
- Status.
- Download/attachment reference when immediately available.
- Business error messages.

Do not return raw ADS traces or implementation exceptions to the user.

### Authorization

Check:

- Instance authorization for the source document.
- Permission for the requested form/output type.
- Sensitive field authorization before building XML.
- Permission to generate final/legal output versus preview.
- Permission to access the stored PDF.

Do not rely only on DCL if behavior/action authorization is required.

### Transaction Boundaries

- A rendering failure must not corrupt the business transaction.
- Do not execute explicit commits inside RAP behavior logic.
- Queue/background submission must use the supported RAP/save lifecycle.
- A background operation may commit only according to its verified controlled/uncontrolled transactional contract.
- Persist request status atomically with the trigger where possible.
- Generated document storage should be idempotent and restart-safe.

## OData Exposure Choices

| Requirement | Preferred interface |
|---|---|
| User requests generation | Bound RAP action |
| Poll generation state | Status fields/entity/function/read |
| Download existing PDF | Verified media/stream/attachment endpoint |
| External bulk generation | Web API action/job endpoint with request IDs |
| SAP business output | Native Output Management process |

Avoid legacy `GET_STREAM` guidance in a RAP OData V4 design unless the target framework explicitly supports the chosen media contract. OData V2 SEGW streaming patterns are not automatically valid in RAP V4.

## Forms Service REST API Path

For a non-ABAP or side-by-side application:

1. Subscribe to SAP Forms service by Adobe.
2. Create a `Forms service by Adobe API` instance (`adsrestapi`) for REST/template-store use.
3. Bind the instance to the application or use a securely managed service key for controlled testing.
4. Use Swagger from the service base URI for the exact deployed API version.
5. Send template/data or reference versioned template-store artifacts.
6. Validate status, content type, size, page count, and error body.

For ABAP system connections, SAP documents a separate `ads` service instance; do not create/use the REST API instance merely because the renderer is on BTP.

## Error Taxonomy

| Category | Examples | Handling |
|---|---|---|
| Business data | Document missing, invalid status, no recipient | No retry; report business message |
| Authorization | Source or PDF access denied | No retry; security event where appropriate |
| Contract | XSD/XDP mismatch, missing binding, bad data type | Block/redeploy compatible artifacts |
| Template | Invalid XDP/script/font/image | Correct and version template |
| Configuration | Missing destination, service instance, template, printer | Fix environment configuration |
| Connectivity | DNS/TLS/OAuth/timeout | Retry only if transient; monitor |
| Renderer | ADS internal/render failure | Capture correlation ID/trace safely; bounded retry |
| Persistence | Attachment/document storage failure | Retry idempotently; do not lose rendered result silently |

## Security

- Use communication arrangements/destinations/service bindings supported by the landscape.
- Store no OAuth client secret in ABAP source, XDP, CDS, or custom tables.
- Restrict template-store management APIs separately from rendering.
- Validate external URL fields before allowing XDP/image retrieval.
- Sanitize dynamic rich text if the chosen template field supports markup.
- Do not let users supply arbitrary XDP/templates to a privileged renderer without review and isolation.
- Avoid logging XML containing personal, payroll, bank, tax, or pricing data.
- Do not assume the background execution identity equals the requesting user. Persist the authorized request context needed for later checks without impersonating the user or bypassing authorization.
- Where applicable, use mTLS and harden Cloud Connector exposure/callback paths according to current SAP guidance.
- If using the template-store instance parameter `readOnly`, verify its one-way lifecycle behavior before enabling it; current SAP documentation states that changing it to true cannot be reverted for that instance.

## Performance

- Fetch hierarchical data in bounded set operations.
- Avoid repeatedly loading unchanged logo/template content for every item.
- Cache only where tenant, company, language, authorization, and validity boundaries are safe.
- Measure XML size, XDP size, rendered PDF size, pages, and latency.
- Use ADS trace level `0` or the documented production default; SAP's sample labels verbose trace as non-production.
- Backpressure mass jobs to protect renderer quotas and business-system resources.

## Test Matrix

- One/minimum/maximum item count.
- Missing optional partner/address/text/image.
- Long descriptions and page overflow.
- Multiple currencies/units and rounding.
- Different languages/locales/timezones.
- RTL and Unicode where required.
- Draft versus active instance keys.
- Unauthorized source and unauthorized PDF download.
- Duplicate request/idempotency behavior.
- ADS timeout and transient retry.
- Invalid/mismatched XDP and XSD.
- Missing font/logo/template configuration.
- Attachment persistence failure.
- Exact PDF MIME type, filename, page count, and rendering quality.

## Sources

- SAP ABAP Cloud Working with Forms:
  https://help.sap.com/docs/abap-cloud/abap-development-tools-user-guide/working-with-forms
- SAP Forms service use cases:
  https://help.sap.com/docs/forms-service-by-adobe/sap-forms-service-cf/use-cases-sap-forms-service-by-adobe
- SAP Forms service Getting Started and Swagger domains:
  https://help.sap.com/docs/forms-service-by-adobe/sap-forms-service-cf/getting-started
- SAP Forms service schema lifecycle:
  https://help.sap.com/docs/forms-service-by-adobe/sap-forms-service-cf/schema
- SAP-owned RAP/Adobe sample:
  https://github.com/SAP-samples/abap-platform-reuse-services

## Syntax Confidence

No production source code is provided here. Named ABAP objects are SAP-sample-confirmed, not universally release-confirmed. Verify object availability, API state, signatures, and exceptions before implementation.
