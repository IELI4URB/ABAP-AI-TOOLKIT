---
name: sap-clean-core-enterprise
description: Use for end-to-end SAP ABAP Clean Core solution architecture and release governance across S/4HANA Public Cloud, Private Cloud ABAP Cloud, and BTP ABAP Environment, including C1 APIs, extension models, ATC, transport, and enterprise delivery.
---

# SAP Clean Core Enterprise Skill

## Purpose

Apply an end-to-end architecture-to-release playbook for:
- SAP S/4HANA Public Cloud
- SAP S/4HANA Private Cloud (ABAP Cloud)
- SAP BTP ABAP Environment

Reference pack: load the `SAP-ABAP-Cloud-Skills` bundle from your active skill library.

## SAP Help Baseline

Use SAP Help as primary evidence for non-trivial recommendations:
- https://help.sap.com/docs/abap-cloud
- https://help.sap.com/docs/btp/sap-business-technology-platform/abap-environment
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm

Release-awareness sources:
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html

## Mandatory Workflow

1. Classify target landscape first.
2. Select matching skill sequence from pack README.
3. Validate assumptions against SAP Help.
4. Design with released APIs and Clean Core constraints.
5. Define tests, operations, and release gates.
6. Produce evidence map and residual-risk notes.

## Progressive Skill Routing

Keep this skill as the enterprise Clean Core owner. Load one primary domain or
technical skill for the active decision and normally no more than two companions.

- Clean Core/release-state decision: `abap-clean-core-principles`
- Data model: `abap-cds-data-modeling`
- Service contract: `abap-odata-service-development` or `abap-api-design-versioning`
- Security: `abap-security-hardening` or `abap-iam-authorization`
- Integration: `abap-integration-patterns`; add `abap-error-handling-resilience` only when failure semantics are in scope
- Implementation validation: `abap-code-review-checklist` and `abap-unit-testing`
- Release phase: `abap-devsecops-transport`

Do not load implementation, review, and release skills during initial discovery.
Add more than two companions only for an explicitly cross-domain architecture
decision, and state why each additional skill is required.

## Development-Phase Continuous Gates (Not Only End Review)

Apply checks during development iterations, not only at final review:
- Before coding a component: run Gate 0 checklist and design-pattern decision.
- After each major method/entity (or every 60-90 minutes): run performance micro-checklist from `abap-performance-optimization` and Section E of `abap-code-review-checklist`.
- Before commit/transport: run full review checklist across all sections.

## Non-Negotiable Rules

- Use released objects and released APIs only.
- No modifications to SAP standard objects.
- No unreleased direct table or API dependencies in cloud-mode designs.
- Include at least two SAP Help references for non-trivial recommendations.

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. Context and landscape assumptions
2. Recommended approach with Clean Core impact
3. RAP/CDS/application design outline
4. Validation plan (ABAP Unit, ATC, transport gates)
5. Evidence map, version sensitivity, and residual risks

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| architecture decisions | layered blueprint + constraint analysis |
| implementation design | RAP/CDS/service contract + test strategy |
| release readiness | gate checklist + evidence pack |
| production risk | resilience + observability + rollback plan |

## Skill Selection Matrix (Agent Behavior)

| Requirement signal | Mandatory skill bundle |
|---|---|
| New feature or enhancement | `abap-clean-core-principles` + `abap-oops-design-patterns` + `abap-code-review-checklist` + `abap-performance-optimization` |
| CDS or RAP model change | previous bundle + `abap-cds-data-modeling` |
| API/service exposure | previous bundle + `abap-odata-service-development` + `abap-api-design-versioning` |
| Security/authorization impact | previous bundle + `abap-security-hardening` + `abap-iam-authorization` |
| External system integration | previous bundle + `abap-integration-patterns` + `abap-error-handling-resilience` |
| Event-driven or extensibility | previous bundle + `abap-events-and-enhancements` |
| Release/transport planning | previous bundle + `abap-devsecops-transport` + `abap-unit-testing` |


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
