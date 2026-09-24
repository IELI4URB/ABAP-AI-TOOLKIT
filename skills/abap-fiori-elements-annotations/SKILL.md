---
name: abap-fiori-elements-annotations
description: >-
  Fiori Elements and ABAP CDS annotation guidance organized by CDS artifact type: interface/basic views, composite views, transactional projections, value-help providers, text providers, and metadata extensions. Covers value helps, dependent additional bindings, text associations/elements, ID-text display, @UI.textArrangement, list reports, object pages, and UI annotations. Use for value help, F4 help, dropdown, text display, show ID and description, interface versus projection annotation placement, metadata extension, @Consumption.valueHelpDefinition, @ObjectModel.text.*, or @UI annotations.
metadata:
  version: 2.0.0
  tags: abap fiori-elements annotations ui value-help text-display projection-view interface-view metadata-extension
---

# Fiori Elements UI Annotations for ABAP Cloud

Expert guide for CDS and UI annotations that drive Fiori Elements applications, with annotation ownership determined by CDS artifact type.

**Golden rule: model reusable semantics in interface/provider views, service-specific consumption contracts in projections, and app-specific UI presentation in metadata extensions. A value help, a text source, and text arrangement are three separate contracts.**

Reference files:
- `references/value-help-and-text-display.md` — mandatory CDS-type placement, value-help contracts, text-provider patterns, ID/text display, failure diagnosis, and validation
- `references/ui-annotations-catalog.md` — broader UI annotation examples; verify each example against the target OData, UI5, and ABAP release before copying

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

## Annotation Placement Architecture

```
ZI_AgencyText (Text Provider)  → language key + text semantics
ZI_AgencyVH   (Value Help)     → selectable key + display/filter fields
      ↘                    ↙
ZI_Travel     (Interface)      → reusable business and text semantics
  ↓
ZC_Travel     (Projection)     → service-specific value-help contract
  ↓
ZME_Travel    (Metadata Ext.)  → app-specific UI and text arrangement
```

| CDS artifact | Preferred annotation responsibility |
|---|---|
| Interface/basic view | Stable key, semantics, reusable text element/association |
| Composite interface view | Reusable business joins and semantic relationships |
| Transactional projection | Service-specific value-help binding and exposed text fields/associations; use release-supported denormalized text patterns when needed |
| Value-help provider | Returned key, dialog display fields, search fields, dependent-filter fields |
| Text provider | Business key, language key, descriptive text |
| Metadata extension | `@UI.lineItem`, facets, selection fields, labels, and app-specific `@UI.textArrangement` |

For any value-help or text-display request, read `references/value-help-and-text-display.md` before proposing annotations. Do not infer placement from the annotation prefix alone.

---

## Essential @UI Annotations

### Header Info (Page Title)
```cds
@UI.headerInfo: {
  typeName: 'Travel',
  typeNamePlural: 'Travels',
  title: { type: #STANDARD, value: 'Description' },
  description: { type: #STANDARD, value: 'TravelID' }
}
```

### List Report Columns
```cds
@UI.lineItem: [{ position: 10, importance: #HIGH }]
TravelID;

@UI.lineItem: [{ position: 20, importance: #HIGH, criticality: 'StatusCriticality' }]
Status;

@UI.lineItem: [{ position: 30, type: #AS_DATAPOINT }]
TotalPrice;
```

### Object Page Facets
```cds
@UI.facet: [
  { id: 'General', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'General', position: 10 },
  { id: 'Booking', purpose: #STANDARD, type: #LINEITEM_REFERENCE, label: 'Bookings', position: 20, targetElement: '_Booking' }
]
```

### Selection Fields (Filter Bar)
```cds
@UI.selectionField: [{ position: 10 }]
AgencyID;

@UI.selectionField: [{ position: 20 }]
Status;
```

---

## Value Help Pattern

Value help and text display must be modeled independently:

```cds
@Consumption.valueHelpDefinition: [{
  entity: {
    name: 'ZI_AgencyVH',
    element: 'AgencyID'
  }
}]
AgencyID;
```

- Prefer a dedicated value-help provider such as `ZI_AgencyVH`.
- Put the annotation on the projection when the contract is service-specific; use the interface only when every consumer shares the same contract.
- Do not use `additionalBinding` with `#RESULT` merely to display a description. Model a text element or text association instead.
- For dependent value helps, specify `usage` explicitly. The documented default when omitted is `#FILTER_AND_RESULT`.
- Verify all local/provider elements, type compatibility, writeability, authorization, Active Annotations, and generated `$metadata`.

