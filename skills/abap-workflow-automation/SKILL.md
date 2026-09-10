---
name: abap-workflow-automation
description: >-
  Workflow and process automation for SAP ABAP Cloud. Covers Classic Workflow (SWDD task types, agent determination, binding), Flexible Workflow (BRFplus conditions, process variants), SAP Build Process Automation integration, approval patterns, workflow API for RAP integration, and decision guides for choosing the right workflow technology. Triggers: workflow, approval, SWDD, flexible workflow, SAP Build, process automation, agent determination, task, work item, approve, reject, workflow API, BRFplus, decision table, process variant.
metadata:
  version: 1.0.0
  tags: abap workflow approval process-automation sap-build flexible-workflow abap-cloud
---

# Workflow and Process Automation for ABAP Cloud

Expert guide for implementing approval workflows and process automation — Classic Workflow, Flexible Workflow, and SAP Build Process Automation.

**Golden rule: Simple approval → Flexible Workflow. Complex multi-step → SAP Build PA. Legacy integration → Classic SWDD. Always keep business rules in BRFplus, not hardcoded.**

Reference files:
- `references/workflow-complete.md` — full implementation patterns for all workflow types

## SAP Help Syntax Grounding (Mandatory)

For ABAP/CDS/BDL/EML syntax, use SAP Help as source of truth.

Rules:
- Do not provide unverified syntax for ABAP statements, CDS DDL, behavior definitions, EML, or RAP annotations/options.
- For non-trivial syntax responses, add a short "Syntax references" section with SAP Help links used.
- If exact syntax is uncertain, explicitly mark it as draft and require SAP Help verification.
- Never invent statement additions, annotation names, or behavior options.

Core SAP Help references:
- https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/cbb86e63a8464e63bbdd43b7bfa5fc4f.html
- https://help.sap.com/docs/ABAP_Cloud/bbcee501b99848bdadecd4e290db3ae4/404edb8b4c0648dca4d8f5a2fdfa6c58.html
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/c35896101f8c417482fd040d477bbbe1.html

Syntax verification steps:
1. Validate keywords and clause names against ABAP Keyword Documentation terminology.
2. Validate RAP strict mode and BDEF/BDL constructs against RAP docs.
3. Validate CDS form and annotation usage against CDS docs.
4. Validate EML operation form and response handling pattern.
5. Reconfirm clean-core and released-object constraints.
Syntax output contract (mandatory when providing ABAP/CDS/BDL/EML syntax):
1. Add `Syntax confidence` with exactly one value: `verified`, `partial`, or `draft`.
2. Add `Syntax references` with SAP Help links for each non-trivial syntax area used.
3. If confidence is `partial` or `draft`, add `Verification required` with unresolved syntax items.
4. Do not provide final production code when confidence is `draft`.


---

## Workflow Technology Decision Matrix

| Requirement | Technology | When to Use |
|---|---|---|
| Simple 1-step approval | **Flexible Workflow** | Approve/reject with conditions |
| Multi-step with parallel branches | **SAP Build Process Automation** | Complex orchestration |
| Integration with legacy ABAP | **Classic Workflow (SWDD)** | Existing investment, ABAP-centric |
| Rule-based routing | **BRFplus** | Dynamic agent/condition determination |
| External process orchestration | **SAP Build PA + API** | Cross-system, human + bot tasks |

---

## Platform Availability

| Technology | Public Cloud | Private Cloud | BTP |
|---|---|---|---|
| Classic Workflow (SWDD) | Limited | Full | N/A |
| Flexible Workflow | Full | Full | N/A |
| SAP Build Process Automation | Via BTP | Via BTP | Native |
| BRFplus (rules) | Full | Full | Via API |

---

## Flexible Workflow Pattern

```
1. Define Workflow Scenario (Fiori: Manage Workflows)
2. Configure Steps:
   - Start condition (status = 'submitted')
   - Approval step (agent = manager of requestor)
   - Outcome: Approve → set status 'A' / Reject → set status 'R'
3. Link to RAP BO via Workflow Integration API
4. Deploy and test
```

