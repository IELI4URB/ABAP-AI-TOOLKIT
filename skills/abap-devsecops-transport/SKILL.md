---
name: abap-devsecops-transport
description: >-
  DevSecOps and transport governance for SAP ABAP Cloud. Covers delivery pipeline stages, ATC governance (ABAP_CLOUD_DEVELOPMENT_DEFAULT, ABAP_CLEAN_CORE_READINESS, Cloud Capability checks), gCTS (single global account only), SAP Cloud Transport Management (cTMS) for cross-account, SAP Cloud ALM integration, branch strategy, transport approval workflow, emergency rollback, and waiver management. Triggers: ATC, transport, gCTS, pipeline, CI/CD, deploy, release, branch, merge, quality gate, Cloud ALM, cTMS, rollback, waiver.
metadata:
  version: 2.0.0
  tags: abap devsecops transport atc gcts cicd cloud-alm abap-cloud
---

# ABAP Cloud DevSecOps and Transport Governance

Expert guide for release-safe delivery with automated quality gates, controlled transports, and compliance monitoring.

**Golden rule: gCTS for same-account transport. cTMS for cross-account. ATC blocks P1/P2 at transport release. No exceptions without time-bound waiver.**

Reference files:
- `references/pipeline-and-transport.md` — pipeline stages, ATC configuration, transport controls

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

## Transport Mechanism Decision

| Scenario | Mechanism | Key Constraint |
|---|---|---|
| Transport within same BTP global account | **gCTS** | Same region, same global account ONLY |
| Transport across global accounts | **SAP Cloud Transport Management (cTMS)** | Requires service instance |
| ISV/partner solution delivery | **Add-on build pipeline** | Separate build system |
| S/4HANA on-premise | **Classic CTS** or **gCTS** | Classic CTS NOT available in BTP |

---

## Pipeline Stages

| Stage | Gate | Blocks On |
|---|---|---|
| Build & syntax | Compiler | Syntax errors |
| Static quality (ATC) | `ABAP_CLOUD_DEVELOPMENT_DEFAULT` | Unreleased APIs, security P1/P2 |
| Automated tests | ABAP Unit | Test failures |
| Review gate | abap-code-review-checklist skill | Unresolved critical findings |
| Transport gate | Approval workflow | Missing sign-off |

---

## ATC Check Variants

| Variant | Purpose |
|---|---|
| `ABAP_CLOUD_DEVELOPMENT_DEFAULT` | Enforce during new development |
| `ABAP_CLOUD_DEVELOPMENT_3TIER` | 3-tier model (Tier 1+2) |
| `ABAP_CLEAN_CORE_READINESS` | Assess brownfield code |

**Cloud Capability checks to add to custom variant:**
- `SLIN_VERS` — Language version compliance
- `SYCM_CLOUD_RELEASED` — Released API usage
- `SYCM_CHECK_AP_LANGU` — Cloud language check
- `SYCM_C_ALLOWED_OBJCT` — Allowed object types

**SAP Notes:** 3565942, 3627152, 3568611

---

## SAP Cloud ALM Integration

- System View dashboard: real-time clean core compliance per system
- Ingests ATC data from Custom Code Migration app
- Tracks A–D level distribution across landscape
- Required for RISE compliance metrics

---

## Response Rules
### "How do I transport?" → Determine: same account (gCTS) or cross-account (cTMS)?
### "ATC is blocking" → Check finding type: P1/P2 = must fix; P3 = can waive
### "Emergency fix?" → Emergency transport process with post-merge backport

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
