# CDS Data Modeling — Complete Syntax Reference

## Objective

Provide complete DDL syntax for every CDS entity type, association/composition pattern, and annotation category used in ABAP Cloud development.

---

## CDS View Entity (Standard)

```sql
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Travel Interface View'
define view entity ZI_Travel
  as select from ztravel as Travel

  association [1..1] to ZI_Agency   as _Agency   on $projection.AgencyID = _Agency.AgencyID
  association [0..1] to ZI_Customer as _Customer on $projection.CustomerID = _Customer.CustomerID
  composition [0..*] of ZI_Booking  as _Booking

{
  key Travel.travel_id    as TravelID,
      Travel.agency_id    as AgencyID,
      Travel.customer_id  as CustomerID,
      Travel.begin_date   as BeginDate,
      Travel.end_date     as EndDate,
      Travel.description  as Description,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Travel.total_price  as TotalPrice,

      @Semantics.currencyCode: true
      Travel.currency_code as CurrencyCode,

      Travel.status        as Status,

      // Calculated field (CDS expression)
      case Status
        when 'A' then 3  // positive
        when 'X' then 1  // negative
        else 0           // neutral
      end                as StatusCriticality,

      // Admin fields
      @Semantics.user.createdBy: true
      Travel.created_by   as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      Travel.created_at   as CreatedAt,
      @Semantics.user.lastChangedBy: true
      Travel.changed_by   as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      Travel.changed_at   as LocalLastChangedAt,

      // Associations (exposed for navigation)
      _Agency,
      _Customer,
      _Booking
}
```

---

## CDS Projection View

```sql
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Travel Projection for UI'
@Metadata.allowExtensions: true
define view entity ZC_Travel
  as projection on ZI_Travel

{
  key TravelID,
      AgencyID,
      CustomerID,
      BeginDate,
      EndDate,
      Description,
      TotalPrice,
      CurrencyCode,
      Status,
      StatusCriticality,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      LocalLastChangedAt,

      // Redirect associations for projection
      _Agency   : redirected to ZC_Agency,
      _Customer : redirected to ZC_Customer,
      _Booking  : redirected to composition child ZC_Booking
}
```

---

## Abstract Entity (Action/Event Parameters)

```sql
@EndUserText.label: 'Travel Created Event Payload'
define abstract entity ZD_TravelCreatedPayload
{
  TravelID  : travel_id;
  AgencyID  : agency_id;
  Amount    : amount;
  Currency  : currency_code;
}
```

**Use for:**
- RAP action parameters (`action Approve parameter ZD_ApproveParams`)
- RAP event payloads (`event Created parameter ZD_TravelCreatedPayload`)
- Function import parameters

---

## Custom Entity (Code-Based Data Provider)

```sql
@EndUserText.label: 'External Flight Data'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_FLIGHT_QUERY'
define custom entity ZCE_Flight
{
  key FlightID    : abap.char(10);
      Airline     : abap.char(20);
      Destination : abap.char(40);
      Price       : abap.dec(15,2);
      Currency    : abap.cuky;
}
```

Implementation class must implement `IF_RAP_QUERY_PROVIDER`:
```abap
CLASS zcl_flight_query DEFINITION FINAL
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.

CLASS zcl_flight_query IMPLEMENTATION.
  METHOD if_rap_query_provider~select.
    " Fetch from external API or compute
    DATA(lt_flights) = get_flights_from_api( ).
    io_response->set_total_number_of_records( lines( lt_flights ) ).
    io_response->set_data( lt_flights ).
  ENDMETHOD.
ENDCLASS.
```

---

## CDS Table Function (AMDP-Backed)

```sql
define table function ZTF_TravelRanked
  with parameters @Environment.systemField: #CLIENT
                  p_client : abap.clnt,
                  p_agency : agency_id
  returns {
    client    : abap.clnt;
    travel_id : travel_id;
    amount    : amount;
    rank      : abap.int4;
  }
  implemented by method zcl_travel_amdp=>get_ranked_tf;
```

---

## CDS Hierarchy

```sql
define hierarchy ZH_OrgUnit
  as parent child hierarchy(
    source ZI_OrgUnit
    child to parent association _ParentOrg
    start where ParentOrgID is initial
    siblings order by SortOrder
  )
{
  key OrgUnitID,
      ParentOrgID,
      OrgName,
      $node.hierarchy_level as Level,
      $node.hierarchy_rank  as Rank
}
```

