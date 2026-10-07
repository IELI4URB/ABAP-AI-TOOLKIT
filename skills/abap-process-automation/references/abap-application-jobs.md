---
name: abap-application-jobs
description: 'Design, implement, schedule, and operate Application Jobs in SAP ABAP Cloud. Use for IF_APJ_DT_EXEC_OBJECT, IF_APJ_RT_EXEC_OBJECT, job catalogs, job templates, parameters, recurring or event-based scheduling, CL_APJ APIs, batch processing, Application Jobs monitoring, and SM36 or SM37 replacement.'
metadata:
  version: 2.0.0
  tags: abap application-jobs scheduling background batch monitoring abap-cloud
---

# ABAP Cloud Application Jobs

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

Use this skill as the background-processing router. Load only the relevant part of [the complete Application Jobs reference](./_legacy/abap-application-jobs/references/jobs-complete.md).

## Ownership

This skill owns Application Job classes, catalogs, templates, scheduling, runtime lifecycle, and job monitoring. Use `abap-error-handling-resilience` for general exception and logging policy and `abap-performance-optimization` for deeper batch-volume analysis.

## Workflow

1. Establish landscape, release, workload, frequency, runtime window, restart requirements, volume, and operator ownership.
2. Inspect job interface signatures, parameter types, persistence boundaries, released APIs, and authorization requirements.
3. Design the class, catalog, template, schedule, package checkpoints, and log correlation as one lifecycle.
4. Read only the matching reference sections below.
5. Define idempotency, cancellation, partial progress, retry/restart, locking, and retention behavior.
6. Validate parameters, empty workload, large volume, concurrent runs, failure recovery, cancellation, and monitoring visibility.

## Reference Routing

| Request | Read sections in `jobs-complete.md` |
|---|---|
| Framework choice and lifecycle | 1, 2 |
| Job class and parameters | 3 |
| Catalog or template | 4, 5 |
| Scheduling | 6 |
| Application Log | 7 |
| Errors and failed status | 8 |
| Monitoring and cancellation | 9 |
| Performance and packaging | 10 |
| End-to-end example | 11 |

## Mandatory Gates

- Use Application Jobs for ABAP Cloud; do not present SM36/SM37 as a cloud implementation path.
- Verify parameter names, data types, ranges, defaults, and runtime conversion against interface contracts.
- Avoid unbounded reads and monolithic transactions; check package size, locks, memory, commits, and restartability.
- Correlate logs to the job run and include actionable business context without exposing sensitive data.
- Verify interfaces, classes, and syntax for the target release; report `Syntax confidence: verified` or block production use.
- Release guidance must include authorization, ATC/readiness, load and concurrency tests, rollback/cancellation, monitoring, and runbook evidence.

## Response Shape

For non-trivial requests, state workload assumptions, artifact list, parameter and execution contracts, package/recovery design, logging and monitoring, tests, and release evidence.

