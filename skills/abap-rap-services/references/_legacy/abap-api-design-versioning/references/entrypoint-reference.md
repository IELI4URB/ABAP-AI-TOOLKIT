---
name: abap-api-design-versioning
description: >-
  API design and versioning for SAP ABAP Cloud RAP services. Covers SAP RAP versioning via service binding names (NOT URL path segments), multiple projections on same interface view, backward compatibility rules, SAP API Deprecation Policy (24-month minimum, 12-month deprecated phase), LUW constraint for multi-projection BOs, @API.element.releaseState annotation, versioned DTOs, and deprecation workflow. Triggers: API version, service binding, backward compatible, breaking change, deprecation, API lifecycle, multiple projections, versioned service, contract, OData version.
metadata:
  version: 2.0.0
  tags: abap api versioning odata service-binding deprecation backward-compatible abap-cloud
---

# API Design and Versioning for ABAP Cloud

Expert guide for designing APIs that evolve without breaking clients — RAP service versioning, deprecation, and contract management.

**Golden rule: Version via service binding NAME (e.g. API_TRAVEL_V1_O4), NOT URL path segments. SAP guarantees 24-month minimum API lifespan. Never remove published fields — deprecate them.**

Reference files:
- `references/api-patterns.md` — versioning strategies, backward compatibility rules, deprecation workflow

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

## SAP RAP Versioning Model

**Versioning is in the SERVICE BINDING NAME, not the URL:**
```
API_TRAVEL_V1_O4  → OData V4 version 1
API_TRAVEL_V2_O4  → OData V4 version 2
ZUI_TRAVEL_V1_O4  → UI binding version 1
```

**Architecture for multi-version:**
```
ZI_Travel (Interface View — shared, stable)
    ├── ZC_Travel_V1 (Projection V1) → ZSD_Travel_V1 → API_TRAVEL_V1_O4
    └── ZC_Travel_V2 (Projection V2) → ZSD_Travel_V2 → API_TRAVEL_V2_O4
```

**LUW Constraint:** Same BO must NOT be modified via different projections in the same LUW (Logical Unit of Work). Violating this causes runtime errors.

---

## Breaking vs Non-Breaking Changes

| Change | Breaking? | Action |
|---|---|---|
| Add optional field | NO | Add to V1 (backward compatible) |
| Add new entity | NO | Add to V1 service definition |
| Remove field | YES | Create V2, deprecate field in V1 |
| Change field type | YES | Create V2 |
| Rename entity | YES | Create V2 |
| Add required field | YES | Create V2 |
| Add new enum value | NO | Clients should handle unknown values |

---

## SAP API Deprecation Policy

| Phase | Duration | Status |
|---|---|---|
| Active | Minimum 24 months total | Fully supported |
| Deprecated | Minimum 12 months | Works, warns, has successor |
| Decommissioned | After deprecated phase | Removed |

---

## Field-Level Deprecation

```cds
@API.element.releaseState: #DEPRECATED
@API.element.successor: 'EstimatedCost'
CalculatedAmount;  // Deprecated — use EstimatedCost instead
```

---

## Response Rules
### "How do I version my API?" → Service binding name convention, NOT URL paths
### "Is this a breaking change?" → Use the breaking/non-breaking matrix
### "How long before I can remove?" → 24 months minimum (SAP policy)

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
