# IAM and Authorization – Complete ABAP Cloud Reference

> **Scope:** ABAP Cloud (BTP / S/4HANA Cloud Public & Private, on-prem ABAP Platform 2023+).  
> All patterns follow the "clean core" constraint set: no direct table access to auth objects at runtime, no SY-UNAME tricks, no CALL TRANSACTION.

---

## 1. Authorization Architecture — The 4-Layer Stack

Every ABAP Cloud application should secure data at four independently enforcing layers. A weakness at any layer is exploitable independently of the others.

```
┌──────────────────────────────────────────────────────────────────┐
│  Layer 4 – Business Role / IAM App                               │
│  (ADT IAM App → Business Catalog → Business Role → User)        │
├──────────────────────────────────────────────────────────────────┤
│  Layer 3 – Field-Level Feature Control                           │
│  (BDEF field/action features : instance → get_features method)  │
├──────────────────────────────────────────────────────────────────┤
│  Layer 2 – RAP Authorization (Global + Instance)                 │
│  (BDEF authorization master, get_global_authorizations,         │
│   get_instance_authorizations in the Behavior Pool)             │
├──────────────────────────────────────────────────────────────────┤
│  Layer 1 – CDS DCL (Access Control)                              │
│  (define role … aspect pfcg_auth → restricts SELECT at DB level) │
└──────────────────────────────────────────────────────────────────┘
```

**Rule of thumb:** DCL guards *read* access. RAP Authorization guards *write* operations. Field-level feature control gates *which fields/actions are editable*. Business Role determines which auth-object field values are granted.

---

## 2. Authorization Object Design

### 2.1 Naming Conventions

| Segment | Pattern | Example |
|---------|---------|---------|
| Object name | `Z_<APP>_<NOUN>` (max 10 chars) | `ZPUR_ORDER` |
| Activity field | Always include `ACTVT` | `01 Add, 02 Change, 03 Display, 06 Delete` |
| Custom org field | `Z<FIELD>` (char, max 10) | `ZPURCHORG` |
| Object class | Match functional area | `ZPURCHASE` |

### 2.2 SU21 Definition (ADT equivalent: Auth Object editor)

In ADT, navigate **Project Explorer → Authorization Objects**. Click **New**, supply:

- **Authorization Object:** `ZPUR_ORDER`  
- **Object Class:** `ZPURCHASE`  
- **Fields:** `ACTVT` (from domain `ACTVT`), `ZPURCHORG` (custom, domain `ZPURCHORG`)

> **Important:** The object must be *active* (transport released) before you can reference it in `AUTHORITY-CHECK` statements and before SU24 proposals take effect.

### 2.3 SU24 Proposal — Linking Service to Auth Object

For a Fiori / OData V4 service, open SU24, navigate to **Fiori application** type and assign `ZPUR_ORDER` with check indicator **`2` (check and propose)** so that downstream role builders see the suggestion automatically.

---

## 3. AUTHORITY-CHECK Patterns

### 3.1 Global Check at Business-Object Level

Place a *global* check inside `get_global_authorizations` (see §4). For ad-hoc checks elsewhere — e.g., a custom action that calls an external API — use this pattern:

```abap
METHOD check_purchase_authority.
  " -------------------------------------------------------
  " Check authorization for Purchase Order maintenance.
  " iv_actvt: '01'=Create, '02'=Change, '03'=Display, '06'=Delete
  " iv_purch_org: purchasing organization key
  " -------------------------------------------------------
  AUTHORITY-CHECK OBJECT 'ZPUR_ORDER'
    ID 'ACTVT'     FIELD iv_actvt
    ID 'ZPURCHORG' FIELD iv_purch_org.

  CASE sy-subrc.
    WHEN 0.
      " Authorization granted – proceed.
    WHEN 4.
      RAISE EXCEPTION TYPE cx_zpur_auth_failed
        MESSAGE e001(zpur_messages)
          WITH iv_actvt iv_purch_org
        EXPORTING
          previous => CAST cx_root( NEW cx_zpur_auth_failed( ) ).
    WHEN OTHERS.
      " sy-subrc 8 = object not active in user master
      RAISE EXCEPTION TYPE cx_zpur_auth_failed
        MESSAGE e002(zpur_messages).
  ENDCASE.
ENDMETHOD.
```

