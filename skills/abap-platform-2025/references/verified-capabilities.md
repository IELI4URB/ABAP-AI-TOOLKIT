# ABAP Platform 2025 Verified Capability Ledger

Last source review: 2026-09-24

Read this file before answering any feature, availability, migration, implementation, or architecture question about ABAP Platform 2025.

## Evidence Labels

- **Overview-confirmed**: Stated in the SAP-authored Community release overview. This confirms that SAP announced the capability in the 2025 release context; it does not prove installation, activation, licensing, API release state, or exact FPS availability.
- **Cross-source-confirmed**: Supported by both the Community overview and another named SAP source.
- **Operationally verified**: Confirmed for the user's exact system through its component/FPS level, selected SAP Help version, relevant SAP Note or release note, API state, configuration, and activation/test evidence.
- **Unverified**: Plausible or inferred, but not established by the sources below. Do not present it as fact.

A capability must not be described as operationally available unless the system-specific checks have actually been performed.

## Source Ledger

### S1: SAP Community Release Overview

Olga Dolinskaja, "ABAP Platform in SAP S/4HANA Cloud Private Edition and SAP S/4HANA 2025," published December 14, 2025:

https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-sap/abap-platform-in-sap-s-4hana-cloud-private-edition-and-sap-s-4hana-2025/ba-p/14289979

This is an SAP-authored overview and the primary source for the capability inventory below. It is not a substitute for feature-specific release notes.

### S2: ABAP Platform 2025 Release Notes

https://help.sap.com/whats-new/5fc51e30e2744f168642e26e0c1d9be1?Product_Line=SAP+S/4HANA+and+SAP+S/4HANA+Cloud+Private+Edition;SAP+S/4HANA+Cloud+Private+Edition&Business_Area=ABAP+Platform

Use the feature-specific entry and verify its delivery date, product, and FPS.

### S3: ABAP Platform Documentation

https://help.sap.com/docs/ABAP_PLATFORM_NEW/b5670aaaa2364a29935f40b16499972d/48ba073157b85295e10000000a42189b.html

This URL can resolve to a currently selected documentation version. Explicitly select the target version. An unversioned/current page is not evidence that a capability belongs to the 2025 initial shipment.

### S4: ABAP Release 8.16 News

https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/ABENNEWS-816.html

Use this page, not the broader ABAP Release 8.1x index, for language changes attributed specifically to ABAP Release 8.16.

### S5: General Information Note

SAP Note 3612209, "ABAP Platform 2025 - General information":

https://me.sap.com/notes/3612209/E

### S6: ABAP Cloud API Enablement Guidelines

"ABAP Cloud API Enablement Guidelines for SAP S/4HANA Cloud Private Edition, and SAP S/4HANA," version 3.0, August 2025:

https://www.sap.com/docs/download/2023/05/b0bd8ae6-747e-0010-bca6-c68f7e60039b.pdf

Use this source for custom wrappers and the specific 2025 communication-target transition. It does not establish the release state of a particular business API.

## Product Baseline

The following statements are **overview-confirmed by S1**:

- SAP S/4HANA Cloud Private Edition 2025 and SAP S/4HANA 2025 were released to customers on October 8, 2025.
- ABAP Platform 2025 is the underlying technology platform and corresponds to `SAP_BASIS 816`.
- It supports SAP HANA only.
- It is not shipped as a standalone product.
- It consists of AS ABAP, ABAP Development Tools for Eclipse, and additional technology components required by the S/4HANA products.
- It is also part of SAP S/4HANA Foundation 2025 for SAP HANA-only add-ons.
- S1 states direct upgrade paths from SAP S/4HANA 1610, 1709, 1809, 1909, 2020, 2021, 2022, and 2023.

Do not infer application compatibility, add-on compatibility, downtime, custom-code readiness, or a supported project path from the direct technical upgrade statement alone.

## Capability Inventory

Unless explicitly stated otherwise, every item in this section is **overview-confirmed by S1 only**.

### Clean Core Development

- The updated model frames ABAP Cloud development as clean core level A and classic ABAP development as levels B, C, and D.
- The overall guidance remains to strive for the highest possible extensibility level.
- ABAP Cloud is SAP's recommended development model for new custom extensions in SAP S/4HANA private cloud and on-premise systems.
- Classic ABAP can still be used while pursuing clean core, with emphasis on upgrade stability and code quality.
- SAP provides a recommended list of "classic APIs" for classic ABAP development.
- ATC supports the clean core level concept with new checks.
- S1 recommends remote ATC in SAP BTP ABAP environment for governance of private-cloud and on-premise ABAP development.

Do not equate "classic ABAP" automatically with non-clean-core. Assess the extension's A-D level and evidence.

### SAP Joule for Developers and ABAP AI

S1 lists:

