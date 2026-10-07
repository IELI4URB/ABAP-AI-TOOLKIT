# Production Delivery Gates

Use this gate flow for delivery-oriented requests:
P0. Intake and constraints
- Confirm business objective, target landscape, ABAP language version, data volume, performance SLO, security sensitivity, and release window.
- Capture ownership, dependencies, and change window.

P1. Requirement decomposition and domain scoping
- Split into capabilities, aggregates, BO ownership, integrations, and non-functional requirements.

P2. Contract and API design
- Define service boundaries, versioning strategy, backward compatibility, and release sequencing.

P3. Security and compliance design
- Define auth model, data protection boundaries, and input contract validation.

P4. Build design and implementation
- Implement RAP/CDS/OOP artifacts with strict clean-core constraints.

P5. Performance and resilience hardening
- Eliminate N+1, enforce pushdown, add pagination or chunking, and classify failure handling.

P6. Operability and runtime automation
- Add application jobs, workflow integration, logging, monitoring, and observable runtime controls.

P7. Verification and quality gates
- Implement ABAP Unit, contract tests, ATC/readiness checks, and review gates.

P8. Release, transport, and rollback readiness
- Validate release gates, transport strategy, rollback plan, and handover evidence.

Design order of decisions:
1. Confirm landscape and ABAP language version.
2. Define business object and ownership boundaries.
3. Select extension approach.
4. Model data contracts in CDS layers.
5. Choose RAP implementation style.
6. Define authorization, validations, and transactional behavior.
7. Design performance strategy from day one.
8. Define test strategy.
9. Define operations strategy.
10. Define transport and rollback strategy.

Development-time gates:
- Gate D0 before coding: apply the code-review checklist constraints.
- Gate D1 on major artifacts: perform a performance check.
- Gate D2 on auth or input touchpoints: perform security and authorization checks.
- Gate D3 before merge: perform ABAP Unit, ATC, and transport-readiness checks.

Definition of done:
- Cloud compliance and released-object constraints are satisfied.
- Contracts are documented and backward compatibility is explicit.
- Security, authorization, and resilience are validated.
- Performance risks are assessed and mitigated.
- Tests are present and passing.
- ATC or readiness gates are green or waived with accepted risk.
- Operational runbook exists.

Forbidden recommendations:
- Unreleased object access in cloud-mode solutions.
- Modifying SAP standard code.
- Obsolete ABAP syntax.
- Hidden commits in RAP save flow.
- Non-testable or unobservable designs.
- RAP extensions on non-C1 or non-extensible providers.

## Shared Guardrail Dependency

Apply [shared guardrails](shared-guardrails.md) before evaluating this definition of done. The reviewer owns the final gate verdict.