### 3.2 Instance Check with Org-Level Field Values

When you need a per-record check (e.g., only allow changes to orders belonging to the user's purchasing org):

```abap
METHOD check_order_instance_auth.
  " ls_order is a structure with the record's org values.
  DATA(lv_purch_org) = ls_order-purchasing_org.

  AUTHORITY-CHECK OBJECT 'ZPUR_ORDER'
    ID 'ACTVT'     FIELD '02'           " 02 = Change
    ID 'ZPURCHORG' FIELD lv_purch_org.

  IF sy-subrc <> 0.
    " Build REPORTED entry so Fiori shows a proper message.
    APPEND VALUE #(
      %tky        = ls_order-%tky
      %msg        = new_message(
                      id       = 'ZPUR_MESSAGES'
                      number   = '003'
                      severity = if_abap_behv_message=>severity-error
                      v1       = lv_purch_org )
    ) TO reported-purchaseorder.

    APPEND VALUE #( %tky = ls_order-%tky ) TO failed-purchaseorder.
  ENDIF.
ENDMETHOD.
```

### 3.3 sy-subrc Handling Reference

| sy-subrc | Meaning | Correct Reaction |
|----------|---------|-----------------|
| `0` | Check passed | Continue normally |
| `4` | Not authorized | Raise exception or append to FAILED/REPORTED |
| `8` | Auth object not active in user master | Treat as not authorized; log warning |
| `12` | Technical error (object not found in repo) | RAISE EXCEPTION TYPE cx_sy_authorization_error (system error) |

> **Anti-pattern:** Checking only `IF sy-subrc = 0` and falling through silently on `sy-subrc = 8` creates a latent authorization bypass.

---

## 4. RAP Global Authorization

### 4.1 BDEF Declaration

```abap
" Managed BDEF for root entity
managed implementation in class zbp_purchase_order unique;
strict ( 2 );

authorization master ( global );   " <-- declares global auth handler

define behavior for ZPURCHASE_ORDER alias PurchaseOrder
  persistent table zpurchase_order
  lock master
  etag master LastChangedAt
{
  create;
  update;
  delete;

  field ( readonly ) OrderID;
  field ( mandatory ) PurchasingOrg, CompanyCode, OrderDate;

  action submitForApproval result [1] $self;
}
```

### 4.2 Projection BDEF — Expose Only Required Operations

```abap
" Projection BDEF restricts which operations the service exposes
projection;
strict ( 2 );

define behavior for ZPURCHASE_ORDER_C alias PurchaseOrder
{
  use create;
  use update;
  use delete;

  global ( ) { create; update; delete; }   " <-- maps to global auth check

  use action submitForApproval;
}
```

### 4.3 `get_global_authorizations` Implementation

```abap
CLASS zbp_purchase_order DEFINITION PUBLIC ABSTRACT FINAL
  INHERITING FROM cl_abap_behavior_pool.

  " ... (generated handler/saver class references omitted for brevity)

ENDCLASS.

CLASS lhc_global DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR PurchaseOrder
      RESULT    result.
ENDCLASS.

CLASS lhc_global IMPLEMENTATION.

  METHOD get_global_authorizations.
    " -----------------------------------------------------------
    " Called by the RAP framework once per request to determine
    " which global operations (create/update/delete) are allowed.
    " Avoids per-instance AUTHORITY-CHECK overhead for bulk reads.
    " -----------------------------------------------------------
    DATA(lv_authorized) = if_abap_behv=>auth-unauthorized.

    " --- CREATE ---
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZPUR_ORDER'
        ID 'ACTVT' FIELD '01'.       " 01 = Add/Create
      IF sy-subrc = 0.
        lv_authorized = if_abap_behv=>auth-allowed.
      ENDIF.
      result-%create = lv_authorized.
    ENDIF.

    " --- UPDATE ---
    lv_authorized = if_abap_behv=>auth-unauthorized.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZPUR_ORDER'
        ID 'ACTVT' FIELD '02'.       " 02 = Change
      IF sy-subrc = 0.
        lv_authorized = if_abap_behv=>auth-allowed.
      ENDIF.
      result-%update = lv_authorized.
    ENDIF.

    " --- DELETE ---
    lv_authorized = if_abap_behv=>auth-unauthorized.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZPUR_ORDER'
        ID 'ACTVT' FIELD '06'.       " 06 = Delete
      IF sy-subrc = 0.
        lv_authorized = if_abap_behv=>auth-allowed.
      ENDIF.
      result-%delete = lv_authorized.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

> **Framework contract:** The framework calls `get_global_authorizations` once per EML statement. If `result-%create = if_abap_behv=>auth-unauthorized`, the framework short-circuits and returns a standard 401/403 response to the Fiori UI — you do *not* need to populate FAILED/REPORTED here.

---

## 5. RAP Instance Authorization

Use instance authorization when the authorization depends on **data values inside the record** (e.g., company code, plant, purchasing org stored in the entity).

### 5.1 BDEF Declaration

```abap
managed implementation in class zbp_sales_order unique;
strict ( 2 );

authorization master ( instance );   " <-- instance auth

define behavior for ZSALES_ORDER alias SalesOrder
  persistent table zsales_order
  lock master
  etag master ChangedAt
{
  create;
  update;
  delete;
}
```

### 5.2 `get_instance_authorizations` Implementation

```abap
CLASS lhc_salesorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys             REQUEST requested_authorizations
                                 FOR SalesOrder
      RESULT    result
      FAILED    failed.
ENDCLASS.

CLASS lhc_salesorder IMPLEMENTATION.

  METHOD get_instance_authorizations.
    " Read the sales org from the database for each key
    SELECT OrderID, SalesOrg
      FROM zsales_order
      FOR ALL ENTRIES IN @keys
      WHERE OrderID = @keys-OrderID
      INTO TABLE @DATA(lt_orders).

    LOOP AT lt_orders INTO DATA(ls_order).
      DATA(lv_auth_update) = if_abap_behv=>auth-unauthorized.
      DATA(lv_auth_delete) = if_abap_behv=>auth-unauthorized.

      " Per-instance check against the record's SalesOrg
      IF requested_authorizations-%update = if_abap_behv=>mk-on.
        AUTHORITY-CHECK OBJECT 'ZSAL_ORDER'
          ID 'ACTVT'    FIELD '02'
          ID 'ZSALESORG' FIELD ls_order-SalesOrg.
        IF sy-subrc = 0.
          lv_auth_update = if_abap_behv=>auth-allowed.
        ENDIF.
      ENDIF.

      IF requested_authorizations-%delete = if_abap_behv=>mk-on.
        AUTHORITY-CHECK OBJECT 'ZSAL_ORDER'
          ID 'ACTVT'    FIELD '06'
          ID 'ZSALESORG' FIELD ls_order-SalesOrg.
        IF sy-subrc = 0.
          lv_auth_delete = if_abap_behv=>auth-allowed.
        ENDIF.
      ENDIF.

      APPEND VALUE #(
        %key    = VALUE #( OrderID = ls_order-OrderID )
        %update = lv_auth_update
        %delete = lv_auth_delete
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

### 5.3 EML Impact

When EML statements (MODIFY / DELETE) are executed inside a RAP behavior pool, the framework automatically evaluates `get_instance_authorizations` for each key. Callers do *not* need to pre-check; the framework rejects unauthorized keys and populates `FAILED`.

---

## 6. Field-Level Feature Control

Field-level features control whether individual fields are **editable**, **mandatory**, or **read-only** per record at runtime — independent of static BDEF definitions.

### 6.1 BDEF Annotation

```abap
define behavior for ZPURCHASE_ORDER alias PurchaseOrder
{
  " Static read-only (never changeable):
  field ( readonly ) OrderID, CreatedAt, CreatedBy;

  " Dynamic per-instance feature control:
  field ( features : instance ) ApprovalStatus, NetValue;

  " Action with dynamic visibility:
  action ( features : instance ) submitForApproval
    result [1] $self;

  action ( features : instance ) cancelOrder
    result [1] $self;
}
```

### 6.2 `get_features` Implementation

```abap
CLASS lhc_purchaseorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_features FOR FEATURES
      IMPORTING keys           REQUEST requested_features
                               FOR PurchaseOrder
      RESULT    result
      FAILED    failed.
ENDCLASS.

CLASS lhc_purchaseorder IMPLEMENTATION.

  METHOD get_features.
    SELECT OrderID, ApprovalStatus, DocumentType
      FROM zpurchase_order
      FOR ALL ENTRIES IN @keys
      WHERE OrderID = @keys-OrderID
      INTO TABLE @DATA(lt_orders).

    LOOP AT lt_orders INTO DATA(ls_order).
      DATA(ls_features) = VALUE #( %key = VALUE #( OrderID = ls_order-OrderID ) ).

      CASE ls_order-ApprovalStatus.
        WHEN 'SUBMITTED' OR 'APPROVED'.
          " Locked for editing once submitted
          ls_features-%field-ApprovalStatus = if_abap_behv=>fc-f-read_only.
          ls_features-%field-NetValue        = if_abap_behv=>fc-f-read_only.
          ls_features-%action-submitForApproval = if_abap_behv=>fc-o-disabled.
          ls_features-%action-cancelOrder       = if_abap_behv=>fc-o-enabled.

        WHEN 'DRAFT' OR ' '.
          ls_features-%field-ApprovalStatus = if_abap_behv=>fc-f-unrestricted.
          ls_features-%field-NetValue        = if_abap_behv=>fc-f-unrestricted.
          ls_features-%action-submitForApproval = if_abap_behv=>fc-o-enabled.
          ls_features-%action-cancelOrder       = if_abap_behv=>fc-o-disabled.

        WHEN OTHERS.
          ls_features-%field-ApprovalStatus = if_abap_behv=>fc-f-read_only.
          ls_features-%action-submitForApproval = if_abap_behv=>fc-o-disabled.
          ls_features-%action-cancelOrder       = if_abap_behv=>fc-o-disabled.
      ENDCASE.

      APPEND ls_features TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

---

## 7. CDS DCL (Access Control)

DCL roles restrict **read access at the database layer** — they apply regardless of who calls the SELECT (ABAP code, OData, ABAP SQL, report).

### 7.1 Basic Role Definition

```cds
@EndUserText.label: 'Access Control: Purchase Order'
@MappingRole: true
define role ZPURCHASE_ORDER_AR {
  grant select on ZPURCHASE_ORDER
    where ( PurchasingOrg ) = aspect pfcg_auth( ZPUR_ORDER, ZPURCHORG,
                                                ACTVT = '03' );
}
```

> **`aspect pfcg_auth`** delegates the WHERE clause value to the authorization object field. Users only see rows where `PurchasingOrg` matches the `ZPURCHORG` field values granted in their role.

### 7.2 Propagating DCL to Projection Views

```cds
@EndUserText.label: 'Purchase Order Projection (Consumer)'
@AccessControl.authorizationCheck: #CHECK   " <-- mandatory; do NOT use #NOT_REQUIRED
define view entity ZPURCHASE_ORDER_C
  as projection on ZPURCHASE_ORDER
{
  key OrderID,
      PurchasingOrg,
      CompanyCode,
      NetValue,
      ApprovalStatus,
      _Supplier
}
```

> **Anti-pattern:** Using `@AccessControl.authorizationCheck: #NOT_REQUIRED` on a projection view that is directly exposed in an OData service removes DCL protection entirely. Only use `#NOT_REQUIRED` on purely technical helper views with no direct service exposure.

### 7.3 DCL for Association Filtering

```cds
define role ZORDER_ITEM_AR {
  grant select on ZPURCHASE_ORDER_ITEM
    where ( PurchasingOrg ) = aspect pfcg_auth( ZPUR_ORDER, ZPURCHORG,
                                                ACTVT = '03' );
}
```

Associations from `ZPURCHASE_ORDER` → `ZPURCHASE_ORDER_ITEM` are automatically filtered by the item DCL when the navigation is performed.

---

## 8. IAM App → Business Catalog → Business Role Flow

### 8.1 Step-by-Step in ADT / BTP Cockpit

| Step | Action | Tool |
|------|--------|------|
| 1 | Create **IAM App** (type `ERP_EXTERNAL_API` or `FIORI_LAUNCHPAD_APP`) | ADT → Project → IAM App |
| 2 | Add **Authorizations** tab: add auth object `ZPUR_ORDER`, set restriction type | ADT IAM App editor |
| 3 | Set **restriction type** per field: `Static` (hardcoded in app) or `Instance` (set by admin in role) | ADT |
| 4 | Create **Business Catalog** and add the IAM app | ADT → Business Catalog |
| 5 | Transport and release the catalog | ABAP Transport |
| 6 | In **BTP Cockpit / Fiori Launchpad**, create **Business Role** from the catalog | Maintain Business Roles app |
| 7 | Set field values for `ZPURCHORG` and `ACTVT` in the role | Maintain Business Roles |
| 8 | Assign Business Role to **Business User** | Maintain Business Users app |

### 8.2 Restriction Types

| Type | Who Sets Values | Typical Use |
|------|----------------|-------------|
| `Static` (No Restriction) | Developer (hardcoded `FIELD '03'`) | Display-only apps |
| `Instance` | Administrator via role maintenance | Data-segmenting fields like org levels |
| `Instance` with `Unrestricted` default | Admin can leave open | Cross-org superusers |

### 8.3 Mapping AUTHORITY-CHECK to Business Role Activity

```abap
" In behavior pool — this checks activity 01 (Create):
AUTHORITY-CHECK OBJECT 'ZPUR_ORDER'
  ID 'ACTVT'     FIELD '01'
  ID 'ZPURCHORG' FIELD lv_purch_org.
```

In the Business Role, the admin sets **ACTVT = 01** (Create) for the purchasing org values that the user may create orders for. The framework matches `lv_purch_org` against the org values in the role at runtime.

---

## 9. Common Anti-Patterns and How to Fix Them

| # | Anti-Pattern | Risk | Fix |
|---|-------------|------|-----|
| 1 | `AUTHORITY-CHECK` passes but no entry in `REPORTED` on failure | Fiori shows generic 403, no actionable message | Always append `%msg` to `REPORTED` when appending to `FAILED` |
| 2 | Checking `ZPUR_ORDER` for an action that should check `ZPUR_APPROVE` | Wrong object grants/denies wrong operations | Map each action to its own dedicated auth object |
| 3 | `@AccessControl.authorizationCheck: #NOT_REQUIRED` on projection view with service binding | Bypasses DCL entirely | Use `#CHECK` on all externally exposed views |
| 4 | `AUTHORITY-CHECK … ID 'ACTVT' FIELD '02'` hardcoded without reading record's org | Ignores org-level segmentation | Read org field from record; pass as `FIELD lv_org` |
| 5 | Catching `sy-subrc = 4` but ignoring `sy-subrc = 8` | Silent bypass for users with inactive object | Handle both 4 and 8 as unauthorized |
| 6 | Single `authorization master ( global )` for an app that has per-record org segmentation | Any user with any org can modify all records | Switch to `authorization master ( instance )` |
| 7 | Placing `AUTHORITY-CHECK` inside a `SELECT` loop | N auth checks per N rows; performance issue | Collect org values, de-duplicate, check once per distinct value |

---

## 10. Quick Reference: Key Constants

```abap
" RAP auth result constants (IF_ABAP_BEHV)
if_abap_behv=>auth-allowed        " 'X' = authorized
if_abap_behv=>auth-unauthorized   " ' ' = not authorized
if_abap_behv=>mk-on               " request flag = 'X' (framework wants this checked)

" Feature control constants
if_abap_behv=>fc-f-unrestricted   " field editable
if_abap_behv=>fc-f-read_only      " field read-only
if_abap_behv=>fc-f-mandatory      " field mandatory
if_abap_behv=>fc-o-enabled        " action button visible & clickable
if_abap_behv=>fc-o-disabled       " action button hidden/greyed

" Standard ACTVT values
'01'  " Add / Create
'02'  " Change / Modify
'03'  " Display / Read
'06'  " Delete
'08'  " Display Change Documents
'16'  " Execute
```
