# Adobe Forms Landscape and Architecture Guide

Last source review: 2026-09-24

Use this reference to choose the correct form technology before designing CDS, RAP, OData, template, or rendering code.

## Terminology

| Term | Meaning |
|---|---|
| Adobe Document Services (ADS) | Rendering engine that combines a form template and data to produce PDF/print output and, where supported, interactive forms |
| SAP Forms service by Adobe | SAP BTP service exposing ADS for ABAP connections and a REST API use case |
| XDP | Adobe XML Data Package layout/design file maintained with Adobe LiveCycle Designer for SAP solutions |
| XSD | Schema describing the form data contract used for template binding |
| Form data provider | SAP S/4HANA Output Management data interface/provider, typically SAP-delivered and based on a gateway model/CDS data source |
| Forms Object | ADT repository object whose main layout artifact is XDP and which uses ADS; availability is release-specific |
| Master form | Reusable overall page/static appearance with fragments/placeholders such as logo, sender address, and footer |
| Application/content form | Business-document content combined with a master-form layout variant |
| Standalone form | Template containing both content and layout without a separate master form |
| SFP form | Classic SAP Interactive Forms by Adobe development object with form interface, context, and layout, developed in transaction SFP |

Do not use these terms as synonyms.

## Landscape Matrix

### SAP S/4HANA Cloud Public Edition

Primary SAP business-output path:

- SAP S/4HANA Output Management/Output Control determines channel, recipient, template, language, and related parameters.
- SAP supplies application, master, or standalone form templates and form data providers for supported business documents.
- Customers copy/adapt the template through the Maintain Form Templates app.
- XDP is edited with the SAP-supported Adobe LiveCycle Designer.
- Manage Logos and Manage Texts provide reusable master-form assets.
- Define Rules for Determination of Master Form Template selects master template/assets for the applicable organizational context.
- Templates are transported from test to production with the supported software-collection process documented for the release.
- Public Cloud customers do not use transaction SFP or direct backend workbench development for this key-user path.

Critical boundary:

SAP Learning states that SAP creates the standard Output Management form data provider and the customer consumes/adapts it. Do not advise a customer to create a custom SEGW form data provider for the Public Cloud key-user path.

Developer extensibility path:

- Current cross-product ABAP Cloud documentation includes Forms Objects in ADT for recent backends. This is not evidence of availability in every older Public Cloud, Private Cloud, or on-premise release.
- A custom RAP/CDS service definition can form a developer-owned data contract for a custom form scenario when target-release documentation and object availability confirm it.
- This path is separate from modifying an SAP-delivered Output Management provider.
- Confirm product release, scope item, Forms Object creation wizard/backend object type, activation, transport, service-definition restrictions, rendering entitlement, and released APIs in the actual tenant.

### SAP S/4HANA Cloud Private Edition

Private Edition can contain multiple valid output paths:

1. SAP S/4HANA Output Control with gateway-based form data providers and application/master/standalone templates, using the ADS runtime configured for that system. The runtime may be embedded/on-premise ADS or a supported SAP Forms service by Adobe ABAP connection.
2. Developer extensibility with ABAP Cloud, RAP/CDS, and release-supported Forms Objects/APIs.
3. Classic SFP/Adobe forms in Standard ABAP for applications still using classic form/output frameworks.

Required decision:

- Identify the business application's actual output framework before choosing a form technology.
- Do not migrate a single form in isolation from its output determination, recipient/channel handling, spool/email/archive behavior, and data provider.
- Prefer the application's strategic Output Control path for new or modernized business outputs.
- Keep classic access and unreleased APIs outside ABAP Cloud packages; use clean-core assessment and wrappers only when justified.

### SAP S/4HANA On-Premise

Possible paths include:

- SAP S/4HANA Output Control with gateway-based forms and SAP Forms service by Adobe.
- Classic SAP Interactive Forms by Adobe through SFP and ADS.
- Legacy output/message-control frameworks whose print program calls the form.
- Custom RAP/OData applications on sufficiently recent ABAP Platform releases.
- Connection from the on-premise ABAP system to SAP Forms service by Adobe on BTP, subject to minimum release/SP and secure connectivity prerequisites.

Official Forms service documentation lists supported S/4HANA on-premise baselines for the ABAP connection use case. Always use the current service documentation and SAP Notes; do not copy old minimum SP values into a design without revalidation.

### SAP BTP ABAP Environment

- SAP Forms service by Adobe supports the ABAP connection use case.
- Print Forms/Forms Objects and released ABAP APIs are release-dependent.
- Communication and service entitlement must be configured in BTP.
- There is no classic SFP/Standard ABAP fallback in ABAP Cloud.

### Non-ABAP Cloud Application

- Use SAP Forms service by Adobe REST API over HTTP.
- The cloud application sends template and data or references a template in the template store.
- Requests/responses use the documented REST/JSON contracts.
- The REST API provides a subset of traditional PDF object features; verify required output capabilities.
- The application owns OAuth/service binding, retries, schema/template versioning, and secure storage.

## Technology Decision Tree

1. Is this an SAP-delivered business output?
   - Yes: identify the application's output framework and use its supported customization path.
   - No: continue.
2. Is the target Public Cloud and key-user customization sufficient?
   - Yes: copy SAP template, use Maintain Form Templates, managed logos/texts, and output determination.
   - No: continue.
3. Is a Forms Object and released rendering API available in the target ABAP Cloud release?
   - Yes: use a developer-owned form data contract and Forms Object/rendering path.
   - No: continue.
