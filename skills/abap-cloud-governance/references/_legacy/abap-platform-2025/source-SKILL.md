---
name: abap-platform-2025
description: >-
  Release-specific guidance for ABAP Platform 2025 in SAP S/4HANA Cloud Private Edition 2025 and SAP S/4HANA 2025 (SAP_BASIS 816). Covers clean core levels A-D, Joule for Developers, RAP 2025 features, CDS table entities, ADT improvements, ABAP language additions, HANA-centric data integration, embedded analytics, business events, Communication Targets, OData V4, HTTP/RFC outbound communication, key user extensibility, and security updates. Use when asked about ABAP Platform 2025, SAP_BASIS 816, S/4HANA 2025 ABAP features, 2025 FPS dependencies, collaborative draft, cross-BO RAP, CDS updatable views, Communication Targets, TLS 1.3, or upgrade capabilities.
argument-hint: Describe the ABAP Platform 2025 feature, landscape, and release/FPS level to assess.
metadata:
  version: 1.0.0
  tags: abap-platform-2025 sap-basis-816 s4hana-private-cloud rap cds adt clean-core connectivity security joule
---

# ABAP Platform 2025

Use this skill for release-specific analysis of ABAP Platform 2025. Combine it with domain skills such as `abap-clean-core-principles`, `abap-rap-behavior-implementation`, `abap-cds-data-modeling`, or `abap-integration-patterns` when implementation details are requested.

**Golden rule: a release overview proves that SAP announced a capability, not that the capability is installed, licensed, configured, released for ABAP Cloud, or available in every 2025 FPS.**

## Mandatory Reference

Before answering any feature, availability, migration, implementation, or architecture question, read:

- `references/verified-capabilities.md` - source ledger, exact capability inventory, cross-source wrapper guidance, prohibited inferences, and system-verification checklist.

Do not answer from the frontmatter description alone. The reference contains scope qualifiers that are intentionally omitted from the discovery description.

## Verified Baseline

The SAP-authored overview establishes these baseline facts:

- Target products: SAP S/4HANA Cloud Private Edition 2025 and SAP S/4HANA 2025.
- Platform component: `SAP_BASIS 816`.
- ABAP language release: ABAP Release 8.16.
- Database: SAP HANA only.
- Delivery: part of the S/4HANA products, not a standalone product.

These facts do not prove availability of an individual feature. Exact FPS/support package, frontend versions, release notes, prerequisites, configuration, entitlement, and API state still need verification.

## Evidence Hierarchy

Use evidence in this order:

1. The user's exact product, `SAP_BASIS`, FPS/support package, kernel, ADT, UI5/Fiori elements, and HANA versions.
2. A feature-specific ABAP Platform 2025 release-note entry with delivery date/FPS.
3. SAP Help with the target documentation version explicitly selected.
4. Relevant SAP Notes and the Product Availability Matrix.
5. API State in ADT/source or real compiler activation for the exact consumption mode.
6. The SAP Community release overview only as an announced-capability inventory.

Never use an unversioned/current SAP Help page as proof of initial-shipment or FPS01 availability.

## Availability Vocabulary

Use one of these labels when reporting a capability:

- `overview-confirmed`: stated in the SAP-authored Community overview only.
- `cross-source-confirmed`: supported by the overview and another named SAP source.
- `operationally verified`: checked for the user's exact system, FPS, prerequisites, API state, and configuration.
- `unverified`: not established by available evidence.

Do not use "available," "supported," or "production-ready" for an `overview-confirmed` capability without stating the missing checks.

## Key Boundary: Communication Targets and Wrappers

Communication Targets configure connectivity endpoints. They do not release a missing business API.

The API Enablement Guidelines version 3.0 state that SAP S/4HANA 2025 introduces Communication Target-based HTTP and RFC communication for ABAP Cloud and SOAP communication without the former provider wrapper. Therefore:

- Reassess a wrapper whose only purpose is destination/logical-port connectivity.
- Do not infer that Communication Targets replace a wrapper around an unreleased business object.
- Verify the exact FPS and released communication APIs before removing any wrapper.

## Syntax Grounding

For ABAP, CDS DDL, BDL/BDEF, EML, RAP annotations, or API examples:

1. Verify exact syntax in SAP Help or ABAP Keyword Documentation for ABAP Release 8.16 and the target FPS.
2. Verify every named SAP object and its release state for the intended consumption mode.
3. Do not derive syntax from a capability-summary sentence.
4. Do not provide final production code when exact syntax remains uncertain.

Syntax output contract:

- `Syntax confidence`: exactly `verified`, `partial`, or `draft`.
- `Syntax references`: exact SAP Help links used.
- `Verification required`: mandatory for `partial` or `draft`.

## Response Workflow

For ABAP Platform 2025 questions:

1. Read `references/verified-capabilities.md`.
2. Establish the product and landscape.
3. Confirm `SAP_BASIS 816` and exact FPS/support package.
4. Classify each claim with the availability vocabulary above.
5. Find the feature-specific release note and select the matching SAP Help version.
6. Verify relevant API state, frontend/backend versions, entitlement, activation, configuration, and authorization.
7. Explain clean-core impact and whether a verified 2025 mechanism replaces classic code or only a connectivity wrapper.
8. Provide a focused validation plan using activation, ATC, tests, traces, and relevant administration tools.
9. State unresolved evidence explicitly.

## Response Contract

For non-trivial requests, include:

1. Landscape and exact release/FPS assumptions.
2. Evidence status for each material capability claim.
3. Recommendation and clean-core impact.
4. Prerequisites and unsupported assumptions.
5. Validation steps.
6. Sources used.

Hard rules:

- Never invent SAP objects, APIs, CDS entities, annotations, transactions, feature names, or FPS assignments.
- Never infer API release state from naming or from this release overview.
- Preserve exact scope qualifiers such as `without draft`, `within a session`, and `cascading delete`.
- Treat the explicit `2025 FPS01` qualifier for SAP-managed client certificates as applying only to that item unless another source establishes otherwise.
- If feature-specific evidence cannot be found, stop at `overview-confirmed` and name the missing verification.
