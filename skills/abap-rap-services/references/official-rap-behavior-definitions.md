# Official RAP Behavior Definitions Guide

This guide synthesizes the [RAP - Behavior Definitions](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-behavior-definitions?locale=en-US) landing page and its distributed RAP BDL detail tree reviewed on 2026-10-07: **180 behavior-definition-related topics / 127,339 words**, including **172 RAP BDL syntax topics**, with zero crawl failures. It provides an original declaration-level reference without copying SAP page bodies.

## Ownership Boundary

Use [RAP implementation selection](./official-rap-implementation-selection.md) before choosing a BDEF kind for a new solution. Use this guide to design and review BDEF declarations after the scenario and transaction owner are established. Use [RAP behavior implementation](./abap-rap-behavior-implementation.md) for generated handler signatures, behavior-pool classes, `FAILED`/`REPORTED`/`MAPPED`, saver methods, and implementation diagnostics.

A BDEF is based on a CDS model with one root entity; a root entity can have at most one BDEF. The BDEF defines the transactional contract visible to RAP consumers. It contains a header and one or more entity behavior definitions; each entity definition contains characteristics and a body.

## Complete BDL Scope

| BDL family | Topics | Purpose |
|---|---:|---|
| Managed and unmanaged BDEF | 99 | implementation type, header, entity characteristics/body, operations and lifecycle |
| BDEF extensions | 42 | extensibility enablement, base/projection/abstract extensions, added/extended elements |
| Projection BDEF | 18 | service-specific reuse, exposure, aliases, augment/precheck, new actions/functions |
| Abstract BDEF | 7 | deep action/function parameter typing, hierarchy, associations and deep mapping |
| Interface BDEF | 5 | stable EML interface over a base BO, explicit behavior reuse |

Source: [RAP Behavior Definitions](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-behavior-definitions?locale=en-US), [RAP BDL](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-bdl?locale=en-US).

## Select the BDEF Kind First

| Kind | Use | Runtime/implementation contract |
|---|---|---|
| `managed` | Framework-managed transactional BO over CDS entities and persistence | Framework handles standard operations, buffering, locking/save where declared; custom behavior still needs handlers |
| `unmanaged` | Existing/custom persistence or full application-owned transactional logic | Standard operations, locking, ETag/save responsibilities are implemented as required in the behavior pool |
| `projection` | Service/role-specific projection of a managed or unmanaged base BO, or a BO interface | Explicitly reuses/exposes selected behavior; may add projection-specific actions/functions and augment/precheck logic |
| `interface` | Stable EML consumption contract over a base BO | No runtime handler and no implementation class; inherits/reuses base behavior; EML-only and not directly exposed as a business service |
| `abstract` | Type contract, especially deep action/function parameters and results | No transactional behavior; limited associations, field characteristics, hierarchy and mapping |
| extension | Additive transportable extension of an enabled base/projection/abstract BDEF | Can add allowed elements; cannot modify, overwrite, or delete original elements |

Establish the exact release before selecting newer features such as collaborative draft, save actions, recommendations, alternative keys, instance hierarchy, or advanced extensibility.

Sources: [Managed and Unmanaged BDEFs](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-managed-and-unmanaged-behavior-definitions?locale=en-US), [Projection BDEFs](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-projection-behavior-definitions?locale=en-US), [Interface BDEF](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-interface-behavior-definition?locale=en-US), [Abstract BDEFs](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-abstract-behavior-definitions?locale=en-US), [BDEF Extension](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-bdef-extension?locale=en-US).

## Header Declaration Catalog

A managed/unmanaged header can declare:

- implementation type: `managed` or `unmanaged`
- save strategy: additional or unmanaged save, optionally cleanup/full data
- `implementation in class ... unique`
- strict mode and version
- auxiliary implementation classes
- extensibility enablement
- draft or collaborative draft
- privileged mode with an authorization context for disable
- cross-BO association support
- foreign entities for response/message mapping
- explicit cross-BO save ordering with `save after`
- one or more entity behavior definitions
- full/disable authorization contexts

### Strict Mode

