# RAP Business Events & Cloud BAdI — Complete Implementation Patterns

## Objective

Provide complete implementation patterns for all extension mechanisms in ABAP Cloud: RAP Business Events, Cloud BAdIs, BDEF Extensions, and CDS Extensions.

---

## RAP Business Events — Full Lifecycle

### Step 1: Define Event in BDEF

```
managed implementation in class zbp_i_travel unique;
strict ( 2 );

define behavior for ZI_Travel alias Travel
  persistent table ztravel
  draft table ztravel_d
  lock master total etag LocalLastChangedAt
{
  // Event declarations
  event TravelCreated parameter ZD_TravelCreatedPayload;
  event TravelAccepted;
  event TravelRejected parameter ZD_TravelRejectedPayload;
  event TravelCancelled parameter ZD_TravelCancelledPayload;
}
```

### Step 2: Define Abstract Entity for Payload

```sql
@EndUserText.label: 'Travel Created Payload'
define abstract entity ZD_TravelCreatedPayload
{
  TravelID   : travel_id;
  AgencyID   : agency_id;
  CustomerID : customer_id;
  Amount     : amount;
  Currency   : currency_code;
  BeginDate  : begin_date;
}
```

### Step 3: Raise Event (SAVE_MODIFIED only)

```abap
CLASS lhc_travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS save_modified FOR MODIFY
      IMPORTING create TYPE REQUEST FOR CREATE Travel
                update TYPE REQUEST FOR UPDATE Travel.
ENDCLASS.

CLASS lhc_travel IMPLEMENTATION.
  METHOD save_modified.
    " Raise event on CREATE
    IF create-travel IS NOT INITIAL.
      RAISE ENTITY EVENT zi_travel~TravelCreated
        FROM VALUE #( FOR <t> IN create-travel
          ( %key   = <t>-%key
            %param = VALUE #(
              TravelID   = <t>-TravelID
              AgencyID   = <t>-AgencyID
              CustomerID = <t>-CustomerID
              Amount     = <t>-TotalPrice
              Currency   = <t>-CurrencyCode
              BeginDate  = <t>-BeginDate ) ) ).
    ENDIF.

    " Raise event on status change to 'A' (accepted)
    IF update-travel IS NOT INITIAL.
      LOOP AT update-travel INTO DATA(ls_upd)
        WHERE Status = 'A'.
        RAISE ENTITY EVENT zi_travel~TravelAccepted
          FROM VALUE #( ( %key = ls_upd-%key ) ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```

**Critical constraints:**
- `RAISE ENTITY EVENT` only in `SAVE_MODIFIED` or `CLEANUP_FINALIZE`
- NOT allowed in: validations, determinations, actions, or feature control
- Event fires AFTER successful save (transactional guarantee)
- Payload entity must be abstract entity (no persistence)

### Step 4: Local Consumption (Same System)

```abap
CLASS zcl_travel_event_handler DEFINITION
  INHERITING FROM cl_abap_behavior_event_handler.

  PRIVATE SECTION.
    METHODS on_travel_created FOR ENTITY EVENT
      travel_created FOR Travel~TravelCreated.

    METHODS on_travel_accepted FOR ENTITY EVENT
      travel_accepted FOR Travel~TravelAccepted.
ENDCLASS.

CLASS zcl_travel_event_handler IMPLEMENTATION.
  METHOD on_travel_created.
    LOOP AT travel_created INTO DATA(event).
      " React: create follow-up, send notification, update analytics
      DATA(lv_travel_id) = event-%param-TravelID.
      DATA(lv_agency)    = event-%param-AgencyID.

      " Example: Create audit log entry
      INSERT INTO z_travel_audit VALUES @(
        VALUE #( travel_id = lv_travel_id
                 event     = 'CREATED'
                 timestamp = utclong_current( )
                 user      = cl_abap_context_info=>get_user_technical_name( ) ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD on_travel_accepted.
    LOOP AT travel_accepted INTO DATA(event).
      " Trigger downstream process (e.g., billing)
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

### Step 5: Remote Consumption (Event Mesh)

1. **Create Event Binding** in ADT: New → Other → Event Binding
2. **Map event to topic:**
   ```
   Topic: sap/s4/beh/travel/v1/Travel/Created/v1
   Event: ZI_Travel~TravelCreated
   ```
3. **Configure Channel:** Communication Arrangement `SAP_COM_0092` (Enterprise Event Enablement)
4. **External consumer subscribes** via SAP Event Mesh or Integration Suite

---

## Cloud BAdI — Complete Pattern

### Discovery

1. **SAP Business Accelerator Hub** → S/4HANA Cloud → On-Stack Extensibility → BAdIs
2. **ADT** → Released Objects → Enhancement Spots → [Application Component]
3. **Search by process:** "Material Document", "Purchase Order", "Sales Order"

### Implementation

```abap
" Step 1: Create Enhancement Implementation in ADT
" Right-click Enhancement Spot → New Enhancement Implementation

