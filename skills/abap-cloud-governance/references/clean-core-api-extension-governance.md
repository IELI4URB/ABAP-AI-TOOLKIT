---
name: clean-core-api-extension-governance
description: 'Apply Clean Core governance for SAP ABAP Cloud. Use for C0/C1 release contracts, API states, ABAP language versions, Tier 1 and Tier 2 wrappers, A-D maturity, extensibility choices, ATC readiness, upgrade safety, and released-object verification.'
metadata:
  version: 3.0.0
  tags: abap clean-core released-api extension wrapper atc governance
---

# Clean Core API and Extension Governance

See the complete Clean Core reference inlined at the end of this guide for detailed patterns.

## Workflow

1. Establish landscape, language version, owner, and extension need.
2. Verify release state and usage contract for every SAP artifact.
3. Select key-user, developer, Tier 2 API enablement, or side-by-side extensibility.
4. Define ATC/readiness, test, deprecation, transport, and retirement evidence.

## Gates

- Never infer release state from naming; verify source annotation, ADT API state, official catalog, or compiler evidence.
- C0 stabilizes extension points; C1 stabilizes system-internal API consumption. Cloud Development visibility is a separate API classification that must also be verified. Use C2 for remote APIs, C3 for configuration content, and C4 for AMDP contracts.
- Do not modify SAP standard or present an unreleased dependency as production-safe.
- Keep Tier 2 wrappers thin, governed, tested, and replaceable.

## Ownership

This guide owns focused release-state and extension decisions. Use `enterprise-clean-core-delivery` only for end-to-end, cross-phase governance.

---

## Clean Core Principles for ABAP Cloud

Source: SAP Help Portal ABAP Cloud, skill pack module 04.

### Objective

Codify the mandatory principles that keep SAP extensions upgrade-safe, released-API compliant, and governance-ready.

### 1. The Five Clean Core Principles

#### 1 — Upgrade-Safe by Design

No modifications to SAP standard objects. Use released extension points only.

| Need | Clean Core Approach |
|---|---|
| Add custom field | ABAP Cloud custom field API or RAP BO extension |
| Change SAP logic | Released BAdI or RAP behavior extension |
| Custom reporting | Released CDS views only |
| Modify SAP FM | Never, rebuild via released API |

#### 2 — Release-State Discipline

| State | Symbol | Use? |
|---|---|---|
| Released C1 | Yes | Always, backward-compatible |
| Released (Deprecated) | Warning | Allowed, plan migration |
| Restricted C2 | Restricted | Partner or SAP internal scope only |
| Use System-Internally | Internal | Never in custom code |
| Not Published | No | Never |

How to verify in ADT:
1. Right-click object.
2. Open Properties.
3. Check API Release State.

Mandatory gate:
- ATC check "Use of released APIs" must return zero violations.

#### 3 — Extension Over Modification

Use SAP-provided extension points only:
- RAP BO extensions (BDEF extension, CDS view extension).
- Released BAdIs.
- Released enhancement spots.

#### 4 — Package Discipline

| Package Purpose | Naming Convention |
|---|---|
| Domain objects | ZDOMAIN_<AREA> |
| Application services | ZAPP_<FEATURE> |
| Infrastructure adapters | ZINFRA_<SYSTEM> |
| Tests | ZTEST_<MODULE> |

#### 5 — API-First Design

All cross-domain integration uses explicit service contracts.

Prohibition:
- No direct table reads across domain boundaries.

### 2. Clean Core Extension Levels

| Level | Description | ATC | When |
|---|---|---|---|
| A | Released APIs plus RAP extension points | No findings | Default, always first choice |
| B | Classic BAdIs plus released objects | Minor findings | If level A is not possible |
| C | Wrapper over non-released objects | Warnings | Only if no level B alternative |
| D | Direct modifications | Errors or blocked | Never |

### 2A. SAP Extensibility Options (Product Taxonomy)

SAP Help classifies ABAP Cloud extensibility into three options. Orthogonal to the A–D maturity above: pick the *option* by scenario, then stay at the highest A–D level it allows.

Source: https://help.sap.com/docs/abap-cloud/abap-cloud-background-concepts-and-overview/extensibility

| | Key User | Developer | Side-by-Side |
|---|---|---|---|
| Scenario | Smaller low/no-code | Tightly coupled, complex extensions and apps | Loosely coupled extensions and apps |
| Extensibility type | On-Stack | On-Stack | Side-by-Side |
| Persona | Key users | Developers | Developers |
| Target environment | S/4HANA Cloud, S/4HANA, S/4HANA Cloud Private Edition | S/4HANA Cloud, S/4HANA, S/4HANA Cloud Private Edition | SAP BTP (incl. ABAP environment) |
| Tooling | Key User Extensibility tools | ABAP Development Tools (ADT) | ADT / non-ABAP (Java, Node.js) |
| ABAP language version | ABAP for Key Users | ABAP for Cloud Development | ABAP for Cloud Development |
| Use cases | UI field layout, custom fields, custom logic, custom CDS views | Lifecycle-stable ABAP apps, extensions of SAP S/4HANA, partner extensions | Custom/multitenant apps, ABAP + non-ABAP, partner SaaS |

Key points:
- All three are modification-free and backed by **release contracts** (C0/C1…) — upgrade-safe.
- **Layered**: customers and partners extend in parallel without interference.
- Key User + Developer = **On-Stack** (run inside the S/4HANA system); Side-by-Side runs on **BTP**.
- Developer Extensibility is the ABAP Cloud (ADT) path this governance guide targets by default; Key User is low/no-code; Side-by-Side decouples onto BTP when the extension should not live on-stack.

### 3. Anti-Patterns

| Pattern | Problem | Fix |
|---|---|---|
| God class (100+ methods) | Untestable and fragile | Split by responsibility (SRP) |
| Circular dependencies | Build/runtime instability | Use domain events for decoupling |
| Direct SELECT on SAP internal tables | Upgrade break risk | Use released CDS views |
| Infrastructure logic in Domain layer | Layer violation | Move to Infrastructure behind interface |
| No package checks | Dependency creep | Enable package checks in ADT |

### 4. Clean Core Governance Checklist

- [ ] No SAP standard modifications
- [ ] All consumed SAP objects are C1 released or explicitly governed
- [ ] Extension points are used instead of code modifications
- [ ] Package naming and dependency rules are enforced
- [ ] Cross-domain integration is API-first
- [ ] ATC released-API check passes with zero violations

### 5. SAP Help Verification Addendum

Verification focus for module 04:
- Clean Core principles are aligned with ABAP Cloud released API and extension guidance.
- API release-state discipline is validated in ADT and enforced by ATC.
- Upgrade-safe design remains the default decision path across all modules.

### 6. Extension Level Escalation Rule (Additive)

Escalation must be explicit and documented:
1. Attempt level A (released APIs and RAP extension points).
2. If blocked, document why level A is not feasible.
3. Escalate to level B/C only with architecture and risk approval.
4. Level D remains prohibited.

### 7. Release-State Audit Checklist

- [ ] API release state recorded for every external SAP object usage.
- [ ] Deprecated usages have migration plan and target release.
- [ ] Restricted/internal/not-published objects are absent from productive custom code.
- [ ] ATC findings are attached to transport/release evidence.

### SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models

