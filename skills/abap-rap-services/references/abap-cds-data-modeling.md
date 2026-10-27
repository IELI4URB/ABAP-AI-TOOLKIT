---
name: abap-cds-data-modeling
description: 'Design and review CDS data models for SAP ABAP Cloud. Use for view entities, projection views, abstract or custom entities, table entities, hierarchies, associations, compositions, DCL, metadata extensions, CDS annotations, IF_RAP_QUERY_PROVIDER, entity extensions, and DEFINE VIEW ENTITY syntax.'
metadata:
  version: 2.0.0
  tags: abap cds data-modeling view-entity projection custom-entity annotations dcl abap-cloud
---

# ABAP Cloud CDS Data Modeling

SAP Help baseline: https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models

Use this skill as the CDS structure and entity-selection router. The complete CDS syntax reference is inlined below.

## Ownership

This skill owns CDS entity selection, layering, keys, associations, compositions, structural annotations, custom entities, and DCL syntax. Use [the official annotation guide](./official-cds-annotations.md) for annotation scope, values, metadata extensions, propagation, and API properties; use `abap-fiori-elements-annotations` for UI/value-help/text presentation, `abap-iam-authorization` for authorization architecture, `abap-sql-and-amdp` for table-function implementation, and `abap-platform-2025` for 2025-only capabilities.

## Workflow

1. Establish landscape, exact release/FPS, transactional or analytical purpose, ownership, volume, and consumers.
2. Inspect source contracts: keys, types, lengths, decimals, units/currencies, nullability, authorization, and release state.
3. Select the entity type and layer before choosing annotations or behavior.
4. Read only the matching reference sections below.
5. Define cardinalities, ON conditions, lifecycle ownership, redirections, provider contracts, and extension boundaries.
6. Validate activation, SQL result semantics, authorization, generated OData metadata, paging, and large-volume behavior.

## Reference Routing

| Request | Read sections in `cds-complete-syntax.md` |
|---|---|
| Entity selection | 1 |
| View entity | 2 |
| Projection view | 3 |
| Abstract entity | 4 |
| Custom entity/query provider | 5 |
| Table entity | 6, plus `abap-platform-2025` |
| Association or composition | 7, 8 |
| DCL | 9, 11 |
| Annotation lookup | 10, then [official annotation semantics](./official-cds-annotations.md) |

## Mandatory Gates

- Separate reusable interface models, consumption projections, behavior, and UI metadata by responsibility.
- Verify keys, cardinalities, association exposure, composition ownership, type compatibility, and projection redirection.
- Do not recommend extension of an SAP provider without verified C1 release and explicit extensibility.
- Check N+1 effects, pushdown, filters, paging, memory, and result size for every exposed model.
- Verify CDS DDL/DCL and annotation syntax for the exact release; report `Syntax confidence: verified` or block production use.
- Release guidance must include activation, ATC/readiness, unit/integration and metadata tests, rollback, and operational evidence.

## Response Shape

For non-trivial requests, state landscape and consumers, selected entity/layer, object contracts, relationships and authorization, performance constraints, test evidence, and unresolved release assumptions.


## CDS Data Modeling — Complete Syntax Reference

> **Audience:** ABAP Cloud developers building RAP-based services on BTP ABAP Environment or S/4HANA 2023+.  
> **Scope:** DDL syntax, view entity types, projection views, custom entities, DCL roles, annotation quick-reference.

---

### 1. Entity Type Selection Matrix

Choose the right CDS artifact for each scenario:

| Artifact | DDL Keyword | DB Table | Can be Root? | Typical Use Case |
|---|---|---|---|---|
| **View Entity** | `define view entity` | ✅ Yes (via `as select from`) | ✅ Yes | Standard BO interface / read layer |
| **Projection View** | `define [root] projection entity` | ❌ No (projects from view entity) | ✅ Yes (root) | OData service exposure, value help |
| **Abstract Entity** | `define abstract entity` | ❌ No | ❌ No | Action/function parameter typing |
| **Custom Entity** | `define [root] custom entity` | ❌ No (runtime class provides data) | ✅ Yes | External API data, complex logic, no DDIC table |
| **Table Function** | `define view entity … as select from … call …` | ❌ No | ❌ No | AMDP-backed read (BTP: restricted) |
| **Table Entity** *(2025 GA)* | `define table entity` | ✅ Replaces DDIC table | ✅ Yes | Pure CDS-based persistence for managed RAP |
| **CDS Hierarchy** | `define hierarchy` | ❌ No | ❌ No | Parent-child tree flattening (GL accounts, org units) |
| **DCL Role** | `define role` | ❌ No | ❌ No | Row-level access control (PFCG / aspect) |