- Joule copilot in ADT.
- Predictive code completion.
- Code explanation and unit-test generation for ABAP and ABAP CDS.
- Application and service generation, including RAP BO generation.
- Predictive business logic for RAP BOs.
- OData consumption assistance.
- An ABAP AI SDK powered by Intelligent Scenario Lifecycle Management (ISLM).
- Migration assistance for custom-code questions, S/4HANA simplifications, legacy report purpose and logic, S/4HANA-related ATC findings, and resolution recommendations.

No item in this list proves entitlement, regional availability, backend readiness, required ADT version, AI setup, or permission to send source code/data to an AI service.

### RAP

S1 lists:

- Generators for OData UI services and RAP BOs with one or more entities, with or without AI assistance.
- Generation of custom UI services based on RAP BO interfaces.
- CDS table entities as the active persistence layer for managed RAP BOs **without draft**, replacing classic Dictionary database tables in that scenario.
- Collaborative draft, allowing multiple users to work simultaneously on the same draft instance without blocking one another.
- Cross-BO transactional scenarios in which participating RAP BO entities are linked by cross-BO associations.
- Read-only and editable tree views, including drag and drop, cut and paste, reordering, and **cascading delete**.
- Event-driven RAP side effects: when the relevant RAP business event is raised, the associated side effect is triggered and defined UI targets are reloaded.
- Propagation of privileged context in subsequent EML read and modify requests.
- Further behavior-definition and behavior-pool enhancements that S1 does not enumerate.

Do not invent BDEF additions, annotations, handler signatures, framework restrictions, or Fiori elements prerequisites from these summaries. Verify each in S2/S3 before giving syntax.

### ADT, Testing, and Troubleshooting

S1 lists:

- Improved class/interface rename handling, new-name validation, and exception long texts.
- A where-used dialog with prefiltering.
- The `abaplv` object-search property for ABAP language version.
- Editors for software-component relations, Adobe Forms, intelligent scenarios, and intelligent-scenario models.
- Creation/editing of CDS table entities and creation of their behavior definitions.
- Unit-test context highlighting, quick actions, inline failure/status display, rerun with coverage, and coverage-result clearing.
- A new AMDP Test Double Framework.
- CDS Test Double Framework support for CDS hierarchy views.
- Debugger views for ABAP memory consumption and memory snapshots.
- Internal-table comparison, hidden/sensitive values, JSON values, and nested-structure component groups in debugging.
- Cross Trace JSON export/import and short-dump ZIP export.
- Transport-management improvements for object assignment, search, and grouping.

ADT features additionally depend on the frontend ADT version. Backend `SAP_BASIS 816` alone is insufficient evidence.

### ABAP Language

S1 states:

- ABAP for Cloud Development is the cloud-optimized language version used for ABAP Cloud development.
- Internal-table enhancements include arbitrary logical expressions and equality conditions, plus harmonization of table expressions and `READ TABLE`.
- New ABAP system classes support random numbers and discrete/continuous probability distributions.
- Expression, function, and transformation enhancements include domain `XSDGEO` for serialization/deserialization between EWKB and GeoJSON.

Use S4 and the installed system's ABAP Keyword Documentation to verify exact syntax and release/API status.

### SAP HANA-Centric Development and Data Integration

S1 states:

- Data exposure includes AMDP for advanced read scenarios.
- CDS updatable view entities can wrap DDIC database tables or CDS table entities, expose a native CDS signature, be used with ABAP SQL, and use DCL-based access control.
- Consumption enhancements include new write scenarios, static CDS external entities, and ABAP CDS models based on imported CDS models.
- CDS table entities define and manage SAP HANA database tables as native CDS repository objects.
- A CDS generation wizard supports hierarchically structured data.
- AI-powered CDS Explain provides semantic context about CDS entities.

"Updatable" does not imply unrestricted writes. Verify supported source types, update rules, authorization, transactional ownership, and the exact write contract.

### Embedded Analytics

S1 lists:

- ABAP Cloud generator wizards for multidimensional analysis apps, Review Booklet apps, and native CDS hierarchy definitions.
- Reusable measures and filters for centrally defined analytical semantics and reuse in CDS view entities.

Verify analytical-engine, annotation, UI, and lifecycle prerequisites in the feature-specific documentation.

### Event Enablement and Business Events

S1 lists:

- Integration with SAP Event Mesh Advanced Plan.
- Support for SAP Cloud Application Event Hub to consume events published by SAP Order Management Foundation on SAP BTP.
- Outbound event filtering based on configurable criteria.
- Dynamic topics in SAP Event Mesh Advanced Plan.
- Event logging, including local capture and logging of successfully processed events.
- Grouping events of the same type and object **within a session** as activities.

S1 does not establish delivery guarantees, ordering, retries, idempotency, retention, or event-contract compatibility. Those must be designed and verified separately.

### Process Integration and Connectivity

S1 lists:

