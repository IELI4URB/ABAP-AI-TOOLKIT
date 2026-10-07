# Implementation Eligibility Matrix

Domain: SAP Production Planning and PP/DS
Primary skill: sap-pp

## Matrix

| Need | ECC or On-Premise | Public Cloud or BTP ABAP |
|---|---|---|
| Read data | Classic tables or CDS as allowed | Released CDS views only |
| Write transaction data | BAPIs, function modules, or released APIs as appropriate | Released APIs or RAP business objects only |
| Enhancement | Classic exits or BAdIs may exist | Released extension points only |
| Integration | Classic and modern options | Released APIs, events, communication scenarios and arrangements only |

## Selection Rule

- If two options satisfy business need, choose the one that is released and upgrade-safe.
- Reject any option that cannot pass release verification for the target landscape.

## Evidence Requirement

For chosen option, capture:
- process fit
- release status evidence
- security and authorization impact
- performance impact
- rollback and operational impact

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
