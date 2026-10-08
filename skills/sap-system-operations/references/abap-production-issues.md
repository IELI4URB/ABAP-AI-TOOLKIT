---
name: abap-production-issues
description: >-
  Production issue diagnosis and resolution guide for ABAP development. Covers 21 issues across SQL/data-volume, RAP/OData, AIF/HTTP, background jobs, lock conflicts, authorization, transport, and clean-core governance. Landscape-specific guidance (Public Cloud Fiori apps vs OnPrem T-codes) with ABAP fix patterns and prevention rules for every issue. Triggered by short dumps (ST22), Fiori errors, job failures, AIF queue errors, lock failures, auth errors, and transport problems.
metadata:
  author: Senior ABAP Developer
  version: 1.0.0
  tags: abap production troubleshooting abap-cloud s4hana rap odata aif transport sql performance authorization locks clean-core short-dump
---

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

## Purpose

This skill activates when a developer or operations team member reports a production issue in an SAP ABAP landscape. It provides structured **Diagnosis → Root Cause → Fix Pattern → Landscape Notes → Prevention** guidance.

> **Scope boundary:** This skill covers **production incident response**.
> For proactive performance optimization, use `abap-performance-optimization`.
> For clean core architecture guidance, use `abap-clean-core-principles`.

## Trigger Phrases

This skill applies when the user mentions any of the following:

**Short dumps / errors:**
- `ST22`, short dump, runtime error, ABAP dump
- `CX_SY_SQL_TOO_MANY_IN_VALUES`, `TSV_TNEW_PAGE_ALLOC_FAILED`, `TIME_OUT`, `DBIF_RSQL_SQL_ERROR`
- `FOR ALL ENTRIES`, empty driver table, 50K+ entries
- SELECT inside LOOP, N+1 pattern, extreme slowness
- HTTP 500 from OData / Fiori, generic error message
- Draft save failed, COMMIT WORK in RAP, FAILED without REPORTED
- AIF message ERROR, stuck queue, interface backlog
- HTTP 401, 403, 503, CX_WEB_HTTP_CLIENT_ERROR
- Background job FAILED, job stuck ACTIVE
- ENQUEUE_FAILED, document locked, orphaned lock
- sy-subrc = 4 after AUTHORITY-CHECK, SU53, authorization error
- Empty Fiori tiles, no data in app, action buttons missing
- ATC P1/P2 finding, transport blocked, clean core violation
- Activation error after import, downgrade check failed
- Emergency transport needed

## Workflow

1. **Ask for the landscape** if not already stated (Public Cloud / Private Cloud / OnPrem)
2. **Identify the issue category** using the Quick-Finder table below
3. **Open the matching reference file** from `references/` and navigate to the `§N` section
4. **Walk through the Diagnosis table** — note which tools apply to the user's landscape
5. **Share the relevant Fix Pattern code** (exact ABAP code for the fix)
6. **Check Landscape Notes** — several fixes differ significantly between landscapes
7. **Always conclude with Prevention** — what to add to the code review checklist or ATC rules

## Landscape Symbols

| Symbol | Landscape |
|--------|-----------|
| ☁️ | Public Cloud — SAP BTP ABAP Environment / S/4HANA Public Cloud |
| 🔒 | Private Cloud Edition — S/4HANA Private Cloud |
| ⚙️ | On-Premise — S/4HANA or ECC |

> **Key rule:** Tools like `SM12`, `SM21`, `ST05`, `SU53`, `SM37`, `SM50`, `STMS`, `PFCG`, `SE80` are OnPrem/Private Cloud only. In Public Cloud, always name the Fiori App equivalent.

## Quick-Finder Table

