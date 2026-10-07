# Official ABAP for RAP Business Objects Guide

This guide synthesizes the complete [ABAP for RAP Business Objects](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-for-rap-business-objects?locale=en-US) subtree reviewed on 2026-10-07: **204 topics / 184,998 words** with zero crawl failures. It provides an original ABAP/EML reference without copying SAP page bodies.

## Ownership Boundary

Use this guide for ABAP language elements that provide or consume RAP BOs: EML, transactional buffers, commits/rollbacks, BDEF-derived types, response components, behavior-pool phase restrictions, and local event handling.

- Use [RAP behavior definitions](./official-rap-behavior-definitions.md) for BDEF declaration design.
- Use [RAP behavior implementation](./abap-rap-behavior-implementation.md) for exact generated handler/saver signatures and class layout.
- Use [events and enhancements](./abap-events-and-enhancements.md) for event bindings, remote consumption, Event Mesh, and integration architecture.

## Complete Scope

| Branch | Topics | Purpose |
|---|---:|---|
| Consuming RAP BOs | 67 | EML read/modify/commit/rollback/permissions/locks/key conversion and tests |
| BDEF-derived types | 64 | operation-specific table/structure/request/response types and `%` components |
| Providing RAP BOs | 46 | behavior pools, handler/saver methods, provider EML and phase restrictions |
| Other RAP ABAP elements | 20 | type mapping, system classes, implementation rules and examples |
| RAP business events | 6 | event handler classes/methods, raising and local event consumption |

## Transactional Model

RAP operations work on a transactional buffer. Consumers see and change the current transactional image, not merely persisted database rows.

- Managed BOs use a framework-managed transactional buffer.
- Unmanaged BOs provide their own buffer and operation behavior, but must still satisfy the RAP BO consumer contract.
- A consumer can be the RAP runtime (for OData/business-service requests) or an ABAP program issuing EML.
- An ABAP behavior pool is a provider and can itself use EML, subject to phase and ownership restrictions.
- Reads normally include persisted state plus unsaved changes in the current RAP transaction.
- Modify operations change the buffer. An external ABAP consumer must explicitly trigger the save sequence; otherwise changes are lost.

Do not mix direct persistence updates with managed buffer state. Do not assume a database `SELECT` reflects unsaved EML changes.

Source: [ABAP for RAP Business Objects](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-for-rap-business-objects?locale=en-US).

## EML Statement Catalog

| Statement | Purpose | Main output |
|---|---|---|
| `READ ENTITY` / `READ ENTITIES` | Read instances, read-by-association, execute functions | `RESULT`, `FAILED`, optionally `REPORTED` |
| `MODIFY ENTITY` / `MODIFY ENTITIES` | Create, create-by-association, update, delete, execute actions | `MAPPED`, `FAILED`, `REPORTED`, action results |
| `GET PERMISSIONS` | Retrieve merged authorization and static/global/instance feature permissions | permission `RESULT`, `FAILED`, `REPORTED` |
| `SET LOCKS` | Request exclusive locks for BO instances | `FAILED`, `REPORTED` |
| `COMMIT ENTITIES` | Trigger save sequence and terminate the RAP transaction | `FAILED`, `REPORTED`, `sy-subrc`, late key conversion forms |
| `ROLLBACK ENTITIES` | Clear all changes and locks in the current RAP transaction | no response parameters |
| `CONVERT KEY` | Convert preliminary/temporary late-numbering keys to final keys | final-key result |

Most EML families have:

- a short static form for one entity,
- a long static form for multiple entities of one BDEF, and
- a dynamic form using generic operation/response tables.

Prefer static forms when the BO is known at compile time: the compiler validates BDEF-derived operand types and operations. Use dynamic EML only for genuinely dynamic frameworks and validate every operation/type at runtime.

Source: [Consuming RAP BOs](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-eml-consuming-rap-bos?locale=en-US).

## Read Contract

`READ ENTITY/ENTITIES` supports read, read-by-association, and function operations as declared by the BO contract.

