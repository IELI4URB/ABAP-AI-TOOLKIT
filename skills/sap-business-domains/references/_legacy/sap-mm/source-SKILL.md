---
name: sap-mm
description: 'SAP Materials Management guidance for S/4HANA ABAP solutions. Use for procurement, purchasing, inventory, valuation, source determination, material master, goods movements, supplier integration, invoice verification, and MM extensions.'
metadata:
  version: 3.0.0
  tags: sap mm procurement inventory valuation purchasing
---

# SAP Materials Management

Use this skill as the MM domain owner. Load only the relevant file under `references/`; prior governance is preserved in [the domain entry-point reference](./references/domain-entrypoint-reference.md).

## Workflow

1. Establish landscape, organizational levels, process stage, document/status lifecycle, valuation, and volume.
2. Verify material, supplier, source, stock, movement, and invoice dependencies.
3. Read only the matching process or released-object reference.
4. Add at most two technical companion skills for the active phase.
5. Validate stock/value integrity, account determination, authorization, performance, and recovery.

## Gates

Do not recommend direct persistence changes or unverified APIs. Preserve movement semantics, quantity/value consistency, document flow, and cross-module controls. Distinguish business-known objects from released technical contracts.
