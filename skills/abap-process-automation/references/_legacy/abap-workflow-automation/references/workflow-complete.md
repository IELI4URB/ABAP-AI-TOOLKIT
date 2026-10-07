# ABAP Cloud Workflow Automation — Complete Reference

> **Audience:** Senior ABAP Cloud developers implementing approval workflows, process automation, and business rule routing on SAP Public Cloud, Private Cloud, and BTP.
> **Last updated:** 2025 | **Platforms covered:** S/4HANA Public Cloud, S/4HANA Private Cloud (2022+), SAP BTP ABAP Environment

---

## 1. Technology Decision Matrix

Choose your workflow technology based on platform availability and process complexity **before** designing the solution.

| Technology | Public Cloud | Private Cloud | BTP ABAP Env | Best For | Complexity |
|---|---|---|---|---|---|
| **Flexible Workflow** (Fiori config) | ✅ | ✅ (2021+) | ❌ | Simple linear approvals on standard SAP BOs (Sales Order, PO, etc.) | Low |
| **SAP Build Process Automation** (BPA) | ✅ | ✅ (via BTP) | ✅ | Complex multi-step, multi-role, SLA-driven processes; RPA integration | Medium–High |
| **Classic Workflow SWDD** | ❌ | ✅ (legacy) | ❌ | Existing complex workflows on Private Cloud; migration target | High |
| **BRFplus** (rules only) | ✅ | ✅ | ❌ | Decision routing logic decoupled from workflow; rule-based approver determination | Medium |
| **RAP Actions** (inline approval) | ✅ | ✅ | ✅ | Simple approve/reject on custom BOs without external workflow system | Low |
| **ABAP-only State Machine** | ✅ | ✅ | ✅ | Programmatic status transitions; no human approval needed | Low |

> **Decision Shortcut:**
> - Standard SAP BO + simple approval → **Flexible Workflow**
> - Custom BO + complex routing → **SAP Build PA** triggered from RAP action
> - Private Cloud + existing SWDD workflow → **Classic Workflow + RAP event trigger**
> - Pure rules / no human step → **BRFplus** or **RAP validation**

---

## 2. Flexible Workflow — 5-Step Setup

Flexible Workflow configures approval steps for standard SAP objects (Purchase Order, Sales Order, Journal Entry, etc.) entirely in Fiori — no ABAP coding required.

### Step 1: Enable Workflow in Fiori

1. Open Fiori app **"Manage Workflows for Purchase Orders"** (or equivalent for your BO).
2. Ensure the backend has activated the workflow foundation: **`SWF_CPWF_ACTIVATE`** (admin task, one-time).

### Step 2: Configure Process Variant

| Field | Example Value | Notes |
|---|---|---|
| Variant ID | `Z_PO_TWO_LEVEL_APPROVAL` | Descriptive, unique per use case |
| Description | Two-Level PO Approval | Shown to users in inbox |
| Start Condition | Active | Can be suspended per variant |
| Validity | `01.01.2024 – 31.12.9999` | |

### Step 3: Define Start Condition

The **start condition** determines when this variant fires. Examples:

| Condition Type | Example | Implementation |
|---|---|---|
| Simple field | `Net Order Value > 10,000 EUR` | Built-in condition editor |
| Complex / multi-field | `Material Group = 'SERVICES' AND Vendor Region = 'APAC'` | BRFplus decision table |
| Org hierarchy | `Company Code = '1000' AND Purchasing Org = '1000'` | Built-in org condition |

### Step 4: Configure Approval Step

| Setting | Value | Notes |
|---|---|---|
| Step Type | Approval | One approver, group, or role |
| Recipient Type | Job / Organizational Unit / User | Use Job for scalability; avoid hardcoded users |
| Recipient | Job `73000135` (Head of Procurement) | Resolved at runtime via org model |
| Due Date | 3 working days | SLA visible in "My Inbox" |
| Escalation | After 5 days → next manager | Optional |

**Field Mapping Example (Purchase Order variant):**

```
Condition field: EKKO-NETWR (Net Value)
Comparison:      > (greater than)
Value:           10000
Currency field:  EKKO-WAERS
```

### Step 5: Activate

Click **Activate**. The variant goes live immediately. No transport, no ABAP change.

---

## 3. Flexible Workflow Conditions — Deep Dive

### 3.1 Simple Field Comparison

