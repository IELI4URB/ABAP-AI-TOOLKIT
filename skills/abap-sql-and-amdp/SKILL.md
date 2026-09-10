---
name: abap-sql-and-amdp
description: >-
  Complete ABAP SQL and AMDP reference for ABAP Cloud. Covers full SELECT syntax with host variables, INSERT/UPDATE/DELETE, aggregations, subqueries, window functions (in ABAP SQL only, NOT CDS DDL), dynamic SQL with CL_ABAP_DYN_PRG, FOR ALL ENTRIES, ABAP Managed Database Procedures (AMDP), CDS Table Functions, and SQL performance patterns. Triggers: SELECT, ABAP SQL, host variable, window function, OVER, PARTITION BY, subquery, EXISTS, FOR ALL ENTRIES, AMDP, table function, dynamic SQL, INSERT, UPDATE, DELETE, MODIFY, aggregation, GROUP BY.
metadata:
  version: 1.0.0
  tags: abap sql amdp abap-cloud select window-functions table-function dynamic-sql
---

# ABAP SQL and AMDP — Complete Reference

Expert guide for all ABAP SQL operations and AMDP (ABAP Managed Database Procedures) in ABAP Cloud.

**Golden rule: Use `@` host variables always. Window functions are ABAP SQL only (NOT CDS DDL). Prefer static SQL; use dynamic only with CL_ABAP_DYN_PRG validation.**

Reference files:
- `references/sql-complete-reference.md` — full syntax catalog with every clause and pattern

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

## ABAP Cloud SQL Constraints

| Feature | Available? | Notes |
|---|---|---|
| `@` host variable prefix | MANDATORY | All variables must use `@` in ABAP SQL |
| `SELECT *` | Allowed but discouraged | Always project specific fields |
| `EXEC SQL` / `ENDEXEC` | FORBIDDEN | Not available in ABAP Cloud |
| `EXECUTE IMMEDIATE` | FORBIDDEN | HANA SQLScript only, not ABAP |
| Window functions (`OVER`) | ABAP SQL only | NOT available in CDS DDL |
| `FOR ALL ENTRIES` | Available | But prefer JOINs or subqueries |
| Dynamic tokens (`WHERE (dyn)`) | Available | Must validate with `CL_ABAP_DYN_PRG` |
| `INTO CORRESPONDING FIELDS` | Available | Standard mapping |
| `OFFSET ... UP TO ... ROWS` | Available (7.51+) | Requires `ORDER BY` |

---

## SELECT Syntax (Complete)

```abap
SELECT [SINGLE] [DISTINCT]
  field1, field2, expression AS alias
  FROM data_source
  [INNER|LEFT OUTER|CROSS] JOIN other ON condition
  WHERE condition
  [GROUP BY field1, field2]
  [HAVING aggregate_condition]
  [ORDER BY field1 [ASCENDING|DESCENDING]]
  [OFFSET @lv_offset]
  [UP TO @lv_rows ROWS]
  INTO [TABLE] @target
  [APPENDING TABLE @target].
```

---

## Window Functions (ABAP SQL ONLY)

**Available in ABAP SQL SELECT statements, NOT in CDS DDL DEFINE VIEW ENTITY.**

```abap
SELECT travel_id, agency_id, amount,
  SUM( @amount ) OVER( PARTITION BY agency_id ) AS agency_total,
  COUNT( * ) OVER( PARTITION BY agency_id ) AS agency_count,
  ROW_NUMBER( ) OVER( ORDER BY amount DESC ) AS price_rank,
  LAG( amount ) OVER( ORDER BY travel_id ) AS prev_amount,
  LEAD( amount ) OVER( ORDER BY travel_id ) AS next_amount
  FROM ztravel
  INTO TABLE @DATA(lt_result).
```

**Available window functions:**
- Aggregates: `SUM`, `COUNT`, `AVG`, `MIN`, `MAX`
- Ranking: `ROW_NUMBER`, `RANK`, `DENSE_RANK`
- Navigation: `LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE`
- Frame: `ROWS BETWEEN x PRECEDING AND y FOLLOWING`

**For CDS-level window logic:** Use AMDP / CDS Table Function instead.

---

## AMDP (ABAP Managed Database Procedures)

```abap
CLASS zcl_travel_amdp DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES if_amdp_marker_hdb.
    
    CLASS-METHODS get_ranked_travels
      IMPORTING VALUE(iv_agency) TYPE agency_id
      EXPORTING VALUE(et_result) TYPE tt_travel_ranked.
ENDCLASS.

CLASS zcl_travel_amdp IMPLEMENTATION.
  METHOD get_ranked_travels BY DATABASE PROCEDURE
    FOR HDB LANGUAGE SQLSCRIPT
    OPTIONS READ-ONLY
    USING ztravel.
    
    et_result = SELECT travel_id, amount,
      ROW_NUMBER() OVER (ORDER BY amount DESC) AS rank
      FROM ztravel
      WHERE agency_id = :iv_agency;
  ENDMETHOD.
ENDCLASS.
```

---

## CDS Table Function

```abap
" CDS definition
define table function ZTF_TravelRanked
  with parameters p_agency : agency_id
  returns {
    travel_id : travel_id;
    amount    : amount;
    rank      : abap.int4;
  }
  implemented by method zcl_travel_amdp=>get_ranked_travels_tf;
```

---

## Dynamic SQL (Safe Pattern)

```abap
" SAFE: Validate with CL_ABAP_DYN_PRG before use
DATA(lv_where) = cl_abap_dyn_prg=>check_whitelist_str(
  val = lv_user_input
  whitelist = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_' ).

SELECT * FROM ztravel
  WHERE status = @lv_where
  INTO TABLE @DATA(lt_result).
```

---

## Response Rules

### SQL syntax question
→ Show complete statement with `@` host variables
→ Note any ABAP Cloud restrictions
→ Show performance alternative if N+1 or SELECT * detected

### Window function question
→ Clarify: ABAP SQL = YES, CDS DDL = NO
→ For CDS context, recommend AMDP table function
→ Show both: ABAP SQL inline and AMDP equivalent

### Dynamic SQL question
→ Always show CL_ABAP_DYN_PRG validation
→ Warn about injection risk
→ Prefer static SQL where possible

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

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Architecture or design trade-offs | decision matrix + constraints + target-state blueprint |
| New implementation | modeling flow + API contract + test strategy |
| Performance issue | hotspot isolation + pushdown/pagination/index strategy |
| Security or authorization | threat points + authorization model + hardening controls |
| Integration behavior | protocol contract + resilience patterns + observability |
| Code review or readiness | findings first + risk ranking + concrete remediation steps |
