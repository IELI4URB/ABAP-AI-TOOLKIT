---
name: sap-clean-core-enterprise
description: 'Orchestrate end-to-end SAP ABAP Clean Core solution architecture and release governance across S/4HANA Public Cloud, Private Cloud ABAP Cloud, and BTP ABAP Environment, including extensions, C1 APIs, ATC, tests, operations, transport, and residual risk.'
---

# SAP Clean Core Enterprise

Use this skill only for end-to-end, cross-phase solutioning. Prior governance is preserved in [the entry-point reference](./references/entrypoint-reference.md).

## Workflow

1. Classify landscape, ownership, capabilities, NFRs, and extension boundaries.
2. Route one active phase at a time through requirements, architecture, contracts, implementation, validation, and release.
3. Keep the applicable domain skill primary and load no more than two technical companions per phase.
4. Require released-object, security, performance, test, ATC, operations, transport, and rollback evidence before release.

## Boundary

Use `abap-clean-core-principles` for focused release-state or extension questions. Do not load this enterprise orchestrator as a blanket companion to analyzer, designer, developer, or reviewer agents.