---

### 2. `DEFINE VIEW ENTITY` — Full Syntax

#### Annotation header (mandatory fields)

```abap
@AbapCatalog.viewEnhancementCategory: [#NONE]
  // #NONE | [#PROJECTION_LIST] | [#UNION] — controls extensibility

@AccessControl.authorizationCheck: #CHECK
  // #CHECK (default) | #NOT_REQUIRED | #NOT_ALLOWED | #PRIVILEGED_ONLY

@EndUserText.label: 'My Entity Label'     // Shown in Data Browser, max 60 chars

@Metadata.ignorePropagatedAnnotations: false
  // true = suppress inherited annotations from base view

@ObjectModel.usageType: {
  serviceQuality: #X,          // #A | #B | #C | #P | #S | #X
  sizeCategory:   #M,          // #XS | #S | #M | #L | #XL | #XXL
  dataClass:      #MIXED       // #TRANSACTIONAL | #MASTER | #CUSTOMIZING | #MIXED
}
```

#### Complete view entity with join and association

```abap
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Sales Order Interface View'
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_SalesOrder
  as select from zsalesorder as so

  // Inner join
  inner join   zcustomer       as cust  on so.customer_id = cust.customer_id

  // Left outer join
  left outer join zcurr_config as curr  on so.currency_code = curr.currency_code

  // Association (lazy — only fetched when $expand or path navigation used)
  association [0..*] to ZI_SalesOrderItem as _Items
    on $projection.SalesOrderID = _Items.SalesOrderID

  association [0..1] to ZI_Customer       as _Customer
    on $projection.CustomerID  = _Customer.CustomerID

{
  key so.sales_order_id                     as SalesOrderID,
  key so.item_number                        as ItemNumber,      // for non-unique root: omit key on second field

      so.customer_id                        as CustomerID,
      cust.customer_name                    as CustomerName,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      so.net_amount                         as NetAmount,

      @Semantics.currencyCode: true
      so.currency_code                      as CurrencyCode,

      @Semantics.systemDate.createdAt: true
      so.created_at                         as CreationDate,

      @Semantics.user.createdBy: true
      so.created_by                         as CreatedBy,

      // Calculated field
      case so.overall_status
        when 'O' then 3    // green
        when 'X' then 1    // red
        else          2    // yellow
      end                                   as OverallStatusCriticality,

      so.overall_status                     as OverallStatus,

      // Type cast
      cast( so.legacy_amount as abap.dec(15,2) preserving type )
                                            as LegacyAmount,

      // Expose association — MANDATORY for use in projection
      _Items,
      _Customer
}
```

#### Key rules

- `key` fields must uniquely identify each row; multiple `key` fields form a compound key
- Non-key fields use camelCase aliases matching DDIC element names where possible
- Associations must be **listed in the SELECT clause** (just the name, no alias) to be available downstream
- `$projection.<FieldName>` is required in ON conditions referencing the current view's fields

---

### 3. Projection View — Full Syntax

The projection view is the **OData-facing** layer. It never adds logic — it redirects associations and configures contracts.

#### Provider contracts

| Contract | Use case |
|---|---|
| `transactional_ui` | Standard RAP UI — List Report / Object Page (OData V4) |
| `transactional_query` | Read-only OData V4 API |
| `odata_v4_ui` | Alias for `transactional_ui` (pre-2022 naming) |
| `analytical_query` | Analytical List Page / embedded analytics |

#### Root projection with redirected associations

```abap
@EndUserText.label: 'Sales Order Projection'
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true  // Required to attach metadata extensions

define root projection entity ZC_SalesOrder
  provider contract transactional_ui
  as projection on ZI_SalesOrder
{
  key SalesOrderID,
      CustomerID,

      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_Customer', element: 'CustomerID' },
        additionalBinding: [{ localElement: 'CustomerName', element: 'CustomerName' }]
      }]
      CustomerID,

      CustomerName,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      NetAmount,
      CurrencyCode,
      CreationDate,
      CreatedBy,
      OverallStatus,
      OverallStatusCriticality,

      // Redirect child association to child projection view
      _Items    : redirected to composition child ZC_SalesOrderItem,
      _Customer : redirected to ZC_Customer
}
```

#### Child projection (no `root`, no `provider contract`)