```
Object:     Purchase Order Header
Field:      NET_VALUE
Operator:   GREATER_THAN
Value:      50000
Currency:   EUR
```

### 3.2 BRFplus Decision Table Integration

When routing logic is complex (multiple fields, dynamic values, country-specific rules), delegate to a BRFplus function:

1. Create BRFplus **Application** `ZPURCHASE_APPROVAL_RULES`.
2. Create **Function** `ZDETERMINE_APPROVAL_LEVEL` with output `APPROVAL_LEVEL` (type `C`, length 2).
3. Build **Decision Table** with input columns: `NET_VALUE`, `MATERIAL_GROUP`, `COMPANY_CODE` → output `APPROVAL_LEVEL` = `L1`, `L2`, `L3`.
4. In Flexible Workflow condition, call BRFplus function ID and compare output column.

### 3.3 Organizational Hierarchy Routing

```
Step recipient:  Organizational Unit (dynamic)
Determination:   Manager of requester
Depth:           1 level up (direct manager)
```

This uses the HR organizational model at runtime — no hardcoded user IDs.

---

## 4. Classic SWDD — RAP Integration (Private Cloud)

> **Platform:** S/4HANA Private Cloud only. In Public Cloud, use Flexible Workflow or SAP Build PA instead.

### 4.1 Triggering a Workflow from a RAP Action

The canonical pattern: RAP action validates the BO, then raises a workflow event via `CL_SWF_CPWF_API_FACTORY`.

```abap
CLASS zcl_bp_purchase_request_a DEFINITION
  PUBLIC ABSTRACT FINAL
  FOR BEHAVIOR OF zpurchase_request_a.

  PUBLIC SECTION.
    METHODS submit_for_approval FOR MODIFY
      IMPORTING keys FOR ACTION purchase_request~submit_for_approval
                      RESULT result.

ENDCLASS.

CLASS zcl_bp_purchase_request_a IMPLEMENTATION.

  METHOD submit_for_approval.
    " 1. Read entity data for the action keys
    READ ENTITIES OF zpurchase_request_a IN LOCAL MODE
        ENTITY purchase_request
        FIELDS ( request_id amount currency status requestor_id )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_requests)
        FAILED DATA(lt_failed_read).

    " 2. Validate: only DRAFT requests may be submitted
    LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls_req>).
      IF <ls_req>-status <> 'DRAFT'.
        APPEND VALUE #(
            %tky = <ls_req>-%tky ) TO failed-purchase_request.
        APPEND VALUE #(
            %tky = <ls_req>-%tky
            %msg = new_message_with_text(
                severity = if_abap_behv_message=>severity-error
                text     = |Request { <ls_req>-request_id } is not in DRAFT status| ) )
          TO reported-purchase_request.
        CONTINUE.
      ENDIF.

      " 3. Update status to IN_APPROVAL
      MODIFY ENTITIES OF zpurchase_request_a IN LOCAL MODE
          ENTITY purchase_request
          UPDATE FIELDS ( status )
          WITH VALUE #( ( %tky  = <ls_req>-%tky
                          status = 'IN_APPROVAL' ) ).

      " 4. Raise workflow event via CL_SWF_CPWF_API_FACTORY
      TRY.
          DATA(lo_workflow_api) = cl_swf_cpwf_api_factory=>get_instance( ).

          " Build workflow container binding with BO key
          DATA(lt_binding) = VALUE if_swf_ifs_service_api=>tt_binding(
              ( name  = 'PURCHASE_REQUEST_ID'
                value = <ls_req>-request_id )
              ( name  = 'AMOUNT'
                value = <ls_req>-amount )
              ( name  = 'CURRENCY'
                value = <ls_req>-currency )
              ( name  = 'REQUESTOR_ID'
                value = <ls_req>-requestor_id ) ).

          lo_workflow_api->raise_event(
              iv_event_object_type = 'ZPURCHREQ'    " SWO1 object type
              iv_event_name        = 'SUBMITTED'    " Event name in SWDD
              iv_object_key        = <ls_req>-request_id
              it_binding           = lt_binding ).

          " 5. Return updated data to UI
          APPEND VALUE #(
              %tky        = <ls_req>-%tky
              request_id  = <ls_req>-request_id
              status      = 'IN_APPROVAL' ) TO result.

        CATCH cx_swf_cpwf_api INTO DATA(lx_wf).
          APPEND VALUE #( %tky = <ls_req>-%tky ) TO failed-purchase_request.
          APPEND VALUE #(
              %tky = <ls_req>-%tky
              %msg = new_message_with_text(
                  severity = if_abap_behv_message=>severity-error
                  text     = lx_wf->get_text( ) ) )
            TO reported-purchase_request.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

### 4.2 SWDD Workflow Definition Binding

In transaction **SWDD**, define the workflow with:

| Setting | Value |
|---|---|
| Start event object type | `ZPURCHREQ` |
| Start event name | `SUBMITTED` |
| Container element | `_WI_OBJECT_ID` bound to `PURCHASE_REQUEST_ID` |
| Step type | User decision (approval/rejection) |
| Outcome event | `APPROVED` or `REJECTED` raised back to ABAP |

---

## 5. SAP Build Process Automation — ABAP Trigger

### 5.1 Architecture

```
ABAP Cloud (RAP Action)
  └─► HTTP POST to SAP Build PA REST API
        └─► Process Instance Created
              └─► Approval Form → Approver inbox
                    └─► Outcome webhook → ABAP HTTP Service
