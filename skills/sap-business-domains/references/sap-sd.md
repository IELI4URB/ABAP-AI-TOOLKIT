---
name: sap-sd
description: 'SAP Sales and Distribution guidance for S/4HANA ABAP solutions. Use for quotations, sales orders, ATP, pricing, partners, deliveries, shipping, billing, output, document flow, credit, and order-to-cash extensions.'
metadata:
  version: 3.0.0
  tags: sap sd sales order pricing delivery billing atp
---

# SAP Sales and Distribution

Use this skill as the SD domain owner.

## Focused reference map

| Concern | Reference | Use |
|---|---|---|
| CDS, transactional API, remote API, BAPI, and BAdI candidates | [SD released-object candidates](#sd-released-objects--full-reference) (inlined in this guide below) | Candidate discovery only; classify C0/C1/C2/Tier 2 and verify in the target system |
| Domain governance: gates, landscape, cross-skill, eligibility, and definition of done | [domain governance](./domain-governance.md) | Shared governance set; load for a full governance audit or release-readiness review |

For internal ABAP updates, search for a C1-released transactional RAP business object in the target system. Use remote OData APIs only when the requirement crosses the SAP system boundary.

## Workflow

1. Establish landscape, sales-area context, process stage, document/status flow, and volume.
2. Verify order type, item/schedule logic, ATP, pricing, partner, delivery, billing, output, and Finance boundaries.
3. Read only the focused reference mapped above when candidate discovery is needed.
4. Add at most two technical companion skills for the active phase.
5. Validate document integrity, authorization, performance, integration, and recovery.

## Gates

Do not recommend direct persistence changes or unverified APIs. Preserve pricing, ATP, copy-control, status, delivery, billing, and posting semantics. Distinguish business-known objects from released technical contracts.

## SD Released Objects — Full Reference

### 1. Reading SD Data with ABAP SQL + CDS

#### Read Open Sales Orders
```abap
SELECT so~SalesOrder,
       so~SalesOrderType,
       so~SoldToParty,
       so~SalesOrganization,
       so~TotalNetAmount,
       so~TransactionCurrency,
       soi~SalesOrderItem,
       soi~Material,
       soi~OrderQuantity,
       soi~NetAmount,
       soi~RequestedDeliveryDate
  FROM I_SalesOrder AS so
  INNER JOIN I_SalesOrderItem AS soi
    ON so~SalesOrder = soi~SalesOrder
  WHERE so~SalesOrganization = @iv_sales_org
    AND so~OverallSDProcessStatus <> 'C'    " C = Completed
    AND so~CreationDate >= @lv_from_date
  ORDER BY so~CreationDate DESCENDING
  INTO TABLE @DATA(lt_orders).
```

#### Read Billing Documents for a Period
```abap
SELECT BillingDocument,
       BillingDocumentType,
       SoldToParty,
       BillingDocumentDate,
       TotalGrossAmount,
       TransactionCurrency
  FROM I_BillingDocument
  WHERE SalesOrganization  = @iv_sales_org
    AND BillingDocumentDate BETWEEN @iv_from AND @iv_to
    AND BillingDocumentType = 'F2'   " Standard invoice
  ORDER BY BillingDocumentDate DESCENDING
  INTO TABLE @DATA(lt_billing).
```

#### Read Pricing Conditions for a Material/Customer
```abap
SELECT ConditionTable,
       ConditionType,
       ConditionRateValue,
       Currency,
       ConditionValidityStartDate,
       ConditionValidityEndDate
  FROM I_PricingConditionRecord
  WHERE ConditionType = 'PR00'   " Base price condition type
    AND ConditionValidityEndDate >= @sy-datum
  INTO TABLE @DATA(lt_prices).
```

### 2. Create Sales Order via API_SALES_ORDER_SRV (OData V2)

```abap
" Build JSON payload
DATA(lv_so_payload) = |\{|
  && |"SalesOrderType":"OR",|
  && |"SoldToParty":"{ iv_customer }",|
  && |"SalesOrganization":"{ iv_sales_org }",|
  && |"DistributionChannel":"{ iv_dist_channel }",|
  && |"OrganizationDivision":"{ iv_division }",|
  && |"to_Item":\{"results":[\{|
  && |"SalesOrderItem":"000010",|
  && |"Material":"{ iv_material }",|
  && |"RequestedQuantity":"{ iv_qty }",|
  && |"RequestedQuantityUnit":"{ iv_unit }",|
  && |"RequestedDeliveryDate":"\/Date({ lv_epoch })\/"|
  && |\}]\}\}|.

DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
  comm_scenario = 'Z_SD_SALES_ORDER_SCENARIO' ).
DATA(lo_client)  = cl_web_http_client_manager=>create_by_destination( lo_destination ).
DATA(lo_request) = lo_client->get_http_request( ).
lo_request->set_method( if_web_http_client=>post ).
lo_request->set_uri_path( '/sap/opu/odata/sap/API_SALES_ORDER_SRV/A_SalesOrder' ).
lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
lo_request->set_text( lv_so_payload ).
DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).
DATA(lv_status) = lo_response->get_status( )-code.
```

### 3. Create Sales Order — Tier 2 Wrapper

#### Interface (released C1 — ABAP Cloud)
```abap
INTERFACE zif_sd_sales_order_creator.
  TYPES: BEGIN OF ty_item,
           material          TYPE matnr,
           order_quantity    TYPE kwmeng,
           unit              TYPE vrkme,
           plant             TYPE werks_d,
           delivery_date     TYPE edatu,
         END OF ty_item.
  TYPES tt_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

  METHODS create
    IMPORTING iv_customer      TYPE kunnr
              iv_sales_org     TYPE vkorg
              iv_dist_channel  TYPE vtweg
              iv_division      TYPE spart
              it_items         TYPE tt_items
    RETURNING VALUE(rv_sales_order) TYPE vbeln
    RAISING   zcx_sd_order_error.
ENDINTERFACE.
```

#### Tier 2 Wrapper (Standard ABAP — NOT ABAP Cloud)
```abap
CLASS zcl_sd_sales_order_creator DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_sd_sales_order_creator.
ENDCLASS.

CLASS zcl_sd_sales_order_creator IMPLEMENTATION.
  METHOD zif_sd_sales_order_creator~create.
    DATA ls_header     TYPE bapisdhd1.
    DATA ls_header_x   TYPE bapisdhd1x.
    DATA lt_items      TYPE TABLE OF bapisditm.
    DATA lt_items_x    TYPE TABLE OF bapisditmx.
    DATA lt_return     TYPE TABLE OF bapiret2.
    DATA lv_salesdoc   TYPE vbeln.

    ls_header-doc_type       = 'OR'.
    ls_header-sales_org      = iv_sales_org.
    ls_header-distr_chan     = iv_dist_channel.
    ls_header-division       = iv_division.
    ls_header-sold_to        = iv_customer.
    ls_header_x-doc_type     = 'X'.
    ls_header_x-sales_org    = 'X'.

    DATA(lv_item_no) = 0.
    LOOP AT it_items INTO DATA(ls_item).
      lv_item_no += 10.
      APPEND VALUE bapisditm(
        itm_number = lv_item_no
        material   = ls_item-material
        target_qty = ls_item-order_quantity
        target_qu  = ls_item-unit
        plant      = ls_item-plant
        req_date   = ls_item-delivery_date ) TO lt_items.
      APPEND VALUE bapisditmx( itm_number = lv_item_no
                               material   = 'X'
                               target_qty = 'X'
                               target_qu  = 'X' ) TO lt_items_x.
    ENDLOOP.

    CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
      EXPORTING  order_header_in   = ls_header
                 order_header_inx  = ls_header_x
      IMPORTING  salesdocument     = lv_salesdoc
      TABLES     order_items_in    = lt_items
                 order_items_inx   = lt_items_x
                 return            = lt_return.

    DATA lt_errors LIKE lt_return.
    LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
      APPEND ls_ret TO lt_errors.
    ENDLOOP.
    IF lt_errors IS NOT INITIAL.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_sd_order_error
        EXPORTING messages = lt_errors.
    ENDIF.

    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
    rv_sales_order = lv_salesdoc.
  ENDMETHOD.
ENDCLASS.
```

### 4. Key SD Extension Points

#### BAdIs
Verify exact BAdI names in SE18 for your release (SD enhancement names vary and are easy to mis-cite).

| BAdI | Description |
|---|---|
| `BADI_SD_SALES` / `BADI_SD_SALES_ITEM` | Sales document header/item enhancement |
| `LE_SHP_DELIVERY_PROC` | Delivery processing enhancement |
| `SD_CIN_LV60AU02` / pricing user-exits (VOFM routines) | Pricing-related enhancement (classic) |

#### S/4HANA SD Key Changes vs ECC
| Topic | ECC | S/4HANA |
|---|---|---|
| Customer master | KNA1 + KNB1 | Business Partner (BUT000) — `I_Customer` CDS |
| Output management | NAST (condition technique) | Output Control (BRF+ based) |
| Availability check | Classic ATP | aATP (Advanced ATP) in SAP S/4HANA |
| Pricing | Classic condition technique | Same technique, new APIs |

### 5. SD Released API Summary Table

| Object Type | Name | Purpose | Release |
|---|---|---|---|
| CDS View | `I_SalesOrder` | SO header | C1 |
| CDS View | `I_SalesOrderItem` | SO line items | C1 |
| CDS View | `I_BillingDocument` | Billing header | C1 |
| CDS View | `I_OutboundDelivery` | Delivery header | C1 |
| CDS View | `I_PricingConditionRecord` | Pricing records | C1 |
| OData API | `API_SALES_ORDER_SRV` | SO R/W | Released |
| OData API | `API_BILLING_DOCUMENT_SRV` | Billing R/W | Released |
| OData API | `API_OUTBOUND_DELIVERY_SRV_0001` | Delivery R/W | Released |
| BAPI (Tier 2) | `BAPI_SALESORDER_CREATEFROMDAT2` | Create SO | Tier 2 only |
| BAPI (Tier 2) | `BAPI_BILLINGDOC_CREATEMULTIPLE` | Create billing | Tier 2 only |
