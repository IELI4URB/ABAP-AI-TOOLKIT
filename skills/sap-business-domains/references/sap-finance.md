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

> **Universal Journal (ACDOCA) — read correctly.** `I_JournalEntryItem` / `I_GLAccountLineItem` sit on the Universal Journal. S/4HANA General Ledger supports **parallel accounting via several parallel ledgers** (one ledger per accounting principle, e.g. IFRS + local GAAP) — SAP Help: *General Ledger Accounting (FI-GL) → Parallel Accounting*. Each ledger holds its own version of the same journal-entry item, so a query without a **`Ledger`** filter returns one row per ledger for the same document, inflating any `SUM`. Constrain `Ledger` (e.g. `0L` leading ledger) whenever aggregating or comparing balances. Standard ACDOCA reporting dimensions you can also select/group by: **Segment** (segment reporting, IFRS/US-GAAP), **FunctionalArea** (cost-of-sales accounting), **ProfitCenter**.

#### Read Journal Entry Items for a Company Code
```abap
SELECT CompanyCode,
       Ledger,
       FiscalYear,
       AccountingDocument,
       AccountingDocumentItem,
       GLAccount,
       CostCenter,
       ProfitCenter,
       Segment,
       FunctionalArea,
       AmountInCompanyCodeCurrency,
       CompanyCodeCurrency,
       PostingDate,
       DebitCreditCode
  FROM I_JournalEntryItem
  WHERE CompanyCode  = @iv_company_code
    AND Ledger       = @iv_ledger          "'0L' leading ledger; mandatory in parallel-ledger systems
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
    AND Ledger      = @iv_ledger           "omit -> balances summed across all ledgers (wrong)
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
    DATA lt_errors LIKE lt_return.
    LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E' OR type = 'A'.
      APPEND ls_ret TO lt_errors.
    ENDLOOP.
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

Substitution and validation are **not** BAdIs — they are the classic config-based framework (transactions `OB28`/`GGB0`, exit programs `RGGBR000`/`RGGBS000`), superseded on S/4HANA by the **Manage Substitution/Validation Rules** app (see §4 below).

#### RAP-Based FI Extensions (S/4HANA 2022+)
For extending standard FI RAP BOs (e.g., `I_JournalEntry`), use the **Extend by Customer Fields** approach via Key User Extensibility if field addition is needed — direct behavior extension requires a released extension point.

#### Custom-Field Extensibility for Journal Entries

Source: SAP Help — *General Ledger Accounting (FI-GL) → Extensibility Options for Finance / Substitution/Validation for Journal Entries*.

Adding custom fields to journal entries (ACDOCA). Pick by scope:

| Option | Mechanism | Scope / Caveat |
|---|---|---|
| Classic Coding Block | Transaction **OXK3** → `CI_COBL` structure | Field flows into ACDOCA **and** BSEG/MSEG/EBKN/EKKN; usable in Fiori apps that post journal entries. **Cannot** extend customer/supplier line items (account type D/K). |
| Custom Fields app (key user) | Business contexts *Accounting: Journal Entry Item*, *Accounting: Coding Block* | Local extension. For a Coding Block field, SAP recommends OXK3 first, then **SCFD_EUI** to enable it for the Custom Fields app. |
| Market Segment / CO-PA | Custom Fields app context *Accounting: Market Segment*, or classic **KEA5** characteristics | KEA5 chars reach ACDOCA when the operating concern uses Margin Analysis. |

Reference: SAP Note 2453614 (FI extensibility). Process extensibility also exposes business scenarios (e.g. *Billing Document → Journal Entry*) for transferring custom-field data.

#### Substitution / Validation Rules (modern)

The **Manage Substitution/Validation Rules** app is the current mechanism to validate, derive, or replace field values in FI postings at runtime (business context *Journal Entry Item*). It supersedes the classic `FI_SUBSTITUTION` / `FI_VALIDATION` / BTE path for new journal-entry work (scope difference: SAP Note 3093515).

- Rules are **topologically ordered** by field dependency: a rule that substitutes a field runs before any rule that reads it.
- Multiple rules substituting the same field run in **alphabetical** order.
- A **cyclic** read/write dependency on the same field aborts rule execution with an error.
- **Table Lookup** lets a rule read values from a database table as a derivation source.

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
