---
name: abap-security-hardening
description: >-
  Security hardening for SAP ABAP Cloud. Covers input validation, SQL injection prevention (parameterized queries, CL_ABAP_DYN_PRG), RAP authorization (global/instance/field-level), secrets management via Communication Arrangements and Destination Service (NOT hardcoded), sensitive data protection, audit trails, hashing and encoding, and ABAP Cloud security constraints (no EXEC SQL, no EXECUTE IMMEDIATE). Triggers: security, SQL injection, input validation, authorization, AUTHORITY-CHECK, secrets, credential, sensitive data, PII, audit, encryption, hashing, CL_ABAP_DYN_PRG, communication arrangement.
metadata:
  version: 2.1.0
  tags: abap security authorization sql-injection secrets abap-cloud input-validation encryption hashing
---

# Security Hardening for ABAP Cloud

Expert guide for building secure applications — input validation, SQL injection prevention, authorization, and secrets management.

**Golden rule: Never trust input. Always check authorization (not just UI). Never hardcode secrets. Use Communication Arrangements for all credentials. EXEC SQL and EXECUTE IMMEDIATE are FORBIDDEN in ABAP Cloud.**

Reference files:
- `references/security-patterns.md` — complete security patterns with code and checklists

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

## ABAP Cloud Security Constraints

| Feature | Status | Correct Alternative |
|---|---|---|
| `EXEC SQL` / `ENDEXEC` | FORBIDDEN | Use ABAP SQL with `@` host variables |
| `EXECUTE IMMEDIATE` | FORBIDDEN (HANA SQLScript only) | Use ABAP SQL or AMDP |
| Hardcoded credentials | FORBIDDEN (by policy) | Communication Arrangement + Destination |
| `CL_HTTP_CLIENT` | NOT released | Use `CL_WEB_HTTP_CLIENT_MANAGER` |
| String concatenation in WHERE | DANGEROUS | Use parameterized queries or `CL_ABAP_DYN_PRG` |

---

## SQL Injection Prevention

```abap
" SAFE: Static ABAP SQL with host variables (automatic escaping)
SELECT * FROM ztravel WHERE destination = @lv_dest INTO TABLE @lt_result.

" SAFE: Dynamic SQL with validation — validate the value, then use THAT value in the WHERE clause
cl_abap_dyn_prg=>check_whitelist_str(
  val       = lv_dynamic_where_value
  whitelist = cl_abap_dyn_prg=>ws_alpha_numeric ).

" Build and use the validated value
DATA(lv_where) = |STATUS = '{ lv_dynamic_where_value }'|.
SELECT * FROM ztravel WHERE (lv_where) INTO TABLE @lt_result.

" FORBIDDEN in ABAP Cloud:
" EXEC SQL ... ENDEXEC
" EXECUTE IMMEDIATE '...'
" String concatenation: 'WHERE x = ''' && user_input && ''''
```

---

## Secrets Management (Correct Pattern)

```abap
" CORRECT: Use Communication Arrangement (credentials managed by admin)
DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
  comm_scenario = 'Z_MY_EXTERNAL_API' ).
DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
" Credentials (OAuth, cert, basic auth) are in the Communication Arrangement
" Developer code NEVER sees passwords

" WRONG: These classes DO NOT EXIST in ABAP Cloud:
" cl_bcs_api_config => FABRICATED, does not exist
" Direct REST calls to BTP Credential Store => Not the ABAP Cloud pattern
```

---

## Authorization in RAP

```
define behavior for ZI_Travel
  authorization master ( global, instance )
```

- **Global:** Can user access this BO? (`AUTHORITY-CHECK OBJECT`)
- **Instance:** Can user access THIS record? (owner/group check)
- **Field:** Can user see cost field? (feature control)
- **Action:** Can user approve? (action-level auth check)

---

## Data Protection — Hashing and Encoding

For sensitive data that must be stored (e.g. checksums, API secret verification):

```abap
" SHA-256 hash using CL_ABAP_MESSAGE_DIGEST
DATA(lo_digest) = cl_abap_message_digest=>get_instance( algorithm = 'SHA-256' ).
lo_digest->update( data = cl_abap_conv_codepage=>create_utf_8( )->convert( lv_sensitive_value ) ).
DATA(lv_hash) = lo_digest->get_hash_str_hexa( ).
```

> Never store plaintext passwords or API keys. Use hashed representations or Communication Arrangements (Destination Service) for credentials. For field-level encryption, use SAP Data Custodian or platform encryption — ABAP application code should not implement its own encryption algorithms.

---

## Response Rules
### Security review → Check all 5 domains (input, SQL, auth, secrets, data)
### "Is this secure?" → Identify specific vulnerability + fix
### "How to handle secrets?" → Communication Arrangement pattern (NEVER hardcode)

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
