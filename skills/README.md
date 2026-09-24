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

## Skills in this repository

* [`abap-api-design-versioning`](abap-api-design-versioning/) - API design and versioning for SAP ABAP Cloud RAP services, including service binding versions, backward compatibility, deprecation policy, and versioned DTOs.
* [`abap-application-jobs`](abap-application-jobs/) - Application Jobs architecture and operations for SAP ABAP Cloud, including catalogs, templates, scheduling, parameters, error handling, and monitoring.
* [`abap-cds-data-modeling`](abap-cds-data-modeling/) - CDS data modeling for ABAP Cloud, including view entities, projections, associations, compositions, annotations, metadata extensions, and DCL roles.
* [`abap-clean-core-principles`](abap-clean-core-principles/) - Clean Core principles and governance for SAP ABAP Cloud, including release states, language versions, wrapper patterns, extensibility, and ATC governance.
* [`abap-code-review-checklist`](abap-code-review-checklist/) - Development and review checks for ABAP Cloud covering naming, RAP, architecture, security, performance, testing, operability, and transport readiness.
* [`abap-code-writing`](abap-code-writing/) - A structured process for building ABAP solutions, from requirements and system exploration through design, implementation, formatting, and unit-test doubles.
* [`abap-devsecops-transport`](abap-devsecops-transport/) - DevSecOps and transport governance for ABAP Cloud, covering delivery pipelines, ATC, gCTS, Cloud Transport Management, approvals, rollback, and waivers.
* [`abap-error-handling-resilience`](abap-error-handling-resilience/) - Error handling and resilience patterns for ABAP Cloud, including exceptions, retries, circuit breakers, application logs, RAP messages, and observability.
* [`abap-events-and-enhancements`](abap-events-and-enhancements/) - RAP business events, Cloud BAdIs, and guidance for choosing among events, BAdIs, BDEF extensions, and CDS extensions.
* [`abap-fiori-elements-annotations`](abap-fiori-elements-annotations/) - CDS-type-aware Fiori Elements guidance for interface and projection views, value-help and text providers, metadata extensions, dependent bindings, and ID/text display.
* [`abap-git-workflows`](abap-git-workflows/) - ABAP development with abapGit, including setup, cloning, branching, configuration, transport-versus-Git workflows, and CI/CD integration.
* [`abap-iam-authorization`](abap-iam-authorization/) - IAM and authorization architecture for ABAP Cloud, covering authorization objects, RAP authorization, DCL, business roles, restrictions, catalogs, and privileges.
* [`abap-integration-patterns`](abap-integration-patterns/) - ABAP Cloud integration patterns for HTTP REST, SOAP, RFC wrappers, communication arrangements, Event Mesh, AIF, and remote-call error handling.
* [`abap-odata-service-development`](abap-odata-service-development/) - OData V2 and V4 development for ABAP Cloud and on-premise, including RAP, SEGW, query options, deep operations, ETags, errors, and pagination.
* [`abap-oops-design-patterns`](abap-oops-design-patterns/) - OOP principles and patterns for ABAP Cloud, including SOLID, Repository, Strategy, Factory, Application Service, Domain Events, and RAP integration.
* [`abap-performance-db`](abap-performance-db/) - ABAP database performance guidance for traditional databases and HANA, covering buffering, SQL pushdown, CDS, AMDP, internal tables, and parallel processing.
* [`abap-performance-optimization`](abap-performance-optimization/) - ABAP Cloud performance optimization covering N+1 elimination, CDS pushdown, pagination, projections, filtering, caching, indexing, and graph traversal.
* [`abap-platform-2025`](abap-platform-2025/) - Release-specific ABAP Platform 2025 guidance for SAP S/4HANA Cloud Private Edition and SAP S/4HANA, including FPS-aware RAP, CDS, ADT, connectivity, security, and Clean Core capabilities.
* [`abap-production-issues`](abap-production-issues/) - Production issue diagnosis for ABAP development across SQL, RAP/OData, AIF/HTTP, jobs, locks, authorization, transports, and Clean Core governance.
* [`abap-rap-behavior-implementation`](abap-rap-behavior-implementation/) - RAP behavior implementation mechanics covering behavior pools, handlers, method categories, failed and reported structures, messages, prechecks, and numbering.
* [`abap-released-classes`](abap-released-classes/) - A categorized quick reference to more than 50 released ABAP Cloud classes with ready-to-use examples.
* [`abap-research`](abap-research/) - Techniques for finding SAP transactions, programs, function modules, classes, errors, BAPIs, tables, custom objects, and unfamiliar functionality.
* [`abap-security-hardening`](abap-security-hardening/) - Security hardening for ABAP Cloud, covering validation, SQL injection prevention, RAP authorization, secrets, sensitive data, auditing, hashing, and encoding.
* [`abap-sql-and-amdp`](abap-sql-and-amdp/) - ABAP SQL and AMDP reference covering data modification, aggregations, subqueries, window functions, dynamic SQL, FOR ALL ENTRIES, and CDS table functions.
* [`abap-unit-testing`](abap-unit-testing/) - ABAP Unit practices for ABAP Cloud, covering test pyramids, mocks, SQL/CDS/RAP doubles, isolation, risk and duration semantics, CI/CD, and coverage.
* [`abap-workflow-automation`](abap-workflow-automation/) - Workflow automation for ABAP Cloud, covering Classic Workflow, Flexible Workflow, SAP Build Process Automation, approvals, and RAP integration.
* [`adt-api-discovery`](adt-api-discovery/) - Investigation of SAP ADT REST endpoints through discovery documents, application and handler classes, transformations, and XML schemas.
* [`adt-mcp-object-workflow`](adt-mcp-object-workflow/) - Controlled creation, population, activation, and testing of ABAP repository objects through the configured SAP ADT MCP server.
* [`cavecrew`](cavecrew/) - Guidance for spawning focused subagents for investigation, implementation, and review while compressing context and enabling parallel work.
* [`clean-abap`](clean-abap/) - Clean ABAP standards for writing, reviewing, and refactoring code, including naming, modern syntax, design, errors, formatting, comments, and tests.
* [`find-skills`](find-skills/) - Guidance for discovering and installing skills that provide specialized capabilities, workflows, and automation support.
* [`sap-clean-core-enterprise`](sap-clean-core-enterprise/) - End-to-end ABAP Clean Core guidance for S/4HANA Public Cloud, S/4HANA Private Cloud, and SAP BTP ABAP Environment.
* [`sap-cloud-dev`](sap-cloud-dev/) - SAP Public Cloud ABAP development guidance for Clean Core, RAP, CDS, BTP ABAP Environment, service layers, naming, and BDEFs.
* [`sap-customizing`](sap-customizing/) - Guidance for navigating SAP Customizing, SPRO, IMG activities, configuration tables, maintenance views, view clusters, and customizing data.
* [`sap-data-workbook`](sap-data-workbook/) - Creation of SAP Data Workbooks for reproducible analysis, data-quality checks, reports, comparisons, profiling, and multi-step exploration.
* [`sap-finance`](sap-finance/) - SAP Finance guidance covering general ledger, payables, receivables, assets, closing, tax, payments, reconciliation, and ABAP solution design.
* [`sap-mm`](sap-mm/) - SAP Materials Management guidance covering procurement, purchasing, inventory, valuation, source determination, goods movements, suppliers, and ABAP solution design.
* [`sap-pp`](sap-pp/) - SAP Production Planning and PP/DS guidance covering BOMs, routings, work centers, MRP, orders, KANBAN, manufacturing, capacity, and ABAP solution design.
* [`sap-sd`](sap-sd/) - SAP Sales and Distribution guidance covering quotations, sales orders, deliveries, billing, pricing, ATP, partners, output, and ABAP solution design.
* [`sap-system-personality-report`](sap-system-personality-report/) - Generation of a system report covering custom code, functional footprint, development activity, health metrics, and package structure.
* [`sap-tm`](sap-tm/) - SAP Transportation Management guidance covering freight orders, freight units, planning, carriers, charge calculation, execution tracking, and ABAP solution design.

## Categories

**ABAP Cloud core / Clean Core**
`abap-clean-core-principles`, `abap-cds-data-modeling`, `abap-rap-behavior-implementation`,
`abap-api-design-versioning`, `abap-code-writing`, `abap-code-review-checklist`,
`clean-abap`, `abap-oops-design-patterns`

**Release-specific platform guidance**
`abap-platform-2025` (SAP S/4HANA Cloud Private Edition 2025 and SAP S/4HANA
2025, `SAP_BASIS 816`; requires feature/FPS verification before use)

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
`sap-system-personality-report`, `sap-data-workbook`, `adt-api-discovery`,
`adt-mcp-object-workflow`

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
