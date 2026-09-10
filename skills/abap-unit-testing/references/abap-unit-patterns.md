# ABAP Unit Test Best Practices — Test Pyramid & Decision Matrix

## Prerequisites

- ABAP Unit basics (test classes, assertions, setup/teardown).
- Familiarity with business logic modules 01, 02, and 06 to define meaningful tests.
- Code review flow from module 07 to position tests as a mandatory release gate.

## Test Pyramid: Why and How Much

```
            △
           /|\
          / | \           Integration Tests (5-10%)
         /  |  \          • RAP + DB
        /   |   \         • Slow, fragile
       /    |    \        • Test contracts only
      /  Unit    \        •
     /   Tests    \       Unit Tests (80-90%)
    /  (fast,     \      • Domain logic
   / deterministic) \    • Fast, predictable
  /_________________\   • Mocked dependencies
       E2E (5-10%)        E2E/UI (5%)
      • Browser tests     • Rare
      • Slow             • Critical paths only
      • Flaky
```

**Recommended Ratio:**
- 80% Unit tests (isolated, mocked)
- 15% Integration tests (real DB, real RAP)
- 5% E2E tests (full system, browser)

## Test Strategy Decision Matrix

| Code | Should Test? | Type | Why | Tool |
|---|---|---|---|---|
| **Domain logic** | ✅ YES | Unit | Core behavior, must be fast & reliable | ABAP Unit |
| **Business rules** | ✅ YES | Unit | Validate + determinations, critical | ABAP Unit |
| **Repository save/read** | ⚠️ MAYBE | Integration | Test persistence contract once, then unit with mock | ABAP Unit + ABAP SQL |
| **RAP behavior handler** | ⚠️ MAYBE | Integration | Test mapping + framework interaction, not every line | Local test |
| **External API call** | ❌ NO | Unit only | Use mock/stub, never real API in tests | Mock library |
| **Authorization check** | ✅ YES | Unit | Test auth logic + failure paths | ABAP Unit |
| **Error handling** | ✅ YES | Unit | Test exceptions, rollback, recovery | ABAP Unit |
| **UI (Form, Report)** | ⚠️ MAYBE | E2E | Only critical paths, too flaky otherwise | Browser test |

## Design for Testability

### Rule 1: Inject Dependencies via Constructor

```abap
" BAD: Hard dependency, untestable
CLASS zcl_travel_service.
  METHODS create_travel.
  PRIVATE SECTION.
    DATA repository TYPE REF TO zcl_travel_repository.  " Created inside
ENDCLASS.

CLASS zcl_travel_service IMPLEMENTATION.
  METHOD create_travel.
    repository = NEW zcl_travel_repository( ).  " Can't swap with mock
    repository->save( travel ).
  ENDMETHOD.
ENDCLASS.

" GOOD: Injected dependency, testable
CLASS zcl_travel_service.
  METHODS constructor IMPORTING repository TYPE REF TO if_travel_repository.
  METHODS create_travel.
  PRIVATE SECTION.
    DATA repository TYPE REF TO if_travel_repository.  " Interface, not concrete
ENDCLASS.

CLASS zcl_travel_service IMPLEMENTATION.
  METHOD constructor.
    me->repository = repository.  " Injected
  ENDMETHOD.
  
  METHOD create_travel.
    repository->save( travel ).  " Works with any implementation
  ENDMETHOD.
ENDCLASS.

" Unit test usage
CLASS zcl_travel_service_test DEFINITION FOR TESTING RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_travel_service.  " Class Under Test
    DATA mock_repo TYPE REF TO zcl_travel_repo_mock.  " Test double
    
    METHODS setup.
    METHODS test_create_travel FOR TESTING.
ENDCLASS.

CLASS zcl_travel_service_test IMPLEMENTATION.
  METHOD setup.
    mock_repo = NEW zcl_travel_repo_mock( ).
    cut = NEW zcl_travel_service( mock_repo ).  " Inject mock
  ENDMETHOD.
  
  METHOD test_create_travel.
    cut->create_travel( 'DEST' ).  " Uses mock, not real DB!
    cl_abap_unit_assert=>assert_equals(
      EXPORTING act = mock_repo->save_called EXPORTING exp = abap_true
    ).
  ENDMETHOD.
ENDCLASS.
```

### Rule 2: Abstract External Concerns

