---
name: abap-cloud-vscode-adt-object-workflow
description: "Mandatory workflow for creating and populating ABAP repository objects in a VS Code + murbani ABAP remote-fs session (abap: URIs). Use whenever a new ABAP object (table, CDS view, behavior definition, class, service definition/binding, DCL) must be created in a connected system from this workspace."
tools: Read, Edit, Write
---
You are applying the verified object-creation protocol for VS Code ABAP remote-fs (`abap:` URIs, murbani.vscode-abap-remote-fs extension).

## Hard-learned rule (verified empirically, do not re-litigate)

Writing files directly into a package path that does not yet contain the target
object does **not** reliably create a real ADT repository object:
- A raw file write can report success yet leave the parent category folder
  empty (no real object registered server-side).
- Edits made this way can silently revert on the next sync from the server.

Real object creation only happens through the VS Code command
`adt-vscode.createObject` (Command Palette or right-click on the package),
which performs the actual ADT create call (package, transport, object type,
name, description).

Once a shell exists (its folder appears under the correct category in the
package tree), direct file edits via `create_file` / `replace_string_in_file`
DO persist reliably and are the normal way to populate/iterate on the object.

## Mandatory protocol

1. Never attempt to originate a brand-new object by writing files into a path
   that doesn't exist yet. Do not "test" this again — it is a settled finding.
2. For each new object needed, tell the user:
   - Exact object type (Database Table, Data Definition, Behavior Definition,
     Class, Service Definition, Service Binding, Access Control/DCL, etc.)
   - Exact name
   - One-line description
   - Target package and transport request to select in the wizard
3. Ask the user to run `adt-vscode.createObject` for that object (batching
   same-type objects is fine).
4. Before editing, verify the shell actually exists: `list_dir` the parent
   category folder and confirm the object's subfolder appears, then read the
   generated skeleton file(s) to see the exact scaffolded clauses (alias
   placeholders, implementation class name, etc.) before overwriting them.
5. Populate the source files directly once confirmed. Re-run `get_errors`
   after population and after every user-reported activation error.
6. Prefer creating dependency-ordered batches (tables → CDS interface views →
   CDS projection views → behavior definitions → behavior implementation
   classes → service definitions → service bindings) and confirm each batch
   activates cleanly before moving to the next.
7. When the auto-generated implementation class name in a Behavior Definition
   differs from an originally planned name, adopt the generated name rather
   than renaming the BDEF reference, to minimize churn.

## Discovered folder taxonomy and file extensions (per package)

| Object type | Folder | Source file extension | Metadata sidecar |
|---|---|---|---|
| Database Table | `Dictionary/Database Tables/<NAME>/` | `.tabl.ddic` | `.tabl.json` |
| CDS View Entity (interface or projection) | `Core Data Services/Data Definitions/<NAME>/` | `.ddls.acds` | `.ddls.json` |
| Behavior Definition | `Core Data Services/Behavior Definitions/<NAME>/` | `.bdef.abdl` | `.bdef.json` |
| Class | `Source Code Library/Classes/<NAME>/` | `.clas.abap` (+ `.clas.definitions.abap`, `.clas.implementations.abap`, `.clas.macros.abap`, `.clas.testclasses.abap`) | `.clas.json`, `.clas.texts.en.properties` |
| Service Definition | `Business Services/Service Definitions/<NAME>/` | `.srvd.acds` | `.srvd.json` |
| Service Binding | `Business Services/Service Bindings/<NAME>/` | none (metadata/UI-configured only) | `.srvb.json` |

Metadata Extensions (DDLX) and DCL access control roles have not yet been
verified in this workspace — confirm the folder/extension the same way
(create shell first, then inspect) before assuming a pattern.

## Known pitfalls already fixed once — check for these first

- `@Semantics.amount.currencyCode` on a DDIC table field requires the
  **fully-qualified** `'<table_name>.<field_name>'` reference (e.g.
  `'zfianomexc.currency'`), not a bare field name (`'currency'`). A bare
  reference produces "Annotation with reference to currency code for field
  ... is incomplete", and ADT's own quick-fix may partially "fix" this by
  appending a stray `.` without the table prefix — don't leave that in place.
- A CDS view entity intended as a RAP root uses the `define root view entity`
  keyword directly in the DDL (not a separate flag). Without it, activating a
  dependent projection with a Behavior Definition fails with "Transactional
  Projection View must be part of a business object" — this clears once the
  view is marked `root` and/or once the Behavior Definition exists.
- Each Behavior Definition targets exactly one root view (or one projection);
  don't expect one BDEF object to define "multiple roots".

## Behavior implementation class structure (mandatory, verified via real activation)

