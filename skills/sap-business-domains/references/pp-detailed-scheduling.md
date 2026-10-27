# PP Detailed Scheduling — ABAP Reference

> ⚠️ **Verify function-module names before use.** Several classic/PP-DS FM names in this guide were **not found** on a standard S/4HANA 2023 system and appear to be illustrative placeholders: `CR_CAPACITY_AVAILABLE_GET`, `CR_CAPACITY_DISPATCH`, `CR_CAPACITY_REQUIREMENTS_GET`, `CIF_ORDER_TRANSFER`, `CIF_MATERIAL_TRANSFER`, `/SAPAPO/OM_ORDER_READ`, `/SAPAPO/HEU_RUN`, `/SAPAPO/OM_PEGGING_READ`, `/SAPAPO/OM_PEGGING_FIX`, `/SAPAPO/OM_PEGGING_FIX_DELETE`, `/SAPAPO/RES_SETUP_MATRIX_GET`, `/SAPAPO/RES_SETUP_MATRIX_SET`, `/SAPAPO/OPT_RUN_BACKGROUND`. Confirm the real API in SE37 / Released Objects for your release. (`/SAPAPO/OM_ORDER_CHANGE` is real. Many PP/DS operations — heuristic/optimizer runs, pegging, setup matrix — are driven via PP/DS apps or internal APIs, not a single public FM.)

## 1. Technology Selection

| Feature | Classic Capacity Planning | Embedded PP/DS S/4 1709+ | APO PP/DS |
|---|---|---|---|
| Scheduling | Backward/forward | Finite scheduling | Finite scheduling |
| Resource model | Work center | PP/DS resource | PP/DS resource + liveCache |
| Optimization | Manual CM21 | Automated optimizer | SCM optimizer |
| Setup times | Basic setup key | Full setup matrix | Full setup matrix |
| Pegging | MRP-based | True demand-supply | True demand-supply |
| Gantt | CM25 | DS Board (Fiori) | APO DS Board |
| Prerequisite | Standard PP | S/4HANA 1709+ | Separate APO server |

### CM Transactions
| Transaction | Description |
|---|---|
| CM01 | Capacity evaluation — work center load |
| CM04 | Overload situations |
| CM21 | Capacity leveling — order-by-order |
| CM22 | Capacity leveling — order pool |
| CM25 | Detailed scheduling Gantt chart |
| CM26 | Variable capacity evaluation |

---

## 2. Classic Capacity Planning — ABAP

### Key Tables
| Table | Description |
|---|---|
| KBED | Capacity requirements per operation |
| CRCA | Available capacity |
| KAKO | Capacity header |
| KAZY | Capacity intervals |

### KBED Key Fields
| Field | Description |
|---|---|
| ARBID | Work center object ID |
| AUFNR | Production order |
| VORNR | Operation number |
| MSSTX | Setup time (remaining) |
| MGVRB | Machine time |
| ISTGE | Actual confirmed quantity |

### Read and Dispatch Capacity

```abap
" Read capacity requirements
CALL FUNCTION 'CR_CAPACITY_REQUIREMENTS_GET'
  EXPORTING
    objid = lv_objid
    kapid = '001'        " 001=machine 002=labor
    datuv = lv_date_from
    datub = lv_date_to
  TABLES
    t_kbed = lt_cap_req
  EXCEPTIONS not_found = 1 OTHERS = 2.

" Read available capacity
CALL FUNCTION 'CR_CAPACITY_AVAILABLE_GET'
  EXPORTING
    objid     = lv_objid
    kapid     = '001'
    date_from = lv_date_from
    date_to   = lv_date_to
    time_from = '000000'
    time_to   = '235959'
  IMPORTING  e_available = lv_avail_hours
  TABLES     t_capacity  = lt_intervals
  EXCEPTIONS OTHERS = 1.

" Dispatch operation to specific time slot (finite scheduling)
CALL FUNCTION 'CR_CAPACITY_DISPATCH'
  EXPORTING
    i_arbid         = lv_arbid
    i_aufnr         = lv_aufnr
    i_vornr         = lv_vornr
    i_new_start     = lv_new_start_date
    i_new_starttime = lv_new_start_time
    i_strategy      = '2'   " 1=backward 2=forward 3=middle
  EXCEPTIONS OTHERS = 1.
```

### Scheduling Type Codes
| Code | Description |
|---|---|
| 1 | Backward (from required date) |
| 2 | Forward (from earliest start) |
| 3 | From today's date |
| 4 | Only create capacity requirements |

---

## 3. PP/DS Architecture

