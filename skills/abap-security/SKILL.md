---
name: abap-security
description: 'Design and review ABAP Cloud security and IAM. Use for AUTHORITY-CHECK, RAP global/instance/field authorization, CDS DCL, IAM apps, catalogs, roles, restriction types, input validation, SQL injection, secrets, communication arrangements, sensitive data, audit, hashing, and security failures.'
---

# ABAP Security and IAM

Load one guide for the active security boundary.

- [IAM and authorization architecture](./references/abap-iam-authorization.md)
- [Security hardening](./references/abap-security-hardening.md)
- [Official CDS access-control semantics](./references/official-cds-access-control.md)

## Workflow

1. Identify identities, trust boundaries, protected operations/data, inputs, and secrets.
2. Use the IAM guide for role/DCL/RAP authorization; use hardening for validation, injection, secrets, and data protection.
3. Verify negative authorization and malformed-input paths directly, not only through UI behavior.
4. Require deny-by-default behavior, released APIs, safe logs, tests, and audit evidence.
