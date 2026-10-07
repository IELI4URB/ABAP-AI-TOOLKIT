# Enterprise Architecture Playbook

The `abap-cloud-enterprise-architect` owns cross-system target architecture and final architecture trade-offs.

## Architecture Sequence

1. Confirm landscape, release/FPS, ABAP language version, business capability, owners, and NFRs.
2. Define system context, business-object ownership, data boundaries, and integration boundaries.
3. Select extension model and released contracts through `abap-cloud-governance`.
4. Define RAP/CDS/service contracts through `abap-rap-services` when applicable.
5. Define security, performance, integration, process automation, forms, and operational boundaries using only the required object groups.
6. Produce an implementation-ready Technical Specification Document (TSD).
7. Obtain explicit approval before implementation begins.

## Technical Specification Document

A non-trivial TSD contains:

1. Business context, scope, exclusions, and acceptance criteria
2. Target landscape, release, and language version
3. New and changed repository objects with purpose and ownership
4. Data model, keys, lifecycle, and relationships
5. Service/API contracts and compatibility
6. Authorization, trust, and sensitive-data design
7. Integration and failure semantics
8. Performance, volume, and concurrency assumptions
9. Test, activation, ATC, transport, operations, and rollback strategy
10. Risks, assumptions, dependencies, and open decisions

## Development Target Selection

After TSD approval, choose explicitly:

- **Connected system:** use the ADT MCP workflow guide inside `sap-system-operations`; use [the VS Code ADT fallback](vscode-adt-object-workflow.md) only when native tools are unavailable.
- **Local files:** generate reviewable files using the project's naming and folder conventions without creating SAP repository objects.

Do not infer the target. Confirm package, naming conventions, transport ownership, and object descriptions before connected-system creation.

## Acceptance Boundary

An architecture is not release-ready until the reviewer confirms:

- released-object and Clean Core evidence
- authorization and input-validation controls
- performance/volume strategy
- tests and ATC/readiness
- observability and operational ownership
- transport sequencing and rollback

Apply [syntax policy](syntax-policy.md), [shared guardrails](shared-guardrails.md), and [delivery gates](delivery-gates.md) without duplicating them in the design.
