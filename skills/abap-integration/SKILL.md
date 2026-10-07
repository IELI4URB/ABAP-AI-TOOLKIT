---
name: abap-integration
description: 'Design and operate ABAP Cloud integrations and resilience. Use for HTTP/REST, SOAP, RFC wrappers, communication scenarios/arrangements, OAuth/JWT, inbound services, Event Mesh, AIF, remote API failures, exception design, retries, backoff, circuit breakers, CL_BALI_LOG, RAP messages, and observability.'
---

# ABAP Integration and Resilience

- [Integration patterns](./references/abap-integration-patterns.md)
- [Engineering: exception and program-flow mechanics](../abap-engineering/references/official-program-flow-logic.md)
- [Error handling and resilience](./references/abap-error-handling-resilience.md)

## Workflow

1. Establish direction, protocol, contract, authentication, delivery guarantee, volume, and timeout budget.
2. Load integration patterns for connectivity; load resilience only when failure behavior is in scope.
3. Verify payload types, status/error mapping, idempotency, retry safety, credentials, and monitoring.
4. Test success, malformed payload, authorization failure, timeout, duplicate delivery, and downstream outage.
