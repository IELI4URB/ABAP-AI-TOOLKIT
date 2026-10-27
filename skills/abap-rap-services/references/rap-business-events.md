# RAP Business Events

> **Audience:** Senior ABAP Cloud developers implementing event-driven architectures, extensibility patterns, and BAdI-based enhancements on S/4HANA Public Cloud, Private Cloud (2023+), and SAP BTP ABAP Environment.
> **Last updated:** 2025 | **Syntax:** ABAP Cloud (Tier 1 unless noted)

---

### 1. Decision Matrix: Events vs. BAdIs vs. Extensions

Choose the right extensibility mechanism before writing code.

| Mechanism | Trigger | Coupling Level | Use Case | Public Cloud | Private Cloud | BTP |
|---|---|---|---|---|---|---|
| **RAP Business Event** (local) | SAVE_MODIFIED / CLEANUP_FINALIZE | Loose (same system, async within LUW) | Trigger side effects in same tenant on BO save | ✅ | ✅ | ✅ |
| **RAP Business Event** (remote) | SAVE_MODIFIED → Event Mesh | Very Loose (async, cross-system) | Notify external systems on BO state change | ✅ | ✅ (2023+) | ✅ |
| **Derived Event** (2311+) | Declarative in BDEF | Loose (cross-entity) | Raise an event on a related entity when the source entity changes | ✅ | ✅ (2311+) | ✅ |
| **Cloud BAdI** | Explicit CALL BADI in SAP code | Medium (same LUW, synchronous) | Enhance SAP-delivered logic at pre-defined extension points | ✅ | ✅ | ✅ |
| **BDEF Extension** | RAP lifecycle hooks | Medium (same LUW) | Add validations, determinations, events to standard SAP BOs | ✅ | ✅ | ✅ |
| **CDS View Extension** (structural) | `extend view entity` | Low (query-time) | Add fields from extension tables to standard SAP CDS views | ✅ | ✅ | ✅ |
| **CDS Annotation Extension** | `annotate view entity` | None (metadata only) | Change Fiori UI layout without adding data | ✅ | ✅ | ✅ |
| **Classic User Exit / Enhancement** | Implicit enhancement point | Tight (synchronous, unreleased) | Legacy Private Cloud only; no equivalent in Public Cloud | ❌ | ✅ (migration target) | ❌ |

> **Decision Rule:** For notifications → Events. For synchronous logic injection → BAdI. For structural BO extension → BDEF Extension + CDS Extension. For UI changes only → CDS Annotation Extension.

---

### 2. RAP Business Event — Full Pattern

#### 2.1 BDEF Declaration

```abap
" ZSalesOrder.bdef.asbdef
managed implementation in class zbp_sales_order unmanaged save;
strict ( 2 );

define behavior for ZSalesOrder alias sales_order
  persistent table zsales_order
  lock master
  authorization master ( instance )
{
  field ( readonly )  order_id; status; created_at;
  field ( mandatory ) customer_id; sales_org; total_value; currency;

  create; update; delete;

  action ( features : instance ) confirm result [1] $self;
  action ( features : instance ) cancel  result [1] $self;

  " Business events — each linked to an abstract parameter entity
  event created   parameter ZSalesOrderCreatedParams;
  event confirmed parameter ZSalesOrderConfirmedParams;
  event cancelled parameter ZSalesOrderCancelledParams;

  determination set_created_fields on modify { create; }
  validation validate_customer      on save   { create; update; }
}
```

#### 2.2 Abstract Parameter Entity

The parameter entity is a **pure abstract structure** — it carries the event payload and has no database table.

```abap
" ZSalesOrderCreatedParams.ddls.asddls
" Abstract entity: no SQL view and no persistence.
" @AbapCatalog.sqlViewName is NOT valid on 'define abstract entity' — do not add it.
@EndUserText.label: 'Sales Order Created Event Parameters'

define abstract entity ZSalesOrderCreatedParams
{
  key order_id      : vbeln_va;        " Primary key for idempotency checking
  customer_id       : kunnr;
  sales_org         : vkorg;
  total_value       : netwr;
  currency          : waers;
  created_by        : sy_uname;
  created_at        : timestampl;
  company_code      : bukrs;
}
```