```

### 5.2 Communication Arrangement Setup

| Artifact | Value |
|---|---|
| Communication Scenario | `ZSCEN_BUILD_PA_TRIGGER` |
| Target Service | SAP Build PA REST API (`/workflow/rest/v1/workflow-instances`) |
| Auth Type | OAuth 2.0 Client Credentials |
| Scope | `workflow_definition` (per BPA service binding) |

### 5.3 Triggering SAP Build PA from RAP Action

```abap
CLASS zcl_bp_contract_a DEFINITION
  PUBLIC ABSTRACT FINAL
  FOR BEHAVIOR OF zcontract_a.

  PUBLIC SECTION.
    METHODS start_approval_process FOR MODIFY
      IMPORTING keys FOR ACTION contract~start_approval_process
                      RESULT result.

ENDCLASS.

CLASS zcl_bp_contract_a IMPLEMENTATION.

  METHOD start_approval_process.
    READ ENTITIES OF zcontract_a IN LOCAL MODE
        ENTITY contract
        FIELDS ( contract_id total_value currency owner_id )
        WITH CORRESPONDING #( keys )
        RESULT DATA(lt_contracts).

    LOOP AT lt_contracts ASSIGNING FIELD-SYMBOL(<ls_contract>).
      " Resolve BPA endpoint via Communication Arrangement
      DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
          comm_scenario = 'ZSCEN_BUILD_PA_TRIGGER'
          service_id    = 'ZSCEN_BUILD_PA_TRIGGER_REST' ).
      DATA(lo_client) = cl_web_http_client_manager=>create_by_destination( lo_dest ).
      DATA(lo_req)    = lo_client->get_http_request( ).

      " Build PAprocess context payload
      lo_req->set_uri_path( '/workflow/rest/v1/workflow-instances' ).
      lo_req->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).

      TYPES: BEGIN OF ty_context,
               contract_id   TYPE string,
               total_value   TYPE string,
               currency      TYPE string,
               owner_id      TYPE string,
               system_id     TYPE string,
             END OF ty_context.
      TYPES: BEGIN OF ty_start_event,
               definition_id TYPE string,
               context       TYPE ty_context,
             END OF ty_start_event.

      DATA ls_start TYPE ty_start_event.
      ls_start-definition_id        = 'us10.12345678trial.zcontractapproval'.  " BPA process definition ID
      ls_start-context-contract_id  = <ls_contract>-contract_id.
      ls_start-context-total_value  = <ls_contract>-total_value.
      ls_start-context-currency     = <ls_contract>-currency.
      ls_start-context-owner_id     = <ls_contract>-owner_id.
      ls_start-context-system_id    = sy-sysid.

      lo_req->set_text( /ui2/cl_json=>serialize(
          data        = ls_start
          pretty_name = /ui2/cl_json=>pretty_mode-camel_case ) ).

      TRY.
          DATA(lo_resp)   = lo_client->execute( if_web_http_client=>post ).
          DATA(lv_status) = lo_resp->get_status( ).

          IF lv_status-code = 201.
            " Extract instance ID from response
            TYPES: BEGIN OF ty_bpa_resp,
                     id     TYPE string,
                     status TYPE string,
                   END OF ty_bpa_resp.
            DATA ls_bpa_resp TYPE ty_bpa_resp.
            /ui2/cl_json=>deserialize(
                EXPORTING json        = lo_resp->get_text( )
                          pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                CHANGING  data        = ls_bpa_resp ).

            " Update BO with workflow instance ID for tracking
            MODIFY ENTITIES OF zcontract_a IN LOCAL MODE
                ENTITY contract
                UPDATE FIELDS ( wf_instance_id status )
                WITH VALUE #( ( %tky          = <ls_contract>-%tky
                                wf_instance_id = ls_bpa_resp-id
                                status         = 'IN_APPROVAL' ) ).

            APPEND VALUE #( %tky = <ls_contract>-%tky ) TO result.
          ELSE.
            APPEND VALUE #( %tky = <ls_contract>-%tky ) TO failed-contract.
          ENDIF.

        CATCH cx_web_http_client_error INTO DATA(lx_http).
          APPEND VALUE #( %tky = <ls_contract>-%tky ) TO failed-contract.
          APPEND VALUE #(
              %tky = <ls_contract>-%tky
              %msg = new_message_with_text(
                  severity = if_abap_behv_message=>severity-error
                  text     = lx_http->get_text( ) ) )
            TO reported-contract.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