- The result is the current transactional image: persisted values plus unsaved changes from the current RAP LUW.
- Request only required fields and keys; use one mass request rather than EML in a loop.
- Long form can bundle multiple entities; dynamic form can bundle runtime-defined operations.
- `WITH CHANGES` and local-mode variants are context-specific; verify exact target-release semantics.
- `REPORTED` on a read can retrieve state messages for instances/compositions and increases runtime. Do not request it when messages are not needed.
- Virtual elements in CDS projections are not generally available through EML reads as documented.
- A transactional projection/interface `WHERE` clause is not automatically an EML instance boundary. Use the documented managed instance filter when that filter must protect EML access.

Source: [READ ENTITY, ENTITIES](https://help.sap.com/docs/abap-cloud/abap-keyword/read-entity-entities?locale=en-US).

## Modify Contract

`MODIFY ENTITY/ENTITIES` supports:

- create
- create by association
- update
- delete
- execute action/factory action

Important gates:

- Fill `%cid` for create, create-by-association targets, and factory-action requests, or use `AUTO FILL CID` only where its dummy correlation is sufficient.
- Use `%cid_ref` to relate dependent requests to a prior create in the same EML request.
- Flag changed fields correctly in `%control`; an update must include at least one flagged non-key field.
- Do not submit duplicate update/delete/execute requests for one instance.
- Standard modify operations do not return changed entity data. Read the current image afterward if needed. Actions can return declared results.
- Request and process `FAILED`; retrieve `MAPPED` where numbering requires correlation; handle `REPORTED` messages.
- Bundle mass modifications. EML in loops can create repeated single accesses and N+1 behavior.
- If processing order among independent requests matters, use separate EML statements. Dependencies expressed through `%cid`, `%cid_ref`, or create-by-association establish their own request relationships.
- Projection/interface filters are not automatically applied to EML modify. Enforce the managed instance filter when that projection boundary is security-relevant.

Provider-side projection augmentation uses `MODIFY ... AUGMENTING`. It must not overwrite fields already controlled by the original request; additional instances must be related so responses can be mapped. Augmenting forms do not use ordinary `FAILED`/`MAPPED`/`REPORTED` additions.

Source: [MODIFY ENTITY, ENTITIES](https://help.sap.com/docs/abap-cloud/abap-keyword/modify-entity-entities?locale=en-US).

## EML Response Contract

| Response | Meaning | Typical components |
|---|---|---|
| `MAPPED` | Maps `%cid`/preliminary identity to real or preliminary keys | `%cid`, `%key`, `%tky`, `%pky`, `%pid`; late forms use `%pre`/`%tmp` |
| `FAILED` | Identifies operations/instances that failed and why | keys/identity, `%fail`, `%op`, operation markers |
| `REPORTED` | Returns transition/state messages and field/path targeting | `%msg`, `%element`, `%path`, `%state_area`, identity components |

Availability by statement:

- Modify: `MAPPED`, `FAILED`, `REPORTED`
- Read: `FAILED`, `REPORTED`
- Commit: `FAILED`, `REPORTED`
- Permissions: `FAILED`, `REPORTED`
- Locks: `FAILED`, `REPORTED`

Rules:

- Empty response tables mean no corresponding response, not that the consumer can ignore other contract outputs.
- Use `if_abap_behv_message` messages in `%msg`; use state-area and element/path markers only in handler phases where they are legal.
- Early responses belong to interaction phase; late responses belong to save sequence.
- `MAPPED` is required for framework/internal numbering scenarios where the consumer needs generated keys; it is not valid for plain external-numbering contracts.
- In late numbering, map every surviving preliminary key in `adjust_numbers`, then use `COMMIT ENTITIES BEGIN/END` and `CONVERT KEY` as documented.
- Fail causes and allowed `%state_area` combinations differ by handler/saver category. Follow the RAP implementation contract; invalid responses can cause `BEHAVIOR_BAD_HANDLER_RESPONSE`.

Sources: [EML Response Parameters](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-eml-response-param?locale=en-US), [TYPE RESPONSE FOR](https://help.sap.com/docs/abap-cloud/abap-keyword/type-response-for?locale=en-US).

## Commit and Rollback

### COMMIT ENTITIES

`COMMIT ENTITIES` triggers the RAP save sequence, terminates the RAP transaction, and persists all valid buffered changes. For a modifying RAP transaction it includes an implicit `COMMIT WORK`. The save is all-or-nothing across involved instances/BOs.

Forms include:

- short commit of all changed BOs,
- long `RESPONSE OF` for typed per-BO responses,
- dynamic `RESPONSES OF`,
- `BEGIN ... END` for late-numbering key conversion,
- simulation mode where supported by the target release.

Check both responses and `sy-subrc`:

- `0`: save/implicit commit completed successfully for a modifying transaction.
- `4`: failure in an early save phase such as finalize/check-before-save; failures are returned and interaction changes can remain in the buffer for correction.
- `8`: failure in a late save phase such as save/save-modified; rollback/cleanup occurs and an explicit `ROLLBACK ENTITIES` is required before safely proceeding.

`COMMIT ENTITIES` is for RAP consumers, not behavior-pool implementations. OData/RAP runtime requests commit automatically; provider code must never commit the transaction itself.

### ROLLBACK ENTITIES

`ROLLBACK ENTITIES` clears all current RAP transaction changes and locks and invokes cleanup. If modifications occurred, it also triggers rollback work semantics. It has no output parameters and cannot be called inside the BO implementation. Use it explicitly for custom ABAP consumers after failed/abandoned transactions, especially after late save failure.

Sources: [COMMIT ENTITIES](https://help.sap.com/docs/abap-cloud/abap-keyword/commit-entities?locale=en-US), [ROLLBACK ENTITIES](https://help.sap.com/docs/abap-cloud/abap-keyword/rollback-entities?locale=en-US).

## Permissions and Locks

### GET PERMISSIONS

Permissions combine:

- static field/operation characteristics from BDEF,
- global and instance feature control,
- global and instance authorization.

Request only relevant operations/fields using the request derived type and optional `ONLY` clause. Results can cover CRUD, create-by-association, fields, actions, and functions. Internal elements are not queryable as public permissions. Permissions are point-in-time hints for consumers; the runtime still enforces the operation when executed.

Do not use permission output as a substitute for server-side authorization. The projection/interface filter caveat also applies to permissions; use managed instance filtering where required.

### SET LOCKS

`SET LOCKS` requests exclusive BO-instance locks until transaction end. Child lock requests resolve to their lock master. A parallel lock failure appears in `FAILED` with the lock cause. Provider use is restricted to documented lock/modify handler phases. Do not hold locks across user interaction or external network waits.

Sources: [GET PERMISSIONS](https://help.sap.com/docs/abap-cloud/abap-keyword/get-permissions?locale=en-US), [SET LOCKS](https://help.sap.com/docs/abap-cloud/abap-keyword/set-locks?locale=en-US).

## Local and Privileged Access

### IN LOCAL MODE

`IN LOCAL MODE` is available for provider-side read/modify of the same BO and suppresses feature control, authorization checks, and prechecks only for elements owned by the using provider.

- It is not a general consumer bypass.
- Calling such reused code outside the owning implementation context can short dump.
- It does not suppress checks owned by another provider/base/extension.
- A BAdI called from an implementation is not automatically part of that implementation context.
- Extension and cross-BO scenarios can implicitly retain/forward privileged context; review the complete call chain.

Use local mode to implement BO-internal state transitions, not to avoid modeling authorization or field-control correctly.

### PRIVILEGED / FORWARDING PRIVILEGED

Privileged EML is valid only for entities enabled with BDEF privileged mode. `PRIVILEGED` bypasses configured authority checks. `FORWARDING PRIVILEGED` propagates an existing privileged context to subsequent BO calls and does nothing if the target is not enabled.

Treat privileged access as a security-sensitive API:

- require an explicit trusted caller and authorization context,
- document which checks are bypassed,
- preserve/forward context only when intended,
- audit cross-BO and save-phase effects,
- never expose a generic privileged helper to untrusted application code.

Sources: [IN LOCAL MODE](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-eml-in-local-mode?locale=en-US), [PRIVILEGED](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-eml-privileged?locale=en-US).

## BDEF-Derived Types

BDEF-derived types are compiler-generated from CDS entities plus their BDEF. They provide type-safe messenger tables and structures for provider/consumer communication and mass processing.

Declaration families:

- `TYPE TABLE FOR ...`: operation-specific internal-table type
- `TYPE STRUCTURE FOR ...`: operation-specific line/structure type
- `TYPE REQUEST FOR CHANGE|DELETE`: deep saver request structures for managed additional/unmanaged save
- `TYPE RESPONSE FOR FAILED|MAPPED|REPORTED [EARLY|LATE]`: deep response structure with one nested entity table per BO node

Common operation-derived purposes include create, update, delete/key, read result, action/function import/result, permissions, features, authorization, lock, numbering, change and saver requests.

These types are compiler-known rather than DDIC repository types. Use ADT F2 and code completion on the actual target BDEF; do not hand-create equivalent structures or guess components.

Source: [BDEF Derived Types](https://help.sap.com/docs/abap-cloud/abap-keyword/bdef-derived-types?locale=en-US).

## Percent-Component Catalog

### Identity and Keys

- `%cid`: consumer-supplied content ID for create/factory correlation
- `%cid_ref`: reference to a prior content ID in a dependent request
- `%key`: persisted primary-key component group
- `%tky`: transactional key, including draft identity where applicable
- `%pky`: preliminary/parent-related key context as generated
- `%pid`: preliminary identity for late numbering
- `%pre` / `%tmp`: late key conversion structures
- `%is_draft`: active versus draft identity

### Data and Control

- `%data`: entity data component group; often includes key fields
- `%control`: per-field markers indicating supplied/changed fields
- `%param`: action/function/event parameter payload
- `%target`: create-by-association target request table/group
- `%field`, `%features`, `%perm`: request/result control for features and permissions

### Operation and Response

- `%create`, `%update`, `%delete`, `%action`, `%assoc`, `%op`: operation markers/context
- `%fail`: failure cause
- `%msg`: behavior message reference
- `%element`: field-specific message/permission targeting
- `%path`: composition/association path context
- `%state_area`: state-message lifecycle area
- `%global`: global rather than instance-specific response
- `%other`, `%own`: context-specific generated groups

Component availability depends on operation, phase, draft, numbering, and BDEF. A field can often be addressed directly or through `%data`/`%key`; do not assign the same physical component through multiple aliases because the final assignment wins and warnings/errors can result.

Source: [Components of BDEF Derived Types](https://help.sap.com/docs/abap-cloud/abap-keyword/components-of-bdef-derived-types?locale=en-US).

## Provider Architecture

An ABAP behavior pool contains local handler and saver classes derived from framework base classes.

- Handler methods implement read/modify, actions/functions, validations, determinations, features, authorization, locks, prechecks, augmentation, and numbering as generated by the BDEF.
- Saver methods implement the legal save-sequence phases such as finalize, check-before-save, adjust-numbers, save/save-modified, cleanup and message mapping as declared.
- Provider-side EML includes ordinary local-mode access and special augmentation variants.
- Exact formal parameters are implicit BDEF-derived types even where declarations use generic `TYPE DATA` placeholders.

Use the generated declarations and the implementation guide for method signatures. Never infer a signature from another BO or release.

## Handler and Saver Phase Restrictions

RAP runs in a controlled SAP LUW. Allowed operations differ by method category and save phase.

Universal gates:

- No `COMMIT WORK`, `COMMIT ENTITIES`, `ROLLBACK WORK`, or `ROLLBACK ENTITIES` in handlers/savers.
- No explicit database commits.
- Direct standard-connection database modification is forbidden during interaction/early phases and permitted only in documented save phases.
- Update-task/background-process calls are restricted to documented late-save phases.
- EML modify is forbidden in validation and most save methods; it is available only in explicitly documented categories such as ordinary modify/determination/finalize or augmenting contexts.
- Read EML, permissions, locks, authorization checks, and classified transactional APIs vary by phase. Consult the target-release restriction matrix rather than generalizing.
- APIs classified with transactional interfaces (`IF_ABAP_TX_*`) must match the current phase classification.
- Functions are side-effect-free; modify EML in a function causes a runtime contract violation.

Source: [Restrictions in RAP Handler and Saver Methods](https://help.sap.com/docs/abap-cloud/abap-keyword/restrictions-in-rap-handler-and-saver-methods?locale=en-US).

## RAP Contract Checks

Design provider and consumer code to avoid contract violations:

- missing `%cid` for create/create-by-association/factory action
- wrong BDEF-derived operand type
- empty update or missing `%control`
- duplicate update/delete/execute requests
- modify EML in a forbidden save phase
- incomplete preliminary-to-final key mapping
- invalid fail cause or response identity
- illegal `%state_area`/operation-marker combinations
- state messages returned from phases that prohibit them
- provider failure entries unrelated to the request
- consumer attempts to change static read-only fields or omit enforced create fields
- ambiguous/unnecessary duplicate consumer operations
- augmentation that overwrites original controlled fields
- authorization checks outside declared contexts
- non-privileged CDS access where the controlled LUW requires privileged access
- save action execution outside its declared saver phase

Contract checks are runtime protection, not a replacement for focused unit/EML tests.

Source: [RAP Implementation Rules](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-implementation-rules?locale=en-US).

## Type Mapping and RAP-Aware ABAP

RAP-related mapping mechanisms include:

- `CORRESPONDING` with BDEF type mapping
- ABAP SQL `MAPPING FROM ENTITY`
- `SET FLAGS` and `SET NAMES`
- behavior auxiliary/context classes such as `CL_ABAP_BEHV_AUX`

Use the BDEF's declared type/control mapping rather than ad hoc field-name conversions. Verify assignment compatibility and `%control` behavior. Check every helper class/method for target-release API availability.

## RAP Business Events in ABAP

The ABAP language surface includes:

- `CLASS ... FOR EVENTS OF` event handler classes
- `CL_ABAP_BEHAVIOR_EVENT_HANDLER`
- `METHODS ... FOR ENTITY EVENT`
- `RAISE ENTITY EVENT`
- local event consumption examples

Event raising belongs to the legal RAP transaction/save phase and payload type generated by the BDEF event declaration. Event publication/delivery is not equivalent to a direct method call; design idempotence, correlation, authorization, failure handling, and monitoring in the events/integration guides.

Source: [ABAP for RAP Business Events](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-for-rap-business-events?locale=en-US).

## Testing Workflow

1. Activate CDS, BDEF, implementation and projection/service contracts.
2. Derive request/result/response types from the actual BDEF.
3. Test mass requests, not only one instance.
4. Assert `MAPPED`, `FAILED`, and `REPORTED`, including keys, paths, fail causes, messages and state areas.
5. Read the transactional image before commit where required.
6. Test early save rejection (`sy-subrc = 4`) and late save failure (`sy-subrc = 8`) recovery.
7. Roll back each test transaction or use the RAP BO test-double/environment pattern appropriate to the codebase.
8. Test authorization/features with normal, local, and privileged contexts separately.
9. Test numbering/key conversion, draft identity, locks and concurrency.
10. Measure bundled versus looped EML at realistic volume.

## Validation Checklist

- Exact ABAP release/FPS, BDEF and entity aliases verified
- Provider versus consumer role and interaction/save phase identified
- Static EML form used unless genuine runtime dynamism is required
- Correct operation-derived request/result type selected
- `%cid`, `%cid_ref`, keys, draft identity and `%control` complete
- `MAPPED`, `FAILED`, `REPORTED` handled for the statement/phase
- Reads use the transactional image intentionally
- EML requests are batched and not hidden in loops
- Projection/interface instance filtering reviewed for EML security
- Permission results not treated as authorization enforcement
- Local/privileged bypass has a documented trust boundary
- No forbidden commit/rollback/database modification in provider code
- Commit responses and `sy-subrc` 0/4/8 handled
- Failed/abandoned transactions explicitly corrected or rolled back
- Late numbering maps every surviving preliminary key
- Handler/saver phase restrictions and RAP contract checks satisfied
- Events raised/consumed in legal phases with operational monitoring
- Focused EML tests cover success, partial interaction failure, save failure, rollback, authorization, features, locks, draft and concurrency