```abap
" GOOD: Abstract time and random generation
INTERFACE if_clock.
  METHODS get_now RETURNING VALUE(now) TYPE timestamp.
ENDINTERFACE.

CLASS zcl_travel.
  PRIVATE SECTION.
    DATA clock TYPE REF TO if_clock.
  PUBLIC SECTION.
    METHODS constructor IMPORTING clock TYPE REF TO if_clock.
    METHODS created_recently RETURNING VALUE(recent) TYPE abap_bool.
ENDCLASS.

CLASS zcl_travel IMPLEMENTATION.
  METHOD created_recently.
    recent = ( sy-tstmp - creation_time ) < 86400.  " 24 hours
  ENDMETHOD.
ENDCLASS.

" Unit test: Control time
CLASS zcl_travel_test DEFINITION FOR TESTING.
  PRIVATE SECTION.
    METHODS test_created_recently FOR TESTING.
ENDCLASS.

CLASS zcl_travel_test IMPLEMENTATION.
  METHOD test_created_recently.
    DATA(mock_clock) = NEW zcl_clock_mock( fixed_time = '20250101000000' ).
    DATA(travel) = NEW zcl_travel( mock_clock ).
    travel->set_created_at( '20241231000000' ).
    
    cl_abap_unit_assert=>assert_true(
      travel->created_recently( )  " Mock clock makes this predictable!
    ).
  ENDMETHOD.
ENDCLASS.
```

## Arrange-Act-Assert Test Structure

### AAA Pattern

```abap
METHODS test_price_calculation FOR TESTING.
  " ARRANGE: Set up test data and doubles
  DATA(travel) = VALUE travel( base_price = 1000 quantity = 2 country = 'DE' ).
  DATA(mock_factor) = NEW zcl_country_factor_mock( factor = 1.2 ).
  DATA(calculator) = NEW zcl_price_calculator( mock_factor ).
  
  " ACT: Execute the behavior being tested
  DATA(result) = calculator->calculate( travel ).
  
  " ASSERT: Verify the outcome
  cl_abap_unit_assert=>assert_equals(
    EXPORTING act = result exp = 2400  " 1000 * 2 * 1.2
  ).
ENDMETHODS.
```

## What to Test: Coverage Decision Matrix

| Code Path | Test? | Priority | Example |
|---|---|---|---|
| **Happy path** | ✅ YES | High | Create travel successfully, all fields populated |
| **Validation failure** | ✅ YES | High | Status required → exception raised |
| **Authorization denied** | ✅ YES | High | User without permission → exception |
| **Boundary values** | ✅ YES | Medium | Amount = 0, Amount = 999999.99 |
| **Error handling/recovery** | ✅ YES | Medium | External API fails → retry, log, notify |
| **Side effects** | ✅ YES | Medium | Save called → verify repository.save() invoked |
| **Internal optimization** | ❌ NO | Low | Caching logic, internal sorting — test via behavior |
| **Trivial getters** | ❌ NO | Low | `METHODS get_status → status` |
| **Framework plumbing** | ❌ NO | Low | BDEF mapping details (test via integration) |

## Anti-Patterns: What NOT to Do

| Anti-Pattern | Problem | Fix |
|---|---|---|
| **Test implementation, not behavior** | Tests break when refactoring. Not about what you do, but outcome. | Test outcomes (results, exceptions, side effects) |
| **Over-mocking internal logic** | Mock everything → tests test mocks, not reality. | Mock only external dependencies, test internal collaborators real |
| **Test without clear assertion** | Passes but doesn't verify. | One behavior per test. Clear assertion that fails if behavior breaks. |
| **Flaky tests (depend on time/order)** | Fails randomly. Unreliable. | Use mock clock. Make tests independent. No DB state assumptions. |
| **Test one thing per assertion** | Fail on first assertion, miss other bugs. | Multiple assertions OK if all test same behavior. |
| **No test for error paths** | Production breaks. Nobody caught it. | Test exceptions, rollback, invalid inputs. |
| **Static test data** | Hard to understand. Brittle. | Build test data with clear intent (builders, factories). |

## Test Quality Rules

### Rule 1: One Behavior, One Test

