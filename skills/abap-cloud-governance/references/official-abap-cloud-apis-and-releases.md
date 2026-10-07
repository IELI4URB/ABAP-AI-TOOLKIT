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

1. Verify API state in the target system, not from naming conventions.
2. Verify the release contract fits the use: extension, internal consumption, remote consumption, configuration, or AMDP.
3. Verify visibility for the consumer's language version.
4. Inspect public dependencies: released APIs must expose suitable released types and released association/behavior targets where required.
5. Run **API_CONSISTENCY** before release. It checks release prerequisites, dependencies, allowed annotations, successor rules, and object-specific constraints.
6. Run **API_COMPATIBILITY** after release and before shipment. It checks the current façade against prior API snapshots.
7. Absence of compatibility findings is not evidence when the checking system has no relevant API snapshots.
8. Resolve incompatible changes by restoring the shipped contract. Use exemptions only through explicit expert governance.

Sources: [Contract Checks](https://help.sap.com/docs/abap-cloud/abap-keyword/contract-checks-for-released-apis?locale=en-US), [Consistency Checks](https://help.sap.com/docs/abap-cloud/abap-keyword/consistency-checks-for-released-apis?locale=en-US), [Compatibility Checks](https://help.sap.com/docs/abap-cloud/abap-keyword/compatibility-checks-for-released-apis?locale=en-US).

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
