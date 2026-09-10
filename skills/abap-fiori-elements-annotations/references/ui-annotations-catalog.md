# Fiori Elements UI Annotations — Complete Catalog

## Objective

Provide the complete reference for all CDS UI annotations used to build Fiori Elements applications (List Report, Object Page, Analytical List Page, Overview Page).

---

## Annotation Placement Rules

| Annotation | Where to Place | Why |
|---|---|---|
| `@UI.headerInfo` | Metadata Extension | UI concern only |
| `@UI.lineItem` | Metadata Extension | Column definition |
| `@UI.facet` | Metadata Extension | Page layout |
| `@UI.selectionField` | Metadata Extension | Filter bar |
| `@UI.fieldGroup` | Metadata Extension | Field grouping |
| `@UI.identification` | Metadata Extension | Object page fields |
| `@UI.dataPoint` | Metadata Extension | KPI/progress |
| `@UI.chart` | Metadata Extension | Analytical chart |
| `@Consumption.valueHelpDefinition` | Projection View | Data binding |
| `@Search.defaultSearchElement` | Interface or Projection | Search behavior |
| `@Semantics.*` | Interface View | Data semantics |

---

## @UI.headerInfo

Controls the page title and description for Object Page.

```cds
@UI.headerInfo: {
  typeName: 'Travel',
  typeNamePlural: 'Travels',
  title: {
    type: #STANDARD,
    value: 'Description'
  },
  description: {
    type: #STANDARD,
    value: 'TravelID'
  },
  imageUrl: 'ImageURL',
  typeImageUrl: 'sap-icon://flight'
}
```

---

## @UI.lineItem (List Report Columns)

```cds
// Basic column
@UI.lineItem: [{ position: 10, importance: #HIGH }]
TravelID;

// Column with criticality (color coding)
@UI.lineItem: [{ position: 20, importance: #HIGH, criticality: 'StatusCriticality' }]
Status;

// Column as data point (shows as micro chart or progress)
@UI.lineItem: [{ position: 30, type: #AS_DATAPOINT }]
TotalPrice;

// Column with navigation (link to Object Page)
@UI.lineItem: [{ position: 40, type: #WITH_INTENT_BASED_NAVIGATION,
                  semanticObjectAction: 'display' }]
AgencyID;

// Action button in table toolbar
@UI.lineItem: [{ position: 50, type: #FOR_ACTION, dataAction: 'AcceptTravel',
                  label: 'Accept', invocationGrouping: #CHANGE_SET }]
TravelID;

// Hidden column (available for personalization but not shown by default)
@UI.lineItem: [{ position: 60, importance: #LOW, hidden: true }]
InternalNote;
```

### Importance Levels
| Level | Behavior |
|---|---|
| `#HIGH` | Always visible |
| `#MEDIUM` | Visible on medium+ screens |
| `#LOW` | Hidden by default, available in personalization |

---

## @UI.facet (Object Page Layout)

```cds
@UI.facet: [
  // Section with field groups
  {
    id: 'GeneralInfo',
    purpose: #STANDARD,
    type: #IDENTIFICATION_REFERENCE,
    label: 'General Information',
    position: 10
  },
  // Section with custom field group
  {
    id: 'DatesSection',
    purpose: #STANDARD,
    type: #FIELDGROUP_REFERENCE,
    label: 'Travel Dates',
    targetQualifier: 'Dates',
    position: 20
  },
  // Table of child entities
  {
    id: 'BookingTable',
    purpose: #STANDARD,
    type: #LINEITEM_REFERENCE,
    label: 'Bookings',
    position: 30,
    targetElement: '_Booking'
  },
  // Header facet (appears in header area)
  {
    id: 'HeaderPrice',
    purpose: #HEADER,
    type: #DATAPOINT_REFERENCE,
    targetQualifier: 'TotalPrice',
    position: 10
  },
  // Collection facet (groups sub-facets)
  {
    id: 'AdminData',
    purpose: #STANDARD,
    type: #COLLECTION,
    label: 'Administration',
    position: 40
  },
  {
    id: 'AuditFields',
    parentId: 'AdminData',
    purpose: #STANDARD,
    type: #FIELDGROUP_REFERENCE,
    label: 'Audit Trail',
    targetQualifier: 'Audit',
    position: 10
  }
]
```

