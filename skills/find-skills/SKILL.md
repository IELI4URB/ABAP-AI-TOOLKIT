---
name: find-skills
description: Discover and install relevant skills when users ask for capabilities, workflows, or specialized automation support.
triggers: find a skill, find skill, is there a skill, skill for, what skills, available skills, install skill, add skill, discover skill, skill catalog, skill library, skill search, how do I add capability, can Copilot do this, skill that can, skill recommendation, which skill, suggest a skill, skill registry, skills available
---

# Find Skills

Use this skill when the user asks for a way to do something that may already exist as an installable skill. Consult the catalogue below first before searching externally.

## Triggers

- "find a skill for X"
- "is there a skill that can..."
- "how do I add capability Y"
- "what skills are available"
- "which skill covers X"

## Skill Catalogue

### ABAP Cloud — Language & Development

| Skill | What it covers |
|---|---|
| `abap-clean-core-principles` | Clean Core rules, C1 contracts, release states, tier 1/2 wrapper pattern, ATC governance |
| `abap-cds-data-modeling` | CDS View Entities, projections, associations, compositions, annotations, metadata extensions |
| `abap-sql-and-amdp` | Full ABAP SQL syntax, window functions, FOR ALL ENTRIES, subqueries, AMDP, dynamic SQL |
| `abap-oops-design-patterns` | SOLID principles, Repository, Strategy, Factory, Decorator, Anti-Corruption Layer patterns |
| `abap-released-classes` | Catalog of 60+ released ABAP Cloud classes (XCO, BALI, HTTP, JSON, UUID, String, etc.) |
| `abap-git-workflows` | abapGit setup, cloning, branching, .abapgit.xml, CI/CD integration, gCTS vs abapGit |
| `abap-error-handling-resilience` | Exception class hierarchy, retry, circuit breaker, CL_BALI_LOG, structured error handling |
| `abap-performance-optimization` | N+1 elimination, CDS pushdown, pagination, table types, BFS/DFS, parallel cursor, caching |
| `abap-security-hardening` | Input validation, SQL injection prevention, secrets management, PII, audit trails |

### ABAP Cloud — RAP & Services

| Skill | What it covers |
|---|---|
| `abap-odata-service-development` | OData V2/V4, RAP service bindings, $filter/$expand/$batch, actions, ETags, pagination |
| `abap-api-design-versioning` | RAP service binding versioning, backward compatibility, deprecation policy, breaking changes |
| `abap-fiori-elements-annotations` | @UI annotations, list report, object page, value help, side effects, draft, metadata extensions |
| `abap-iam-authorization` | Authorization objects, AUTHORITY-CHECK, RAP auth master, CDS DCL, business roles, catalogs |
| `abap-integration-patterns` | HTTP REST (CL_WEB_HTTP_CLIENT_MANAGER), SOAP proxy, RFC wrapper, Communication Scenarios |
| `abap-events-and-enhancements` | RAISE ENTITY EVENT, Cloud BAdIs, Event Mesh, extension decision matrix |
| `abap-application-jobs` | IF_APJ_DT_EXEC_OBJECT, job catalog/template, scheduling, monitoring, background processing |
| `abap-workflow-automation` | Classic Workflow (SWDD), Flexible Workflow, SAP Build PA, approval patterns, agent determination |

### Architecture & Governance

| Skill | What it covers |
|---|---|
| `sap-clean-core-enterprise` | End-to-end Clean Core playbook, multi-skill orchestration, architecture-to-release governance |
| `abap-code-review-checklist` | 8-section review: Clean Core, RAP design, OOP quality, security, performance, testing, transport |
| `abap-unit-testing` | ABAP Unit, CL_ABAP_TESTDOUBLE, CL_OSQL_TEST_ENVIRONMENT, CDS doubles, RAP BO test doubles |
| `abap-devsecops-transport` | ATC governance, gCTS, cTMS, CI/CD pipeline, branch strategy, transport approval, rollback |
| `abap-production-issues` | 21 production issues: SQL dump, RAP/OData errors, AIF queue, job failure, lock, auth, transport |
| `sap-cloud-dev` | SAP BTP ABAP Environment setup, development toolchain, ADT, abapGit, cloud-specific patterns |

### SAP Domain Modules

| Skill | What it covers |
|---|---|
| `sap-finance` | FI: G/L, AP, AR, asset accounting, period close, reconciliation, payments, BKPF/BSEG/ACDOCA |
| `sap-mm` | MM: procurement, purchasing, inventory, goods movements, valuation, invoice verification |
| `sap-sd` | SD: sales orders, delivery, billing, pricing, ATP, partner determination, order-to-cash |
| `sap-tm` | TM: freight orders, transportation planning, carrier collaboration, charge calculation |
| `sap-pp` | PP: BOM, routing, MRP, production orders, PP/DS, capacity planning, KANBAN, repetitive mfg |

### Meta / Utilities

| Skill | What it covers |
|---|---|
| `find-skills` | This skill — discover what's available in the library |
| `cavecrew` | Subagent delegation patterns using the task tool (investigate / build / review) |

---

## Discovery Workflow

1. Check the catalogue above for the closest matching skill.
2. If multiple skills match, identify the primary (most specific) and secondary (supporting) skills.
3. Recommend the skill bundle: primary + any mandatory companions.
4. Provide first-use trigger examples.

## Recommendation Rules

- Always prefer the most specific skill over a general one.
- For ABAP Cloud work, `abap-clean-core-principles` is almost always a companion.
- For non-trivial features, recommend a bundle — single-skill responses are rarely sufficient.
- Flag if a required skill is missing from the library.

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. User intent and capability need
2. Matching skill(s) from catalogue
3. Recommended primary + companion bundle with rationale
4. First-use trigger examples
5. Any gaps — capabilities not covered by installed skills

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Specific SAP domain (FI/MM/SD/TM/PP) | Domain skill + abap-clean-core-principles |
| RAP / OData / Fiori | sap-rap-assistant or abap-odata-service-development |
| Code quality or review | abap-code-review-checklist + abap-oops-design-patterns |
| Production problem | abap-production-issues (21-issue guide) |
| Unknown capability | Catalogue scan → closest match |
