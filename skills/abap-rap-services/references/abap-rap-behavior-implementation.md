---
name: abap-rap-behavior-implementation
description: 'Implement and troubleshoot RAP behavior-pool classes for ABAP Cloud. Use for lhc_* handlers, CL_ABAP_BEHAVIOR_HANDLER, FOR VALIDATE, DETERMINE, ACTION, FUNCTION, AUTHORIZATION, FEATURES, precheck, numbering, unmanaged saver, FAILED, REPORTED, MAPPED, and behavior implementation activation errors.'
metadata:
  version: 4.0.0
  tags: abap rap bdef behavior-implementation eml handler failed reported
---

# RAP Behavior Implementation

Use this skill for implementation-class mechanics below the BDEF declaration layer. Use [the official BDEF guide](./official-rap-behavior-definitions.md) for behavior declaration design and syntax, and [the ABAP-for-RAP guide](./official-abap-for-rap-business-objects.md) for EML, BDEF-derived types, transactional phases, and provider restrictions. The complete behavior implementation reference is inlined below for generated implementation mechanics.

## Workflow

1. Inspect the BDEF, entity aliases, implementation class, method declaration, and target release.
2. Classify the method category and implicit response types.
3. Read only the corresponding reference section.
4. Verify handler signature and caller/callee types against generated contracts.
5. Make the smallest implementation change, activate, and run focused behavior tests.

## Reference Routing

| Need | Section |
|---|---|
| Split-source behavior-pool layout | Split-source class structure |
| Instance/global authorization | Instance Authorization; method-category reference |
| `FAILED`, `REPORTED`, `MAPPED`, `%msg` | FAILED / REPORTED shape |
| Message exception class | Message-carrying exception class base |
| Validation, determination, action, function | Full method-category reference |
| Features, prechecks, numbering | Full method-category reference |
| Stale diagnostics | Diagnostics caveat |

## Gates

- Never invent handler signatures or EML response shapes; inspect generated contracts and current SAP Help.
- Match entity aliases exactly when accessing nested response components.
- Distinguish declarative BDEF design from behavior implementation mechanics.
- Treat system-specific activation findings as evidence for that release, not universal syntax.


## RAP Behavior Implementation Class Mechanics

This skill covers the **implementation class** layer referenced by a
Behavior Definition's `managed implementation in class zbp_xxx unique;`
clause — distinct from `abap-cds-data-modeling`, which covers the CDS/BDEF
*declarative* layer only.

**Golden rule: the global `zbp_*` class stays an empty shell. All real logic
lives in a local class (`lhc_*`) inheriting `CL_ABAP_BEHAVIOR_HANDLER`.**

For a **custom entity used as an unmanaged RAP BO with actions**, first load
`abap-cds-data-modeling` and follow its `references/cds-complete-syntax.md`
section **Custom Entity RAP BO with Actions**. That section owns the complete
artifact chain: root custom entity, `IF_RAP_QUERY_PROVIDER`, unmanaged BDEF,
behavior pool, transactional buffer, saver, and service exposure. Apply this
skill to the handler methods, implicit response parameters, and saver mechanics.

### SAP Help Syntax Grounding (Mandatory)

Core SAP Help references used and verified for this skill:
- Business Object (behavior pool / local handler classes): https://help.sap.com/docs/abap-cloud/abap-rap/business-object
- Authorization Control (Global/Instance Authorization methods): https://help.sap.com/docs/abap-cloud/abap-rap/authorization-control
- Actions: https://help.sap.com/docs/abap-cloud/abap-rap/actions
- Validations: https://help.sap.com/docs/abap-cloud/abap-rap/validations
- Messages (state vs. transition, %MSG in REPORTED): https://help.sap.com/docs/abap-cloud/abap-rap/messages
- Functions (read-only custom operations): https://help.sap.com/docs/abap-cloud/abap-rap/functions
- Feature Control (overview): https://help.sap.com/docs/abap-cloud/abap-rap/feature-control
- Instance Feature Control (static/dynamic, field clauses, FOR INSTANCE FEATURES): https://help.sap.com/docs/abap-cloud/abap-rap/instance-feature-control
- Implementing Prechecks (FOR CREATE/FOR UPDATE precheck methods, worked example): https://help.sap.com/docs/abap-cloud/abap-rap/implementing-prechecks
- Numbering (early/late, managed/unmanaged, FOR NUMBERING): https://help.sap.com/docs/abap-cloud/abap-rap/numbering
- Determinations: https://help.sap.com/docs/abap-cloud/abap-rap/determinations
- **Implicit Response Parameters** (authoritative source for FAILED/REPORTED/MAPPED shape and all `%...` components): https://help.sap.com/docs/abap-cloud/abap-rap/implicit-response-parameters
- Entity Manipulation Language (EML): https://help.sap.com/docs/abap-cloud/abap-rap/entity-manipulation-language-eml
- ABAP for RAP, BDEF Derived Types (ABAP Keyword Documentation): https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=ABENRPM_DERIVED_TYPES.htm

