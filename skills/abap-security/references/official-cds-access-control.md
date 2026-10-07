# Official CDS Access-Control Semantics

Use this guide when designing or diagnosing CDS DCL and its interaction with classic/RAP authorization.

## Evaluation Boundary

CDS access control restricts data returned when an entry-level CDS entity is read by ABAP SQL. It does **not** automatically propagate through a CDS entity that wraps or selects from the protected entity. Define/review access control for every entry point exposed to consumers.

Consequences:

- DCL on an interface/base entity does not by itself prove a projection or wrapper is protected.
- Direct reads of different layers can produce different authorization behavior.
- Authorization tests must exercise the actual exposed entity.

Source: [ABAP CDS Access Control](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-access-control?locale=en-US).

## Authorization-Check Annotation

| Value | Runtime meaning |
|---|---|
| `#NOT_REQUIRED` | Default. If no access control exists, full access; if one exists, it is evaluated. |
| `#CHECK` | Same runtime behavior as `#NOT_REQUIRED`, but syntax warning when no access-control object exists. |
| `#MANDATORY` | Access control must exist; absence causes a runtime error on ABAP SQL access. |
| `#NOT_ALLOWED` | Existing access control is ignored at runtime; intended for technical entities where DCL is harmful. |
| `#PRIVILEGED_ONLY` | Framework-oriented value. In ordinary ABAP SQL, behavior is effectively like `#CHECK`; do not use unless the framework documentation requires it. |

Do not claim `#CHECK` denies access when DCL is missing. Use `#MANDATORY` where accidental loss of the DCL must fail visibly, after verifying target support and operational consequences.

## Privileged Access

Privileged access deliberately bypasses DCL and must be narrowly justified, reviewed, and tested.

- `WITH PRIVILEGED ACCESS` can disable access control for a particular entity usage.
- Statement-level `PRIVILEGED ACCESS` can also affect association traversal covered by the statement.
- A wrapper entity with access control disabled is another bypass surface.

Record why the bypass is necessary, which authorization replaces it, and which data can be exposed.

## Defense in Depth

- Keep classic start authorization where an application/service launch must be controlled.
- Use DCL for row/data-model restrictions.
- Use RAP global/instance authorization for operation-level and instance-state permissions.
- Use feature control for UX/operation availability, not as the sole security boundary.
- An empty result cannot tell an ABAP consumer whether data was absent or filtered by DCL.
- Account for DCL performance cost: complexity, protected-view shape, role values, and statement position affect database work.

## Test Matrix

Test with non-developer identities:

1. permitted rows and operations
2. forbidden rows and operations
3. missing/blank versus unrestricted role values
4. direct access to interface, projection, service, and association paths
5. privileged code paths
6. missing DCL under each annotation mode
7. performance with realistic PFCG-role value volume

Source: [ABAP CDS Access Control](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-access-control?locale=en-US).
