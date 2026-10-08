---
name: sap-finance
description: 'SAP Finance guidance for S/4HANA ABAP solutions. Use for general ledger, AP, AR, asset accounting, closing, tax, payments, reconciliation, Universal Journal, posting controls, FI integrations, and Finance-related extensions.'
metadata:
  version: 3.0.0
  tags: sap finance fi gl ap ar closing reconciliation
---

# SAP Finance

Use this skill as the Finance domain owner.

## Focused reference map

| Concern | Reference | Use |
|---|---|---|
| CDS, transactional API, remote API, BAPI, and BAdI candidates | [Finance released-object candidates](#fi-released-objects--full-reference) (inlined in this guide below) | Candidate discovery only; classify C0/C1/C2/Tier 2 and verify in the target system |
| Domain governance: gates, landscape, cross-skill, eligibility, and definition of done | [domain governance](./domain-governance.md) | Shared governance set; load for a full governance audit or release-readiness review |

For internal ABAP postings or updates, search for a C1-released transactional RAP business object in the target system. Use remote APIs only when the requirement crosses the SAP system boundary.

## Workflow

1. Establish landscape, company/ledger context, process, document lifecycle, controls, and volume.
2. Verify posting, reconciliation, authorization, audit, and cross-module boundaries.
3. Read only the focused reference mapped above when candidate discovery is needed.
4. Add at most two technical companion skills for the active phase.
5. Validate business controls, data integrity, performance, and operational recovery.

## Gates

Do not recommend direct persistence changes or unverified APIs. Preserve document balance, account determination, period controls, auditability, and reconciliation. Distinguish business-known objects from released technical contracts.

## FI Released Objects — Full Reference

### 1. Reading FI Data with ABAP SQL + CDS

#### Read Journal Entry Items for a Company Code
```abap
SELECT CompanyCode,
       FiscalYear,
       AccountingDocument,
       AccountingDocumentItem,
       GLAccount,
       CostCenter,
       ProfitCenter,
       AmountInCompanyCodeCurrency,
       CompanyCodeCurrency,
       PostingDate,
       DebitCreditCode
  FROM I_JournalEntryItem
  WHERE CompanyCode  = @iv_company_code
    AND FiscalYear   = @iv_fiscal_year
    AND PostingDate BETWEEN @iv_from_date AND @iv_to_date
  ORDER BY PostingDate DESCENDING
  INTO TABLE @DATA(lt_items).
```

#### Read GL Account Balance (Aggregated)
```abap
SELECT GLAccount,
       CompanyCode,
       SUM( AmountInCompanyCodeCurrency ) AS Balance,
       CompanyCodeCurrency
  FROM I_GLAccountLineItem
  WHERE CompanyCode = @iv_company_code
    AND GLAccount   = @iv_gl_account
    AND FiscalYear  = @iv_fiscal_year
  GROUP BY GLAccount, CompanyCode, CompanyCodeCurrency
  INTO TABLE @DATA(lt_balance).
```

#### Read Cost Center Master
```abap
SELECT ControllingArea,
       CostCenter,
       CostCenterName,
       CompanyCode,
       ValidityEndDate
  FROM I_CostCenter
  WHERE ControllingArea = @iv_controlling_area
    AND ValidityEndDate >= @sy-datum
  INTO TABLE @DATA(lt_cost_centers).
```

### 2. Consuming FI OData API from ABAP

#### Read Journal Entries via API_JOURNALENTRIES_SRV
```abap
" Set up destination via Communication Arrangement
DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
  comm_scenario = 'SAP_COM_0002'   " FI standard comm scenario — verify in your system
  service_id    = 'JOURNALENTRIES_SRV' ).

DATA(lo_client) = cl_web_http_client_manager=>create_by_destination( lo_destination ).
DATA(lo_request) = lo_client->get_http_request( ).

lo_request->set_uri_path(
  '/sap/opu/odata/sap/API_JOURNALENTRIES_SRV/A_JournalEntry' &&
  '?$filter=CompanyCode eq ''' && iv_company_code && '''' &&
  '&$top=100' ).
lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).

DATA(lo_response) = lo_client->execute( if_web_http_client=>get ).
DATA(lv_json) = lo_response->get_text( ).
```

### 3. Posting FI Documents — Tier 2 Wrapper

#### Interface (released C1 — in ABAP Cloud package)
```abap
INTERFACE zif_fi_document_poster.
  TYPES: BEGIN OF ty_line_item,
           gl_account     TYPE saknr,
           cost_center    TYPE kostl,
           amount         TYPE wrbtr,
           currency       TYPE waers,
           debit_credit   TYPE shkzg,    " H=Credit, S=Debit
         END OF ty_line_item.
  TYPES tt_line_items TYPE STANDARD TABLE OF ty_line_item WITH EMPTY KEY.

  METHODS post
    IMPORTING iv_company_code TYPE bukrs
              iv_posting_date TYPE dats
              iv_doc_type     TYPE blart
              it_items        TYPE tt_line_items
    RETURNING VALUE(rv_doc_number) TYPE belnr_d
    RAISING   zcx_fi_posting_error.
ENDINTERFACE.
```

#### Tier 2 Wrapper Implementation (Standard ABAP package — NOT ABAP Cloud)
```abap
CLASS zcl_fi_document_poster DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_fi_document_poster.
ENDCLASS.

CLASS zcl_fi_document_poster IMPLEMENTATION.
  METHOD zif_fi_document_poster~post.
    DATA ls_header   TYPE bapiache09.
    DATA lt_gl_items TYPE TABLE OF bapiacgl09.
    DATA lt_return   TYPE TABLE OF bapiret2.

    " Build header
    ls_header-bus_act    = 'RFBU'.
    ls_header-username   = sy-uname.
    ls_header-comp_code  = iv_company_code.
    ls_header-doc_date   = iv_posting_date.
    ls_header-pstng_date = iv_posting_date.
    ls_header-doc_type   = iv_doc_type.

    " Build line items
    DATA(lv_item) = 0.
    LOOP AT it_items INTO DATA(ls_item).
      lv_item += 1.
      APPEND VALUE bapiacgl09(
        itemno_acc = lv_item
        gl_account = ls_item-gl_account
        costcenter = ls_item-cost_center
        amount     = ls_item-amount
        currency   = ls_item-currency
        dc_ind     = ls_item-debit_credit ) TO lt_gl_items.
    ENDLOOP.

    " Call BAPI (unreleased FM — only possible from Tier 2)
    CALL FUNCTION 'BAPI_ACC_DOCUMENT_POST'
      EXPORTING  documentheader = ls_header
      TABLES     accountgl       = lt_gl_items
                 return          = lt_return.

    " Check for errors
    DATA(lt_errors) = FILTER #( lt_return WHERE type = 'E' OR type = 'A' ).
    IF lt_errors IS NOT INITIAL.
      ROLLBACK WORK.
      RAISE EXCEPTION TYPE zcx_fi_posting_error
        EXPORTING messages = lt_errors.
    ENDIF.

    " Commit and return document number
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = 'X'.
    rv_doc_number = lt_return[ type = 'S' ]-message_v2.  " Adjust field per BAPI doc
  ENDMETHOD.
ENDCLASS.
```

> ⚠️ `BAPI_ACC_DOCUMENT_POST` exact parameter structure — verify field names in SE37/ADT. The structure `BAPIACHE09` and `BAPIACGL09` names are correct for ECC/S4; verify table names in your release.

### 4. Key FI Extension Points

#### BAdIs for FI Document Posting
| BAdI | Description |
|---|---|
| `BADI_ACC_DOCUMENT` | Enhance accounting document during posting |
| `FI_SUBSTITUTION` | Field substitution before document save |
| `FI_VALIDATION` | Validation rules during posting |

#### RAP-Based FI Extensions (S/4HANA 2022+)
For extending standard FI RAP BOs (e.g., `I_JournalEntry`), use the **Extend by Customer Fields** approach via Key User Extensibility if field addition is needed — direct behavior extension requires a released extension point.

### 5. FI Released API Summary Table

| Object Type | Name | Purpose | Release |
|---|---|---|---|
| CDS View | `I_JournalEntry` | FI document header | C1 |
| CDS View | `I_JournalEntryItem` | FI document items | C1 |
| CDS View | `I_GLAccountLineItem` | GL line items reporting | C1 |
| CDS View | `I_CompanyCode` | Company code master | C1 |
| CDS View | `I_GLAccountInChartOfAccounts` | GL account master | C1 |
| CDS View | `I_CostCenter` | Cost center | C1 |
| CDS View | `I_ProfitCenter` | Profit center | C1 |
| OData API | `API_JOURNALENTRIES_SRV` | Journal entry R/W | Released |
| OData API | `API_OPLACCTGDOCITEMCUBE_SRV` | Doc item reporting | Released |
| BAPI (Tier 2) | `BAPI_ACC_DOCUMENT_POST` | Post FI document | Tier 2 only |
| BAPI (Tier 2) | `BAPI_TRANSACTION_COMMIT` | Commit BAPI LUW | Tier 2 only |
