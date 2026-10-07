---
name: abap-unit-testing
description: 'Design and review ABAP Unit tests for ABAP Cloud. Use for CL_ABAP_TESTDOUBLE, CL_OSQL_TEST_ENVIRONMENT, CL_CDS_TEST_ENVIRONMENT, RAP BO tests, isolation, risk level, duration, Given-When-Then, coverage, mocks, test data, and CI execution.'
metadata:
  version: 2.0.0
  tags: abap unit-test test-double osql cds rap coverage
---

# ABAP Unit Testing

Load only the needed pattern from [the ABAP Unit reference](./abap-unit-testing/references/abap-unit-patterns.md). Prior entry-point examples are preserved in [the entry-point reference](./abap-unit-testing/references/unit-testing-entrypoint-reference.md).

## Workflow

1. Identify the behavior contract, dependencies, persistence access, and failure paths.
2. Select interface doubles, OSQL/CDS environments, or RAP test support.
3. Build isolated Given-When-Then tests with valid keys and boundary data.
4. Run focused tests, then relevant regression coverage.

## Gates

- Use SQL/CDS test environments for database-dependent tests.
- Keep test data contract-correct, deterministic, and isolated.
- Test positive, negative, authorization, boundary, and exception behavior appropriate to risk.
- Do not use production data or hidden transaction side effects.
- Treat coverage as evidence of execution, not correctness by itself.

