---
name: abap-clean-core-principles
description: >-
  Clean Core principles and governance for SAP ABAP Cloud. Covers the 5 principles, correct release state terminology (C0/C1 contracts, Released/Not to Be Released/Deprecated), ABAP language versions (Standard vs Cloud Development), Tier 2 wrapper pattern, A-D maturity model (2025), Key User Extensibility, extension model decision guide, ATC governance (ABAP_CLOUD_DEVELOPMENT_DEFAULT, ABAP_CLEAN_CORE_READINESS), Cloudification Repository Viewer, and Cloud ALM monitoring. Triggers: clean core, released API, C1 contract, language version, wrapper pattern, tier 1, tier 2, extension, ABAP Cloud, upgrade-safe, ATC, clean core check.
metadata:
  version: 2.0.0
  tags: abap clean-core released-api abap-cloud extension wrapper atc governance
---

# Clean Core Principles for ABAP Cloud

Expert guide for SAP Clean Core strategy — released APIs, extension models, governance, and compliance.

**Golden rule: Only consume Released (C1) APIs. Zero modifications to SAP standard. Custom code in isolated packages. ATC enforces compliance — not optional.**

Reference files:
- `references/clean-core-detail.md` — detailed principles, anti-patterns, and extension examples

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

## Release Contracts and States

| Contract | Code | Meaning |
|---|---|---|
| Use in Cloud Development | **C1** | Stable, backward-compatible, safe for ABAP Cloud |
| Use System-Internally | **C0** | Internal SAP use only, can change without notice |

| Release State | Meaning | Can Use? |
|---|---|---|
| **Released** | Stable API for cloud development | YES |
| **Not to Be Released** | Explicitly not intended as external API | NO |
| **Deprecated** | Was released, successor exists, plan migration | YES (but migrate) |
| **Not to Be Released, Stable** | Internal only but interface won't change | NO (not for custom code) |

---

## Mandatory: Never Assume Release State — Always Confirm

Do not infer release status from naming convention alone (e.g. `I_*` prefix, "looks like a VDM interface view"). Naming convention is a weak heuristic, not proof — many `I_*` views are NOT released, and consuming an unreleased object is a hard compile-time block in ABAP Cloud, not a style issue.

Before recommending or consuming any SAP-delivered object (CDS view, class, BAdI, FM wrapper, etc.) as "released"/C1, confirm it via one of these, in order of preference:

1. **In-source annotation (fastest, tool-readable)**: check the object header for an explicit contract annotation, e.g. `@VDM.lifecycle.contract.type: #PUBLIC_LOCAL_API` on CDS views, or `@AbapCatalog.rap.bo.releaseState` / equivalent on other artifact types. If present, this is authoritative. If absent, treat release state as **unconfirmed** — do not assume "released" just because the annotation is missing (older objects may be released through mechanisms that predate this annotation).
2. **ADT UI check (authoritative for objects without a source annotation)**: right-click the object in ADT → **Properties** → **API State** panel, or the release-state badge/icon shown in the object outline/editor. This queries SAP's API State Framework directly and is the ground truth. This is a UI-only signal — it cannot be read via file/source access, so ask the user to check it if you cannot confirm via annotation.
3. **SAP API Business Hub** (https://api.sap.com) — search the object name; if published there with a contract type (C0/C1/C2), that is official confirmation of released status for external/side-by-side consumption.
4. **Empirical compiler test (last resort, but authoritative for the specific consumption path you need)**: attempt the actual consumption (e.g. create the consuming CDS view/AMDP/class) and activate it for real. ABAP Cloud's compiler enforces release-state restrictions at activation time — a real "not released for usage here" error is definitive proof of non-release for that specific usage type (note: release restrictions can be usage-specific, e.g. an object can be released for CDS-to-CDS consumption but explicitly NOT released for AMDP/SQLScript consumption — confirm separately for each consumption mechanism you intend to use).

Do not report an object as "confirmed released" unless one of methods 1–4 was actually performed and its result stated. If none could be performed, explicitly say the release state is **unconfirmed** and name which of the above checks is still outstanding.

---

## ABAP Language Versions

| Version | Where | Restrictions |
|---|---|---|
| **Standard ABAP** | Classic/Tier 3, ECC, S/4HANA classic | None (full syntax) |
| **ABAP for Cloud Development** | Tier 1, BTP ABAP Environment | Restricted: only released APIs, no EXEC SQL, no dynpros |
| **ABAP for Key Users** | Key user apps (Custom Logic) | Further restricted subset |

---

## A–D Clean Core Maturity Model (2025)

| Level | Description | ATC Priority |
|---|---|---|
| **A** | Released objects only (ABAP Cloud compliant) | No errors |
| **B** | Classic but recommended objects | Priority 3 (warning) |
| **C** | Internal SAP objects (managed risk) | Priority 2 (error) |
| **D** | Not-recommended objects/technologies | Priority 1 (blocking) |

---

## Extension Model Decision

| Need | Model | Tools |
|---|---|---|
| Add field, simple logic | **Key User Extensibility** | Custom Fields app, Custom Logic app |
| Full custom BO / complex logic | **Developer Extensibility (Tier 1)** | ADT, RAP, ABAP Cloud |
| Wrap unreleased SAP FM | **API Enablement (Tier 2)** | Standard ABAP wrapper → release as C1 |
| Completely decoupled capability | **Side-by-Side (BTP)** | CAP, Node.js, Python on BTP |

---

## Tier 2 Wrapper Pattern

```
1. Identify unreleased SAP object (e.g. BAPI_GOODSMVT_CREATE)
2. Create wrapper class in STANDARD ABAP (not ABAP Cloud)
3. Release the wrapper with C1 contract
4. Consume from ABAP Cloud (Tier 1) code
5. Run ATC API_CONSISTENCY check on wrapper
6. Retire wrapper when SAP releases official API
```

---

## Response Rules

### "Is this clean core?" → Check: C1 released? ATC passes? No modifications?
### "How do I use unreleased FM?" → Tier 2 wrapper pattern
### "What extension model?" → Decision matrix: Key User → Developer → Side-by-Side

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
