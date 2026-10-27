# PP Production Orders and Process Orders — ABAP Reference

## 1. Production Order Lifecycle

```
Create(CO01) -> Release(CO02) -> Goods Issue(MIGO-261)
-> Confirm Operations(CO11N) -> Goods Receipt(MIGO-101)
-> TECO(CO02) -> Settlement(KO88) -> Close(CLSD)
```

### Order Status Codes (JEST-STAT)
| Status | Description |
|---|---|
| I0001 | CRTD — Created |
| I0002 | REL — Released |
| I0010 | PCNF — Partially confirmed |
| I0009 | CNF — Confirmed |
| I0012 | DLV — Delivery completed |
| I0045 | TECO — Technically complete |
| I0046 | CLSD — Closed |
| I0076 | DLT — Deleted |

```abap
" Check order status
SELECT SINGLE objnr FROM aufk INTO @DATA(lv_objnr)
  WHERE aufnr = @lv_aufnr.

SELECT stat FROM jest INTO TABLE @DATA(lt_status)
  WHERE objnr = @lv_objnr AND inact = ' '.

IF line_exists( lt_status[ stat = 'I0002' ] ).  " Released
ENDIF.
```

---

## 2. Key Production Order Tables

| Table | Description |
|---|---|
| AFKO | Order header |
| AFPO | Order items |
| AFVC | Operations |
| AFVV | Operation quantities, times, dates |
| AFFL | Work flow / sequence |
| AUFK | Order master data |
| RESB | Component reservations |
| JEST | Individual object status |

### AFKO Key Fields
| Field | Description |
|---|---|
| AUFNR | Order number |
| AUFART | Order type (PP01, PP02) |
| MATNR | Material |
| WERKS | Plant |
| GSTRS | Scheduled start date |
| GLTRS | Scheduled finish date |
| FTRMS | Basic start date |
| FLTRS | Basic finish date |
| IGMNG | Target quantity |
| GMEIN | Unit of measure |
| VERID | Production version |

### AFPO Key Fields
| Field | Description |
|---|---|
| AUFNR | Order number |
| POSNR | Item number |
| MATNR | Material |
| KDAUF | Sales order (MTO link) |
| KDPOS | Sales order item (MTO link) |
| LGORT | Storage location |
| WEMNG | GR quantity |
| PSMNG | Planned quantity |

### AFVC Key Fields
| Field | Description |
|---|---|
| AUFNR | Order number |
| APLZL | Internal operation counter |
| VORNR | Operation number |
| ARBID | Work center object ID |
| STEUS | Control key |
| MGVRB | Confirmed quantity |

---

## 3. Production Order BAPIs

### Create

```abap
DATA: ls_header TYPE bapi_pp_order_header,
      lt_return TYPE TABLE OF bapiret2.

ls_header-material   = lv_matnr.
ls_header-plant      = lv_werks.
ls_header-order_type = 'PP01'.
ls_header-basic_end  = lv_req_date.
ls_header-quantity   = lv_qty.
ls_header-unit       = lv_uom.
ls_header-sched_type = '2'.   " 2=backward
ls_header-version    = lv_verid.

CALL FUNCTION 'BAPI_PRODORD_CREATE'
  EXPORTING  orderdata    = ls_header
  IMPORTING  order_number = lv_aufnr
  TABLES     return       = lt_return.
READ TABLE lt_return INTO DATA(ls_e) WITH KEY type = 'E'.
IF sy-subrc <> 0.
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
ENDIF.
```

### Read

```abap
CALL FUNCTION 'BAPI_PRODORD_GET_DETAIL'
  EXPORTING
    number          = lv_aufnr
    plant           = lv_werks
  IMPORTING
    orderdata       = ls_order_header
  TABLES
    res_components  = lt_components
    operations      = lt_operations
    return          = lt_return.
```

### Release

```abap
CALL FUNCTION 'BAPI_PRODORD_RELEASE'
  EXPORTING  number = lv_aufnr
  TABLES     detail_return = lt_return.
CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
```

### Confirm Operation

```abap
DATA: ls_tt    TYPE bapi_pp_timeticket,
      lt_gsmvt TYPE TABLE OF bapi_pp_goodsmovements,
      lt_ret   TYPE TABLE OF bapiret2.

ls_tt-orderid        = lv_aufnr.
ls_tt-operation      = lv_vornr.
ls_tt-plant          = lv_werks.
ls_tt-work_center    = lv_arbpl.
ls_tt-conf_quant     = lv_conf_qty.
ls_tt-conf_unit      = lv_uom.
ls_tt-act_setup_time = lv_setup_hrs.
ls_tt-act_machtime   = lv_machine_hrs.
ls_tt-act_labtime    = lv_labor_hrs.
ls_tt-final_conf     = 'X'.
ls_tt-postg_date     = sy-datum.

CALL FUNCTION 'BAPI_PRODORDCONF_CREATE_TT'
  EXPORTING  timeticket     = ls_tt
  TABLES     goodsmovements = lt_gsmvt  return = lt_ret.
CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
```

