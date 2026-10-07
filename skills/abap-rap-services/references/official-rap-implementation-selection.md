# Official RAP Implementation Selection Guide

This guide turns SAP's [Developing RAP Business Objects](https://help.sap.com/docs/abap-cloud/abap-rap/develop?version=sap_cross_product_abap) scenario catalog into a decision workflow. Use it before choosing CDS entity types, BDEF implementation type, draft model, behavior handlers, or service binding.

The SAP development guide is scenario-oriented: choose the desired outcome first, then follow the matching end-to-end path. Do not begin with `managed` versus `unmanaged` in isolation.

## Required Inputs

Establish these facts before selecting an implementation:

1. **Outcome:** read-only query, transactional BO, analytical table, remote façade, UI app, or Web API.
2. **Data source:** local tables/released CDS, existing RAP BO, legacy transactional API, remote OData/API, or mixed sources.
3. **Transaction owner:** RAP framework, existing legacy logic, or a managed BO with custom save integration.
4. **Editing model:** immediate save, exclusive draft, collaborative draft, cross-BO draft scope, hierarchy editing, or mass inline maintenance.
5. **Consumer:** Fiori Elements UI service, known ABAP/EML consumer, or unspecified remote API clients.
6. **Nonfunctional constraints:** authorization, volume, latency, offline/resume needs, concurrency, release contract, extensibility, and operations.
7. **Landscape/release:** Public Cloud, Private Cloud/on-premise ABAP Cloud, or BTP ABAP Environment and exact release/FPS.

If any controlling input is unknown, do not generate a BDEF or handler skeleton yet.

## Fast Decision Flow

1. **No data changes?**
   - Standard list/search/value-help UI: choose a read-only list-reporting service.
   - Aggregation/grouping analytical UI: choose a read-only RAP analytical table.
   - Remote or heterogeneous query data: choose a CDS custom entity with an unmanaged query provider; add local transactional behavior only for locally persisted fields when required.
2. **Transactional changes?**
   - Greenfield persistence and no existing transaction engine: choose managed RAP.
   - Existing legacy transaction API/buffer/save/lock logic owns correctness: choose unmanaged RAP or a wrapper architecture.
   - Framework-managed interaction but special persistence/save integration: choose managed RAP with additional save or unmanaged save after validating the save contract.
3. **Users need resumable/inconsistent work?**
   - One editing owner at a time: exclusive draft.
   - Multiple invited users edit the same draft: collaborative draft.
   - Multiple independent BOs must edit/activate as one draft scope: cross-BO draft scope.
   - Otherwise use non-draft transactional behavior.
4. **Special UI shape?**
   - Parent-child hierarchy display only: read-only treeview/hierarchy.
   - Editable hierarchy: managed draft BO with instance hierarchy/treeview contract.
   - SM30-like mass maintenance: multi-inline edit with singleton technical root; accept that this changes the BO shape.
5. **Consumer contract?**
   - Fiori Elements: OData V4 UI service plus UI metadata.
   - Unspecified external client: Web API service binding and versioned remote API contract.
   - ABAP-only stable consumption: RAP BO interface released for the intended C1/C0 contract and consumed with EML.

## Primary Scenario Matrix

| Scenario | Choose when | Core implementation | Avoid when |
|---|---|---|---|
| Read-only list report | Existing data needs navigation, texts, value help, search, labels and UI service | CDS interface/projection, annotations/metadata extension, service definition/binding | Business changes or custom transactional buffer are required |
| Read-only analytical table | UI requires aggregation and grouping over read-only data | Read-only BO, analytical projection annotations, OData V4 UI service | Row-level transactional editing or extensibility incompatible with analytical-table restrictions is required |
| Managed transactional | New application, local persistence, RAP can own buffer/CRUD/save | Managed BDEF, persistent tables, custom actions/validations/determinations, projection/service | Existing legacy transaction engine must remain authoritative |
| Unmanaged transactional | Existing APIs/business logic/persistence own CRUD, buffer or save | Unmanaged BDEF and complete provider implementation over legacy logic | Greenfield CRUD could be framework-managed more safely and cheaply |
| Exclusive draft | Users must pause/resume, retain inconsistent work, recover sessions, one edit owner | Managed or unmanaged draft BO, draft tables, total ETag, draft actions, draft projection | Short atomic edits do not justify draft complexity |
| Collaborative draft | Multiple authorized users must edit one shared draft | Collaborative-draft BDEF, Share action, draft query/DCL and global/instance authorization | Concurrent co-editing is not a real business requirement |
| Cross-BO draft scope | Separate draft BOs must be edited/activated as one LUW | Principal/dependent draft BOs, cross associations, reverse association, link/unlink/inverse behavior | A single composition BO can correctly own the lifecycle |
| Hierarchical app | Data is naturally parent-child and needs tree visualization | CDS hierarchy; read-only treeview or managed-draft editable instance hierarchy | A flat list/object page meets the workflow |
| Multi-inline edit | Users maintain many master/configuration rows together, SM30-style | Draft BO with singleton technical root and editable child list | Same BO must also retain a normal root-list-report shape |
| Remote-service UI façade | UI combines remote OData data with local enrichment/persistence | Service Consumption Model, client proxy, custom entity/unmanaged query, local behavior | Remote data can be replicated/owned locally or direct remote UI consumption suffices |
| Web API | Undefined clients consume an OData business contract | Existing RAP BO/projection plus Web API service binding, API versioning/security | Service is UI-only and no stable remote contract is intended |
| RAP recommendations | Context-aware proposals are needed for value-help-backed input fields | Recommendation fields/function, side effects, UI service and target-release support | Deterministic validation/defaulting alone meets the requirement |

