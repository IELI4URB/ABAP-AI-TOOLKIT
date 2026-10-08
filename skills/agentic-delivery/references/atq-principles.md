---
name: atq-principles
description: 'Apply SAP ATQ agentic engineering and solutioning governance to multi-step work. Use for planning, file edits, commands, subagent orchestration, requirements-to-code handoffs, architecture reviews, approval, recovery, validation, or ATQ compliance. Skip simple read-only questions.'
argument-hint: '[task or solution to govern or evaluate]'
user-invocable: true
disable-model-invocation: false
---

# ATQ Agentic Delivery

This skill is the sole process-governance owner.

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

## ATQ Agentic Delivery Protocol

> **Reference:** Full wiki topic table with exact descriptions → `references/atq-learning-map.md`
> **Source:** wiki.one.int.sap — Agentic Engineering Learning Map · Author: Axel Janssen (D047951) · CIS FastForward, April 2026 · Status: Alpha/Draft

### Ownership Boundary

This skill is the single source of truth for ATQ agentic process governance.

- This skill owns agent operation, context control, approval, orchestration, recovery, artefact gates, and requirements-to-code handoff.
- ABAP and SAP skills own domain facts, architecture patterns, syntax, security, performance, testing, and release controls.
- Agent prompts route work and assign roles. They must reference this skill instead of copying its principles.
- Do not restate ATQ rules in domain skills. Combine outputs by reference.

### Activation Decision

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

### Operating State

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

### Risk-Based Approval

Treat approval as authorization for a bounded action set, not as permission for unrelated work.

| Risk | Examples | Required behavior |
|---|---|---|
| Low | Read-only inspection, search, diagnostics | Proceed within stated scope and summarize findings. |
| Medium | Reversible file edits explicitly requested, local tests | State scope and validation; proceed only when the request authorizes edits. |
| High | Deletion, deployment, transport, production data, secrets, broad refactor | Obtain explicit approval for the exact operation immediately before execution. |

Never infer approval for expanded scope. Never expose or request secrets through the model. Review generated changes before accepting them.

### ATQ 20 Engineering Principles

#### Foundations (1-4)

1. **Choose the interaction mode.** Declare manual, hybrid, or agentic work. Agentic work plans, acts, observes, and iterates.
2. **Run the agent loop.** Plan -> propose -> approve as required -> execute -> observe -> iterate.
3. **Use bounded approval.** Make scope, risk, reversibility, and the next validation visible. Do not rubber-stamp high-risk actions.
4. **Manage context deliberately.** Load only current-phase inputs. Compress completed work into the operating state. Re-scope when repetition, drift, or correction dominates execution.

#### Inspection and Planning (5-8)

5. **Inspect before acting.** Resolve the controlling behavior and cheapest falsifying check before editing.
6. **Scope context precisely.** Name files, folders, objects, systems, exclusions, and acceptance boundaries.
7. **Use disciplined prompts.** One objective per instruction, constraints first, explicit non-goals, and a verifiable outcome.
8. **Choose agent, manual, or hybrid execution.** Use agents for bounded search, repetitive work, and verification; use human judgment for ambiguous business rules and irreversible decisions.

#### Decomposition and Orchestration (9-12)

9. **Decompose into verifiable units.** Implement one behavior change at a time with one discriminating check.
10. **Isolate subtasks.** Give each subagent one role, bounded context, acceptance criteria, and a compact return contract.
11. **Use project configuration.** Store stable conventions, forbidden patterns, commands, and domain constraints in project instructions; keep them concise and avoid duplicating skills.
12. **Use disciplined version control.** One short-lived branch per task, small logical commits after validation, and diff review against intent before merge.

#### Failure and Recovery (13-15)

13. **Read generated diffs.** Check for five pathologies: unrelated edits, removed tests or comments, renamed symbols with broad blast radius, style churn hiding logic changes, duplicated logic.
14. **Classify failure before retrying.** Distinguish wrong scope, partial fix, unsupported API, excessive refactor, bad assumption, context overload, and environment failure.
15. **Recover at the smallest boundary.** Revert only owned changes, tighten constraints, restart with a compact state when context is polluted, and escalate to manual control when uncertainty remains.

#### Operational Fluency (16-20)