```abap
" ZSalesOrderConfirmedParams.ddls.asddls
define abstract entity ZSalesOrderConfirmedParams
{
  key order_id      : vbeln_va;
  confirmed_by      : sy_uname;
  confirmed_at      : timestampl;
  previous_status   : char10;
  new_status        : char10;
}
```

#### 2.3 Raising Events in SAVE_MODIFIED

> ⚠️ **Critical constraint:** `RAISE ENTITY EVENT` may **only** be called inside `SAVE_MODIFIED` (for managed BOs with unmanaged save) or `CLEANUP_FINALIZE`. It cannot be called in `MODIFY`, `ACTION`, or `VALIDATION` methods. If you need to raise an event conditionally from an action, set a flag during the action and check it in SAVE_MODIFIED.

```abap
CLASS zcl_bp_sales_order DEFINITION
  PUBLIC ABSTRACT FINAL
  FOR BEHAVIOR OF zsales_order.

  " ...
ENDCLASS.

CLASS zcl_saver_sales_order DEFINITION
  PUBLIC FINAL
  FOR BEHAVIOR OF zsales_order.  " unmanaged saver

  PUBLIC SECTION.
    METHODS save_modified FOR SAVE.
    METHODS cleanup_finalize FOR CLEANUP.
ENDCLASS.

CLASS zcl_saver_sales_order IMPLEMENTATION.

  METHOD save_modified.
    " ── Handle CREATEs ────────────────────────────────────────────────────
    IF create-sales_order IS NOT INITIAL.
      LOOP AT create-sales_order ASSIGNING FIELD-SYMBOL(<ls_create>).
        " Persist to DB
        INSERT zsales_order FROM @(
            CORRESPONDING zsales_order( <ls_create> ) ).

        " Raise Created event with full payload
        RAISE ENTITY EVENT zsales_order~created
            FROM VALUE #( (
                %key         = <ls_create>-%key
                order_id     = <ls_create>-order_id
                customer_id  = <ls_create>-customer_id
                sales_org    = <ls_create>-sales_org
                total_value  = <ls_create>-total_value
                currency     = <ls_create>-currency
                created_by   = <ls_create>-created_by
                created_at   = <ls_create>-created_at
                company_code = <ls_create>-company_code ) ).
      ENDLOOP.
    ENDIF.

    " ── Handle UPDATEs ────────────────────────────────────────────────────
    IF update-sales_order IS NOT INITIAL.
      LOOP AT update-sales_order ASSIGNING FIELD-SYMBOL(<ls_update>).
        " Check for status change to 'CONFIRMED'
        IF <ls_update>-%control-status = if_abap_behv=>mk-on
            AND <ls_update>-status = 'CONFIRMED'.

          UPDATE zsales_order
              SET status       = @<ls_update>-status
                  confirmed_by = @sy-uname
              WHERE order_id   = @<ls_update>-order_id.

          RAISE ENTITY EVENT zsales_order~confirmed
              FROM VALUE #( (
                  %key           = <ls_update>-%key
                  order_id       = <ls_update>-order_id
                  confirmed_by   = sy-uname
                  confirmed_at   = cl_abap_context_info=>get_system_timestamp( )
                  previous_status = 'OPEN'
                  new_status      = 'CONFIRMED' ) ).
        ELSE.
          " Generic update without event
          UPDATE zsales_order FROM @(
              CORRESPONDING zsales_order( <ls_update> ) ).
        ENDIF.
      ENDLOOP.
    ENDIF.

    " ── Handle DELETEs ────────────────────────────────────────────────────
    IF delete-sales_order IS NOT INITIAL.
      LOOP AT delete-sales_order ASSIGNING FIELD-SYMBOL(<ls_delete>).
        DELETE zsales_order WHERE order_id = @<ls_delete>-order_id.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup_finalize.
    " Called on rollback — clean up transient data only; no DB changes here
    " Can raise events to compensate remote side effects if needed
  ENDMETHOD.

ENDCLASS.
```

