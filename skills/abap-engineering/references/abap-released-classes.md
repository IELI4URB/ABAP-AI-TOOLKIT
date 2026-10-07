---
name: abap-released-classes
description: 'Find released ABAP classes and interfaces for ABAP Cloud. Use for XCO, UUID, JSON/XML, HTTP destinations, application logs, strings, dates, regex, hashing, email, PDF, testing, and communication arrangements when released API evidence is required.'
---

# Released ABAP Classes

Search [the released-class catalog](./_legacy/abap-released-classes/references/released-classes-catalog.md) by capability. Prior examples are preserved in [the entry-point reference](./_legacy/abap-released-classes/references/released-classes-entrypoint-reference.md).

## Workflow

1. Establish landscape, release/FPS, and required capability.
2. Find candidate classes in the catalog.
3. Verify release contract and exact method signature in the target system or current SAP Help.
4. Inspect input/output types and exceptions before producing code.
5. Validate activation and behavior in the target release.

## Gates

- Catalog presence is a discovery hint, not proof of release in every target.
- Never infer C1 status from a class name.
- Prefer target-system API-state evidence and generated signatures.
- Mark unverified examples as draft and do not call them production-ready.

## Output

Return capability, recommended released API, verified target/release, contract summary, minimal usage outline, alternatives, and evidence.

