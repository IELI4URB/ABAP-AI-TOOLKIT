---
name: abap-events-and-enhancements
description: >-
  RAP Business Events, Cloud BAdIs, and enhancement mechanisms for SAP ABAP Cloud. Covers RAISE ENTITY EVENT, local and remote event consumption, Event Mesh integration, Cloud BAdI implementation (GET BADI/CALL BADI), derived events, and the decision matrix for choosing between Events vs BAdIs vs BDEF Extensions vs CDS Extensions. Use when asked about events, BAdI, enhancement, after sales order create, event-driven, decouple, react to changes, extension points, RAISE ENTITY EVENT, Event Mesh, event binding. Triggers: RAP event, business event, BAdI, enhancement, RAISE ENTITY EVENT, event binding, Event Mesh, cloud BAdI, extension point, react after, decouple, event-driven, after create, after save.
metadata:
  version: 1.0.0
  tags: abap rap-events badi enhancement event-mesh abap-cloud clean-core extensibility
---

# Events & Enhancements for ABAP Cloud

Expert guide for event-driven architecture and clean-core enhancement mechanisms in SAP ABAP Cloud (S/4HANA Public/Private, BTP ABAP).

**Golden rule: Events for AFTER (decoupled reaction). BAdIs for DURING (synchronous influence). Never modify standard code.**

Reference files:
- `references/events-and-badi-patterns.md` — complete implementation patterns with code for RAP events, BAdIs, and extensions

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

## Decision Matrix: Which Enhancement Mechanism?

| Need | Mechanism | Coupling | Data Flow | Use When |
|---|---|---|---|---|
| React AFTER something happened | **RAP Business Event** | Loose (async) | One-way (fire and forget) | After SO create → notify warehouse |
| Influence DURING processing | **Cloud BAdI** | Tight (sync) | Two-way (can modify) | During pricing → apply custom discount |
| Add fields to existing BO | **CDS View Extension** | Structural | N/A | Add custom field to standard Travel BO |
| Add validation/action to existing BO | **BDEF Extension** | Behavioral | N/A | Add custom validation to standard PO |
| Add UI annotations to existing view | **Metadata Extension** | UI only | N/A | Change column order on standard list |

---

## RAP Business Events — Architecture

### Event Lifecycle
```
1. DEFINE event in BDEF     → declares what events exist
2. RAISE event in save phase → fires when BO state changes
3. CONSUME locally          → handler class in same system
4. EXPOSE externally        → Event Binding → Event Mesh → external consumer
```

### Event Declaration (BDEF)
```
managed implementation in class ZBP_I_TRAVEL unique;

define behavior for ZI_TRAVEL alias Travel
{
  ...
  event TravelCreated parameter ZD_TravelCreatedPayload;
  event TravelAccepted;
  event TravelRejected parameter ZD_TravelRejectedPayload;
}
```

### Raising Events (Behavior Pool — SAVE_MODIFIED only)
```abap
METHOD save_modified.
  IF create-travel IS NOT INITIAL.
    RAISE ENTITY EVENT zi_travel~TravelCreated
      FROM VALUE #( FOR travel IN create-travel
        ( %key = travel-%key
          %param = VALUE #( travel_id = travel-TravelID
                            agency_id = travel-AgencyID ) ) ).
  ENDIF.
ENDMETHOD.
```

**Critical rules:**
- `RAISE ENTITY EVENT` is ONLY allowed in `SAVE_MODIFIED` or `CLEANUP_FINALIZE` phase
- NOT allowed in validations, determinations, or actions
- Event is raised AFTER successful save (transactional guarantee)
- Parameter CDS entity must be abstract: `define abstract entity ZD_TravelCreatedPayload`