---

### 3. Local Event Consumption

Local consumers run **in the same ABAP system** as the producer, within the same transaction LUW. Ideal for side-effect logic that should not be coupled into the main RAP implementation.

#### 3.1 Handler Class Implementation

```abap
" Local event consumer: when a SalesOrder is created,
" create a corresponding CreditCheck request.

CLASS zcl_evt_handler_so_created DEFINITION
  PUBLIC FINAL CREATE PUBLIC
  INHERITING FROM cl_abap_behavior_event_handler.

  PRIVATE SECTION.
    METHODS on_sales_order_created FOR ENTITY EVENT
        IMPORTING params FOR zsales_order~created.

ENDCLASS.

CLASS zcl_evt_handler_so_created IMPLEMENTATION.

  METHOD on_sales_order_created.
    " params: table of ZSalesOrderCreatedParams instances
    LOOP AT params ASSIGNING FIELD-SYMBOL(<ls_event>).
      " Validate event data before acting
      CHECK <ls_event>-order_id IS NOT INITIAL.
      CHECK <ls_event>-total_value > 0.

      " Create credit check via EML on another BO
      MODIFY ENTITIES OF zcredit_check_request
          ENTITY credit_check_request
          CREATE
          FIELDS ( sales_order_id customer_id amount currency requested_at )
          WITH VALUE #( (
              %cid            = |CC_{ <ls_event>-order_id }|
              sales_order_id  = <ls_event>-order_id
              customer_id     = <ls_event>-customer_id
              amount          = <ls_event>-total_value
              currency        = <ls_event>-currency
              requested_at    = cl_abap_context_info=>get_system_timestamp( ) ) )
          REPORTED DATA(lt_rep)
          FAILED DATA(lt_failed).

      IF lt_failed IS NOT INITIAL.
        " Log error — do not let event handler crash the main LUW
        " In production: use application log (SLG1/SBAL) instead of MESSAGE
        DATA(lo_log) = cl_bali_log=>create_with_header(
            header = cl_bali_header_setter=>create(
                object    = 'ZEVT_HANDLER'
                subobject = 'SO_CREATED' ) ).
        lo_log->add_item( cl_bali_message_setter=>create(
            severity   = if_bali_constants=>c_severity_error
            id         = 'ZSO_EVENTS'
            number     = '001'
            variable_1 = <ls_event>-order_id ) ).
        cl_bali_log_db=>get_instance( )->save_log( log = lo_log ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

#### 3.2 Handler Registration

Register the handler class in the **behavior definition** of the **consumer** (not the producer):

```abap
" ZCreditCheckRequest.bdef.asbdef
" Register event handler for incoming events from external BO
define behavior for ZCreditCheckRequest alias credit_check_request ...
{
  " ... standard behavior ...

  " Register local event handler
  event handler zcl_evt_handler_so_created for zsales_order~created;
}
```

Or register globally without a specific BO context using the **Event Subscription** object in ADT (preferred for cross-BO consumers without structural dependency).

---

### 4. Remote Event Consumption — Event Mesh

#### 4.1 End-to-End Architecture

```
ABAP System (Producer)
  RAISE ENTITY EVENT zsales_order~created
        │
        ▼
  Enterprise Event Enablement Framework
        │ serializes to CloudEvents JSON
        ▼
  SAP Event Mesh / Advanced Event Mesh
  Topic: sap/s4/beh/salesorder/v1/SalesOrder/Created/v1
        │
        ▼
  Consumer (BTP Integration Suite, SAP Build PA, external subscriber)
