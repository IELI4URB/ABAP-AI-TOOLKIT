---
name: abap-fiori-elements-annotations
description: >-
  Complete Fiori Elements UI annotation guide for ABAP Cloud. Covers all @UI annotations (lineItem, fieldGroup, identification, selectionField, facet, headerInfo, chart), @Consumption.valueHelpDefinition, @Search annotations, List Report, Object Page, Analytical List Page, Overview Page, side effects, draft indicators, and metadata extension patterns. Triggers: @UI, annotation, Fiori Elements, list report, object page, lineItem, facet, headerInfo, value help, search, metadata extension, side effect, draft, analytical, chart, column, field group, selection field.
metadata:
  version: 1.0.0
  tags: abap fiori-elements annotations ui list-report object-page value-help abap-cloud
---

# Fiori Elements UI Annotations for ABAP Cloud

Expert guide for all CDS UI annotations that drive Fiori Elements applications — List Reports, Object Pages, Analytical views, and more.

**Golden rule: Annotations go in Metadata Extensions (separate from data model). Never mix UI concerns into interface views.**

Reference files:
- `references/ui-annotations-catalog.md` — complete annotation catalog with every option and pattern

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
ZI_Travel (Interface View)     → NO UI annotations here
    ↓
ZC_Travel (Projection View)    → Minimal annotations (valueHelp, search)
    ↓
ZME_Travel (Metadata Extension) → ALL @UI annotations here
```

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

```cds
@Consumption.valueHelpDefinition: [{
  entity: { name: 'ZI_Agency', element: 'AgencyID' },
  additionalBinding: [{ localElement: 'AgencyName', element: 'Name', usage: #RESULT }]
}]
AgencyID;
```

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

## Draft Action Buttons

```cds
// In the Projection View — add action buttons for Edit/Save/Discard
@UI.lineItem: [
  { type: #FOR_ACTION, dataAction: 'Edit', label: 'Edit' },
  { type: #FOR_ACTION, dataAction: 'Activate', label: 'Save' }
]
// Note: Draft actions (Edit, Activate, Discard) are exposed via the draft action imports
// in the behavior definition, not as custom actions
```

```cds
// Enable Edit button via BDEF draft action
// In BDEF:
//   draft action Edit;
//   draft action Activate;
//   draft action Discard;
//   draft action Resume;
//   draft determine action Prepare;
```

For the Edit button in the List Report (to show the pencil icon per row):
```cds
@UI.lineItem: [{ position: 10, label: 'Travel ID' },
               { type: #FOR_ACTION, dataAction: 'Edit',
                 label: 'Edit', position: 100 }]
travel_id;
```

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
### "How do I add a value help dropdown?" → @Consumption.valueHelpDefinition
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

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Architecture or design trade-offs | decision matrix + constraints + target-state blueprint |
| New implementation | modeling flow + API contract + test strategy |
| Performance issue | hotspot isolation + pushdown/pagination/index strategy |
| Security or authorization | threat points + authorization model + hardening controls |
| Integration behavior | protocol contract + resilience patterns + observability |
| Code review or readiness | findings first + risk ranking + concrete remediation steps |
