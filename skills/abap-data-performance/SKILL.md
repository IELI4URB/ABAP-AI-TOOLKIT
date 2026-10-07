---
name: abap-data-performance
description: 'Write and optimize ABAP data access and calculations. Use for ABAP SQL, SELECT, joins, subqueries, DML, FOR ALL ENTRIES, dynamic SQL, CTEs, AMDP, CDS table functions, SQLScript, HANA/traditional database tuning, N+1, pushdown, pagination, internal-table keys, caching, indexes, memory, traces, BOM/pegging traversal, BFS, DFS, and cycle detection.'
---

# ABAP Data and Performance

| Concern | Guide |
|---|---|
| ABAP assignments, internal-table semantics, strings, dates, meshes, RTTS, streams | [Engineering: internal data processing](../abap-engineering/references/official-internal-data-processing.md) |
| Official DDIC/CDS persistence, activation, and data-access gates | [DDIC/CDS data access](./references/official-ddic-cds-data-access.md) |
| ABAP SQL, DML, AMDP, table functions | [SQL and AMDP](./references/abap-sql-and-amdp.md) |
| Cloud query/runtime optimization and graph traversal | [Performance optimization](./references/abap-performance-optimization.md) |
| ECC/traditional DB versus HANA tuning | [Database performance](./references/abap-performance-db.md) |

## Workflow

1. Establish release, database, data contract, volume, access pattern, and measured hotspot.
2. Load one primary guide and verify types, keys, ordering, authorization filters, and transaction semantics.
3. Prefer bounded set operations, minimal projection, deterministic paging, and measured pushdown.
4. Validate with realistic volume, traces/plans, boundary inputs, and memory/locking checks.
