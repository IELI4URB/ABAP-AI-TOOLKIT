# UI Annotations Catalog — ABAP Cloud Fiori Elements

> **Audience:** Senior ABAP Cloud developers building Fiori Elements List Reports, Object Pages, and Analytical apps.  
> **RAP version:** ABAP Cloud 2023+ (on-premise 2023 and BTP ABAP Environment)

---

## 1. Annotation Placement — The 3-Layer Architecture

A well-structured RAP application separates concerns across three CDS layers. Mixing
annotations across layers is the single most common source of activation errors and
annotation-override failures.

| Layer | Naming convention | Allowed annotations | Purpose |
|---|---|---|---|
| **Interface / BO** | `ZI_*`, `ZR_*` | `@AbapCatalog`, `@AccessControl`, `@ObjectModel`, `@Semantics`, `@Search` | Persistence mapping, associations, access control |
| **Projection / Service** | `ZC_*`, `ZP_*` | `@Consumption`, `@EndUserText`, basic `@ObjectModel` | OData exposure, value help binding, text elements |
| **Metadata Extension** | `ZME_*` (file type `.cdsext`) | Annotations whose official `MDE` property permits DDLX placement | Fiori Elements layout, facets, field groups, charts |

### Placement Rule

> Prefer app-specific `@UI` annotations in metadata extensions when the target entity
> allows extensions and the annotation's official `Scope` and `MDE` properties permit
> DDLX placement. This is an architecture convention, not a universal CDS-language
> rule that every UI annotation must live exclusively in a metadata extension.

---

## 2. Metadata Extension Structure

A metadata extension is a dedicated DDL source object of type **CDS Metadata Extension**.

### Creation in ADT

1. Right-click project → **New → Other ABAP Repository Object → Core Data Services → Metadata Extension**  
2. Enter name (convention `ZME_<ServiceEntity>`), linked entity `ZC_MyEntity`  
3. The wizard generates the skeleton below

### Syntax skeleton

```abap
@Metadata.layer: #CUSTOMER          "  #CORE | #PARTNER | #CUSTOMER | #INDUSTRY | #LOCALIZATION
@UI.headerInfo: {
  typeName:       'Sales Order',
  typeNamePlural: 'Sales Orders',
  title:          { type: #STANDARD, value: 'SalesOrderID' },
  description:    { type: #STANDARD, value: 'CustomerName' }
}
@UI.presentationVariant: [{ sortOrder: [{ by: 'CreationDate', direction: #DESC }] }]
annotate entity ZC_SalesOrder with
{
  @UI.facet: [
    { id: 'FacetHeader',  type: #COLLECTION,           label: 'General',    position: 10 },
    { id: 'FacetGeneral', type: #IDENTIFICATION_REFERENCE, parentId: 'FacetHeader', label: 'General Data', position: 10 }
  ]

  @UI.lineItem:      [{ position: 10, importance: #HIGH,   label: 'Order ID' }]
  @UI.identification:[{ position: 10 }]
  SalesOrderID;

  @UI.lineItem:      [{ position: 20, importance: #HIGH }]
  @UI.identification:[{ position: 20 }]
  CustomerName;

  @UI.lineItem: [{ position: 30, importance: #MEDIUM, criticality: 'StatusCriticality' }]
  OverallStatus;
}
```

### `@Metadata.layer` priority (highest wins)

`#CUSTOMER` > `#PARTNER` > `#INDUSTRY` > `#LOCALIZATION` > `#CORE`

Customer extensions always use `#CUSTOMER`. SAP ships content at `#CORE`.

---

## 3. `@UI.lineItem` — List Report Columns

Controls which fields appear as columns in a Fiori Elements table.

### Full property reference

| Property | Type | Default | Notes |
|---|---|---|---|
| `position` | Integer | — | Column order (10, 20, 30 …); gaps allow future insertions |
| `importance` | Enum | `#MEDIUM` | `#HIGH` / `#MEDIUM` / `#LOW` — LOW columns hidden on small screens |
| `label` | String | `@EndUserText.label` | Override column header |
| `criticality` | String | — | Path to Integer field (0=none,1=red,2=yellow,3=green,5=info) |
| `criticalityRepresentation` | Enum | `#WITH_ICON` | `#WITHOUT_ICON` suppresses colored icon |
| `type` | Enum | `#STANDARD` | `#FOR_ACTION` renders a button; `#AS_CONTACT`, `#AS_ADDRESS` |
| `dataAction` | String | — | Bound action name (with `type: #FOR_ACTION`) |
| `url` | String | — | Field path providing navigation URL |
| `urlMimeType` | String | — | e.g. `'image/png'` |
| `qualifier` | String | `''` | Named variant; referenced by presentationVariant |
| `hidden` | Boolean / Path | `false` | `true` or path to Boolean field |
| `lineItemHidden` | Boolean | — | Deprecated; use `hidden` |