---

## 6. BRFplus Decision Table

Use BRFplus to externalize routing rules that change frequently without requiring ABAP code transport.

### 6.1 Creation Steps

| Step | Transaction / App | Action |
|---|---|---|
| 1 | **BRF+** (transaction `BRFPLUS`) | Create Application: `ZPURCHASE_RULES`, type = Customizing Application |
| 2 | Within app | Create Function: `ZDETERMINE_APPROVER`, Context Objects: `NET_VALUE` (CURR), `VENDOR_COUNTRY` (CHAR 3) |
| 3 | Within function | Create Decision Table action with result column `APPROVER_ROLE` (CHAR 30) |
| 4 | Decision table | Add rules rows (see below) |
| 5 | Activate | Transport via standard CTS |

### 6.2 Decision Table Example

| NET_VALUE (from) | NET_VALUE (to) | VENDOR_COUNTRY | → APPROVER_ROLE |
|---|---|---|---|
| 0 | 10,000 | `*` | `PROCUR_SPECIALIST` |
| 10,001 | 50,000 | `*` | `PROCUR_MANAGER` |
| 50,001 | 999,999,999 | `*` | `VP_PROCUREMENT` |
| 0 | 999,999,999 | `CN` | `TRADE_COMPLIANCE_OFFICER` |

### 6.3 Calling BRFplus from ABAP

```abap
" Call a BRFplus function to determine approver role
DATA(lo_engine) = cl_fdt_factory=>get_instance( )->get_function_accessor( ).
DATA(lo_function) = lo_engine->get_function(
    iv_id = '12345678901234567890123456789012' ).  " BRFplus Function UUID

DATA(lo_context) = lo_function->create_context( ).
lo_context->set_value( iv_name  = 'NET_VALUE'
                        iv_value = lv_net_value ).
lo_context->set_value( iv_name  = 'VENDOR_COUNTRY'
                        iv_value = lv_country ).

lo_function->process( io_context = lo_context ).

DATA lv_approver_role TYPE char30.
lo_context->get_value( EXPORTING iv_name  = 'APPROVER_ROLE'
                         IMPORTING ev_value = lv_approver_role ).
```

---

## 7. Approval Action in RAP BDEF

### 7.1 BDEF Definition

```abap
managed implementation in class zbp_leave_request unmanaged save;
strict ( 2 );

define behavior for ZLeaveRequest alias leave_request
  persistent table zleave_request
  lock master
  authorization master ( instance )
{
  field ( readonly ) status;
  field ( mandatory ) start_date; end_date; employee_id; leave_type;

  " Standard CUD
  create; update; delete;

  " Workflow actions
  action ( features : instance ) approve
      result [1] $self;
  action ( features : instance ) reject
      parameter ZLeaveRequestRejectionParam
      result [1] $self;

  " Business event raised on approval
  event approved
      parameter ZLeaveRequestApprovedParams;

  " Conditional enablement
  determination set_initial_status on modify { create; }
  validation validate_dates on save { create; update; }
}
```

### 7.2 Action Feature Control (Instance)

