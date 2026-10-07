---
name: atq-principles
description: 'Apply SAP ATQ agentic engineering and solutioning governance to multi-step work. Use for planning, file edits, commands, subagent orchestration, requirements-to-code handoffs, architecture reviews, approval, recovery, validation, or ATQ compliance. Skip simple read-only questions.'
argument-hint: '[task or solution to govern or evaluate]'
user-invocable: true
disable-model-invocation: false
---

# ATQ Agentic Delivery

This skill is the sole process-governance owner. The full protocol is preserved in [the ATQ delivery reference](./atq-principles/references/atq-delivery-protocol.md); the source learning map is [here](./atq-principles/references/atq-learning-map.md).

## Operating Loop

1. Classify fast path versus governed workflow.
2. Record mode, phase, scope, input, output, approval, validation, and risk.
3. Resolve the controlling behavior and cheapest falsifying check before editing.
4. Decompose into one bounded, verifiable unit at a time.
5. Obtain bounded approval for destructive, production, security-sensitive, or scope-expanding actions.
6. Execute, observe, classify failure, and recover at the smallest boundary.
7. Preserve approved artefacts and hand off only complete phase outputs.

## Delegation

Give each agent one role, exact scope/exclusions, approved input, output contract, acceptance criteria, tool restrictions, and compact return format.

## Gates

- Do not duplicate ATQ catalogs in domain skills or agents.
- Load only current-phase context.
- Validate every substantive edit before broadening scope.
- Never infer approval for expanded or irreversible work.
- For formal compliance evaluation, load the full protocol and report evidence for every principle.