```

#### 4.2 Event Binding Artifact (ADT)

1. In ADT: **New → Event Binding**.
2. Select **Business Object**: `ZSalesOrder` → **Event**: `created`.
3. Set **Topic**: auto-generated as `sap/s4/beh/<module>/<version>/<Entity>/<EventType>/<version>`.
4. Set **Channel**: references the Communication Arrangement for `SAP_COM_0092`.
5. Activate and transport.

#### 4.3 Topic Naming Convention

```
sap / s4 / beh / <module> / v<X> / <EntityName> / <EventType> / v<Y>

Examples:
  sap/s4/beh/salesorder/v1/SalesOrder/Created/v1
  sap/s4/beh/purchaseorder/v1/PurchaseOrder/Confirmed/v1
  sap/s4/beh/leavemanagement/v1/LeaveRequest/Approved/v1

Custom BO example (namespace your module):
  sap/s4/beh/zmyapp/v1/ZMyEntity/Created/v1
```

#### 4.4 Communication Arrangement SAP_COM_0092

| Setting | Value |
|---|---|
| Communication Scenario | `SAP_COM_0092` |
| Auth Type | OAuth 2.0 Client Credentials |
| Token endpoint | SAP Event Mesh service key `tokenurl` |
| Management URL | SAP Event Mesh service key `uri` |
| Messaging URL | SAP Event Mesh service key `protocol[amqp10ws].uri` |

#### 4.5 CloudEvents Payload Format

The framework serializes ABAP event parameters to **CloudEvents 1.0 JSON**:

```json
{
  "specversion": "1.0",
  "type": "sap.s4.beh.salesorder.v1.SalesOrder.Created.v1",
  "source": "/default/sap.s4.cloud/S4HCLNT100",
  "id": "a3b4c5d6-1234-5678-abcd-000000000001",
  "time": "2025-01-15T10:30:00Z",
  "datacontenttype": "application/json",
  "data": {
    "OrderID":    "0000000042",
    "CustomerID": "0000001000",
    "SalesOrg":   "1000",
    "TotalValue": "25000.00",
    "Currency":   "EUR",
    "CreatedBy":  "JDOE",
    "CompanyCode": "1000"
  }
}
```

#### 4.6 Monitoring in Fiori

- App: **Enterprise Event Enablement — Event Monitor** (search bar: `Event Monitor`).
- Shows: publish queue depth, failed events with error details, replay button.
- **Topic Explorer** app: browse available topics, verify binding is active.

---

### 5. Derived Events (Release 2311+)

#### 5.1 Concept

A **derived event** is raised declaratively on an **associated entity** when the source entity changes. The framework handles the derivation — no explicit `RAISE ENTITY EVENT` in ABAP code.

```
Source BO changes → Framework automatically raises event on Target BO
```

#### 5.2 BDEF Declaration

```abap
" On ZOrderItem save, also raise an event on the parent ZSalesOrder
define behavior for ZOrderItem alias order_item ...
{
  " ... standard behavior ...

  " Derived event: when an item is created, also raise SalesOrder.ItemAdded
  event item_created parameter ZOrderItemCreatedParams;

  " Declarative derivation to parent BO
  derive event zsales_order~item_added
      from event order_item~item_created
      using association _sales_order;
}
```

#### 5.3 Use Cases

| Scenario | Source Event | Derived Event | Benefit |
|---|---|---|---|
| Order total recalculation | `OrderItem~Created` | `SalesOrder~ItemAdded` | Parent BO notified without tight coupling |
| Invoice line approval | `InvoiceItem~Verified` | `Invoice~ItemVerified` | Invoice-level subscriber gets item-level detail |
| Hierarchy roll-up | `CostCenter~Updated` | `ControllingArea~CostCenterChanged` | Aggregated notification without recursive RAISE |

---

### 6. Cross-BO Events (2025)

#### 6.1 Concept

In 2025+, it is possible to raise events **on the key of an associated BO** directly from a RAP action or SAVE_MODIFIED, even when the target BO is in a different package or owned by SAP.

#### 6.2 Prerequisites

1. The target BO must have its event parameter entity released as **C1 (Use System-Internally)** on the Business Accelerator Hub.
2. The source BO developer package must have a **software component dependency** on the target BO's software component.
3. The event binding artifact must map both source and target channel.

#### 6.3 Pattern

```abap
" Raise an event on an associated SAP BO from a custom BO's SAVE_MODIFIED
" Requires: C1 release on SAP BO event parameter entity

