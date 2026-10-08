# PP ABAP Development — BAdIs, Exits, Released APIs, RAP, CDS

## 1. Complete PP BAdI Catalog

### Production Order BAdIs
| BAdI | Interface | Purpose |
|---|---|---|
| WORKORDER_UPDATE | IF_EX_WORKORDER_UPDATE | Before/after production order save |
| WORKORDER_GOODSMVT | IF_EX_WORKORDER_GOODSMVT | Before/after goods movement for order |
| WORKORDER_SCHEDULE | IF_EX_WORKORDER_SCHEDULE | Before/after order scheduling |
| CO_XT_CALL_UP | IF_EX_CO_XT_CALL_UP | Trigger business function from order |
| ORDER_CHANGE_MGMT | IF_EX_ORDER_CHANGE_MGMT | Order change management |
| CONF_AFFW | IF_EX_CONF_AFFW | Before/after order confirmation |
| GOODS_MOVEMENT_CREATE | IF_EX_GOODS_MOVEMENT_CREATE | Goods movement enhancement |

### MRP BAdIs
| BAdI | Interface | Purpose |
|---|---|---|
| MD_CHANGE_MRP_DATA | IF_MD_CHANGE_MRP_DATA | Modify MRP parameters before planning |
| MD_PLDORD_CHANGE | IF_MD_PLDORD_CHANGE | Modify planned orders during MRP |
| MD_ADD_CON | IF_MD_ADD_CON | Add additional planning constraints |
| MD_EXT_SUP | IF_MD_EXT_SUP | External supply element processing |
| MD_REORDER_POINT | IF_MD_REORDER_POINT | Custom reorder point calculation |
| MD_MRP_STRAT | IF_MD_MRP_STRAT | Custom planning strategy logic |
| MD_MRP_PLIVE_POSTPROCESS | IF_MRP_PLIVE_POSTPROCESS | Post-process MRP Live results |
| MD_MRP_PLIVE_ORDER_PROPS | IF_MRP_PLIVE_ORDER_PROPS | Modify MRP Live planned orders |
| MRP_PLIVE_BOM_SELECTION | IF_MRP_PLIVE_BOM_SEL | Custom BOM selection in MRP Live |
| MRP_PLIVE_ROUTING_SEL | IF_MRP_PLIVE_ROUTING | Custom routing selection in MRP Live |

### PP/DS BAdIs
| BAdI | Interface | Purpose |
|---|---|---|
| /SAPAPO/PPDS_ORDER_CHANGE | /SAPAPO/IF_PPDS_ORDER_CHG | Before/after PP/DS order change |
| /SAPAPO/PPDS_ORDER_CREATE | /SAPAPO/IF_PPDS_ORDER_CRT | Before/after PP/DS order creation |
| /SAPAPO/PPDS_HEU_IMPLEMENT | /SAPAPO/IF_PPDS_HEU_EXECUTE | Custom heuristic implementation |
| /SAPAPO/PPDS_ALERT_CREATE | /SAPAPO/IF_PPDS_ALERT | Custom PP/DS alert generation |
| /SAPAPO/PPDS_SCHED_CHECK | /SAPAPO/IF_PPDS_SCHED | Scheduling constraint validation |
| /SAPAPO/OM_PROD_PLANNING | /SAPAPO/IF_OM_PROD_PLAN | Production planning lifecycle |
| /SAPAPO/RES_CHECK_AVAIL | /SAPAPO/IF_RES_AVAIL | Custom resource availability check |

### Capacity Planning BAdIs
| BAdI | Interface | Purpose |
|---|---|---|
| SCHEDULING_STRATEGY | IF_EX_SCHEDULING_STRATEGY | Custom scheduling strategy |
| CAPACITY_REQUIREMENTS | IF_EX_CAPACITY_REQ | Modify capacity requirement creation |
| CM_CHG_PROP_ORDERS | IF_EX_CM_CHG_PROP_ORDERS | Change order proposal in CM |

### BOM and Routing BAdIs
| BAdI | Interface | Purpose |
|---|---|---|
| MB_DOCUMENT_BADI | IF_EX_MB_DOCUMENT_BADI | Goods movement document enhancement |
| CS_BOM_EXPL | IF_EX_CS_BOM_EXPL | BOM explosion enhancement |
| ROUTING_CHECK | IF_EX_ROUTING_CHECK | Custom routing validation |

---

## 2. Classic User Exits (CMOD)

### Production Order User Exits
| Exit | Function Exit | Description |
|---|---|---|
| PPCO0001 | EXIT_SAPLCOAS_001 | Order header — additional data |
| PPCO0002 | EXIT_SAPLCOAS_002 | Order header — check on save |
| PPCO0004 | EXIT_SAPLCOAS_004 | Operation — additional data |
| PPCO0005 | EXIT_SAPLCOAS_005 | Component — additional data |
| PPCO0006 | EXIT_SAPLCOAS_006 | Trigger action on order |
| PPCO0007 | EXIT_SAPLCOAS_007 | Before order release |
| PPCO0009 | EXIT_SAPLCOAS_009 | Read additional data |

### MRP User Exits
| Exit | Function Exit | Description |
|---|---|---|
| M61X0001 | EXIT_SAPMM61X_001 | Modify planned order during MRP |
| M61X0002 | EXIT_SAPMM61X_002 | Modify purchase requisition in MRP |
| MDVP0001 | EXIT_SAPMMRP0_001 | Planning run preprocessing |