Rules:
- Do not invent EML clause forms or handler method signatures.
- The split-source file placement (`.clas.definitions.abap` vs
  `.clas.implementations.abap`) and the local-class-must-be-nested compiler
  rule were **verified via real ADT activation** in a specific system (not
  found as an explicit statement on a public SAP Help page at time of
  writing) — treat as `verified` per this skill's own testing, but re-confirm
  if a future SAP Help page states otherwise.
- The FAILED/REPORTED nested-table-per-entity shape and `%MSG` /
  `IF_ABAP_BEHV_MESSAGE` are directly quoted from SAP Help (see above) —
  `Syntax confidence: verified`.

---

### Split-source class structure (verified via real ADT activation)

| File | Content |
|---|---|
| `.clas.abap` (global class) | Empty shell only: `CLASS zbp_xxx DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zi_xxx. ENDCLASS.` + empty `IMPLEMENTATION`. **Never** put `INHERITING FROM cl_abap_behavior_handler` or method declarations here — causes "Local classes of CL_ABAP_BEHAVIOR_HANDLER can only be derived in the Local Definitions/Implementations of a global BEHAVIOR class." |
| `.clas.definitions.abap` | Leave **blank** (boilerplate comment only) for behavior-pool classes. |
| `.clas.implementations.abap` | Holds **both** the local handler class `DEFINITION ... ENDCLASS.` and its `IMPLEMENTATION ... ENDCLASS.`, back to back, in this one file. |

This matches SAP Help's own description on the Business Object page: *"The
implementation of a behavior definition can be done in a single ABAP class
(behavior pool) or can be split between an arbitrary set of ABAP classes
(behavior pools)"* — the local handler class (commonly named `lhc_*`) is the
actual behavior pool; the global `zbp_*` class is the BDEF-bound anchor.

```abap
" .clas.implementations.abap
CLASS lhc_threshold DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR threshold RESULT result.
    METHODS validatethreshold FOR VALIDATE ON SAVE
      IMPORTING keys FOR threshold~validatethreshold.
ENDCLASS.

CLASS lhc_threshold IMPLEMENTATION.
  METHOD get_instance_authorizations.
    result = VALUE #( FOR key IN keys ( %tky = key-%tky
                                         %update = if_abap_behv=>auth-allowed
                                         %delete = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD validatethreshold.
    " ... business logic
  ENDMETHOD.
ENDCLASS.
```

### Instance Authorization (SAP Help: "Authorization Control")

Per SAP Help: *"Instance authorization is used for all authorization checks
that, in addition to the user role, depend on the state of the entity
instance in question... the implementation method for instance
authorizations requires the keys of the instance for the authorization
check."* — and *"For them, authorization is defined in the behavior
definition and implemented in the methods for authorization."*

**Practical rule confirmed via real activation in this skill's authoring
system**: if the BDEF declares `authorization master ( instance )`, the
handler class must implement a `FOR INSTANCE AUTHORIZATION` method — even
if a DCL role also exists. Omitting it does not fail cleanly; instead every
other validation/determination/action in the same BDEF gets reported as
"not implemented" by the compiler, which looks unrelated to the real cause.
Always check for this method first when multiple unrelated-looking
"not implemented" errors appear together.

