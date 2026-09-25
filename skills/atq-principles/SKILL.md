---
name: atq-principles
description: 'Apply SAP ATQ agentic engineering and solutioning governance to multi-step work. Use for agentic planning, file edits, command execution, subagent orchestration, requirements-to-code handoffs, architecture reviews, recovery, or ATQ compliance checks. Skip simple read-only questions.'
argument-hint: '[task or solution to govern or evaluate]'
user-invocable: true
disable-model-invocation: false
---

# ATQ Agentic Delivery Protocol

> **Reference:** Full wiki topic table with exact descriptions → `references/atq-learning-map.md`
> **Source:** wiki.one.int.sap — Agentic Engineering Learning Map · Author: Axel Janssen (D047951) · CIS FastForward, April 2026 · Status: Alpha/Draft

## Ownership Boundary

This skill is the single source of truth for ATQ agentic process governance.

- This skill owns agent operation, context control, approval, orchestration, recovery, artefact gates, and requirements-to-code handoff.
- ABAP and SAP skills own domain facts, architecture patterns, syntax, security, performance, testing, and release controls.
- Agent prompts route work and assign roles. They must reference this skill instead of copying its principles.
- Do not restate ATQ rules in domain skills. Combine outputs by reference.

## Activation Decision

Load this skill when any condition is true:

- Work changes files, runs commands, deploys, transports, or modifies an external system.
- Work spans requirements, architecture, contracts, implementation, or review phases.
- Subagents or multiple skills are needed.
- A formal plan, estimate, stakeholder artefact, or implementation handoff is required.
- The user requests ATQ evaluation or agentic engineering compliance.

Use the fast path only when all conditions are true:

- The task is local, familiar, reversible, and low risk.
- Scope and expected result are unambiguous.
- No architecture, public contract, security boundary, destructive operation, or cross-system effect changes.
- One focused validation can falsify the result.

Simple explanation and read-only lookup tasks do not need the full protocol.

## Operating State

For non-trivial work, maintain this compact state instead of repeatedly loading prior detail:

```text
mode: manual | hybrid | agentic
phase: requirements | architecture | modules | contracts | plan | implementation | validation
scope: exact files, objects, systems, and exclusions
input: approved upstream artefact or user request
output: current phase deliverable
approval: not-needed | requested | granted
validation: next falsifying check
risk: low | medium | high
```

Update the state at phase transitions, scope changes, failures, and handoffs.

## Risk-Based Approval

Treat approval as authorization for a bounded action set, not as permission for unrelated work.

| Risk | Examples | Required behavior |
|---|---|---|
| Low | Read-only inspection, search, diagnostics | Proceed within stated scope and summarize findings. |
| Medium | Reversible file edits explicitly requested, local tests | State scope and validation; proceed only when the request authorizes edits. |
| High | Deletion, deployment, transport, production data, secrets, broad refactor | Obtain explicit approval for the exact operation immediately before execution. |

Never infer approval for expanded scope. Never expose or request secrets through the model. Review generated changes before accepting them.

## ATQ 20 Engineering Principles

### Foundations (1-4)

1. **Choose the interaction mode.** Declare manual, hybrid, or agentic work. Agentic work plans, acts, observes, and iterates.
2. **Run the agent loop.** Plan -> propose -> approve as required -> execute -> observe -> iterate.
3. **Use bounded approval.** Make scope, risk, reversibility, and the next validation visible. Do not rubber-stamp high-risk actions.
4. **Manage context deliberately.** Load only current-phase inputs. Compress completed work into the operating state. Re-scope when repetition, drift, or correction dominates execution.

### Inspection and Planning (5-8)

5. **Inspect before acting.** Resolve the controlling behavior and cheapest falsifying check before editing.
6. **Scope context precisely.** Name files, folders, objects, systems, exclusions, and acceptance boundaries.
7. **Use disciplined prompts.** One objective per instruction, constraints first, explicit non-goals, and a verifiable outcome.
8. **Choose agent, manual, or hybrid execution.** Use agents for bounded search, repetitive work, and verification; use human judgment for ambiguous business rules and irreversible decisions.

### Decomposition and Orchestration (9-12)

9. **Decompose into verifiable units.** Implement one behavior change at a time with one discriminating check.
10. **Isolate subtasks.** Give each subagent one role, bounded context, acceptance criteria, and a compact return contract.
11. **Use project configuration.** Store stable conventions, forbidden patterns, commands, and domain constraints in project instructions; keep them concise and avoid duplicating skills.
12. **Use disciplined version control.** One short-lived branch per task, small logical commits after validation, and diff review against intent before merge.

### Failure and Recovery (13-15)

13. **Read generated diffs.** Check for five pathologies: unrelated edits, removed tests or comments, renamed symbols with broad blast radius, style churn hiding logic changes, duplicated logic.
14. **Classify failure before retrying.** Distinguish wrong scope, partial fix, unsupported API, excessive refactor, bad assumption, context overload, and environment failure.
15. **Recover at the smallest boundary.** Revert only owned changes, tighten constraints, restart with a compact state when context is polluted, and escalate to manual control when uncertainty remains.

### Operational Fluency (16-20)

