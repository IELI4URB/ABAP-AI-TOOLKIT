---
name: quality-gates-and-transports
description: 'Govern ABAP Cloud delivery, ATC, transports, gCTS, cTMS, CI/CD, Cloud ALM, branches, approvals, rollback, emergency fixes, and waivers. Use for release pipelines and transport-readiness decisions.'
---

# ABAP Cloud Quality Gates and Transports

Load detailed controls from [the preserved entry-point reference](./_legacy/abap-devsecops-transport/references/entrypoint-reference.md) and the package reference files.

## Workflow

1. Establish landscape/account topology, transport mechanism, branch strategy, and release ownership.
2. Define build, test, ATC/readiness, security, approval, deployment, monitoring, and rollback gates.
3. Select gCTS, cTMS, classic transport, or hybrid based on verified landscape constraints.
4. Record waivers and emergency paths with owners, expiry, and remediation.

## Gates

Do not bypass P1/P2 findings, approval boundaries, cross-account controls, rollback planning, or post-deployment monitoring. Keep Git branching distinct from SAP transport/deployment state.