Source: [Developing RAP Business Objects](https://help.sap.com/docs/abap-cloud/abap-rap/develop?version=sap_cross_product_abap), [Develop Applications](https://help.sap.com/docs/abap-cloud/abap-rap/develop-applications?version=sap_cross_product_abap).

## Managed Versus Unmanaged

### Choose Managed RAP by Default for Greenfield

Managed RAP is the default when:

- persistence is under your control,
- no existing transactional buffer/save engine must be preserved,
- standard create/update/delete semantics fit the BO,
- framework locking, concurrency and save sequencing are desired,
- custom logic can be expressed as actions, validations, determinations, features, authorization and saver extensions.

The managed provider supplies standard CRUD, transactional buffering and generic interaction/save processing. Application code focuses on business behavior.

Source: [Developing Managed Transactional Apps](https://help.sap.com/docs/abap-cloud/abap-rap/developing-managed-transactional-apps?version=sap_cross_product_abap).

### Choose Unmanaged Only When Application Logic Owns the Transaction

Unmanaged RAP is appropriate when:

- released/legacy APIs must execute CRUD,
- existing logic owns persistence consistency, locks, numbering or save order,
- persistence is not directly compatible with managed mapping,
- the application must provide its own transactional buffer and complete REST contract.

Unmanaged means the provider implements standard operations, buffer behavior and save sequence responsibilities. It is not merely “managed with more custom code.” Validate that the reused legacy operations can obey RAP LUW, idempotence, message, authorization and rollback contracts.

Source: [Developing Unmanaged Transactional Apps](https://help.sap.com/docs/abap-cloud/abap-rap/developing-unmanaged-transactional-apps?version=sap_cross_product_abap).

## Managed Hybrid Save Options

Do not jump from managed directly to full unmanaged when only save integration differs.

| Option | Choose when | Responsibility |
|---|---|---|
| Managed default save | RAP tables and mapping can persist the BO | Framework performs persistence |
| Managed with additional save | Managed persistence remains authoritative, but audit/log/change-document/outbound additions are required | Framework saves; saver adds legal post/parallel save work |
| Managed with unmanaged save | Managed interaction/buffer is useful, but application-specific persistence must replace framework persistence | Application implements save logic; no managed persistent-table contract for that entity |
| Fully unmanaged | Existing transaction engine must own interaction operations and save | Application owns buffer, CRUD and save behavior |

Select the narrowest ownership transfer that satisfies the requirement. Review allowed saver phases and failure recovery before choosing either custom save option.

## Read-Only Selection

### List Reporting

Choose read-only list reporting for existing persistent sources where consumers need associations, text display, value helps, search and Fiori Elements navigation. Model reusable semantics in the CDS interface layer and app presentation in the projection/metadata layer.

Source: [Developing Read-Only List Reporting Apps](https://help.sap.com/docs/abap-cloud/abap-rap/developing-read-only-list-reporting-apps?version=sap_cross_product_abap).

### Analytical Table

Choose a RAP analytical table for aggregation/grouping in an OData V4 UI service over a read-only BO. It uses analytical projection annotations such as aggregation support/default aggregation. Confirm the current extensibility restriction before selecting this path.

Source: [Developing Read-Only RAP Analytical Tables](https://help.sap.com/docs/abap-cloud/abap-rap/developing-read-only-rap-analytical-tables?version=sap_cross_product_abap).

### Custom Entity / Unmanaged Query

Choose a custom entity and `IF_RAP_QUERY_PROVIDER` when the query result is not represented by a normal CDS database view, especially for remote or mixed sources. The query provider must implement filtering, sorting, paging, count and error behavior required by the service contract. A custom query is read-oriented; do not treat it as a shortcut around a transactional BO design.

## Draft Selection

### No Draft

Use non-draft transactional RAP for short, atomic edits where users do not need to save inconsistent intermediate state or resume later. This has the smallest state, authorization, lock and test surface.

### Exclusive Draft

Choose exclusive draft when one user must pause/resume work, preserve incomplete data, recover after client termination, or edit a multi-step Fiori workflow. Draft state is persisted separately after transactions; active/draft transitions require draft tables, total ETag, locking, actions and projection reuse. Draft-enabling an existing BO requires revalidating all business logic for active versus draft instances.

Source: [Developing Transactional Apps with Exclusive Draft Capabilities](https://help.sap.com/docs/abap-cloud/abap-rap/developing-transactional-apps-with-draft-capabilities?version=sap_cross_product_abap).

### Collaborative Draft

Choose collaborative draft only when invited users genuinely co-edit the same draft. It is mutually exclusive with exclusive draft and applies to the entire BO, not selected nodes. Add the Share action, required roles/authorization object checks, projection/interface reuse, and draft read protection.

For DDIC-table collaborative draft scenarios, the root authorization master needs the documented draft query view/DCL setup. OData root fallback does not automatically secure EML reads of subentities; model EML authorization explicitly.

Source: [Developing Transactional Apps with Collaborative Draft Capabilities](https://help.sap.com/docs/abap-cloud/abap-rap/adding-collaboration-capability-to-draft-enabled-managed-business-object?version=sap_cross_product_abap).

### Cross-BO Draft Scope

Use cross-BO draft scope when two independent, already-functional draft BOs must become one editing/activation unit. One BO is principal, one dependent, and a real foreign-key relationship exists. This requires cross associations, reverse association, draft link/unlink/inverse operations, `use draft as dependent`, matching projection association declarations, and joint service exposure.

Prefer one composition BO when one aggregate truly owns the lifecycle; cross-BO scope is for independently owned BOs that must temporarily share a draft LUW.

Source: [Developing Cross-BO Scenarios with Draft Scope](https://help.sap.com/docs/abap-cloud/abap-rap/developing-transactional-apps-with-draft-enabled-cross-bo-capabilities?version=sap_cross_product_abap).

## Specialized UI Shapes

### Hierarchical Data

Choose CDS hierarchy/treeview modeling when parent-child hierarchy is the actual domain shape. Use a read-only treeview for navigation/inspection. Editable treeviews require the documented managed-draft instance-hierarchy contract and must define move/reorder/copy semantics, cycle prevention, authorization and concurrency.

Source: [Developing Apps with Hierarchical Data Structures](https://help.sap.com/docs/abap-cloud/abap-rap/implementing-hierarchical-view?version=sap_cross_product_abap).

### Multi-Inline Edit

Choose multi-inline edit for configuration/master data where users must create/update/delete many rows on one screen. The RAP pattern introduces a singleton technical root and models maintained rows as children so standard child-table editing/locking applies.

This changes the BO structure significantly; the same BO cannot simultaneously serve as a conventional root list report and the multi-inline scenario. Treat it as a deliberate service/BO shape, not a UI annotation toggle.

Source: [Developing Transactional Apps with Multi-Inline-Edit Capabilities](https://help.sap.com/docs/abap-cloud/abap-rap/developing-transactional-apps-with-multi-inline-edit-capabilities?version=sap_cross_product_abap).

## Remote-Service Façade

Choose the remote-service UI scenario when a local service must query a remote OData API and enrich it with local persisted data.

Typical architecture:

1. Import remote metadata through a Service Consumption Model and generated client proxy.
2. Configure communication scenario/system/arrangement and destination.
3. Define a CDS custom entity for the combined result.
4. Implement the unmanaged query with paging/filter/sort/count forwarding and result transformation.
5. Define separate local persistence/transactional behavior for local fields.
6. Expose a UI service.

Do not attempt to make remote data a managed persistent table without an explicit replication/ownership design. Define timeout, retry, partial-result, authorization, destination, observability and remote-version behavior.

Source: [Developing a UI Service with Access to a Remote Service](https://help.sap.com/docs/abap-cloud/abap-rap/developing-ui-service-with-access-to-remote-service?version=sap_cross_product_abap).

## UI Service, Web API, or EML Interface

| Consumer | Choose | Contract implications |
|---|---|---|
| Fiori Elements | OData V4 UI service binding | UI/value-help/search annotations, draft UX, side effects, metadata/runtime tests |
| Unspecified external clients | Web API binding | No UI metadata contract; C2/API lifecycle, authentication, compatibility, pagination, batch and error contract |
| Internal ABAP consumers | RAP BO interface + EML | C1 system-internal API, explicit behavior reuse, derived types and transaction semantics |

A UI and Web API can reuse the same base BO but should use projections/bindings appropriate to each consumer. Do not publish UI-specific projection churn as a stable remote API contract.

Source: [Develop Web APIs](https://help.sap.com/docs/abap-cloud/abap-rap/develop-web-apis?version=sap_cross_product_abap).

## RAP Recommendations

Choose recommendations when a Fiori input field with value help needs context-aware proposals, potentially backed by generative AI or another recommendation source. The model requires recommendation-enabled fields, a recommendation function, side effects and a UI consumer. It does not replace validation, deterministic defaulting, authorization, or value-help correctness.

Source: [Adding RAP Recommendations](https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/9d9cc97cab9d48fdaa35d5c333526ba0).

## Artifact Plan by Scenario

| Concern | Read-only | Managed transactional | Unmanaged transactional | Remote façade |
|---|---|---|---|---|
| Persistence/data source | Existing table/CDS | RAP-owned tables | Existing persistence/API | Remote API plus optional local table |
| CDS root/interface | Query/root as needed | Root/composition view entities | Root/composition views over legacy model | Custom entity, optional local entities |
| Base BDEF | None/read-only contract | Managed | Unmanaged | Query provider; local managed/unmanaged behavior separately |
| Behavior pool | Query/custom logic only | Custom behavior only | Full standard/custom provider | Query implementation plus local behavior |
| Projection | Consumer-specific | Consumer-specific | Consumer-specific | Combined service projection |
| Service | UI or API | UI/API | UI/API | Usually UI façade; API only with explicit remote contract |
| Transaction tests | Query semantics | RAP buffer/save/draft | Legacy adapter/buffer/save | Remote failure plus local transaction consistency |

## Required Development Sequence

1. Confirm release, landscape, source/API release state and business ownership.
2. Choose scenario using this guide and record rejected alternatives.
3. Model CDS ownership, keys, compositions/associations, cardinalities and authorization entry points.
4. Select BDEF kind/save strategy/draft model only after the ownership decision.
5. Define behavior contract, then generated implementation methods.
6. Build projection appropriate to each UI/API/EML consumer.
7. Define service and binding type; do not let the binding decide the BO architecture retroactively.
8. Implement security, transaction boundaries, messages, locks, ETags and observability.
9. Test BO behavior with EML before relying on UI preview.
10. Test generated metadata/runtime, volume, failures, authorization and rollback for the selected scenario.

## Selection Anti-Patterns

- Choosing unmanaged because custom actions exist. Managed BOs support custom actions, validations and determinations.
- Choosing managed over legacy persistence while bypassing the existing transaction API with direct SQL.
- Adding draft because the UI has an Edit button, without a resume/inconsistent-state requirement.
- Using collaborative draft for ordinary parallel reads or independent edits.
- Combining independent BOs into one composition solely to obtain one draft screen.
- Treating custom entities as transactional persistence entities.
- Exposing a remote service through synchronous row-by-row calls from a query provider.
- Using multi-inline edit as a cosmetic option without accepting the singleton-root BO shape.
- Reusing one projection as both mutable UI metadata and a stable remote API contract.
- Selecting implementation type before establishing transaction ownership and failure/rollback behavior.

## Required Decision Output

For a non-trivial RAP request, state:

- selected SAP scenario and source link,
- landscape/release,
- read-only versus transactional,
- managed/unmanaged/hybrid-save rationale,
- persistence/query and transaction owner,
- draft mode and justification,
- BO/CDS/BDEF/projection/service artifacts,
- UI/Web API/EML consumer contract,
- authorization/concurrency/transaction design,
- volume and remote-dependency constraints,
- rejected alternatives,
- focused validation and operational evidence.

If those fields cannot be completed, the implementation choice is not ready for code generation.
