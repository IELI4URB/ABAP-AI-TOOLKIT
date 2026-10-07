---
name: sap-pp
description: 'SAP Production Planning and PP/DS guidance for S/4HANA ABAP solutions. Use for BOM, routing, work centers, MRP, planned and production/process orders, confirmations, KANBAN, repetitive manufacturing, capacity, scheduling, pegging, and PP/DS.'
metadata:
  version: 3.0.0
  tags: sap pp ppds mrp production capacity scheduling
---

# SAP Production Planning

Use this skill as the PP/PP-DS domain owner. Load only the relevant file under `references/`; prior governance is preserved in [the domain entry-point reference](./_legacy/sap-pp/references/domain-entrypoint-reference.md).

## Workflow

1. Establish landscape and distinguish classic PP, embedded PP/DS, and APO PP/DS.
2. Classify master data, planning, execution, capacity, scheduling, or integration scope.
3. Verify BOM/routing/work-center/version, status, movement, confirmation, and settlement dependencies.
4. Read only the matching reference and add at most two technical companions.
5. Validate planning integrity, cycles/depth, volume, authorization, performance, and recovery.

## Gates

Do not recommend unverified transactional APIs or direct persistence changes. Preserve order/status, stock movement, confirmation, planning, and settlement semantics. Verify release eligibility per landscape.

