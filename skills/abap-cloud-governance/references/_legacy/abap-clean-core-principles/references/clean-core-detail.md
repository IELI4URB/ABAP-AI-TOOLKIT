# Clean Core Principles for ABAP Cloud

Source: SAP Help Portal ABAP Cloud, skill pack module 04.

## Objective

Codify the mandatory principles that keep SAP extensions upgrade-safe, released-API compliant, and governance-ready.

## 1. The Five Clean Core Principles

### 1 — Upgrade-Safe by Design

No modifications to SAP standard objects. Use released extension points only.

| Need | Clean Core Approach |
|---|---|
| Add custom field | ABAP Cloud custom field API or RAP BO extension |
| Change SAP logic | Released BAdI or RAP behavior extension |
| Custom reporting | Released CDS views only |
| Modify SAP FM | Never, rebuild via released API |

### 2 — Release-State Discipline

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

### 3 — Extension Over Modification

Use SAP-provided extension points only:
- RAP BO extensions (BDEF extension, CDS view extension).
- Released BAdIs.
- Released enhancement spots.

### 4 — Package Discipline

| Package Purpose | Naming Convention |
|---|---|
| Domain objects | ZDOMAIN_<AREA> |
| Application services | ZAPP_<FEATURE> |
| Infrastructure adapters | ZINFRA_<SYSTEM> |
| Tests | ZTEST_<MODULE> |

### 5 — API-First Design

All cross-domain integration uses explicit service contracts.

Prohibition:
- No direct table reads across domain boundaries.

## 2. Clean Core Extension Levels

| Level | Description | ATC | When |
|---|---|---|---|
| A | Released APIs plus RAP extension points | No findings | Default, always first choice |
| B | Classic BAdIs plus released objects | Minor findings | If level A is not possible |
| C | Wrapper over non-released objects | Warnings | Only if no level B alternative |
| D | Direct modifications | Errors or blocked | Never |

## 3. Anti-Patterns

| Pattern | Problem | Fix |
|---|---|---|
| God class (100+ methods) | Untestable and fragile | Split by responsibility (SRP) |
| Circular dependencies | Build/runtime instability | Use domain events for decoupling |
| Direct SELECT on SAP internal tables | Upgrade break risk | Use released CDS views |
| Infrastructure logic in Domain layer | Layer violation | Move to Infrastructure behind interface |
| No package checks | Dependency creep | Enable package checks in ADT |

## 4. Clean Core Governance Checklist

- [ ] No SAP standard modifications
- [ ] All consumed SAP objects are C1 released or explicitly governed
- [ ] Extension points are used instead of code modifications
- [ ] Package naming and dependency rules are enforced
- [ ] Cross-domain integration is API-first
- [ ] ATC released-API check passes with zero violations

## 5. SAP Help Verification Addendum

Verification focus for module 04:
- Clean Core principles are aligned with ABAP Cloud released API and extension guidance.
- API release-state discipline is validated in ADT and enforced by ATC.
- Upgrade-safe design remains the default decision path across all modules.

## 6. Extension Level Escalation Rule (Additive)

Escalation must be explicit and documented:
1. Attempt level A (released APIs and RAP extension points).
2. If blocked, document why level A is not feasible.
3. Escalate to level B/C only with architecture and risk approval.
4. Level D remains prohibited.

## 7. Release-State Audit Checklist

- [ ] API release state recorded for every external SAP object usage.
- [ ] Deprecated usages have migration plan and target release.
- [ ] Restricted/internal/not-published objects are absent from productive custom code.
- [ ] ATC findings are attached to transport/release evidence.

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
