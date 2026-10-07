---
name: sap-system-personality-report
description: 'Generate a SAP System Personality Report covering system identity, custom-code inventory, packages, development activity, inactive objects, dumps, health indicators, functional footprint, and an evidence-based system narrative.'
---

# SAP System Personality Report

SAP Help baseline: https://help.sap.com/docs/SAP_S4HANA_CLOUD

Use [the complete report playbook](./references/report-playbook.md) as an ordered workflow. Load only the current collection step, retaining compact aggregate results between steps.

## Workflow

1. Collect system identity and release facts.
2. Count custom repository objects by supported type.
3. Aggregate package distribution and development timeline.
4. Measure recent transport/developer activity and inactive objects.
5. Collect bounded health indicators such as recent dump trends.
6. Infer functional footprint only from observed packages, objects, and usage evidence.
7. Assemble the report with query limitations, confidence, and missing evidence.

## Rules

- Prefer aggregate queries and bounded date ranges; do not extract unnecessary business data.
- Mark inaccessible tables, authorization gaps, and unsupported metrics explicitly.
- Do not convert object names or package prefixes into confident business conclusions without corroboration.
- Avoid exposing user-sensitive or production-sensitive details beyond the report purpose.
- Keep raw counts separate from interpretation.

## Output

Report system identity, custom-code landscape, package footprint, activity, health, inferred capabilities, evidence quality, and recommended next investigations.