```abap
METHOD get_instance_features.
  READ ENTITIES OF zleave_request IN LOCAL MODE
      ENTITY leave_request
      FIELDS ( status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests).

  result = VALUE #(
      FOR ls_req IN lt_requests
      ( %tky            = ls_req-%tky
        %action-approve = COND #( WHEN ls_req-status = 'IN_APPROVAL'
                                    THEN if_abap_behv=>fc-o-enabled
                                    ELSE if_abap_behv=>fc-o-disabled )
        %action-reject  = COND #( WHEN ls_req-status = 'IN_APPROVAL'
                                    THEN if_abap_behv=>fc-o-enabled
                                    ELSE if_abap_behv=>fc-o-disabled ) ) ).
ENDMETHOD.
```

### 7.3 Approve Action Implementation

```abap
METHOD approve.
  READ ENTITIES OF zleave_request IN LOCAL MODE
      ENTITY leave_request
      FIELDS ( leave_request_id employee_id start_date end_date status )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_requests)
      FAILED DATA(lt_failed).

  LOOP AT lt_requests ASSIGNING FIELD-SYMBOL(<ls_req>).
    IF <ls_req>-status <> 'IN_APPROVAL'.
      APPEND VALUE #( %tky = <ls_req>-%tky ) TO failed-leave_request.
      CONTINUE.
    ENDIF.

    " Update status
    MODIFY ENTITIES OF zleave_request IN LOCAL MODE
        ENTITY leave_request
        UPDATE FIELDS ( status approved_by approved_at )
        WITH VALUE #( ( %tky        = <ls_req>-%tky
                        status      = 'APPROVED'
                        approved_by = sy-uname
                        approved_at = cl_abap_context_info=>get_system_date( ) ) ).

    " Raise business event to notify downstream systems
    RAISE ENTITY EVENT zleave_request~approved
        FROM VALUE #( ( %tky                 = <ls_req>-%tky
                        leave_request_id     = <ls_req>-leave_request_id
                        employee_id          = <ls_req>-employee_id
                        approved_by          = sy-uname
                        start_date           = <ls_req>-start_date
                        end_date             = <ls_req>-end_date ) ).

    APPEND VALUE #(
        %tky             = <ls_req>-%tky
        leave_request_id = <ls_req>-leave_request_id
        status           = 'APPROVED' ) TO result.
  ENDLOOP.
ENDMETHOD.
```

---

## 8. Work Item Completion — My Inbox Integration

### 8.1 How Approvers Interact

| Channel | App / Transaction | Notes |
|---|---|---|
| Fiori **My Inbox** | `MYINBOX` | Primary approver UI; shows task context and approve/reject buttons |
| SAP Mobile Start | Mobile app | Delegates to My Inbox web |
| Email notification | Workflow notification email | Link opens My Inbox task |
| Programmatic | EML via `MODIFY ENTITIES` | For automated approvers / testing only |

### 8.2 Completing a Work Item Programmatically (Testing)

```abap
" For integration testing: complete workflow decision task via EML
" This simulates an approver clicking "Approve" in My Inbox

MODIFY ENTITIES OF zleave_request
    ENTITY leave_request
    EXECUTE approve
    FROM VALUE #( ( leave_request_id = '0000001234' ) )
    FAILED DATA(lt_failed)
    REPORTED DATA(lt_reported).

IF lt_failed IS NOT INITIAL.
  " Check lt_reported for error messages
  LOOP AT lt_reported-leave_request ASSIGNING FIELD-SYMBOL(<rep>).
    WRITE: / <rep>-%msg->if_message~get_text( ).
  ENDLOOP.
ENDIF.
```

### 8.3 Workflow Status Check from ABAP

```abap
" Check if a workflow instance is still running (SAP Build PA)
METHOD check_workflow_status.
  DATA(lo_dest)   = cl_http_destination_provider=>create_by_comm_arrangement(
      comm_scenario = 'ZSCEN_BUILD_PA_TRIGGER'
      service_id    = 'ZSCEN_BUILD_PA_TRIGGER_REST' ).
  DATA(lo_client) = cl_web_http_client_manager=>create_by_destination( lo_dest ).
  DATA(lo_req)    = lo_client->get_http_request( ).
  lo_req->set_uri_path( |/workflow/rest/v1/workflow-instances/{ iv_instance_id }| ).

  DATA(lo_resp) = lo_client->execute( if_web_http_client=>get ).
  IF lo_resp->get_status( )-code = 200.
    TYPES: BEGIN OF ty_wf_status,
             id     TYPE string,
             status TYPE string,   " RUNNING, COMPLETED, CANCELED, ERRONEOUS
           END OF ty_wf_status.
    DATA ls_wf_status TYPE ty_wf_status.
    /ui2/cl_json=>deserialize(
        EXPORTING json = lo_resp->get_text( )
        CHANGING  data = ls_wf_status ).
    rv_status = ls_wf_status-status.
  ENDIF.
ENDMETHOD.
```

