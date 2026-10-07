# MM Released Objects — Full Reference

## 1. Reading MM Data with ABAP SQL + CDS

### Read Open Purchase Orders for a Plant
```abap
SELECT po~PurchaseOrder,
       po~Supplier,
       po~CompanyCode,
       poi~Material,
       poi~Plant,
       poi~OrderQuantity,
       poi~NetPriceAmount,
       poi~PurchaseOrderCurrency
  FROM I_PurchaseOrder AS po
  INNER JOIN I_PurchaseOrderItem AS poi
    ON po~PurchaseOrder = poi~PurchaseOrder
  WHERE poi~Plant           = @iv_plant
    AND po~PurchaseOrderType <> 'STPO'  " exclude stock transport orders
    AND poi~OrderQuantity   > poi~GoodsReceiptQuantity  " open quantity
  INTO TABLE @DATA(lt_open_pos).
```

### Read Current Stock Levels
```abap
SELECT Material,
       Plant,
       StorageLocation,
       MatlWrhsStkQtyInMatlBaseUnit AS StockQty,
       MaterialBaseUnit
  FROM I_InventoryBalance
  WHERE Plant           = @iv_plant
    AND StorageLocation = @iv_sloc
    AND MatlWrhsStkQtyInMatlBaseUnit > 0
  ORDER BY Material
  INTO TABLE @DATA(lt_stock).
```

### Read Material Document (Goods Movement History)
```abap
SELECT h~MaterialDocument,
       h~MaterialDocumentYear,
       h~PostingDate,
       i~Material,
       i~Plant,
       i~StorageLocation,
       i~MovementType,
       i~QuantityInBaseUnit,
       i~BaseUnit
  FROM I_MaterialDocumentHeader AS h
  INNER JOIN I_MaterialDocumentItem AS i
    ON  h~MaterialDocument     = i~MaterialDocument
    AND h~MaterialDocumentYear = i~MaterialDocumentYear
  WHERE h~PostingDate BETWEEN @lv_from AND @lv_to
    AND i~Plant     = @iv_plant
    AND i~Material  = @iv_material
  ORDER BY h~PostingDate DESCENDING
  INTO TABLE @DATA(lt_movements).
```

## 2. Consuming MM OData APIs from ABAP

### Post Goods Receipt via API_MATERIAL_DOCUMENT_SRV
```abap
" Build JSON payload for GR against PO
DATA(lv_payload) = |\{|
  && |"PostingDate":"{ iv_posting_date+0(4) }-{ iv_posting_date+4(2) }-{ iv_posting_date+6(2) }",|
  && |"DocumentDate":"{ iv_posting_date+0(4) }-{ iv_posting_date+4(2) }-{ iv_posting_date+6(2) }",|
  && |"MaterialDocumentHeaderText":"GR for PO { iv_po_number }",|
  && |"to_MaterialDocumentItem":\{|
  && |"results":[\{|
  && |"DocumentItemText":"Item 001",|
  && |"Material":"{ iv_material }",|
  && |"Plant":"{ iv_plant }",|
  && |"StorageLocation":"{ iv_sloc }",|
  && |"MovementType":"101",|
  && |"PurchaseOrder":"{ iv_po_number }",|
  && |"PurchaseOrderItem":"{ iv_po_item }",|
  && |"QuantityInBaseUnit":"{ iv_qty }",|
  && |"BaseUnit":"{ iv_base_unit }"|
  && |\}]\}\}|.

DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
  comm_scenario = 'Z_MM_MATDOC_SCENARIO' ).
DATA(lo_client)  = cl_web_http_client_manager=>create_by_destination( lo_destination ).
DATA(lo_request) = lo_client->get_http_request( ).
lo_request->set_method( if_web_http_client=>post ).
lo_request->set_uri_path( '/sap/opu/odata/sap/API_MATERIAL_DOCUMENT_SRV/A_MaterialDocumentHeader' ).
lo_request->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
lo_request->set_text( lv_payload ).
DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).
```

## 3. Goods Movement — Tier 2 Wrapper