Use the most recent strict mode supported by the target release, normally `strict(2)`. Strict mode makes implicit operations explicit, rejects outdated forms, and adds RAP contract checks. It is mandatory in some release/extensibility scenarios. A projection using strict mode requires its base to use the same strict-mode version. Strict composition trees cannot contain behavior-enablement gaps, and obsolete DDIC-based CDS views are not accepted under the documented strict rules.

### Implementation Class and Groups

A managed BO needs an implementation class when custom/unmanaged components require implementation; unmanaged behavior normally requires implementation. Entity declarations may assign implementation groups so implementation-relevant elements are divided among behavior-pool implementation classes. Do not invent a class or group layout independently of generated declarations.

### Save Options

Save options are available for managed BOs:

- `with additional save`: retain managed save and add `save_modified` logic.
- `with unmanaged save`: replace managed persistence; a persistent table must not be declared for that unmanaged-save entity/contract.
- `and cleanup`: requires saver cleanup implementation.
- `with full data`: passes all `%data` fields to `save_modified`; `%control` still marks only changed fields. Without it, unchanged field values are not reliable and must not be evaluated.

An unmanaged BO already owns its save strategy. Keep side effects, outbound calls, change logs, numbering, and final persistence in the legal RAP save phase.

Sources: [BDEF Header](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-behaviordefinitionheader?locale=en-US), [Strict Mode](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-bdef-strict-mode?locale=en-US), [Saving Options](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-savingoptions?locale=en-US).

## Entity Declaration Contract

Each BO node starts with `define behavior for Entity`, optionally with:

- `alias` for ABAP behavior methods and BDEF-derived types; maximum 30 characters
- `external` name for OData metadata; not known by ABAP
- an entity/group implementation class where allowed
- entity behavior characteristics
- an entity behavior body

Every transactional node needed in the composition tree must have an entity behavior definition under strict-mode rules. A CDS entity omitted from behavior has no transactional character. Keep aliases stable once used by implementations or consumers.

Source: [EntityBehaviorDefinition](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-entitybehaviordefinition?locale=en-US).

## Entity Characteristics Catalog

| Characteristic | Contract |
|---|---|
| `persistent table` | Managed persistence target; field/type mapping must be coherent |
| `draft table` / optional draft query | Draft persistence and query contract; only for draft-enabled scenarios |
| saving options | Entity-specific managed additional/unmanaged save |
| `lock master` / `lock dependent by` | Pessimistic concurrency ownership |
| `etag master` / `etag dependent by` | Active-data optimistic concurrency |
| `total etag` | Draft-to-active concurrency; mandatory for draft-enabled BOs and positioned directly after lock master |
| `authorization master (...)` / `authorization dependent by` | Modify/action/function authorization ownership |
| dependent short form | Combines lock, authorization, and ETag dependency along one association |
| `extensible` | Entity-level BDEF extensibility enablement |
| early/late numbering | Point in lifecycle at which primary key values are assigned |
| change documents | Entity-level change-document enablement where supported |

Each characteristic can occur only once per entity, and declaration order can be significant.

Source: [EntityBehaviorCharacteristics](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-entitybehaviorcharacteristics?locale=en-US).

## Concurrency

### Locking

- The root is a lock master; children are lock masters or lock-dependent through an explicitly behavior-enabled CDS association.
- Managed locking is framework-provided unless `lock master unmanaged` is selected.
- Unmanaged locking requires `FOR LOCK` implementation for lock masters.
- Update, delete, create-by-association, and actions normally request locks; an action can opt out only where `lock:none` is valid and safe.
- Managed create performs framework uniqueness handling; unmanaged create does not gain that behavior automatically.

### ETags

- `etag master Field` gives an entity its own optimistic concurrency token.
- `etag dependent by _Assoc` delegates to a higher ETag master; the association must be declared in CDS and enabled in the behavior body.
- `total etag Field` is mandatory for draft-enabled BOs and protects active/draft transitions after exclusive-lock expiry.
- Managed automatic timestamp handling requires the documented semantic annotations and supported timestamp type. Unmanaged code must update ETag/total-ETag values reliably, preferably in the save sequence.
- Mark framework-maintained ETag fields read-only.

