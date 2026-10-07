---
name: abap-error-handling-resilience
description: 'Design and review error handling, resilience, and observability for SAP ABAP Cloud. Use for exception hierarchies, TRY CATCH, CX_STATIC_CHECK, CX_DYNAMIC_CHECK, CX_NO_CHECK, retry, exponential backoff, circuit breakers, CL_BALI_LOG, RAP FAILED or REPORTED messages, recovery, and application logging.'
metadata:
  version: 2.0.0
  tags: abap exceptions resilience retry circuit-breaker logging rap-messages abap-cloud
---

# ABAP Cloud Error Handling and Resilience

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

Use this skill as the failure-semantics and observability router. Load only the relevant part of [the complete error-pattern reference](./references/error-patterns.md).

## Ownership

This skill owns exception design, propagation, retries, circuit breakers, Application Log patterns, RAP messages, and recovery policy. Domain skills still own protocol-specific or business-specific error contracts.

## Workflow

1. Classify each failure as validation, business conflict, transient dependency, permanent dependency, authorization, concurrency, or programming defect.
2. Inspect caller/callee exception contracts, RAP response structures, retry safety, transaction boundaries, and released API status.
3. Choose propagation, translation, retry, compensation, or fail-fast behavior explicitly.
4. Read only the matching reference sections below.
5. Define correlation, log severity, sensitive-data handling, operator action, and recovery ownership.
6. Validate root-cause preservation, maximum retries, duplicate effects, partial results, broad catches, and failure observability.

## Reference Routing

| Request | Read sections in `error-patterns.md` |
|---|---|
| Exception type selection | 1 |
| Domain exception design | 2 |
| Propagation and chaining | 3 |
| `CL_BALI_LOG` | 4 |
| Retry/backoff | 5 |
| Circuit breaker | 6 |
| RAP messages | 7 |
| Fail-fast or partial results | 8 |
| Review | 9 |

## Mandatory Gates

- Preserve the original cause and business context; never silently swallow exceptions.
- Retry only transient, idempotent operations with bounded attempts and explicit timeout budgets.
- Keep circuit-breaker state and concurrency semantics appropriate to the runtime; do not present an in-memory sketch as production architecture.
- Log actionable context without credentials, tokens, or protected business data.
- Verify exception, RAP message, and logging APIs for the target release; report `Syntax confidence: verified` or block production use.
- Release guidance must include negative tests, ATC/readiness, failure injection, rollback/recovery, alerts, and runbook evidence.

## Response Shape

For non-trivial requests, state failure taxonomy, exception/message contracts, resilience decisions, transaction impact, logging and recovery, tests, and residual operational risks.