### Confirmation User Exits
| Exit | Function Exit | Description |
|---|---|---|
| CONF0001 | EXIT_SAPLCORF_001 | Before confirmation |
| CONF0002 | EXIT_SAPLCORF_002 | After confirmation |
| CONF0010 | EXIT_SAPLCORF_010 | Goods movement at confirmation |

---

## 3. Production Order BAdI Implementation Example

```abap
" BAdI: WORKORDER_UPDATE — validate before order save
CLASS zcl_pp_order_update DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_ex_workorder_update.
ENDCLASS.

CLASS zcl_pp_order_update IMPLEMENTATION.
  METHOD if_ex_workorder_update~before_update.
    " im_aufnr = order number being saved
    " Validate production version is assigned
    SELECT SINGLE verid FROM afko
      INTO @DATA(lv_verid)
      WHERE aufnr = @im_aufnr.
    IF lv_verid IS INITIAL.
      MESSAGE e001(zpp) WITH im_aufnr
        INTO DATA(lv_msg).
      RAISE EXCEPTION TYPE cx_bo_error
        EXPORTING
          textid = cx_bo_error=>general
          text   = lv_msg.
    ENDIF.
  ENDMETHOD.

  METHOD if_ex_workorder_update~after_update.
    " Log order save event
    DATA(lo_log) = cl_bali_log=>create(
      i_object     = 'ZPP'
      i_subobject  = 'ORDER_SAVE'
    ).
    DATA(lo_msg) = cl_bali_free_text=>create(
      i_severity = if_bali_constants=>c_severity_information
      i_text     = |Order { im_aufnr } saved at { sy-datum }|
    ).
    lo_log->add_item( lo_msg ).
    cl_bali_log_db=>get_instance( )->save_log(
      i_log                        = lo_log
      i_assign_to_current_appl_log = abap_true
    ).
  ENDMETHOD.
ENDCLASS.
```

---

## 4. Released C1 APIs for S/4HANA Cloud (PP)

### CDS Views (Read)
| CDS View | Description |
|---|---|
| I_ProductionOrder | Production order header |
| I_ProductionOrderItem | Production order item |
| I_ProductionOrderOperation | Production order operations |
| I_ProductionOrderComponent | Production order components |
| I_PlannedOrder | Planned orders |
| I_PlannedOrderComponent | Planned order components |
| I_ProductionVersion | Production versions |
| I_BillOfMaterial | BOM header |
| I_BillOfMaterialItem | BOM items |
| I_BillOfMaterialExplodedItem | Multi-level BOM explosion |
| I_WorkCenter | Work center header |
| I_WorkCenterCapacity | Work center capacity |
| I_MRPMaterial | Material MRP parameters |
| I_PlannedIndepRqmt | Planned independent requirements |
| I_MfgOrderConfirmation | Order confirmations |

### OData V2/V4 APIs
| API | Version | Description |
|---|---|---|
| API_PRODUCTION_ORDERS_SRV | V2 | CRUD production orders |
| API_PLANNED_ORDERS | V2 | Manage planned orders |
| API_MRP_MATERIALS_SRV | V2 | Read MRP material data |
| API_REQUIREMENTS_SRV | V2 | Manage PIRs |
| API_BILL_OF_MATERIAL_SRV | V2 | BOM read |
| API_WORK_CENTER_SRV | V2 | Work center read |
| API_PRODUCTION_ROUTING | V2 | Routing read |
| API_PRODUCTION_VERSION | V2 | Production version read |
| API_PROD_ORDER_CONFIRMATION | V2 | Order confirmations |

---

## 5. RAP Business Objects for PP (S/4HANA Cloud)

### Available RAP BOs
| RAP BO | Description |
|---|---|
| I_ProductionOrder | Production order (read/update/actions) |
| I_PlannedOrder | Planned order (CRUD) |
| I_BillOfMaterial | BOM management |
| I_ProductionRouting | Routing management |
| I_WorkCenter | Work center management |

### RAP: Read Production Orders

```abap
" Use EML (Entity Manipulation Language)
DATA: lt_orders TYPE TABLE FOR READ IMPORT i_productionorder.

APPEND VALUE #( productionorder = lv_aufnr ) TO lt_orders.

READ ENTITIES OF i_productionorder
  ENTITY productionorder
  FIELDS ( productionorder material plant scheduledbasicenddate
           manufacturedquantity productionordertype )
  WITH lt_orders
  RESULT DATA(lt_result)
  FAILED DATA(lt_failed)
  REPORTED DATA(lt_reported).

IF lt_failed IS INITIAL.
  READ TABLE lt_result INTO DATA(ls_order) INDEX 1.
ENDIF.
```

### RAP: Release Production Order (Action)

```abap
DATA: lt_keys TYPE TABLE FOR ACTION IMPORT
        i_productionorder~release.

APPEND VALUE #( productionorder = lv_aufnr ) TO lt_keys.

MODIFY ENTITIES OF i_productionorder
  ENTITY productionorder
  EXECUTE release
  FROM lt_keys
  RESULT DATA(lt_result)
  FAILED DATA(lt_failed)
  REPORTED DATA(lt_reported).

IF lt_failed IS INITIAL.
  COMMIT ENTITIES.
ENDIF.
```

### RAP: Custom Extension on Production Order

```abap
" 1. Define extension in BDEF
" extend behavior for I_ProductionOrder with ZI_ProdOrderExt
"   { field ZCustomField; }

" 2. Create custom CDS extension
@AbapCatalog.extensibility: {
  allowNewDatasources: true,
  dataSources: ['I_ProductionOrder']
}
extend view entity I_
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