### Cancel a Confirmation

```abap
CALL FUNCTION 'BAPI_PRODORDCONF_CANCEL'
  EXPORTING  conf_no = lv_conf_no
  TABLES     return  = lt_return.
CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
```

---

## 4. Process Orders (PP-PI)

### Production Order vs Process Order
| Aspect | Production Order | Process Order |
|---|---|---|
| Transaction | CO01 | COR1 |
| Used for | Discrete manufacturing | Chemical, pharma, food |
| Routing | Standard routing | Master recipe |
| Operations | Operations | Phases |
| PI Sheets | Not used | Yes |
| GxP Signature | Not required | Required |

### Process Instruction Categories
| Category | Description |
|---|---|
| I | Input values (set parameters to equipment) |
| O | Output values (record results from equipment) |
| C | Calculated values |
| M | Message / text displayed to operator |
| R | Signature required |

### Create Process Order

```abap
DATA: ls_header TYPE bapi_pp_order_header,
      lt_return TYPE TABLE OF bapiret2.

ls_header-material   = lv_matnr.
ls_header-plant      = lv_werks.
ls_header-order_type = 'PI01'.   " Process order type
ls_header-basic_end  = lv_req_date.
ls_header-quantity   = lv_qty.
ls_header-unit       = lv_uom.

CALL FUNCTION 'BAPI_PROCORD_CREATE'
  EXPORTING  orderdata    = ls_header
  IMPORTING  order_number = lv_aufnr
  TABLES     return       = lt_return.
CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
```

### Generate PI Sheet

PI sheets / control recipes are not created by a standalone released BAPI. They are generated through **control recipe determination**: configure the control recipe destination and generate via transaction **CO60** (or the control-recipe generation step `COCF`/background job). In ABAP, trigger generation through the process-order functions; there is no `CPIP_PI_SHEET_CREATE` BAPI — verify the available control-recipe API for your release before coding.

---

## 5. KANBAN

### Architecture
- **Supply area**: consumption zone where material is pulled
- **KANBAN card**: replenishment signal unit
- **Control cycle**: links supply area, material, replenishment strategy
- **Replenishment strategies**: production order, purchase order, stock transfer, in-house Kanban

### Key Tables
| Table | Description |
|---|---|
| PKPS | KANBAN control cycle |
| PKPSI | KANBAN card items |

### Set KANBAN Status

```abap
" nextstatus is a BAPI1075 status code (e.g. '2' = EMPTY, '5' = FULL);
" check the status values for your configuration.
CALL FUNCTION 'BAPI_KANBAN_CHANGESTATUS1'
  EXPORTING
    kanbanidnumber     = lv_kanban_id
    nextstatus         = lv_next_status
  IMPORTING
    return             = ls_return
  TABLES
    statuschangeresult = lt_result.
CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
```

---

## 6. Repetitive Manufacturing

### Key Tables
| Table | Description |
|---|---|
| S025 | Run schedule header |
| S026 | Run schedule item quantities |
| MKAL | Production version (links to repetitive mfg) |

### Backflushing

```abap
" Post repetitive manufacturing backflush
CALL FUNCTION 'MFBF_BACKFLUSH'
  EXPORTING
    i_matnr      = lv_matnr
    i_werks      = lv_werks
    i_verid      = lv_verid
    i_qty        = lv_qty
    i_pstng_date = sy-datum
    i_move_type  = '131'   " 131=GR for replenishment order
  TABLES
    t_return     = lt_return
  EXCEPTIONS OTHERS = 1.
CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
```

### Create Run Schedule Quantity

```abap
CALL FUNCTION 'BAPI_REPMANCONF1_CREATE_MTS'
  EXPORTING
    plant              = lv_werks
    material           = lv_matnr
    production_version = lv_verid
    posting_date       = sy-datum
    backflush_quant    = lv_qty
    backflush_uom      = lv_uom
  TABLES
    return             = lt_return.
CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
```

---

## 7. Order Settlement (CO Integration)

Production/process order settlement is **not** a standalone released BAPI (`KB_BAPI_SETTLEMENT_RUN` does not exist). Settle via the standard transactions / jobs:
- **KO88** — individual order settlement.
- **CO88** — collective settlement run.
- Schedule as a periodic background job (settlement period / fiscal year as selection parameters).

After settlement, check variance categories (target vs actual) on the order.

```abap
" Settlement itself is run via KO88/CO88 (or their batch programs), not a BAPI.
" Read settlement/variance results afterwards from the order's cost documents.
SELECT aufnr, versn, wtgbtr
  FROM cosb
  INTO TABLE @DATA(lt_variances)
  WHERE aufnr = @lv_aufnr
    AND gjahr = @lv_gjahr.
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