```abap
@EndUserText.label: 'Sales Order Item Projection'
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
define projection entity ZC_SalesOrderItem
  as projection on ZI_SalesOrderItem
{
  key SalesOrderID,
  key ItemNumber,
      ProductID,
      Quantity,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      NetAmount,
      CurrencyCode,

      // Back-link to parent
      _SalesOrder : redirected to parent ZC_SalesOrder
}
```

---

### 4. Abstract Entity — Action Parameter Typing

Abstract entities have no SELECT — they are pure type definitions used in BDEF action parameters.

```abap
@EndUserText.label: 'Input for Mass Approval'
define abstract entity ZA_MassApprovalInput
{
  Reason         : abap.char(255);
  EffectiveDate  : abap.dats;
  NotifyEmail    : abap.char(241);
  SimulationMode : abap_boolean;
}
```

#### BDEF usage

```abap
define behavior for ZC_PurchaseOrder alias PO
{
  action massApprove parameter ZA_MassApprovalInput
                     result    [0..*] $self;
}
```

---

### 5. Custom Entity — Full Detail

Custom entities surface **any data** (external REST APIs, complex ABAP logic, aggregated queries) as an OData V4 entity without a DDIC table.

#### Critical constraints

| Constraint | Detail |
|---|---|
| No metadata extensions | ALL annotations (including `@UI`) must be inline in the DDL |
| No DDIC-backed associations | Associations to real view entities only work if your query class resolves them |
| CRUD not supported via BDEF | Only `action` and `static action` are allowed |
| `@ObjectModel.query.implementedBy` mandatory | Must point to an existing class |

#### DDL Syntax

```abap
@EndUserText.label: 'External Product Catalog'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CE_PRODUCT_QUERY'

// UI annotations MUST be inline — no metadata extensions
@UI.headerInfo: {
  typeName:       'Product',
  typeNamePlural: 'Products',
  title:          { type: #STANDARD, value: 'ProductID' }
}
define root custom entity ZCE_ExternalProduct
{
  @UI.lineItem:      [{ position: 10, importance: #HIGH }]
  @UI.identification:[{ position: 10 }]
  key ProductID     : abap.char(40);

  @UI.lineItem:      [{ position: 20, importance: #HIGH }]
  @UI.selectionField:[{ position: 10 }]
  ProductName       : abap.char(255);

  @UI.lineItem:      [{ position: 30 }]
  @UI.selectionField:[{ position: 20 }]
  Category          : abap.char(60);

  @Semantics.amount.currencyCode: 'Currency'
  @UI.lineItem:      [{ position: 40 }]
  ListPrice         : abap.dec(15,2);

  @Semantics.currencyCode: true
  Currency          : abap.cuky;

  @UI.lineItem:      [{ position: 50 }]
  StockLevel        : abap.int4;
}
```

#### Query Implementation Class

```abap
CLASS zcl_ce_product_query DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.

CLASS zcl_ce_product_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    " ── 1. Read filter conditions ──────────────────────────────────────
    DATA(lt_filter_ranges) = io_request->get_filter( )->get_as_ranges( ).

    DATA lv_product_name TYPE string.
    DATA lv_category     TYPE string.

    LOOP AT lt_filter_ranges INTO DATA(ls_range_set).
      CASE ls_range_set-name
        WHEN 'PRODUCTNAME'.
          READ TABLE ls_range_set-range INTO DATA(ls_name_range) INDEX 1.
          IF sy-subrc = 0. lv_product_name = ls_name_range-low. ENDIF.
        WHEN 'CATEGORY'.
          READ TABLE ls_range_set-range INTO DATA(ls_cat_range) INDEX 1.
          IF sy-subrc = 0. lv_category = ls_cat_range-low. ENDIF.
      ENDCASE.
    ENDLOOP.

    " ── 2. Read requested fields (projection push-down) ─────────────
    DATA(lt_requested) = io_request->get_requested_elements( ).

    " ── 3. Paging ────────────────────────────────────────────────────
    DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).
    " IF_RAP_QUERY_PAGING~ALL_INSTANCES = 0 means fetch all
    IF lv_page_size = if_rap_query_paging=>all_instances.
      lv_page_size = 200.   " safety cap
    ENDIF.

    " ── 4. Fetch data from external source ───────────────────────────
    DATA lt_result TYPE STANDARD TABLE OF zce_externalproduct WITH DEFAULT KEY.

    " ... call external API / aggregation logic here ...
    " Example: stub with ABAP internal data
    lt_result = VALUE #(
      ( productid = 'P001' productname = 'Widget A' category = 'Hardware'
        listprice = '9.99' currency = 'EUR' stocklevel = 100 )
      ( productid = 'P002' productname = 'Widget B' category = 'Software'
        listprice = '49.99' currency = 'EUR' stocklevel = 50  )
    ).

    " ── 5. Apply filter (simple demo) ────────────────────────────────
    IF lv_category IS NOT INITIAL.
      DELETE lt_result WHERE category <> lv_category.
    ENDIF.

    DATA(lv_total) = lines( lt_result ).

    " ── 6. Apply paging ──────────────────────────────────────────────
    IF lv_offset > 0.
      DELETE lt_result TO lv_offset.
    ENDIF.
    IF lv_page_size > 0 AND lines( lt_result ) > lv_page_size.
      DELETE lt_result FROM lv_page_size + 1.
    ENDIF.

    " ── 7. Return data and total count ───────────────────────────────
    io_response->set_total_number_of_records( lv_total ).
    io_response->set_data( lt_result ).

  ENDMETHOD.
ENDCLASS.
```