### Facet Types
| Type | Usage |
|---|---|
| `#IDENTIFICATION_REFERENCE` | Shows `@UI.identification` fields |
| `#FIELDGROUP_REFERENCE` | Shows `@UI.fieldGroup` with matching qualifier |
| `#LINEITEM_REFERENCE` | Shows child entity table |
| `#DATAPOINT_REFERENCE` | Shows KPI/progress indicator |
| `#CHART_REFERENCE` | Shows embedded chart |
| `#COLLECTION` | Groups sub-facets under one tab |
| `#CONTACT_REFERENCE` | Shows contact card |
| `#ADDRESS_REFERENCE` | Shows address card |

---

## @UI.selectionField (Filter Bar)

```cds
@UI.selectionField: [{ position: 10 }]
AgencyID;

@UI.selectionField: [{ position: 20 }]
Status;

@UI.selectionField: [{ position: 30 }]
BeginDate;

// Hidden filter (default value set, user can't change)
@UI.selectionField: [{ position: 40 }]
@UI.hidden: true
CompanyCode;
```

---

## @UI.fieldGroup (Grouped Fields on Object Page)

```cds
@UI.fieldGroup: [{ qualifier: 'Dates', position: 10, label: 'Start Date' }]
BeginDate;

@UI.fieldGroup: [{ qualifier: 'Dates', position: 20, label: 'End Date' }]
EndDate;

@UI.fieldGroup: [{ qualifier: 'Pricing', position: 10 }]
TotalPrice;

@UI.fieldGroup: [{ qualifier: 'Pricing', position: 20 }]
CurrencyCode;

@UI.fieldGroup: [{ qualifier: 'Audit', position: 10, label: 'Created By' }]
CreatedBy;

@UI.fieldGroup: [{ qualifier: 'Audit', position: 20, label: 'Created On' }]
CreatedAt;
```

---

## @UI.identification (Object Page General Section)

```cds
@UI.identification: [{ position: 10 }]
TravelID;

@UI.identification: [{ position: 20 }]
Description;

@UI.identification: [{ position: 30 }]
AgencyID;

// Action button on Object Page
@UI.identification: [{ position: 40, type: #FOR_ACTION, dataAction: 'AcceptTravel', label: 'Accept' }]
TravelID;
```

---

## @UI.dataPoint (KPI/Progress/Rating)

```cds
// Simple value display
@UI.dataPoint: {
  qualifier: 'TotalPrice',
  title: 'Total Price',
  criticality: 'PriceCriticality'
}
TotalPrice;

// Progress indicator
@UI.dataPoint: {
  qualifier: 'Progress',
  title: 'Completion',
  visualization: #PROGRESS,
  targetValue: 100
}
CompletionPercent;

// Rating indicator
@UI.dataPoint: {
  qualifier: 'Rating',
  title: 'Customer Rating',
  visualization: #RATING,
  targetValue: 5
}
CustomerRating;
```

---

## @UI.chart (Analytical)

```cds
@UI.chart: [{
  qualifier: 'RevenueByAgency',
  chartType: #BAR,
  dimensions: ['AgencyID'],
  measures: ['TotalRevenue'],
  title: 'Revenue by Agency'
}]

@UI.chart: [{
  qualifier: 'TravelTrend',
  chartType: #LINE,
  dimensions: ['Month'],
  measures: ['TravelCount'],
  title: 'Monthly Travel Count'
}]
```

### Chart Types
`#BAR`, `#COLUMN`, `#LINE`, `#PIE`, `#DONUT`, `#SCATTER`, `#BUBBLE`, `#HEATMAP`, `#WATERFALL`

---

## @Consumption.valueHelpDefinition

