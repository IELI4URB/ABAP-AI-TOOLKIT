---
name: abap-security-hardening
description: 'Harden SAP ABAP Cloud solutions. Use for input validation, SQL injection, dynamic SQL, secrets, communication arrangements, authorization, sensitive data, audit, hashing/encoding, HTTP clients, and security review.'
---

# ABAP Cloud Security Hardening

Load detailed controls from [security patterns](./references/security-patterns.md). Prior entry-point guidance is preserved in [the entry-point reference](./references/entrypoint-reference.md).

## Workflow

1. Identify trust boundaries, inputs, identities, sensitive data, destinations, and audit requirements.
2. Validate input before expensive or privileged work.
3. Use parameterized/static SQL; strictly validate any dynamic tokens.
4. Use communication arrangements/destinations for endpoints and credentials.
5. Apply authorization at data and operation boundaries and test negative paths.

## Gates

Never hardcode secrets, trust UI checks, concatenate untrusted SQL, expose protected data in logs/messages, or recommend unreleased security APIs. Use `abap-iam-authorization` for role/DCL/RAP authorization architecture.
