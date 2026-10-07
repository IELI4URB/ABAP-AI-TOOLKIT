# Search and Traversal Algorithms for ABAP (Supply Chain and Scheduling)

Objective: ready-to-use ABAP patterns for standard search and graph traversal algorithms used in pegging, BOM processing, scheduling, and large dataset processing.

## BFS (Breadth-First Search)
Use for:
- Multi-level pegging explosion
- BOM level-by-level expansion
- Shortest path in unweighted graph
- Supply chain where-used analysis

Characteristics:
- Explores all nodes at current depth before going deeper
- Guarantees shortest path in unweighted graphs
- Uses FIFO queue
- Memory cost can be high for wide graphs (stores full frontier)

```abap
CLASS zcl_bfs_traversal DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_node,
             node_id TYPE guid,
             level   TYPE i,
             parent  TYPE guid,
           END OF ty_node,
           tt_nodes TYPE STANDARD TABLE OF ty_node WITH EMPTY KEY,
           tt_guid  TYPE STANDARD TABLE OF guid WITH EMPTY KEY.

    METHODS traverse
      IMPORTING iv_start_node TYPE guid
                iv_max_level  TYPE i DEFAULT 999
      RETURNING VALUE(rt_result) TYPE tt_nodes.

  PRIVATE SECTION.
    METHODS get_adjacent_nodes
      IMPORTING iv_node_id TYPE guid
      RETURNING VALUE(rt_children) TYPE tt_guid.
ENDCLASS.

CLASS zcl_bfs_traversal IMPLEMENTATION.
  METHOD traverse.
    DATA lt_queue   TYPE STANDARD TABLE OF ty_node WITH EMPTY KEY.
    DATA lt_visited TYPE HASHED TABLE OF guid WITH UNIQUE KEY table_line.

    APPEND VALUE #( node_id = iv_start_node level = 0 ) TO lt_queue.

    WHILE lt_queue IS NOT INITIAL.
      DATA(ls_current) = lt_queue[ 1 ].
      DELETE lt_queue INDEX 1.

      IF line_exists( lt_visited[ table_line = ls_current-node_id ] ).
        CONTINUE.
      ENDIF.
      INSERT ls_current-node_id INTO TABLE lt_visited.

      APPEND ls_current TO rt_result.

      IF ls_current-level >= iv_max_level.
        CONTINUE.
      ENDIF.

      DATA(lt_children) = get_adjacent_nodes( ls_current-node_id ).
      LOOP AT lt_children ASSIGNING FIELD-SYMBOL(<lv_child>).
        IF NOT line_exists( lt_visited[ table_line = <lv_child> ] ).
          APPEND VALUE #(
            node_id = <lv_child>
            level   = ls_current-level + 1
            parent  = ls_current-node_id
          ) TO lt_queue.
        ENDIF.
      ENDLOOP.
    ENDWHILE.
  ENDMETHOD.
ENDCLASS.
```

Performance keys:
- Hashed visited set gives O(1) cycle detection
- Each node processed once gives O(V + E)
- Batch-fetch adjacency (do not call DB per node)

## DFS (Depth-First Search)
Use for:
- Finding deep leaf nodes (for example raw materials in BOM)
- Path existence checks
- Topological preprocessing
- Memory-constrained traversal of deep trees

Characteristics:
- Explores as deep as possible before backtracking
- Uses LIFO stack (or recursion)
- Lower memory than BFS for deep and narrow graphs
- Does not guarantee shortest path

```abap
METHOD traverse_dfs.
  DATA lt_stack   TYPE STANDARD TABLE OF ty_node WITH EMPTY KEY.
  DATA lt_visited TYPE HASHED TABLE OF guid WITH UNIQUE KEY table_line.

  APPEND VALUE #( node_id = iv_start level = 0 ) TO lt_stack.

  WHILE lt_stack IS NOT INITIAL.
    DATA(lv_top) = lines( lt_stack ).
    DATA(ls_current) = lt_stack[ lv_top ].
    DELETE lt_stack INDEX lv_top.

    IF line_exists( lt_visited[ table_line = ls_current-node_id ] ).
      CONTINUE.
    ENDIF.
    INSERT ls_current-node_id INTO TABLE lt_visited.

    APPEND ls_current TO rt_result.

    IF ls_current-level >= iv_max_level.
      CONTINUE.
    ENDIF.

    DATA(lt_children) = get_adjacent_nodes( ls_current-node_id ).
    LOOP AT lt_children ASSIGNING FIELD-SYMBOL(<lv_child>).
      IF NOT line_exists( lt_visited[ table_line = <lv_child> ] ).
        APPEND VALUE #(
          node_id = <lv_child>
          level   = ls_current-level + 1
          parent  = ls_current-node_id
        ) TO lt_stack.
      ENDIF.
    ENDLOOP.
  ENDWHILE.
ENDMETHOD.
```

