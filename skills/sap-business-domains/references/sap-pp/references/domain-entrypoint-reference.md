---
name: sap-pp
description: Full-scale SAP Production Planning and PP/DS guidance for ABAP developers and architects on S/4HANA. Use when working on BOM, routing, work centers, MRP, planned orders, production orders, process orders, KANBAN, repetitive manufacturing, capacity planning, PP/DS, or PP-related ABAP design.
metadata:
  version: 2.0.0
  tags: sap abap production-planning pp ppds mrp capacity-planning shop-floor clean-core rap cds
---

# SAP PP and PP/DS Expert Skill

Use this skill for SAP Production Planning design, troubleshooting, and ABAP implementation guidance across S/4HANA contexts.

## Scope

- Master data: BOM, work centers, routings, production versions, material MRP views
- Planning: PIR, MRP Classic, MRP Live, net requirements, planning strategies, lot sizing, pegging
- Execution: planned orders, production orders, process orders, confirmations, GI/GR, KANBAN, repetitive manufacturing
- Capacity and scheduling: shifts, calendars, utilization, CM01/CM21/CM25, PP/DS heuristics, optimizer constraints
- Integrations and controls: MM movement dependencies, settlement impacts, IBP and planning integration touchpoints, status flow, shop-floor integrity
- ABAP: released CDS and cloud-ready APIs for PP scenarios

## SAP Help Baseline

Use SAP Help as the primary business and technical grounding.

Business-process grounding:
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/9d794cbd48c648bc8a176e422772de7e?locale=en-US&state=PRODUCTION&version=2608.500
- https://help.sap.com/doc/7c9e0bbbd1664c2581b2038a1c7ae4b3/2608.500/en-US/FSD_CE2608.pdf

ABAP and syntax grounding:
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models

Release-awareness and extensibility grounding:
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d?locale=en-US&state=PRODUCTION&version=1
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html?locale=en-US&state=PRODUCTION&version=2608.00

## Domain Governance Gates (Mandatory)

Before recommending implementation, validate all of the following:
- Process correctness: the recommendation respects the real PP or PP/DS document and status lifecycle.
- Master data dependencies: BOM, routing, work center, production version, plant parameters, and MRP dependencies are explicit.
- Cross-module integrity: MM movements, reservations, confirmations, settlement, and planning integration impacts are identified.
- Control integrity: planning, execution, and posting controls are preserved across GI/GR, confirmations, and order state transitions.
- Volume profile: the dominant business volume pattern is identified before suggesting technical design, especially for BOM explosion, pegging, order operations, and scheduling.

## Landscape Classification Gate (Mandatory)

Classify the target landscape before recommending technical artifacts:
- ECC / classic ABAP
- S/4HANA on-premise
- S/4HANA Public Cloud / ABAP Cloud
- BTP ABAP Environment
- APO PP/DS (classic)
- Embedded PP/DS on S/4HANA

Landscape rules:
- Public Cloud and BTP ABAP require released APIs, released CDS artifacts, clean-core patterns, and upgrade-safe extensibility only.
- On-premise may allow classic techniques, but prefer released and future-safe patterns when possible.
- APO PP/DS and embedded PP/DS must be distinguished before giving heuristic, optimizer, or pegging guidance.
- If landscape is unclear, ask once before giving implementation guidance.

## Detailed References

Load only the relevant file under `references/` for PP master data, MRP,
production orders, scheduling, ABAP development, released objects, or
governance. Do not require an additional PP skill package.

## Decision Anchors

- Start with landscape and release boundaries.
- Confirm whether requirement is master data, MRP, order execution, capacity planning, PP/DS optimization, or PP-MM integration.
- Confirm whether the request is business-process design, troubleshooting, reporting, extension, or transactional implementation.
- Prefer released artifacts, upgrade-safe extension techniques, and API-first integration paths.
- Prefer Public Cloud-safe recommendations as the default baseline when multiple options exist.

## Progressive Skill Routing

Keep `sap-pp` primary. Business-process questions need no technical companion.
For design or implementation, load only the skill owning the active concern and
normally no more than two companions: CDS, OData/API, integration, security/IAM,
events, performance, testing, or transport. Add `sap-mm` only for a real stock,
movement, or procurement boundary. Load review and release skills only in those
phases.

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. PP process context and assumptions
2. Recommended approach and business rationale
3. Technical realization (CDS/API/tables/events/extensions)
4. Validation and performance test plan
5. Risks, release sensitivities, and fallback path

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| MRP or shortages | requirements/receipts analysis + planning controls + master data dependencies |
| capacity overload | work center capacity model + detailed scheduling or PP/DS strategy |
| order lifecycle issues | status flow + confirmations + movement integrity checks |
| PP-MM integration | reservation, goods movement, stock, and settlement touchpoints |
| ABAP implementation | released CDS/API mapping + testable service design |

## Implementation Eligibility Matrix

| Need | ECC / On-Premise | Public Cloud / BTP ABAP |
|---|---|---|
| Read PP data | classic tables or CDS as allowed | released CDS views only |
| Write PP transaction data | BAPIs/FMs or released APIs as appropriate | released APIs / RAP BOs only |
| Enhancement | classic exits/BAdIs may exist | released extension points only |
| PP/DS execution | classic or embedded objects as landscape allows | only released and permitted artifacts |

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
- Before coding: confirm PP lifecycle, release eligibility, and volume profile.
- During coding: check projection size, pushdown potential, status integrity logic, and authorization effects.
- For BOM, pegging, and where-used style traversal: validate algorithm fit, cycle protection, and max-depth guards.
- Before release: validate tests, ATC/readiness, rollback, observability, and handover evidence.

## Output Modes

- Discovery mode: process analysis, options, constraints, and risks without final code.
- Design mode: implementation-ready architecture and object model.
- Build mode: targeted production-grade implementation guidance.
- Review mode: findings-first validation of correctness, compliance, and production readiness.

## Definition of Done

A response is production-ready only when all are true:
- PP process integrity is preserved.
- Landscape constraints are explicitly respected.
- Released-object status is verified for technical recommendations.
- Syntax-bearing content includes SAP Help-backed syntax confidence and references.
- Security, performance, and operational concerns are explicitly covered.
- Validation and release-readiness steps are defined.
