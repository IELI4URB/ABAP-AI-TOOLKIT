# BAdIs and Enhancements

### 7. Cloud BAdI Implementation

#### 7.1 Finding Available BAdIs

1. Open **SAP Business Accelerator Hub** → search for your BO / transaction area.
2. Filter by **Extension Points / BAdIs**.
3. Each BAdI entry shows: Enhancement Spot name, interface name, filter conditions, and documentation.

Alternatively, in ADT: **Ctrl+Shift+A** → search `BADI_*` → open Enhancement Spot `ES_*` to see all BAdIs in a functional area.

#### 7.2 Enhancement Spot and BAdI Implementation

```abap
" Step 1: In ADT, create Enhancement Implementation
"         Parent: Enhancement Spot  ES_SD_SALES_ORDER_BP
"         BAdI:   BADI_SD_SALES_ORDER_BEFORE_SAVE
"         Implementation Class:  ZCL_BADI_SO_BEFORE_SAVE_IMPL

CLASS zcl_badi_so_before_save_impl DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_badi_interface.
    INTERFACES if_sd_so_before_save.   " generated from BAdI definition

ENDCLASS.

CLASS zcl_badi_so_before_save_impl IMPLEMENTATION.

  METHOD if_sd_so_before_save~validate_before_save.
    " iv_sales_order_data: structure with all sales order fields
    " ct_messages: add validation errors here
    " rv_reject: set to abap_true to reject the save

    " Example: Block orders with no payment terms for key accounts
    IF iv_sales_order_data-customer_account_group = 'Z001'  " Key account
        AND iv_sales_order_data-payment_terms IS INITIAL.
      APPEND VALUE #(
          msgid  = 'ZSD_VALIDATION'
          msgno  = '010'
          msgty  = 'E'
          msgv1  = iv_sales_order_data-sold_to_party )
        TO ct_messages.
      rv_reject = abap_true.
    ENDIF.

    " Example: Derive discount from BRFplus rules
    IF iv_sales_order_data-net_value > 100000.
      DATA(lo_engine) = cl_fdt_factory=>get_instance( )->get_function_accessor( ).
      " ... call BRFplus function for discount determination ...
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

#### 7.3 GET BADI / CALL BADI Pattern (for Framework Code)

When SAP framework code calls BAdIs, the pattern uses `GET BADI` and `CALL BADI`:

```abap
" This is how SAP-delivered code calls a BAdI — shown for understanding only.
" Custom code should implement the BAdI interface, not call it directly.

DATA lo_badi TYPE REF TO if_sd_so_before_save.

GET BADI lo_badi
    FILTERS
        sales_org    = lv_sales_org
        company_code = lv_company_code.

CALL BADI lo_badi->validate_before_save
    EXPORTING
        iv_sales_order_data = ls_so_data
    CHANGING
        ct_messages = lt_messages
    RECEIVING
        rv_reject = lv_reject.

IF lv_reject = abap_true.
  " Abort save; surface messages to caller
ENDIF.
```

#### 7.4 BAdI Usage Timeline (Public Cloud)

| Term | Meaning | When Applicable |
|---|---|---|
| **Short-term** | BAdI available and called in current release | Use now; may be deprecated with notice |
| **Medium-term** | BAdI planned for removal in 2–3 releases | Use with migration plan |
| **Deprecated** | Flagged for removal; replacement documented | Migrate immediately |

---

### 8. BDEF Extension

#### 8.1 Prerequisites

Before extending a standard SAP BO:
1. Verify the BO exposes a **C0 (Use as Extension Point / Extend)** contract with declared extension points on the Business Accelerator Hub. C0 is the contract that governs extensibility; **C1 (Use System-Internally)** and **C2 (Use as Remote API)** are consumption contracts, not extension permits. Separately verify the C1 contract of any released API that your extension code consumes.
2. Verify the extension fields exist in the CDS extension include (`_extension_include`).
3. Your custom package must depend on the package containing the SAP BO.

#### 8.2 CDS View Extension (Structural — Add Fields)

```abap
" extend view entity: adds fields from extension table to standard CDS view
" Requires: DDIC extension include in the standard view

@AbapCatalog.extensibility: {
    extensible: true,
    elementSuffix: 'ZSD',
    allowNewAssociations: true
}
extend view entity I_SalesOrder with
{
    " Extension fields from customer include CI_VBAK (Private Cloud)
    " or from append structure (Public Cloud via Key User extensibility)
    SalesOrder.zz_key_account_flag as KeyAccountFlag,
    SalesOrder.zz_priority_code    as PriorityCode,

    " Association to custom extension table
    _SalesOrderExtension.special_terms as SpecialTerms
}
```

#### 8.3 BDEF Extension (Add Validations / Determinations / Events)

```abap
" ZExtend_I_SalesOrder.bdef.asbdef
" Extend standard SAP SalesOrder BO to add custom validation

