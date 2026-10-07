---
name: abap-adobe-forms
description: >-
  Adobe Forms architecture and delivery for SAP S/4HANA Cloud Public Edition, SAP S/4HANA Cloud Private Edition, SAP S/4HANA on-premise, and ABAP Cloud. Covers SAP Forms service by Adobe, Adobe Document Services, Forms Objects in ADT, RAP actions, OData/form data providers, XDP/XSD lifecycle, Output Management, SFP, dynamic stored texts, logos, master/content/standalone forms, template determination, PDF attachments, security, performance, transport, and troubleshooting. Use for Adobe form, print form, PDF generation, RAP PDF, OData form service, form template, form data provider, ADS, SFP, LiveCycle Designer, dynamic text, logo, footer, or output control.
argument-hint: Describe the landscape, release, output framework, data source, trigger, template ownership, and dynamic text/logo requirements.
metadata:
  version: 1.0.0
  tags: abap adobe-forms ads rap odata pdf output-management form-template dynamic-text logo
---

# Adobe Forms for SAP ABAP Landscapes

Use this skill to select, design, implement, or review Adobe form solutions. The same phrase "Adobe form" can refer to different technologies and ownership models. Determine the landscape and output path before recommending objects or APIs.

**Golden rule: first choose the form ownership and runtime path; only then choose RAP/OData, Output Management, Forms Object, SFP, ADS connection, or REST API. Never combine instructions from different paths without explicit evidence that the target release supports the combination.**

## Mandatory References

Read the relevant references before answering:

- `references/landscape-and-architecture.md` - Public Cloud, Private Cloud, on-premise, BTP/ABAP Cloud decision matrix; Output Management, Forms Object, SFP, ADS, and transport boundaries.
- `references/rap-odata-and-rendering.md` - RAP actions, service definitions as developer form data sources, XML/XSD/XDP/PDF flow, asynchronous processing, attachments/media, released APIs, security, and tests.
- `references/dynamic-content-and-assets.md` - stored/dynamic texts, multilingual content, logos, master forms, fragments, image binding, determination, caching, authorization, and lifecycle.

Do not answer from the frontmatter description alone.

## Required Context

Establish these facts before producing a design:

1. Landscape: Public Cloud, Private Cloud, on-premise, or BTP ABAP Environment.
2. Exact product release, FPS/support package, ABAP language version, ADT version, and UI5 version where relevant.
3. Business output framework: SAP S/4HANA Output Control/Output Management, classic message control, standalone custom RAP app, or external cloud application.
4. Trigger: business output event, RAP action, application job, API request, preview, print, email, or download.
5. Template owner: SAP-delivered template copy, key-user template, ADT Forms Object, classic SFP form, or Forms service template store.
6. Data owner: SAP-delivered form data provider, custom service definition/CDS model, classic form interface, or REST JSON/XML payload.
7. Rendering runtime: embedded/on-premise ADS, SAP Forms service by Adobe for ABAP connections, or Forms service REST API.
8. Dynamic content: business fields, stored standard text, language-dependent text, logo, signature, barcode, attachment, or master-form fragment.
9. Output requirements: PDF/PDF-A, interactive form, print queue, email, attachment persistence, digital signature, accessibility, and retention.
10. Non-functional constraints: data volume, maximum document size, latency, retries, confidentiality, audit, and regional processing.

If these are not known, present a conditional architecture matrix rather than a single implementation.

## Evidence Vocabulary

Use these labels for material claims:

- `officially documented`: stated in SAP Help or SAP Learning for the named landscape/release.
- `SAP-sample-confirmed`: demonstrated in an SAP-owned sample repository; still verify API release state and target-release availability.
- `system-verified`: confirmed in the user's system through object/API state, activation, configuration, and a rendering test.
- `unverified`: not established for the target system; do not present as production-ready.

A class appearing in an SAP sample is not automatically released in every ABAP Cloud or S/4HANA release.

## Architecture Router

| Scenario | Preferred starting path |
|---|---|
| Adapt SAP business document in Public Cloud | Output Management + SAP-delivered form data provider + copied XDP template + Maintain Form Templates |
| Company-specific logo/footer in Public Cloud | Master form + Manage Logos/Manage Texts + master-form determination rules |
| Custom RAP application generates a PDF | RAP action/application service + dedicated form data service/model + verified Forms Object or ADS rendering API |
| Long-running or high-volume PDF generation | Persist request state, process asynchronously through a supported background mechanism, store result, expose status/attachment |
| Private Cloud SAP business output | Determine whether the application uses S/4HANA Output Control or classic output; customize within that framework |
| Private Cloud/on-premise classic custom form | SFP form/interface/context + ADS, when Standard ABAP and the application's output framework permit it |
| Cloud or non-ABAP application renders forms | SAP Forms service by Adobe REST API + template/schema store or application-owned template |
| On-premise ABAP uses BTP rendering | Supported SAP Forms service ABAP connection, exact release/SP prerequisites, secure service connection |

Do not assume classic SFP, SAP S/4HANA Output Control, and ADT Forms Objects are interchangeable. They have different design-time artifacts, data contracts, and runtime configuration.

## Data and Template Contracts

Every design must identify four contracts:

