---
name: abap-oops-design-patterns
description: >-
  OOP design principles and design patterns for SAP ABAP Cloud. Covers SOLID principles with decision matrices, Repository, Strategy, Factory, Application Service, Anti-Corruption Layer, Domain Events (RAP Business Events), Decorator patterns, RAP integration guidance (where patterns fit in BDEF lifecycle), YAGNI warnings, and ABAP Cloud OOP restrictions. Triggers: OOP, SOLID, design pattern, repository, strategy, factory, dependency injection, interface, SRP, OCP, LSP, ISP, DIP, decorator, anti-corruption, domain event, god class, clean code, testability, composition.
metadata:
  version: 2.0.0
  tags: abap oop solid design-patterns clean-code abap-cloud testability dependency-injection
---

# OOP Design Principles and Design Patterns for ABAP Cloud

Expert guide for applying object-oriented design that improves maintainability, testability, and upgrade safety in ABAP Cloud.

**Golden rule: Always start with the decision matrix. Know WHEN and WHY before writing code. Patterns serve testability — if you can't test it, your design is wrong.**

Reference files:
- `references/solid-principles.md` — SOLID deep dive with SAP code examples
- `references/design-patterns.md` — all patterns with decision matrix and implementations

## SAP Help Syntax Grounding (Mandatory)

For ABAP/CDS/BDL/EML syntax, use SAP Help as source of truth.

Rules:
- Do not provide unverified syntax for ABAP statements, CDS DDL, behavior definitions, EML, or RAP annotations/options.
- For non-trivial syntax responses, add a short "Syntax references" section with SAP Help links used.
- If exact syntax is uncertain, explicitly mark it as draft and require SAP Help verification.
- Never invent statement additions, annotation names, or behavior options.

Core SAP Help references:
- https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/cbb86e63a8464e63bbdd43b7bfa5fc4f.html
- https://help.sap.com/docs/ABAP_Cloud/bbcee501b99848bdadecd4e290db3ae4/404edb8b4c0648dca4d8f5a2fdfa6c58.html
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/c35896101f8c417482fd040d477bbbe1.html

Syntax verification steps:
1. Validate keywords and clause names against ABAP Keyword Documentation terminology.
2. Validate RAP strict mode and BDEF/BDL constructs against RAP docs.
3. Validate CDS form and annotation usage against CDS docs.
4. Validate EML operation form and response handling pattern.
5. Reconfirm clean-core and released-object constraints.
Syntax output contract (mandatory when providing ABAP/CDS/BDL/EML syntax):
1. Add `Syntax confidence` with exactly one value: `verified`, `partial`, or `draft`.
2. Add `Syntax references` with SAP Help links for each non-trivial syntax area used.
3. If confidence is `partial` or `draft`, add `Verification required` with unresolved syntax items.
4. Do not provide final production code when confidence is `draft`.


---

## ABAP Cloud OOP Constraints

| Feature | Status | Guidance |
|---|---|---|
| `FINAL` keyword | Available, RECOMMENDED | Make classes FINAL by default |
| `FRIEND` | Available but DISCOURAGED | Use interfaces + DI instead |
| `ABSTRACT` classes | Available | Prefer interfaces for extension contracts |
| `CREATE PRIVATE` | Available | Use for Factory pattern (static create method) |
| `COMMIT WORK` in RAP | FORBIDDEN (runtime error) | Use `COMMIT ENTITIES` only |
| `NEW zcl_concrete( )` | Available but violates DIP | Inject via constructor |
| `CL_ABAP_TESTDOUBLE` | Released (interfaces only) | Primary mocking framework |

---

## Pattern Selection Decision Matrix

| Requirement | Pattern | Skip when |
|---|---|---|
| Hide persistence from domain | **Repository** | Trivial single-table CRUD |
| Multiple algorithms by context | **Strategy** | Only 1 algorithm ever |
| Complex object creation | **Factory** | Simple 1-2 field constructor |
| Orchestrate 3+ operations | **Application Service** | 1-2 services only |
| Shield from external API | **Anti-Corruption Layer** | API stable and yours |
| React to BO state change | **RAP Business Event** | Sync acceptable |
| Extend behavior without modify | **Decorator** | One-time logic |

---

## RAP Integration: Where Patterns Live

| RAP Phase | Pattern Used | Example |
|---|---|---|
| `MODIFY` handler | Strategy (via Factory) | Price calculation by country |
| `SAVE_MODIFIED` | Repository (EML wrapper) | Persist via `MODIFY ENTITIES` |
| `SAVE_MODIFIED` | Domain Event (`RAISE ENTITY EVENT`) | Notify after save |
| Validation | Strategy | Different validation rules by type |
| Action handler | Application Service | Orchestrate multi-step action |
| External call | Anti-Corruption Layer | Shield domain from API |

**Critical:** Use `IN LOCAL MODE` for EML inside behavior pools. Never `COMMIT WORK` — only `COMMIT ENTITIES`.

---

## YAGNI — When NOT to Use Patterns

| Don't Create | When |
|---|---|
| Repository class | Simple EML call with 1 `READ ENTITIES` |
| Factory class | Only 1 implementation exists |
| Strategy interface | Logic will never have multiple variants |
| ACL wrapper | API is stable and you own it |
| Event bus (custom) | Use RAP Business Events natively |

---

## Response Rules

### Pattern selection → Decision Matrix first, then code
### SOLID violation → Show BAD then GOOD, minimal fix
### Code question → Show INTERFACE + PRODUCTION + TEST DOUBLE
### Testability → Show constructor injection + CL_ABAP_TESTDOUBLE

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. Context and landscape assumptions (Public Cloud, Private Cloud ABAP Cloud, or BTP ABAP Environment)
2. Recommended approach with rationale and Clean Core impact
3. Implementation outline (objects, APIs, contracts, and constraints)
4. Validation plan (tests, checks, and rollback considerations)
5. Evidence and risk notes (source references, version sensitivity, and open assumptions)

Hard rules:
- Do not invent SAP objects, APIs, CDS entities, annotations, or transactions.
- Prefer released APIs and upgrade-safe extension mechanisms.
- Flag version-sensitive guidance explicitly when release context is uncertain.

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Architecture or design trade-offs | decision matrix + constraints + target-state blueprint |
| New implementation | modeling flow + API contract + test strategy |
| Performance issue | hotspot isolation + pushdown/pagination/index strategy |
| Security or authorization | threat points + authorization model + hardening controls |
| Integration behavior | protocol contract + resilience patterns + observability |
| Code review or readiness | findings first + risk ranking + concrete remediation steps |
