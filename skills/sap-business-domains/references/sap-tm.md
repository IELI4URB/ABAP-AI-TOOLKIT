---
name: sap-tm
description: 'SAP Transportation Management guidance for S/4HANA ABAP solutions. Use for freight units/orders/bookings, planning, tendering, carriers, capacity, charges, settlement, execution events, milestones, exceptions, and logistics integration.'
metadata:
  version: 3.0.0
  tags: sap tm freight transportation planning execution charges
---

# SAP Transportation Management

Use this skill as the TM domain owner.

## Focused reference map

| Concern | Reference | Use |
|---|---|---|
| CDS, transactional API, remote API, BOPF/BAPI, and BAdI candidates | [TM released-object candidates](#tm-released-objects--full-reference) (inlined in this guide below) | Candidate discovery only; classify landscape and C0/C1/C2/Tier 2 before target-system verification |
| Domain governance: gates, landscape, cross-skill, eligibility, and definition of done | [domain governance](./domain-governance.md) | Shared governance set; load for a full governance audit or release-readiness review |

For internal ABAP updates in embedded TM, search for a C1-released transactional business object in the target system. Use remote APIs only when the requirement crosses a system boundary.

## Workflow

1. Establish landscape and distinguish embedded TM, decentralized TM, and integration boundaries.
2. Classify demand, planning, tendering, execution, event, charge, or settlement scope.
3. Verify freight document flow, locations/resources, capacity, carrier, charge, and SD/EWM boundaries.
4. Read only the focused reference mapped above when candidate discovery is needed, then add at most two technical companions.
5. Validate planning/execution integrity, authorization, volume, event idempotency, and recovery.

## Gates

Do not recommend direct persistence changes or unverified APIs. Preserve freight document status, planning constraints, charge/settlement semantics, event ordering, and logistics integration contracts.

## TM Released Objects — Full Reference

### Important: Landscape Determines Available Objects

| Deployment | Available Objects | Extension Approach |
|---|---|---|
| **Embedded TM in S/4HANA** | I_ CDS views, OData APIs, RAP BOs, Cloud BAdIs | ABAP Cloud (CDS/RAP/BAdI) |
| **Standalone SAP TM 9.x** | Classic ABAP, TM-specific BAPIs, BOPF objects | Classic ABAP, user exits, BAdIs |
| **SAP S/4HANA + standalone TM via CPI** | Integration via SAP Integration Suite | CPI iFlows, API-based |

Always identify your deployment type before designing extensions.

### 1. Reading TM Data — Embedded S/4HANA

#### Read Freight Orders for Carrier
```abap
SELECT FreightOrder,
       FreightOrderType,
       TransportationMode,
       CarrierParty,
       ShippingType,
       FreightOrderLifeCycleStatus
  FROM I_FreightOrder
  WHERE CarrierParty = @iv_carrier
    AND FreightOrderLifeCycleStatus <> '99'  " not completed
  ORDER BY CreationDate DESCENDING
  INTO TABLE @DATA(lt_freight_orders).
```

#### Read Freight Units Pending Planning
```abap
SELECT FreightUnit,
       FreightUnitType,
       SourceLocation,
       DestinationLocation,
       TotalGrossWeight,
       WeightUnit,
       EarliestPickUpDateTime,
       LatestDeliveryDateTime
  FROM I_FreightUnit
  WHERE PlanningStatus = '01'   " 01 = Not planned — verify value in your system
    AND SourceLocation = @iv_source_location
  INTO TABLE @DATA(lt_unplanned_fus).
```

#### Read Charge Items for a Freight Order
```abap
SELECT FreightOrder,
       ChargeType,
       RateValue,
       ChargeCurrency,
       BaseQuantity,
       BaseUnit
  FROM I_TMFreightOrderChargeItem
  WHERE FreightOrder = @iv_freight_order
  INTO TABLE @DATA(lt_charges).
```

### 2. Freight Order Lifecycle — State Overview

```
Created → Tendering → Carrier Confirmed → In Execution → Completed
                ↘ Declined → Re-tender or Manual assignment
```

#### Key Status Values (verify in your system — may vary by release)
| Status Field | Typical Values |
|---|---|
| `FreightOrderLifeCycleStatus` | 01=Created, 02=In Planning, 03=Fixed, 05=In Execution, 09=Completed |
| `TenderingStatus` | 01=Not Started, 02=In Progress, 03=Confirmed, 04=Rejected |
| `ExecutionStatus` | Varies by config |

### 3. Creating/Updating Freight Orders via OData

#### Create Freight Order
```abap
DATA(lv_payload) = |\{|
  && |"FreightOrderType":"FO",|
  && |"TransportationMode":"03",|
  && |"ShippingType":"01",|
  && |"CarrierParty":"{ iv_carrier }",|
  && |"PlannedPickUpDate":"{ iv_pickup_date+0(4) }-{ iv_pickup_date+4(2) }-{ iv_pickup_date+6(2) }"|
  && |\}|.

DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
  comm_scenario = 'Z_TM_FO_SCENARIO' ).
DATA(lo_client)  = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).
DATA(lo_request) = lo_client->get_http_request( ).
lo_request->set_method( if_web_http_client=>post ).
lo_request->set_uri_path( '/sap/opu/odata/sap/API_FREIGHT_ORDER_SRV/A_FreightOrder' ).
lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
lo_request->set_text( lv_payload ).
DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).
```

> ⚠️ Verify API path and entity set name in your system. TM OData service paths can vary by activation and release.

### 4. Charge Calculation Extension — BAdI Pattern

```abap
" Cloud BAdI for custom charge calculation (Embedded TM in S/4HANA)
CLASS zcl_tm_custom_charge DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_badi_interface.  " Marker interface
    INTERFACES zif_tm_charge_calculator.  " BAdI interface — verify exact name in your system
ENDCLASS.

CLASS zcl_tm_custom_charge IMPLEMENTATION.
  METHOD zif_tm_charge_calculator~calculate.
    " Apply custom fuel surcharge based on distance
    DATA(lv_distance) = is_freight_order-total_distance.
    IF lv_distance > 500.
      ev_surcharge = lv_distance * '0.05'.  " 5% surcharge per km over 500
      ev_currency  = 'EUR'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```

> ⚠️ The exact BAdI name, interface, and parameter structure for `TM_CHARGE_CALCULATION` must be verified in your system via transaction SE18 (on-premise) or ADT BAdI browser (ABAP Cloud).

### 5. Carrier Selection Enhancement

```abap
" Enhance carrier scoring — filter carriers by custom criteria
CLASS zcl_tm_carrier_filter DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_badi_interface.
    INTERFACES zif_tm_carrier_selection.  " Verify interface name in ADT
ENDCLASS.

CLASS zcl_tm_carrier_filter IMPLEMENTATION.
  METHOD zif_tm_carrier_selection~filter_carriers.
    " Remove carriers that are blocked for the destination country
    DELETE it_carriers WHERE country_code = iv_blocked_country.
  ENDMETHOD.
ENDCLASS.
```

### 6. TM Integration Patterns

#### TM → FI (Freight Cost Settlement)
```
Freight Order
    ↓ (charge calculation)
Charge Items (I_TMFreightOrderChargeItem)
    ↓ (settlement run)
FI Accounting Document (BAPI_ACC_DOCUMENT_POST in Tier 2)
    ↓
Supplier Invoice (Logistics Invoice Verification)
```

#### TM → MM (Goods Receipt on Delivery)
```
TM Freight Order (arrival event)
    ↓ (event triggers)
Inbound Delivery (SD/TM)
    ↓ (GR posting)
Material Document (BAPI_GOODSMVT_CREATE in Tier 2)
    ↓
FI/CO Document (goods receipt postings)
```

#### SD → TM (Delivery Request)
```
Sales Order (I_SalesOrder)
    ↓ (outbound delivery creation)
Outbound Delivery (I_OutboundDelivery)
    ↓ (TM integration — if active)
Freight Unit (I_FreightUnit)
    ↓ (planning + carrier selection)
Freight Order (I_FreightOrder)
```

### 7. TM Released API Summary

| Object Type | Name | Purpose | Deployment |
|---|---|---|---|
| CDS View | `I_FreightOrder` | Freight order header | Embedded TM |
| CDS View | `I_FreightUnit` | Freight unit | Embedded TM |
| CDS View | `I_TMFreightOrderChargeItem` | Charge items | Embedded TM |
| CDS View | `I_Location` | TM locations | Embedded TM |
| OData API | `API_FREIGHT_ORDER_SRV` | FO R/W | Embedded TM |
| OData API | `API_FREIGHT_UNIT_SRV` | FU management | Embedded TM |
| BAdI | `TM_CHARGE_CALCULATION` | Custom charges | Both |
| BAdI | `TM_CARRIER_SELECTION` | Carrier filtering | Both |

> All objects marked "Embedded TM" require S/4HANA with embedded TM activated. For standalone TM 9.x, use the dedicated SAP TM BAPI/BOPF APIs — contact your TM architect for the correct entry points.
