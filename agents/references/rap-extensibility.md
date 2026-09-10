# SAP RAP Extensibility - Clean Core Reference

Source baseline: SAP Help Portal, SAP Learning, SAP Community (2024)

## 1) What RAP Extensibility Is

RAP extensibility enables additive extension of existing RAP business objects without modifying original provider artifacts.

Core rule:
- Only add behavior and fields.
- Never remove or overwrite provider behavior.

## 2) Roles

- Original BO Provider: marks extensibility and releases C1 contract.
- Extension Developer: builds overlay extensions on released extension points.

## 3) Preconditions Before Any Extension

1. Base BO release status is C1.
2. Base BDEF is extensibility-enabled.
3. Only released APIs and artifacts are used.

If any precondition fails, stop and provide a compliant alternative.

## 4) Extension Points

- Data model extension: add custom fields through include/append extension.
- CDS extension: extend interface and projection view entities.
- Behavior extension: add determinations, validations, actions, additional save, feature control.
- Node extension: add child/association nodes when extension point allows.
- Service extension: expose added entities/fields via service definition extension.

Not allowed:
- Overwriting standard operations
- Removing provider fields/operations
- Using implicit enhancements or unreleased internals

## 5) Overlay Extension Flow

1. Identify released, extensible BO.
2. Extend active and draft persistence tables where draft is active.
3. Extend interface CDS and projection CDS.
4. Create behavior definition extension.
5. Generate and implement extension behavior class.
6. Extend service definition where needed.
7. Activate and test through service binding preview.
8. Run ATC released API and clean core checks.

## 6) BDEF Extension Pattern

```abap
extension using interface ZI_TravelOrder
  implementation in class ZCL_BP_EXT_TRAVELORDER unique;

extend behavior for TravelOrder {
  field (features : instance) ZZExternalRef, ZZCustomNote;

  determination setExternalRefDefault on modify { create; }
  validation validateExternalRef on save { field ZZExternalRef; create; update; }

  action submitForReview result [1] $self;
}
```

## 7) Behavior Implementation Guardrails

- Use READ ENTITIES and MODIFY ENTITIES in local mode.
- Capture and evaluate FAILED, REPORTED, and MAPPED for EML operations.
- Validations populate failed and reported with typed messages.
- Feature control requires both BDEF declaration and instance feature implementation.

## 8) Clean Core Level Target

Target Level A for all new extension work:
- Released APIs
- RAP extension points
- ABAP Cloud language restrictions

## 9) Common Failure Modes

- Extension artifact missing: base BO not extensible or not C1.
- Field not visible in UI: CDS extension or projection UI annotations inactive.
- Draft extension errors: active table extended but draft table not extended.
- Feature control inactive: field features not declared in BDEF extension.
- ATC findings: unreleased object consumption.
