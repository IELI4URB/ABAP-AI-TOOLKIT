---
name: abap-fiori-elements-annotations
description: 'Design and troubleshoot Fiori Elements CDS annotations for SAP ABAP Cloud. Use for list reports, object pages, metadata extensions, UI facets or fields, value help, F4, dependent bindings, dropdowns, text associations or elements, ID-text display, text arrangement, charts, side effects, and generated OData metadata.'
metadata:
  version: 3.0.0
  tags: abap fiori-elements annotations ui value-help text-display metadata-extension odata
---

# ABAP Cloud Fiori Elements Annotations

Use this skill as the UI-annotation and value-help router. Load only the reference needed for the request.

## Ownership

This skill owns Fiori Elements presentation annotations, metadata-extension placement, value-help contracts, text display, and generated UI metadata. Use [the official annotation guide](./official-cds-annotations.md) for scope, MDE eligibility, layers, propagation, and annotation API properties; use `abap-cds-data-modeling` for structural CDS design and `abap-rap-behavior-implementation` for behavior logic.

## Workflow

1. Establish landscape, ABAP release/FPS, OData version, UI5/Fiori Elements version, page type, and target CDS artifact.
2. Inspect exposed entity/property names, types, keys, associations, writeability, authorization, and generated `$metadata`.
3. Separate provider semantics, service-specific consumption, and app-specific presentation before placing annotations.
4. Read only the matching references below.
5. For value help, define provider key, text source, filters, result mappings, and text arrangement as separate contracts.
6. Validate Active Annotations, service metadata, runtime requests, authorization, draft state, and desktop/mobile rendering.

## Reference Routing

| Request | Read |
|---|---|
| Annotation legality, scope, MDE support, layers, propagation | [official annotation semantics](./official-cds-annotations.md) |
| Value help, dependent binding, text display, dropdown | [value-help and text display](./abap-fiori-elements-annotations/references/value-help-and-text-display.md) |
| Placement or metadata extension | `ui-annotations-catalog.md`, sections 1-2 |
| List report columns | section 3 |
| Header, facets, field groups, identification | sections 4-7 |
| Filter bar | section 8 |
| General value-help catalog | section 9, then the dedicated value-help reference |
| Side effects or draft UI | sections 10-11 |
| Charts or analytical list page | sections 12-13 |
| Search | section 14 |
| Review or complete examples | sections 15-18 |

The catalog is [the UI annotations reference](./abap-fiori-elements-annotations/references/ui-annotations-catalog.md).

## Mandatory Gates

- Do not infer annotation placement from the annotation prefix; classify the CDS artifact and consumer first.
- Do not use value-help result binding as a substitute for text modeling, and do not set text arrangement without a verified text source.
- Verify every local/provider element, type, key, cardinality, writeability, authorization, and OData exposure.
- Confirm target-version support in generated metadata and runtime behavior; examples are not release evidence.
- Verify CDS/annotation/BDEF syntax in current SAP Help and report `Syntax confidence: verified` or block production use.
- Release guidance must include metadata and UI tests, authorization, ATC/readiness, rollback, browser/device checks, and support evidence.

## Response Shape

For non-trivial requests, state target versions and artifact type, annotation ownership, provider/text/value-help contracts, expected metadata, validation steps, and unresolved release assumptions.