4. Is Standard ABAP/SFP allowed and appropriate in Private Cloud/on-premise?
   - Yes: use SFP/ADS within the application's existing output framework.
   - No: use a side-by-side application with Forms service REST API or reassess requirements.

## Form Type Selection

| Need | Form type |
|---|---|
| Common branding reused across S/4HANA Output Control business documents | Master form plus application forms (called content forms in some SAP learning material) |
| Independent custom PDF with no shared master page | Standalone form |
| SAP application output already based on master/content forms | Copy and adapt the application/master templates within Output Management |
| Custom developer form using one template and custom data | Forms Object or standalone template path, when supported |
| Classic on-premise interactive/print form | SFP form, subject to ADS and application framework |

## Output Management Runtime Flow

For SAP S/4HANA Output Control:

1. Business document/output request is created.
2. Output parameter determination selects output type, recipient/role, channel, template, and language according to the application's rules.
3. Form data provider retrieves the hierarchical business data.
4. Application/content form is combined with the determined master form/fragment where applicable.
5. ADS renders the output.
6. Output Management sends it to preview, print, email, or another configured channel and records status.

The exact rule fields differ by application and release. Do not promise a condition field without checking the target Output Parameter Determination content.

Master/application composition is an SAP S/4HANA Output Control model. Do not assume Forms Objects or generic REST template-store forms automatically support the same master-form determination or fragment lifecycle.

## Classic SFP Runtime Flow

Typical on-premise/Private Cloud classic flow:

1. Driver/output program gathers authorized business data.
2. Generated form interface/context receives the data.
3. ADS job is opened with output parameters.
4. Generated form function/rendering call combines interface data and XDP layout.
5. ADS returns PDF/spool output.
6. Job is closed and the application handles spool, email, archive, or download.

Exact generated function modules and classic ADS APIs are Standard ABAP/release-specific. Verify them in the target system; do not use this pattern as ABAP Cloud code.

## Forms Service Runtime Choices

### ABAP Connection

- Form templates remain in the ABAP repository for the ABAP application use case.
- The ABAP system connects securely to SAP Forms service by Adobe.
- The Forms service instance uses service name `ads` according to current SAP Help.
- REST API service instance creation is not required solely for the ABAP connection use case.

### REST API and Template Store

- REST API service name is documented as `adsrestapi`.
- Application may send the XDP and data or use the service template store.
- Template store can organize forms, schemas, templates, and versions.
- Repository creation for the template store is a separate setup step.
- Schema/template compatibility is customer/application responsibility.

Never place service keys or client secrets in source code, form templates, or logs.

## Transport and Lifecycle

### Public Cloud

- Develop/adapt templates in the designated development/test system.
- Use the documented software collection/export-import mechanism.
- Build a transport matrix for form template/XDP metadata, Forms Object, CDS/service definition, logos, texts, master-form determination, destinations, service instances, certificates, and any template-store content. Confirm which artifacts use software collections and which require target-system configuration.
- Preserve original language and translations.
- Use template version history and compare functions where available.

### Private Cloud/On-Premise

- SFP forms/interfaces and ABAP repository objects use transport requests.
- Output Control templates/configuration can have separate transport/configuration mechanisms.
- BTP Forms service subscription, instances, destinations, certificates, and roles are environment configuration and are not ABAP transports.
- Coordinate ABAP, XDP/XSD, configuration, and BTP changes in release order.
- Do not assume Forms Objects use the same transport path in every release; verify repository object and layout transport behavior in the target system.

### REST Applications

- Version template/schema artifacts alongside application releases or use controlled template-store versions.
- Record immutable identifiers/versions used for legally relevant documents.
- Test rollback to the previous compatible template and schema.

## Landscape Validation Checklist

- Product edition and exact release/FPS confirmed.
- Business application output framework confirmed.
- Form object type and design tool available.
- Rendering service licensed and reachable in the region.
- Required SAP-delivered form data provider/template exists for key-user customization.
- API/object release state confirmed for developer extensibility.
- Output channels, printer/spool, email, archive, and retention configured.
- Template, configuration, and BTP lifecycle documented.
- Target environment rendering test completed.

## Official Sources

- ABAP Cloud Working with Forms:
  https://help.sap.com/docs/abap-cloud/abap-development-tools-user-guide/working-with-forms
- SAP Forms service Getting Started:
  https://help.sap.com/docs/forms-service-by-adobe/sap-forms-service-cf/getting-started
- SAP Forms service use cases:
  https://help.sap.com/docs/forms-service-by-adobe/sap-forms-service-cf/use-cases-sap-forms-service-by-adobe
- SAP S/4HANA Cloud Form Templates:
  https://help.sap.com/docs/SAP_S4HANA_CLOUD/a630d57fc5004c6383e7a81efee7a8bb/aaad0f198a634014b0776e001e4980bc.html
- Maintain Form Templates:
  https://help.sap.com/docs/SAP_S4HANA_CLOUD/a630d57fc5004c6383e7a81efee7a8bb/da488f76078447b0b42792226cfcf9b1.html
- Customized master forms:
  https://help.sap.com/docs/SAP_S4HANA_CLOUD/a630d57fc5004c6383e7a81efee7a8bb/f776f77564e04331b5e891d9569b6d12.html
- Form strategy and architecture:
  https://learning.sap.com/courses/getting-started-with-sap-forms-service-by-adobe/explaining-sap-s-form-strategy_fe64fe10-e7ee-48a0-a0c2-3d6904904c58
  https://learning.sap.com/courses/getting-started-with-sap-forms-service-by-adobe/outlining-form-architecture-in-sap-s-4hana_bc1bfd03-8d07-463c-aa54-876d0690fb4b
