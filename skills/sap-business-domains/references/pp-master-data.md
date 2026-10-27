# PP Master Data — ABAP Reference

## 1. Material Master (PP Views)

### Critical MARC Fields
| Field | Description |
|---|---|
| DISMM | MRP type: PD=MRP, VB=reorder point, ND=no planning |
| DISPO | MRP controller |
| BESKZ | Procurement type: E=in-house, F=external, X=both |
| SOBSL | Special procurement key |
| LGPRO | Default issue storage location |
| MTVFP | Checking group for availability check |
| MINBE | Reorder point quantity |
| EISBE | Safety stock quantity |
| BSTMI | Minimum lot size |
| BSTMA | Maximum lot size |
| BSTFE | Fixed lot size |
| WEBAZ | Goods receipt processing time (days) |
| PLIFZ | Planned delivery time (days) |
| DZEIT | In-house production time (days) |
| FHORI | Scheduling margin key |
| PLNTY | Task list type for routing selection |
| STLAL | BOM alternative |
| STLAN | BOM usage |
| STRGR | Planning strategy group |
| DISLS | Lot sizing procedure |

### Read Material MRP Data

```abap
" ECC / S/4 on-premise
SELECT SINGLE dismm, dispo, beskz, eisbe, minbe,
               bstfe, bstmi, bstma, webaz, plifz,
               dzeit, fhori, disls, strgr, stlal, stlan
  FROM marc
  INTO @DATA(ls_marc)
  WHERE matnr = @lv_matnr
    AND werks = @lv_werks.

" S/4HANA Cloud — released CDS view
SELECT SINGLE Material, MRPType, MRPController,
              ProcurementType, SafetyStockQuantity,
              MinimumLotSizeQuantity, MaximumLotSizeQuantity,
              PlannedDeliveryDurationInDays
  FROM I_MRPMaterial
  INTO @DATA(ls_mrp)
  WHERE Material = @lv_matnr
    AND MRPPlant  = @lv_werks.
```

### BAPI: Read and Update Material Master

```abap
" Read all PP-relevant views
CALL FUNCTION 'BAPI_MATERIAL_GET_DETAIL'
  EXPORTING
    material                    = lv_matnr
    plant                       = lv_werks
  IMPORTING
    materialplantmrp1           = ls_mrp1
    materialplantmrp2           = ls_mrp2
    materialplantmrp3           = ls_mrp3
    materialplantmrp4           = ls_mrp4
    materialplantworkscheduling = ls_wrksched
  TABLES
    return                      = lt_return.

" Update MRP parameters — MRP data goes in PLANTDATA (BAPI_MARC)
DATA: ls_headdata   TYPE bapimathead,
      ls_plantdata  TYPE bapi_marc,
      ls_plantdatax TYPE bapi_marcx.

ls_headdata-material    = lv_matnr.
ls_headdata-mrp_view    = 'X'.
ls_plantdata-plant      = lv_werks.
ls_plantdata-mrp_type   = 'PD'.
ls_plantdata-lotsizekey = 'EX'.
ls_plantdatax-plant      = lv_werks.
ls_plantdatax-mrp_type   = 'X'.
ls_plantdatax-lotsizekey = 'X'.

CALL FUNCTION 'BAPI_MATERIAL_SAVEDATA'
  EXPORTING
    headdata   = ls_headdata
    plantdata  = ls_plantdata
    plantdatax = ls_plantdatax
  TABLES
    returnmessages = lt_return.
CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
```

---

## 2. Bill of Materials (BOM)

### Key Tables
| Table | Description |
|---|---|
| STKO | BOM header |
| STPO | BOM items |
| MAST | Material-to-BOM assignment |
| STAS | BOM item selection |

### STKO Key Fields
| Field | Description |
|---|---|
| STLTY | BOM category (M=material BOM) |
| STLNR | BOM number |
| STLAL | Alternative (01, 02...) |
| STLAN | Usage (1=production, 5=sales) |
| DATUV | Valid from |
| BMENG | Base quantity |

### STPO Key Fields
| Field | Description |
|---|---|
| POSTP | Item category: L=stock, N=non-stock, T=text, R=variable-size |
| IDNRK | Component material |
| MENGE | Component quantity |
| AUSCH | Scrap percentage |
| LGORT | Issue storage location |
| DUMPS | Phantom indicator |
| VORNR | Assigned operation number |

### BOM BAPIs

```abap
" Create BOM
CALL FUNCTION 'CSAP_MAT_BOM_CREATE'
  EXPORTING
    material   = lv_matnr
    plant      = lv_werks
    bom_usage  = '1'
    valid_from = sy-datum
  IMPORTING
    fl_stlnr   = lv_stlnr
    fl_stlal   = lv_stlal
  TABLES
    t_stpo     = lt_bom_items
    return     = lt_return
  EXCEPTIONS
    error      = 1
    OTHERS     = 2.

" Multi-level BOM explosion
CALL FUNCTION 'CS_BOM_EXPL_MAT_V2'
  EXPORTING
    capid = 'PP01'
    datuv = sy-datum
    mtnrv = lv_matnr
    werks = lv_werks
    stlan = '1'
    mehrs = 'X'
  TABLES
    stb   = lt_bom_explo
  EXCEPTIONS
    alt_not_found = 1
    OTHERS        = 2.

" BOM where-used
CALL FUNCTION 'CS_WHERE_USED_MAT'
  EXPORTING
    datub = sy-datum
    datuv = sy-datum
    matnr = lv_comp_matnr
    werks = lv_werks
    stlan = '1'
  TABLES
    wultb = lt_where_used
  EXCEPTIONS OTHERS = 1.
```