RAISE ENTITY EVENT i_salesorder~zsalesorder_updated       " SAP-released event
    FROM VALUE #( (
        %key      = <ls_assoc_key>          " key of the SAP SalesOrder
        order_id  = <ls_my_entity>-so_id    " mapped from custom BO association
        updated_by = sy-uname ) ).
```

> ⚠️ Same-system cross-BO raising requires the SAP BO event and its parameter entity to be released **C1 (Use System-Internally)** on the Business Accelerator Hub. Only if that same event is additionally delivered remotely via Event Mesh must the event also carry a **C2 (Use as Remote API)** contract. Verify each contract independently; do not assume C1 implies remote eligibility.

---

### 10. Platform Availability Matrix

| Feature | Public Cloud | Private Cloud | BTP ABAP Env | Min. Release |
|---|---|---|---|---|
| RAP Business Events (local) | ✅ | ✅ | ✅ | 2021.1 |
| RAP Business Events (remote / Event Mesh) | ✅ | ✅ | ✅ | 2022.1 / 2022 |
| Event Binding artifact (ADT) | ✅ | ✅ | ✅ | 2022.1 |
| Derived Events (BDEF declarative) | ✅ | ✅ | ✅ | 2311 |
| Cross-BO Event Raising | ✅ | ✅ | ✅ | 2025 |
| `RAISE ENTITY EVENT` in CLEANUP_FINALIZE | ✅ | ✅ | ✅ | 2023.1 |
| Cloud BAdI (Enhancement Spot/ADT) | ✅ | ✅ | ✅ | 2020+ |
| BDEF Extension (custom validations) | ✅ | ✅ | ✅ | 2021.1 |
| BDEF Extension (raise events) | ✅ | ✅ | ✅ | 2022.1 |
| `extend view entity` (structural CDS) | ✅ | ✅ | ✅ | 2020+ |
| `annotate view entity` | ✅ | ✅ | ✅ | 2020+ |
| Classic User Exit / Enhancement | ❌ | ✅ (legacy) | ❌ | Legacy only |
| Enterprise Event Enablement Monitor (Fiori) | ✅ | ✅ | ✅ | 2022.1 |
| SAP_COM_0092 (Event Mesh comm. scenario) | ✅ | ✅ | ✅ | 2022 |

---

### 11. Complete Example: Full Event Chain

This example shows a complete event chain: RAP BO raises an event → local consumer reacts → remote consumer receives on Event Mesh.

#### 11.1 Producer (SAVE_MODIFIED)

```abap
" Already shown in Section 2.3 — raise in SAVE_MODIFIED
RAISE ENTITY EVENT zsales_order~created
    FROM VALUE #( ( %key        = <ls_create>-%key
                    order_id    = <ls_create>-order_id
                    customer_id = <ls_create>-customer_id
                    total_value = <ls_create>-total_value
                    currency    = <ls_create>-currency
                    created_by  = <ls_create>-created_by
                    created_at  = <ls_create>-created_at ) ).
```

#### 11.2 Local Consumer (same system, reacts synchronously)

```abap
CLASS zcl_local_so_created_handler DEFINITION
  PUBLIC FINAL CREATE PUBLIC
  INHERITING FROM cl_abap_behavior_event_handler.

  PRIVATE SECTION.
    METHODS on_so_created FOR ENTITY EVENT
        IMPORTING params FOR zsales_order~created.

ENDCLASS.

