---
name: abap-integration
description: 'Design and operate ABAP Cloud integrations and resilience. Use for HTTP/REST, SOAP, RFC wrappers, communication scenarios/arrangements, OAuth 2.0 (Client Credentials, Authorization Code + PKCE, JWT Bearer), inbound services, Event Mesh, AIF, remote API failures, exception design, retries, backoff, circuit breakers, CL_BALI_LOG, RAP messages, and observability. OAuth 2.0 and JWT patterns are available in Communication Arrangements from S/4HANA 2025.'
metadata:
  version: 2.0.0
  tags: abap integration http soap rfc aif event-mesh oauth jwt resilience cl-bali-log abap-cloud
---

# ABAP Integration and Resilience

- [Integration patterns](./references/abap-integration-patterns.md)
- [Engineering: exception and program-flow mechanics](../abap-engineering/references/official-program-flow-logic.md)
- [Error handling and resilience](./references/abap-error-handling-resilience.md)

## Workflow

1. Establish direction, protocol, contract, authentication (Basic vs OAuth 2.0 vs mTLS), delivery guarantee, volume, and timeout budget.
2. For new outbound integrations on S/4HANA 2025+, prefer OAuth 2.0 Client Credentials over Basic Auth; use JWT Bearer for highest-assurance M2M.
3. Load integration patterns for connectivity; load resilience only when failure behavior is in scope.
4. Verify payload types, status/error mapping, idempotency, retry safety, credentials (never hardcoded — Communication Arrangement only), and monitoring.
5. Test success, malformed payload, authorization failure, timeout, duplicate delivery, token expiry, and downstream outage.

## Auth Selection (S/4HANA 2025+)

| Scenario | Auth Type |
|---|---|
| Service-to-service outbound (M2M) | OAuth 2.0 Client Credentials |
| UI-initiated call where user identity flows | OAuth 2.0 Authorization Code + PKCE |
| Highest-assurance M2M, eliminates shared secrets | JWT Bearer |
| Legacy or not-yet-migrated integration | Basic Auth (avoid for new) |
| mTLS / SAP-managed cert lifecycle | Client Certificate (Private Cloud 2025) |
