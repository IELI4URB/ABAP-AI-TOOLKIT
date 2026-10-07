---
name: abap-workflow-automation
description: 'Design and integrate workflow automation for SAP ABAP Cloud. Use for Flexible Workflow, Classic Workflow or SWDD, SAP Build Process Automation, BRFplus decisions, approval routing, agents, work items, My Inbox, process variants, and RAP approval actions.'
metadata:
  version: 2.0.0
  tags: abap workflow approval process-automation sap-build brfplus flexible-workflow abap-cloud
---

# ABAP Cloud Workflow Automation

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

Use this skill as the workflow-technology and approval-flow router. Load only the required part of [the complete workflow reference](./abap-workflow-automation/references/workflow-complete.md).

## Ownership

This skill owns workflow technology selection, approval lifecycle, conditions, agents, work items, and RAP workflow integration. Use `abap-integration-patterns` for remote API connectivity, `abap-iam-authorization` for approver permissions, and `abap-events-and-enhancements` for event-trigger design.

## Workflow

1. Establish landscape, release, process owner, approval states, participants, SLAs, audit needs, and cross-system boundaries.
2. Choose Flexible Workflow, SAP Build Process Automation, or Classic Workflow using availability and complexity, not habit.
3. Inspect BO/action contracts, workflow context schema, agent rules, callbacks, idempotency, and released API status.
4. Read only the matching reference sections below.
5. Define start, approval, rejection, cancellation, timeout, escalation, restart, and compensation behavior.
6. Validate authorization, duplicate triggers, stale work items, partial failures, and end-to-end status reconciliation.

## Reference Routing

| Request | Read sections in `workflow-complete.md` |
|---|---|
| Technology selection | 1, 10 |
| Flexible Workflow setup | 2, 3 |
| Classic Workflow or SWDD | 4 |
| SAP Build Process Automation | 5 |
| BRFplus routing | 6 |
| RAP approval action | 7 |
| My Inbox or work-item handling | 8 |
| Troubleshooting | 9, 11 |

## Mandatory Gates

- Verify technology and API availability for the exact landscape; Classic Workflow guidance is not portable to Public Cloud or BTP ABAP.
- Keep workflow state and BO state transitions explicit, authorized, idempotent, and auditable.
- Verify context fields, callback payloads, keys, optionality, status mappings, and exception paths.
- Do not hardcode credentials, endpoints, approvers, or mutable business policy in implementation code.
- Verify all syntax and released APIs in current SAP Help; report `Syntax confidence: verified` or block production use.
- Release guidance must include workflow tests, authorization, ATC/readiness, rollback/cancellation, monitoring, and support ownership.

## Response Shape

For non-trivial requests, state landscape and process assumptions, technology decision, state model, artifacts and contracts, authorization and recovery, acceptance tests, and operational evidence.

