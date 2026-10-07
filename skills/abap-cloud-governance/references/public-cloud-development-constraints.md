---
name: public-cloud-development-constraints
description: 'Apply SAP S/4HANA Public Cloud and BTP ABAP Environment constraints. Use for landscape eligibility, released-API requirements, ABAP language restrictions, extensibility boundaries, and Public Cloud delivery gates; route RAP, CDS, security, and implementation mechanics to their owning skills.'
---

# Public Cloud Development Constraints

Use this guide for focused Public Cloud constraints, not general RAP or CDS implementation. Prior guidelines are preserved in [the entry-point reference](./_legacy/sap-cloud-dev/references/entrypoint-reference.md).

## Workflow

1. Confirm S/4HANA Public Cloud or BTP ABAP Environment and exact release.
2. Verify released APIs, extensibility, package/language version, and service requirements.
3. Select CDS layers, RAP behavior, service definition/binding, authorization, and UI/API exposure.
4. Validate activation, metadata, tests, ATC/readiness, transport, and operations.

## Gates

No SAP modifications, unreleased dependencies, hidden commits, guessed annotations, or classic APIs in cloud-mode designs. Use focused CDS, RAP, OData, IAM, performance, and testing skills only as required by the current phase.