### Example — mixed criticality and action button

```abap
annotate entity ZC_PurchaseOrder with
{
  @UI.lineItem: [
    { position: 10, importance: #HIGH,   label: 'PO Number' },
    { position: 20, importance: #HIGH }
  ]
  PurchaseOrderID;

  @UI.lineItem: [
    { position: 30, importance: #HIGH,   label: 'Net Amount' },
    { position: 40, type: #FOR_ACTION,   dataAction: 'approvePO',
      label: 'Approve', importance: #HIGH }
  ]
  NetAmount;

  @UI.lineItem: [{ position: 50, criticality: 'ApprovalStatusCriticality',
                   criticalityRepresentation: #WITH_ICON }]
  ApprovalStatus;
}
```

---

## 4. `@UI.headerInfo` — Object Page Header

Defines the title band at the top of an Object Page.

| Property | Sub-property | Meaning |
|---|---|---|
| `typeName` | — | Singular label shown above the title (e.g. `'Purchase Order'`) |
| `typeNamePlural` | — | Used in back-navigation breadcrumb |
| `title` | `value` | Field name (string) whose content becomes the main title |
| `title` | `type` | `#STANDARD` (default) \| `#WITH_UNIT` \| `#WITH_URL` |
| `description` | `value` | Sub-title field |
| `imageUrl` | — | Field path providing an image URL |

```abap
@UI.headerInfo: {
  typeName:       'Travel Request',
  typeNamePlural: 'Travel Requests',
  title:          { type: #STANDARD, value: 'Description' },
  description:    { type: #STANDARD, value: 'AgencyName'  },
  imageUrl:       'AgencyPhotoUrl'
}
annotate entity ZC_Travel with { ... }
```

---

## 5. `@UI.facet` — Object Page Sections

Facets define the section/sub-section layout of an Object Page.

### Facet types

| Type constant | Renders | Requirement |
|---|---|---|
| `#COLLECTION` | Section container | Must have children via `parentId` |
| `#IDENTIFICATION_REFERENCE` | Fields from `@UI.identification` | — |
| `#LINEITEM_REFERENCE` | Embedded table from `@UI.lineItem` | `targetQualifier` for non-default variant |
| `#FIELDGROUP_REFERENCE` | Fields from `@UI.fieldGroup[{qualifier}]` | `targetQualifier` must match |
| `#DATAPOINT_REFERENCE` | Single KPI tile | `targetQualifier` points to `@UI.dataPoint` |

### Complete 2-level facet example

```abap
@UI.facet: [
  { id: 'FacetGeneral',  type: #COLLECTION,              label: 'General Information', position: 10 },
  { id: 'FacetHeader',   type: #IDENTIFICATION_REFERENCE, label: 'Header Data',
    parentId: 'FacetGeneral', position: 10 },
  { id: 'FacetPartner',  type: #FIELDGROUP_REFERENCE,     label: 'Partner',
    parentId: 'FacetGeneral', position: 20,
    targetQualifier: 'PartnerGroup' },
  { id: 'FacetItems',    type: #COLLECTION,               label: 'Items',    position: 20 },
  { id: 'FacetItemLine', type: #LINEITEM_REFERENCE,        label: 'Order Items',
    parentId: 'FacetItems',   position: 10,
    targetElement: '_Items' }
]
annotate entity ZC_SalesOrder with { ... }
```

---

## 6. `@UI.fieldGroup` — Grouped Fields within a Facet

Groups a set of fields under a named qualifier for placement inside a `#FIELDGROUP_REFERENCE` facet.

