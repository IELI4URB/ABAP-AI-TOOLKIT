---
name: abap-performance-optimization
description: 'Optimize SAP ABAP Cloud performance. Use for N+1 queries, CDS/SQL pushdown, field projection, pagination, FILTER keys, caching, indexing, memory, traces, AMDP window functions, and graph traversal such as BOM, pegging, BFS, DFS, and cycle detection.'
---

# ABAP Cloud Performance

Load only the relevant reference: [performance patterns](./_legacy/abap-performance-optimization/references/performance-patterns.md), [database optimization](./_legacy/abap-performance-optimization/references/database-optimization.md), or [search/traversal algorithms](./_legacy/abap-performance-optimization/references/search-traversal-algorithms.md). Prior entry-point guidance is preserved in [the entry-point reference](./_legacy/abap-performance-optimization/references/entrypoint-reference.md).

## Workflow

1. Establish volume, access pattern, SLA, database, and measured hotspot.
2. Eliminate N+1 access and unnecessary fields/rows.
3. Push set operations to SQL/CDS/AMDP where supported.
4. Make ordering, pagination, table keys, cache lifetime, and traversal limits explicit.
5. Validate with realistic data and traces.

## Gates

Performance claims require measurement. Pagination needs deterministic order; `FILTER` needs a suitable key; graph traversal needs cycle/depth protection; CDS DDL window-function claims require release verification.