#### BDEF for Custom Entity (actions only)

```abap
// ZBP_ExternalProduct.bdef
define behavior for ZCE_ExternalProduct alias ExProduct
  implementation in class zbp_ce_external_product unique
  unmanaged
{
  // Only actions are valid on custom entities — NO create/update/delete
  static action fetchLatestPrices result [0..*] $self;
  action        reorderProduct    parameter ZA_ReorderInput
                                  result    [1] $self;
}
```

> **Remember:** `create`, `update`, `delete`, `draft`, and `lock` are **not permitted** in a custom entity BDEF. Attempting to add them causes activation error `BDEF_CE_001`.

---

### 6. Table Entity (2025 GA)

Table entities replace DDIC transparent tables as the persistence layer in a pure CDS managed RAP scenario. They are activated as database tables but defined entirely in CDS DDL.

```abap
@EndUserText.label:            'Sales Order Table Entity'
@AbapCatalog.enhancement.category: #NOT_EXTENSIBLE
@AccessControl.authorizationCheck:  #NOT_REQUIRED
@AbapCatalog.tableEntity.deliveryClass:  #A    // #A | #C | #E | #G | #L | #S | #W
@AbapCatalog.tableEntity.dataMaintenance: #RESTRICTED
define table entity ZSALESORDER_TE
{
  key client      : abap.clnt not null;
  key so_id       : abap.char(10) not null;
      customer_id : abap.char(10);
      net_amount  : abap.dec(15,2);
      currency    : abap.cuky;
      status      : abap.char(1);
      created_at  : abap.utclong;
      created_by  : abap.char(12);
      changed_at  : abap.utclong;
      changed_by  : abap.char(12);
}
```

#### BDEF managed persistence reference

```abap
define behavior for ZI_SalesOrder
  persistent table ZSALESORDER_TE
  lock master
  ...
```

---

### 7. Association Syntax

#### Cardinality

| Notation | Meaning |
|---|---|
| `[1]` | Exactly one — join will fail if target row missing |
| `[0..1]` | Zero or one — standard for header lookups |
| `[0..*]` | Zero or many — standard for child/item entities |
| `[1..*]` | One or many — rarely used |

#### ON condition patterns

```abap
// Simple equality
association [0..1] to ZI_Customer as _Customer
  on $projection.CustomerID = _Customer.CustomerID

// Compound key
association [0..*] to ZI_SalesOrderItem as _Items
  on  $projection.SalesOrderID = _Items.SalesOrderID
  and $projection.CompanyCode  = _Items.CompanyCode

// Association to a parameter entity via session variable
association [0..1] to I_Language as _Language
  on _Language.Language = $session.system_language

// Published association (to be used in SELECT)
association [0..1] to ZI_BusinessPartner as _BP
  on $projection.BPID = _BP.BusinessPartnerID
```

#### Naming convention

Always prefix association names with `_` (underscore): `_Items`, `_Customer`, `_Status`.  
This distinguishes them from field aliases in the SELECT clause.

---

### 8. Composition Syntax

Compositions define the **parent–child lifecycle**. Child rows cannot exist without the parent.