## Text Display Pattern

When the description already exists in the same entity, define the text source separately from its UI arrangement:

```cds
@ObjectModel.text.element: ['AgencyName']
AgencyID,
AgencyName
```

Apply consumption-specific presentation to the service-exposed property, preferably in the metadata extension:

```cds
@UI.textArrangement: #TEXT_LAST
AgencyID;
```

For language-dependent text, choose by consumption pattern: direct association consumption uses `@ObjectModel.text.association`; a denormalized projection follows the target-release `localized` plus text-element pattern and must not retain a prohibited text association. Do not combine strategies without target-release evidence.

Text arrangement does not supply a text. The referenced text element or association must survive the projection and appear correctly in OData metadata.

Metadata extensions require the target CDS entity to allow extensions, for example through `@Metadata.allowExtensions: true` where supported.

---

## Side Effects (Refresh After Change)

```cds
// In BDEF:
side effects {
  field Amount affects field TotalPrice, entity _Booking;
  action RecalculatePrice affects field TotalPrice;
}
```

---

## Chart and Data Point Annotations

```cds
// Data point definition (used by chart and KPIs)
@UI.dataPoint: {
  qualifier: 'TotalPriceDP',
  title: 'Total Price',
  criticality: 'PriceCriticality'
}
TotalPrice;

// Chart annotation (Analytical List Page or Object Page section)
@UI.chart: [{
  qualifier: 'PriceByAgency',
  chartType: #BAR,
  title: 'Revenue by Agency',
  dimensions: [{ value: 'AgencyID', role: #CATEGORY }],
  measures: [{ value: 'TotalPrice', role: #AXIS_1, dataPoint: '@UI.DataPoint#TotalPriceDP' }]
}]
AgencyID;

// To use chart in Object Page facet:
@UI.facet: [{
  id: 'RevenueChart',
  purpose: #STANDARD,
  type: #CHART_REFERENCE,
  qualifier: 'PriceByAgency',
  label: 'Revenue Analysis',
  position: 30
}]
```

---

## Draft Actions

Do not model standard RAP draft Edit, Save/Activate, Resume, or Discard buttons as custom `@UI.lineItem` actions. Fiori Elements derives standard draft controls from the draft-enabled RAP/OData capabilities. Verify draft behavior and target-version UI behavior in SAP Help before adding any custom action annotation.

---

## Object Page — Identification Section

The `@UI.identification` annotation marks fields that appear in the Object Page header identification area (displayed prominently at the top).

```cds
@UI.identification: [{ position: 10 }]
travel_id;

@UI.identification: [{ position: 20, label: 'Description' }]
description;

// Combine headerInfo with identification for Object Page header:
@UI.headerInfo: {
  typeName: 'Travel',
  typeNamePlural: 'Travels',
  title: { type: #STANDARD, value: 'TravelId' },
  description: { type: #STANDARD, value: 'Description' }
}
```

---

## Response Rules

### "How do I add a column to the list?" → @UI.lineItem
### "How do I create sections on Object Page?" → @UI.facet
### "How do I add a filter?" → @UI.selectionField
### "Where does this annotation belong?" → classify the CDS artifact first, then use the placement matrix
### "How do I add a value help?" → read `references/value-help-and-text-display.md`; define provider and mappings before UI layout
### "How do I show description instead of ID?" → define text source first, then `@UI.textArrangement`
### "How do I add a dropdown?" → verify fixed-value semantics and generated metadata; valueHelpDefinition alone does not guarantee a dropdown
### "How do I show a chart?" → @UI.chart + @UI.dataPoint (see Chart section above)

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
- Never use value-help result binding as a substitute for text modeling.
- Never recommend text arrangement without identifying the text source.
- Never recommend `additionalBinding` until every local and provider element has been verified.
- Preserve the separation between value-help provider and associated text provider unless generated metadata proves the combined design works.

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Architecture or design trade-offs | decision matrix + constraints + target-state blueprint |
| New implementation | modeling flow + API contract + test strategy |
| Performance issue | hotspot isolation + pushdown/pagination/index strategy |
| Security or authorization | threat points + authorization model + hardening controls |
| Integration behavior | protocol contract + resilience patterns + observability |
| Code review or readiness | findings first + risk ranking + concrete remediation steps |
