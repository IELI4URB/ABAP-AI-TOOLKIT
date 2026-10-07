---
name: sap-sd
description: Full-scale SAP Sales and Distribution guidance for ABAP developers and architects on S/4HANA. Use when working on quotations, sales orders, deliveries, billing, pricing, ATP, partner determination, output, or SD-related ABAP design.
metadata:
  version: 2.0.0
  tags: sap abap sales-distribution sd order-to-cash pricing delivery billing clean-core rap cds
---

# SAP Sales and Distribution Expert Skill

Use this skill for SAP Sales and Distribution process design, troubleshooting, and ABAP implementation guidance across S/4HANA contexts.

## Scope

- Master data: customers, business partners, sales areas, material sales data, partner functions, condition records
- Order management: inquiry, quotation, sales order, schedule lines, ATP, credit touchpoints, document flow
- Fulfillment: outbound delivery, picking, packing, shipment dependencies, proof of delivery touchpoints, logistics execution integration
- Billing: invoices, credit/debit memos, billing plans, pricing and output integration, finance touchpoints
- Integrations and controls: partner determination, status integrity, output, pricing consistency, and order-to-cash control flow
- ABAP: released CDS views, cloud-ready APIs, events, and extension patterns for SD scenarios

## SAP Help Baseline

Use SAP Help as the primary business and technical grounding.

Business-process grounding:
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/9d794cbd48c648bc8a176e422772de7e?locale=en-US&state=PRODUCTION&version=2608.500
- https://help.sap.com/doc/7c9e0bbbd1664c2581b2038a1c7ae4b3/2608.500/en-US/FSD_CE2608.pdf

ABAP and syntax grounding:
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm

Release-awareness and extensibility grounding:
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d?locale=en-US&state=PRODUCTION&version=1
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html?locale=en-US&state=PRODUCTION&version=2608.00

## Reference Files

| File | Content |
|---|---|
| `references/governance/governance-gates-reference.md` | Full domain governance gates with validation checklists |
| `references/governance/landscape-and-release-gate.md` | Landscape classification rules and release eligibility |
| `references/governance/cross-skill-requirement-evaluation-template.md` | Multi-skill bundle selection template |
| `references/governance/implementation-eligibility-matrix.md` | ECC vs. on-premise vs. Public Cloud eligibility |
| `references/governance/development-and-definition-of-done-checklist.md` | Development-phase gates and definition-of-done |

## Domain Governance Gates (Mandatory)

Before recommending implementation, validate all of the following:
- Process correctness: the recommendation respects the real SD document and status lifecycle.
- Master data dependencies: customer, BP, sales area, material sales data, partner, and condition dependencies are explicit.
- Cross-module integrity: logistics, billing, and finance impacts are identified.
- Control integrity: pricing, ATP, output, credit, and billing controls are preserved.
- Volume profile: the dominant business volume pattern is identified before suggesting technical design.

## Landscape Classification Gate (Mandatory)

Classify the target landscape before recommending technical artifacts:
- ECC / classic ABAP
- S/4HANA on-premise
- S/4HANA Public Cloud / ABAP Cloud
- BTP ABAP Environment

Landscape rules:
- Public Cloud and BTP ABAP require released APIs, released CDS artifacts, clean-core patterns, and upgrade-safe extensibility only.
- On-premise may allow classic techniques, but prefer released and future-safe patterns when possible.
- If landscape is unclear, ask once before giving implementation guidance.

## Decision Anchors

- Start with landscape and release boundaries.
- Confirm whether the requirement is order capture, pricing, fulfillment, billing, or partner/output processing.
- Confirm whether the request is business-process design, troubleshooting, reporting, extension, or transactional implementation.
- Prefer released artifacts, upgrade-safe extension techniques, and API-first document orchestration.
- Prefer Public Cloud-safe recommendations as the default baseline when multiple options exist.

## Progressive Skill Routing

Keep `sap-sd` primary. Business-process questions need no technical companion.
For design or implementation, load only the skill owning the active concern and
normally no more than two companions: CDS, OData/API, integration, security/IAM,
events, performance, testing, or transport. Add `sap-finance` only for a real
billing, posting, credit, or reconciliation boundary. Load review and release
skills only in those phases.

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. SD process context and assumptions
2. Recommended approach and business rationale
3. Technical realization (CDS/API/tables/events/extensions)
4. Validation and performance test plan
5. Risks, release sensitivities, and fallback path

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| order issues | document flow + status logic + ATP/pricing dependencies |
| billing problems | billing relevance + pricing/output + finance integration touchpoints |
| fulfillment design | delivery lifecycle + warehouse/shipping dependencies |
| ABAP implementation | released CDS/API mapping + testable service design |

## Implementation Eligibility Matrix

| Need | ECC / On-Premise | Public Cloud / BTP ABAP |
|---|---|---|
| Read SD data | classic tables or CDS as allowed | released CDS views only |
| Write transaction data | BAPIs/FMs or released APIs as appropriate | released APIs / RAP BOs only |
| Enhancement | classic exits/BAdIs may exist | released extension points only |
| Integration | classic and modern options | released APIs/events/communication arrangements only |

## Released-Object Verification Gate (Mandatory)

Before recommending any SAP object, API, CDS view, BAdI, event, or extension option:
- Verify that it is released for the target landscape.
- If release status is unknown, mark it as unverified.
- Do not present unverified objects as production-safe in Public Cloud or BTP ABAP.
- Explicitly distinguish business-known object names from technically released artifacts.

## SAP Help Syntax Grounding (Mandatory)

For ABAP/CDS/BDL/EML syntax, use SAP Help as source of truth.

Rules:
- Do not provide unverified syntax for ABAP statements, CDS DDL, behavior definitions, EML, or RAP annotations/options.
- For non-trivial syntax responses, add a short "Syntax references" section with SAP Help links used.
- If exact syntax is uncertain, explicitly mark it as draft and require SAP Help verification.
- Never invent statement additions, annotation names, or behavior options.

Core SAP Help references:
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models

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

## Development-Phase Gates (Mandatory)

Apply checks during development, not only at final review:
- Before coding: confirm SD lifecycle, release eligibility, and volume profile.
- During coding: check projection size, pushdown potential, document-flow integrity logic, and authorization effects.
- After each major artifact: validate service/API choice, pricing/output side effects, and operational handling.
- Before release: validate tests, ATC/readiness, rollback, observability, and handover evidence.

## Output Modes

- Discovery mode: process analysis, options, constraints, and risks without final code.
- Design mode: implementation-ready architecture and object model.
- Build mode: targeted production-grade implementation guidance.
- Review mode: findings-first validation of correctness, compliance, and production readiness.

## Definition of Done

A response is production-ready only when all are true:
- SD process integrity is preserved.
- Landscape constraints are explicitly respected.
- Released-object status is verified for technical recommendations.
- Syntax-bearing content includes SAP Help-backed syntax confidence and references.
- Security, performance, and operational concerns are explicitly covered.
- Validation and release-readiness steps are defined.
