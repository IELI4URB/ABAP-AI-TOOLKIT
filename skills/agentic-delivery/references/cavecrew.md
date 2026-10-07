---
name: cavecrew
description: Delegate bounded investigation, implementation, review, routing, and validation work to named custom agents while keeping the parent conversation concise. Use for subagent orchestration, parallel research, isolated code review, and long-session context control.
---

# Named-Agent Delegation

Use the available custom-agent invocation capability. Select a registered agent by exact name; do not assume an undocumented generic subagent API exists.

## Routing

| Need | Agent |
|---|---|
| Fast read-only repository exploration | `Explore` |
| ABAP Cloud feasibility and risk analysis | `abap-cloud-analyzer` |
| Enterprise architecture and implementation-ready design | `abap-cloud-enterprise-architect` |
| ABAP Cloud implementation | `abap-cloud-developer` |
| Findings-first ABAP Cloud review | `abap-cloud-reviewer` |
| Standard or legacy ABAP implementation | `abap-classic-developer` |
| ECC-to-S/4HANA migration | `abap-ecc-to-s4hana-migration` |
| Multi-phase routing and approval gates | `abap-cloud-routing-and-handoff` |

## Delegation Contract

Give each subagent:

1. One role and one objective.
2. Exact scope and explicit exclusions.
3. Known evidence and approved upstream artefacts.
4. Required output format and acceptance criteria.
5. Tool or write restrictions.
6. A compact return: findings, evidence, changes, validation, and unresolved risks.

Invoke independent read-only tasks in parallel when supported. Do not delegate the same implementation decision to multiple agents unless an independent challenge is intentional. The parent agent owns synthesis, edits, validation, and user-facing conclusions.

## Recovery

If a delegated result is incomplete, return only the missing contract items to the same agent. If its premise is falsified, route one ownership boundary closer to the controlling behavior. Avoid circular handoffs.

