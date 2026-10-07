---
name: sap-cloud-dev
description: SAP Public Cloud ABAP development guidelines for Clean Core, RAP, CDS, and BTP ABAP Environment. RAP/CDS quick-start guide with service layer decision tables, CDS naming conventions, BDEF checklist, and clean core rules for SAP Public Cloud ABAP development.
metadata:
  version: 1.0.0
  tags: abap rap cds public-cloud btp clean-core fiori-elements odata bdef
---

# SAP Public Cloud Development Guidelines

## Core Principles

1. Use only released APIs, released CDS views, and released objects.
2. Never invent object names, annotations, API contracts, or syntax.
3. Prefer RAP-first, Cloud-ready, upgrade-safe implementation patterns.

## Priority SAP Help References

- https://help.sap.com/docs/abap-cloud
- https://help.sap.com/docs/btp/sap-business-technology-platform/abap-environment
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm
- https://help.sap.com/docs/SAP_S4HANA_CLOUD

Release-awareness:
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html

## RAP / CDS Development Decision Guide

### Service Layer Choice
| Scenario | Use |
|---|---|
| Fiori Elements UI (List Report, Object Page) | Managed RAP + OData V4 UI binding |
| External API consumers (mobile, integration) | Managed RAP + OData V4 Web API binding |
| Read-only reporting/analytics | CDS interface view + OData V4 |
| Complex transaction logic | Managed RAP with behavior pool |
| Legacy BAPI wrapping | Unmanaged RAP + Tier 2 wrapper |

### CDS View Naming Convention
| Layer | Prefix | Example |
|---|---|---|
| Interface View (I_) | `ZI_` | `ZI_SalesOrder` |
| Consumption/Projection View (C_) | `ZC_` | `ZC_SalesOrderTP` |
| Extension View | `ZX_` or `ZE_` | `ZX_I_SalesOrder` |

### BDEF Structure Checklist
- [ ] Behavior for interface view, projection for projection view
- [ ] `managed` mode unless strong reason for unmanaged
- [ ] `strict ( 2 )` mode — enforces clean coding rules
- [ ] `authorization master` defined for secured BOs
- [ ] Draft handling declared if Fiori app needs offline edit capability
- [ ] `with additional save` only if side-effects outside RAP are needed

### Key Clean Core Rules for Public Cloud
1. Language version: **ABAP for Cloud Development** (set in package properties)
2. No unreleased APIs: run `ABAP_CLOUD_DEVELOPMENT_DEFAULT` ATC check before transport
3. No modifications: use BAdIs, RAP extensions, or Tier 2 wrappers
4. No direct access to SAP tables: use released CDS views or OData APIs
5. Test everything: `CL_ABAP_TESTDOUBLE` + `CL_OSQL_TEST_ENVIRONMENT` for all behavior classes

## Development Rules

- Prefer interface-driven OOP design and constructor injection.
- Keep classes SRP-compliant and extension-friendly.
- Use RAP messages for transactional feedback.
- Validate release-sensitive recommendations with current SAP release notes.

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. Landscape and release assumptions
2. Proposed implementation approach
3. CDS/BDEF/service design details
4. Test and authorization strategy
5. Evidence links and known constraints

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| CDS or RAP modeling | entity design + behavior contract |
| service/API exposure | binding type + compatibility + versioning |
| reliability/security | auth model + resilience + logging |
| troubleshooting | root-cause steps + reproducible checks |


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