### Order Categories
| Category | ABAP Object |
|---|---|
| Planned Order | /SAPAPO/MSDPORD |
| Production Order | /SAPAPO/PPHEAD |
| Process Order (PP-PI) | /SAPAPO/PPHEAD |
| Purchase Requisition | /SAPAPO/MMPUR |

### Activity Types within an Operation
- **Phase**: main production execution
- **Setup**: pre-production changeover/preparation
- **Teardown**: post-production cleanup

---

## 4. PP/DS Heuristics

### Standard Heuristics Catalog
| ID | Purpose |
|---|---|
| SAP_PP_D001 | Schedule by date — respects due dates |
| SAP_PP_D002 | Schedule by priority |
| SAP_PP_D003 | Backward and forward combined |
| SAP_PP_D004 | Decomposition — multi-resource |
| SAP_PP_D005 | Infinite scheduling |
| SAP_PP_D006 | Capacity leveling |
| SAP_PP_D010 | Block planning — group similar setups |
| SAP_PP_C001 | Cyclic scheduling |
| SAP_PP_009 | Scheduling sequence heuristic |
| SAP_MRP_001 | Standard MRP within PP/DS |
| SAP_MRP_002 | Full PP/DS planning run |

### Run PP/DS Heuristic

```abap
DATA: lt_ordkey   TYPE TABLE OF /sapapo/om_ordkey,
      lt_messages TYPE TABLE OF /sapapo/om_message.

APPEND VALUE /sapapo/om_ordkey(
  guid    = lv_order_guid
  ordtype = 'PPorder'
) TO lt_ordkey.

CALL FUNCTION '/SAPAPO/HEU_RUN'
  EXPORTING
    i_heuname   = 'SAP_PP_D001'
    i_mode      = 'B'
    i_plant     = lv_werks
    i_matnr     = lv_matnr
    i_from_date = lv_from_date
    i_to_date   = lv_to_date
  IMPORTING
    e_messages  = lt_messages
  TABLES
    t_ordkey    = lt_ordkey
  EXCEPTIONS
    heuristic_not_found = 1
    OTHERS              = 2.
```

### Custom Heuristic via BAdI

```abap
" Register in T-code /SAPAPO/CDPSHEUR, then implement:
CLASS zcl_pp_heuristic DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES /sapapo/if_ppds_heu_execute.
ENDCLASS.
CLASS zcl_pp_heuristic IMPLEMENTATION.
  METHOD /sapapo/if_ppds_heu_execute~execute.
    LOOP AT it_ordkey INTO DATA(ls_key).
      TRY.
          CALL FUNCTION '/SAPAPO/OM_ORDER_READ'
            EXPORTING i_ordkey = ls_key
            IMPORTING e_order  = DATA(ls_order).
          " Apply custom scheduling logic here
          CALL FUNCTION '/SAPAPO/OM_ORDER_CHANGE'
            EXPORTING
              i_ordkey    = ls_key
              i_new_start = lv_new_start
              i_commit    = abap_false.
        CATCH /sapapo/cx_ppds_order INTO DATA(lx).
          APPEND VALUE /sapapo/om_message(
            msgty = 'E'  msgtx = lx->get_text()
          ) TO ct_message.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

---

## 5. PP/DS Optimizer

### Optimization Objectives
| Objective | Description |
|---|---|
| Minimize lateness | Respect order due dates |
| Minimize setup | Reduce changeovers (needs setup matrix) |
| Minimize WIP | Reduce average cycle time |
| Maximize utilization | Fill capacity gaps |
| Combined weighted | Penalty cost across objectives |

```abap
" Run optimizer in background
CALL FUNCTION '/SAPAPO/OPT_RUN_BACKGROUND'
  EXPORTING
    i_profile_name  = 'ZOPT_PROFILE_01'
    i_plant         = lv_werks
    i_resource_name = lv_resource
    i_from_date     = lv_from_date
    i_to_date       = lv_to_date
    i_mode          = 'R'   " R=real  S=simulation
  IMPORTING
    e_job_name      = lv_job_name
    e_return_code   = lv_rc
  EXCEPTIONS
    profile_not_found = 1
    OTHERS            = 2.
```

---

## 6. Setup Matrices

### Key Tables
| Table | Description |
|---|---|
| /SAPAPO/SEQOBJ | Setup key definitions |
| /SAPAPO/SEQMAT | Material-to-setup-key assignment |
| /SAPAPO/SEQGRP | Setup groups |
| /SAPAPO/SEQTIM | Setup times matrix (from/to) |

```abap
" Set setup time between two keys
CALL FUNCTION '/SAPAPO/RES_SETUP_MATRIX_SET'
  EXPORTING
    i_resource       = lv_resource
    i_setup_key_from = lv_key_from
    i_setup_key_to   = lv_key_to
    i_setup_duration = lv_duration_sec
    i_setup_unit     = 'SEC'
  EXCEPTIONS resource_not_found = 1 OTHERS = 2.