```cds
// Simple value help
@Consumption.valueHelpDefinition: [{
  entity: { name: 'ZI_Agency', element: 'AgencyID' }
}]
AgencyID;

// With additional bindings (auto-fill related fields)
@Consumption.valueHelpDefinition: [{
  entity: { name: 'ZI_Agency', element: 'AgencyID' },
  additionalBinding: [
    { localElement: 'AgencyName', element: 'Name', usage: #RESULT },
    { localElement: 'AgencyCity', element: 'City', usage: #RESULT }
  ]
}]
AgencyID;

// With filter (restrict value help results)
@Consumption.valueHelpDefinition: [{
  entity: { name: 'ZI_Airport', element: 'AirportID' },
  additionalBinding: [
    { localElement: 'Country', element: 'CountryCode', usage: #FILTER }
  ]
}]
DepartureAirport;
```

---

## @Search Annotations

```cds
// Enable fuzzy search on this field
@Search.defaultSearchElement: true
@Search.fuzzinessThreshold: 0.8
Description;

// Ranking (higher = more relevant in results)
@Search.defaultSearchElement: true
@Search.ranking: #HIGH
TravelID;

@Search.defaultSearchElement: true
@Search.ranking: #MEDIUM
CustomerName;
```

---

## Side Effects (BDEF Syntax)

```
define behavior for ZI_Travel alias Travel
{
  side effects {
    // When Amount changes, refresh TotalPrice field
    field Amount affects field TotalPrice;

    // When action runs, refresh entity
    action RecalculatePrice affects field TotalPrice, field Status;

    // When field changes, refresh child table
    field Status affects entity _Booking;

    // Determine action: refresh field after determination runs
    determine action SetDefaults executed on field AgencyID affects field AgencyName;
  }
}
```

---

## Draft Indicators

```cds
// In metadata extension:
@UI.lineItem: [{ position: 99, type: #AS_DRAFT_INDICATOR }]
HasDraftEntity;
```

---

## Complete Metadata Extension Example

```cds
@Metadata.layer: #CUSTOMER
annotate entity ZC_Travel with
{
  @UI.headerInfo: {
    typeName: 'Travel',
    typeNamePlural: 'Travels',
    title: { type: #STANDARD, value: 'Description' },
    description: { type: #STANDARD, value: 'TravelID' }
  }

  @UI.facet: [
    { id: 'General', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'General', position: 10 },
    { id: 'Dates', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, label: 'Dates', targetQualifier: 'Dates', position: 20 },
    { id: 'Bookings', purpose: #STANDARD, type: #LINEITEM_REFERENCE, label: 'Bookings', position: 30, targetElement: '_Booking' },
    { id: 'HeaderPrice', purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'Price', position: 10 }
  ]

  @UI.lineItem: [{ position: 10, importance: #HIGH }]
  @UI.identification: [{ position: 10 }]
  TravelID;

  @UI.lineItem: [{ position: 20, importance: #HIGH }]
  @UI.identification: [{ position: 20 }]
  @UI.selectionField: [{ position: 10 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_Agency', element: 'AgencyID' } }]
  AgencyID;

  @UI.lineItem: [{ position: 30, importance: #MEDIUM }]
  @UI.identification: [{ position: 30 }]
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_Customer', element: 'CustomerID' } }]
  CustomerID;

  @UI.lineItem: [{ position: 40, importance: #HIGH, criticality: 'StatusCriticality' }]
  @UI.selectionField: [{ position: 20 }]
  Status;

  @UI.lineItem: [{ position: 50, type: #AS_DATAPOINT }]
  @UI.dataPoint: { qualifier: 'Price', title: 'Total Price' }
  TotalPrice;

  @UI.fieldGroup: [{ qualifier: 'Dates', position: 10 }]
  BeginDate;

  @UI.fieldGroup: [{ qualifier: 'Dates', position: 20 }]
  EndDate;

  @UI.lineItem: [{ position: 90, type: #FOR_ACTION, dataAction: 'AcceptTravel', label: 'Accept' }]
  @UI.identification: [{ position: 90, type: #FOR_ACTION, dataAction: 'AcceptTravel', label: 'Accept' }]
  TravelID;
}
```

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