```abap
" BAD: One test, multiple behaviors
METHODS test_travel FOR TESTING.
  " Creating, validating, and pricing in one test
  DATA(travel) = zcl_travel_factory=>create( 'DEST' ).
  cl_abap_unit_assert=>assert_not_initial( travel ).
  
  DATA(valid) = zcl_travel_validator=>validate( travel ).
  cl_abap_unit_assert=>assert_true( valid ).
  
  DATA(price) = zcl_price_calculator=>calculate( travel ).
  cl_abap_unit_assert=>assert_equals( act = price exp = 2400 ).
ENDMETHODS.

" GOOD: One test per behavior
METHODS test_create_travel FOR TESTING.
  DATA(travel) = zcl_travel_factory=>create( 'DEST' ).
  cl_abap_unit_assert=>assert_not_initial( travel ).
ENDMETHODS.

METHODS test_validate_valid_travel FOR TESTING.
  DATA(travel) = TEST_DATA=>valid_travel( ).
  cl_abap_unit_assert=>assert_true( zcl_travel_validator=>validate( travel ) ).
ENDMETHODS.

METHODS test_calculate_price FOR TESTING.
  DATA(travel) = TEST_DATA=>travel_with_price_factors( base = 1000 qty = 2 country = 'DE' ).
  cl_abap_unit_assert=>assert_equals( act = zcl_price_calculator=>calculate( travel ) exp = 2400 ).
ENDMETHODS.
```

### Rule 2: Name Tests by Intent

```abap
" BAD: Vague name, doesn't describe test
METHODS test1 FOR TESTING.
METHODS test_it FOR TESTING.
METHODS test_logic FOR TESTING.

" GOOD: Describes expected behavior
METHODS test_rejects_missing_status FOR TESTING.
METHODS test_price_country_factor FOR TESTING.
METHODS test_create_invalid_date FOR TESTING.
METHODS test_auth_denies_non_mgr FOR TESTING.
```

## Minimum Coverage Expectations

```
Critical domain logic      → >80% branch coverage
Business rules/validations → >75% branch coverage
Integration/adapter layer  → >50% coverage (more integration testing)
UI/presentation layer      → >30% unit, mostly E2E testing
```

## Example: Complete Unit Test Class

```abap
CLASS zcl_travel_service_test DEFINITION FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_travel_service.
    DATA mock_repo TYPE REF TO zcl_travel_repo_mock.
    DATA mock_pricing TYPE REF TO zcl_pricing_service_mock.

    METHODS setup.
    METHODS test_create_travel_success FOR TESTING.
    METHODS test_create_invalid_date FOR TESTING.
    METHODS test_create_saves_repo FOR TESTING.
    METHODS test_authorization_denied FOR TESTING.
ENDCLASS.

CLASS zcl_travel_service_test IMPLEMENTATION.
  METHOD setup.
    mock_repo = NEW zcl_travel_repo_mock( ).
    mock_pricing = NEW zcl_pricing_service_mock( fixed_price = 2400 ).
    cut = NEW zcl_travel_service( mock_repo, mock_pricing ).
  ENDMETHOD.

  METHOD test_create_travel_success.
    DATA(travel_id) = cut->create_travel(
      agency_id = '001'
      destination = 'PARIS'
    ).
    cl_abap_unit_assert=>assert_not_initial( travel_id ).
  ENDMETHOD.

  METHOD test_create_invalid_date.
    TRY.
      cut->create_travel(
        agency_id = '001'
        destination = 'PARIS'
      ).
      cut->create_travel(
        agency_id = '001'
        destination = 'PARIS'
        start_date = '20201231'  " Past date
      ).
      cl_abap_unit_assert=>fail( 'Expected exception for past date' ).
    CATCH cx_invalid_date.
      " Expected
    ENDTRY.
  ENDMETHOD.

  METHOD test_create_saves_repo.
    cut->create_travel( agency_id = '001' destination = 'PARIS' ).
    cl_abap_unit_assert=>assert_equals(
      act = mock_repo->save_call_count
      exp = 1
    ).
  ENDMETHOD.

  METHOD test_authorization_denied.
    " Mock user without permission
    mock_repo->set_authorized( abap_false ).
    TRY.
      cut->create_travel( agency_id = '001' destination = 'PARIS' ).
      cl_abap_unit_assert=>fail( 'Expected authorization exception' ).
    CATCH cx_authorization_error.
      " Expected
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
```

## Checklist: Test Coverage

- [ ] Each public method has positive + negative test cases
- [ ] All business rules and validations tested
- [ ] All exception paths tested (invalid input, authorization, external API failure)
- [ ] All authorization checks (global + instance) tested
- [ ] All side effects verified (repository calls, events published)
- [ ] External dependencies mocked (never call real APIs, DBs in unit tests)
- [ ] Tests independent and runnable in any order
- [ ] Test data uses builders/factories for clarity
- [ ] ATC cloning analysis passes (no unwanted test copies)
- [ ] Test names describe behavior, not implementation

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
