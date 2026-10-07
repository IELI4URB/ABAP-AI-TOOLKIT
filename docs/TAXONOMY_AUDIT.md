# Skill and Agent Taxonomy Audit

## Scope and Method

This audit rates the registered skill groups and toolkit-managed agents. Immutable source snapshots under `references/_legacy/` are integrity evidence, not active skills, and are therefore outside the rating scope.

Scores combine naming clarity, ownership separation, discoverability, progressive loading, and maintenance safety.

## Skill Ratings

| Registered skill | Score | Ownership assessment |
|---|---:|---|
| `abap-cloud-governance` | 9.5/10 | Clear owner for release contracts, landscape constraints, Clean Core, quality gates, transports, and Git delivery. |
| `abap-data-performance` | 9.3/10 | Clear owner for SQL/AMDP and performance; engineering owns non-performance language semantics. |
| `abap-engineering` | 9.4/10 | Clear owner for ABAP construction, language mechanics, OOP, tests, and code review. |
| `abap-forms` | 9.3/10 | Narrow and unambiguous Adobe Forms/PDF output scope. |
| `abap-integration` | 9.3/10 | Clear owner for connectivity and remote/operational resilience, not general exception syntax. |
| `abap-process-automation` | 9.4/10 | Clean split between background jobs and approval/workflow automation. |
| `abap-rap-services` | 9.5/10 | Comprehensive RAP/CDS/OData/UI/API owner with explicit companion boundaries. |
| `abap-security` | 9.4/10 | Clear IAM/authorization and hardening split, with official DCL semantics. |
| `agentic-delivery` | 9.1/10 | Clear execution-governance owner and explicit skip rule for simple work. |
| `sap-business-domains` | 9.4/10 | Clear functional ownership across FI, MM, PP/DS, SD, and TM. |
| `sap-system-operations` | 9.3/10 | Clear real-system investigation, discovery, ADT, Basis, and Customizing ownership. |

**Overall skill taxonomy: 9.4/10.**

## Agent Ratings

| Managed agent | Score | Exclusive role |
|---|---:|---|
| `abap-cloud-routing-and-handoff` | 9.3/10 | Orchestration and phase handoff; no domain decisions or implementation. |
| `abap-cloud-analyzer` | 9.4/10 | Pre-design feasibility, evidence gaps, constraints, and risks. |
| `abap-cloud-enterprise-architect` | 9.6/10 | Target architecture, cross-system boundaries, NFRs, and implementation blueprint. |
| `abap-cloud-developer` | 9.5/10 | ABAP Cloud implementation and executable validation. |
| `abap-cloud-reviewer` | 9.5/10 | Independent findings-first review and release verdict. |
| `abap-classic-developer` | 9.4/10 | Standard ABAP implementation for ECC and on-premise ownership. |
| `abap-ecc-to-s4hana-migration` | 9.4/10 | Migration impact, remediation, and HANA adaptation. |

The SAP ADT extension may additionally contribute `abap-developer`. It is external to this toolkit and is not included in the managed-agent score.

## Structural Proof

- One registered `SKILL.md` per group.
- One `references/README.md` ownership index per group.
- Active guides are direct Markdown files under `references/`.
- Integrity source snapshots live only under `references/_legacy/`.
- Zero active guide/directory basename collisions.
- Validators enforce group counts, ownership indexes, archive sets, hashes, links, and agent topology.