## Topological Sort (Kahn's Algorithm)
Use for:
- Dependency-order processing
- MRP netting and scheduling sequence
- DAG processing where prerequisites must be resolved first

```abap
METHOD topological_sort.
  " Input: lt_edges TYPE TABLE OF ty_edge (from_node, to_node)
  " Output: rt_sorted TYPE STANDARD TABLE OF guid

  TYPES: BEGIN OF ty_degree,
           node_id TYPE guid,
           degree  TYPE i,
         END OF ty_degree.

  DATA lt_in_degree TYPE HASHED TABLE OF ty_degree WITH UNIQUE KEY node_id.
  DATA lt_queue     TYPE STANDARD TABLE OF guid WITH EMPTY KEY.

  LOOP AT lt_edges ASSIGNING FIELD-SYMBOL(<edge>).
    ASSIGN lt_in_degree[ node_id = <edge>-to_node ] TO FIELD-SYMBOL(<deg>).
    IF sy-subrc = 0.
      <deg>-degree += 1.
    ELSE.
      INSERT VALUE #( node_id = <edge>-to_node degree = 1 ) INTO TABLE lt_in_degree.
    ENDIF.

    IF NOT line_exists( lt_in_degree[ node_id = <edge>-from_node ] ).
      INSERT VALUE #( node_id = <edge>-from_node degree = 0 ) INTO TABLE lt_in_degree.
    ENDIF.
  ENDLOOP.

  LOOP AT lt_in_degree ASSIGNING <deg> WHERE degree = 0.
    APPEND <deg>-node_id TO lt_queue.
  ENDLOOP.

  WHILE lt_queue IS NOT INITIAL.
    DATA(lv_current) = lt_queue[ 1 ].
    DELETE lt_queue INDEX 1.
    APPEND lv_current TO rt_sorted.

    LOOP AT lt_edges ASSIGNING <edge> WHERE from_node = lv_current.
      ASSIGN lt_in_degree[ node_id = <edge>-to_node ] TO <deg>.
      <deg>-degree -= 1.
      IF <deg>-degree = 0.
        APPEND <edge>-to_node TO lt_queue.
      ENDIF.
    ENDLOOP.
  ENDWHILE.

  " Cycle detection: lines( rt_sorted ) < lines( lt_in_degree )
ENDMETHOD.
```

## Dijkstra (Weighted Shortest Path)
Use for:
- Cost-optimal supply assignment
- Transportation route optimization
- Weighted network analysis (non-negative weights)

```abap
METHOD dijkstra.
  TYPES: BEGIN OF ty_dist,
           node_id  TYPE guid,
           distance TYPE decfloat34,
           visited  TYPE abap_bool,
           prev     TYPE guid,
         END OF ty_dist.

  CONSTANTS lc_inf TYPE decfloat34 VALUE '99999999'.

  DATA lt_dist TYPE HASHED TABLE OF ty_dist WITH UNIQUE KEY node_id.

  LOOP AT lt_all_nodes ASSIGNING FIELD-SYMBOL(<lv_node>).
    INSERT VALUE #(
      node_id  = <lv_node>
      distance = COND #( WHEN <lv_node> = iv_source THEN 0 ELSE lc_inf )
      visited  = abap_false
    ) INTO TABLE lt_dist.
  ENDLOOP.

  DO.
    DATA(lv_min_dist) = lc_inf.
    DATA lv_current   TYPE guid.

    LOOP AT lt_dist ASSIGNING FIELD-SYMBOL(<d>) WHERE visited = abap_false.
      IF <d>-distance < lv_min_dist.
        lv_min_dist = <d>-distance.
        lv_current = <d>-node_id.
      ENDIF.
    ENDLOOP.

    IF lv_min_dist >= lc_inf.
      EXIT.
    ENDIF.

    ASSIGN lt_dist[ node_id = lv_current ] TO FIELD-SYMBOL(<curr>).
    <curr>-visited = abap_true.

    LOOP AT get_weighted_edges( lv_current ) ASSIGNING FIELD-SYMBOL(<ls_edge>).
      ASSIGN lt_dist[ node_id = <ls_edge>-to_node ] TO FIELD-SYMBOL(<neighbor>).
      IF sy-subrc = 0 AND <neighbor>-visited = abap_false.
        DATA(lv_new_dist) = <curr>-distance + <ls_edge>-weight.
        IF lv_new_dist < <neighbor>-distance.
          <neighbor>-distance = lv_new_dist.
          <neighbor>-prev = lv_current.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDDO.

  rt_distances = lt_dist.
ENDMETHOD.
```