For a managed Behavior Definition's implementation class (`zbp_*`, created via
`adt-vscode.createObject` type Class, name taken from the BDEF's
`managed implementation in class ...` line):

- The **global class** (`.clas.abap`) stays a plain, empty shell:
  ```abap
  CLASS zbp_i_<entity> DEFINITION PUBLIC ABSTRACT FINAL
    FOR BEHAVIOR OF zi_<entity>.
  ENDCLASS.

  CLASS zbp_i_<entity> IMPLEMENTATION.
  ENDCLASS.
  ```
- `.clas.definitions.abap` stays **blank** (only the boilerplate comment).
  Do not put the local handler class `DEFINITION` here — this was tried and
  produces "Local classes of CL_ABAP_BEHAVIOR_HANDLER can only be derived in
  the Local Definitions/Implementations of a global BEHAVIOR class."
- `.clas.implementations.abap` holds **both** the local handler class
  `DEFINITION ... ENDCLASS.` and its `IMPLEMENTATION ... ENDCLASS.`, back to
  back, in that one file:
  ```abap
  CLASS lhc_<entity> DEFINITION INHERITING FROM cl_abap_behavior_handler.
    PRIVATE SECTION.
      METHODS ...
  ENDCLASS.

  CLASS lhc_<entity> IMPLEMENTATION.
    METHOD ...
    ENDMETHOD.
  ENDCLASS.
  ```
- If the BDEF declares `authorization master ( instance )`, the local handler
  class **must** implement a `FOR INSTANCE AUTHORIZATION` method, even though
  a DCL role also exists — omitting it causes every other operation
  (validations, determinations, actions) in the same BDEF to be reported as
  "not implemented", which is a confusing cascading symptom of this one
  missing method:
  ```abap
  METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
    IMPORTING keys REQUEST requested_authorizations FOR <alias> RESULT result.

  METHOD get_instance_authorizations.
    result = VALUE #( FOR key IN keys ( %tky = key-%tky
                                         %update = if_abap_behv=>auth-allowed
                                         %delete = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.
  ```
- In `FOR MODIFY ... FOR ACTION` method bodies, when the entity has a
  composition child (making its `FAILED`/`REPORTED` types "deep"), a direct
  or table-level `CORRESPONDING #( lt_failed )` assignment into
  `failed-<alias>` fails with "must be both structures or both internal
  tables". Use **per-row** `CORRESPONDING` inside a table constructor instead:
  ```abap
  failed-<alias>   = VALUE #( FOR ls_failed   IN lt_failed   ( CORRESPONDING #( ls_failed ) ) ).
  reported-<alias> = VALUE #( FOR ls_reported IN lt_reported ( CORRESPONDING #( ls_reported ) ) ).
  ```
- The `get_errors` tool result on these split-file class objects is
  sometimes **stale** (references content that was already removed, or shows
  "No errors found" when a real activation in ADT reports otherwise). Treat
  a live ADT activation report from the user as the source of truth; re-run
  `get_errors` after an edit but don't argue with the user's real activation
  result if it conflicts.

## Confirmed error, corrected by the user (do not repeat)

The `FAILED`/`REPORTED` variables captured from
`MODIFY ENTITIES ... FAILED DATA(lt_failed) REPORTED DATA(lt_reported)` are
themselves **structures with one component per entity alias touched by that
statement** (e.g. `lt_failed-exception`), not directly usable as a table.
Writing `failed-<alias> = VALUE #( FOR ls IN lt_failed ( ... ) )` (looping
over `lt_failed` directly) is wrong and causes the type-mismatch errors seen
above, even with per-row `CORRESPONDING`. The corrected, working form
(confirmed by real ADT activation) is:
```abap
failed-exception   = VALUE #( FOR ls_failed   IN lt_failed-exception   ( CORRESPONDING #( ls_failed ) ) ).
reported-exception = VALUE #( FOR ls_reported IN lt_reported-exception ( CORRESPONDING #( ls_reported ) ) ).
```
i.e. always drill into `lt_failed-<entity_alias>` / `lt_reported-<entity_alias>`
before iterating, matching the entity alias used in the preceding
`MODIFY ENTITIES ... ENTITY <alias>` block.

Also confirmed in this session: `CX_ABAP_BEHV` (the base class SAP's own RAP
tutorials use for message-carrying exceptions) was reported "unknown" in this
particular system/release. The working fallback is inheriting from
`CX_STATIC_CHECK` instead, keeping `IF_T100_DYN_MSG` (and
`IF_ABAP_BEHV_MESSAGE` if it resolves) for T100 message-text wiring. Verify
`CX_ABAP_BEHV` availability per-system before assuming it; don't treat its
absence as a syntax error on your part.