16. **Optimize safe operations.** Batch independent reads. Collapse repeated steps after 3+ successful repetitions. Reuse context when productive; restart when correcting more than executing.
17. **Graduate automation by evidence.** Begin read-only; allow reversible writes only with explicit scope and executable validation; never auto-approve destructive work.
18. **Skip formal planning only on the fast path.** Any unfamiliar, cross-file, contract, security, deletion, or production-impacting task requires a plan.
19. **Select capability deliberately.** Use stronger reasoning for requirements, architecture, ambiguity, and review; use faster execution for deterministic, well-specified operations.
20. **Maintain an operating protocol.** Document activation rules, safety invariants, approval boundaries, validation, and recovery for the project or team.

### ATQ 13 Solutioning Principles

#### Cross-Cutting (1-3)

1. **Control phase context.** Requirements use source material and stakeholder input; implementation uses approved design and only relevant code.
2. **Treat artefacts as deliverables.** Persist and version formal requirements, architecture, contracts, decisions, estimates, and plans when stakeholder handoff or multi-phase work requires them.
3. **Orchestrate phase by phase.** Requirements -> architecture -> module specifications -> interface contracts -> implementation plan -> code. Each phase consumes approved outputs from the prior phase.

#### Requirements Engineering (4)

4. **Structure requirements.** Produce named capabilities, acceptance criteria, constraints, scope boundaries, dependencies, non-functional requirements, and unresolved questions.

#### Specification (5-7)

5. **Freeze the reviewed specification.** Record approval and require an explicit amendment when downstream learning changes it.
6. **Decompose by capability.** Split large specifications into independently designable business capabilities or stories before defining code tasks.
7. **Verify artefacts against sources.** Check requirements, APIs, constraints, error paths, and assumptions against authoritative evidence before coding.

#### Stakeholder Artefacts (8-11)

8. **Deepen architecture progressively.** Lock system context, then modules, then interfaces; do not design lower levels on unstable boundaries.
9. **Lock contracts before implementation.** Define ownership, inputs, outputs, errors, compatibility, and non-functional constraints.
10. **Label concepts honestly.** Mark mockups, prototypes, demos, and generated examples as concepts until stakeholders approve commitment.
11. **Challenge architecture.** Run a separate critique for contradictions, missing interfaces, failure modes, operability, security, performance, and feasibility.

#### Estimation and Handoff (12-13)

12. **State estimation methodology.** Declare scope basis, dimensions, assumptions, uncertainty, exclusions, and how AI acceleration affects effort without hiding review cost.
13. **Separate design approval from code generation.** Generate the implementation plan from approved design; obtain PO or architect approval when applicable; then implement from that plan in a separate phase.

### Efficient Phase Gates

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

### Subagent Contract

Every delegated task must contain:

1. One role: investigator, designer, builder, or reviewer.
2. Exact scope and explicit exclusions.
3. Approved input artefact or factual context.
4. Expected output format and acceptance criteria.
5. Tool and write restrictions.
6. A compact result: findings, evidence, changes, validation, and unresolved risks.

Do not delegate the same decision to multiple agents unless performing an intentional independent challenge. Do not permit circular handoffs.

### Failure Protocol

1. Stop broadening the task.
2. Preserve evidence from the failed check.
3. Classify the failure using Principle 14.
4. Repair the same bounded unit when evidence supports the hypothesis.
5. If falsified, move one ownership boundary toward the controlling behavior.
6. If context is polluted, restart from the compact operating state and approved artefacts.
7. Escalate irreversible, security-sensitive, or unresolved domain decisions to a human owner.

### Red Flags

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

### Compliance Output

For an ATQ evaluation, report:

1. Scope, evidence, and assumptions.
2. Each of the 20 engineering principles: pass, partial, fail, or not applicable.
3. Each of the 13 solutioning principles: pass, partial, fail, or not applicable.
4. Red flags with concrete evidence.
5. Top remediation actions ordered by risk reduction.
6. Residual risks and accountable approval needed.

Do not convert missing evidence into a pass. Do not repeat domain review findings already owned by ABAP or SAP skills; reference those findings instead.

## ATQ Agentic Engineering — Learning Map Reference

**Source:** wiki.one.int.sap — Agentic Engineering Learning Map
**URL:** https://wiki.one.int.sap/wiki/spaces/developmentservices/pages/6384715751/Learning+Map
**Author:** Axel Janssen (D047951)
**Program:** CIS FastForward — AI Native Operating Model
**Status:** Alpha / Draft · Created April 2026

---

### ATQ 20 Core Agentic Engineering Principles

Full reference table. All 20 topics with official descriptions from wiki. All topics status: **Draft**.

