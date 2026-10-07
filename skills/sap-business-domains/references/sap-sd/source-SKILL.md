---
name: sap-sd
description: 'SAP Sales and Distribution guidance for S/4HANA ABAP solutions. Use for quotations, sales orders, ATP, pricing, partners, deliveries, shipping, billing, output, document flow, credit, and order-to-cash extensions.'
metadata:
  version: 3.0.0
  tags: sap sd sales order pricing delivery billing atp
---

# SAP Sales and Distribution

Use this skill as the SD domain owner. Load only the relevant file under `references/`; prior governance is preserved in [the domain entry-point reference](./references/domain-entrypoint-reference.md).

## Workflow

1. Establish landscape, sales-area context, process stage, document/status flow, and volume.
2. Verify order type, item/schedule logic, ATP, pricing, partner, delivery, billing, output, and Finance boundaries.
3. Read only the matching process or released-object reference.
4. Add at most two technical companion skills for the active phase.
5. Validate document integrity, authorization, performance, integration, and recovery.

## Gates

Do not recommend direct persistence changes or unverified APIs. Preserve pricing, ATP, copy-control, status, delivery, billing, and posting semantics. Distinguish business-known objects from released technical contracts.
