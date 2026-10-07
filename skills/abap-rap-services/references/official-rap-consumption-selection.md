# Official RAP Consumption Selection Guide

This guide turns SAP's [Consuming RAP Business Objects and Events](https://help.sap.com/docs/abap-cloud/abap-rap/consume?version=sap_cross_product_abap) documentation into a consumption-channel decision workflow.

Use it after a RAP provider or released API has been selected. It chooses among RAP BO interfaces, EML, CDS projections, OData UI/Web API consumption, local/remote OData client proxies, and local/remote business events.

## Consumption Channels

| Need | Select | Required release contract |
|---|---|---|
| ABAP code invokes a RAP BO in the same ABAP system | Released RAP BO interface + EML | C1 for stable system-internal use |
| Build a new RAP projection/service over an existing stable BO | CDS transactional projection + projection BDEF over RAP BO interface | C1 source interface; C2 for resulting external service |
| Fiori Elements consumes a RAP UI service | OData V4 UI service | C2 |
| Same-server ABAP integration test invokes the OData contract | Local OData client proxy | C2 service |
| ABAP consumes a RAP OData API on another server | Service Consumption Model + remote OData client proxy | C2 service |
| Same-system ABAP reacts asynchronously to a RAP event | Local RAP event handler class | Event exposed through C1 RAP BO interface |
| Another system consumes RAP events asynchronously | Event Mesh + event consumption model/subscription | C2 released event version |

Do not consume an implementation object merely because it is technically visible. Select an API with the release contract matching the consumption boundary.

## Fast Decision Flow

1. **Do you need synchronous BO operations inside ABAP?**
   - Same ABAP system and BO semantics are desired: consume the C1 RAP BO interface using EML.
   - You need a service-specific projection over that BO: build a CDS transactional query plus projection BDEF over the C1 interface.
   - Different system/server: consume the C2 OData service with a remote client proxy, not EML.
2. **Do you need a user interface?**
   - Fiori Elements generated from RAP metadata: consume the C2 OData V4 UI service.
   - Custom UI/client: consume the appropriate C2 OData UI or Web API contract according to the provider's intended binding.
3. **Do you need asynchronous reaction?**
   - Same ABAP system: local event consumption through a C1 BO interface event.
   - Cross-system/event-driven integration: C2 event version through Event Mesh/event consumption model.
4. **Are you testing an OData contract on the same server?**
   - Use the local OData client proxy so the test exercises service metadata/protocol behavior and can use test doubles.
   - Use direct EML instead when the test intentionally targets only the BO contract, not OData.

## Business Object Interface Consumption

A RAP BO interface is the stable system-internal contract over an underlying base BO. It can be consumed in two ways.

### ABAP Consumption with EML

Choose EML when ABAP code needs type-safe transactional access to the BO contract:

- read entities and associations,
- create/update/delete,
- execute actions/functions,
- retrieve permissions,
- commit/rollback the RAP transaction when the caller owns it.

Address the RAP BO interface, not the base implementation BDEF. Derived request/result/response types then reflect the released interface contract.

Use cases include application services, BAdI implementations, jobs, integrations within the same system, and behavior implementations calling another released BO.

Consumer gates:

- Handle `MAPPED`, `FAILED`, and `REPORTED` as allowed by the operation.
- Respect static/dynamic features and authorization; permission lookup is not enforcement.
- Bundle mass operations rather than issuing EML in loops.
- Own `COMMIT ENTITIES` only in top-level custom ABAP consumers; never commit inside a behavior implementation.
- Do not rely on base-BO fields/operations that the interface does not expose.

