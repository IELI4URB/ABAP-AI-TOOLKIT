# Code Review Checklist for Clean Core Cloud Development

## Using This Checklist

- **For all ABAP code** in SAP Cloud projects
- **By senior developer** (at least once, before transport)
- **Reference specific line numbers** when findings apply
- Use sections as applicable (all sections = Enterprise delivery, not all needed for bugs)

---

## A. Clean Core Compliance (CRITICAL)

**Purpose:** Ensure zero modifications to SAP standard, only released APIs used.

### A1. Released API Validation
- [ ] **ATC "Use of released APIs" check passes** (zero violations)
- [ ] **All SAP objects used have release state "C1 - Released"**
  - Check in ADT: Right-click object → Properties → Release State
  - Red flag: If state is "Use System-Internally", "Restricted", or unreleased
- [ ] **No `/IWBEP/*`, `/UI5/*`, `/SAP/CX_*_INTERNAL` classes used**
  - Search: `Ctrl+H` for `/IWBEP`, `/SAP/CX_*INTERNAL`
  - If found: Replace with released API or log request to SAP

### A2. Standard Object Modifications
- [ ] **No MODIFY statements on SAP classes** (`MODIFY /SAP/CL_*`, `/IWBEP/CL_*`)
- [ ] **No direct table field additions to SAP tables** (use custom field API or custom table)
- [ ] **No enhancement points without SAP Release Note**
  - Verify via SAP Help → this exit point published?

### A3. Namespace Compliance
- [ ] **Custom code only in approved namespace** (`Z*`, `Y*`, customer namespace)
- [ ] **No code in `/SAP/*`, `/IWBEP/*`, `/UI5/*` namespaces** (read-only)
- [ ] **Package name reflects purpose** (`ZTRAVEL_APP`, `ZORDER_DOMAIN`, not `ZCUSTOM_MISC`)

**Verdict:**
- ✅ Pass: All checks green, zero ATC violations
- ❌ Fail: Any red flag above

---

## B. RAP and Service Design (HIGH)

### B1. CDS Model Layering
- [ ] **Three-layer model evident** (Interface → Projection → Metadata Extension)
  - Interface view (ZI_*): no annotations, maps table
  - Projection view (ZC_*): filters fields, marks `@Metadata.allowExtensions`
  - Metadata extension (ZME_*): UI annotations only
- [ ] **No circular dependencies between views** (ZC_A depends on ZC_B AND ZC_B depends on ZC_A)
  - Run Package Monitor in ADT if complex
- [ ] **Naming conventions consistent** (all views use same prefix)
- [ ] **View fields commented or self-explanatory** (especially complex calculations)

