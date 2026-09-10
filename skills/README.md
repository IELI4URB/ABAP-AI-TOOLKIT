# Skills

Domain-knowledge files (`SKILL.md`, one per folder) loaded automatically by Copilot
or Claude Code when a request matches their `description`. They don't run code
themselves — they add grounding/guardrails/reference material to the agent's context
for that turn.

## How they behave

- **Loaded on demand, not always-on.** Each `SKILL.md` frontmatter has a `name` and
  `description`; the assistant matches your request against these descriptions and
  pulls in only the relevant ones, keeping context small.
- **Progressive disclosure.** The `SKILL.md` body is read first; if it links to a
  `references/*.md` file (deeper syntax tables, catalogs, checklists), that's only
  read when the assistant actually needs that level of detail.
- **Composable.** Multiple skills can apply to one request (e.g. implementing a
  Finance RAP service pulls in `sap-finance` for domain rules, `abap-cds-data-modeling`
  for the data model, and `abap-security-hardening` for auth), and the [`../agents/`](../agents/)
  explicitly reference which skills to use for which situations.

## Categories

**ABAP Cloud core / Clean Core**
`abap-clean-core-principles`, `abap-cds-data-modeling`, `abap-rap-behavior-implementation`,
`abap-api-design-versioning`, `abap-code-writing`, `abap-code-review-checklist`,
`clean-abap`, `abap-oops-design-patterns`

**Services & UI**
`abap-odata-service-development`, `abap-fiori-elements-annotations`,
`abap-events-and-enhancements`

**Performance**
`abap-performance-optimization`, `abap-performance-db` (ECC + HANA in one),
`abap-performance-ecc` / `abap-performance-hana` (installed separately by the
ABAP remote-fs extension, detect DB type first)

**Security & access**
`abap-security-hardening`, `abap-iam-authorization`

**Integration, jobs, workflow**
`abap-integration-patterns`, `abap-application-jobs`, `abap-workflow-automation`,
`abap-error-handling-resilience`

**Testing & delivery**
`abap-unit-testing`, `abap-sql-and-amdp`, `abap-devsecops-transport`,
`abap-git-workflows`, `abap-released-classes`

**Operations / troubleshooting**
`abap-production-issues`, `abap-research`, `sap-customizing`,
`sap-system-personality-report`, `sap-data-workbook`, `adt-api-discovery`

**End-to-end / quick-start**
`sap-clean-core-enterprise`, `sap-cloud-dev`

**Functional (SAP modules, not ABAP-Cloud-specific)**
`sap-pp`, `sap-mm`, `sap-sd`, `sap-finance`, `sap-tm`

**Meta / general-purpose**
`cavecrew` (multi-agent/subagent orchestration guidance),
`find-skills` (discover/install new skills)

## Behavior rules common to most skills

- Functional skills (`sap-pp`/`sap-mm`/`sap-sd`/`sap-finance`/`sap-tm`) are meant to
  be loaded **first** for domain-anchored requests, before the ABAP-technical skills.
- Performance skills require detecting the database type (HANA/S4 vs ECC/traditional)
  before applying guidance — the two branches give different, sometimes opposite,
  advice (pushdown vs minimize-round-trips).
- Several skills carry a `references/` subfolder with governance material
  (definition-of-done checklists, eligibility matrices, released-object catalogs)
  that's only pulled in for deeper, non-trivial requests.
