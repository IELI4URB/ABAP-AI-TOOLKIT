---
name: abap-code-review-checklist
description: 'Review ABAP Cloud code during development and before transport. Use for naming and method gates, Clean Core, RAP/CDS quality, OOP, security, performance, ABAP Unit, operability, ATC, rollback, and transport-readiness findings.'
---

# ABAP Cloud Review Checklist

The full release-review checklist and the Clean ABAP code-level checklist are included below.

## Workflow

1. Establish target landscape, changed artifacts, risk, and review phase.
2. Apply Gate 0 constraints during development.
3. Review only relevant sections after each bounded change.
4. Before release, execute the full checklist and report findings by severity.

## Verdict

Block on unreleased dependencies, authorization gaps, contract violations, unbounded data access, missing critical tests, failed ATC/readiness, or absent rollback/operations evidence. Never replace concrete findings with a checklist-only response.

## Code Review Checklist for Clean Core Cloud Development

### Using This Checklist

- **For all ABAP code** in SAP Cloud projects
- **By senior developer** (at least once, before transport)
- **Reference specific line numbers** when findings apply
- Use sections as applicable (all sections = Enterprise delivery, not all needed for bugs)

---

### A. Clean Core Compliance (CRITICAL)

**Purpose:** Ensure zero modifications to SAP standard, only released APIs used.

#### A1. Released API Validation
- [ ] **ATC "Use of released APIs" check passes** (zero violations)
- [ ] **All SAP objects used have release state "C1 - Released"**
  - Check in ADT: Right-click object → Properties → Release State
  - Red flag: If state is "Use System-Internally", "Restricted", or unreleased
- [ ] **No `/IWBEP/*`, `/UI5/*`, `/SAP/CX_*_INTERNAL` classes used**
  - Search: `Ctrl+H` for `/IWBEP`, `/SAP/CX_*INTERNAL`
  - If found: Replace with released API or log request to SAP

#### A2. Standard Object Modifications
- [ ] **No MODIFY statements on SAP classes** (`MODIFY /SAP/CL_*`, `/IWBEP/CL_*`)
- [ ] **No direct table field additions to SAP tables** (use custom field API or custom table)
- [ ] **No enhancement points without SAP Release Note**
  - Verify via SAP Help → this exit point published?

#### A3. Namespace Compliance
- [ ] **Custom code only in approved namespace** (`Z*`, `Y*`, customer namespace)
- [ ] **No code in `/SAP/*`, `/IWBEP/*`, `/UI5/*` namespaces** (read-only)
- [ ] **Package name reflects purpose** (`ZTRAVEL_APP`, `ZORDER_DOMAIN`, not `ZCUSTOM_MISC`)

**Verdict:**
- ✅ Pass: All checks green, zero ATC violations
- ❌ Fail: Any red flag above

---

### B. RAP and Service Design (HIGH)

#### B1. CDS Model Layering
- [ ] **Three-layer model evident** (Interface → Projection → Metadata Extension)
  - Interface view (ZI_*): no annotations, maps table
  - Projection view (ZC_*): filters fields, marks `@Metadata.allowExtensions`
  - Metadata extension (ZME_*): UI annotations only
- [ ] **No circular dependencies between views** (ZC_A depends on ZC_B AND ZC_B depends on ZC_A)
  - Run Package Monitor in ADT if complex
- [ ] **Naming conventions consistent** (all views use same prefix)
- [ ] **View fields commented or self-explanatory** (especially complex calculations)

#### B2. Behavior Definition Quality
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

#### B3. Service Exposure
- [ ] **Service definition (ZSD_*) lists only required entities**
  - Filter: expose only what consumer needs
- [ ] **Service binding type correct** (OData V4 UI for Fiori, Web API for stateless)
- [ ] **Actions/functions have clear semantics** (what does this do? documented)
- [ ] **Authorization aligned** (service binding + BDEF auth + IAM app)

**Verdict:**
- ✅ Pass: Layering clear, behavior logic sound, service well-defined
- ❌ Fail: Missing draft for transactional app, authorization unclear, or 200-line handler method

---

### C. Architecture and OOP Quality (HIGH)

#### C1. Layering & Dependencies
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

#### C2. OOP Design
- [ ] **Interfaces segregated** (not fat)
  - Red flag: Interface >5 methods
  - Red flag: Class implements interface but leaves 3+ methods as stubs
- [ ] **Dependency injection used** (constructor or setter, not NEW inside)
  - Check: Any `NEW zcl_concrete( )` inside method?
    - If YES and it's a dependency (repo, service, factory) → inject via constructor