Source: [Business Object Consumption](https://help.sap.com/docs/abap-cloud/abap-rap/business-object-interface-consumption?version=sap_cross_product_abap), [ABAP for RAP Business Objects](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-for-rap-business-objects?locale=en-US).

### CDS Consumption and Re-Exposure

Choose CDS consumption when building a consumer-owned service/projection over a C1 RAP BO interface.

Required artifacts:

1. CDS projection view with provider contract `transactional_query` over the transactional interface.
2. Projection BDEF that explicitly reuses selected operations, ETag, draft, keys, actions/functions and side effects.
3. Consumer-owned metadata extensions/annotations as needed.
4. Service definition and UI/Web API service binding.
5. DCL/access-control design for the consuming projection where required.

The generated ADT wizard can create UI projection/service artifacts, but generated authorization artifacts still require review and DCL may need manual creation.

Value helps marked `@Consumption.valueHelpDefinition.useAsTemplate` on the released interface are templates, not automatically exposed metadata. Copy the desired definition into the consuming projection and remove `useAsTemplate` there, or use the wizard behavior that applies the suggestions.

Do not assume behavior is inherited automatically: projection/interface BDEF operations and characteristics generally require explicit `use` declarations.

Source: [Business Object Consumption](https://help.sap.com/docs/abap-cloud/abap-rap/business-object-interface-consumption?version=sap_cross_product_abap).

## OData Service Consumption

RAP BOs can be exposed and consumed through C2-released OData services locally or remotely.

### Fiori Elements / UI Consumption

Choose the OData V4 UI service when the client should interpret backend UI, value-help, search, side-effect and draft metadata.

- The Fiori Elements preview in the service binding is useful for backend validation.
- Preview is not a substitute for a deployable SAP Business Application Studio application and browser/device/end-to-end testing.
- Validate generated `$metadata`, annotations, value helps, ETags, draft actions, side effects and authorization behavior.
- Treat UI annotations as a client contract only where the service/version supports them.

### Local OData Client Proxy

Choose the local OData client proxy for programmatic same-application-server consumption, especially OData integration tests.

- It tests the service/protocol contract rather than bypassing directly to EML.
- Processing occurs in the same ABAP session, enabling test doubles and controlled integration tests.
- Use direct EML for BO-level unit/integration tests where OData translation is not under test.

### Remote OData Client Proxy

Choose a remote OData client proxy when the service is hosted on another application server/system.

Typical setup:

1. Use a C2-released OData service.
2. Generate/import a Service Consumption Model from service metadata where appropriate.
3. Configure communication scenario, system, arrangement, authentication and destination.
4. Use the remote OData client proxy.
5. Implement paging, filtering, batch, ETag, timeout, retry, error and version handling.

Do not replace remote API consumption with direct table/CDS access or RFC unless that alternative is itself the released integration contract.

Source: [OData Service Consumption](https://help.sap.com/docs/abap-cloud/abap-rap/odata-service-consumption?version=sap_cross_product_abap).

## UI Service Versus Web API Consumption

| Concern | UI service | Web API service |
|---|---|---|
| Primary consumer | Fiori Elements/UI client | Unspecified application/system client |
| Metadata | Includes UI-oriented metadata as designed | Reduced to API-relevant metadata; UI annotations/value helps are not the remote API contract |
| Stability | C2 service contract | C2 service contract, normally stricter lifecycle/version governance |
| Client design | Draft/side-effect/value-help/UI semantics | Protocol, schema, paging, batch, concurrency and error semantics |
| Testing | Metadata + UI runtime + browser/device | Contract tests + client proxy + negative/protocol tests |

A single base BO can support both, but use projections/bindings appropriate to each consumer. Do not couple a stable Web API client to UI-specific annotations or mutable presentation projections.

## Business Event Consumption

RAP business events can be consumed locally or remotely.

### Local Event Consumption

Choose local consumption when provider and consumer run in the same ABAP system but asynchronous decoupling is still desired.

Prerequisites and artifacts:

- Event exposed in a C1-released RAP BO interface.
- Global class declared `FOR EVENTS OF` the interface/root.
- Local handler class inheriting from `CL_ABAP_BEHAVIOR_EVENT_HANDLER`.
- One `METHODS ... FOR ENTITY EVENT` handler per event within a handler class.
- No service binding or Event Mesh communication is required.

An event can have one handler method per handler class, while multiple handler classes may react. Design handlers as idempotent because delivery/retry can repeat work.

Temporary local handling failures can request framework retry using a custom exception derived from `CX_RAP_EVENT_HDLR_ERROR_RETRY`, including a delay. The framework can retry local execution up to the documented limit (currently three attempts in the referenced guide). Do not use retry for permanent validation or authorization failures.

### Remote Event Consumption

Choose remote consumption for cross-system asynchronous integration.

Prerequisites and artifacts:

- Event exposed as a C2-released event version.
- Event Mesh and inbound/outbound communication arrangement configured.
- Queue/subscription and event consumption model created.
- Consumer implements idempotence, duplicate handling, ordering assumptions, dead-letter/retry, schema versioning, correlation, security and monitoring.

Managed-event payload views are read by the framework with privileged access by default. Review payload minimization and sensitive-data exposure explicitly; DCL should not be assumed to filter the emitted payload.

Source: [Business Event Consumption](https://help.sap.com/docs/abap-cloud/abap-rap/business-event-consumption?version=sap_cross_product_abap).

## Release Contract Decision

| Contract | Consumption meaning |
|---|---|
| C0 | Released extension point; not the general contract for consuming a BO as an API |
| C1 | Stable system-internal use, including RAP BO interfaces and local event exposure |
| C2 | Stable remote API/service/event consumption boundary |

Cloud Development visibility is separate from the release contract. Verify both target-language availability and the required contract.

For CDS consumption over a C1 interface followed by OData exposure, the source interface uses C1 while the resulting remote service needs its own C2 lifecycle contract.

## Lifecycle-Stable Consumer Rules

Released RAP APIs guarantee compatible evolution within their release contract, not one exact implementation response forever.

Consumers must:

- Handle every failure cause/status allowed by the RAP/OData/event contract.
- Treat messages as diagnostics for people, not stable machine decision keys.
- Never branch business logic on concrete T100 message class/number/text unless that message identity is explicitly a released contract.
- Expect contract-valid differences in message text, ordering, optional fields and response details.
- Use typed failure causes, HTTP status/category, operation result, and released fields for decisions.
- Preserve unknown-but-valid response information for logging/support.
- Test compatible provider evolution, new optional fields, multiple messages and alternate valid failure causes.
- Monitor deprecation and version changes; do not silently switch service/event versions.

Example: an update may be rejected as disabled (mapped to a contract-appropriate HTTP status such as 422) or fail with an unspecified/business error (for example 400), with varying T100 messages. The consumer must handle the defined categories instead of recognizing one current message.

Source: [Consuming RAP Business Objects and Events](https://help.sap.com/docs/abap-cloud/abap-rap/consume?version=sap_cross_product_abap).

## Security Boundaries

- EML against a C1 interface still enforces the BO's authorization/features unless explicitly using trusted local/privileged provider context.
- CDS DCL read protection applies at the actual CDS read entry point; validate the consuming projection and draft-query access model.
- C2 OData requires communication arrangements/authentication and service authorization appropriate to the landscape.
- Event payload authorization differs from request-time BO authorization; minimize payload and validate consumer entitlement.
- `GET PERMISSIONS` and UI enablement are hints, not substitutes for runtime enforcement.
- Never expose credentials/tokens in RAP messages, event payloads or logs.

## Error and Transaction Ownership

| Channel | Transaction owner | Consumer recovery |
|---|---|---|
| EML in top-level ABAP | Calling program | Inspect responses, commit/rollback explicitly |
| EML inside behavior implementation | RAP runtime/provider | Never commit/rollback; return legal responses |
| OData UI/Web API | RAP transactional engine per request/change set | Handle HTTP/OData error and retry only safe/idempotent operations |
| Local event | Event framework | Idempotent handler; retry exception only for transient failure |
| Remote event | Messaging infrastructure + consumer | Ack/retry/dead-letter according to broker/consumer contract |

Do not span one atomic transaction across a remote OData call or asynchronous event. Use compensation/idempotence and explicit process state for cross-system workflows.

## Consumption Anti-Patterns

- EML against an unreleased base BDEF instead of a C1 BO interface.
- Wrapping C1 internal behavior into a C2 service without defining the remote compatibility contract.
- Calling a same-system OData service from ABAP when direct EML is the intended BO contract, except when testing the OData boundary.
- Using EML for cross-system access.
- Parsing T100 text or message numbers to determine program flow.
- Treating Fiori preview as the only UI test.
- Using local events when the consumer must be independently deployed across systems.
- Using remote events for synchronous request/response requirements.
- Assuming Event Mesh gives exactly-once processing.
- Assuming DCL automatically filters managed-event payloads read with privileged access.
- Using permission results instead of enforcing authorization in the provider.

## Required Consumption Output

For a non-trivial RAP consumption design, state:

- selected channel and SAP scenario,
- provider and consumer landscapes/releases,
- C1/C2 release contract and exact API/service/event version,
- synchronous versus asynchronous requirement,
- EML/CDS/OData/event artifacts,
- transaction, retry and idempotence ownership,
- authorization and sensitive-data boundary,
- failure categories and lifecycle-stable error handling,
- volume/paging/batch/ordering constraints,
- observability and support model,
- rejected consumption alternatives,
- focused contract and negative tests.

If the release contract, transaction owner, or failure model is unknown, the consumption design is not ready for implementation.