```abap
annotate entity ZC_SalesOrder with
{
  @UI.fieldGroup: [{ qualifier: 'PartnerGroup', position: 10, label: 'Sold-To Party' }]
  SoldToParty;

  @UI.fieldGroup: [{ qualifier: 'PartnerGroup', position: 20, label: 'Ship-To Party' }]
  ShipToParty;

  @UI.fieldGroup: [{ qualifier: 'PartnerGroup', position: 30 }]
  @UI.lineItem:   [{ position: 40, importance: #LOW }]
  BillingParty;
}
```

> A field can appear in **multiple** `@UI.fieldGroup` entries and in `@UI.lineItem`
> simultaneously by providing an array of annotation records.

---

## 7. `@UI.identification` — Object Page Header Fields

Fields annotated with `@UI.identification` are rendered in the `#IDENTIFICATION_REFERENCE` facet section (the "general" area directly beneath the header).

```abap
annotate entity ZC_Travel with
{
  @UI.identification: [{ position: 10 }]
  TravelID;

  @UI.identification: [{ position: 20, label: 'Agency' }]
  AgencyID;

  @UI.identification: [{ position: 30 }]
  BeginDate;

  @UI.identification: [{ position: 40 }]
  EndDate;
}
```

---

## 8. `@UI.selectionField` — Filter Bar

Exposes fields as filter options in the List Report filter bar.

```abap
annotate entity ZC_Travel with
{
  @UI.selectionField: [{ position: 10 }]
  TravelStatus;

  @UI.selectionField: [{ position: 20 }]
  AgencyID;

  @UI.selectionField: [{ position: 30 }]
  @Consumption.filter.selectionType: #RANGE
  BeginDate;
}
```

`@Consumption.filter.selectionType` values: `#SINGLE` | `#MULTIPLE` | `#RANGE` | `#INTERVAL`

---

## 9. `@Consumption.valueHelpDefinition` — Value Help Binding

Defined on the **projection view** field (not in metadata extension). Links a field to a value help entity.

### Properties

| Property | Purpose |
|---|---|
| `entity.name` | CDS view name providing the value list |
| `entity.element` | Key element in the VH entity that maps to this field |
| `additionalBinding` | Array of `{ localElement, element }` for auto-fill |
| `qualifier` | For multiple VH definitions on the same field |
| `useForValidation` | `true` validates typed values against the VH entity |

### Local text annotation

```abap
// In ZI_Agency (interface view)
@ObjectModel.text.element: ['AgencyName']
AgencyID;

AgencyName;
```

### Projection view value help

```abap
// In ZC_Travel (projection view)
@Consumption.valueHelpDefinition: [{
  entity: { name: 'ZI_Agency', element: 'AgencyID' },
  additionalBinding: [
    { localElement: 'AgencyName', element: 'AgencyName' }
  ],
  useForValidation: true
}]
AgencyID;
```

---

## 10. Side Effects in BDEF

Side effects instruct the framework to re-fetch specific fields or entities after a user
action without requiring a full page reload.

```abap
// In ZBP_SalesOrder.bdef or behavior definition DDL
define behavior for ZC_SalesOrder alias SalesOrder
...
{
  // Changing DeliveryDate should refresh TotalPrice and NetDueDate
  sideEffects for DeliveryDate {
    field TotalPrice;
    field NetDueDate;
  }

  // Executing the action should refresh entire entity and child items
  sideEffects for action recalculatePrices {
    entity;
    navigation _Items { entity; }
  }
}
```

### When are side effects needed?

- A determination runs on field change (`on modify`) and the result must update the UI
- An action modifies fields not in the original request body
- Changing a header field changes a display-only calculated field

---

## 11. Draft Indicators

Draft-enabled apps should show which list rows are currently in draft state.

```abap
// In the projection view, expose DraftAdministrativeData fields
@UI.lineItem: [{ position: 5, type: #AS_DATAPOINT, qualifier: 'DraftAdminIndicator' }]
@UI.dataPoint #DraftAdminIndicator: { value: 'HasDraftEntity', targetValue: 1 }
HasDraftEntity;
```

### Draft node in BDEF

```abap
define behavior for ZC_SalesOrder alias SalesOrder
draft table ZSALESORDER_D
...
{
  // Draft actions are auto-generated
  draft action Edit;
  draft action Activate;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare;
}
```

---

## 12. Chart Annotations

### `@UI.chart`