" Step 2: Implement the BAdI interface
CLASS zcl_po_validation_badi DEFINITION FINAL
  PUBLIC SECTION.
    INTERFACES if_ex_purchaseorder_check.
ENDCLASS.

CLASS zcl_po_validation_badi IMPLEMENTATION.
  METHOD if_ex_purchaseorder_check~check.
    " Custom validation during PO processing
    LOOP AT purchase_order_items INTO DATA(item).
      IF item-quantity > 9999.
        APPEND VALUE #(
          msgty = 'E'
          msgid = 'Z_PO'
          msgno = '001'
          msgv1 = item-material ) TO messages.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

### BAdI Filter Values

```abap
" BAdI with filter (only triggers for specific context)
CLASS zcl_pricing_badi DEFINITION FINAL
  PUBLIC SECTION.
    INTERFACES if_ex_pricing_calc.
ENDCLASS.

" Registration: Enhancement Implementation → Filter = 'Z_CUSTOM_PRICING'
" BAdI only called when pricing procedure uses filter value Z_CUSTOM_PRICING
```

### BAdI Fallback Class

```abap
" Default behavior when no implementation is active
CLASS zcl_pricing_fallback DEFINITION FINAL
  PUBLIC SECTION.
    INTERFACES if_ex_pricing_calc.
ENDCLASS.

CLASS zcl_pricing_fallback IMPLEMENTATION.
  METHOD if_ex_pricing_calc~calculate.
    " Default: no custom pricing applied
    result = standard_price.
  ENDMETHOD.
ENDCLASS.
```

---

## BDEF Extension (Extend Standard SAP BO)

### Syntax

```
extend behavior for I_PurchaseOrderTP {
  // Add custom validation
  validation zCheckCustomLimit on save { create; update; field PurchaseOrderAmount; }

  // Add custom determination
  determination zSetCustomCategory on modify { create; field PurchaseOrderType; }

  // Add custom action
  action zApproveWithComment parameter ZD_ApproveComment result [1] $self;

  // Add custom event
  event zCustomApproved parameter ZD_CustomApprovalPayload;
}
```

### Implementation

```abap
CLASS lhc_purchaseorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS zCheckCustomLimit FOR VALIDATE ON SAVE
      IMPORTING keys FOR PurchaseOrder~zCheckCustomLimit.
ENDCLASS.

CLASS lhc_purchaseorder IMPLEMENTATION.
  METHOD zCheckCustomLimit.
    READ ENTITIES OF I_PurchaseOrderTP IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( PurchaseOrderAmount ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orders).

    LOOP AT lt_orders INTO DATA(order).
      IF order-PurchaseOrderAmount > 1000000.
        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky = order-%tky
          %msg = NEW zcx_po_limit( amount = order-PurchaseOrderAmount ) )
          TO reported-purchaseorder.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

**Prerequisites:**
- Standard BO released for extension (C1 contract + extensibility enabled)
- ADT: Right-click BDEF → New Behavior Extension
- Extension runs in SAME transaction as standard logic
- Extension class in SAME behavior pool or separate extension pool

---

## CDS View Extension

```sql
extend view entity I_PurchaseOrderTP with
{
  // Add field from extension include
  PurchaseOrder.zcustom_category as ZCustomCategory,

  // Add new association
  association [0..1] to ZI_CustomApprover as _CustomApprover
    on $projection.ZCustomCategory = _CustomApprover.Category
}
```

---

## Decision Matrix: Which Mechanism?

| Question | Answer | Mechanism |
|---|---|---|
| Need to MODIFY data during processing? | YES | Cloud BAdI |
| Need to REACT after something happened? | YES | RAP Business Event |
| Need to ADD fields to standard BO? | YES | CDS View Extension |
| Need to ADD validation/action to standard BO? | YES | BDEF Extension |
| Need external system to react? | YES | RAP Event + Event Mesh |
| Need guaranteed delivery? | YES | RAP Event + Event Mesh |
| Need same-system lightweight reaction? | YES | RAP Event + Local Consumption |

---

## Platform Availability

| Feature | Public Cloud | Private Cloud | BTP ABAP |
|---|---|---|---|
| RAP Business Events (define/raise) | 2211+ | 2022+ | 2208+ |
| Local event consumption | 2302+ | 2023+ | 2208+ |
| Event Binding (remote) | 2211+ | 2022+ | 2208+ |
| Derived Events | 2311+ | 2023 FPS01+ | 2311+ |
| Cloud BAdI implementation | All | All | All |
| BDEF Extension | All | All | All |
| CDS View Extension | All | All | All |

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
