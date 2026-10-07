---
name: abap-iam-authorization
description: 'Design and review IAM and authorization for SAP ABAP Cloud. Use for AUTHORITY-CHECK, RAP global or instance authorization, DCL access control, field-level authorization, restriction types, IAM apps, business catalogs, business roles, and authorization failures.'
metadata:
  version: 2.0.0
  tags: abap iam authorization dcl business-role access-control abap-cloud security
---

# ABAP IAM and Authorization

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

Use this skill as the authorization router. Keep the entry point small and load only the relevant part of [the complete IAM reference](./references/iam-complete.md).

## Ownership

This skill owns authorization objects, RAP authorization, CDS DCL, IAM artifacts, restriction types, and their end-to-end mapping. Use `abap-security-hardening` for broader input validation, secrets, audit, and data-protection concerns.

## Workflow

1. Establish the target landscape and release: Public Cloud, Private Cloud with ABAP Cloud, or BTP ABAP Environment.
2. Classify the request by layer: data visibility, operation permission, instance permission, field control, or role provisioning.
3. Inspect the relevant object contracts and released/extensible status before proposing code.
4. Read only the matching reference sections below; do not load the whole reference unless the request spans the full authorization stack.
5. Design defense in depth: CDS access control plus RAP operation authorization where both apply. UI controls are not authorization.
6. Define negative tests and verify behavior through direct OData or EML access, not only through Fiori Elements.

## Reference Routing

| Request | Read these sections in `iam-complete.md` |
|---|---|
| Authorization architecture | 1, 8 |
| Authorization object or `AUTHORITY-CHECK` | 2, 3 |
| RAP global authorization | 4 |
| RAP instance authorization | 5 |
| Field-level control | 6 |
| CDS DCL or PFCG aspects | 7 |
| IAM app, catalog, role, restriction type | 8 |
| Review or troubleshooting | 9, 10 |

## Mandatory Gates

- Verify every SAP artifact and API is released for the target landscape; do not infer release state from examples.
- Align caller/callee signatures, authorization fields, values, activities, entity keys, and DCL element types.
- Never use UI visibility, feature control, or service exposure as the sole security boundary.
- Treat missing or failed checks as deny by default and avoid leaking protected data through messages or logs.
- For syntax-bearing output, verify ABAP, CDS DCL, BDEF, and EML syntax in current SAP Help and report `Syntax confidence: verified`; otherwise mark unresolved syntax as draft and block production use.
- Include authorization, input-validation, ATC, test, rollback, and operational evidence in release guidance.

## Response Shape

For non-trivial requests, state landscape assumptions, authorization layers, required objects and contracts, implementation sequence, negative tests, released-object evidence, and residual risks.