```abap
@UI.chart: [{
  qualifier:            'SalesChart',
  chartType:            #BAR,
  title:                'Sales by Region',
  description:          'Current year net sales per region',
  dimensions:           ['Region'],
  measures:             ['NetAmount'],
  dimensionAttributes:  [{ dimension: 'Region',    role: #CATEGORY }],
  measureAttributes:    [{ measure:   'NetAmount', role: #AXIS_1, asDataPoint: true }]
}]
annotate entity ZC_SalesKPI with { ... }
```

### `@UI.dataPoint`

```abap
annotate entity ZC_SalesKPI with
{
  @UI.dataPoint: { qualifier: 'NetAmountDP',
                   title: 'Net Amount',
                   value: 'NetAmount',
                   maximumValue: 1000000,
                   criticality: 'AmountCriticality',
                   criticalityCalculation: { improvementDirection: #TARGET,
                                             toleranceRangeLowValue:  95,
                                             toleranceRangeHighValue: 105 } }
  NetAmount;
}
```

---

## 13. Analytical List Page (ALP)

ALP wires `@UI.selectionVariant`, `@UI.presentationVariant`, and `@UI.chart` together.

```abap
@UI.selectionVariant: [{
  qualifier:      'DefaultFilter',
  text:           'Open Orders',
  filterExpression: 'OverallStatus EQ O'
}]

@UI.presentationVariant: [{
  qualifier:       'DefaultPresentation',
  visualizations:  [{ type: #AS_CHART, qualifier: 'SalesChart' },
                    { type: #AS_LINEITEM }],
  sortOrder:       [{ by: 'NetAmount', direction: #DESC }],
  maxItems:        50
}]
annotate entity ZC_SalesKPI with { ... }
```

---

## 14. `@Search` Annotations

```abap
// On the entity level (in projection view or metadata extension)
@Search.searchable: true
annotate entity ZC_Customer with
{
  @Search.defaultSearchElement: true
  @Search.ranking:              #HIGH
  CustomerID;

  @Search.defaultSearchElement: true
  @Search.ranking:              #MEDIUM
  CustomerName;

  @Search.defaultSearchElement: false
  @Search.ranking:              #LOW
  Street;
}
```

Text search across associations requires `@ObjectModel.text.element` in the interface view so the search engine can resolve the readable text.

---

## 15. Key Anti-Patterns

| Anti-pattern | Symptom | Correct approach |
|---|---|---|
| `@UI.lineItem` placed in interface view `ZI_*` | Column shows in service but cannot be overridden | Move ALL `@UI` to metadata extension |
| Missing `@Metadata.layer` | Activation error `CDS_ANNO_001` | Always set `@Metadata.layer: #CUSTOMER` |
| Metadata extension for wrong entity | Annotations ignored silently | Extension `annotate entity` must name the **projection** view, not the interface view |
| Overriding `#CORE` annotation at `#CUSTOMER` layer | Override ignored | Impossible for same qualifier — use a new qualifier or extend via `#CUSTOMER` extension point if offered |
| `@UI.facet` on a child entity without referencing parent | Object page section missing | Add facet on the **root** projection for sub-entity, or on the child view if the sub-page is configured |
| `additionalBinding` in metadata extension | Runtime error | `@Consumption.valueHelpDefinition` must be in the projection view DDL, not in a metadata extension |

---

## 16. Complete Example A — List Report Metadata Extension

```abap
@Metadata.layer: #CUSTOMER
@UI.headerInfo: {
  typeName:       'Purchase Order',
  typeNamePlural: 'Purchase Orders',
  title:          { type: #STANDARD, value: 'PurchaseOrderID' },
  description:    { type: #STANDARD, value: 'SupplierName' }
}
@UI.presentationVariant: [{
  sortOrder: [{ by: 'CreationDate', direction: #DESC }],
  visualizations: [{ type: #AS_LINEITEM }]
}]
annotate entity ZC_PurchaseOrder with
{
  @UI.selectionField: [{ position: 10 }]
  @UI.lineItem:       [{ position: 10, importance: #HIGH, label: 'PO Number' }]
  PurchaseOrderID;

  @UI.selectionField: [{ position: 20 }]
  @UI.lineItem:       [{ position: 20, importance: #HIGH }]
  SupplierID;

  @UI.lineItem: [{ position: 30, importance: #HIGH }]
  SupplierName;

  @UI.selectionField: [{ position: 30 }]
  @UI.lineItem:       [{ position: 40, importance: #MEDIUM }]
  @Consumption.filter.selectionType: #RANGE
  CreationDate;

  @UI.lineItem: [{
    position: 50,
    importance: #HIGH,
    criticality: 'PurchaseOrderStatusCriticality',
    criticalityRepresentation: #WITH_ICON,
    label: 'Status'
  }]
  PurchaseOrderStatus;

  @UI.lineItem: [{ position: 60, importance: #MEDIUM }]
  NetAmount;

  @UI.lineItem: [{
    position: 70,
    type: #FOR_ACTION,
    dataAction: 'approvePurchaseOrder',
    label: 'Approve',
    importance: #HIGH
  }]
  PurchaseOrderID;  " repeated for action button column
}
```