| # | Topic | What's Behind It | Section |
|---|-------|-----------------|---------|
| 1 | Agentic vs. autocomplete vs. chat | Three categories of AI-assisted coding. Autocomplete is passive. Chat is Q&A. Agentic means the AI plans, acts on files, runs commands, and iterates autonomously. The distinction matters because agentic has consequences. | Foundations |
| 2 | The agent loop | Plan, propose, approve. Execute, observe, iterate. Your role is supervision and judgment. | Foundations |
| 3 | The approval gate | Every agent action requires your explicit approval. The cost of rubber-stamping: bugs, deleted code, destructive commands. | Foundations |
| 4 | Context window mechanics | The agent's working memory. When exceeded, the agent loses earlier context and makes mistakes. Context management has outsized impact on output quality. | Foundations |
| 5 | Inspect before you act | Before making changes, use read-only exploration to: identify relevant files, explain current behavior, surface assumptions, propose minimal edits, produce a file-level impact map. | Inspection & Planning |
| 6 | Context scoping | Deliberately controlling what the agent sees. Precise file/folder references vs. letting the agent discover on its own (expensive and unreliable). Signs of overload: repetition, drift, hallucination. | Inspection & Planning |
| 7 | Prompt discipline | Specific over vague. One task per instruction. Constraints up front. State what not to touch. The prompt is the work. | Inspection & Planning |
| 8 | Agent / manual / hybrid decision | Not every task benefits from the agent. Agent excels at: repetitive multi-file edits, boilerplate, test scaffolding, exploration. Manual excels at: surgical fixes, domain logic, performance-critical code. Hybrid often works best: agent drafts, you revise. | Inspection & Planning |
| 9 | Task decomposition | The core operational skill. Slice work into units small enough to verify and safe enough to approve. One behavior change at a time, inspect before edit, separate refactor from feature from bugfix, smallest verifiable step. | Decomposition & Orchestration |
| 10 | Multi-step orchestration | Coordinating complex workflows by delegating subtasks. Each runs in its own context, returns a summary. Known risk: information loss in handoffs. Start with two-subtask orchestrations before longer chains. | Decomposition & Orchestration |
| 11 | Project-level configuration | Persistent constraints the agent respects across conversations. Rules files, custom modes, team-shared config. Encodes naming conventions, forbidden patterns, domain rules. | Decomposition & Orchestration |
| 12 | Git discipline for agents | Commit after each verified step. Branch per task. Consider worktrees. Use git diff to review actual vs. intent. Never let more than one logical change accumulate without committing. | Decomposition & Orchestration |
| 13 | Reading AI-generated diffs | AI diffs hide problems differently than hand-written ones. Five pathologies: unrelated edits, deleted comments/tests, renamed symbols with broad blast radius, style churn hiding logic changes, duplicated logic. | Failures & Recovery |
| 14 | Failure diagnosis | Common failure modes: wrong file edited, partial fix that breaks tests, invented API usage (hallucinated methods), over-broad refactor, context overload producing incoherent output. | Failures & Recovery |
| 15 | Recovery strategies | Recognizing hallucinated code (check imports, verify signatures, run it). Git rollback to last good commit. Fresh conversation with better constraints. Escalating to manual work is judgment, not failure. | Failures & Recovery |
| 16 | Speed patterns | Batching safe read operations. Collapsing steps after 3+ successful repetitions. Context reuse vs. restart. If you're correcting more than executing, restart. | Operational Fluency |
| 17 | Controlled auto-approve | Graduating from full manual to selective automation. Start with read-only. Graduate to writes for well-understood, reversible operations with test coverage. | Operational Fluency |
| 18 | When to skip planning | Safe: you know the code, change is local, you've done it before, risk is low. Not safe: unfamiliar code, cross-file changes, deletion, you're unsure what "done" looks like. | Operational Fluency |
| 19 | Model selection as a lever | Not all tasks need the strongest model. Strong model for planning, faster model for routine execution. Cheaper models make more mistakes; the optimum depends on the task. | Operational Fluency |
| 20 | Personal operating protocol | One-page document: when you use the agent, when you don't, your default workflow, speed shortcuts, safety invariants, recovery procedure. The capstone: captures your individual methodology. | Operational Fluency |

> **Note:** All 20 topics are tool-agnostic in principle. Tool-specific syntax is flagged inline on the wiki where it differs.

---

### ATQ 13 Agentic Solutioning Principles

