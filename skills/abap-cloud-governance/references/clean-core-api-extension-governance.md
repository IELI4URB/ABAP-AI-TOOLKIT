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

Source: SAP Help — [ABAP Cloud](https://help.sap.com/docs/abap-cloud) Clean Core and released-API guidance.

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

Release **state** (Released / Deprecated / Decommissioned — plus the implicit *Not released / Not published*, i.e. absence of any stable contract) and release **contract** (C0–C4) are separate axes. See `official-abap-cloud-apis-and-releases.md` for the authoritative definitions.

| State / Contract | Meaning | Use in custom code? |
|---|---|---|
| Released, **C1** (Use System-Internally) | Stable public API for consumption in on-stack custom code (ADT or key-user apps) | **Yes** — the standard case for consuming SAP APIs |
| Released, **C0** (Extend) | Stable extension points (BAdI, enhancement, RAP extension) | Yes — for extending SAP objects |
| Released, **C2** (Use as Remote API) | Stable remote API | Yes — for remote / side-by-side consumption |
| Released (Deprecated) | Still usable, has a successor | Allowed; plan migration |
| Decommissioned | Unsupported (C2 remote APIs only) | No — replace with highest priority |
| Not released / Not published | No stable contract | Never in custom code |

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
| Released object types | BAdIs, CDS views | BAdIs, classes, interfaces, CDS views, behavior definitions, authorization objects | BAPIs, IDocs, OData APIs, SOAP APIs, events |
| Use cases | UI field layout, custom fields, custom logic, custom CDS views | Lifecycle-stable ABAP apps, extensions of SAP S/4HANA, partner extensions | Custom/multitenant apps, ABAP + non-ABAP, partner SaaS |

Key points:
- All three are modification-free and backed by **release contracts** (C0/C1…) — upgrade-safe.
- **Layered**: customers and partners extend in parallel without interference.
- The **Virtual Data Model (VDM)** — released CDS views over abstract DB tables — is the data-access basis for **all three** options.
- Key User + Developer = **On-Stack** (run inside the S/4HANA system); Side-by-Side runs on **BTP**.
- Developer Extensibility is the ABAP Cloud (ADT) path this governance guide targets by default; Key User is low/no-code; Side-by-Side decouples onto BTP when the extension should not live on-stack.

#### Choosing an extensibility model (decision guide)

Grounded on SAP Help *"What extensibility option suits my purpose?"* (S/4HANA Cloud Public Edition → Extend and Integrate → Extensibility). Decide per requirement, top-down:

1. **Can a key user do it with no code?** (add a field, a custom CDS view/query, a simple custom business object, a rule) → **Key User Extensibility**. No ADT, no transport pipeline.
2. **Does it need real ABAP logic tightly coupled to SAP transactional data/BOs on the same stack?** (RAP behavior extension, released BAdI, custom ABAP app consuming released APIs in-process) → **Developer Extensibility** (ADT, ABAP for Cloud Development).
3. **Does it need a separate runtime, lifecycle, or non-ABAP tech?** → **Side-by-Side** on BTP.

**Pick Side-by-Side when any of these hold** (common for AI / POC use cases):
- Non-ABAP technology required — **Java, Node.js, Python, AI/ML services, LLM orchestration**, third-party SDKs.
- Extension must **scale and be released independently** of the S/4HANA lifecycle (own CI/CD, own upgrade cadence).
- **Loose coupling** is desired — integrate via released OData/SOAP/Events/SQL service, not in-process.
- **Multitenant / SaaS** solution, or a partner app serving multiple customers.
- Workload shouldn't consume S/4HANA app-server resources, or must reach external systems/data.

**Stay On-Stack (Key User or Developer) when:**
- The extension is **synchronous** to SAP business logic / transactional consistency (same LUW).
- It only reads/writes SAP data via released APIs and needs **low-latency in-process** access.
- No extra runtime or non-ABAP tech is needed.

> **AI-POC heuristic (derived, not SAP doctrine).** Applying the SAP criteria above: if a POC calls an external AI service or runs non-ABAP code, the Side-by-Side triggers are met → default to **Side-by-Side** (BTP — ABAP environment or CAP/Node/Java), consuming S/4HANA through **released APIs / events**. Use On-Stack only when the AI logic is thin enough to run as released-API ABAP in-system. This is engineering guidance inferred from the grounded comparison, not a statement from SAP Help.

### 2B. Business Configuration content (C3)

Custom **business configuration** (customizing) content is the **C3 "Manage Configuration Content"** contract. Developer workflow (business role `SAP_BR_DEVELOPER`):

- Base the config on a DB table with **delivery class `C`** (`@AbapCatalog.deliveryClass: #C`) so content is **transportable between tenants** (created in DEV, transported to TEST/PROD via **customizing** transport requests).
- Build a full **RAP business object** on the table and expose it as an **OData service** so business users maintain content through a UI. SAP's standardized **Custom Business Configurations app** consumes it — prefer it over a bespoke UI.
- Alternative for large volumes: enable the object for **file upload/download** (generic file-upload app; supports the ERP/S4 download format for migration) — no full BO required.
- **Business Configuration Change Logs** track lifecycle; maintenance/lifecycle is usually a separate user from the developer.

Source: SAP Help — [Business Configuration (ABAP environment)](https://help.sap.com/docs/btp/sap-business-technology-platform/dev-in-abap-env-business-configuration?locale=en-US).

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

Verification focus:
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