### B2. Behavior Definition Quality
- [ ] **Implementation type justified** (managed/unmanaged/query with comment)
  - e.g., `managed implementation ...  " Managed chosen: standard CRUD, no legacy code
- [ ] **Draft table defined for transactional apps** (`with draft; persistent table ... draft table ...`)
- [ ] **Authorization checks present** (`authorization master ( global )`)
- [ ] **Determinations, validations, actions clearly separated** (not mixed)
  - Determination: derive data, side-effect free
  - Validation: check rules, can fail
  - Action: user-triggered, can have side effects
- [ ] **Mapping block complete** (`mapping for table { field = db_field; ... }`)
- [ ] **EML used exclusively in handlers** (no direct ABAP SQL DML)

### B3. Service Exposure
- [ ] **Service definition (ZSD_*) lists only required entities**
  - Filter: expose only what consumer needs
- [ ] **Service binding type correct** (OData V4 UI for Fiori, Web API for stateless)
- [ ] **Actions/functions have clear semantics** (what does this do? documented)
- [ ] **Authorization aligned** (service binding + BDEF auth + IAM app)

**Verdict:**
- ✅ Pass: Layering clear, behavior logic sound, service well-defined
- ❌ Fail: Missing draft for transactional app, authorization unclear, or 200-line handler method

---

## C. Architecture and OOP Quality (HIGH)

### C1. Layering & Dependencies
- [ ] **Layers respected** (API → Application → Domain → Infrastructure)
  - Check imports: does Application depend on API? Red flag
  - Check calls: does Domain call Repository? Use interface
- [ ] **No cyclic dependencies** (ClassA → ClassB → ClassA)
  - ADT Package Monitor → Dependency Graph (should be acyclic)
- [ ] **Single Responsibility** (each class does one thing)
  - Red flag: Class name has "And" (XyzAndAbc) → split
  - Red flag: >100 lines → likely doing multiple things
- [ ] **Open/Closed** (extend via composition, not modification)
  - Adding feature requires modifying 3+ methods? Use strategy/factory

### C2. OOP Design
- [ ] **Interfaces segregated** (not fat)
  - Red flag: Interface >5 methods
  - Red flag: Class implements interface but leaves 3+ methods as stubs
- [ ] **Dependency injection used** (constructor or setter, not NEW inside)
  - Check: Any `NEW zcl_concrete( )` inside method?
    - If YES and it's a dependency (repo, service, factory) → inject via constructor
- [ ] **Abstractions are real** (not just wrappers)
  - Question: Could I swap this interface with another implementation?
  - If NO → interface is just overhead

### C3. Error Handling
- [ ] **Exceptions used (not return codes)** for errors
  - Red flag: Method returns `success TYPE abap_bool`
  - Better: Raise exception on error
- [ ] **Meaningful exception texts** (user can understand what happened)
  - Bad: `RAISE EXCEPTION TYPE cx_error.`
  - Good: `RAISE EXCEPTION TYPE cx_invalid_date EXPORTING message = |Start date cannot be in past|.`
- [ ] **No silent failures** (catch exception → log, then what? rethrow or handled?)

**Verdict:**
- ✅ Pass: Layers clear, DIP applied, error handling explicit
- ❌ Fail: Circular dependencies, God class, dependencies created inline, silent failures

---

## D. Security and Authorization (CRITICAL)

### D1. Authorization Implementation
- [ ] **Authorization checks explicit** (not implicit via UI)
  - Red flag: "Checked in UI" → not enough, check in handler too
  - Good: `AUTHORITY-CHECK` or `RAP authorization master`
- [ ] **Global and instance auth both present** (if needed)
  - Global: "Can user access this BO at all?"
  - Instance: "Can user edit THIS specific record?"
- [ ] **No privilege bypass** (e.g., no technical user assumption)
  - Question: Code assumes user is ADMIN? ❌ Fail
  - Question: Code runs under technical user to bypass auth? ❌ Fail
- [ ] **Sensitive fields protected** (cost, salary, password)
  - Check: Are there `authorization ( update: ... )` field guards?

### D2. Input Validation
- [ ] **External API calls validated** (OData input, REST payload)
  - Check length, type, range
  - Sanitize if building SQL/commands
- [ ] **Batch operations guarded** (don't accept 1M records)
  - Red flag: No limit on array size
- [ ] **No SQL injection risk** (parameterized queries only)
  - Red flag: String concatenation in WHERE clause

**Verdict:**
- ✅ Pass: Authorization explicit, input validated, no bypass paths
- ❌ Fail: Missing auth check, bypass detected, or unvalidated input accepted

---

## E. Performance and Data Access (MEDIUM)

### E1. Query Optimization
- [ ] **CDS pushdown used** (calculation in DB, not ABAP)
  - Check: Heavy calc in ABAP loop? Move to CDS
- [ ] **No N+1 queries** (loop with SELECT inside)
  - Pattern: `LOOP AT travels. SELECT * FROM bookings WHERE ... ENDLOOP.` ❌
  - Better: `SELECT * FROM bookings WHERE travel_id IN (travel_ids)`
- [ ] **Filtering and pagination in OData** (`$filter`, `$top`, `$skip`)
  - Check: Method fetches all 100K records, then filters in ABAP? ❌
- [ ] **Field projection** (don't fetch all columns if only 3 needed)
  - Check: `SELECT * FROM table` or `SELECT travel_id, status FROM table`?

### E2. Data Volume Handling
- [ ] **Large exports/imports have progress indicators** (if UI)
- [ ] **Batch operations split** (if processing >1K records)
- [ ] **Timeouts configured** (external API calls don't hang forever)

**Verdict:**
- ✅ Pass: No N+1 detected, CDS used for heavy calcs, proper filtering
- ❌ Fail: N+1 pattern found, unfiltered large data fetches, or no pagination

---

## F. ABAP Unit Testing (HIGH)

### F1. Test Coverage
- [ ] **Positive test case exists** for each public method
- [ ] **Negative test case exists** for validations and error paths
  - Test: Invalid input → exception raised?
  - Test: Authorization denied → exception raised?
- [ ] **Critical domain logic tested** (>80% branch coverage)
  - Question: What if this pricing calc is wrong? Would tests catch it?
  - If unsure → coverage is insufficient
- [ ] **Mocks used for external dependencies** (repo, API, clock)
  - Red flag: Test calls `NEW zcl_repository( )` → real DB hit
  - Better: Inject mock via constructor

### F2. Test Quality
- [ ] **Tests are independent** (can run in any order, no shared state)
  - Red flag: Test 2 depends on Test 1 running first
- [ ] **One behavior per test** (not multiple assertions testing different things)
- [ ] **Test names describe behavior** (`test_validate_rejects_past_date` not `test_validate1`)
- [ ] **No flaky tests** (passes sometimes, fails other times)
  - Question: Does test depend on current time/date? Use mock
  - Question: Does test depend on system order? Use explicit setup

### F3. ATC Compliance
- [ ] **ATC code inspector passes** (no warnings, all clean-core violations fixed)
- [ ] **Cyclomatic complexity reasonable** (methods not 20+ lines of nested logic)

**Verdict:**
- ✅ Pass: Tests cover positive + negative paths, ATC passes, no flaky tests
- ❌ Fail: Missing negative tests, ATC violations, or tests call real DB/API

---

## G. Operability and Maintainability (MEDIUM)

### G1. Logging & Observability
- [ ] **Meaningful logs at key points** (create, update, delete, error)
  - Bad: `LOG-write( msg = 'OK' )`
  - Good: `LOG-write( msg = |Travel { travel_id } created by { sy-uname }| )`
- [ ] **Errors logged with context** (what operation, what failed)
  - Check: Error messages include business identifier (travel_id, order_id)?
- [ ] **No sensitive data in logs** (password, credit card, PII)
- [ ] **Performance concerns logged** (slow queries, API latency >1s)

### G2. Documentation
- [ ] **Public methods documented** (what does it do, what does it throw)
  - Check: Method signature clear? E.g., what parameter types?
- [ ] **Complex logic has comments** (why this approach, not just what)
  - But avoid "obvious" comments: `x = x + 1 " Increment x` ❌