```abap
define view entity ZI_SalesOrder
  ...
  composition [0..*] of ZI_SalesOrderItem as _Items
  composition [0..*] of ZI_SalesOrderNote as _Notes
{
  key SalesOrderID,
  ...
  _Items,
  _Notes
}

// Child back-link (mandatory for RAP)
define view entity ZI_SalesOrderItem
  ...
  association to parent ZI_SalesOrder as _SalesOrder
    on $projection.SalesOrderID = _SalesOrder.SalesOrderID
{
  key SalesOrderID,
  key ItemNumber,
  ...
  _SalesOrder
}
```

#### Delete cascade behavior (BDEF)

```abap
define behavior for ZI_SalesOrder alias Header { ...
  delete;
}
define behavior for ZI_SalesOrderItem alias Item {
  delete ( features : instance );
}
```

Child rows are automatically deleted when the parent is deleted if the `delete` statement
is present on the child node.

---

### 9. CDS Role (DCL)

DCL roles implement row-level access control. They are attached to a view entity by its `@AccessControl.authorizationCheck: #CHECK` annotation.

#### PFCG-based role

```abap
@EndUserText.label: 'Access control for Sales Orders'
@MappingRole: true
define role ZR_SalesOrder
{
  grant select on ZI_SalesOrder
    where ( CompanyCode ) = aspect pfcg_auth( F_BKPF_BUK, BUKRS, ACTVT = '03' );
}
```

#### Multi-field restriction

```abap
define role ZR_PurchaseOrder
{
  grant select on ZI_PurchaseOrder
    where ( CompanyCode, PurchaseOrg )
      = aspect pfcg_auth( M_BEST_EKG,
                          BUKRS,
                          EKORG,
                          ACTVT = '03' );
}
```

#### Condition with literal

```abap
define role ZR_ActiveCustomers
{
  grant select on ZI_Customer
    where ( DeletionFlag ) != 'X'
      and ( CompanyCode )   = aspect pfcg_auth( F_KNA1_BUK, BUKRS, ACTVT = '03' );
}
```

#### Key notes

- DCL file name must equal view entity name (e.g. `ZI_SalesOrder.dcls`)
- `@MappingRole: true` is **required** for projection to work correctly
- `aspect pfcg_auth` checks the user's PFCG authorization object at runtime
- Multiple roles for the same entity are combined with **OR** logic

---

### 10. Annotation Quick Reference

#### `@AbapCatalog`