### Interface (released C1 — ABAP Cloud)
```abap
INTERFACE zif_mm_goods_movement.
  TYPES: BEGIN OF ty_item,
           material       TYPE matnr,
           plant          TYPE werks_d,
           storage_loc    TYPE lgort_d,
           movement_type  TYPE bwart,
           quantity       TYPE menge_d,
           unit           TYPE meins,
           purchase_order TYPE ebeln,
           po_item        TYPE ebelp,
         END OF ty_item.
  TYPES tt_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

  METHODS post_movement
    IMPORTING iv_posting_date TYPE dats
              iv_doc_text     TYPE bktxt
              it_items        TYPE tt_items
    RETURNING VALUE(rv_mat_doc) TYPE mblnr
    RAISING   zcx_goods_movement_error.
ENDINTERFACE.
```

### Tier 2 Wrapper (Standard ABAP — NOT ABAP Cloud)
```abap
CLASS zcl_mm_goods_movement DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_mm_goods_movement.
ENDCLASS.

CLASS zcl_mm_goods_movement IMPLEMENTATION.
  METHOD zif_mm_goods_movement~post_movement.
    DATA ls_header   TYPE bapi2017_gm_head_01.
    DATA lt_items    TYPE TABLE OF bapi2017_gm_item_create.
    DATA lt_return   TYPE TABLE OF bapiret2.
    DATA ls_mat_doc  TYPE bapi2017_gm_head_ret.

    ls_header-pstng_date = iv_posting_date.
    ls_header-doc_date   = iv_posting_date.
    ls_header-header_txt = iv_doc_text.
    ls_header-ref_doc_no = iv_doc_text.

    LOOP AT it_items INTO DATA(ls_item).
      APPEND VALUE bapi2017_gm_item_create(
        material    = ls_item-material
        plant       = ls_item-plant
        stge_loc    = ls_item-storage_loc
        move_type   = ls_item-movement_type
        entry_qnt   = ls_item-quantity
        entry_uom   = ls_item-unit
        po_number   = ls_item-purchase_order
        po_item     = ls_item-po_item ) TO lt_items.
    ENDLOOP.

    CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
      EXPORTING  goodsmvt_header  = ls_header
                 goodsmvt_code    = '01'   " GR for PO
      IMPORTING  goodsmvt_headret = ls_mat_doc
      TABLES     goodsmvt_item    = lt_items
                 return           = lt_return.

    DATA(lt_errors) = FILTER #( lt_return WHERE type = 'E' OR type = 'A' ).
    IF lt_errors IS NOT INITIAL.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_goods_movement_error
        EXPORTING messages = lt_errors.
    ENDIF.

    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
    rv_mat_doc = ls_mat_doc-mat_doc.
  ENDMETHOD.
ENDCLASS.
```

## 4. Key MM Extension Points

### BAdIs
| BAdI | Description |
|---|---|
| `MB_DOCUMENT_BADI` | Enhancement during goods movement posting |
| `ME_PROCESS_PO_CUST` | Enhance PO processing |
| `ME_REQ_POSTED` | After purchase requisition save |
| `BADI_MATVAL_PRICE_CHANGE` | Material valuation price change |

### S/4HANA MM Simplifications vs ECC
| ECC Table | S/4HANA Replacement | Note |
|---|---|---|
| `MKPF` + `MSEG` | `MATDOC` | Single document table |
| `MARD` (plant stock) | `MARD` still exists but use `I_InventoryBalance` | CDS view preferred |
| `EKKO` + `EKPO` | Same tables, use `I_PurchaseOrder` CDS | CDS view preferred for reads |
| `BSEG` FI split | `ACDOCA` | New universal journal — no more BSEG split |

## 5. MM Released API Summary Table

| Object Type | Name | Purpose | Release |
|---|---|---|---|
| CDS View | `I_PurchaseOrder` | PO header | C1 |
| CDS View | `I_PurchaseOrderItem` | PO line items | C1 |
| CDS View | `I_GoodsMovement` | Goods movement | C1 |
| CDS View | `I_MaterialDocumentItem` | Material doc items | C1 |
| CDS View | `I_Material` | Material master | C1 |
| CDS View | `I_InventoryBalance` | Stock levels | C1 |
| OData API | `API_PURCHASEORDER_PROCESS_SRV` | PO R/W | Released |
| OData API | `API_MATERIAL_DOCUMENT_SRV` | GR/GI posting | Released |
| BAPI (Tier 2) | `BAPI_GOODSMVT_CREATE` | Goods movement | Tier 2 only |
| BAPI (Tier 2) | `BAPI_PO_CREATE1` | Create PO | Tier 2 only |