- [ ] **Package README** (purpose of package, key classes)

### G3. Naming Consistency
- [ ] **Class names meaningful** (zcl_travel_service, zcl_price_calculator)
- [ ] **Method names describe action** (create_travel, not do_something)
- [ ] **Variable names clear** (travel_id, not t_id)
- [ ] **No misleading names** (method named `calculate_price` but also saves?)

**Verdict:**
- ✅ Pass: Logs have context, no sensitive data, naming clear
- ❌ Fail: Logs empty or vague, critical operation undocumented

---

## H. Transport Readiness (MEDIUM)

### H1. Backward Compatibility
- [ ] **Exposed contracts versioned** (if changing API, bump version)
  - Public method signature changed? → Check all callers
- [ ] **No removal of used functionality** (if field/method used, keep it)
- [ ] **Database changes non-breaking** (new columns nullable, not removing)

### H2. Documentation
- [ ] **Deployment prerequisites documented** (config, tables, authorizations)
- [ ] **Rollback plan** (if something fails, how to revert)
  - Critical code needs rollback steps
- [ ] **Known limitations documented** (what this code does NOT do)

### H3. Testing Before Transport
- [ ] **Code tested in test system** (not just dev)
- [ ] **Data migration tested** (if applicable)
- [ ] **Integration tested** (with other systems, if applicable)

**Verdict:**
- ✅ Pass: Backward compatible, prerequisites clear, rollback possible
- ❌ Fail: Breaking API changes, no deployment docs, untested

---

## Reviewer Verdict Template

```
╔════════════════════════════════════════════════════════╗
║ CODE REVIEW VERDICT                                    ║
╚════════════════════════════════════════════════════════╝

Submission: [Change/PR/Transport number]
Reviewer: [Name]
Date: [Date]

┌─ COMPLIANCE STATUS ────────────────────────────────────┐
│ A. Clean Core:     ✅ PASS / ⚠️ MINOR / ❌ FAIL       │
│ B. RAP Design:     ✅ PASS / ⚠️ MINOR / ❌ FAIL       │
│ C. Architecture:   ✅ PASS / ⚠️ MINOR / ❌ FAIL       │
│ D. Security:       ✅ PASS / ⚠️ MINOR / ❌ FAIL       │
│ E. Performance:    ✅ PASS / ⚠️ MINOR / ❌ FAIL       │
│ F. Testing:        ✅ PASS / ⚠️ MINOR / ❌ FAIL       │
│ G. Operability:    ✅ PASS / ⚠️ MINOR / ❌ FAIL       │
│ H. Transport:      ✅ PASS / ⚠️ MINOR / ❌ FAIL       │
└────────────────────────────────────────────────────────┘

OVERALL: ✅ APPROVED / ⚠️ APPROVED WITH FIXES / ❌ REJECT

┌─ MAJOR FINDINGS ────────────────────────────────────────┐
│ [List critical issues blocking approval]               │
│ 1. [Line X] [Issue] → [Fix required]                   │
│ 2. [Line Y] [Issue] → [Fix required]                   │
└────────────────────────────────────────────────────────┘

┌─ REQUIRED FIXES ────────────────────────────────────────┐
│ [Must fix before approval]                             │
│ • Line 42: Unreleased API used → use released version  │
│ • Line 85: Missing auth check → add AUTHORITY-CHECK   │
│ • Line 123: N+1 query → batch fetch                    │
└────────────────────────────────────────────────────────┘

┌─ OPTIONAL IMPROVEMENTS ─────────────────────────────────┐
│ [Nice-to-have, not blocking]                           │
│ • Consider extracting domain service from handler      │
│ • Add INFO log on creation                             │
│ • Simplify complex validation logic                    │
└────────────────────────────────────────────────────────┘

RISK LEVEL: 🟢 LOW / 🟡 MEDIUM / 🔴 HIGH

APPROVAL DECISION: [Date signed off by reviewer]
```

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
