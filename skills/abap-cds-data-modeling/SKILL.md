---
name: abap-cds-data-modeling
description: >-
  Complete CDS data modeling guide for ABAP Cloud. Covers CDS View Entities, Projection Views, Abstract Entities, Custom Entities, Table Entities, Hierarchies, associations, compositions, CDS annotations catalog, metadata extensions, CDS roles (DCL access control), and entity extension patterns. Use for any CDS DDL question, data model design, association vs composition decisions, annotation syntax, or entity type selection. Triggers: CDS, view entity, projection, association, composition, annotation, metadata extension, abstract entity, custom entity, hierarchy, table entity, DDL, data model, DEFINE VIEW ENTITY.
metadata:
  version: 1.0.0
  tags: abap cds data-modeling view-entity annotations abap-cloud ddl associations
---

# CDS Data Modeling for ABAP Cloud

Expert guide for designing CDS-based data models in SAP ABAP Cloud — every entity type, association pattern, and annotation category.

**Golden rule: Interface view for reuse, projection view for consumption, metadata extension for UI. Never mix concerns.**

Reference files:
- `references/cds-complete-syntax.md` — full DDL syntax for all entity types with code examples

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

## Entity Type Selection Matrix

| Need | Entity Type | Persistence | Use Case |
|---|---|---|---|
| Standard data model on DB tables | **CDS View Entity** | Yes (SQL) | Core BO data model, interface views |
| Consumption-specific shape | **CDS Projection View** | Delegates | UI projection, API projection |
| Parameter structure (no DB) | **Abstract Entity** | No | Action parameters, event payloads |
| Manual data provider (code) | **Custom Entity** | No (code) | External API data, calculated results |
| AMDP-based tabular result | **Table Function** | No (AMDP) | Complex calculations, window functions |
| Tree/hierarchy structure | **CDS Hierarchy** | Derived | Org charts, BOM explosion |
| Future table replacement | **Table Entity** | Yes | New-style persistence (2025+) |

---

## Three-Layer Architecture

```
┌─────────────────────────────────────────────┐
│  CONSUMPTION LAYER                          │
│  ZC_Travel (Projection View)               │
│  + Metadata Extension (UI annotations)      │
│  + Service Definition + Service Binding     │
├─────────────────────────────────────────────┤
│  BUSINESS OBJECT LAYER                      │
│  ZI_Travel (Interface View Entity)          │
│  + Behavior Definition (BDEF)              │
│  + Behavior Implementation (ABP class)     │
├─────────────────────────────────────────────┤
│  PERSISTENCE LAYER                          │
│  ZTRAVEL (Database Table)                  │
│  ZTRAVEL_D (Draft Table)                   │
└─────────────────────────────────────────────┘
```

---

## Association vs Composition

| Aspect | Association | Composition |
|---|---|---|
| Relationship | Independent entities | Parent-child (lifecycle) |
| Delete behavior | Independent | Child deleted with parent |
| Draft | Independent draft | Shared draft with parent |
| Lock | Independent lock | Parent lock covers child |
| Syntax | `association [0..*] to` | `composition [0..*] of` |
| Use when | Travel → Agency (lookup) | Travel → Booking (owned) |

```sql
define view entity ZI_Travel as select from ztravel {
  key travel_id,
  agency_id,
  
  // Association: independent entity (lookup)
  association [1..1] to ZI_Agency as _Agency
    on $projection.agency_id = _Agency.agency_id,
    
  // Composition: owned child entities
  composition [0..*] of ZI_Booking as _Booking
}
```

---

## Key Annotations by Category

| Category | Annotation | Purpose |
|---|---|---|
| **Semantics** | `@Semantics.amount.currencyCode` | Currency field binding |
| **Semantics** | `@Semantics.quantity.unitOfMeasure` | Unit field binding |
| **Object Model** | `@ObjectModel.representativeKey` | Key for value help |
| **Object Model** | `@ObjectModel.usageType.serviceQuality` | Performance hint |
| **Search** | `@Search.defaultSearchElement: true` | Fuzzy search field |
| **Consumption** | `@Consumption.valueHelpDefinition` | Value help binding |
| **OData** | `@OData.publish: true` | Auto-publish (legacy) |
| **Analytics** | `@Analytics.dataCategory: #CUBE` | Analytical model |
| **AccessControl** | `@AccessControl.authorizationCheck: #CHECK` | DCL enforcement |

---

## Response Rules

### "How do I model X?" questions
→ Start with entity type selection matrix
→ Show three-layer architecture placement
→ Provide complete DDL with associations and annotations

### "Association or composition?" questions
→ Key question: "Does the child have independent lifecycle?"
→ YES = association, NO = composition
→ Show both with BDEF implications (lock, draft, delete)

### "What annotation do I use for X?" questions
→ Reference the annotation catalog in references file
→ Show the annotation in context of a full CDS view

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