- OData service consumption with Swagger UI preview.
- OData V4 bulk processing and asynchronous communication integrated with AIF.
- Communication Targets within Communication Arrangements for more granular control over connectivity endpoints.
- API-to-package assignment and API packages for organization across API types.
- OData-based access to Communication Management data.
- Outbound communication enablement via HTTP and RFC.
- AIR key support as a custom HTTP header in SOAP requests.
- Direct push-based data exchange between ABAP systems via RFC.
- Server-Sent Events (SSE) support in the ABAP HTTP client and server.

Do not add "for ABAP Cloud" to an individual item unless its feature-specific documentation establishes the released consumption model.

#### Communication Targets Versus Wrappers

This distinction is **cross-source-confirmed by S1 and S6**:

- Communication Targets concern endpoint/connectivity configuration within communication management.
- A business API wrapper concerns access to an SAP object that is not released for ABAP Cloud.
- S6 recommends use-case-specific provider wrappers where destination or logical-port access was unavailable through released APIs. Do not reconstruct full class names from the document's `_RFC` and `_SOAP` shorthand; verify exact object names in the target release documentation.
- S6 states that, starting with SAP S/4HANA 2025, HTTP and RFC communication becomes possible in ABAP Cloud using Communication Targets, and SOAP communication becomes possible without such a wrapper.

Required conclusion:

- On a verified 2025 target, assess whether Communication Targets remove a **connectivity-provider wrapper**.
- Do not claim that Communication Targets release or replace a missing **business API**.
- Verify the exact 2025 FPS, released classes/interfaces, communication arrangement setup, and API state before removing a wrapper.

### Key User Extensibility

S1 lists:

- One-click generation of a Fiori elements application for a custom business object.
- Maintenance of behavior extensions for SAP-provided RAP BOs through key user extensibility.
- Developer-extensibility feature control for custom fields created through the Custom Fields app.
- A new extension-field wizard for custom-field creation through developer extensibility.

Do not assume every SAP BO or business context exposes these extension points.

### Security

S1 lists:

- OAuth Authorization Code with PKCE (RFC 7636).
- JWT-based client authentication (RFC 7523).
- SAP-managed client certificates for secure SAP S/4HANA Private Cloud integration, explicitly labeled **2025 FPS01**.
- TLS 1.3 support described by S1 with the wording "HTTP, WebSocket RFC, and SMTP."
- OAuth Client Credentials Grant for outbound SMTP scenarios such as Exchange Online.
- OpenID Connect enhancements.
- Troubleshooting guidance in SAP Note 3111813.
- Transaction `SOAUTH_CLIENT` as a new OAuth Client Configuration UI with testing and token-metadata display.

The S1 TLS wording is grammatically ambiguous. Conservatively report that the overview announces TLS 1.3 and mentions HTTP, WebSocket, RFC, and SMTP-related scenarios; verify each protocol and prerequisite in S2/S3 before implementation.

Do not generalize the explicit FPS01 qualifier on SAP-managed client certificates to other security bullets, and do not assume those other bullets are initial-shipment features without a feature-specific release note.

## Prohibited Inferences

Do not make these claims without additional evidence:

| Unsupported inference | Required evidence |
|---|---|
| "The feature is available because the system is SAP_BASIS 816" | Exact FPS/support package, feature release note, prerequisites |
| "The API is released for ABAP Cloud" | API State in ADT/source, released-object catalog, or compiler/activation evidence |
| "Communication Targets replace Tier 2 wrappers" | Wrapper is only for connectivity; exact released 2025 path verified |
| "Communication Targets replace a missing business API" | Never infer this; find a released business API or retain governed API enablement |
| "The ADT feature is present" | Compatible installed ADT frontend and backend versions |
| "A Joule feature can be used" | Entitlement, region, setup, authorization, data-governance approval |
| "Direct upgrade means the project is ready" | PAM/add-on checks, simplification analysis, ATC/custom-code remediation, project validation |
| "A CDS updatable view permits arbitrary writes" | Feature-specific source/update restrictions and transactional contract |
| "A Community overview bullet proves initial shipment or FPS01" | Feature-specific release note with delivery date/FPS |
| "TLS 1.3 applies to every mentioned protocol in this system" | Protocol-specific release note and kernel/crypto/configuration evidence |

## System-Specific Verification Checklist

Before giving a final implementation recommendation:

1. Identify product: SAP S/4HANA Cloud Private Edition 2025 or SAP S/4HANA 2025.
2. Confirm `SAP_BASIS 816` and exact FPS/support package.
3. Select that exact version in SAP Help; do not rely on the current/default documentation version.
4. Locate the feature-specific S2 release-note entry and record delivery date/FPS.
5. Check relevant SAP Notes, including correction-note prerequisites.
6. Verify ADT/Fiori elements/UI5/HANA/kernel versions where applicable.
7. Verify license, entitlement, region, activation, communication setup, and authorization prerequisites.
8. Verify API release state for the exact consumption mode.
9. Activate/compile the proposed consumption and run focused tests.
10. Run the applicable ATC checks and record any exemption or clean-core-level decision.

If any step cannot be completed, label the answer `overview-confirmed` or `unverified`; do not label it available or production-ready.
