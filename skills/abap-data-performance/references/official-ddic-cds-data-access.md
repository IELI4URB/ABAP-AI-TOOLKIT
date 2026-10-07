# Official DDIC/CDS Data-Access and Activation Guide

Use this guide for persistence/type changes that affect activation, database adjustment, SQL access, buffering, and performance.

## Persistence Decision

- DDIC database tables describe physical tables and can also type ABAP structures.
- CDS table entities are CDS-native persistence and require exact target-release verification.
- CDS view entities model reusable SQL-based reads without obsolete DDIC-view generation.
- CDS custom/abstract entities are transient contracts and do not behave like general SQL-readable persistent entities.
- CDS table functions/scalar functions push implementation into AMDP and create database-specific contracts.

Do not select persistence only from syntax convenience. Evaluate lifecycle ownership, update path, client dependency, extension/release contract, data volume, conversion/transport behavior, and access patterns.

## DDIC Table Change Gate

Before changing a database table, data element, domain, structure, or included type:

1. Run where-used across DDIC, CDS, ABAP, interfaces, and persistence consumers.
2. Assess key and semantic-reference impact.
3. Estimate physical database adjustment/conversion cost from row volume and change type.
4. Check foreign-key/check-table consistency risk.
5. Plan activation order and transport sequencing.
6. Validate indexes, buffering/tuning objects, and database-specific behavior.
7. Test rollback/recovery for failed conversion or partial activation.

Source: [DDIC Database Tables](https://help.sap.com/docs/abap-cloud/abap-keyword/ddic-database-tables?locale=en-US).

## Activation Gate

- Activation creates/updates runtime metadata and timestamps.
- Dependent DDIC objects activate immediately; ABAP loads regenerate on use/transport.
- Partially active status means some dependency still uses the previous runtime definition. Inspect activation logs and repair dependents first.
- Use mass activation for related/interdependent sets and transport contents.
- Run syntax/ATC/tests on ABAP consumers even when the DDIC activation itself succeeded.

Source: [DDIC Activation](https://help.sap.com/docs/abap-cloud/abap-keyword/ddic-activating-abap-dictionary-types?locale=en-US).

## CDS Access and Performance

- Persistent CDS entities are potential ABAP SQL data sources; transient entities are not general read sources.
- CDS DCL is applied at the directly accessed entry entity, not inherited automatically from underlying CDS sources.
- DCL adds database filtering work; measure it with representative role-value volume.
- Transport DDL source and activate in the target; the entity metadata/database artifacts are produced there.
- Entity/DDL names become stable once activated, so naming is an API/lifecycle decision.
- Prefer CDS view entities for new CDS views; DDIC-based CDS views are obsolete.

Sources: [CDS Data Definitions](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-data-definitions?locale=en-US), [CDS Access Control](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-access-control?locale=en-US).

## Measurement Contract

For performance guidance, report:

- target database and release
- data and PFCG-role value volumes
- statement/entity actually measured
- projection/filter/order/paging shape
- index/buffer/tuning assumptions
- trace/plan evidence
- cold/warm-cache distinction where relevant
- before/after runtime and resource impact

Do not infer performance from entity type alone.
