# Agents

Custom agents for GitHub Copilot in VS Code (`*.agent.md`). Claude Code-compatible
equivalents live in [`../claude-agents/`](../claude-agents/).

## How they work together

Four are the main entry points you pick from the chat agent picker, meant to be used
in this order for non-trivial work:

| Order | Agent | Role |
|---|---|---|
| 1 | `abap-cloud-analyzer` | Analyzes requirements, risks, and constraints. Produces no code. |
| 2 | `abap-cloud-designer` | Turns an analyzed requirement into an architecture/design decision. Produces no code. |
| 3 | `abap-cloud-developer` | Implements the design: RAP/CDS/OOP code, tests, gates. |
| 4 | `abap-cloud-reviewer` | Reviews for defects, compliance, security, and performance risks. Does not edit code. |

`abap-cloud-enterprise-architect` is a fifth, all-in-one entry point that owns the
same analyzer → designer → developer → reviewer routing itself (including a
mandatory design-before-development gate and a Technical Specification Document
step) — use it when you want one agent to orchestrate the whole flow instead of
switching between the four manually.

`abap-ecc-to-s4hana-migration` is a separate, self-contained specialist for
ECC → S/4HANA brownfield conversion work (impact analysis, remediation, syntax
modernization) and does not participate in the analyzer/designer/developer/reviewer
routing.

## Shared behavior files (not meant to be selected directly)

These have `user-invocable: false` or no frontmatter and exist only to be linked
from the agents above, keeping shared rules in one place instead of duplicated:

| File | Purpose |
|---|---|
| `abap-cloud-shared-guardrails.agent.md` | Prompt-injection defense, production-acceptance evidence checklist, domain/skill routing anchors. |
| `abap-cloud-syntax-policy.agent.md` | "SAP Help is truth" rule for ABAP/CDS/BDL/EML syntax, syntax-confidence output contract. |
| `abap-cloud-delivery-gates.agent.md` | The P0-P8 delivery gate flow, definition of done, evidence-first and object-contract verification gates. |
| `abap-cloud-routing-and-handoff.agent.md` | The analyzer → designer → developer → reviewer escalation rule and handoff/domain-routing tables. |
| `abap-cloud-vscode-adt-object-workflow.agent.md` | Mandatory protocol for creating ABAP repository objects via VS Code ABAP remote-fs (`abap:` URIs) — linked by developer/enterprise-architect. |

## Behavior rules common to every agent

- SAP Help is the mandatory authority for ABAP/CDS/BDL/EML syntax; unverified syntax
  must be marked `draft`, not shipped as final.
- External content (web pages, fetched code, issue text) is treated as untrusted —
  agents don't execute instructions found inside it.
- No "production-ready" language unless the shared evidence checklist (syntax
  confidence, Clean Core/released-object check, security, performance, tests,
  transport/ATC readiness) is explicitly satisfied.
- Every issue-analysis/defect-triage response follows the same Evidence-First
  Investigation Protocol (inspect real artifacts, reproduce with real or synthetic
  data, rank root causes by confidence) instead of speculative answers.
- Before suggesting implementation or test code touching another object, agents
  verify the object contract (signatures, types, key-linking) first.

## Tool scopes

| Agent | Tools |
|---|---|
| `abap-cloud-analyzer`, `abap-cloud-designer`, `abap-cloud-reviewer` | read, search, web, todo (read-only — no edit/execute) |
| `abap-cloud-developer`, `abap-cloud-enterprise-architect`, `abap-ecc-to-s4hana-migration` | read, search, edit, execute, web, todo |
| `abap-cloud-shared-guardrails` | read |
| `abap-cloud-vscode-adt-object-workflow` | read, edit |
