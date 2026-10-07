---
name: abap-rap-services
description: 'Design, implement, and troubleshoot ABAP Cloud RAP and service objects. Use for CDS view/projection/custom entities, BDEF behavior handlers, EML, OData V2/V4, service definitions/bindings, API versioning, business events, Fiori Elements annotations, value help, text display, draft, actions, authorization handlers, and RAP activation errors.'
---

# ABAP RAP and Services

Load only the guide matching the object or contract being changed.

## Guide Routing

| Object or concern | Guide |
|---|---|
| Official DDIC/CDS/RAP object and transaction semantics | [DDIC, CDS, and RAP semantics](./references/official-ddic-cds-rap-semantics.md) |
| CDS entities, associations, compositions, DCL structure | [CDS data modeling](./references/abap-cds-data-modeling.md) |
| Behavior pool, handlers, EML responses, saver | [RAP behavior implementation](./references/abap-rap-behavior-implementation.md) |
| OData V2/V4, query options, ETags, batch | [OData services](./references/abap-odata-service-development.md) |
| List report, object page, value help, text display | [Fiori Elements annotations](./references/abap-fiori-elements-annotations.md) |
| API compatibility, versions, deprecation | [API design and versioning](./references/abap-api-design-versioning.md) |
| RAP events, BAdIs, BDEF/CDS extensions | [Events and enhancements](./references/abap-events-and-enhancements.md) |

## Workflow

1. Establish landscape/release and identify the owning RAP/CDS/service object.
2. Load one primary guide; add a second only for a real cross-object contract.
3. Verify keys, types, cardinalities, behavior signatures, release state, and generated metadata.
4. Activate and run the smallest relevant behavior, metadata, or service test.