16. **Optimize safe operations.** Batch independent reads. Collapse repeated steps after 3+ successful repetitions. Reuse context when productive; restart when correcting more than executing.
17. **Graduate automation by evidence.** Begin read-only; allow reversible writes only with explicit scope and executable validation; never auto-approve destructive work.
18. **Skip formal planning only on the fast path.** Any unfamiliar, cross-file, contract, security, deletion, or production-impacting task requires a plan.
19. **Select capability deliberately.** Use stronger reasoning for requirements, architecture, ambiguity, and review; use faster execution for deterministic, well-specified operations.
20. **Maintain an operating protocol.** Document activation rules, safety invariants, approval boundaries, validation, and recovery for the project or team.

## ATQ 13 Solutioning Principles

### Cross-Cutting (1-3)

1. **Control phase context.** Requirements use source material and stakeholder input; implementation uses approved design and only relevant code.
2. **Treat artefacts as deliverables.** Persist and version formal requirements, architecture, contracts, decisions, estimates, and plans when stakeholder handoff or multi-phase work requires them.
3. **Orchestrate phase by phase.** Requirements -> architecture -> module specifications -> interface contracts -> implementation plan -> code. Each phase consumes approved outputs from the prior phase.

### Requirements Engineering (4)

4. **Structure requirements.** Produce named capabilities, acceptance criteria, constraints, scope boundaries, dependencies, non-functional requirements, and unresolved questions.

### Specification (5-7)

5. **Freeze the reviewed specification.** Record approval and require an explicit amendment when downstream learning changes it.
6. **Decompose by capability.** Split large specifications into independently designable business capabilities or stories before defining code tasks.
7. **Verify artefacts against sources.** Check requirements, APIs, constraints, error paths, and assumptions against authoritative evidence before coding.

### Stakeholder Artefacts (8-11)

8. **Deepen architecture progressively.** Lock system context, then modules, then interfaces; do not design lower levels on unstable boundaries.
9. **Lock contracts before implementation.** Define ownership, inputs, outputs, errors, compatibility, and non-functional constraints.
10. **Label concepts honestly.** Mark mockups, prototypes, demos, and generated examples as concepts until stakeholders approve commitment.
11. **Challenge architecture.** Run a separate critique for contradictions, missing interfaces, failure modes, operability, security, performance, and feasibility.

### Estimation and Handoff (12-13)

12. **State estimation methodology.** Declare scope basis, dimensions, assumptions, uncertainty, exclusions, and how AI acceleration affects effort without hiding review cost.
13. **Separate design approval from code generation.** Generate the implementation plan from approved design; obtain PO or architect approval when applicable; then implement from that plan in a separate phase.

## Efficient Phase Gates

Use the minimum gate that preserves correctness:

| Phase | Required output | Exit gate |
|---|---|---|
| Requirements | Capabilities, acceptance criteria, constraints, open questions | Stakeholder confirms intent. |
| Architecture | Boundaries, data flow, decisions, risks | Architect or accountable owner approves direction. |
| Modules | Responsibilities and dependencies | Coverage and ownership are complete. |
| Contracts | Inputs, outputs, errors, compatibility, NFRs | Interfaces are reviewed and stable. |
| Plan | Ordered, verifiable implementation units | Each unit has scope and validation. |
| Implementation | Small reviewed changes | Focused checks pass after each unit. |
| Validation | Tests, review findings, residual risks | Acceptance criteria and release gates pass. |

For fast-path work, combine the first five phases into a short scope statement, but retain implementation and validation as separate steps.

## Subagent Contract

Every delegated task must contain:

1. One role: investigator, designer, builder, or reviewer.
2. Exact scope and explicit exclusions.
3. Approved input artefact or factual context.
4. Expected output format and acceptance criteria.
5. Tool and write restrictions.
6. A compact result: findings, evidence, changes, validation, and unresolved risks.

Do not delegate the same decision to multiple agents unless performing an intentional independent challenge. Do not permit circular handoffs.

## Failure Protocol

1. Stop broadening the task.
2. Preserve evidence from the failed check.
3. Classify the failure using Principle 14.
4. Repair the same bounded unit when evidence supports the hypothesis.
5. If falsified, move one ownership boundary toward the controlling behavior.
6. If context is polluted, restart from the compact operating state and approved artefacts.
7. Escalate irreversible, security-sensitive, or unresolved domain decisions to a human owner.

## Red Flags

- Direct AI Core API usage where approved SAP routing is required.
- MTA or authorization configuration generated without authoritative CAP context and validation.
- Work Zone integration claimed without navigation validation.
- Oversized or missing project-level agent instructions.
- Missing prompt or decision trace when evaluation requires reproducibility.
- One-shot generation of an entire application.
- Mid-task scope switching before the active unit is complete.
- Generated stories or design accepted without accountable review.
- Missing automated lint, test, build, or activation checks after generation.
- Skipping requirements, specification, and design for non-fast-path work.

## Compliance Output

For an ATQ evaluation, report:

1. Scope, evidence, and assumptions.
2. Each of the 20 engineering principles: pass, partial, fail, or not applicable.
3. Each of the 13 solutioning principles: pass, partial, fail, or not applicable.
4. Red flags with concrete evidence.
5. Top remediation actions ordered by risk reduction.
6. Residual risks and accountable approval needed.

Do not convert missing evidence into a pass. Do not repeat domain review findings already owned by ABAP or SAP skills; reference those findings instead.