---
name: abap-sql-and-amdp
description: 'Write, review, and optimize ABAP SQL and AMDP for ABAP Cloud. Use for SELECT, joins, subqueries, aggregation, DML, host variables, window functions, FOR ALL ENTRIES, dynamic SQL, CTEs, AMDP, CDS table functions, SQLScript, and database-side calculations.'
metadata:
  version: 2.0.0
  tags: abap sql amdp select window-functions table-function dynamic-sql abap-cloud
---

# ABAP SQL and AMDP

SAP Help baseline: https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm

Use this skill as the SQL syntax and database-computation router. Load only the relevant part of [the complete SQL and AMDP reference](./abap-sql-and-amdp/references/sql-complete-reference.md).

## Ownership

This skill owns ABAP SQL statements, DML, AMDP, table-function implementation, and SQL-specific safety. Use `abap-cds-data-modeling` for CDS entity architecture, `abap-performance-optimization` for broader performance diagnosis, and `abap-security-hardening` for security review beyond dynamic SQL.

## Workflow

1. Establish landscape, release, database, data volume, consistency needs, and the exact input/output contract.
2. Inspect source and target types, keys, nullability, units/currencies, client handling, and released-object status.
3. Prefer static ABAP SQL and database pushdown; justify AMDP or dynamic SQL explicitly.
4. Read only the matching reference sections below.
5. Check deterministic ordering, pagination, empty inputs, duplicates, authorization filtering, and error paths.
6. Validate with realistic volume and an execution-plan or trace when performance is material.

## Reference Routing

| Request | Read sections in `sql-complete-reference.md` |
|---|---|
| Cloud SQL constraints | 1 |
| `SELECT`, joins, subqueries, ordering | 2 |
| `INSERT`, `UPDATE`, `DELETE`, `MODIFY` | 3 |
| Window functions | 4 |
| `FOR ALL ENTRIES` | 5 |
| Dynamic SQL | 6 |
| AMDP | 7 |
| CDS table functions | 8 |
| Aggregation, CTEs, performance | 9, 10 |

## Mandatory Gates

- Use host variables and field projection; do not recommend `SELECT *` for production paths without justification.
- Guard empty `FOR ALL ENTRIES` inputs and require deterministic `ORDER BY` for pagination.
- Validate dynamic tokens with released APIs and never concatenate untrusted SQL fragments.
- Check N+1 access, pushdown, pagination, memory, locking, and large-volume behavior.
- Verify ABAP SQL, CDS, AMDP, and SQLScript syntax for the target release; report `Syntax confidence: verified` or block production use.
- Release guidance must include tests, ATC/readiness, performance evidence, rollback, and operational monitoring.

## Response Shape

For non-trivial requests, state data contracts and assumptions, chosen execution layer, query or procedure outline, correctness and security checks, performance validation, and release evidence.

