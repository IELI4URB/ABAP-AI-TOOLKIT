# PP MRP and Planning — ABAP Reference

## 1. MRP Fundamentals

### Planning Run Types
| Code | Description |
|---|---|
| NETCH | Net change — only materials changed since last run |
| NETPL | Net change within planning horizon only |
| NEUPL | Regenerative — full replanning of all materials |

### Planning Modes
| Mode | Description |
|---|---|
| 1 | Adapt planning data (standard) |
| 2 | Delete and recreate planning data |
| 3 | Delete, re-explode BOM |

### MRP Types (MARC-DISMM)
| Code | Description |
|---|---|
| PD | Standard MRP (deterministic) |
| VB | Reorder point (manual) |
| VM | Reorder point (automatic) |
| ND | No planning |
| P1-P4 | Master Production Scheduling |

### Planning Strategies
| Strategy | Description |
|---|---|
| 10 | Make-to-stock (anonymous) |
| 20 | Make-to-order (order-specific) |
| 25 | Planning without final assembly |
| 40 | Planning with final assembly (variant config) |
| 70 | KANBAN |

### Lot Sizing Keys (MARC-DISLS)
| Key | Description |
|---|---|
| EX | Lot-for-lot |
| FX | Fixed lot size |
| WB | Weekly batches |
| MB | Monthly batches |
| HB | Replenish to max stock level |
| GR | Groff reorder procedure |
| LF | Least unit cost |

---

## 2. Key MRP Tables

| Table | Description |
|---|---|
| MDTB | MRP element table |
| PLAF | Planned orders |
| MDKP | MRP document header |
| RESB | Reservations / dependent requirements |
| VBBS | Sales requirements |
| PBHI | Planning file entries |
| PBIM | Independent requirements per material |
| PBED | PIR dates and quantities |

### PLAF Key Fields
| Field | Description |
|---|---|
| PLNUM | Planned order number |
| MATNR | Material |
| WERKS | Plant |
| PSTTR | Scheduled start date |
| PEDTR | Scheduled finish date |
| PSMNG | Planned quantity |
| VERID | Production version |
| DISPO | MRP controller |
| PLNNR | Routing group |
| STLNR | BOM number |

---

## 3. MRP Classic — Function Modules

```abap
" Lock material before planning
CALL FUNCTION 'MD_SET_PLANNING_LOCK'
  EXPORTING  werks = lv_werks  matnr = lv_matnr.

" Execute MRP run
CALL FUNCTION 'MD_SET_PLANNING_RUN'
  EXPORTING
    plant          = lv_werks
    material       = lv_matnr
    processing_key = 'NETCH'
    create_poreq   = '2'   " 2=always create
    create_mrl     = 'X'
    planning_mode  = '1'
    scheduling     = '2'   " 2=lead-time scheduling
  EXCEPTIONS
    no_authority   = 1
    OTHERS         = 2.

" Unlock after planning
CALL FUNCTION 'MD_UNSET_PLANNING_LOCK'
  EXPORTING  werks = lv_werks  matnr = lv_matnr.

" Convert planned order to production order
CALL FUNCTION 'BAPI_PRODORD_CREATE_FROM_PLORD'
  EXPORTING  planned_order = lv_plnum
  IMPORTING  order_number  = lv_aufnr
  TABLES     return        = lt_return.

READ TABLE lt_return INTO DATA(ls_err) WITH KEY type = 'E'.
IF sy-subrc <> 0.
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
ELSE.
  CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
ENDIF.

" Read MRP stock/requirements list
CALL FUNCTION 'MD_STOCK_REQUIREMENTS_LIST_API'
  EXPORTING  matnr = lv_matnr  werks = lv_werks
  TABLES     mdezx = lt_mrp_elements  mdkpx = lt_headers
  EXCEPTIONS OTHERS = 1.

" MDEZX-DELKZ element types:
" PE=PIR  BS=Safety stock  OC=Production order
" FS=Firmed planned order  WE=Scheduled GR  RE=Reservation
```

---

## 4. Planned Independent Requirements (PIRs)

```abap
" Create PIRs
DATA: lt_pir_in  TYPE TABLE OF bapipir1,
      lt_pir_out TYPE TABLE OF bapipir2,
      lt_return  TYPE TABLE OF bapiret2.

APPEND VALUE bapipir1(
  material = lv_matnr  plant    = lv_werks
  req_date = lv_date   req_qty  = lv_qty
  version  = '00'      active   = 'X'
) TO lt_pir_in.

CALL FUNCTION 'BAPI_REQUIREMENTS_CREATE'
  TABLES
    bapirequirementschangein  = lt_pir_in
    bapirequirementschangeout = lt_pir_out
    return                    = lt_return.

READ TABLE lt_return INTO DATA(ls_e) WITH KEY type = 'E'.
IF sy-subrc <> 0.
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
ENDIF.

" Delete PIRs
CALL FUNCTION 'BAPI_REQUIREMENTS_REMOVE'
  EXPORTING
    material = lv_matnr  plant   = lv_werks
    req_date = lv_date   version = '00'
  TABLES  return = lt_return.
CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
```

