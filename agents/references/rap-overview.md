# SAP RAP Architecture and Development Reference

Source baseline: SAP Help Portal RAP documentation

## 1) RAP Definition

RAP is the strategic ABAP programming model for HANA-optimized OData services in ABAP Cloud landscapes.

Target platforms:
- SAP BTP ABAP Environment
- SAP S/4HANA Cloud Public Edition
- SAP S/4HANA Cloud Private Edition with ABAP Cloud language version

## 2) Three-Layer Architecture

- Data and behavior layer: CDS entities, BDEF, behavior implementation
- Service provisioning layer: projection views, service definition, service binding
- Service consumption layer: Fiori Elements and API clients

## 3) Core Artifacts

- Interface CDS view entity (ZI_*)
- Projection CDS view entity (ZC_*)
- Metadata extension for UI annotations
- Behavior definition and behavior implementation class
- Service definition and service binding

## 4) End-to-End Build Flow

1. Database table
2. Interface CDS view entity
3. Projection CDS view entity
4. Metadata extension
5. Behavior definition
6. Behavior implementation class
7. Service definition
8. Service binding
9. Functional and contract tests

Read-only service path:
- Skip behavior definition and implementation.
- Expose CDS through service definition and binding.

## 5) Managed vs Unmanaged

Managed:
- Preferred for greenfield BOs.
- Framework handles persistence interaction, draft, and lifecycle plumbing.

Unmanaged:
- Use when legacy persistence and lifecycle logic must be preserved.
- Developer owns implementation details.

## 6) Mandatory RAP Quality Rules

- Use strict ( 2 ) for behavior definitions.
- Use lock master total etag LocalLastChangedAt on root entities.
- Use draft for transactional Fiori apps unless exception is justified.
- Determinations derive data; validations enforce invariants.
- EML handling must evaluate FAILED, REPORTED, and MAPPED.
- No COMMIT WORK in behavior handlers.

## 7) ADT Paths

- Database table: New > Other ABAP Repository Object > Dictionary > Database Table
- CDS data definition: New > Other ABAP Repository Object > Core Data Services > Data Definition
- Metadata extension: New > Other ABAP Repository Object > Core Data Services > Metadata Extension
- Behavior definition: Right click root CDS > New > Behavior Definition
- Behavior implementation class: BDEF > Quick Fix > Create behavior implementation class
- Service definition: Right click projection CDS > New > Service Definition
- Service binding: Right click service definition > New > Service Binding

## 8) Troubleshooting Quick Checks

- Service binding published, not only activated
- BDEF active before behavior implementation generation
- Data preview returns rows for root CDS
- Authorization checks and DCL behavior validated
- Entity aliases are consistent across CDS, BDEF, and EML

## 9) Example BDEF Skeleton

```abap
managed implementation in class ZCL_BP_TRAVELORDER unique;
strict ( 2 );
with draft;

define behavior for ZI_TravelOrder alias TravelOrder
persistent table ztravelorder
lock master total etag LocalLastChangedAt
authorization master ( global )
{
  create;
  update;
  delete;

  determination setDefaultStatus on modify { create; }
  validation validateStatus on save { field Status; create; update; }
  action approve result [1] $self;
}
```

## 10) Example EML Handling Template

```abap
MODIFY ENTITIES OF ZI_TravelOrder IN LOCAL MODE
  ENTITY TravelOrder
  UPDATE FIELDS ( Status )
  WITH lt_update
  MAPPED   DATA(ls_mapped)
  REPORTED DATA(ls_reported)
  FAILED   DATA(ls_failed).

IF ls_failed IS NOT INITIAL.
  failed-TravelOrder = CORRESPONDING #( BASE ( failed-TravelOrder ) ls_failed-TravelOrder ).
  reported-TravelOrder = CORRESPONDING #( BASE ( reported-TravelOrder ) ls_reported-TravelOrder ).
ENDIF.
```
