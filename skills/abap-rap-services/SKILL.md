---
name: abap-rap-services
description: 'Select, design, implement, and troubleshoot ABAP Cloud RAP and service objects. Use for managed versus unmanaged RAP, read-only/custom-query scenarios, draft models, UI versus Web API services, CDS view/projection/custom entities, BDEF behavior handlers, EML, OData V2/V4, service definitions/bindings, API versioning, business events, Fiori Elements annotations, value help, text display, actions, authorization handlers, and RAP activation errors.'
metadata:
  version: 2.0.0
  tags: abap rap cds bdef odata fiori annotations abap-cloud services
---

# ABAP RAP and Services

Load only the guide matching the object or contract being changed.

## Guide Routing

| Object or concern | Guide |
|---|---|
| Choose SAP Help landscape/version and identify target-specific RAP differences | [RAP documentation versioning](./references/official-rap-documentation-versioning.md) |
| Choose read-only/managed/unmanaged/draft/remote/UI/API implementation scenario | [RAP implementation selection](./references/official-rap-implementation-selection.md) |
| Choose C1 EML/CDS, C2 OData UI/API, local proxy, or local/remote event consumption | [RAP consumption selection](./references/official-rap-consumption-selection.md) |
| Official DDIC/CDS/RAP object and transaction semantics | [DDIC, CDS, and RAP semantics](./references/official-ddic-cds-rap-semantics.md) |
| Official annotation syntax, scope, MDE, layers, propagation, API properties | [CDS annotation semantics](./references/official-cds-annotations.md) |
| CDS entities, associations, compositions, DCL structure | [CDS data modeling](./references/abap-cds-data-modeling.md) |
| BDEF kinds, header, characteristics, operations, draft, projection/interface reuse, extensions | [RAP behavior definitions](./references/official-rap-behavior-definitions.md) |
| EML consumption, RAP transactions, derived types/components, provider restrictions, local/privileged mode | [ABAP for RAP business objects](./references/official-abap-for-rap-business-objects.md) |
| Behavior pool, handlers, EML responses, saver | [RAP behavior implementation](./references/abap-rap-behavior-implementation.md) |
| OData V2/V4, query options, ETags, batch | [OData services](./references/abap-odata-service-development.md) |
| List report, object page, value help, text display | [Fiori Elements annotations](./references/abap-fiori-elements-annotations.md) |
| API compatibility, versions, deprecation | [API design and versioning](./references/abap-api-design-versioning.md) |
| RAP events, BAdIs, BDEF/CDS extensions | [Events and enhancements](./references/abap-events-and-enhancements.md) |

## Workflow

1. Establish landscape, exact release/FPS, and SAP Help version key; then use the implementation selector before choosing CDS/BDEF/service artifacts.
2. For an existing provider/API, use the consumption selector; for an existing implementation object, identify its owning RAP/CDS/service contract and load one primary guide.
3. Verify keys, types, cardinalities, behavior signatures, release state, and generated metadata.
4. Activate and run the smallest relevant behavior, metadata, or service test.
