---
name: abap-unit-testing
description: 'Design and review ABAP Unit tests for ABAP Cloud. Use for CL_ABAP_TESTDOUBLE, CL_OSQL_TEST_ENVIRONMENT, CL_CDS_TEST_ENVIRONMENT, RAP BO tests, isolation, risk level, duration, Given-When-Then, coverage, mocks, test data, and CI execution.'
metadata:
  version: 2.0.0
  tags: abap unit-test test-double osql cds rap coverage
---

# ABAP Unit Testing

Load only the needed pattern from [the ABAP Unit reference](./_legacy/abap-unit-testing/references/abap-unit-patterns.md). Prior entry-point examples are preserved in [the entry-point reference](./_legacy/abap-unit-testing/references/unit-testing-entrypoint-reference.md).

## Workflow

1. Identify the behavior contract, dependencies, persistence access, and failure paths.
2. Select interface doubles, OSQL/CDS environments, or RAP test support.
3. Build isolated Given-When-Then tests with valid keys and boundary data.
4. Run focused tests, then relevant regression coverage.

## Test Environment Selector

| Code path under test | Environment |
|---|---|
| Direct Open SQL against owned tables only | `CL_OSQL_TEST_ENVIRONMENT` |
| CDS entity reads, projections, associations, or RAP rehydration | `CL_CDS_TEST_ENVIRONMENT` |
| Additional lookup/reference tables not covered by the CDS dependency graph | `CL_OSQL_TEST_ENVIRONMENT` alongside CDS TDF |
| RAP consumer/provider contract where available | RAP BO test doubles/support |
| Authorization/DCL behavior | Separate authorization-focused test with the CDS access-control double |

SAP's official EML scenario-test pattern uses both environments when responsibilities
differ: CDS test doubles provide BO read/persistence dependencies, while OSQL doubles
stub additional tables. Do not create overlapping doubles for the same dependency.

Reference patterns:

- [EML Integration Tests](https://help.sap.com/docs/abap-cloud/abap-rap/eml-integration-tests?locale=en-US)
- [RAP100 EML Unit Test Tutorial](https://developers.sap.com/tutorials/abap-environment-rap100-unit-testing/)
- SAP reference class `/DMO/TC_TRAVEL_M` when installed in the target system.

## EML Scenario Test Pattern

1. Prefer a dedicated global test class for BO-level scenario/integration tests and
  add `"! @testing BDEF:<name>` so tests run from the BDEF. Local behavior-pool
  tests remain suitable for tightly scoped provider logic.
2. In `CLASS_SETUP`, create one CDS environment for the base BO entity, using
  `CREATE_FOR_MULTIPLE_CDS` when multiple entities are under test. Create one OSQL
  environment only for additional non-overlapping tables.
3. In `SETUP`, call `CLEAR_DOUBLES` on each environment and insert deterministic
  lookup/reference data.
4. Execute one EML scenario using `%cid`/`%cid_ref` when create and actions belong to
  the same transaction. Assert `FAILED`, `REPORTED`, and `MAPPED` before commit.
5. Persist with `COMMIT ENTITIES RESPONSES`, then assert commit `FAILED` and
  `REPORTED` separately.
6. Verify persistence by selecting the base BO CDS entity backed by the configured
  CDS doubles.
7. In `TEARDOWN`, call `ROLLBACK ENTITIES`. In `CLASS_TEARDOWN`, destroy every test
  environment.

Additional gates:

- Create environments once per test class; some releases reject multiple instances.
- Use `test_associations = 'X'` only when modeled associations are part of the CUT.
- Keep authorization tests separate from persistence tests. DCL is ignored by
  default in CDS TDF unless an access-control double is configured.
- Use `IN LOCAL MODE` only when intentionally testing provider logic without
  authorization, feature control, or prechecks.
- For managed numbering, assert `MAPPED` and persisted keys before later operations.
- If EML fails without a message, inspect `%fail-cause` before changing behavior.

## Gates

- Use SQL/CDS test environments for database-dependent tests.
- Keep test data contract-correct, deterministic, and isolated.
- Test positive, negative, authorization, boundary, and exception behavior appropriate to risk.
- Do not use production data or hidden transaction side effects.
- Treat coverage as evidence of execution, not correctness by itself.
- A test that fails in setup, activation, or teardown has not established a business
  defect. Classify and repair the test infrastructure first.