---

## 17. Complete Example B — Object Page with Field Groups

```abap
@Metadata.layer: #CUSTOMER
@UI.headerInfo: {
  typeName:       'Sales Order',
  typeNamePlural: 'Sales Orders',
  title:          { type: #STANDARD, value: 'SalesOrderID' },
  description:    { type: #STANDARD, value: 'CustomerName'  }
}
annotate entity ZC_SalesOrder with
{
  @UI.facet: [
    // --- Section 1: General ---
    { id: 'FacetGeneral',   type: #COLLECTION,              label: 'General',       position: 10 },
    { id: 'FacetBasic',     type: #IDENTIFICATION_REFERENCE, label: 'Basic Data',
      parentId: 'FacetGeneral', position: 10 },
    { id: 'FacetPartner',   type: #FIELDGROUP_REFERENCE,    label: 'Partner Data',
      parentId: 'FacetGeneral', position: 20, targetQualifier: 'PartnerGrp' },
    // --- Section 2: Items ---
    { id: 'FacetItems',     type: #COLLECTION,              label: 'Items',         position: 20 },
    { id: 'FacetItemTable', type: #LINEITEM_REFERENCE,       label: 'Order Items',
      parentId: 'FacetItems',   position: 10, targetElement: '_SalesOrderItems' }
  ]

  @UI.lineItem:      [{ position: 10, importance: #HIGH }]
  @UI.identification:[{ position: 10 }]
  SalesOrderID;

  @UI.lineItem:      [{ position: 20, importance: #HIGH }]
  @UI.identification:[{ position: 20 }]
  CustomerName;

  @UI.identification:[{ position: 30 }]
  @UI.fieldGroup:    [{ qualifier: 'PartnerGrp', position: 10 }]
  SoldToParty;

  @UI.fieldGroup:    [{ qualifier: 'PartnerGrp', position: 20 }]
  ShipToParty;

  @UI.lineItem:      [{ position: 30, importance: #MEDIUM }]
  @UI.identification:[{ position: 40 }]
  NetAmount;

  @UI.lineItem:      [{ position: 40, importance: #LOW }]
  TaxAmount;

  @UI.selectionField:[{ position: 10 }]
  @UI.lineItem:      [{ position: 50, criticality: 'OverallStatusCriticality' }]
  OverallStatus;
}
```

---

## 18. Complete Example C — Value Help Pattern (Projection View)

```abap
// ── ZC_Travel.ddls (Projection View) ──────────────────────────────────────
@EndUserText.label: 'Travel Request'
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
define root projection entity ZC_Travel
  provider contract transactional_ui
  as projection on ZI_Travel
{
  key TravelID,

  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_Agency', element: 'AgencyID' },
    additionalBinding: [
      { localElement: 'AgencyName', element: 'AgencyName' },
      { localElement: 'CurrencyCode', element: 'CurrencyCode' }
    ],
    useForValidation: true
  }]
  AgencyID,

  AgencyName,

  @Consumption.valueHelpDefinition: [{
    entity:   { name: 'ZI_Customer', element: 'CustomerID' },
    additionalBinding: [
      { localElement: 'CustomerName', element: 'FullName' }
    ]
  }]
  CustomerID,

  CustomerName,

  @Consumption.valueHelpDefinition: [{
    entity: { name: '/DMO/I_Flight', element: 'CurrencyCode' }
  }]
  CurrencyCode,

  BeginDate,
  EndDate,
  Description,
  TotalPrice,
  BookingFee,
  TravelStatus,
  TravelStatusCriticality,
  LastChangedAt,

  /* Associations */
  _Booking : redirected to composition child ZC_Booking,
  _Agency,
  _Customer
}
```

---

*End of UI Annotations Catalog*
