---
name: abap-performance-optimization
description: 'Optimize SAP ABAP Cloud performance. Use for N+1 queries, CDS/SQL pushdown, field projection, pagination, FILTER keys, caching, indexing, memory, traces, AMDP window functions, and graph traversal such as BOM, pegging, BFS, DFS, and cycle detection.'
---

# ABAP Cloud Performance

This guide is a router. The reference material is split into focused sibling guides covering performance patterns, database optimization, and search and traversal algorithms; open the relevant guide from the reference map.

## Workflow

1. Establish volume, access pattern, SLA, database, and measured hotspot.
2. Eliminate N+1 access and unnecessary fields/rows.
3. Push set operations to SQL/CDS/AMDP where supported.
4. Make ordering, pagination, table keys, cache lifetime, and traversal limits explicit.
5. Validate with realistic data and traces.

## Gates

Performance claims require measurement. Pagination needs deterministic order; `FILTER` needs a suitable key; graph traversal needs cycle/depth protection; CDS DDL window-function claims require release verification.

## Reference map

| Topic | Guide |
|---|---|
| N+1, CDS pushdown, pagination, field projection, caching, query/non-query patterns, testing, checklist | [Performance patterns](./perf-performance-patterns.md) |
| Indexing strategy, query/execution-plan optimization, data lifecycle, archival, partitioning, DB monitoring | [Database optimization](./perf-database-optimization.md) |
| BFS, DFS, topological sort, Dijkstra, graph traversal for pegging, BOM, scheduling | [Search and traversal algorithms](./perf-search-traversal-algorithms.md) |
