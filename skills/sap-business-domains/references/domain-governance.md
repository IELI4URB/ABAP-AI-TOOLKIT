# SAP Domain Governance


Shared governance reference for all five SAP business-domain guides (Finance, MM, SD, TM, PP). The content below is canonical from the Finance domain copy. The per-domain legacy copies are structurally identical; they differ only in domain-specific tokens: the `Domain:` / `Primary skill:` lines, the process-lifecycle examples in the gate sequence, the mandatory-bundle primary skill, and the named domain dependency. When applying the gates, substitute your active domain's primary skill (for example `sap-mm`, `sap-sd`, `sap-tm`, or `sap-pp`) for `sap-finance`.


## Governance Gates Reference

Domain: SAP Finance
Primary skill: sap-finance

### Mandatory Gate Sequence

1. Process integrity gate
- Confirm recommendation follows real lifecycle: posting lifecycle, AP/AR, clearing, payment processing, closing, reconciliation, and audit controls.
- Identify status transitions and posting side effects before design.

2. Landscape classification gate
- Classify target as ECC, S/4HANA on-premise, S/4HANA Public Cloud ABAP Cloud, or BTP ABAP.
- If landscape is unclear, stop and request clarification before implementation detail.

3. Released-object verification gate
- Verify all APIs, CDS views, events, and extension points are released for the target landscape.
- Mark unknown release status as unverified.
- Do not present unverified objects as production-safe in Public Cloud or BTP ABAP.

4. Cross-skill requirement gate
- Build mandatory bundle: sap-finance, abap-clean-core-principles, abap-oops-design-patterns, abap-code-review-checklist, abap-performance-optimization.
- Add conditional skills based on interface, security, data modeling, testing, and transport needs.
- Add domain dependency: sap-sd and sap-mm.

5. Implementation eligibility gate
- Map each technical option to landscape-safe alternatives before coding.
- Reject options that violate clean core in Public Cloud or BTP ABAP.

6. Development-phase gate
- Validate controls while coding, not only at final review.
- Re-check process integrity after each major artifact.

7. Definition-of-done gate
- Complete all release, test, observability, and handover checks before production recommendation.

### SAP Help Evidence Links

<!-- sap-help-evidence:added -->

Use these as the authoritative baseline when applying this reference:
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/9d794cbd48c648bc8a176e422772de7e?locale=en-US&state=PRODUCTION&version=2608.500
- https://help.sap.com/doc/7c9e0bbbd1664c2581b2038a1c7ae4b3/2608.500/en-US/FSD_CE2608.pdf
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d?locale=en-US&state=PRODUCTION&version=1
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html?locale=en-US&state=PRODUCTION&version=2608.00

## Landscape and Release Gate

Domain: SAP Finance
Primary skill: sap-finance

### Classification Checklist

- Confirm landscape type: ECC, S/4HANA on-premise, S/4HANA Public Cloud ABAP Cloud, or BTP ABAP.
- Confirm extensibility model constraints for the landscape.
- Confirm allowed API and CDS usage model.

### Public Cloud and BTP ABAP Rules

- Released APIs and released CDS artifacts only.
- Upgrade-safe extension points only.
- No recommendation that depends on unreleased technical objects.

### On-Premise Rules

- Classic options may exist, but prefer released and future-safe patterns.
- Document any deliberate use of classic alternatives and the risk rationale.

### Release Verification Evidence

For each recommended object record:
- object_type
- object_name
- release_state
- verification_source
- landscape_scope
- status (verified or unverified)

### Stop Conditions

Stop implementation guidance and request clarification when:
- landscape is unknown,
- release state cannot be validated for required objects,
- recommendation would violate clean core constraints.

### SAP Help Evidence Links

<!-- sap-help-evidence:added -->

Use these as the authoritative baseline when applying this reference:
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/9d794cbd48c648bc8a176e422772de7e?locale=en-US&state=PRODUCTION&version=2608.500
- https://help.sap.com/doc/7c9e0bbbd1664c2581b2038a1c7ae4b3/2608.500/en-US/FSD_CE2608.pdf
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d?locale=en-US&state=PRODUCTION&version=1
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html?locale=en-US&state=PRODUCTION&version=2608.00

## Cross-Skill Requirement Evaluation Template

Domain: SAP Finance
Primary skill: sap-finance

### Skill Selection Map

List each skill and why it is needed.

