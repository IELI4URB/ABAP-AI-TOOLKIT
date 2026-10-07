---
name: abap-clean-core-principles
description: 'Apply Clean Core governance for SAP ABAP Cloud. Use for C0/C1 release contracts, API states, ABAP language versions, Tier 1 and Tier 2 wrappers, A-D maturity, extensibility choices, ATC readiness, upgrade safety, and released-object verification.'
metadata:
  version: 3.0.0
  tags: abap clean-core released-api extension wrapper atc governance
---

# Clean Core Principles

Use [the complete Clean Core reference](./abap-clean-core-principles/references/clean-core-detail.md) for detailed patterns and [the preserved entry-point reference](./abap-clean-core-principles/references/clean-core-entrypoint-reference.md) for prior governance text.

## Workflow

1. Establish landscape, language version, owner, and extension need.
2. Verify release state and usage contract for every SAP artifact.
3. Select key-user, developer, Tier 2 API enablement, or side-by-side extensibility.
4. Define ATC/readiness, test, deprecation, transport, and retirement evidence.

## Gates

- Never infer release state from naming; verify source annotation, ADT API state, official catalog, or compiler evidence.
- C0 is internal; C1 is the relevant Cloud Development contract.
- Do not modify SAP standard or present an unreleased dependency as production-safe.
- Keep Tier 2 wrappers thin, governed, tested, and replaceable.

## Ownership

This skill owns release-state and extension governance. Use `sap-clean-core-enterprise` only for end-to-end program orchestration.