| Category | Issue | Reference File → Section |
|---|---|---|
| SQL | Large range / IN clause overflow (`CX_SY_SQL_TOO_MANY_IN_VALUES`) | [sql-data-volume.md](./sql-data-volume.md) → §1 |
| SQL | FOR ALL ENTRIES with empty driver table (silent full-table read) | [sql-data-volume.md](./sql-data-volume.md) → §2 |
| SQL | FOR ALL ENTRIES with 50K+ driver table (timeout / memory dump) | [sql-data-volume.md](./sql-data-volume.md) → §3 |
| SQL | TIME_OUT dump | [sql-data-volume.md](./sql-data-volume.md) → §4 |
| SQL | TSV_TNEW_PAGE_ALLOC_FAILED (memory dump) | [sql-data-volume.md](./sql-data-volume.md) → §5 |
| SQL | N+1 SELECT inside LOOP (extreme slowness at scale) | [sql-data-volume.md](./sql-data-volume.md) → §6 |
| RAP / OData | HTTP 500 from OData / Fiori generic "An error occurred" | [framework-runtime.md](./framework-runtime.md) → §1 |
| RAP / OData | Draft activation failure / action error / FAILED without REPORTED | [framework-runtime.md](./framework-runtime.md) → §2 |
| Integration | AIF message in ERROR status / stuck queue | [framework-runtime.md](./framework-runtime.md) → §3 |
| Integration | HTTP outbound 401 / 403 / 408 / timeout | [framework-runtime.md](./framework-runtime.md) → §4 |
| Jobs | Background job FAILED or stuck ACTIVE | [framework-runtime.md](./framework-runtime.md) → §5 |
| Locks | ENQUEUE_FAILED / lock conflict / document locked | [lock-auth-issues.md](./lock-auth-issues.md) → §1 |
| Locks | RAP draft lock — "Object is already being edited" | [lock-auth-issues.md](./lock-auth-issues.md) → §2 |
| Locks | Database deadlock (`DBIF_RSQL_SQL_ERROR`) | [lock-auth-issues.md](./lock-auth-issues.md) → §3 |
| Auth | AUTHORITY-CHECK sy-subrc = 4 in production | [lock-auth-issues.md](./lock-auth-issues.md) → §4 |
| Auth | IAM / Business Role issues — empty Fiori tiles, no data, buttons missing | [lock-auth-issues.md](./lock-auth-issues.md) → §5 |
| Transport | ATC P1 / P2 finding blocking transport release | [transport-governance.md](./transport-governance.md) → §1 |
| Transport | Activation error after transport import | [transport-governance.md](./transport-governance.md) → §2 |
| Transport | Downgrade check failure | [transport-governance.md](./transport-governance.md) → §3 |
| Transport | Clean core violation after transport (released API / release gap) | [transport-governance.md](./transport-governance.md) → §4 |
| Transport | Emergency transport procedure | [transport-governance.md](./transport-governance.md) → §5 |

## Response Format

For each issue, structure your answer as:

1. **Confirm the root cause** (1–2 sentences)
2. **Diagnosis steps** (as a table with Fiori App and T-Code columns)
3. **Fix Pattern** (ABAP code block with comments)
4. **Landscape Note** (any landscape-specific differences)
5. **Prevention** (what to add to the code review checklist or ATC configuration)

## Important Coding Rules Embedded in This Guide

The reference files contain absolute rules that must be cited when relevant:

- `FOR ALL ENTRIES` without `IS NOT INITIAL` guard → **always a blocker**
- `SELECT` inside `LOOP` → **always a blocker** unless bounded to ≤10 iterations
- `COMMIT WORK` inside a RAP behavior method → **P1 ATC violation**
- `ENQUEUE_*` FMs in ABAP Cloud → **not released; use RAP locking**
- `RAISE EXCEPTION` escaping a RAP method unhandled → becomes HTTP 500
- Any unbounded range table (SELECT WHERE field IN @lt_xxx) without chunking → **must chunk at 5,000**
- FAILED appended without matching REPORTED → generic error shown in Fiori
- Direct SELECT from SAP standard table in ABAP Cloud → P1 ATC violation
- Never modify objects directly in QAS or PRD → always fix in DEV and transport

