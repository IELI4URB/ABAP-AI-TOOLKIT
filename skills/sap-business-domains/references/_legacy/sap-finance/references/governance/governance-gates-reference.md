# Governance Gates Reference

Domain: SAP Finance
Primary skill: sap-finance

## Mandatory Gate Sequence

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

## SAP Help Evidence Links

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