---

## 3. Work Centers

### Key Tables
| Table | Description |
|---|---|
| CRHD | Work center header |
| CRCA | Available capacity |
| KAKO | Capacity header |
| KBED | Capacity requirements |

### CRHD Key Fields
| Field | Description |
|---|---|
| OBJID | Internal object ID (use for all joins) |
| ARBPL | Work center ID |
| WERKS | Plant |
| KAPID | Default capacity category: 001=machine, 002=labor |
| KOSTL | Cost center |
| KTSCH | Standard value key |
| LOANZ | Number of individual capacities |

### Work Center ABAP

```abap
" Get internal object ID
CALL FUNCTION 'CR_WORKCENTER_GET_OBJID'
  EXPORTING
    werks = lv_werks
    arbpl = lv_arbpl
  IMPORTING
    objid = lv_objid
  EXCEPTIONS
    not_found = 1
    OTHERS    = 2.

" Read full work center details
CALL FUNCTION 'CR_WORKCENTER_READ_COMPLETE'
  EXPORTING
    objid  = lv_objid
  IMPORTING
    e_crca = ls_capacity
    e_crhd = ls_header
  TABLES
    t_crtx = lt_texts
  EXCEPTIONS
    not_found = 1
    OTHERS    = 2.

" Read capacity requirements
CALL FUNCTION 'CR_CAPACITY_REQUIREMENTS_GET'
  EXPORTING
    objid = lv_objid
    kapid = '001'
    datuv = lv_date_from
    datub = lv_date_to
  TABLES
    t_kbed = lt_cap_req
  EXCEPTIONS
    not_found = 1
    OTHERS    = 2.

" Read available capacity
CALL FUNCTION 'CR_CAPACITY_AVAILABLE_GET'
  EXPORTING
    objid     = lv_objid
    kapid     = '001'
    date_from = lv_date_from
    date_to   = lv_date_to
    time_from = '000000'
    time_to   = '235959'
  IMPORTING
    e_available = lv_avail_hours
  TABLES
    t_capacity  = lt_intervals
  EXCEPTIONS OTHERS = 1.
```

---

## 4. Routings

### Key Tables
| Table | Description |
|---|---|
| PLKO | Routing header |
| PLPO | Operations |
| PLMZ | Component allocation (BOM-routing link) |
| MAPL | Routing-to-material assignment |
| PLFH | Production resources / tools (PRT) |

### PLKO Key Fields
| Field | Description |
|---|---|
| PLNTY | Task list type: N=routing, R=rate routing |
| PLNNR | Routing group number |
| PLNAL | Group counter |
| WERKS | Plant |
| DATUV | Valid from |

### PLPO Key Fields
| Field | Description |
|---|---|
| VORNR | Operation number |
| ARBID | Work center object ID |
| STEUS | Control key: PP01=internal, PP03=subcontract |
| VGW01 | Standard value 1 (setup) |
| VGW02 | Standard value 2 (machine) |
| VGW03 | Standard value 3 (labor) |
| ANZZL | Number of splits |
| PRZNT | Overlap percentage |

### Routing BAPIs

```abap
" Read routing
CALL FUNCTION 'CARO_ROUTING_READ'
  EXPORTING
    e_plnty = 'N'
    e_plnnr = lv_plnnr
    e_plnal = lv_plnal
    e_datuv = sy-datum
  IMPORTING
    e_plko  = ls_routing_header
  TABLES
    t_plpo  = lt_operations
    t_plmz  = lt_comp_alloc
  EXCEPTIONS
    not_found = 1
    OTHERS    = 2.

" Maintain routing
CALL FUNCTION 'CARO_ROUTING_MAINTAIN'
  EXPORTING
    i_plko   = ls_routing_header
  TABLES
    t_plpo   = lt_operations
    t_plpo_x = lt_change_flags
    return   = lt_return
  EXCEPTIONS OTHERS = 1.
```

---

## 5. Production Versions

### MKAL Key Fields
| Field | Description |
|---|---|
| MATNR | Material |
| WERKS | Plant |
| VERID | Version ID (e.g., 0001) |
| ADATU | Valid from |
| BDATU | Valid to |
| MINLOS | Min lot size |
| MAXLOS | Max lot size |
| PLNTY | Task list type |
| PLNNR | Routing group |
| PLNAL | Routing counter |
| STLAL | BOM alternative |
| STLAN | BOM usage |

```abap
" Read valid production versions (ECC / S4 on-premise)
SELECT verid, text1, adatu, bdatu, plnnr, plnal, stlal, minlos, maxlos
  FROM mkal
  INTO TABLE @DATA(lt_pv)
  WHERE matnr = @lv_matnr
    AND werks = @lv_werks
    AND adatu <= @sy-datum
    AND bdatu >= @sy-datum.

" S/4 Cloud — released CDS view
SELECT ProductionVersion, ValidityStartDate, ValidityEndDate,
       ProductionRoutingGroup, BillOfMaterialVariant
  FROM I_ProductionVersion
  WHERE Material = @lv_matnr
    AND Plant     = @lv_werks
  INTO TABLE @DATA(lt_pv_cloud).
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
