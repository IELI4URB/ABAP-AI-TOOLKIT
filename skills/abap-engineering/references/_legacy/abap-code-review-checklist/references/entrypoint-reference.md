---
name: abap-code-review-checklist
description: >-
  **Development-phase and review-phase checklist** for SAP ABAP Cloud Clean Core development. Use DURING development (Gate 0) to enforce naming (≤30 chars), method length (≤20 lines), parameters (≤3), exceptions, and modern language constructs from day 1. Then use AFTER implementation as transport review gate. Covers 8 comprehensive sections: Clean Core compliance (ATC, released APIs), RAP/service design (CDS layering, BDEF quality), architecture/OOP quality (SOLID, DIP, layering), security/authorization (RAP auth, input validation), performance (N+1, CDS pushdown, pagination), ABAP Unit testing (coverage, doubles), operability (logging, naming), and transport readiness (backward compatibility, rollback). Triggers: write code, implement feature, create class, create method, refactor code, code review, review checklist, PR review, transport review, quality gate, review template, approval, merge check, naming standards, method size, parameter count, 30 character limit, clean code, constraint enforcement.
metadata:
  version: 2.2.0
  tags: abap code-review checklist quality clean-core abap-cloud governance development-phase pre-coding
---

# Code Review Checklist for ABAP Cloud — Development & Review Gates

**Dual-Phase Checklist:**
1. **Development Phase (Gate 0 — BEFORE writing code):** Consult [clean-abap-checklist.md](clean-abap-checklist.md) to enforce naming (max 30 chars), method length (≤20 lines), parameter count (≤3), and standards-based code patterns from the first variable declaration.
2. **Review Phase (Transport Gate):** Use this full checklist to verify implementation against 8 review sections before release.

**Critical Rules to Apply While Coding:**
- ✅ Names ≤30 characters (no Hungarian notation, no abbreviations)
- ✅ Methods ≤20 lines (ideally 3-5, focus on one thing)
- ✅ Methods ≤3 IMPORTING parameters (split methods if needed)
- ✅ One output per method: RETURNING > EXPORTING > CHANGING
- ✅ Exceptions, never return codes
- ✅ Modern syntax: NEW, COND, VALUE, SWITCH, FILTER
- ✅ Inline declarations: DATA(x) = ...
- ✅ No magic numbers (all constants defined)
- ✅ No empty if branches (all paths covered)

**Mandatory Performance Gate During Development (continuous):**
- ✅ After each major method/entity, run a micro-check from Section E (no N+1, pushdown opportunity checked, projection minimal, pagination considered, key strategy verified)
- ✅ For traversal-heavy logic (BOM, pegging, where-used), validate algorithm choice (BFS/DFS/topological/Dijkstra), visited-set strategy, and depth guard before continuing
- ✅ If one performance rule fails, fix immediately; do not defer all performance fixes to transport review

**Golden rule:** CRITICAL sections (A, D) must pass with zero findings. HIGH sections (B, C, F) block with major findings. MEDIUM sections (E, G, H) allow approved waivers.

Reference files:
- `clean-abap-checklist.md` — quick development-phase checklist with examples for WHILE-coding guidance
- `full-checklist.md` — complete transport review checklist with verdict criteria and reviewer template

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

## Section Overview

| Section | Priority | Focus |
|---|---|---|
| **A. Clean Core** | CRITICAL | ATC passes, released APIs only, no SAP modifications |
| **B. RAP Design** | HIGH | CDS layering, BDEF quality, service exposure |
| **C. Architecture/OOP** | HIGH | SOLID, DIP, no circular dependencies |
| **D. Security** | CRITICAL | Auth checks, input validation, no SQL injection |
| **E. Performance** | MEDIUM | No N+1, CDS pushdown, pagination |
| **F. Testing** | HIGH | Coverage >80% domain, mocks for externals |
| **G. Operability** | MEDIUM | Meaningful logs, clear naming |
| **H. Transport** | MEDIUM | Backward compatible, rollback documented |

---

## Quick Fail Criteria

Any ONE of these = immediate REJECT:
- ATC unreleased API finding (Section A)
- Missing authorization check on sensitive operation (Section D)
- Hardcoded password/credential in code (Section D)
- N+1 query pattern (SELECT in loop) on >10 items (Section E)
- Zero unit tests for domain logic (Section F)

---

## Verdict Template

```
OVERALL: ✅ APPROVED / ⚠️ APPROVED WITH FIXES / ❌ REJECT

A. Clean Core:    ✅/⚠️/❌
B. RAP Design:    ✅/⚠️/❌
C. Architecture:  ✅/⚠️/❌
D. Security:      ✅/⚠️/❌
E. Performance:   ✅/⚠️/❌
F. Testing:       ✅/⚠️/❌
G. Operability:   ✅/⚠️/❌
H. Transport:     ✅/⚠️/❌

REQUIRED FIXES:
• [Line X] [Issue] → [Fix]
```

---

## Response Rules
### Code review request → Walk through ALL 8 sections systematically
### "Is this ready for transport?" → Quick Fail Criteria check first
### Specific finding → Reference the relevant skill for the fix
### "I am still developing" → Apply Gate 0 + Section E micro-check now (do not wait for final review)

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