- [ ] **Abstractions are real** (not just wrappers)
  - Question: Could I swap this interface with another implementation?
  - If NO → interface is just overhead

#### C3. Error Handling
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

### D. Security and Authorization (CRITICAL)

#### D1. Authorization Implementation
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

#### D2. Input Validation
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

### E. Performance and Data Access (MEDIUM)

#### E1. Query Optimization
- [ ] **CDS pushdown used** (calculation in DB, not ABAP)
  - Check: Heavy calc in ABAP loop? Move to CDS
- [ ] **No N+1 queries** (loop with SELECT inside)
  - Pattern: `LOOP AT travels. SELECT * FROM bookings WHERE ... ENDLOOP.` ❌
  - Better: `SELECT * FROM bookings WHERE travel_id IN (travel_ids)`
- [ ] **Filtering and pagination in OData** (`$filter`, `$top`, `$skip`)
  - Check: Method fetches all 100K records, then filters in ABAP? ❌
- [ ] **Field projection** (don't fetch all columns if only 3 needed)
  - Check: `SELECT * FROM table` or `SELECT travel_id, status FROM table`?

#### E2. Data Volume Handling
- [ ] **Large exports/imports have progress indicators** (if UI)
- [ ] **Batch operations split** (if processing >1K records)
- [ ] **Timeouts configured** (external API calls don't hang forever)

**Verdict:**
- ✅ Pass: No N+1 detected, CDS used for heavy calcs, proper filtering
- ❌ Fail: N+1 pattern found, unfiltered large data fetches, or no pagination

---

### F. ABAP Unit Testing (HIGH)

#### F1. Test Coverage
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

#### F2. Test Quality
- [ ] **Tests are independent** (can run in any order, no shared state)
  - Red flag: Test 2 depends on Test 1 running first
- [ ] **One behavior per test** (not multiple assertions testing different things)
- [ ] **Test names describe behavior** (`test_validate_rejects_past_date` not `test_validate1`)
- [ ] **No flaky tests** (passes sometimes, fails other times)
  - Question: Does test depend on current time/date? Use mock
  - Question: Does test depend on system order? Use explicit setup

#### F3. ATC Compliance
- [ ] **ATC code inspector passes** (no warnings, all clean-core violations fixed)
- [ ] **Cyclomatic complexity reasonable** (methods not 20+ lines of nested logic)

**Verdict:**
- ✅ Pass: Tests cover positive + negative paths, ATC passes, no flaky tests
- ❌ Fail: Missing negative tests, ATC violations, or tests call real DB/API

---

### G. Operability and Maintainability (MEDIUM)

#### G1. Logging & Observability
- [ ] **Meaningful logs at key points** (create, update, delete, error)
  - Bad: `LOG-write( msg = 'OK' )`
  - Good: `LOG-write( msg = |Travel { travel_id } created by { sy-uname }| )`
- [ ] **Errors logged with context** (what operation, what failed)
  - Check: Error messages include business identifier (travel_id, order_id)?
- [ ] **No sensitive data in logs** (password, credit card, PII)
- [ ] **Performance concerns logged** (slow queries, API latency >1s)

#### G2. Documentation
- [ ] **Public methods documented** (what does it do, what does it throw)
  - Check: Method signature clear? E.g., what parameter types?
- [ ] **Complex logic has comments** (why this approach, not just what)
  - But avoid "obvious" comments: `x = x + 1 " Increment x` ❌
- [ ] **Package README** (purpose of package, key classes)

#### G3. Naming Consistency
- [ ] **Class names meaningful** (zcl_travel_service, zcl_price_calculator)
- [ ] **Method names describe action** (create_travel, not do_something)
- [ ] **Variable names clear** (travel_id, not t_id)
- [ ] **No misleading names** (method named `calculate_price` but also saves?)

**Verdict:**
- ✅ Pass: Logs have context, no sensitive data, naming clear
- ❌ Fail: Logs empty or vague, critical operation undocumented

---

### H. Transport Readiness (MEDIUM)

#### H1. Backward Compatibility
- [ ] **Exposed contracts versioned** (if changing API, bump version)
  - Public method signature changed? → Check all callers
- [ ] **No removal of used functionality** (if field/method used, keep it)
- [ ] **Database changes non-breaking** (new columns nullable, not removing)

#### H2. Documentation
- [ ] **Deployment prerequisites documented** (config, tables, authorizations)
- [ ] **Rollback plan** (if something fails, how to revert)
  - Critical code needs rollback steps
- [ ] **Known limitations documented** (what this code does NOT do)

#### H3. Testing Before Transport
- [ ] **Code tested in test system** (not just dev)
- [ ] **Data migration tested** (if applicable)
- [ ] **Integration tested** (with other systems, if applicable)

**Verdict:**
- ✅ Pass: Backward compatible, prerequisites clear, rollback possible
- ❌ Fail: Breaking API changes, no deployment docs, untested

---

### Reviewer Verdict Template

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

### SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models

## Clean ABAP Checklist — Development Guidelines

**Use this checklist WHILE WRITING CODE**, not just during review. Apply these standards from the first class, method, and variable declaration.

---

### Names Checklist

**Apply during development:**
- ✅ All variables have descriptive, meaningful names
- ✅ **No Hungarian notation** (iv_, ev_, lv_, lt_, ls_, gt_)
- ✅ Consistent use of snake_case
- ✅ No abbreviations unless commonly understood
- ✅ Class names are nouns (e.g., `account`, `reader`, `converter`)
- ✅ Method names are verbs (e.g., `read`, `calculate`, `validate`)
- ✅ Boolean methods start with `is_`, `has_`, `can_`
- ✅ **No noise words** (data, info, object) unless meaningful
- ✅ Same abbreviations used consistently throughout
- ✅ No obscuring of built-in functions (lines, strlen, condense)

**Example (WRONG):**
```abap
DATA lv_cnt TYPE i.           " ← Hungarian notation, unclear
DATA lt_accts TYPE TABLE OF   " ← "accts" is abbreviation
DATA gs_result TYPE result.   " ← Noise word "gs_"
METHOD get_data.              " ← Verb, but vague
```

**Example (RIGHT):**
```abap
DATA account_count TYPE i.
DATA accounts TYPE TABLE OF account.
DATA result TYPE result.
METHOD read_account.
```

---

### Language Checklist

**Apply during development:**
- ✅ Uses modern syntax (`NEW` instead of `CREATE OBJECT`)
- ✅ Uses functional style (`VALUE`, `COND`, `SWITCH`, `FILTER`)
- ✅ No obsolete constructs (`MOVE`, `TRANSLATE`, `ADD`)
- ✅ `SELECT` uses `@` for host variables
- ✅ Inline declarations where appropriate
- ✅ Table expressions instead of `READ TABLE`
- ✅ Object-oriented (classes) instead of procedural (function modules)

**Example (WRONG):**
```abap
CREATE OBJECT account.
MOVE value1 TO value2.
SELECT * FROM database INTO TABLE @result WHERE id = id.
READ TABLE accounts INTO account TRANSPORTING NO FIELDS.
```

**Example (RIGHT):**
```abap
DATA(account) = NEW account( ).
value2 = value1.
SELECT * FROM database INTO TABLE @result WHERE id = @input_id.
IF line_exists( accounts[ id = input_id ] ).
```

---

### Constants Checklist

**Apply during development:**
- ✅ No magic numbers or strings in code
- ✅ All constants have descriptive names
- ✅ Related constants are grouped (`BEGIN OF`/`END OF`)
- ✅ `ENUM` used for enumerations (ABAP 7.60+)
- ✅ No constants named by value (c_01, c_x)

**Example (WRONG):**
```abap
IF amount > 1000.           " ← Magic number
  status = 'A'.             " ← Magic string
ENDIF.
```

**Example (RIGHT):**
```abap
CONSTANTS:
  BEGIN OF amount_limits,
    high TYPE i VALUE 1000,
  END OF amount_limits.

CONSTANTS status_active TYPE string VALUE 'ACTIVE'.

IF amount > amount_limits-high.
  status = status_active.
ENDIF.
```

---

### Variables Checklist

**Apply during development:**
- ✅ Inline declarations used: `DATA(name) = ...`
- ✅ Variables not used outside declaration block
- ✅ No chained DATA declarations
- ✅ Field symbols only where necessary
- ✅ Appropriate loop targets (field-symbol vs reference vs value)

**Example (WRONG):**
```abap
DATA account TYPE account.
DATA amount TYPE decimalv16_3.
DATA created_by TYPE string.
account = read_account( id ).
amount = account-amount.
```

**Example (RIGHT):**
```abap
DATA(account) = read_account( id ).
DATA(amount) = account-amount.
```

---

### Methods — Parameters Checklist

**Apply during development:**
- ✅ **<= 3 IMPORTING parameters** (split methods if more)
- ✅ No `OPTIONAL` parameters (split methods instead)
- ✅ No `PREFERRED PARAMETER`
- ✅ Exactly one output (`RETURNING`, `EXPORTING`, or `CHANGING`)
- ✅ `RETURNING` preferred to `EXPORTING`
- ✅ Not mixing `RETURNING` with `EXPORTING`/`CHANGING`
- ✅ `CHANGING` used sparingly
- ✅ No boolean input parameters (split method instead)

**Example (WRONG):**
```abap
METHOD process_data
  IMPORTING
    id TYPE string
    account TYPE account
    amount TYPE decimalv16_3
    include_fee TYPE abap_bool OPTIONAL
  EXPORTING
    result TYPE result
    message TYPE string.
```

**Example (RIGHT):**
```abap
METHOD process_account
  IMPORTING
    id TYPE string
    account TYPE account
    amount TYPE decimalv16_3
  RETURNING
    VALUE(result) TYPE result.

METHOD process_with_fee
  IMPORTING
    id TYPE string
    account TYPE account
    amount TYPE decimalv16_3
  RETURNING
    VALUE(result) TYPE result.
```

---

### Methods — Body Checklist

**Apply during development:**
- ✅ Method does **one thing**
- ✅ Method length **<= 20 lines** (ideally 3-5)
- ✅ Focus on happy path OR error handling (not both)
- ✅ One level of abstraction
- ✅ Fail fast pattern used
- ✅ `CHECK` only at start of method
- ✅ `RETURN` used for guards

**Example (WRONG — 40+ lines, mixed concerns):**
```abap
METHOD process_order
  DATA(order) = read_order( order_id ).
  
  CHECK order IS NOT INITIAL.
  
  IF order-status = 'PENDING'.
    DATA(items) = read_order_items( order_id ).
    LOOP AT items INTO DATA(item).
      IF item-quantity > 0.
        DATA(price) = calculate_price( item-id item-quantity ).
        IF price > 10000.
          APPEND calculate_discount( price ) TO discounts.
        ENDIF.
      ENDIF.
    ENDLOOP.
    
    IF discounts IS NOT INITIAL.
      order-total = reduce_by_discounts( order-total discounts ).
    ENDIF.
    
    DATA(payment) = process_payment( order ).
    IF payment-status = 'SUCCESS'.
      order-status = 'PAID'.
    ELSE.
      out->write( payment-error ).
      RETURN.
    ENDIF.
  ENDIF.
  
  update_order( order ).
ENDMETHOD.
```

**Example (RIGHT — small, focused methods):**
```abap
METHOD process_order
  CHECK validate_order( order_id ) = abap_true.
  
  DATA(order) = read_order( order_id ).
  calculate_order_total( order ).
  process_payment( order ).
  update_order( order ).
ENDMETHOD.

METHOD calculate_order_total
  IMPORTING order TYPE order
  DATA(items) = read_order_items( order-id ).
  LOOP AT items INTO DATA(item).
    order-total = order-total + calculate_item_price( item ).
  ENDLOOP.
ENDMETHOD.

METHOD process_payment
  IMPORTING order TYPE order
  DATA(payment) = create_payment( order ).
  IF payment-status NE payment_status-success.
    RAISE EXCEPTION TYPE payment_failed.
  ENDIF.
ENDMETHOD.
```

---

### Classes — Scope Checklist

**Apply during development:**
- ✅ Global classes by default
- ✅ Local classes only where appropriate
- ✅ `FINAL` if not designed for inheritance
- ✅ Members `PRIVATE` by default
- ✅ `PROTECTED` only if needed for inheritance
- ✅ `READ-ONLY` used appropriately (public immutables)

**Example:**
```abap
CLASS account DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS:
      create
        IMPORTING id TYPE string
        RETURNING VALUE(result) TYPE REF TO account,
      
      get_balance
        RETURNING VALUE(balance) TYPE decimalv16_3,
      
      deposit
        IMPORTING amount TYPE decimalv16_3.
    
    DATA account_id TYPE string READ-ONLY.
  
  PRIVATE SECTION.
    DATA balance TYPE decimalv16_3.
    DATA created_at TYPE timestamp READ-ONLY.
ENDCLASS.
```

---

### Error Handling Checklist

**Apply during development:**
- ✅ Exceptions used instead of return codes
- ✅ Class-based exceptions (not message classes)
- ✅ `CX_STATIC_CHECK` for manageable errors
- ✅ `CX_NO_CHECK` for unrecoverable errors
- ✅ `RAISE EXCEPTION NEW` instead of `RAISE EXCEPTION TYPE`
- ✅ Foreign exceptions wrapped
- ✅ No catching `CX_ROOT` (too generic)
- ✅ No silent catches

**Example (WRONG):**
```abap
METHOD read_account
  IMPORTING id TYPE string
  RETURNING VALUE(account) TYPE account.
  
  TRY.
    SELECT * FROM database INTO account WHERE id = @id.
  CATCH CX_ROOT.
    " Silently ignore all errors
  ENDTRY.
  
  RETURN account.
ENDMETHOD.
```

**Example (RIGHT):**
```abap
METHOD read_account
  IMPORTING id TYPE string
  RETURNING VALUE(account) TYPE account
  RAISING account_not_found_error.
  
  SELECT * FROM database INTO account WHERE id = @id.
  
  IF account IS INITIAL.
    RAISE EXCEPTION NEW account_not_found_error(
      message = |Account { id } not found|
    ).
  ENDIF.
  
  RETURN account.
ENDMETHOD.
```

---

### Testing Checklist

**Apply during development (before/alongside code):**
- ✅ Code is testable (dependency injection)
- ✅ Public methods have tests
- ✅ Test class names describe purpose
- ✅ Test method names describe scenario
- ✅ Given-When-Then structure used
- ✅ One When per test method
- ✅ Few, focused assertions
- ✅ Right assert type used
- ✅ Content assertions, not quantity
- ✅ No unnecessary test doubles

**Example:**
```abap
CLASS account_test DEFINITION FOR TESTING.
  PRIVATE SECTION.
    DATA account TYPE REF TO account.
    
    METHODS:
      setup,
      test_deposit_increases_balance FOR TESTING,
      test_deposit_zero_fails FOR TESTING.
ENDCLASS.

CLASS account_test IMPLEMENTATION.
  METHOD setup.
    account = account=>create( id = 'ACC123' ).
    account->deposit( 100 ).
  ENDMETHOD.
  
  METHOD test_deposit_increases_balance FOR TESTING.
    " Given: Account with balance 100
    
    " When: Deposit 50
    account->deposit( 50 ).
    
    " Then: Balance is 150
    cl_abap_unit_assert=>assert_equals(
      EXPORTING
        act = account->get_balance( )
        exp = 150
    ).
  ENDMETHOD.
  
  METHOD test_deposit_zero_fails FOR TESTING.
    " Given: Account
    
    " When: Try to deposit 0
    " Then: Raises exception
    TRY.
      account->deposit( 0 ).
      cl_abap_unit_assert=>fail( 'Should have raised exception' ).
    CATCH invalid_amount_error.
      " Expected
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
```

---

### Priority Assessment

#### Critical Issues (Must Fix — Blocks Code Commit)
- Magic numbers without constants
- Deep nesting (>3 levels)
- Methods with >5 parameters
- Multiple output parameters
- Empty IF branches
- Static classes without good reason
- Return codes instead of exceptions
- DEFAULT KEY usage
- Silent exception catching
- Commented-out code in production
- **Naming >30 characters**
- **Hungarian notation**

#### Major Issues (Should Fix — Code Review)
- Non-descriptive names
- Long methods (>20 lines)
- Up-front declarations where inline is clearer
- APPEND TO instead of INSERT INTO TABLE
- Old-style READ TABLE
- EXPORTING instead of RETURNING
- Methods doing multiple things
- No interfaces for public methods
- Non-FINAL classes not designed for inheritance

#### Minor Issues (Nice to Have — Polish)
- Single quotes instead of backticks for strings
- Unnecessary me-> references
- Concatenation instead of string templates
- RECEIVING keyword usage
- Multiple blank lines
- Minor formatting inconsistencies

---

### Quick Self-Check Before Commit

Run through these before committing code:

```
☐ All variable names are descriptive (no lv_, iv_, etc.)
☐ No naming longer than 30 characters
☐ All methods <= 20 lines (ideally 5-10)
☐ All methods have <= 3 parameters
☐ One RETURNING output per method (no EXPORTING)
☐ No magic numbers (all constants defined)
☐ No empty IF branches or silent catches
☐ Used NEW instead of CREATE OBJECT
☐ Used inline declarations (DATA(x) = ...)
☐ All public methods have unit tests
☐ ATC clean (no warnings)
☐ All exception handling uses class-based exceptions
```

---

### References

- SAP Clean ABAP Style Guide: https://github.com/SAP/styleguides/blob/master/clean-abap/CleanABAP.md
- ABAP Unit Testing: CL_ABAP_UNIT_ASSERT, CL_ABAP_TESTDOUBLE
- Skill: abap-code-review-checklist (for comprehensive 8-section review)


### SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
