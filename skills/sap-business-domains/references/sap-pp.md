---
name: sap-pp
description: 'SAP Production Planning and PP/DS guidance for S/4HANA ABAP solutions. Use for BOM, routing, work centers, MRP, planned and production/process orders, confirmations, KANBAN, repetitive manufacturing, capacity, scheduling, pegging, and PP/DS.'
metadata:
  version: 3.0.0
  tags: sap pp ppds mrp production capacity scheduling
---

# SAP Production Planning

Use this skill as the PP/PP-DS domain owner.

## Focused reference map

| Concern | Reference | Use |
|---|---|---|
| BOM, routing, work center, and production version | [PP Master Data](./pp-master-data.md) | Process and candidate discovery |
| MRP, demand, supply, and planning runs | [PP MRP and Planning](./pp-mrp-and-planning.md) | Process and candidate discovery |
| Production and process orders | [PP Production Orders](./pp-production-orders.md) | Process and candidate discovery |
| Capacity and midpoint/detailed scheduling | [PP Detailed Scheduling](./pp-detailed-scheduling.md) | Process and candidate discovery |
| CDS, RAP BO, BAPI, BAdI, and exit candidates | [PP ABAP Development](./pp-abap-development.md) | Candidate discovery only; classify C0/C1/C2/Tier 2 and verify in the target system |
| Domain governance: gates, landscape, cross-skill, eligibility, and definition of done | [domain governance](./domain-governance.md) | Shared governance set; load for a full governance audit or release-readiness review |

Read at most one focused reference for the active concern. For internal ABAP updates, search for a C1-released transactional RAP business object in the target system; do not substitute a remote OData API or classic BAPI without an explicit boundary decision.

## Workflow

1. Establish landscape and distinguish classic PP, embedded PP/DS, and APO PP/DS.
2. Classify master data, planning, execution, capacity, scheduling, or integration scope.
3. Verify BOM/routing/work-center/version, status, movement, confirmation, and settlement dependencies.
4. Read only the focused reference mapped above when needed and add at most two technical companions.
5. Validate planning integrity, cycles/depth, volume, authorization, performance, and recovery.

## Gates

Do not recommend unverified transactional APIs or direct persistence changes. Preserve order/status, stock movement, confirmation, planning, and settlement semantics. Verify release eligibility per landscape.
