---
name: abap-security
description: 'Design and review ABAP Cloud security and IAM. Use for AUTHORITY-CHECK, RAP global/instance/field authorization, CDS DCL, IAM apps, catalogs, roles, restriction types, input validation, SQL injection, secrets, communication arrangements (never hardcode credentials), sensitive data, audit, hashing, OAuth 2.0/JWT token security rules, PKCE, and security failures. OAuth 2.0 and JWT patterns are available in Communication Arrangements from S/4HANA 2025.'
metadata:
  version: 2.0.0
  tags: abap security iam authorization dcl oauth jwt pkce input-validation sql-injection secrets abap-cloud
---

# ABAP Security and IAM

Load one guide for the active security boundary.

- [IAM and authorization architecture](./references/abap-iam-authorization.md)
- [Security hardening](./references/abap-security-hardening.md)
- [Official CDS access-control semantics](./references/official-cds-access-control.md)

## Workflow

1. Identify identities, trust boundaries, protected operations/data, inputs, and secrets.
2. Use the IAM guide for role/DCL/RAP authorization; use hardening for validation, injection, secrets, and data protection.
3. For credential/token handling: never store OAuth tokens in Z-tables, never log `Authorization: Bearer` headers, never pass tokens in URL parameters, always use short token lifetimes.
4. Verify negative authorization and malformed-input paths directly, not only through UI behavior.
5. Require deny-by-default behavior, released APIs, safe logs, tests, and audit evidence.

## OAuth Token Security Rules (S/4HANA 2025+)

| Rule | Rationale |
|---|---|
| Never store tokens in Z-tables | Bypasses token rotation — treat tokens as credentials |
| Never log `Authorization: Bearer` header | Token in logs = plaintext credential |
| Never pass tokens in URL parameters | URLs appear in server/proxy/browser logs |
| Never disable TLS certificate validation | Makes OAuth useless against MITM |
| Always enable PKCE for Authorization Code flows | Prevents auth code interception |
