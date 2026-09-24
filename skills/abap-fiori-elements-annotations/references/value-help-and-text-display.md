# Value Help and Text Display by CDS Artifact Type

Last source review: 2026-09-24

Use this reference before recommending `@Consumption.valueHelpDefinition`, `additionalBinding`, `@ObjectModel.text.*`, `@Semantics.text`, `@Semantics.language`, or `@UI.textArrangement`.

## First Decision: Which CDS Artifact Owns the Concern?

| Artifact type | Owns | Usually does not own |
|---|---|---|
| Basic/interface view entity | Stable business key, reusable text relationship, amount/unit semantics, reusable associations | App-specific list columns, facets, text arrangement |
| Composite interface view entity | Reusable business joins and semantic relationships | App-specific value-help behavior unless all consumers need it |
| Transactional projection view | Service-specific field exposure and value-help binding; provider contract must match the use case or be inherited where syntax requires it | Persistence semantics or reusable master-data ownership |
| Value-help provider view | Selectable key, display columns, dependent-filter fields, search fields | Consumer UI layout; unrelated business joins |
| Text provider view | Business key, language key, descriptive text | Value-help behavior; SAP warns against using one associated provider for both text and value help |
| Metadata extension | Fiori UI annotations, including line items, facets, selection fields, and app-specific text arrangement | Data joins, associations, provider keys, value-help datasets |

The placement is an architectural default, not a syntax law. Put reusable semantics as low as practical and consumption-specific behavior as high as practical. Inspect propagated annotations before duplicating or overriding them.

## Mandatory Inspection Before Suggesting Annotations

1. Identify the consumer element and its CDS artifact type.
2. Identify whether the use case is display text, value selection, dependent filtering, result write-back, or a combination.
3. Inspect the complete consumer-to-service path: interface view, projection, metadata extension, service definition, and binding.
4. Confirm all local elements referenced by annotations are exposed in the projection.
5. Confirm all provider elements referenced by annotations exist in the value-help provider.
6. Confirm data type, length, case conversion, and nullability compatibility across each mapping.
7. Check Active Annotations in ADT to understand propagation and overrides.
8. Inspect generated OData `$metadata` and the value-list metadata request.

Never infer a value help or text relationship from similar field names alone.

## Value Help Placement

### Reusable Versus Service-Specific

- Put `@Consumption.valueHelpDefinition` on an interface element only when the same value-help contract is valid for every consumer and its propagation is intentional.
- Prefer the transactional projection element when the provider, dependent filters, returned fields, or UX behavior is specific to one service.
- Do not put `@Consumption.valueHelpDefinition` in a metadata extension merely because the value help appears in the UI. It defines a data/consumption contract, not page layout.
- Prefer an explicit provider contract supported by the target release, normally `transactional_query` for a transactional UI projection. Omission currently defaults to transactional query but is obsolete/deprecated. Do not add an explicit contract where projection syntax requires inheritance, such as applicable child projections with to-parent associations or parent redirections; verify the exact rules for the target release.

### Value-Help Provider Contract

A dedicated provider should expose only what the value help needs:

- The element whose value is returned to the consumer.
- Human-readable display elements.
- Every element used by `additionalBinding` filters or results.
- Searchable elements when free-text search is required.
- Stable keys and authorization behavior appropriate for the value-help dataset.

Do not assume `@ObjectModel.representativeKey` creates a value help. It identifies a representative key; `@Consumption.valueHelpDefinition` establishes the value-help reference.

### Simple Value Help

This is the minimum ABAP CDS shape documented for a consumer element:

```cds
@Consumption.valueHelpDefinition: [{
  entity: {
    name: 'ZI_AgencyVH',
    element: 'AgencyID'
  }
}]
AgencyID;
```

Before using it, verify:

- `ZI_AgencyVH` exists and is allowed in the target language version.
- `AgencyID` exists in both consumer and provider with compatible types.
- The provider is represented correctly in generated service/value-list metadata.
- Authorization does not expose forbidden master data.

### Dependent Value Help with Additional Binding

Official SAP Help syntax:

```cds
@Consumption.valueHelpDefinition: [{
  entity: {
    name: 'ZI_ConnectionVH',
    element: 'ConnectionID'
  },
  additionalBinding: [{
    localElement: 'CarrierID',
    element: 'CarrierID',
    usage: #FILTER
  }]
}]
ConnectionID;
```

Usage has material behavior:

| Usage | Direction | Effect |
|---|---|---|
| `#FILTER` | Consumer to provider | Restricts provider rows using the current local value |
| `#RESULT` | Provider to consumer | Copies the selected provider value into the local element |
| `#FILTER_AND_RESULT` | Both | Filters and writes the selected value back |

`#FILTER_AND_RESULT` is the documented default when `usage` is omitted. Always specify `usage` explicitly to avoid accidental write-back.