Sources: [Locking](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-locking?locale=en-US), [ETag](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-etag?locale=en-US).

## Authorization

Every entity is an authorization master or authorization-dependent entity. The root must be an authorization master. Master choices are `global`, `instance`, `global, instance`, or `none`.

- Global authorization is implemented in `FOR GLOBAL AUTHORIZATION`.
- Instance authorization is implemented in `FOR INSTANCE AUTHORIZATION`.
- Combined control requires both methods.
- `none` prohibits authorization handler methods for that master contract.
- Operation-level additions can override/default authorization with `authorization:none`, `:update`, `:global`, or `:instance` where allowed.
- Dependent entities delegate standard modify authorization to their master, but actions/functions and certain associations can require their own methods.
- RAP BDEF authorization protects modify/nonstandard behavior. CDS DCL governs read access at the CDS entity actually read; do not treat BDEF authorization as a DCL replacement.
- `IN LOCAL MODE` and privileged mode bypass controls by explicit contract and require a reviewed trust boundary.

Authorization contexts document authorization objects used by implementation or define narrowly controlled disabling. A full context must be exhaustive. A disable context causes associated `AUTHORITY-CHECK` calls to return authorized and must be consistent with the full context, especially under strict(2).

Sources: [Authorization](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-authorization?locale=en-US), [AuthorizationContext](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-authorizationcontext?locale=en-US).

## Field Declaration Catalog

Supported field characteristics include:

- `readonly`
- `mandatory`
- `suppress`
- `features:instance`
- `mandatory:create`
- `mandatory:update`
- `readonly:create`
- `readonly:update`
- `recommendations`
- release-specific trigger/extension characteristics documented on the target system

Key rules:

- Primary key fields should be read-only or read-only on update, except for the explicit external-numbering contract.
- Plain `mandatory` is a consumer/UI hint and does not perform a runtime consistency check; implement a validation when persistence must be rejected.
- `mandatory:create` has stronger create-request enforcement than plain `mandatory`.
- Dynamic field features require `FOR INSTANCE FEATURES`; forbidden changes can be ignored rather than automatically reported.
- `suppress` removes eligible fields from BDEF-derived types and RAP APIs; keys, dependencies, ETag fields, referenced unit/currency fields, and used BDEF elements constrain suppression.
- Recommendations require a recommendation function, value-help support, and corresponding side effects.
- Managed internal numbering uses field numbering declarations; external, early, and late numbering have different lifecycle/handler contracts.

Source: [FieldCharacteristics](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-fieldcharacteristics?locale=en-US).

## Operations Catalog

### Standard and Association Operations

- Standard operations: create, read, update, delete. Managed BOs receive framework implementation; unmanaged BOs implement the applicable handler methods.
- Association behavior always enables read-by-association when declared. Add `create` to enable create-by-association.
- Draft association declarations must match draft scope (`with draft` or dependent-draft contract).
- Additions can include precheck, feature control, authorization control, external/internal exposure, and lock behavior where the operation permits them.

### Actions

Actions modify BO state and are implemented with `FOR MODIFY`. Forms include:

- instance or static non-factory actions
- factory/default factory actions that create instances
- save actions executed only in finalize/adjust-numbers save phases
- draft actions
- determine actions
- release-specific copy/reorder or hierarchy actions

Possible contracts include input/output parameters, result cardinality, feature/authorization control, precheck, repeatability, `lock:none`, internal/external names, and default-values functions. Save actions called during interaction cause a runtime failure; model them only for save-sequence work.

### Functions

Functions return information without side effects, locks, or modification. They require an output parameter and may have an input/default-values function. Forms include instance/static, repeatable, internal/external, feature/authorization controlled, and alternative-key functions. A function implementation that performs `MODIFY ENTITIES` violates the RAP contract and fails at runtime.

### Operation Addition Checklist

For every operation, decide and verify:

