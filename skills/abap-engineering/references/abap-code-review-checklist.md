---
name: abap-code-review-checklist
description: 'Review ABAP Cloud code during development and before transport. Use for naming and method gates, Clean Core, RAP/CDS quality, OOP, security, performance, ABAP Unit, operability, ATC, rollback, and transport-readiness findings.'
---

# ABAP Cloud Review Checklist

Use [the full checklist](./abap-code-review-checklist/references/full-checklist.md) for release reviews and [the Clean ABAP checklist](./abap-code-review-checklist/references/clean-abap-checklist.md) for code-level checks. Prior entry-point guidance is preserved in [the entry-point reference](./abap-code-review-checklist/references/entrypoint-reference.md).

## Workflow

1. Establish target landscape, changed artifacts, risk, and review phase.
2. Apply Gate 0 constraints during development.
3. Review only relevant sections after each bounded change.
4. Before release, execute the full checklist and report findings by severity.

## Verdict

Block on unreleased dependencies, authorization gaps, contract violations, unbounded data access, missing critical tests, failed ATC/readiness, or absent rollback/operations evidence. Never replace concrete findings with a checklist-only response.