Additional-binding rules:

- The local element or parameter must exist in the consumer.
- The mapped element or parameter must exist in the provider.
- A `#RESULT` target must be exposed and writable in the applicable UI/transaction context.
- For numeric local elements, SAP documents that an empty initial value can filter using `0`; test initial-state behavior.
- For a dependent chain such as Company Code -> Plant -> Storage Location, model and test each dependency separately.

### Result Binding Is Not Text Display

Do not use `usage: #RESULT` merely to show a description beside an ID. A result binding writes another consumer field after selection. For display text, model a text element or text association and apply text arrangement.

Use `#RESULT` only when the business contract intentionally copies provider data into another local property and that property is part of the projection and update contract.

### Keep Value-Help and Text Providers Separate

SAP Help warns that associating the value-help provider to the source view can prevent the provider metadata from being marked as a value list. It recommends separating value-help information into provider views that do not coincide with associated views such as text providers.

Default design:

```text
ZI_Agency          reusable agency/master-data interface
ZI_AgencyText      language-dependent text provider
ZI_AgencyVH        dedicated value-help provider
ZC_Travel          service-specific transactional projection
ZME_Travel         metadata extension for UI arrangement
```

A provider may reuse lower-level sources, but do not make one exposed CDS entity perform both association-based text retrieval and value-help-provider roles without verifying generated metadata.

## Text Display Placement

A complete text display needs two independent decisions:

1. **Text source**: which element or association supplies the description?
2. **Arrangement**: should the UI show ID, text, or both, and in what order?

`@UI.textArrangement` controls presentation; it does not discover the text source.

### Pattern A: Text Element Already in the Same Entity

Use a reusable text-element relationship on the key/code field:

```cds
@ObjectModel.text.element: ['AgencyName']
AgencyID,
AgencyName
```

Then apply app-specific arrangement on the exposed projection element, preferably through its metadata extension:

```cds
@UI.textArrangement: #TEXT_LAST
AgencyID;
```

Expected intent:

| Arrangement | Intended display |
|---|---|
| `#TEXT_ONLY` | Agency name |
| `#TEXT_FIRST` | Agency name followed by ID |
| `#TEXT_LAST` | ID followed by agency name |
| `#TEXT_SEPARATE` | Code/ID and text are represented separately; the ID is shown and text may appear elsewhere. Rendering is control/version dependent |

Actual punctuation and rendering vary by Fiori elements version, control, OData version, edit/display mode, and responsive context. Verify in the target app.

### Pattern B: Language-Dependent Text Provider

Use a dedicated text provider as the reusable source when descriptions vary by logon language. Then choose the consumer pattern:

- Direct association consumption: use `@ObjectModel.text.association` according to target-release rules.
- Denormalized service projection: follow the target-release `localized` projection pattern and identify the projected text through `@ObjectModel.text.element`. SAP documents that this projection pattern must not use `@ObjectModel.text.association` on the projected field.

Conceptual text-provider shape:

```cds
@ObjectModel.dataCategory: #TEXT
define view entity ZI_AgencyText
  as select from zagency_text
{
  key agency_id as AgencyID,

  @Semantics.language: true
  key language as Language,

  @Semantics.text: true
  agency_name as AgencyName
}
```

Conceptual consumer relationship:

```cds
association [0..*] to ZI_AgencyText as _Text
  on $projection.AgencyID = _Text.AgencyID

@ObjectModel.text.association: '_Text'
AgencyID,
_Text
```

Treat these as release-sensitive templates until activated in the target system. Verify cardinality, language handling, annotation availability, and OData metadata.

Do not combine `@ObjectModel.text.association` and `@ObjectModel.text.element` on the same field unless target-release documentation explicitly supports the combination. SAP documentation describes them as alternative text-modeling strategies.

### Projection Requirements for Text Display

The service-facing projection must expose everything required by the selected text strategy:

- For `text.element`, expose the code and referenced text element.
- For `text.association`, expose or redirect the required association according to projection and service rules.
- For a denormalized language-dependent projection, verify the target-release `localized` syntax and do not retain `text.association` where SAP prohibits it.
- Apply or override `@UI.textArrangement` at the consumption edge when different applications need different rendering.
- Check whether inherited annotations are ignored or overridden through metadata settings.

A text annotation pointing to an element that was removed from the projection cannot produce reliable UI text.

## Metadata Extension Placement

Entity-level UI annotations precede `annotate entity`; element-level annotations belong inside its element block:

The annotated CDS entity must allow metadata extensions, for example through `@Metadata.allowExtensions: true` where supported. Verify the metadata layer and annotation propagation.