1. **Selection contract** - keys and authorization needed to identify the business document.
2. **Data contract** - hierarchical fields/nodes delivered to the form, including optionality, lengths, currency/unit semantics, binary/text encoding, and language.
3. **Template contract** - XDP bindings and scripts matched to the exact XSD/data structure.
4. **Output contract** - PDF MIME type, filename, persistence/retention, status, recipient/channel, and error behavior.

A template and schema can both exist while being incompatible. SAP Forms service documentation states that the template store does not prove schema-template matching; validate the pair through rendering tests.

## RAP and OData Boundaries

- RAP/OData owns the application transaction and service contract; ADS owns form rendering.
- A RAP action can trigger PDF generation, but a slow remote rendering call should not be hidden in the RAP save sequence.
- Never call `COMMIT WORK` or `COMMIT ENTITIES` in a RAP action or behavior save implementation. A separate background operation may commit only when its declared transactional contract and target release permit it.
- State draft semantics explicitly. Final/legal output should normally reject draft instances unless the data contract deliberately reads draft data and carries the active/draft discriminator; preview may use separate rules.
- Prefer a dedicated read-oriented form data model/service over reusing a broad transactional UI service.
- Expose only fields needed by the form; protect PII and confidential pricing through authorization and data minimization.
- Do not return large PDF binaries in ordinary action results by default. Persist or stream them through a verified attachment/media pattern and return status/reference metadata.
- Treat generated PDF content as immutable evidence when business/audit requirements demand reproducibility; record template version, language, rendering timestamp, and source-document version.

Read `references/rap-odata-and-rendering.md` before naming APIs or writing code.

## Dynamic Content Boundaries

- Master-form logos, sender addresses, and footer blocks are configuration-driven assets in SAP S/4HANA Output Management.
- Business-dynamic paragraphs belong in the form data contract, resolved by business key, validity date, and language before rendering.
- A value selected from a text repository is not the same as a translated static XDP label.
- Do not use unreleased classic text function modules directly from ABAP Cloud. Find a released API or use a governed wrapper only where the landscape permits it.
- Prefer embedded image content for controlled document reproducibility; external URLs add network, authentication, availability, and content-change risks.
- Validate image MIME type, dimensions, file size, transparency/color requirements, and accessibility text.

Read `references/dynamic-content-and-assets.md` before recommending storage or binding.

## Security and Compliance Gates

- Never hardcode ADS endpoints, service credentials, OAuth secrets, or template-store credentials.
- Use the landscape's supported communication arrangement, destination, service binding, or secure ABAP connection.
- Restrict template-store roles and separate template administration from business-document execution.
- Authorize the source document before reading data and again before allowing download where access can change.
- Treat XDP scripts and externally maintained templates as executable presentation logic; review and version them.
- Prevent SSRF and untrusted-resource loading when forms can reference URLs.
- Avoid writing raw business XML, credentials, or complete rendered PDFs to application logs.
- Define retention, deletion, masking, and audit rules for generated forms containing personal or financial data.

## Performance and Reliability Gates

- Avoid N+1 reads in the form data provider; retrieve header, items, texts, partners, and assets in bounded sets.
- Set explicit maximum item counts, image sizes, and document-size expectations.
- Keep ADS production trace level disabled/minimal; SAP sample code explicitly warns against verbose tracing in production.
- Use idempotency keys for asynchronous requests to avoid duplicate PDFs or outputs.
- Classify errors as business data, template/schema mismatch, authorization, configuration, connectivity, timeout, or renderer failure.
- Retry only transient failures and never duplicate an already-issued legal/business output without a business rule.
- Monitor queue/background status, rendering duration, failures, and document size.

## Validation Contract

A form implementation is not complete until all applicable checks pass:

1. Template activates/uploads and is paired with the intended XSD/data source.
2. Preview/render succeeds with minimum, typical, maximum, and empty optional data.
3. Header/item hierarchy, page breaks, repeating headers, totals, currencies, units, and locales are correct.
4. Text and logo determination is tested for each company/country/language rule.
5. Authorization and negative-access tests pass.
6. Output is tested in every required channel: preview, download, print queue, email, and archive.
7. Unicode, RTL language, long text, special characters, and font embedding are tested when relevant.
8. Failures produce actionable logs without leaking sensitive content.
9. Template and configuration transport/deployment is verified in the target environment.
10. ATC, released API checks, integration tests, and rollback/version restoration are documented.

## Response Contract

For non-trivial requests, respond with:

1. Landscape and release assumptions.
2. Selected form path and rejected alternatives.
3. Data, template, rendering, and output contracts.
4. RAP/OData or Output Management design.
5. Dynamic text/logo design.
6. Security, performance, error handling, and observability.
7. Transport/deployment sequence.
8. Test and acceptance plan.
9. Evidence status and SAP sources.

Hard rules:

- Never invent an ADS class, form object, service name, transaction, app, annotation, or API release state.
- Never recommend SFP in Public Cloud.
- Never claim customers can create or modify an SAP-delivered Output Management form data provider in Public Cloud unless exact target-release documentation proves it.
- Never treat a custom RAP OData service as an SAP-delivered Output Management form data provider.
- Never treat a template-store REST client from a sample as an SAP standard API.
- Never promise interactive PDF, PDF/A, signatures, fragments, or output channels without target-service capability evidence.
- Never infer that a background process runs with the requesting user's identity or authorizations; design and test the execution identity explicitly.
- Never provide production ABAP/RAP code when named API release state or exact signatures remain unverified.
