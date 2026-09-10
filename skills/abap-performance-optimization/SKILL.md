---
name: abap-performance-optimization
description: >-
  Performance optimization for SAP ABAP Cloud. Covers N+1 query elimination, CDS pushdown (calculations NOT window functions in CDS DDL), pagination (OFFSET requires ORDER BY), field projection, FILTER# operator (requires sorted/hashed key), caching strategies, AMDP for window functions, database indexing patterns, performance monitoring, and graph/search traversal algorithms for supply chain scenarios. Triggers: performance, slow query, N+1, SELECT in loop, CDS pushdown, pagination, caching, index, FILTER, OFFSET, field projection, batch fetch, memory, response time, BFS, DFS, topological sort, Dijkstra, shortest path, BOM explosion, pegging traversal, where-used, cycle detection.
metadata:
  version: 2.2.0
  tags: abap performance n-plus-one cds-pushdown pagination caching indexing abap-cloud bfs dfs topological-sort dijkstra
---

# Performance Optimization for ABAP Cloud

Expert guide for query performance, data transfer, and response time optimization.

**Golden rule: Push work to DB. Fetch only what you need. Never query in a loop. Window functions are ABAP SQL only (NOT CDS DDL) — use AMDP for CDS-level window logic.**

Reference files:
- `references/performance-patterns.md` — anti-patterns and fixes with code
- `references/database-optimization.md` — indexing, query analysis, data lifecycle
- `references/search-traversal-algorithms.md` — BFS/DFS/topological sort/Dijkstra patterns for BOM, pegging, and scheduling

## Development-Phase Usage Protocol (Mandatory)

Use this skill during coding, not only after implementation:
1. Before coding: identify expected data volume, hotspots, and query surfaces.
2. During coding (each major method/entity): run the micro-checklist below.
3. After each iteration: fix detected performance findings immediately.

Micro-checklist (run repeatedly):
- No SELECT in loop (N+1)
- Pushdown candidates assessed (CDS/SQL/AMDP)
- Minimal field projection (no accidental SELECT *)
- Pagination/limits considered for large result sets
- Internal table/key strategy explicit (hashed/sorted/standard by access pattern)
- Traversal logic validated (BFS/DFS/topological/Dijkstra + cycle/depth controls)

## SAP Help Syntax Grounding (Mandatory)

For ABAP/CDS/BDL/EML syntax, use SAP Help as source of truth.

Rules:
- Do not provide unverified syntax for ABAP statements, CDS DDL, behavior definitions, EML, or RAP annotations/options.
- For non-trivial syntax responses, add a short "Syntax references" section with SAP Help links used.
- If exact syntax is uncertain, explicitly mark it as draft and require SAP Help verification.
- Never invent statement additions, annotation names, or behavior options.

Core SAP Help references:
- https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/cbb86e63a8464e63bbdd43b7bfa5fc4f.html
- https://help.sap.com/docs/ABAP_Cloud/bbcee501b99848bdadecd4e290db3ae4/404edb8b4c0648dca4d8f5a2fdfa6c58.html
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/c35896101f8c417482fd040d477bbbe1.html

Syntax verification steps:
1. Validate keywords and clause names against ABAP Keyword Documentation terminology.
2. Validate RAP strict mode and BDEF/BDL constructs against RAP docs.
3. Validate CDS form and annotation usage against CDS docs.
4. Validate EML operation form and response handling pattern.
5. Reconfirm clean-core and released-object constraints.
Syntax output contract (mandatory when providing ABAP/CDS/BDL/EML syntax):
1. Add `Syntax confidence` with exactly one value: `verified`, `partial`, or `draft`.
2. Add `Syntax references` with SAP Help links for each non-trivial syntax area used.
3. If confidence is `partial` or `draft`, add `Verification required` with unresolved syntax items.
4. Do not provide final production code when confidence is `draft`.


---

## Critical Constraints

| Feature | Constraint |
|---|---|
| Window functions (`OVER`) | ABAP SQL only. NOT available in CDS DDL. Use AMDP. |
| `FILTER #( itab WHERE ... )` | Requires **sorted or hashed key** on filtered fields |
| `OFFSET @n` | Requires mandatory `ORDER BY` clause |
| `@` host variables | MANDATORY in all ABAP SQL |
| Performance claims | Context-dependent — measure with SQL trace, don't assume |

---

## Big 4 Anti-Patterns

| Anti-Pattern | Fix | Relative Gain |
|---|---|---|
| N+1 (SELECT in loop) | Batch fetch with WHERE IN | Significant |
| No CDS pushdown (calculate in ABAP) | Move to CDS calculated field | Significant |
| No pagination (fetch all) | OFFSET + UP TO ROWS | Prevents crash |
| SELECT * (fetch 50 cols, use 3) | Project only needed fields | Proportional to data volume |

---

## N+1 Fix Pattern
```abap
" BAD: SELECT inside LOOP
LOOP AT lt_travels INTO DATA(travel).
  SELECT * FROM zbooking WHERE travel_id = @travel-id INTO TABLE @travel-bookings.
ENDLOOP.

" GOOD: Batch fetch + FILTER
SELECT * FROM zbooking
  WHERE travel_id IN ( SELECT travel_id FROM @lt_travels AS t )
  INTO TABLE @DATA(lt_all_bookings).

LOOP AT lt_travels INTO DATA(travel).
  travel-bookings = FILTER #( lt_all_bookings WHERE travel_id = travel-id ).
ENDLOOP.
" Note: lt_all_bookings must be SORTED BY travel_id for FILTER to work!
```

---

## Response Rules
### "Why is this slow?" → Check Big 4 anti-patterns first
### "Window function in CDS?" → NO. Use ABAP SQL SELECT or AMDP table function
### "FILTER not working?" → Check: is the table sorted/hashed on the filtered key?

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. Context and landscape assumptions (Public Cloud, Private Cloud ABAP Cloud, or BTP ABAP Environment)
2. Recommended approach with rationale and Clean Core impact
3. Implementation outline (objects, APIs, contracts, and constraints)
4. Validation plan (tests, checks, and rollback considerations)
5. Evidence and risk notes (source references, version sensitivity, and open assumptions)

Hard rules:
- Do not invent SAP objects, APIs, CDS entities, annotations, or transactions.
- Prefer released APIs and upgrade-safe extension mechanisms.
- Flag version-sensitive guidance explicitly when release context is uncertain.

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Architecture or design trade-offs | decision matrix + constraints + target-state blueprint |
| New implementation | modeling flow + API contract + test strategy |
| Performance issue | hotspot isolation + pushdown/pagination/index strategy |
| Security or authorization | threat points + authorization model + hardening controls |
| Integration behavior | protocol contract + resilience patterns + observability |
| Code review or readiness | findings first + risk ranking + concrete remediation steps |
