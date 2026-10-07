---
name: abap-unit-testing
description: >-
  ABAP Unit Test best practices for ABAP Cloud. Covers test pyramid, CL_ABAP_TESTDOUBLE (dynamic mocking), CL_OSQL_TEST_ENVIRONMENT (SQL doubles), CL_CDS_TEST_ENVIRONMENT (CDS doubles), RAP BO test doubles, Given-When-Then pattern, RISK LEVEL semantics (default is CRITICAL), DURATION semantics, test isolation with ROLLBACK ENTITIES, CI/CD pipeline integration, and coverage analysis. Triggers: unit test, ABAP Unit, test double, mock, CL_ABAP_TESTDOUBLE, CL_OSQL_TEST_ENVIRONMENT, CDS test, RAP test, coverage, TDD, FOR TESTING, RISK LEVEL, AAA, Given-When-Then, test class.
metadata:
  version: 2.0.0
  tags: abap unit-testing test-doubles mocking abap-cloud tdd coverage rap-testing
---

# ABAP Unit Test Best Practices for ABAP Cloud

Expert guide for the complete SAP testing toolkit — from basic ABAP Unit to RAP BO test doubles and CI/CD integration.

**Golden rule: Test BEHAVIOR, not implementation. Use CL_ABAP_UNIT_ASSERT (not deprecated CL_AUNIT_ASSERT). RISK LEVEL defaults to CRITICAL if omitted — always declare it.**

Reference files:
- `references/abap-unit-patterns.md` — complete test patterns, frameworks, and examples

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

## ABAP Cloud Testing Toolkit

| Framework | Purpose | Key Class |
|---|---|---|
| ABAP Unit (core) | Test execution framework | `CL_ABAP_UNIT_ASSERT` |
| OO Test Double | Mock global interfaces dynamically | `CL_ABAP_TESTDOUBLE` |
| SQL Test Double | Mock DB tables for unit tests | `CL_OSQL_TEST_ENVIRONMENT` |
| CDS Test Double | Mock CDS entity access | `CL_CDS_TEST_ENVIRONMENT` |
| RAP BO Test Double | Mock EML / RAP BO behavior | `CL_BOTD_TXBUFDBL_BO_TEST_ENV` |

---

## Test Class Structure

```abap
"! @testing BDEF:ZI_TRAVEL
CLASS ltcl_travel_test DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    CLASS-DATA: sql_env TYPE REF TO if_osql_test_environment.
    DATA: cut TYPE REF TO zcl_travel_service.
    DATA: mock_repo TYPE REF TO zif_travel_repository.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS test_create_success FOR TESTING.
    METHODS test_rejects_past_date FOR TESTING.
ENDCLASS.
```

**RISK LEVEL semantics:**
- `HARMLESS` = no system changes (most unit tests)
- `DANGEROUS` = changes application data
- `CRITICAL` = changes system settings (DEFAULT if omitted!)

**DURATION semantics:**
- `SHORT` = few seconds | `MEDIUM` = ~1 minute | `LONG` = >1 minute

---

## CL_ABAP_TESTDOUBLE (Dynamic Mocking)

```abap
" 1. Create double for global interface
DATA(lo_double) = CAST zif_travel_repository(
  cl_abap_testdouble=>create( 'ZIF_TRAVEL_REPOSITORY' ) ).

" 2. Configure return value
cl_abap_testdouble=>configure_call( lo_double
  )->returning( VALUE ztravel( travel_id = '001' status = 'N' ) ).
lo_double->find_by_id( '001' ).  " Configure for this call

" 3. Inject into class under test
DATA(lo_cut) = NEW zcl_travel_service( repository = lo_double ).

" 4. Verify expectations
cl_abap_testdouble=>verify_expectations( lo_double ).
```

**Constraint:** Only works with GLOBAL interfaces. Not classes, not local interfaces.

---

## SQL Test Double (CL_OSQL_TEST_ENVIRONMENT)

```abap
CLASS-METHODS class_setup.
  sql_env = cl_osql_test_environment=>create(
    i_dependency_list = VALUE #( ( 'ZTRAVEL' ) ( 'ZBOOKING' ) ) ).

METHODS setup.
  sql_env->clear_doubles( ).
  sql_env->insert_test_data( VALUE zttravel( ( travel_id = '001' status = 'N' ) ) ).

CLASS-METHODS class_teardown.
  sql_env->destroy( ).
```

---

## RAP Test Isolation

```abap
" Reset RAP transactional buffer between tests
ROLLBACK ENTITIES.
```

---

## Given-When-Then (SAP Primary Pattern)

```abap
METHOD test_price_applies_vat.
  " GIVEN a travel with base price 1000 in Germany
  DATA(travel) = VALUE ztravel( base_price = 1000 country = 'DE' ).

  " WHEN price is calculated
  DATA(result) = cut->calculate_price( travel ).

  " THEN price includes 19% VAT
  cl_abap_unit_assert=>assert_equals( act = result exp = 1190 ).
ENDMETHOD.
```

---

## Response Rules

### "How do I test X?" → Determine framework (OO double, SQL double, or CDS double)
### "How do I mock?" → CL_ABAP_TESTDOUBLE for interfaces, CL_OSQL for tables
### "What coverage?" → 80% for domain logic, 75% for rules, 50% for adapters

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
- When returning ABAP code, use a fenced `abap` code block and keep it copy-paste ready.
- For ABAP Cloud code examples, do not use `CREATE OBJECT`; use constructor expressions with `NEW`.
- For ABAP Unit class requests, always use `CL_OSQL_TEST_ENVIRONMENT` for DB tables and `CL_CDS_TEST_ENVIRONMENT` for CDS views/entities.
- For ABAP Unit class requests touching DB access, creating DB test doubles is mandatory.
- When inserting DB test-double data, always populate all key fields with unique key combinations.
- Never provide duplicate key combinations in test data, even for key fields not used in the test selection filter.
- Keep ABAP test method names at 30 characters or fewer.
- For ABAP Unit class requests, do not use dependency injection patterns, `TEST-SEAM`, or `TEST-INJECTION`.

DB test data integrity rule:
1. Identify the complete primary key of each doubled table before preparing test rows.
2. Populate all key fields explicitly in every inserted row.
3. Ensure each row has a unique full-key combination across the inserted dataset.
4. If key metadata is missing, mark the test data draft and request the missing key definition.

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Architecture or design trade-offs | decision matrix + constraints + target-state blueprint |
| New implementation | modeling flow + API contract + test strategy |
| Performance issue | hotspot isolation + pushdown/pagination/index strategy |
| Security or authorization | threat points + authorization model + hardening controls |
| Integration behavior | protocol contract + resilience patterns + observability |
| Code review or readiness | findings first + risk ranking + concrete remediation steps |
