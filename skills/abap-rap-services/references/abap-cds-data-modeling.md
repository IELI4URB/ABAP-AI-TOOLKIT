---
name: abap-cds-data-modeling
description: 'Design and review CDS data models for SAP ABAP Cloud. Use for view entities, projection views, abstract or custom entities, table entities, hierarchies, associations, compositions, DCL, metadata extensions, CDS annotations, IF_RAP_QUERY_PROVIDER, entity extensions, and DEFINE VIEW ENTITY syntax.'
metadata:
  version: 2.0.0
  tags: abap cds data-modeling view-entity projection custom-entity annotations dcl abap-cloud
---

# ABAP Cloud CDS Data Modeling

SAP Help baseline: https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models

Use this skill as the CDS structure and entity-selection router. Load only the relevant part of [the complete CDS syntax reference](./abap-cds-data-modeling/references/cds-complete-syntax.md).

## Ownership

This skill owns CDS entity selection, layering, keys, associations, compositions, structural annotations, custom entities, and DCL syntax. Use [the official annotation guide](./official-cds-annotations.md) for annotation scope, values, metadata extensions, propagation, and API properties; use `abap-fiori-elements-annotations` for UI/value-help/text presentation, `abap-iam-authorization` for authorization architecture, `abap-sql-and-amdp` for table-function implementation, and `abap-platform-2025` for 2025-only capabilities.

## Workflow

1. Establish landscape, exact release/FPS, transactional or analytical purpose, ownership, volume, and consumers.
2. Inspect source contracts: keys, types, lengths, decimals, units/currencies, nullability, authorization, and release state.
3. Select the entity type and layer before choosing annotations or behavior.
4. Read only the matching reference sections below.
5. Define cardinalities, ON conditions, lifecycle ownership, redirections, provider contracts, and extension boundaries.
6. Validate activation, SQL result semantics, authorization, generated OData metadata, paging, and large-volume behavior.

## Reference Routing

| Request | Read sections in `cds-complete-syntax.md` |
|---|---|
| Entity selection | 1 |
| View entity | 2 |
| Projection view | 3 |
| Abstract entity | 4 |
| Custom entity/query provider | 5 |
| Table entity | 6, plus `abap-platform-2025` |
| Association or composition | 7, 8 |
| DCL | 9, 11 |
| Annotation lookup | 10, then [official annotation semantics](./official-cds-annotations.md) |

## Mandatory Gates

- Separate reusable interface models, consumption projections, behavior, and UI metadata by responsibility.
- Verify keys, cardinalities, association exposure, composition ownership, type compatibility, and projection redirection.
- Do not recommend extension of an SAP provider without verified C1 release and explicit extensibility.
- Check N+1 effects, pushdown, filters, paging, memory, and result size for every exposed model.
- Verify CDS DDL/DCL and annotation syntax for the exact release; report `Syntax confidence: verified` or block production use.
- Release guidance must include activation, ATC/readiness, unit/integration and metadata tests, rollback, and operational evidence.

## Response Shape

For non-trivial requests, state landscape and consumers, selected entity/layer, object contracts, relationships and authorization, performance constraints, test evidence, and unresolved release assumptions.