- Instance authorization is **not possible** for CREATE or static actions
  (SAP Help: "Operations that are excluded from instance authorization are
  CREATE and static actions... Static operations don't relate to one
  specific instance, and thus, can't provide a key.").
- `IN LOCAL MODE` on an EML statement bypasses both `FOR GLOBAL
  AUTHORIZATION` and `FOR INSTANCE AUTHORIZATION` checks (only valid when
  consuming your own BO from within its own behavior pool).

### FAILED / REPORTED shape (SAP Help verified — "Implicit Response Parameters")

Direct quotes from SAP Help:
> "FAILED — This exporting parameter is defined as a **nested table which
> contains one table for each entity defined in the behavior definition**."
> "REPORTED — ... It is defined as a **nested table which contains one table
> for each entity** defined in the behavior definition."
> "%MSG — Provides an instance of the message interface
> **IF_ABAP_BEHV_MESSAGE**."

This means `lt_failed`/`lt_reported` captured from
`MODIFY ENTITIES OF ... ENTITY <alias> ... FAILED DATA(lt_failed) REPORTED DATA(lt_reported).`
are **structures with one table component per entity alias**, e.g.
`lt_failed-<alias>` — never a directly-iterable table by themselves.

```abap
" WRONG — lt_failed is a structure, not a table; fails with a type-mismatch
" or MOVE-CORRESPONDING error at the failed-<alias> assignment
failed-exception = lt_failed.
failed-exception = CORRESPONDING #( lt_failed ).

" CORRECT — drill into the entity-alias component, then per-row CORRESPONDING
failed-exception   = VALUE #( FOR ls_failed   IN lt_failed-exception   ( CORRESPONDING #( ls_failed ) ) ).
reported-exception = VALUE #( FOR ls_reported IN lt_reported-exception ( CORRESPONDING #( ls_reported ) ) ).
```

The entity-alias suffix (`-exception` above) must match the alias used in the
preceding `MODIFY ENTITIES ... ENTITY <alias>` block, which may differ from
the outer action method's own entity alias if a composition child was also
touched in that same statement.

Other documented `%...` components worth knowing (SAP Help, same page):
`%tky` (all key elements incl. `%is_draft`), `%cid`/`%cid_ref` (temporary key
for numbering scenarios), `%control` (which fields were supplied/requested),
`%data` (all data elements), `%fail` (failure symptom), `%element` (fields a
message relates to), `%param` (action import/result type).

### Message-carrying exception class base

SAP's own RAP tutorials use `CX_ABAP_BEHV` as the base class for exceptions
assigned to `%msg` in `reported-<alias>`. This class's availability is
**release/system-dependent** — verified absent ("Type CX_ABAP_BEHV is
unknown") in at least one real system during this skill's authoring. Fallback
pattern:

```abap
CLASS zcx_xxx_msg DEFINITION PUBLIC INHERITING FROM cx_static_check FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_t100_dyn_msg.
    INTERFACES if_abap_behv_message.

    CONSTANTS:
      BEGIN OF some_error,
        msgid TYPE symsgid VALUE 'ZMSG_CLASS',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF some_error.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL.
ENDCLASS.

CLASS zcx_xxx_msg IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
```

### Full method-category reference (SAP Help)

RAP handler classes implement one method per behavior-definition operation.
Every category below is a distinct `FOR ...` method form; mixing them up (or
omitting a mandatory one) is the single biggest source of "not implemented" /
"is unknown" activation errors.

#### Validation — `FOR VALIDATE ON SAVE`
*"An invoked validation can reject inconsistent instance data from being
saved by passing the keys of failed instances to the corresponding table in
the FAILED structure... a validation can return messages... by passing them
to the REPORTED structure."* Constraints: **not allowed** to use EML modify
statements inside a validation; execution order across multiple triggered
validations is **not guaranteed**; in unmanaged scenarios validations only
apply to draft instances.

#### Determination — `FOR DETERMINE ON SAVE` / `FOR DETERMINE ON MODIFY`
*"A determination is implicitly invoked by the business object's framework
if the trigger condition... is fulfilled... An invoked determination can
compute data, modify entity instances according to the computation result
and return messages to the consumer."* Constraints: result **must be
idempotent** (same result if run multiple times under the same conditions);
execution order across determinations is **not guaranteed**; in unmanaged
scenarios determinations only apply to draft instances; a determination
triggered on create+delete in the same request can hit a read-not-found
condition — handle defensively.

#### Action — `FOR MODIFY ... FOR ACTION`
*"Actions are executed by calling the corresponding method FOR MODIFY that
has typed import and export parameters. They are identified as actions by
the syntax FOR ACTION."* An action can be `internal` (BDEF: `internal action
ActionName`) — only callable from other business logic (validations,
determinations, other non-internal actions), never externally.

#### Function — `FOR READ ... FOR FUNCTION` (read-only, no side effects)
*"A function in RAP is a custom read-operation... Functions perform
calculations or reads on business objects without causing any unintentional
consequences. Functions don't issue any locks on database tables and you
can't modify or persist any data computed in a function implementation."*
Functions can only return **transition** messages, never state messages.
Triggered by a consumer, an action, a determination via EML, or another BO.

#### Instance/Global Authorization — `FOR INSTANCE AUTHORIZATION` / `FOR GLOBAL AUTHORIZATION`
See the dedicated section below — mandatory whenever the BDEF declares
`authorization master ( instance )` / `authorization master ( global )`.

#### Instance/Global Feature Control — `FOR INSTANCE FEATURES` / `FOR GLOBAL FEATURES`
Controls whether fields/operations/actions/functions are enabled, read-only,
or mandatory — either **statically** (fixed BDEF clauses) or **dynamically**
(implemented in the behavior pool). Static field clauses (BDL, on the field
in the BDEF): `field ( readonly )`, `field ( mandatory:create )`, `field
( readonly:update )`, `field ( readonly:create )`, `field ( mandatory:update
)`, `field ( suppress )`. Dynamic control needs `field ( features:instance )`
in the BDEF plus an implementation of `FOR INSTANCE FEATURES` returning per
field: `UNRESTRICTED`, `MANDATORY`, `READONLY`, or `ALL`. For operations,
actions, and functions: add `( features:instance )` to the operation/action/
function in the BDEF, then implement `FOR INSTANCE FEATURES` returning
`ENABLED` or `DISABLED` per instance. *"You can use either instance feature
control or global feature control on an operation, function, or action. You
can't combine both options."* CREATE cannot have instance-level feature
control (no instance exists yet).

#### Precheck — `create ( precheck )` / `update ( precheck )` + `FOR CREATE` / `FOR UPDATE`
*"With the addition of precheck, the behavior implementation for precheck is
called, before the main operation is executed... receives all entities to be
created and returns failed and reported as changing parameters if the check
against the incoming values returns a negative result."* Used to check
**incoming values** before they reach the transactional buffer (regular
authorization/validation methods can only check the *before image*, not
incoming values). For draft-enabled BOs, add `with additional implementation`
to the draft action `Resume` so edit-drafts re-trigger the precheck. **ADT
provides a quick-fix to generate the precheck method declaration directly
from the behavior definition editor** — prefer that over hand-typing the
signature.

#### Numbering — `FOR NUMBERING`
*"Numbering is about setting values for primary key fields of entity
instances during runtime."* Four combinations along two axes:
- **Early vs. late**: early = key set immediately on CREATE (by consumer,
  framework, or a `FOR NUMBERING` method); late = key assigned internally
  only after the point of no return in the SAVE sequence (gap-free, e.g.
  invoice numbers).
- **Managed vs. unmanaged**: managed = framework assigns the key
  automatically with no behavior-pool code (e.g. UUID keys); unmanaged =
  an implementation is required (in `FOR NUMBERING` for early, or in the
  saver methods for late).

#### Authorization in projection BDEFs
Reused (`use`) operations inherit authorization from the base BDEF; new
actions/functions defined at projection level (with `strict` mode) must
declare their own `authorization global`/`authorization instance`
individually — there is **no master/dependent relation** between different
projection definitions. `authorization:none` excludes an action/function
from authorization checks entirely.

### Diagnostics caveat

Static/lint-style error checks on split-source class files (`.clas.abap` +
`.clas.definitions.abap` + `.clas.implementations.abap` checked individually)
can be **stale or per-file-isolated**, missing the cross-file assembly the
real ABAP compiler performs on activation. Treat a live ADT activation result
as the source of truth over any standalone linter/diagnostics read against
these split files.

### Response Rules

#### "Why is my behavior implementation class not activating?" questions
→ Check split-source placement first (empty definitions file, both DEFINITION
  and IMPLEMENTATION of the local class in the implementations file)
→ Check for a missing `FOR INSTANCE AUTHORIZATION` method if `authorization
  master ( instance )` is declared
→ Check FAILED/REPORTED usage for the entity-alias-structure pitfall
→ Ask for a real ADT activation error message before proposing further fixes