- instance-bound versus static
- mutation versus side-effect-free read
- input parameter type/deepness and output type/cardinality
- factory/save/draft/determine semantics
- repeatability and idempotence
- feature and authorization mode
- precheck/augment ownership
- lock requirement
- ABAP alias and external OData name
- exposure/reuse in interface and projection layers

Sources: [RAP BO Operations](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-rap-bo-operations?locale=en-US), [Action](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-action?locale=en-US), [Function](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-function?locale=en-US).

## Validations and Determinations

### Validation

A validation runs `on save` for declared create/update/delete or field triggers and is implemented `FOR VALIDATE`. It can reject the RAP transaction and report messages. One invalid instance rejects the complete transactional-buffer content for that save. After a failed commit, correct/delete the invalid instance or use `ROLLBACK ENTITIES`; the buffer is not automatically cleared.

- Execution order among validations is undefined.
- Do not make one validation depend on another.
- `MODIFY ENTITIES` is not allowed in validation implementation.
- Validations are available for managed BOs and draft-enabled unmanaged BOs, not unmanaged non-draft BOs.

### Determination

A determination runs `on modify` or `on save` for declared operation/field triggers and is implemented `FOR DETERMINE`. It may calculate and modify BO data.

- Results must be idempotent because the framework can execute a determination repeatedly.
- Execution order among determinations is undefined; each must be independent.
- On-modify results are available in the interaction phase; on-save results run in the save sequence.
- Trigger fields belong to the declaring entity; release-specific `notrigger` restrictions apply.
- Availability follows the documented managed/draft-enabled unmanaged rules.

Sources: [Validation](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-validation?locale=en-US), [Determination](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-determination?locale=en-US).

## Draft Contract

`with draft` or `with collaborative draft` enables framework draft handling. A complete draft contract aligns:

- draft table/query per node
- lock master and mandatory total ETag
- active-data ETag where needed
- draft-enabled associations
- draft actions such as Edit, Activate, Discard, Resume, Prepare, plus collaborative-draft actions where supported
- validations/determinations triggered on draft and activation paths
- projection/interface `use draft` and explicit reuse of draft actions

Draft locks have an exclusive phase followed by optimistic ETag control. Test abandoned drafts, expired locks, resume conflicts, activation failure, authorization during activation, and multi-node rollback.

## Projection and Interface Reuse

Behavior is not generally exposed merely because the CDS element is projected. Use declarations explicitly select the contract:

- `use create`, `use update`, `use delete`
- `use association`
- `use action`, `use function`
- `use draft` / collaborative/dependent draft
- `use etag`
- `use event` where allowed
- `use side effects`
- `use key`
- default-values functions and recommendations

The reused element must exist underneath. Reuse maps to the base implementation and needs no new handler. Projection-only `augment` and `precheck` do require implementation; they are unavailable in interface BDEFs. New projection actions/functions are service-specific and need their own handlers.

Important gates:

- Missing `use etag` loses optimistic concurrency checks at the projection/interface contract even if the field value continues to update.
- Draft reuse requires explicit draft-action and draft-association reuse.
- Business-event reuse is generally interface-only; events for side effects have their documented projection exception.
- Result entities must be projected/mapped or operations can disappear from service exposure.
- External aliases affect OData names and must match UI/service metadata consumers.

Source: [Use in Projection and Interface BDEF](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-use-projection-and-interface-bdef?locale=en-US).

## Abstract BDEF

An abstract BDEF is a typing model, not a transactional BO. Use it for flat/deep/table action or function parameters/results. Its limited body covers field characteristics such as suppression, associations/hierarchy, and deep/type mapping. It has no transactional operations or runtime behavior implementation. Keep its hierarchy and parameter cardinality aligned with the consuming action/function signature.

## Events, Side Effects, and Other Body Elements

### Events

BDEF event forms include application business events, derived/managed events based on existing events, and events solely for event-driven side effects. Event payload and release compatibility are API contracts. Route implementation/binding/Event Mesh design through the events guide.

### Side Effects