extend behavior for I_SalesOrder
    implementation in class zcl_bp_ext_sales_order
{
  " Add custom determination that fires when custom extension field changes
  determination derive_key_account_discount
      on modify { field ZZ_KEY_ACCOUNT_FLAG; }

  " Add custom validation before save
  validation validate_special_terms
      on save { create; update; }

  " Add custom event on BO extension
  event z_sales_order_special_created
      parameter ZSpecialSalesOrderCreatedParams;
}
```

#### 8.4 Extension Behavior Pool

```abap
CLASS zcl_bp_ext_sales_order DEFINITION
  PUBLIC ABSTRACT FINAL
  FOR BEHAVIOR OF i_sales_order.    " extension of standard SAP BO

  PUBLIC SECTION.
    METHODS derive_key_account_discount FOR DETERMINATION
        ON MODIFY IMPORTING keys FOR sales_order~derive_key_account_discount.

    METHODS validate_special_terms FOR VALIDATION
        ON SAVE IMPORTING keys FOR sales_order~validate_special_terms
        RESULT sales_order.

ENDCLASS.

CLASS zcl_bp_ext_sales_order IMPLEMENTATION.

  METHOD derive_key_account_discount.
    READ ENTITIES OF i_sales_order IN LOCAL MODE
        ENTITY sales_order
        FIELDS ( SoldToParty ZZ_KEY_ACCOUNT_FLAG )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_orders).

    LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_order>).
      CHECK <ls_order>-ZZ_KEY_ACCOUNT_FLAG = abap_true.

      " Look up key account discount from custom table
      SELECT SINGLE discount_pct
          FROM zkeyaccount_discounts
          WHERE sold_to_party = @<ls_order>-SoldToParty
          INTO DATA(lv_discount).

      IF sy-subrc = 0.
        MODIFY ENTITIES OF i_sales_order IN LOCAL MODE
            ENTITY sales_order
            UPDATE FIELDS ( ZZ_KEY_ACCOUNT_DISC )
            WITH VALUE #( ( %tky                 = <ls_order>-%tky
                            ZZ_KEY_ACCOUNT_DISC  = lv_discount ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate_special_terms.
    READ ENTITIES OF i_sales_order IN LOCAL MODE
        ENTITY sales_order
        FIELDS ( SalesOrder ZZ_KEY_ACCOUNT_FLAG ZZ_SPECIAL_TERMS )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_orders).

    LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<ls_order>).
      " Key accounts must have special terms specified
      IF <ls_order>-ZZ_KEY_ACCOUNT_FLAG = abap_true
          AND <ls_order>-ZZ_SPECIAL_TERMS IS INITIAL.
        APPEND VALUE #(
            %tky = <ls_order>-%tky ) TO failed-sales_order.
        APPEND VALUE #(
            %tky = <ls_order>-%tky
            %msg = new_message(
                id       = 'ZSD_EXTENSION'
                number   = '001'
                severity = if_abap_behv_message=>severity-error
                v1       = <ls_order>-SalesOrder ) )
          TO reported-sales_order.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

---

### 9. CDS View Extension Patterns

#### 9.1 `extend view entity` vs. `annotate view entity`

| Aspect | `extend view entity` | `annotate view entity` |
|---|---|---|
| Adds new fields | ✅ Yes | ❌ No |
| Changes UI layout / labels | Via UI annotations | ✅ Primary use case |
| Requires extension include | ✅ Yes | ❌ No |
| Transport required | ✅ Yes | ✅ Yes |
| Impact on query performance | Possible (JOIN added) | None |
| Use when | Adding data from extension table | Changing labels, hiding fields, reordering UI |

#### 9.2 Annotation-Only Extension Example

```abap
" annotate view entity: purely changes metadata, no structural impact
" Use to override SAP UI labels, add search help, change field order

annotate view entity I_SalesOrder with
{
  @EndUserText.label: 'Customer PO Reference'
  PurchaseOrderByCustomer;

  @UI.hidden: true
  SalesDocumentType;

  @UI.lineItem: [ { position: 5, importance: #HIGH } ]
  @UI.selectionField: [ { position: 5 } ]
  ZZ_KEY_ACCOUNT_FLAG;
}
```

#### 9.3 Structural Extension Example

```abap
" extend view entity: adds fields from extension table via association
" Requires: CDS association to extension table

@AbapCatalog.extensibility: {
    extensible: true,
    elementSuffix: 'ZSD'
}
extend view entity I_SalesOrder with
    association [0..1] to ZSalesOrderExt as _SalesOrderExt
        on $projection.SalesOrder = _SalesOrderExt.SalesOrder
{
    _SalesOrderExt.special_customer_code as SpecialCustomerCode,
    _SalesOrderExt.key_account_tier      as KeyAccountTier,
    _SalesOrderExt.last_negotiation_date as LastNegotiationDate
}
```

---