Note: this implementation is O(V^2 + E). For very large graphs, use a priority queue pattern to reach O(E log V).

## Decision Matrix

| Scenario | Algorithm | Why |
|---|---|---|
| BOM explosion (all levels) | BFS | Level-by-level full expansion |
| Pegging traversal (supply to demand) | BFS + visited hash | Handles shared supply and avoids revisits |
| Find deepest raw material leaf | DFS | Deep-first and memory-efficient on narrow graphs |
| MRP netting sequence | Topological sort | Dependency-order execution |
| Lowest-cost supply assignment | Dijkstra | Weighted shortest path |
| Route optimization with heuristic | A* | Dijkstra with directed heuristic |
| Exact record lookup | Hashed table | O(1) key access |
| Range scan / prefix match | Sorted table + binary search | O(log n) lookup on ordered data |
| Cycle detection in pegging | DFS with back-edge detection | Standard cycle detection |
| Reverse BOM where-used | BFS upward from leaf | Finds all parent chains |

## Complexity Snapshot

| Algorithm | Time | Space | Cycles |
|---|---|---|---|
| BFS | O(V + E) | O(V) queue | Yes, with visited set |
| DFS | O(V + E) | O(V) stack | Yes, with visited set |
| Topological sort | O(V + E) | O(V) | No, DAG only (detects cycles) |
| Dijkstra (heap) | O(E log V) | O(V) | Yes, non-negative weights |
| Binary search | O(log n) | O(1) | N/A |
| Hash lookup | O(1) average | O(n) | N/A |

## Critical Implementation Rules
1. Always use hashed table for visited sets.
2. Batch-fetch children; avoid one DB call per node.
3. Add iv_max_level guards for runaway depth.
4. Preload edge list once and build adjacency in memory.
5. Use ASSIGNING in inner traversal loops to avoid copy overhead.

## Supply-Chain Specific Notes
- BOM and pegging graphs are often shared-node DAG-like structures with occasional cycle risk from bad master data. Keep cycle protection mandatory.
- For large datasets, partition traversal by plant, MRP area, or planning run to control memory.
- For weighted optimization, validate that edge weights are non-negative before running Dijkstra.

## SAP Help Validation Notes

Validated on 2026-08-05 against SAP Help content that is publicly reachable.

Confirmed ABAP facts used in this reference:
- Internal table categories and access behavior are correct: hashed tables are managed by hash algorithm, accessed by table key only, and do not support index operations.
- line_exists is a valid predicate function for checking existence of table rows.
- Table expressions itab[ ... ] are valid operand-position read access.
- Performance guidance to use hash tables for single-record lookups and sorted tables plus binary search for range or ordered lookup scenarios is documented in SAP performance guidance.

Scope clarification:
- BFS, DFS, topological sort, and Dijkstra are general computer science algorithms. SAP Help validates ABAP language and internal-table performance primitives used by the implementations, not the algorithm theory itself.

SAP Help sources:
- Internal Tables (Application Development on AS ABAP, SP27):
  https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_FOR_SOH_740/7bfe8cdcfbb040dcb6702dada8c3e2f0/29deb7eddc4f47cf8c919661cdf52de2.html?locale=en-US&state=PRODUCTION&version=7.40.27
- ABAP Programming Language (Enhanced) release notes (line_exists and table expressions):
  https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_FOR_SOH_740/f1cccec432514a3181f2852f2b91d306/1d3322510300fc74e10000000a423f68.html?locale=en-US&state=PRODUCTION&version=7.40.30
- Performance Tips for ABAP Programming (hash/sorted/binary-search guidance):
  https://help.sap.com/docs/SAP_NETWEAVER_750/2e90b26cf7484203a523bf0f4b1bc137/b3573138bb684b128e5067a44af22da8.html?locale=en-US&state=PRODUCTION&version=7.5.25
