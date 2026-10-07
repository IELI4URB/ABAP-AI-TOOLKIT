---
name: sap-tm
description: 'SAP Transportation Management guidance for S/4HANA ABAP solutions. Use for freight units/orders/bookings, planning, tendering, carriers, capacity, charges, settlement, execution events, milestones, exceptions, and logistics integration.'
metadata:
  version: 3.0.0
  tags: sap tm freight transportation planning execution charges
---

# SAP Transportation Management

Use this skill as the TM domain owner. Load only the relevant file under `references/`; prior governance is preserved in [the domain entry-point reference](./sap-tm/references/domain-entrypoint-reference.md).

## Workflow

1. Establish landscape and distinguish embedded TM, decentralized TM, and integration boundaries.
2. Classify demand, planning, tendering, execution, event, charge, or settlement scope.
3. Verify freight document flow, locations/resources, capacity, carrier, charge, and SD/EWM boundaries.
4. Read only the matching reference and add at most two technical companions.
5. Validate planning/execution integrity, authorization, volume, event idempotency, and recovery.

## Gates

Do not recommend direct persistence changes or unverified APIs. Preserve freight document status, planning constraints, charge/settlement semantics, event ordering, and logistics integration contracts.

