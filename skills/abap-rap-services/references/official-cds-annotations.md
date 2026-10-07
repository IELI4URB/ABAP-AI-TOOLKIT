# Official ABAP CDS Annotation Guide

This guide synthesizes the complete [ABAP CDS Annotations](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-annotations?locale=en-US) subtree reviewed on 2026-10-07: **937 pages / 229,089 words** with zero crawl failures.

## Core Model

A CDS annotation enriches a CDS object with metadata. Annotation metadata is stored when the CDS object is activated and can be evaluated through `CL_DD_DDL_ANNOTATION_SERVICE` or by the owning framework.

Use only annotations that have an annotation definition and follow that definition's rules. SAP currently defines the supported SAP annotations; partners/customers should not invent arbitrary annotations in CDS source.

Sources: [CDS Annotations](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-annotations?locale=en-US), [Specifying Annotations](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-specifying-annotations?locale=en-US), [SAP Annotations](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-sap-annotations?locale=en-US).

## Annotation Property Contract

Before recommending an annotation, inspect its official property table:

| Property | Decision it controls |
|---|---|
| `Kind` | ABAP-runtime annotation or framework-specific annotation |
| `Syntax` | Full name, subannotations, and whether an array is used |
| `Scope` | Exact CDS source positions where it is legal |
| `Type` | Required value type |
| `Enums` | Allowed enumeration symbols |
| `Default` | Value when the annotation is present without a value; this may differ from behavior when absent |
| `Text` | Whether the value is translatable |
| `MDE` | Whether it may be specified in a metadata extension |
| `API` | Whether/how the annotation itself is released as an API |

Do not infer scope, MDE support, enum spelling, or default behavior from examples or the annotation prefix.

Source: [Annotation Properties](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-annotation-properties?locale=en-US).

## Placement Workflow

1. Identify the exact artifact: table entity, view entity, projection, custom/abstract entity, hierarchy, table function, element, parameter, role, service, extension, or metadata extension.
2. Open the annotation's property page and verify its `Scope` includes that position.
3. Verify target-release availability and API status.
4. Decide whether metadata belongs to the reusable data contract, service-specific consumption contract, or app/framework presentation.
5. If using DDLX, verify the annotation's `MDE` property permits it and that the target entity allows metadata extensions.
6. Activate and inspect active annotations/generated service metadata and runtime framework behavior.

The official scope set includes positions such as `#ENTITY`, `#VIEW`, `#ELEMENT`, `#PARAMETER`, `#TABLE_ENTITY`, `#CUSTOM_ENTITY`, `#HIERARCHY`, `#TABLE_FUNCTION`, `#SERVICE`, `#ROLE`, `#ACCESSPOLICY`, and `#ANNOTATE`; not every annotation supports every scope.

Source: [Scopes for Annotations](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-scopes-for-annotations?locale=en-US).

## Syntax Rules

- Annotation syntax is fixed and further constrained by the annotation definition.
- Dot notation identifies subannotations.
- Brackets in an annotation property signature indicate arrays; array elements follow the documented structure/value contract.
- Values can be literals, enum symbols, references, structures, or arrays only when the definition permits them.
- ADT code completion/coloring helps discover defined annotations, but release-aware syntax and property documentation remain authoritative.
- DDL, DDLA, and DDLX checks are not identical; do not assume a DDL syntax check validates every semantic constraint from the annotation definition or consuming framework.