| Annotation | Values | Purpose |
|---|---|---|
| `viewEnhancementCategory` | `[#NONE]` / `[#PROJECTION_LIST]` / `[#UNION]` | Controls append extensibility |
| `sqlViewName` | `string` | Legacy: DDIC SQL view name (view entities don't need it) |

#### `@AccessControl`

| Annotation | Values | Purpose |
|---|---|---|
| `authorizationCheck` | `#CHECK` / `#NOT_REQUIRED` / `#NOT_ALLOWED` / `#PRIVILEGED_ONLY` | DCL enforcement |

#### `@EndUserText`

| Annotation | Purpose |
|---|---|
| `label` | Human-readable label (used in UI if no `@UI.lineItem.label` override) |
| `quickInfo` | Tooltip text |

#### `@ObjectModel`

| Annotation | Purpose |
|---|---|
| `usageType` | Classifies serviceQuality, sizeCategory, dataClass |
| `text.element` | `['TextFieldName']` — field providing human-readable text for a key |
| `text.association` | `'_TextAssoc'` — association to text table |
| `foreignKey.association` | `'_AssocName'` — marks field as FK for value help auto-resolution |
| `query.implementedBy` | `'ABAP:ClassName'` — required for custom entities |
| `dataCategory` | `#ABSTRACT_ENTITY` / `#BUSINESS_OBJECT` / ... |

#### `@Semantics`

| Annotation | Fields |
|---|---|
| `amount.currencyCode` | `'CurrencyCodeFieldName'` |
| `quantity.unitOfMeasure` | `'UomFieldName'` |
| `currencyCode: true` | Marks the currency field itself |
| `unitOfMeasure: true` | Marks the UoM field itself |
| `systemDate.createdAt: true` | Auto-population by framework |
| `systemDate.lastChangedAt: true` | Auto-population by framework |
| `user.createdBy: true` | Marks created-by user field |
| `user.lastChangedBy: true` | Marks changed-by user field |

#### `@Search`

| Annotation | Purpose |
|---|---|
| `searchable: true` | Enables free-text search on the entity |
| `defaultSearchElement: true` | Field is included in the default search scope |
| `ranking` | `#HIGH` / `#MEDIUM` / `#LOW` — weight in search result ranking |
| `fuzzinessThreshold` | `0.0`–`1.0` — fuzzy match sensitivity |

#### `@UI` (summary — see UI Annotations Catalog for full detail)

| Annotation | Purpose |
|---|---|
| `headerInfo` | Object page title/description band |
| `lineItem` | List report column |
| `identification` | Object page identification section field |
| `facet` | Object page section/sub-section structure |
| `fieldGroup` | Named group of fields for a facet |
| `selectionField` | Filter bar field |
| `chart` | Chart definition for ALP or Object Page chart |
| `dataPoint` | KPI tile or chart measure definition |
| `presentationVariant` | Default sort, visualizations |
| `selectionVariant` | Default filter expression |

#### `@Consumption`

| Annotation | Purpose |
|---|---|
| `valueHelpDefinition` | VH entity binding with additionalBinding |
| `filter.selectionType` | `#SINGLE` / `#MULTIPLE` / `#RANGE` / `#INTERVAL` |
| `filter.hidden` | `true` hides from filter bar but keeps for programmatic filtering |
| `semanticObject` | Smart Link / intent-based navigation target |

---

### 11. Complete Example D — CDS DCL Role (Full Pattern)

```abap
// ── ZR_TravelBooking.dcls ──────────────────────────────────────────────────
@EndUserText.label: 'Access Control: Travel Booking BO'
@MappingRole: true
define role ZR_TravelBooking
{
  // User may read travel bookings for their own agency only
  grant select on ZI_TravelBooking
    where ( AgencyID )
      = aspect pfcg_auth( Z_TRAVEL_AGY, ZAGENCYID, ACTVT = '03' );
}

// ── ZR_TravelBookingAdmin.dcls ────────────────────────────────────────────
// Admin role: unrestricted read
@EndUserText.label: 'Access Control: Travel Booking Admin'
@MappingRole: true
define role ZR_TravelBookingAdmin
{
  grant select on ZI_TravelBooking
    where (  )  = aspect pfcg_auth( S_TRVL_ADM, ACTVT = '03' );
}
```

> When both roles exist for the same entity, a user satisfying **either** is granted access
> (roles are OR-combined at runtime).

---

### 12. Analytical CDS Modeling (Embedded Analytics / OLAP)

Distinct from the transactional RAP/OData path. Same CDS stack, different annotations and runtime: the data model is exposed over the **InA (Information Access) protocol** and processed by the **ABAP Analytical Engine**, not OData. Embedded = engine runs in the same ABAP stack, on the same persistence as transactional apps, **no replication** to an external warehouse — queries hit live business data.

Source: SAP Help, ABAP Cloud Analytical Services / Analytical Use Cases.

#### Building blocks (star / snowflake schema)

| Block | Annotation | Role |
|---|---|---|
| Cube (fact) | `@Analytics.dataCategory: #CUBE` | Center of the star — measures + dimension associations |
| Dimension | `@Analytics.dataCategory: #DIMENSION` | Master-data / characteristic views joined to the cube |
| Analytical query | `@Analytics.query: true` | Consumption view; defines aggregation, layout, variables |

```abap
" Dimension
@Analytics.dataCategory: #DIMENSION
define view entity ZDIM_Product as select from zproduct { ... }

" Cube
@Analytics.dataCategory: #CUBE
define view entity ZCUBE_Sales as select from zsales
  association [1..1] to ZDIM_Product as _Product on ...
{ ... key fields, @Semantics-typed measures, _Product }

" Analytical query
@Analytics.query: true
define view entity ZQ_Sales as select from ZCUBE_Sales { ... }
```

#### Measures and aggregation

- Standard aggregations: **SUM, MIN, MAX** (built-in).
- **Calculated measures** — derive new KPIs from existing measures at query level.
- **Restricted measures** — filter a measure's result set by condition (exclude values from aggregation).
- `@AnalyticsDetails` — default multidimensional layout, variable sequence, aggregation/planning behavior.
- Engine evaluates measures either on the **SAP HANA database** or in **ABAP**.

#### Consumption

InA services consumed by **SAP Fiori** analytical UIs (Analytical List Page) or **SAP Analytics Cloud**. The `analytical_query` provider contract (see §3 Provider contracts) governs the projection exposed to clients.

#### Analytical extension points

Analytical extensibility targets: **dimension, cube, analytical-query, service-definition** — add a hierarchy, dimension, measure, or query to a released analytical model (modification-free, release-contract-backed).

---

*End of CDS Complete Syntax Reference*