CLASS zcl_local_so_created_handler IMPLEMENTATION.
  METHOD on_so_created.
    LOOP AT params ASSIGNING FIELD-SYMBOL(<ev>).
      " Write to audit log / notification table
      INSERT zso_creation_audit FROM @(
          VALUE zso_creation_audit(
              order_id    = <ev>-order_id
              customer_id = <ev>-customer_id
              created_by  = <ev>-created_by
              log_ts      = cl_abap_context_info=>get_system_timestamp( ) ) ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

#### 11.3 Remote Consumer Configuration

```yaml
# Event Binding artifact (created in ADT — shown here as pseudoconfig)
BO:            ZSalesOrder
Event:         created
Channel:       SAP_COM_0092 (bound to SAP Event Mesh arrangement)
Topic:         sap/s4/beh/zmyapp/v1/ZSalesOrder/Created/v1
CloudEvents:   enabled (auto-serialized by framework)
```

---

### 12. Common Mistakes and Pitfalls

| # | Mistake | Consequence | Correct Approach |
|---|---|---|---|
| 1 | `RAISE ENTITY EVENT` in an ACTION method | Syntax error or runtime error | Move RAISE to SAVE_MODIFIED; set a flag in ACTION |
| 2 | Abstract parameter entity has a DB table | Activation error | Remove `@AbapCatalog.dbTableCategory` / use `define abstract entity` only |
| 3 | Event consumer crashes and propagates exception | Main LUW rolls back; user sees unrelated error | Always use TRY/CATCH in event handler methods; use application log |
| 4 | Missing Event Binding artifact | Event raised locally but never sent to Event Mesh | Create and activate Event Binding in ADT |
| 5 | Wrong topic format in Event Binding | Messages not routed to correct queue | Follow `sap/s4/beh/<module>/v<n>/<Entity>/<Type>/v<n>` exactly |
| 6 | BDEF extension without verified extensibility contract | Works in DEV, fails in transport to Cloud | Verify the provider's C0 extension contract and declared extension points; separately verify C1 contracts for APIs consumed by the extension |
| 7 | `extend view entity` without extension include | DDIC activation error | Check that standard view has `_EXTENSION_INCLUDE` before extending |
| 8 | BAdI implementation without filter match | BAdI called unexpectedly in wrong org context | Set correct filter values (sales org, company code) in BAdI implementation |
| 9 | Calling `RAISE ENTITY EVENT` with wrong `%key` | Event fires with null payload; consumers receive empty events | Always populate `%key` exactly matching the BO's primary key fields |
| 10 | Not transporting Event Binding artifact | Works in DEV, no events in QA/PROD | Include Event Binding in transport request alongside BDEF |

---

### 13. Quick-Reference Card

```
RAISE EVENT (BDEF):
  event created parameter ZMyEntityCreatedParams;
  ─ in SAVE_MODIFIED:
  RAISE ENTITY EVENT zmy_entity~created
      FROM VALUE #( ( %key = ... field1 = ... field2 = ... ) ).

LOCAL CONSUMER:
  CLASS zcl_my_handler INHERITING FROM cl_abap_behavior_event_handler.
    METHODS on_event FOR ENTITY EVENT
        IMPORTING params FOR zmy_entity~created.

REMOTE CONSUMER:
  1. ADT → New → Event Binding → select BO + Event + Channel (SAP_COM_0092)
  2. Topic: sap/s4/beh/<module>/v1/<Entity>/<EventType>/v1
  3. Monitor: Fiori "Enterprise Event Enablement — Event Monitor"

CLOUD BADI:
  1. Find on Business Accelerator Hub → Enhancement Spot name
  2. ADT → New → BAdI Implementation → implement interface methods
  3. Filter: set org-level filters to prevent unintended activation

BDEF EXTENSION:
  extend behavior for I_<SAPEntity>
      implementation in class zcl_bp_ext_<name>
  {
    determination my_det on modify { field My_Ext_Field; }
    validation    my_val on save   { create; update; }
    event         z_my_event parameter ZMyEventParams;
  }

CDS EXTENSION:
  extend view entity I_<SAPView> with { ... new fields ... }   " structural
  annotate view entity I_<SAPView> with { @UI.hidden: true Field; }  " annotation
```
