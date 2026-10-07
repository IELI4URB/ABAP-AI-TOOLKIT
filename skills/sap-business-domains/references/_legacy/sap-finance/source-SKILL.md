---
name: sap-finance
description: 'SAP Finance guidance for S/4HANA ABAP solutions. Use for general ledger, AP, AR, asset accounting, closing, tax, payments, reconciliation, Universal Journal, posting controls, FI integrations, and Finance-related extensions.'
metadata:
  version: 3.0.0
  tags: sap finance fi gl ap ar closing reconciliation
---

# SAP Finance

Use this skill as the Finance domain owner. Load only the relevant file under `references/`; prior governance is preserved in [the domain entry-point reference](./references/domain-entrypoint-reference.md).

## Workflow

1. Establish landscape, company/ledger context, process, document lifecycle, controls, and volume.
2. Verify posting, reconciliation, authorization, audit, and cross-module boundaries.
3. Read only the matching process or released-object reference.
4. Add at most two technical companion skills for the active phase.
5. Validate business controls, data integrity, performance, and operational recovery.

## Gates

Do not recommend direct persistence changes or unverified APIs. Preserve document balance, account determination, period controls, auditability, and reconciliation. Distinguish business-known objects from released technical contracts.