### Local Consumption (same system, since S/4HANA 2023)
```abap
CLASS zcl_travel_event_handler DEFINITION
  INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.
    METHODS on_travel_created FOR ENTITY EVENT
      travel_created FOR Travel~TravelCreated.
ENDCLASS.

CLASS zcl_travel_event_handler IMPLEMENTATION.
  METHOD on_travel_created.
    LOOP AT travel_created INTO DATA(event).
      " React: create follow-up document, send notification, etc.
      DATA(travel_id) = event-%param-travel_id.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

### Remote Consumption (Event Mesh)
1. Create **Event Binding** in ADT (New → Other → Event Binding)
2. Map RAP event to topic: `sap/s4/beh/travel/v1/Travel/Created/v1`
3. Configure **Enterprise Event Enablement** channel (Communication Arrangement `SAP_COM_0092`)
4. External consumer subscribes to topic via Event Mesh / Integration Suite

---

## Cloud BAdI — Implementation Pattern

### Discovery
1. SAP Business Accelerator Hub → S/4HANA Cloud → On-Stack Extensibility → BAdIs
2. ADT → Released Objects tree → Enhancement Spots → [Application Component]
3. Search by process area (e.g., "Material Document", "Purchase Order")

### Implementation Steps
```abap
" 1. Get BAdI handle
DATA(lo_badi) = NEW zcl_my_badi_impl( ).

" Actually — in ABAP Cloud, BAdI is called by framework automatically:
" You just implement the interface in a class and register it.

" Step 1: Create Enhancement Implementation (ADT)
" Right-click Enhancement Spot → New Enhancement Implementation

" Step 2: Implement the BAdI interface
CLASS zcl_mat_doc_badi DEFINITION FINAL
  PUBLIC SECTION.
    INTERFACES if_mm_purchase_order_check.
ENDCLASS.

CLASS zcl_mat_doc_badi IMPLEMENTATION.
  METHOD if_mm_purchase_order_check~check.
    " Your custom validation logic
    IF purchase_order-amount > 100000.
      APPEND VALUE #( message = 'Amount exceeds limit' ) TO messages.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```

### BAdI vs Event Decision
```
Ask: "Do I need to MODIFY data during processing?"
  YES → Cloud BAdI (synchronous, can return values/modify)
  NO  → "Do I need guaranteed delivery to external system?"
    YES → RAP Event + Event Mesh (async, reliable delivery)
    NO  → "Is it same-system reaction?"
      YES → RAP Event + Local Consumption (lightweight)
      NO  → RAP Event + Event Mesh
```

---

## BDEF Extension (Extend Standard SAP BO)

```
" Extend standard SAP Travel BO with custom validation
extend behavior for R_PurchaseOrderTP {
  validation myCustomCheck on save { create; update; }
  determination setCustomField on modify { field Amount; }
  event CustomAmountExceeded parameter ZD_AmountPayload;
}
```

**Prerequisites:**
- Standard BO must be released for extension (check C1 contract + extensibility enabled)
- Use ADT: Right-click BDEF → New Behavior Extension
- Extension runs within the SAME transaction as standard logic

---

## Platform Availability

| Feature | Public Cloud | Private Cloud | BTP ABAP |
|---|---|---|---|
| RAP Business Events (define/raise) | 2211+ | 2022+ | 2208+ |
| Local event consumption | 2302+ | 2023+ | 2208+ |
| Event Binding (remote) | 2211+ | 2022+ | 2208+ |
| Derived Events | 2311+ | 2023 FPS01+ | 2311+ |
| Cloud BAdI implementation | All | All | All |
| BDEF Extension | All | All | All |
| CDS View Extension | All | All | All |

---

## Response Rules

### "After X happens, I need to do Y" questions
→ This is an EVENT scenario (react AFTER)
→ Show RAP Business Event pattern (define → raise → consume)
→ Determine: local consumption or remote (Event Mesh)?

### "During X processing, I need to change Y" questions
→ This is a BAdI scenario (influence DURING)
→ Show Cloud BAdI discovery and implementation
→ Verify BAdI is released (check Business Accelerator Hub)

### "I need to add a field/action to standard SAP BO" questions
→ This is an EXTENSION scenario
→ Show BDEF Extension or CDS View Extension
→ Verify extensibility is enabled on the standard BO

### "Events vs BAdI — which one?" questions
→ Use the Decision Matrix at the top
→ Key question: "Do you need to MODIFY data or just REACT?"

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
