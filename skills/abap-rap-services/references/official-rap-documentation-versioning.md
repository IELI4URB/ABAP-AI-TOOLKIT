# Official RAP Documentation Version Selection

SAP Help publishes the same RAP topic under multiple `version` parameters. Store the guidance once, then store landscape/version differences as a compact matrix. Do not copy one full skill guide per URL.

## Version Keys

Use this URL pattern:

`https://help.sap.com/docs/abap-cloud/abap-rap/<topic>?locale=en-US&version=<version-key>`

| Version key | Displayed SAP Help version | Target landscape | Consumption root |
|---|---|---|---|
| `sap_cross_product_abap` | ABAP Cross-Product | Common RAP concepts and current cross-product baseline | [Consume](https://help.sap.com/docs/abap-cloud/abap-rap/consume?locale=en-US&version=sap_cross_product_abap) |
| `s4hana_cloud` | SAP S/4HANA Cloud Public Edition | Public Cloud current documentation stream | [Consume](https://help.sap.com/docs/abap-cloud/abap-rap/consume?locale=en-US&version=s4hana_cloud) |
| `s4_hana_cloud_pce` | SAP S/4HANA Cloud Private Edition | Private Cloud/PCE current documentation stream | [Consume](https://help.sap.com/docs/abap-cloud/abap-rap/consume?locale=en-US&version=s4_hana_cloud_pce) |
| `s4_hana` | SAP S/4HANA | S/4HANA on-premise documentation stream | [Consume](https://help.sap.com/docs/abap-cloud/abap-rap/consume?locale=en-US&version=s4_hana) |
| `sap_btp` | SAP BTP ABAP environment | BTP ABAP Environment current documentation stream | [Consume](https://help.sap.com/docs/abap-cloud/abap-rap/consume?locale=en-US&version=sap_btp) |

These version keys are moving aliases, not immutable release identifiers. For reproducible decisions, also record the displayed version/release, review date, and target system release/FPS.

The unversioned RAP overview URL currently resolves to `sap_cross_product_abap`. Do not rely on that implicit default in stored evidence; specify the version key explicitly.

## Reviewed Deliverables

Snapshot reviewed on 2026-10-07:

| Version key | Deliverable ID | Build | Consume LOIO | RAP overview LOIO |
|---|---:|---:|---|---|
| `sap_cross_product_abap` | `32800170` | `8557` | `d68d0242690343bfa327bf2413cb469b` | `289477a81eec4d4e84c0302fb6835035` |
| `s4hana_cloud` | `31912690` | `2818` | `d68d0242690343bfa327bf2413cb469b` | `289477a81eec4d4e84c0302fb6835035` |
| `s4_hana_cloud_pce` | `39392659` | `741` | `d68d0242690343bfa327bf2413cb469b` | `289477a81eec4d4e84c0302fb6835035` |
| `s4_hana` | `31939402` | `436` | `d68d0242690343bfa327bf2413cb469b` | `289477a81eec4d4e84c0302fb6835035` |
| `sap_btp` | `31905745` | `8220` | `d68d0242690343bfa327bf2413cb469b` | `289477a81eec4d4e84c0302fb6835035` |

The matching topic LOIO proves conceptual identity, not feature parity. Deliverable/build differences remain authoritative for each landscape.

## Storage Model

Use progressive loading:

1. **Canonical conceptual guide**
   - Keep one synthesized guide per concept, normally grounded in `sap_cross_product_abap`.
   - Example: [RAP consumption selection](./official-rap-consumption-selection.md).
2. **Version matrix**
   - Keep landscape keys, exact URLs, reviewed deliverables/builds, known drift, and verification rules in this file.
3. **Landscape override only when needed**
   - Add a small override reference only if a target version changes behavior, syntax, availability, prerequisites, or release contracts materially.
   - Never duplicate the entire canonical guide for wording-only or link-only differences.
4. **Target-system evidence**
   - Record exact installed release/FPS, API state, syntax/activation result, and relevant release note in the solution or review output.

Suggested override naming when a real difference appears:

`references/rap-version-overrides/<topic>--<version-key>.md`

Each override should contain only:

- target version and reviewed build/date,
- changed/absent features,
- replacement rule or syntax,
- validation evidence,
- links to the target-version pages and release notes.

No override folder is needed while differences fit clearly in this matrix.

## RAP Overview-Topic Drift Observed

All five overview URLs resolve to LOIO `289477a81eec4d4e84c0302fb6835035`, use the same headings, and link to the same ABAP Cloud documentation-landscape child. The common sections cover architecture, evolution, RAP in simple terms, ABAP language version, documentation validity, prerequisites, constraints, and the relationship between RAP and ABAP Cloud.

Reviewed overview URLs:

- [ABAP Cross-Product](https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model?locale=en-US&version=sap_cross_product_abap)
- [SAP S/4HANA Cloud Public Edition](https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model?locale=en-US&version=s4hana_cloud)
- [SAP S/4HANA Cloud Private Edition](https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model?locale=en-US&version=s4_hana_cloud_pce)
- [SAP S/4HANA](https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model?locale=en-US&version=s4_hana)
- [SAP BTP ABAP Environment](https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model?locale=en-US&version=sap_btp)

| Version | Words | Normalized SHA-256 | Material distinction |
|---|---:|---|---|
| ABAP Cross-Product | 794 | `701c873ae10e887ed442f65abcff460950ac429c95cf45411d38e8c1862d013d` | Validity lists Public Cloud, PCE, BTP, and S/4HANA; contains both cloud/on-premise markers |
| BTP ABAP Environment | 775 | `2d6137882fa9881cb091270d13eea7035f7a941bcb6e6646f8f825535842045c` | Validity lists Public Cloud and BTP; cloud-specific links/markers |
| S/4HANA Cloud Public Edition | 754 | `0d6d6ffc0f96f9ac2f1fea16e4de9978742a1b2c6448ae576a27268516501e8a` | Validity lists Public Cloud only; Public Cloud links |
| S/4HANA Cloud Private Edition | 766 | `eadb6f705455e58224faed59112e08d06f7d59362c0c360a375761edf605e4d6` | Validity lists PCE and S/4HANA; on-premise-specific markers/links |
| SAP S/4HANA | 766 | `eadb6f705455e58224faed59112e08d06f7d59362c0c360a375761edf605e4d6` | Byte-equivalent to the reviewed PCE overview content |

These overview differences do not justify separate skill guides. They reinforce the same architecture and ABAP-for-Cloud-Development recommendation while varying product validity and navigation. Keep one canonical architecture/selection guide and verify the target version's prerequisites and constraints pages.

## Consumption-Topic Drift Observed

All five deliverables use the same root and branch LOIOs:

- Consume: `d68d0242690343bfa327bf2413cb469b`
- Business Object Consumption: `637dd6c02945488aaafc6af3efe03919`
- OData Service Consumption: `f2cbcacaf8b74540b0708fc143875bc3`
- Business Event Consumption: `e3446499d68f40db9013b0ad4580e2fe`

All expose the same three branches. Content differs:

| Version | Observed state on 2026-10-07 |
|---|---|
| ABAP Cross-Product | Current baseline including lifecycle stability and C1/C2 release-contract sections |
| BTP ABAP Environment | Root, BO and OData pages align with cross-product; event page includes landscape-specific content |
| S/4HANA Cloud Public Edition | Root aligns with cross-product; branch wording/content has small landscape-specific differences |
| S/4HANA Cloud Private Edition | Root aligns with cross-product; BO/OData/event branches have small landscape-specific differences |
| SAP S/4HANA | Older/shorter content: root omits Lifecycle Stability; BO and OData pages omit explicit Release Contract sections; event page is shorter |

The absence of a section in an older landscape page does not authorize using the latest feature there. Conversely, lifecycle best practices from the cross-product guide remain useful design guidance, but target availability/release state must be verified separately.

## Selection Rules

1. **Identify landscape first.**
   - Public Cloud: `s4hana_cloud`
   - Private Cloud/PCE: `s4_hana_cloud_pce`
   - On-premise S/4HANA: `s4_hana`
   - BTP ABAP Environment: `sap_btp`
2. **Use cross-product only for common architecture.**
   - It is the canonical baseline for skills, not proof that a feature exists in every target.
3. **Verify the target-version topic.**
   - Open the same topic with the target version key.
   - Check whether the relevant section, syntax, wizard, service binding, event mechanism, or contract exists.
4. **Pin the actual product release.**
   - Public/BTP/PCE aliases advance over time.
   - Record the displayed release and exact target system release/FPS.
5. **Check API state and release notes.**
   - Documentation availability, ABAP Cloud visibility, and C0/C1/C2 release contract are separate facts.
6. **Prefer target evidence on conflict.**
   - Target-version Help, system syntax/activation, API-state tools, and target release notes override cross-product assumptions.
7. **Report confidence.**
   - `Verified`: target page/system evidence confirms the recommendation.
   - `Conditional`: cross-product guidance exists but target release evidence is incomplete.
   - `Unsupported`: target documentation/system does not provide the feature.

## Version-Aware Routing

Before loading a RAP implementation or consumption guide, state:

- landscape,
- exact product release/FPS,
- selected SAP Help version key,
- whether the task is provider implementation or consumption,
- required release contract,
- any target-version divergence from the cross-product baseline.

Then load only the needed guide:

- Provider/scenario choice: [RAP implementation selection](./official-rap-implementation-selection.md)
- Consumption channel: [RAP consumption selection](./official-rap-consumption-selection.md)
- BDEF declaration: [RAP behavior definitions](./official-rap-behavior-definitions.md)
- EML/provider ABAP: [ABAP for RAP business objects](./official-abap-for-rap-business-objects.md)
- Handler/saver implementation: [RAP behavior implementation](./abap-rap-behavior-implementation.md)

## Maintenance Rule

When SAP updates a version alias:

1. Resolve metadata for all five version keys.
2. Compare topic LOIO, branch TOC, normalized headings/content hashes, and feature/release sections.
3. Update reviewed deliverable/build/date in this matrix.
4. Update the canonical guide only for common semantic changes.
5. Add or update a compact landscape override only for material target-specific differences.
6. Revalidate links, local active parity, and the shared toolkit.

This avoids token-heavy duplication while retaining landscape correctness and auditability.