Source: [CDS DDL Annotation Syntax](https://help.sap.com/docs/abap-cloud/abap-keyword/cds-ddl-annotation-syntax?locale=en-US).

## ABAP vs Framework-Specific Annotations

- ABAP annotations are evaluated during activation or by the ABAP runtime framework.
- Framework-specific annotations are evaluated by their owning framework/component.
- An annotation that no active framework evaluates can be ignored even if syntactically accepted.
- Runtime effect therefore requires both valid CDS annotation syntax and an applicable framework/version/consumer.

Do not claim UI, analytics, search, event, OData, or data-integration behavior from CDS activation alone. Verify the framework contract and generated metadata/runtime evaluation.

## Metadata Extensions (DDLX)

Metadata extensions separate eligible metadata from the base DDL and can be transported/activated independently.

- The target CDS entity must allow metadata extensions using `@Metadata.allowExtensions` as required by the target release.
- Only annotations whose property table permits `MDE` can be specified in DDLX.
- Metadata required to activate/define the CDS entity cannot be moved to a metadata extension.
- Use `ANNOTATE ENTITY`/supported DDLX syntax in the dedicated ADT editor.
- `//` is valid for DDLX comments; do not assume `--` is valid.
- Separation improves base DDL readability and avoids unnecessary dependent-object mass activation for presentation metadata.

Source: [Metadata Extensions](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-metadata-extensions?locale=en-US), [DDL for Metadata Extensions](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-ddl-for-metadata-extensions?locale=en-US).

## Metadata Layer Precedence

When annotation services evaluate metadata extensions, layer priority is:

1. `#CUSTOMER`
2. `#PARTNER`
3. `#INDUSTRY`
4. `#LOCALIZATION`
5. `#CORE`

A value found in a higher layer prevents lookup of the same annotation in lower layers. Remaining annotations from the CDS entity itself are then added, including eligible inherited metadata. If multiple extensions define the same annotation in the same layer, evaluation order is undefined but stable; do not design competing definitions within one layer.

Source: [Evaluation of Metadata Extensions](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-evaluation-of-metadata-extensions?locale=en-US).

## Propagation and Overrides

Annotation propagation is annotation- and consumer-dependent; it is not a universal inheritance guarantee.

`Metadata.ignorePropagatedAnnotations` controls whether annotation-service evaluation includes inherited annotations from used CDS definitions:

- `true`: consider direct and derived annotations of the definition, ignore inherited annotations from used definitions.
- `false`: inherited annotations can also be considered.
- When the annotation is absent, documented runtime behavior uses `false` even though the annotation property's syntactic `Default` column can describe the value used when the annotation is present without an explicit value. Distinguish absence from valueless specification.

Always inspect active annotations at the consuming entity. Do not assume an annotation on an interface/base view survives a projection, metadata layer, service exposure, or framework transformation.

Source: [Metadata.ignorePropagatedAnnotations](https://help.sap.com/docs/abap-cloud/abap-keyword/metadata-ignorepropagatedannotations?locale=en-US).

## Fiori Elements and UI Guidance

Prefer app-specific `@UI` presentation metadata in a metadata extension when:

- the annotation's official `MDE` property permits it,
- the entity allows metadata extensions,
- the target Fiori Elements/UI5 version evaluates it, and
- separation from reusable semantics is desired.

This is an architecture convention, not a blanket language statement that every UI annotation must exist only in DDLX. Stable reusable semantics, text relationships, currency/unit bindings, authorization, and service contracts must remain in their owning model layers.

For value help and text display, verify independently:

- provider key and returned fields
- local/additional bindings and usage
- text source/association or text element
- service exposure and generated OData metadata
- UI text arrangement and target-version behavior

## Compatibility and Release Gate

Released CDS/API annotations can be compatibility-significant. Before changing a released object:

1. Inspect the annotation definition's compatibility metadata and API status.
2. Run API consistency and compatibility ATC checks.
3. Check whether changing, adding, or removing the annotation changes consumer semantics, service metadata, key/text/unit/currency interpretation, event payload, or extensibility.
4. Version remote APIs when the documented C2 contract requires it.

Do not treat an annotation as decorative merely because activation succeeds.

## Validation Checklist

- Exact target ABAP release/FPS and consuming framework version known
- Annotation definition exists
- Scope matches placement
- Value type/enums/array/subannotations match definition
- MDE eligibility verified when using DDLX
- Metadata extension layer and conflicts reviewed
- Propagation/override behavior verified at consuming entity
- Active Annotations and generated `$metadata` inspected
- Runtime UI/analytics/search/event behavior tested
- API consistency/compatibility checked for released contracts

## Discovery Tool

SAP documents program `ABAP_DOCU_CDS_ANNOS_OVERVIEW` as an overview of SAP annotations and their properties. Use it or target-system ADT discovery to complement, not replace, release-specific SAP Help and actual API-state checks.
