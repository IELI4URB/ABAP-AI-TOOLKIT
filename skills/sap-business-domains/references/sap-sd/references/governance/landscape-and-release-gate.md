# Landscape and Release Gate

Domain: SAP Sales and Distribution
Primary skill: sap-sd

## Classification Checklist

- Confirm landscape type: ECC, S/4HANA on-premise, S/4HANA Public Cloud ABAP Cloud, or BTP ABAP.
- Confirm extensibility model constraints for the landscape.
- Confirm allowed API and CDS usage model.

## Public Cloud and BTP ABAP Rules

- Released APIs and released CDS artifacts only.
- Upgrade-safe extension points only.
- No recommendation that depends on unreleased technical objects.

## On-Premise Rules

- Classic options may exist, but prefer released and future-safe patterns.
- Document any deliberate use of classic alternatives and the risk rationale.

## Release Verification Evidence

For each recommended object record:
- object_type
- object_name
- release_state
- verification_source
- landscape_scope
- status (verified or unverified)

## Stop Conditions

Stop implementation guidance and request clarification when:
- landscape is unknown,
- release state cannot be validated for required objects,
- recommendation would violate clean core constraints.

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