Required baseline:
- sap-finance
- abap-clean-core-principles
- abap-oops-design-patterns
- abap-code-review-checklist
- abap-performance-optimization

Conditional skill prompts:
- Data model and CDS: abap-cds-data-modeling
- API and service contract: abap-odata-service-development, abap-api-design-versioning
- Integration: abap-integration-patterns
- Security and authorization: abap-security-hardening, abap-iam-authorization
- Events and enhancement: abap-events-and-enhancements
- Testing and transport: abap-unit-testing, abap-devsecops-transport
- Domain dependency: sap-sd and sap-mm

### Required Output Sections

1. Skill selection map
2. Design-pattern decision
3. Domain risk map
4. Development-phase gates
5. Release-readiness gates

### Acceptance Rule

The requirement evaluation is incomplete if any non-trivial risk area is missing a mapped skill and gate.

### SAP Help Evidence Links

<!-- sap-help-evidence:added -->

Use these as the authoritative baseline when applying this reference:
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/9d794cbd48c648bc8a176e422772de7e?locale=en-US&state=PRODUCTION&version=2608.500
- https://help.sap.com/doc/7c9e0bbbd1664c2581b2038a1c7ae4b3/2608.500/en-US/FSD_CE2608.pdf
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d?locale=en-US&state=PRODUCTION&version=1
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html?locale=en-US&state=PRODUCTION&version=2608.00

## Implementation Eligibility Matrix

Domain: SAP Finance
Primary skill: sap-finance

### Matrix

| Need | ECC or On-Premise | Public Cloud or BTP ABAP |
|---|---|---|
| Read data | Classic tables or CDS as allowed | Released CDS views only |
| Write transaction data | BAPIs, function modules, or released APIs as appropriate | Released APIs or RAP business objects only |
| Enhancement | Classic exits or BAdIs may exist | Released extension points only |
| Integration | Classic and modern options | Released APIs, events, communication scenarios and arrangements only |

### Selection Rule

- If two options satisfy business need, choose the one that is released and upgrade-safe.
- Reject any option that cannot pass release verification for the target landscape.

### Evidence Requirement

For chosen option, capture:
- process fit
- release status evidence
- security and authorization impact
- performance impact
- rollback and operational impact

### SAP Help Evidence Links

<!-- sap-help-evidence:added -->

Use these as the authoritative baseline when applying this reference:
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/9d794cbd48c648bc8a176e422772de7e?locale=en-US&state=PRODUCTION&version=2608.500
- https://help.sap.com/doc/7c9e0bbbd1664c2581b2038a1c7ae4b3/2608.500/en-US/FSD_CE2608.pdf
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d?locale=en-US&state=PRODUCTION&version=1
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html?locale=en-US&state=PRODUCTION&version=2608.00

## Development-Phase and Definition-of-Done Checklist

Domain: SAP Finance
Primary skill: sap-finance

### During Development

- Confirm process lifecycle assumptions remain valid.
- Confirm release eligibility remains valid for each newly introduced object.
- Validate projection size and pushdown opportunities.
- Validate authorization and data exposure effects.
- Validate event and side-effect handling.

### Before Release

- Run clean core and readiness checks.
- Validate unit and integration test evidence.
- Validate observability and supportability design.
- Validate rollback and fallback plan.
- Validate handover notes and operational runbook readiness.

### Definition of Done

A recommendation is production-ready only if all are true:
- Process integrity is preserved.
- Landscape constraints are respected.
- Released-object status is verified for all technical recommendations.
- Security, performance, and operational concerns are explicitly addressed.
- Validation and release-readiness evidence is complete.

### SAP Help Evidence Links

<!-- sap-help-evidence:added -->

Use these as the authoritative baseline when applying this reference:
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/9d794cbd48c648bc8a176e422772de7e?locale=en-US&state=PRODUCTION&version=2608.500
- https://help.sap.com/doc/7c9e0bbbd1664c2581b2038a1c7ae4b3/2608.500/en-US/FSD_CE2608.pdf
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
- https://help.sap.com/whats-new/7d3d11840a6543329e72391cf4d48e2d?locale=en-US&state=PRODUCTION&version=1
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/ee9ee0ca4c3942068ea584d2f929b5b1/1df8b8b1799a4d07899d9fb6c72835cf.html?locale=en-US&state=PRODUCTION&version=2608.00
