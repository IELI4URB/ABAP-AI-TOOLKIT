# Official ABAP Cloud APIs, Contracts, and Release Guidance

Use this guide for ABAP language-version, API-release, compatibility, release-news, and documentation-source decisions. It is synthesized from SAP Help's ABAP Keyword Documentation and must be rechecked for the target release.

## Documentation Authority Map

| Question | Primary authority |
|---|---|
| Exact ABAP/CDS/BDL/EML syntax and semantics | ABAP Keyword Documentation |
| Cloud development model and lifecycle | ABAP Cloud Guide |
| RAP architecture and end-to-end development | RAP Guide |
| CDS/data-model architecture | ABAP Data Models Guide |
| Integration protocols and communication management | ABAP Integration and Connectivity Guide |
| Analytical data models | ABAP Analytics Guide |
| SQLScript implementation | SAP HANA SQLScript Reference |
| Release-specific feature availability | ABAP Release News plus target product/FPS documentation |

Start from [ABAP Cloud Documentation Landscape](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cloud-documentation-landscape?locale=en-US). Do not use one guide as a substitute for another guide's ownership.

## Cloudification Repository Release-State Lookup

Use the [Cloudification Repository Viewer](https://sap.github.io/abap-atc-cr-cv-s4hc/) to check whether an SAP repository object is cataloged for a specific product and release. Treat this as catalog evidence; the target system's ADT API state, compiler, and ATC result remain authoritative for actual consumption.

### Product and Release Selection

| Viewer product | Release handling |
|---|---|
| **SAP Cloud ERP** | `Latest` |
| **SAP Cloud ERP Private** | Select the exact available release, such as `2023 SP1` or `2025 SP0`; do not substitute `Latest` |
| **SAP BTP ABAP Environment** | `Latest` |
| **Partner APIs Only** | Select the partner namespace; no product release is offered |

Normalize shorthand only when the product is already known. For example, `SAP Cloud ERP Private 2023 01` means viewer release `2023 SP1`. If the product or release is ambiguous, ask for it before reporting a status.

### Lookup Procedure

1. Open the viewer and select the exact **SAP Product** and **Release**.
2. Search the exact technical object name, preferably uppercase. Do not rely on a business-term search as final evidence.
3. Select the requested **Object Type**. If none was provided, search all types and report each matching row independently.
4. Select **Released** only when answering a released-API query. If no row is returned, remove the state filter to distinguish another state from a missing object.
5. Match the exact `objectKey` or technical name and object type. A name can have separate records for `BDEF`, `CDS_STOB`, and other types; one released record does not release the others.
6. Record the state, software component, application component, successor information, selected product/release, source URL, and check date.
7. In the target system, confirm ADT **API Release State**, the required release contract and Cloud Development visibility, then run the relevant released-API ATC check.

Do not conclude that an object is unreleased solely from zero filtered results. First check the product, release, exact spelling, object type, state filter, and partner namespace. A `released` catalog row also does not prove that the API supports the required operation; inspect the released contract and object definition.

### Required Response Format

Report a release-state lookup with these fields:

```text
Object: <exact technical name>
Product: <viewer product>
Release: <exact viewer release or N/A>
Object type: <exact type>
State: <released, deprecated, not found, or other returned state>
Software component: <value or N/A>
Application component: <value or N/A>
Successor: <value or none>
Catalog checked: <URL and date>
Target-system verification: <confirmed or still required>
```

Example: for **SAP Cloud ERP Private 2023 SP1**, `I_PRODUCTIONORDERTP` has separate released rows for object types `BDEF` and `CDS_STOB`, both in software component `S4CORE` and application component `PP-SFC`, with no successor listed. This catalog result still requires target-system verification before use.

## ABAP Language Versions

- **ABAP for Cloud Development** is a restricted language version. It restricts both language scope and addressable repository objects.
- A Cloud Development object can consume APIs released for that language version, objects permitted by software-component relationships, and eligible objects in the relevant local/custom software-component boundaries.
- Client isolation is part of the model, including implicit client handling in ABAP SQL and client-safety requirements for AMDP usage.
- **Standard ABAP** has the complete language scope and no API restriction beyond package/software-component access controls. This does not make classic APIs acceptable in an ABAP Cloud-owned design.
- Language version can be explicit or inherited from package/software-component configuration. Verify the effective value on the actual object.

Source: [ABAP Language Versions](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-language-versions-abenabap_language_versions?locale=en-US).

## Release Contracts

Release contract and visibility for a restricted language version are separate classifications.

| Contract | Official purpose | Design consequence |
|---|---|---|
| **C0 - Extend** | Stability of dedicated extension points | Use to prove extensibility, not general API consumption |
| **C1 - Use System-Internally** | Stable public interface for internal consumption | Relevant contract for consuming repository APIs from restricted ABAP language versions |
| **C2 - Use as Remote API** | Stable external/remote contract | External clients must not require adjustment after upgrade; length changes are also restricted |
| **C3 - Manage Configuration Content** | Stable persistence for configuration content | Keys and existing fields remain stable; intended for business configuration tooling |
| **C4 - Use in AMDP** | Stable interface callable from other AMDP methods | No changes or optional additions after release |

Never describe C0 as "internal" or C1 as the name of the Cloud Development language version. For consumption, verify both the contract and visibility.

Sources: [Release Contracts](https://help.sap.com/docs/abap-cloud/abap-keyword/release-contracts?locale=en-US), [Released APIs](https://help.sap.com/docs/abap-cloud/abap-keyword/released-apis?locale=en-US).

## Provider and Consumer Gates

**Release states** (ADT *API State* tab, Properties view — visible only for releasable object types):
- **Released** — public API, usable for stable custom development per its contract.
- **Deprecated** — still usable but should be replaced; deprecation requires selecting one or more **successors** (a released object or a replacing concept). For C2, a **planned decommissioning date** (month/year) may be set.
- **Decommissioned** — no longer for productive use, unsupported; replace with highest priority. On object level currently **restricted to C2 remote APIs**. Using a decommissioned object raises a **syntax warning** pointing to the successor.

Consumer side:
1. Verify API state in the target system, not from naming conventions.
2. Verify the release contract fits the use: extension, internal consumption, remote consumption, configuration, or AMDP.
3. Verify visibility for the consumer's language version.
4. Run **API_USAGE** (*API Release: Usage of Deprecated or Decommissioned Objects*) to find deprecated/decommissioned API and CDS-element references across objects. Part of the `ABAP_CLOUD_DEVELOPMENT_DEFAULT` variant. **Only reported** for referring objects whose language version is **ABAP for Cloud Development** or **ABAP for Key Users**.
5. Inspect public dependencies: released APIs must expose suitable released types and released association/behavior targets where required.

Provider side (when releasing your own APIs):
1. Run **API_CONSISTENCY** before release. It checks release prerequisites, dependencies, allowed annotations, successor rules, and object-specific constraints.
2. Run **API_COMPATIBILITY** after release and before shipment. It checks the current façade against prior **API snapshots** (create via the *Manage API Snapshots* app).
3. Absence of compatibility findings is not evidence when the checking system has no relevant API snapshots.
4. Resolve incompatible changes by restoring the shipped contract. Use exemptions only through explicit expert governance.

All three checks (`API_USAGE`, `API_CONSISTENCY`, `API_COMPATIBILITY`) are part of the `ABAP_CLOUD_DEVELOPMENT_DEFAULT` ATC variant.

Sources: [Released APIs / release states, deprecation, decommissioning, API_USAGE](https://help.sap.com/docs/abap-cloud/abap-development-tools-user-guide/released-apis?locale=en-US), [Contract Checks](https://help.sap.com/docs/abap-cloud/abap-keyword/contract-checks-for-released-apis?locale=en-US), [Consistency Checks](https://help.sap.com/docs/abap-cloud/abap-keyword/consistency-checks-for-released-apis?locale=en-US), [Compatibility Checks](https://help.sap.com/docs/abap-cloud/abap-keyword/compatibility-checks-for-released-apis?locale=en-US).

## High-Impact Compatibility Rules

- Released objects cannot be deleted and must remain released or become deprecated through the supported lifecycle.
- Existing public names, keys, types, cardinalities, parameters, operations, and associations are generally stable; additions are contract- and object-specific.
- C2 remote contracts are stricter than C1; even type-length growth can be incompatible.
- C4 permits no contract changes.
- For released classes/interfaces, public methods and types are stable, new importing/changing parameters must be optional where allowed, and class-based exception behavior must remain compatible.
- For released CDS entities, key shape/order, element types, public association targets/cardinalities, client dependency, and compatibility-controlled annotations are contract surfaces.
- For released RAP BDEFs, CRUD availability, aliases/external names, draft/etag/numbering characteristics, fields, associations, actions/functions/events, parameter/result contracts, mappings, and keys can be compatibility surfaces.
- For released OData contracts, entity sets/types/properties/navigation/operations and semantics annotations are compatibility surfaces; OData V4 remote services also require semantic version handling.

Use the current ATC check documentation for the object type; do not maintain a hand-written allowlist as the sole gate.

## API Design Recommendations

- Prefer a released interface plus private/final implementation and factory when designing class APIs for testability and replacement.
- Public signatures should use released or self-contained types.
- Use class-based, dedicated exceptions; document public contracts with ABAP Doc.
- Deprecation requires a valid released successor where the object type supports it.
- Element-level CDS deprecation must be explicit in each released view when required; inherited metadata alone may be insufficient for API documentation/checks.

## Release News Gate

[ABAP Release News](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-release-news?locale=en-US) groups language changes by ABAP release and maps them to product/kernel releases. Before selecting a new construct:

1. Determine the target product, ABAP release, kernel, and FPS.
2. Read the exact release-news page and the construct's current keyword page.
3. Check language-version availability and API release state independently.
4. Keep guidance version-sensitive until activation/test evidence exists in the target system.

Do not equate "documented in latest" with "available in the user's release."
