---
name: abap-api-design-versioning
description: 'Design and evolve SAP ABAP Cloud RAP APIs. Use for service-binding versions, backward compatibility, breaking changes, deprecation, versioned projections/DTOs, API lifecycle, release-state annotations, and multi-projection BO constraints.'
---

# ABAP API Design and Versioning

Load the relevant pattern from [API patterns](./abap-api-design-versioning/references/api-patterns.md). Prior governance is preserved in [the entry-point reference](./abap-api-design-versioning/references/entrypoint-reference.md).

## Workflow

1. Identify consumers, service binding, entity/action contract, and compatibility window.
2. Classify the proposed change as compatible, additive with risk, or breaking.
3. Use service-binding versions and versioned projections/contracts; do not invent URL-path versioning for RAP.
4. Define deprecation, coexistence, migration, test, and retirement evidence.

## Gates

Verify release policy and target support. Preserve old contracts during the approved deprecation period, account for LUW constraints in multi-projection BOs, and require consumer contract tests before removal.

