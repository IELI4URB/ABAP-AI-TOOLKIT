# ATQ Agentic Engineering — Learning Map Reference

**Source:** wiki.one.int.sap — Agentic Engineering Learning Map
**URL:** https://wiki.one.int.sap/wiki/spaces/developmentservices/pages/6384715751/Learning+Map
**Author:** Axel Janssen (D047951)
**Program:** CIS FastForward — AI Native Operating Model
**Status:** Alpha / Draft · Created April 2026

---

## ATQ 20 Core Agentic Engineering Principles

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

## ATQ 13 Agentic Solutioning Principles

**Source page:** https://wiki.one.int.sap/wiki/spaces/developmentservices/pages/6148671667/Agentic+Solutioning

Solutioning is the pre-offer engagement work: turning customer input into something an implementation team can build, with effort estimates the offer team can stand behind.

> **Group count discrepancy:** The Learning Map page (6384715751) describes "three groups (requirements engineering, stakeholder artefacts, estimation and handoff)". The Agentic Solutioning page (6148671667) and the ATQ rubric both describe **five groups** (cross-cutting, requirements engineering, specification, stakeholder artefacts, estimation and handoff). The five-group breakdown is authoritative — it accounts for all 13 principles.

### Cross-cutting (Principles 1–3)

| # | Principle | Description |
|---|-----------|-------------|
| 1 | Context management across phases | Load only relevant files per phase. Requirements phase: source material and stakeholder input only; no source code. Implementation phase: approved design and only relevant code. |
| 2 | Solutioning artefacts as deliverables | Persist and version formal requirements, architecture, contracts, decisions, estimates, and plans. Treated as formal deliverables, not intermediate notes. |
| 3 | Multi-phase orchestration | Full pipeline: requirements → architecture → module specifications → interface contracts → implementation plan → code. Each phase consumes approved outputs from the prior phase. |

### Requirements Engineering (Principle 4)

| # | Principle | Description |
|---|-----------|-------------|
| 4 | Requirements structuring | Produce named capabilities with acceptance criteria, constraints, scope boundaries, dependencies, non-functional requirements, and unresolved questions. Ambiguous customer input is never passed directly to design. |

### Specification (Principles 5–7)

| # | Principle | Description |
|---|-----------|-------------|
| 5 | Specification discipline | Spec written, reviewed against source material, FROZEN before design begins. Downstream changes require explicit amendment with approval record. |
| 6 | Specification decomposition | Large spec broken into independently designable business capabilities or stories before defining code tasks. |
| 7 | Artefact review discipline | Agent-produced specs/architecture verified against authoritative sources — not just plausibility. Hallucinated APIs, missing error paths, wrong constraints caught BEFORE coding. |

### Stakeholder Artefacts (Principles 8–11)

| # | Principle | Description |
|---|-----------|-------------|
| 8 | Progressive architecture deepening | Level-by-level: system context → modules → interfaces. Each level locked before going deeper. Do not design lower levels on unstable boundaries. |
| 9 | Interface and contract locking | Module boundaries and API contracts (inputs, outputs, errors, compatibility, NFRs) frozen before implementation. Prevents design drift mid-build. |
| 10 | Stakeholder-artefact discipline | Mockups, prototypes, demos, and generated examples marked clearly as concepts until stakeholders approve commitment. Disclaimer enforced verbally. |
| 11 | Architecture challenge | Agent used to stress-test its own design: find contradictions, missing interfaces, failure modes, operability, security, performance, feasibility — before human review. |

### Estimation and Handoff (Principles 12–13)

| # | Principle | Description |
|---|-----------|-------------|
| 12 | Estimation methodology | Declare scope basis, dimensions, assumptions, uncertainty, exclusions, and how AI compression affects effort. Methodology explicit — AI acceleration does not hide review cost. |
| 13 | Specification-to-implementation handoff | Implementation plan generated from approved design first. PO or Architect reviews and approves generated stories/design BEFORE handing to developer. Then code generated from plan in a separate phase. Blindly accepting LLM output = fail. |

---

## Related Wiki Pages

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