---

## 9. Common Mistakes

| # | Mistake | Consequence | Correct Approach |
|---|---|---|---|
| 1 | Using Classic SWDD in Public Cloud | Activation error; SWDD not available | Use Flexible Workflow or SAP Build PA |
| 2 | Missing C1 contract on BO event trigger | Syntax check error in consumer package | Check released APIs on Business Accelerator Hub before using |
| 3 | Workflow binding key mismatch (SWDD) | Work item created but container elements empty; approval has no context | Double-check `SWO1` object key field mapping vs. SWDD container element name |
| 4 | Hardcoding BPA endpoint URL | Works in DEV, breaks in QA/PROD | Always use Communication Arrangement |
| 5 | Not handling `APPROVE/REJECT` feature control | Action button always visible even in wrong status | Implement `GET_INSTANCE_FEATURES` to enable/disable per status |
| 6 | Raising workflow event outside SAVE phase | Event fires but BO data not yet persisted | Always trigger workflows from `SAVE_MODIFIED` or after `COMMIT WORK` |
| 7 | Not storing workflow instance ID on the BO | Cannot query status later; debugging is impossible | Store BPA instance ID in a BO field during trigger |
| 8 | Using BRFplus for heavy computation | Slow response time in approval determination | BRFplus is for rule tables, not complex algorithms |
| 9 | Approval action missing `result [1] $self` | UI does not refresh after action — user sees stale data | Always declare `result [1] $self` on BDEF actions |
| 10 | Not transporting BRFplus rules | Works in DEV, missing in QA/PROD | Use CTS transport for BRFplus Customizing Applications |

---

## 10. Platform Availability Summary

| Feature | Public Cloud | Private Cloud | BTP ABAP Env | Release |
|---|---|---|---|---|
| Flexible Workflow | ✅ | ✅ | ❌ | Public: 2020, Private: 2021 |
| SAP Build PA REST Trigger | ✅ | ✅ (via BTP) | ✅ | 2022+ |
| Classic SWDD | ❌ | ✅ | ❌ | Legacy |
| `CL_SWF_CPWF_API_FACTORY` (RAP→SWDD) | ❌ | ✅ | ❌ | Private Cloud 2022 |
| BRFplus | ✅ | ✅ | ❌ | Long available |
| RAP Action approve/reject | ✅ | ✅ | ✅ | 2021+ |
| My Inbox (MYINBOX app) | ✅ | ✅ | ❌ (use BTP WZI) | 2020+ |
| Workflow email notifications | ✅ | ✅ | via BPA | — |

---

## 11. Quick-Reference Card

```
FLEXIBLE WORKFLOW:  Fiori "Manage Workflows" → Variant → Condition → Recipient → Activate
                    No ABAP code needed for standard SAP BOs

SWDD FROM RAP:      cl_swf_cpwf_api_factory=>get_instance( )->raise_event(
                        iv_event_object_type = 'ZSWOBJ'
                        iv_event_name        = 'SUBMITTED'
                        iv_object_key        = lv_key
                        it_binding           = lt_binding )

SAP BUILD PA:       POST /workflow/rest/v1/workflow-instances
                    { "definitionId": "...", "context": { ... } }
                    Via Communication Arrangement (OAuth 2.0 CC)

RAP ACTIONS:        BDEF:  action (features:instance) approve result [1] $self;
                    POOL:  MODIFY status + RAISE ENTITY EVENT ~approved
                    FEATURES: GET_INSTANCE_FEATURES → fc-o-enabled / fc-o-disabled

BRFPLUS:            cl_fdt_factory=>get_instance( )->get_function_accessor( )
                    ->get_function( iv_id = '<UUID>' )->process( io_context = ... )
```