**Source page:** https://wiki.one.int.sap/wiki/spaces/developmentservices/pages/6148671667/Agentic+Solutioning

Solutioning is the pre-offer engagement work: turning customer input into something an implementation team can build, with effort estimates the offer team can stand behind.

> **Group count discrepancy:** The Learning Map page (6384715751) describes "three groups (requirements engineering, stakeholder artefacts, estimation and handoff)". The Agentic Solutioning page (6148671667) and the ATQ rubric both describe **five groups** (cross-cutting, requirements engineering, specification, stakeholder artefacts, estimation and handoff). The five-group breakdown is authoritative — it accounts for all 13 principles.

#### Cross-cutting (Principles 1–3)

| # | Principle | Description |
|---|-----------|-------------|
| 1 | Context management across phases | Load only relevant files per phase. Requirements phase: source material and stakeholder input only; no source code. Implementation phase: approved design and only relevant code. |
| 2 | Solutioning artefacts as deliverables | Persist and version formal requirements, architecture, contracts, decisions, estimates, and plans. Treated as formal deliverables, not intermediate notes. |
| 3 | Multi-phase orchestration | Full pipeline: requirements → architecture → module specifications → interface contracts → implementation plan → code. Each phase consumes approved outputs from the prior phase. |

#### Requirements Engineering (Principle 4)

| # | Principle | Description |
|---|-----------|-------------|
| 4 | Requirements structuring | Produce named capabilities with acceptance criteria, constraints, scope boundaries, dependencies, non-functional requirements, and unresolved questions. Ambiguous customer input is never passed directly to design. |

#### Specification (Principles 5–7)

| # | Principle | Description |
|---|-----------|-------------|
| 5 | Specification discipline | Spec written, reviewed against source material, FROZEN before design begins. Downstream changes require explicit amendment with approval record. |
| 6 | Specification decomposition | Large spec broken into independently designable business capabilities or stories before defining code tasks. |
| 7 | Artefact review discipline | Agent-produced specs/architecture verified against authoritative sources — not just plausibility. Hallucinated APIs, missing error paths, wrong constraints caught BEFORE coding. |

#### Stakeholder Artefacts (Principles 8–11)

| # | Principle | Description |
|---|-----------|-------------|
| 8 | Progressive architecture deepening | Level-by-level: system context → modules → interfaces. Each level locked before going deeper. Do not design lower levels on unstable boundaries. |
| 9 | Interface and contract locking | Module boundaries and API contracts (inputs, outputs, errors, compatibility, NFRs) frozen before implementation. Prevents design drift mid-build. |
| 10 | Stakeholder-artefact discipline | Mockups, prototypes, demos, and generated examples marked clearly as concepts until stakeholders approve commitment. Disclaimer enforced verbally. |
| 11 | Architecture challenge | Agent used to stress-test its own design: find contradictions, missing interfaces, failure modes, operability, security, performance, feasibility — before human review. |

#### Estimation and Handoff (Principles 12–13)

| # | Principle | Description |
|---|-----------|-------------|
| 12 | Estimation methodology | Declare scope basis, dimensions, assumptions, uncertainty, exclusions, and how AI compression affects effort. Methodology explicit — AI acceleration does not hide review cost. |
| 13 | Specification-to-implementation handoff | Implementation plan generated from approved design first. PO or Architect reviews and approves generated stories/design BEFORE handing to developer. Then code generated from plan in a separate phase. Blindly accepting LLM output = fail. |

---

### Related Wiki Pages

| Page | URL | Purpose |
|------|-----|---------|
| ATQ Hub | /spaces/developmentservices/pages/4862814085 | Entry point for ATQ governance |
| Agentic Engineering | /spaces/developmentservices/pages/6148671660 | Parent section, field reports, project setup |
| Learning Map | /spaces/developmentservices/pages/6384715751 | 20-topic curriculum (this doc's source) |
| Core Agentic Principles | /spaces/developmentservices/pages/6148671661 | Principles detail pages |
| Agentic Solutioning | /spaces/developmentservices/pages/6148671667 | 13 solutioning principles + handbook |
| ABAP Agentic Engineering Adoption | /spaces/developmentservices/pages/6384715750 | ABAP-specific guidance |
| CIS Agentic Toolkit | /spaces/developmentservices/pages/6384715749 | Claude Code plugin, SAP-compliant setup |
| ATQ Governance | /spaces/developmentservices/pages/4882480785 | Governance framework |