---

## Association Patterns

### Simple 1:1 Lookup
```sql
association [1..1] to ZI_Agency as _Agency
  on $projection.AgencyID = _Agency.AgencyID
```

### Optional 0..1
```sql
association [0..1] to ZI_Customer as _Customer
  on $projection.CustomerID = _Customer.CustomerID
```

### 1:N Children (Independent)
```sql
association [0..*] to ZI_Review as _Reviews
  on $projection.TravelID = _Reviews.TravelID
```

### Composition (Parent-Child Lifecycle)
```sql
// In parent:
composition [0..*] of ZI_Booking as _Booking

// In child:
association to parent ZI_Travel as _Travel
  on $projection.TravelID = _Travel.TravelID
```

---

## Composition vs Association Decision

| Question | Answer → Use |
|---|---|
| Does child exist without parent? | YES → Association |
| Should child be deleted with parent? | YES → Composition |
| Should child share parent's draft? | YES → Composition |
| Should child share parent's lock? | YES → Composition |
| Is it a lookup/reference? | YES → Association |

---

## CDS Access Control (DCL)

```sql
@EndUserText.label: 'Travel Access Control'
@MappingRole: true
define role ZR_Travel {
  grant select on ZI_Travel
    where ( AgencyID ) = aspect pfcg_auth( Z_AGENCY, ZAGENCY, ACTVT = '03' )
      and ( Status ) = aspect pfcg_auth( Z_TRAVEL, ZSTATUS, ACTVT = '03' );
}
```

---

## Metadata Extension

```sql
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
    { id: 'General', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'General Info', position: 10 },
    { id: 'Dates', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, label: 'Dates', targetQualifier: 'Dates', position: 20 },
    { id: 'Bookings', purpose: #STANDARD, type: #LINEITEM_REFERENCE, label: 'Bookings', position: 30, targetElement: '_Booking' }
  ]

  @UI.lineItem: [{ position: 10, importance: #HIGH }]
  @UI.identification: [{ position: 10 }]
  TravelID;

  @UI.lineItem: [{ position: 20, importance: #HIGH }]
  @UI.selectionField: [{ position: 10 }]
  AgencyID;

  @UI.lineItem: [{ position: 30, importance: #MEDIUM, criticality: 'StatusCriticality' }]
  @UI.selectionField: [{ position: 20 }]
  Status;

  @UI.lineItem: [{ position: 40, type: #AS_DATAPOINT }]
  @UI.dataPoint: { qualifier: 'TotalPrice', title: 'Total Price' }
  TotalPrice;

  @UI.fieldGroup: [{ qualifier: 'Dates', position: 10 }]
  BeginDate;

  @UI.fieldGroup: [{ qualifier: 'Dates', position: 20 }]
  EndDate;
}
```

---

## CDS View Extension

```sql
extend view entity ZI_Travel with
{
  // Add custom fields from extension table
  Travel.zcustom_field as CustomField,

  // Add new association
  association [0..1] to ZI_CustomRef as _CustomRef
    on $projection.CustomField = _CustomRef.RefID
}
```

---

## Key Annotations Catalog

| Annotation | Layer | Purpose |
|---|---|---|
| `@AccessControl.authorizationCheck: #CHECK` | Interface | Enforce DCL |
| `@Metadata.allowExtensions: true` | Projection | Allow ME |
| `@ObjectModel.representativeKey` | Interface | Value help key |
| `@Semantics.amount.currencyCode` | Interface | Currency binding |
| `@Semantics.quantity.unitOfMeasure` | Interface | Unit binding |
| `@Semantics.user.createdBy` | Interface | Audit: who created |
| `@Semantics.systemDateTime.createdAt` | Interface | Audit: when created |
| `@Search.defaultSearchElement: true` | Interface | Enable fuzzy search |
| `@Consumption.valueHelpDefinition` | Projection | VH binding |
| `@Analytics.dataCategory: #CUBE` | Interface | Analytical model |
| `@Analytics.dataCategory: #DIMENSION` | Interface | Master data dimension |
| `@ObjectModel.usageType.serviceQuality: #A` | Interface | Performance hint |

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