" Read full matrix
CALL FUNCTION '/SAPAPO/RES_SETUP_MATRIX_GET'
  EXPORTING  i_resource = lv_resource
  TABLES     et_matrix  = lt_setup_matrix
  EXCEPTIONS OTHERS = 1.
```

---

## 7. Pegging

```abap
" Read supply covering a demand
CALL FUNCTION '/SAPAPO/OM_PEGGING_READ'
  EXPORTING
    i_ordkey     = ls_demand_ordkey
    i_direction  = 'D'   " D=demand-to-supply S=supply-to-demand
    i_all_levels = 'X'
  TABLES  et_pegging = lt_pegging
  EXCEPTIONS OTHERS = 1.

" Fix a pegging relationship
CALL FUNCTION '/SAPAPO/OM_PEGGING_FIX'
  EXPORTING
    i_demand_ordkey = ls_demand_ordkey
    i_supply_ordkey = ls_supply_ordkey
    i_quantity      = lv_qty
  EXCEPTIONS pegging_error = 1 OTHERS = 2.

" Delete fixed pegging
CALL FUNCTION '/SAPAPO/OM_PEGGING_FIX_DELETE'
  EXPORTING
    i_demand_ordkey = ls_demand_ordkey
    i_supply_ordkey = ls_supply_ordkey
  EXCEPTIONS OTHERS = 1.
```

---

## 8. PP/DS BAdIs

| BAdI | Interface | Purpose |
|---|---|---|
| /SAPAPO/PPDS_ORDER_CHANGE | /SAPAPO/IF_PPDS_ORDER_CHG | Before/after order change |
| /SAPAPO/PPDS_ORDER_CREATE | /SAPAPO/IF_PPDS_ORDER_CRT | Before/after order creation |
| /SAPAPO/PPDS_HEU_IMPLEMENT | /SAPAPO/IF_PPDS_HEU_EXECUTE | Custom heuristic |
| /SAPAPO/PPDS_ALERT_CREATE | /SAPAPO/IF_PPDS_ALERT | Custom alerts |
| /SAPAPO/PPDS_SCHED_CHECK | /SAPAPO/IF_PPDS_SCHED | Scheduling constraint check |
| /SAPAPO/RES_CHECK_AVAIL | /SAPAPO/IF_RES_AVAIL | Custom resource availability |

```abap
CLASS zcl_ppds_order_chg DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES /sapapo/if_ppds_order_chg.
ENDCLASS.
CLASS zcl_ppds_order_chg IMPLEMENTATION.
  METHOD /sapapo/if_ppds_order_chg~before_change.
    " Reject changes beyond planning horizon
    IF is_order_after-end_date > lv_horizon.
      RAISE EXCEPTION TYPE /sapapo/cx_ppds_order.
    ENDIF.
  ENDMETHOD.
  METHOD /sapapo/if_ppds_order_chg~after_change.
    " Log rescheduling event
  ENDMETHOD.
ENDCLASS.
```

---

## 9. CIF Integration (APO to ERP)

### CIF Object Types
| Object | Description |
|---|---|
| Materials | Master data transfer |
| Plants | Plant structure |
| Work Centers / Resources | Capacity transfer |
| Orders | Planned + production order sync |
| Stock | Inventory synchronization |

```abap
" Transfer material to APO
CALL FUNCTION 'CIF_MATERIAL_TRANSFER'
  EXPORTING
    i_matnr = lv_matnr  i_werks = lv_werks  i_modus = 'T'
  TABLES  et_return = lt_messages.

" Transfer production order to APO
CALL FUNCTION 'CIF_ORDER_TRANSFER'
  EXPORTING
    i_aufnr = lv_aufnr  i_modus = 'T'  i_object = 'PP'
  TABLES  et_return = lt_messages.
```

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->

Use these as the authoritative baseline when applying this reference:
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/9d794cbd48c648bc8a176e422772de7e?locale=en-US&state=PRODUCTION&version=2608.500
- https://help.sap.com/doc/7c9e0bbbd1664c2581b2038a1c7ae4b3/2608.500/en-US/FSD_CE2608.pdf
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d?locale=en-US&state=PRODUCTION&version=1
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html?locale=en-US&state=PRODUCTION&version=2608.00