---

## Classic Workflow Integration with RAP

⚠️ `CL_SWF_RUN_WIM_FACTORY` is NOT released in ABAP Cloud. Use the Workflow Push API instead:

```abap
" Trigger workflow from RAP action (ABAP Cloud — released API)
METHOD trigger_approval_workflow.
  " Use released Workflow Context Push API (SAP_COM_0542)
  DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
    comm_scenario = 'SAP_COM_0542' ).
  DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).

  DATA(lo_req) = lo_client->get_http_request( ).
  lo_req->set_uri_path( '/internal/workflow/rest/v1/workflow-instances' ).
  lo_req->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).

  " Build context payload
  DATA(lv_payload) = |\{"definitionId":"my_approval_wf","context":\{"travelId":"{  travel-%key-TravelID  }"\}\}|.
  lo_req->set_text( lv_payload ).

  TRY.
      DATA(lo_resp) = lo_client->execute( if_web_http_client=>post ).
    CATCH cx_web_http_client_error INTO DATA(lx).
      RAISE EXCEPTION TYPE cx_workflow_trigger_failed EXPORTING previous = lx.
    CLEANUP.
      lo_client->close( ).
  ENDTRY.
ENDMETHOD.
```

**Note:** For S/4HANA Private Cloud with full Basis stack, `CL_SWF_CPWF_API_FACTORY=>GET_API_INSTANCE` is available but is NOT released for ABAP Cloud (Public Cloud / BTP ABAP).

---

## SAP Build Process Automation Integration

```
1. Create Process in SAP Build (BTP)
2. Define Forms (approval form with travel details)
3. Define Decision (auto-approve if < 5000)
4. Configure API Trigger (from ABAP Cloud via HTTP)
5. Map outcomes back to RAP BO status
```

### Triggering from ABAP Cloud:
```abap
" Call SAP Build PA REST API
DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
  comm_scenario = 'Z_BUILD_PA_SCENARIO' ).
DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).

DATA(lo_req) = lo_client->get_http_request( ).
lo_req->set_uri_path( '/workflow/rest/v1/workflow-instances' ).
lo_req->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
lo_req->set_text( lv_json_context ).

DATA(lo_resp) = lo_client->execute( if_web_http_client=>post ).
```

---

## Response Rules

### "I need an approval workflow" questions
→ First determine complexity: 1-step? multi-step? cross-system?
→ Simple approval → Flexible Workflow
→ Complex → SAP Build Process Automation
→ Show integration pattern with RAP BO

### "Classic SWDD or new workflow?" questions
→ New development: Flexible Workflow or SAP Build PA
→ Existing SWDD workflows: keep if working, migrate on next change
→ Show decision matrix

### "How do I determine the approver?" questions
→ BRFplus decision table for dynamic routing
→ Org structure-based (manager of requestor)
→ Amount-based (threshold → different approver level)

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. Context and landscape assumptions (Public Cloud, Private Cloud ABAP Cloud, or BTP ABAP Environment)
2. Recommended approach with rationale and Clean Core impact
3. Implementation outline (objects, APIs, contracts, and constraints)
4. Validation plan (tests, checks, and rollback considerations)
5. Evidence and risk notes (source references, version sensitivity, and open assumptions)

Hard rules:
- Do not invent SAP objects, APIs, CDS entities, annotations, or transactions.
- Prefer released APIs and upgrade-safe extension mechanisms.
- Flag version-sensitive guidance explicitly when release context is uncertain.

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Architecture or design trade-offs | decision matrix + constraints + target-state blueprint |
| New implementation | modeling flow + API contract + test strategy |
| Performance issue | hotspot isolation + pushdown/pagination/index strategy |
| Security or authorization | threat points + authorization model + hardening controls |
| Integration behavior | protocol contract + resilience patterns + observability |
| Code review or readiness | findings first + risk ranking + concrete remediation steps |
