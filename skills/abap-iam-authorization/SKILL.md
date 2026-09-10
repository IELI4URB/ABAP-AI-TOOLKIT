---
name: abap-iam-authorization
description: >-
  IAM and Authorization architecture for SAP ABAP Cloud. Covers authorization objects, AUTHORITY-CHECK, RAP authorization master (global and instance), CDS Access Control (DCL roles), business roles, restriction types, IAM apps, business catalogs, privilege checks, and the full authorization flow from BDEF to business role assignment. Triggers: authorization, AUTHORITY-CHECK, auth object, business role, IAM, DCL, access control, restriction type, catalog, privilege, role, permission, global auth, instance auth, field-level auth.
metadata:
  version: 1.0.0
  tags: abap iam authorization dcl business-role access-control abap-cloud security
---

# IAM and Authorization Architecture for ABAP Cloud

Expert guide for designing and implementing authorization in SAP ABAP Cloud — from auth objects to business role assignment.

**Golden rule: Authorization is MANDATORY, not optional. Check at BDEF level (RAP auth master) AND CDS level (DCL). UI-only checks are NEVER sufficient.**

Reference files:
- `references/iam-complete.md` — full implementation patterns for auth objects, DCL, business roles, and RAP authorization

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

## Authorization Layers

```
┌─────────────────────────────────────────────┐
│ Layer 1: CDS Access Control (DCL)           │
│ - Row-level filtering at data access        │
│ - Enforced by DB engine (cannot bypass)     │
├─────────────────────────────────────────────┤
│ Layer 2: RAP Authorization (BDEF)           │
│ - Operation-level (create/update/delete)    │
│ - Global: "Can user access BO at all?"      │
│ - Instance: "Can user access THIS record?"  │
├─────────────────────────────────────────────┤
│ Layer 3: Field-Level Control                │
│ - Sensitive field visibility/editability    │
│ - Via feature control in BDEF               │
├─────────────────────────────────────────────┤
│ Layer 4: Business Role Assignment           │
│ - IAM App → Business Catalog → Business Role│
│ - Assigned to users by administrator        │
└─────────────────────────────────────────────┘
```

---

## RAP Authorization (BDEF)

```
define behavior for ZI_Travel alias Travel
  authorization master ( global, instance )
{
  create;
  update;
  delete;
}
```

### Global Authorization Implementation
```abap
METHOD get_global_authorizations.
  AUTHORITY-CHECK OBJECT 'ZTRAVEL'
    ID 'ACTVT' FIELD '01'.  " Create
  IF sy-subrc <> 0.
    result-%create = if_abap_behv=>auth-unauthorized.
  ENDIF.
ENDMETHOD.
```

### Instance Authorization Implementation
```abap
METHOD get_instance_authorizations.
  READ ENTITIES OF zi_travel IN LOCAL MODE
    ENTITY Travel FIELDS ( AgencyID ) WITH
    CORRESPONDING #( keys )
    RESULT DATA(lt_travels).

  LOOP AT lt_travels INTO DATA(ls_travel).
    AUTHORITY-CHECK OBJECT 'ZTRAVEL'
      ID 'ZAGENCY' FIELD ls_travel-AgencyID
      ID 'ACTVT' FIELD '02'.  " Update
    IF sy-subrc <> 0.
      APPEND VALUE #( %tky = ls_travel-%tky
        %update = if_abap_behv=>auth-unauthorized
        %delete = if_abap_behv=>auth-unauthorized
      ) TO result.
    ENDIF.
  ENDLOOP.
ENDMETHOD.
```

---

## CDS Access Control (DCL)

```cds
@EndUserText.label: 'Travel Access Control'
@MappingRole: true
define role ZR_Travel {
  grant select on ZI_Travel
  where ( AgencyID ) = aspect pfcg_auth( ZTRAVEL, ZAGENCY )
    and ( ) = aspect pfcg_auth( ZTRAVEL, ACTVT, '03' );
}
```

---

## IAM Artifact Flow

```
Authorization Object (ZTRAVEL)
    ↓
IAM App (ZTRAVEL_IAM)  →  references auth object + service binding
    ↓
Business Catalog (ZTRAVEL_BC)  →  groups IAM apps
    ↓
Business Role (BR_TRAVEL_MANAGER)  →  assigned to users
    ↓
Restriction Type  →  field-level value restrictions on role
```

---

## Response Rules

### "How do I add authorization?" questions
→ Show full stack: BDEF auth master → implementation → DCL → IAM app → catalog → role
→ Always include both global AND instance authorization

### "What's the difference between DCL and RAP auth?" questions
→ DCL = row filtering (data access), enforced by DB, SELECT returns only allowed rows
→ RAP auth = operation control (can user CREATE/UPDATE/DELETE), checked before operation

### "How do I restrict by field value?" questions
→ Show Restriction Type on business role
→ AND DCL role with aspect pfcg_auth filtering

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