---

## 5. MRP Live (S/4HANA)

### Classic vs MRP Live
| Aspect | Classic MRP | MRP Live |
|---|---|---|
| Transaction | MD01/MD02 | MD01N |
| Engine | Sequential, DB-heavy | Parallel, HANA in-memory |
| BOM explosion | Sequential | Parallel multi-level |
| Performance | Minutes to hours | Seconds to minutes |
| PP/DS integration | Via planned orders | Direct pegging |

```abap
" Trigger MRP Live for single material
CALL FUNCTION 'MRP_MRPRUN_START'
  EXPORTING
    i_plant         = lv_werks
    i_mrp_run_mode  = 'NET_CHANGE'
    i_plan_horizon  = 90
    i_scope         = 'SINGLE_MATERIAL'
    i_material      = lv_matnr
  TABLES
    et_messages     = lt_messages
  EXCEPTIONS OTHERS = 1.
```

### MRP Live BAdIs
| BAdI | Purpose |
|---|---|
| MD_MRP_PLIVE_POSTPROCESS | Post-process results |
| MD_MRP_PLIVE_ORDER_PROPS | Modify planned order properties |
| MRP_PLIVE_BOM_SELECTION | Custom BOM selection |
| MRP_PLIVE_ROUTING_SEL | Custom routing selection |

```abap
" BAdI: modify planned order in MRP Live
CLASS zcl_mrplive_order_props DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_mrp_plive_order_props.
ENDCLASS.
CLASS zcl_mrplive_order_props IMPLEMENTATION.
  METHOD if_mrp_plive_order_props~modify_planned_order.
    IF cs_planned_order-quantity >= 500.
      cs_planned_order-production_version = '0002'.
    ELSE.
      cs_planned_order-production_version = '0001'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```

---

## 6. Classic MRP BAdIs

| BAdI | Interface | Purpose |
|---|---|---|
| MD_CHANGE_MRP_DATA | IF_MD_CHANGE_MRP_DATA | Modify MRP params before run |
| MD_PLDORD_CHANGE | IF_MD_PLDORD_CHANGE | Modify planned orders during run |
| MD_ADD_CON | IF_MD_ADD_CON | Add planning constraints |
| MD_REORDER_POINT | IF_MD_REORDER_POINT | Custom reorder point calculation |
| MD_MRP_STRAT | IF_MD_MRP_STRAT | Custom planning strategy logic |

```abap
" BAdI: modify planned order during MRP
CLASS zcl_md_pldord_change DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_md_pldord_change.
ENDCLASS.
CLASS zcl_md_pldord_change IMPLEMENTATION.
  METHOD if_md_pldord_change~pldord_change.
    " Force production version for specific plant
    IF cs_plaf-werks = 'P001'.
      cs_plaf-verid = '0001'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```

---

## 7. IBP Integration

### Architecture
```
IBP Demand Plan  --[CPI/BTP Integration]--> S/4HANA PIRs
IBP Supply Plan  --[CPI/BTP Integration]--> S/4HANA Planned Orders
S/4 Stock/Orders --[OData or CIF]------> IBP supply view
```

### IBP Supply Plan BAdI

```abap
CLASS zcl_pp_ibp_supply DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_pp_ibp_supply_plan.
ENDCLASS.
CLASS zcl_pp_ibp_supply IMPLEMENTATION.
  METHOD if_pp_ibp_supply_plan~post_process_supply_plan.
    LOOP AT ct_supply_plan ASSIGNING FIELD-SYMBOL(<ls>).
      " Snap to production version minimum lot size
      SELECT SINGLE minlos FROM mkal
        INTO @DATA(lv_min)
        WHERE matnr = @<ls>-matnr
          AND werks = @<ls>-werks
          AND verid = @<ls>-verid.
      IF sy-subrc = 0 AND <ls>-quantity < lv_min.
        <ls>-quantity = lv_min.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

### OData APIs for IBP-PP
| API | Purpose |
|---|---|
| API_PLANNED_ORDERS | Manage planned orders |
| API_MRP_MATERIALS_SRV | Read MRP material parameters |
| API_REQUIREMENTS_SRV | Manage PIRs |
| API_PRODUCTION_ORDERS_SRV | Production order status |

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