```cds
@Metadata.layer: #CUSTOMER
@UI.headerInfo: {
  typeName: 'Travel',
  typeNamePlural: 'Travels'
}
annotate entity ZC_Travel with
{
  @UI.lineItem: [{ position: 10 }]
  TravelID;

  @UI.lineItem: [{ position: 20 }]
  @UI.selectionField: [{ position: 10 }]
  @UI.textArrangement: #TEXT_LAST
  AgencyID;
}
```

Do not place entity-level `@UI.headerInfo` or `@UI.facet` inside the element block.

## Selection Field, Display Text, and Value Help Are Separate

For a field such as `AgencyID`:

- `@UI.selectionField` places it in the filter bar.
- `@Consumption.valueHelpDefinition` defines the selectable values and mappings.
- `@ObjectModel.text.element` or `@ObjectModel.text.association` defines its descriptive text source.
- `@UI.textArrangement` controls how ID and text are rendered.

One annotation cannot substitute for the others.

## Fixed-Value Versus Search Value Help

Before recommending a dropdown, distinguish:

- A small, stable fixed-value set.
- A searchable master-data value help.
- A context-dependent value help with additional bindings.

Do not promise a dropdown from `@Consumption.valueHelpDefinition` alone. Rendering depends on generated metadata, fixed-value semantics, cardinality/size behavior, OData version, and Fiori elements version. Verify the target service metadata and UI control.

## Failure Diagnosis

### Value-help icon or dialog is missing

Check:

1. Annotation exists on the service-exposed element after propagation.
2. Provider and element names are exact.
3. Consumer/provider types are compatible.
4. Generated `$metadata` contains a value-list mapping.
5. Value-list metadata request resolves for the property.
6. Provider authorization returns rows.
7. The provider is not incorrectly reused as an associated text provider.

### Value help opens but dependent filter does not work

Check:

1. `usage` is explicitly `#FILTER` or `#FILTER_AND_RESULT`.
2. Local element is populated before opening the help.
3. Both local and provider elements are exposed.
4. Initial numeric values are not unintentionally filtering by `0`.
5. Backend trace shows the expected provider filter.

### ID displays but description does not

Check:

1. A text source is defined; value help alone is insufficient.
2. Referenced text element is exposed by the projection.
3. Text association is exposed/redirected and language filtering works.
4. `@UI.textArrangement` is applied to the correct service property.
5. Active annotations and `$metadata` contain the expected text relationship.
6. Edit and display modes are tested separately.

### Description displays in the dialog but not after selection

The value-help provider has a display column, but the consumer field lacks a text relationship. Add a verified text element/association contract; do not add `#RESULT` solely as a display workaround.

## Required Validation

For every generated or reviewed pattern:

1. Activate consumer, provider, projection, and metadata extension in ADT.
2. Inspect Active Annotations for propagation and overrides.
3. Inspect service `$metadata` for text and value-list terms.
4. Test value-help opening, searching, selection, cancellation, and empty input.
5. Test every additional binding with populated and initial local values.
6. Verify result bindings write only intended fields.
7. Test ID/text rendering in list report, filter bar, object page display mode, and edit mode.
8. Test at least two logon languages for language-dependent text.
9. Run relevant ATC checks and authorization tests.

## Source References

- Projection views and provider contracts:
  https://help.sap.com/docs/abap-cloud/abap-data-models/cds-projection-views
- Provider-contract syntax and inheritance rules:
  https://help.sap.com/docs/abap-cloud/abap-keyword/cds-ddl-provider-contract
- Language-dependent text in projection views:
  https://help.sap.com/docs/abap-cloud/abap-rap/getting-language-dependent-text-in-projection-views
- Metadata extensions:
  https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abencds_meta_data_extensions.htm
- UI text arrangement:
  https://help.sap.com/docs/abap-cloud/abap-keyword/ui-textarrangement
- Value help with additional binding:
  https://help.sap.com/docs/abap-cloud/abap-rap/value-help-with-additional-binding
- ABAP Release 8.16 annotation documentation entry for `Consumption.valueHelpDefinition.additionalBinding.localElement`:
  https://help.sap.com/doc/abapdocu_816_index_htm/8.16/en-US/ABENCDS_274352458-_ANNO.html
- SAP Fiori elements field text and text arrangement guidance:
  Use the official Fiori elements documentation search for "Field Annotation Patterns" and "Display Text and ID for Value Help Input Fields" for the target OData/UI5 version.
- SAP annotation vocabulary definitions:
  https://github.com/SAP/odata-vocabularies

## Syntax Confidence

- `@Consumption.valueHelpDefinition` and `additionalBinding` syntax: **verified** against SAP Help.
- Projection provider-contract recommendation, deprecated omission, and inheritance exception: **verified** against SAP Help.
- Text element and text arrangement concepts: **verified** against SAP Fiori and ABAP annotation documentation.
- Full text-provider and association snippets: **partial**; activate and validate against the target ABAP release before production use.
