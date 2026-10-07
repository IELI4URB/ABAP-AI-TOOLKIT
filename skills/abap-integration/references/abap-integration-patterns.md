---
name: abap-integration-patterns
description: 'Design and review SAP ABAP Cloud integrations. Use for outbound HTTP or REST, SOAP proxies, communication scenarios and arrangements, inbound HTTP services, OAuth or JWT, RFC Tier 2 wrappers, Event Mesh connectivity, AIF, remote calls, and external API failures.'
metadata:
  version: 2.0.0
  tags: abap integration http rest soap rfc event-mesh communication-arrangement abap-cloud
---

# ABAP Cloud Integration Patterns

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

Use this skill as the integration router. Load only the required part of [the complete integration reference](./_legacy/abap-integration-patterns/references/integration-complete.md).

## Ownership

This skill owns protocol choice, communication-management artifacts, remote contracts, connectivity, and integration observability. Use `abap-error-handling-resilience` for reusable retry, circuit-breaker, and logging policy; use `abap-events-and-enhancements` for RAP event semantics; use `abap-iam-authorization` for authorization design.

## Workflow

1. Establish landscape, release, direction, protocol, trust boundary, volume, latency, and delivery guarantees.
2. Inspect the provider contract, generated proxy or client signatures, payload schema, authentication, errors, limits, and released API status.
3. Select the pattern and communication artifacts before writing caller code.
4. Read only the matching reference sections below.
5. Define timeout, retry/idempotency, monitoring, credential rotation, and failure recovery.
6. Validate success, protocol errors, malformed payloads, authorization failure, timeout, duplicate delivery, and unavailable downstream behavior.

## Reference Routing

| Request | Read sections in `integration-complete.md` |
|---|---|
| Pattern selection | 1, 2, 10 |
| HTTP or REST | 3, 4, 11 |
| SOAP | 5, 11 |
| RFC Tier 2 wrapper | 6 |
| Inbound HTTP | 7 |
| OAuth or JWT | 8 |
| Event Mesh connectivity | 9 |
| Review or quick lookup | 10, 11, 12 |

## Mandatory Gates

- Never hardcode endpoints or credentials; use target-supported communication management.
- RFC wrappers are Private Cloud Tier 2 options only and require released C1 contracts plus Clean Core governance.
- Verify request/response types, lengths, optionality, status mapping, serialization, and exception contracts.
- Confirm every SAP API/class is released for the exact landscape and release.
- For syntax-bearing output, verify against current SAP Help and report `Syntax confidence: verified`; unresolved syntax blocks production use.
- Release guidance must include security, performance/volume, ATC, contract tests, rollback, credential operations, and monitoring evidence.

## Response Shape

For non-trivial requests, state landscape and contract assumptions, selected pattern, required artifacts, data/error flow, resilience and security controls, validation, and residual risks.

