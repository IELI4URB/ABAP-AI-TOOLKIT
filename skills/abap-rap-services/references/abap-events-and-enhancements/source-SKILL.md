---
name: abap-events-and-enhancements
description: 'Design and review SAP ABAP Cloud events and enhancement mechanisms. Use for RAP business events, RAISE ENTITY EVENT, local event handlers, Event Mesh bindings, derived or cross-BO events, Cloud BAdIs, GET BADI or CALL BADI, BDEF extensions, CDS extensions, and reactions after create or save.'
metadata:
  version: 2.0.0
  tags: abap rap-events badi enhancement event-mesh bdef-extension clean-core abap-cloud
---

# ABAP Cloud Events and Enhancements

SAP Help baseline: https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model

Use this skill as the extensibility-mechanism router. Load only the relevant part of [the complete events and BAdI reference](./references/events-and-badi-patterns.md).

## Ownership

This skill owns the choice and lifecycle of RAP events, event consumers, Cloud BAdIs, BDEF extensions, and CDS extensions. Use `abap-integration-patterns` for Event Mesh connectivity, `abap-rap-behavior-implementation` for handler-method mechanics, and `abap-clean-core-principles` for Tier and release governance.

## Workflow

1. Establish landscape, exact release/FPS, provider ownership, timing requirement, coupling, delivery guarantee, and transaction semantics.
2. Decide whether the need is an after-the-fact reaction, synchronous influence, behavioral extension, structural extension, or annotation extension.
3. Verify provider release contract, extensibility, event/BAdI contract, payload types, keys, and execution phase.
4. Read only the matching reference sections below.
5. Define idempotency, ordering, retries, duplicate delivery, failure isolation, and observability.
6. Validate supported phases, save behavior, authorization, payload compatibility, consumer failure, and upgrade behavior.

## Reference Routing

| Request | Read sections in `events-and-badi-patterns.md` |
|---|---|
| Mechanism selection | 1, 13 |
| RAP event producer | 2 |
| Local event consumer | 3 |
| Remote Event Mesh consumer | 4 |
| Derived events | 5 |
| Cross-BO events | 6, plus `abap-platform-2025` |
| Cloud BAdI | 7 |
| BDEF extension | 8 |
| CDS or metadata extension | 9 |
| Availability and review | 10, 12 |
| End-to-end example | 11 |

## Mandatory Gates

- Never modify SAP standard code or extend a provider without verified release and extensibility contracts.
- Use events for decoupled reactions and BAdIs for synchronous influence; state transaction and delivery semantics explicitly.
- Verify payload keys, types, versioning, optionality, handler signatures, and provider/consumer compatibility.
- Treat event consumers as duplicate-tolerant and observable; define poison-message and replay handling for remote delivery.
- Verify BDEF, EML, event, and BAdI syntax for the exact release; report `Syntax confidence: verified` or block production use.
- Release guidance must include ATC/readiness, producer/consumer tests, rollback or disablement, monitoring, and operational ownership.

## Response Shape

For non-trivial requests, state timing and coupling needs, selected mechanism, provider contracts, transaction and failure model, artifacts, tests, and released-object evidence.