Side effects describe UI reload dependencies and require no behavior-pool implementation. Triggers include fields, `$self`, actions, determine actions, events, and recommendation functions; targets include fields/entities, permissions, messages, and other documented targets. Static actions cannot be side-effect triggers or targets. Side effects are metadata hints, not server-side consistency enforcement.

### Change Documents, Hierarchy, Keys, Mapping, Groups

The entity body can also declare:

- change-document logging options
- editable instance hierarchy and hierarchy actions
- pure/secondary alternative BDEF keys and key functions
- type/control mappings to persistence or partner structures
- implementation groups
- recommendation functions

Type mapping follows assignment/conversion rules. `corresponding`, exclusions, constants, parameters, control mapping, and extensible mapping must exactly cover the intended partner contract. No handler is required solely for declarative mapping.

Sources: [EntityBehaviorBody](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-entitybehaviorbody?locale=en-US), [Events](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-events?locale=en-US), [Side Effects](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-side-effects?locale=en-US), [TypeMapping](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-typemapping?locale=en-US).

## Extensions and Release Contracts

A BDEF must be explicitly extensible before extension. Enable only the required field, behavior, node, mapping, or operation extension points. Extensions are additive and cannot replace/delete original declarations. Base, projection, and abstract BDEF extensions have distinct allowed elements.

- Use customer/partner namespaces for extension and added element names.
- An extension inherits the original BO's release contract and must preserve it.
- C0 governs released extension points; C1 governs system-internal consumption interfaces; C2 remote API concerns belong to service exposure. Do not conflate these contracts.
- Released interface/projection BDEF changes must pass API consistency/compatibility checks; changing operations, parameters, field restrictions, authorization, keys, or draft/concurrency behavior can be breaking.

## Declaration-to-Implementation Matrix

| Declaration | Framework/declarative only | Handler/saver implementation |
|---|---|---|
| managed CRUD/persistence | Usually framework | Only custom/unmanaged components |
| unmanaged CRUD | No | Modify/read handlers and save as declared |
| readonly/mandatory/suppress | Static declaration | Validation still needed for plain mandatory business enforcement |
| instance features | Contract only | `FOR INSTANCE FEATURES` |
| global features | Contract only | `FOR GLOBAL FEATURES` |
| global/instance authorization | Contract only | Corresponding authorization methods |
| managed lock | Framework | None unless unmanaged lock selected |
| unmanaged lock | No | `FOR LOCK` |
| action | Signature/control | `FOR MODIFY ... ACTION` |
| function | Signature/control | `FOR READ ... FUNCTION`, no modification |
| validation | Trigger contract | `FOR VALIDATE` |
| determination | Trigger contract | `FOR DETERMINE` |
| precheck/augment/numbering | Contract | Matching generated method category |
| additional/unmanaged save | Save contract | Saver methods such as `save_modified`, cleanup as declared |
| side effects/type mapping | Declarative metadata/mapping | None solely for the declaration |
| projection/interface `use` | Reuses base | None unless projection adds augment/precheck/new operations |

Always derive exact method signatures from the activated BDEF and generated behavior-pool contracts.

## Validation Checklist

- Exact ABAP release/FPS and BDEF kind established
- CDS root/composition tree, keys, associations, persistence and projections activated
- Strict-mode version selected and consistent across base/projection
- No composition behavior gaps
- Alias/external names and derived-type impact reviewed
- Managed/unmanaged ownership documented for CRUD, lock, ETag, numbering and save
- Every node has lock, authorization and concurrency ownership
- Draft tables, total ETag, actions and association scope complete
- Field restrictions distinguished from runtime validations
- Operations have correct mutation, static/instance, parameter/result, feature, auth and lock contracts
- Validations/determinations independent, idempotent where required, and correctly timed
- Projection/interface explicitly reuses every intended operation/ETag/draft/event/side effect/key
- Extension points and release contracts verified
- Generated handler/saver declarations activated; no invented signatures
- EML tests cover create/update/delete, associations, actions/functions, authorization/features, draft, validation failure, concurrency conflict and rollback
- OData metadata/runtime tests confirm only intended projected behavior is exposed
- ATC/API compatibility, authorization, performance, logging, rollback and transport evidence complete
