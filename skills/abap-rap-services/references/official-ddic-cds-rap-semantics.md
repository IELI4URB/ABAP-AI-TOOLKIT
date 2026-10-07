# Official DDIC, ABAP CDS, and RAP Semantics

Use this guide before choosing persistence, CDS entity type, RAP business-object shape, behavior contract, or EML transaction flow.

## ABAP Dictionary (DDIC)

ABAP Dictionary is the persistent repository for global type metadata and database-table definitions. Its principal objects include data elements, domains, structures, table types, database tables, tuning objects, lock objects, and search helps.

- Data elements carry elementary/reference typing plus semantics such as texts and documentation. Domains can centralize technical properties and value ranges, but ABAP programs do not type directly against domains.
- Structures and table types are global ABAP types. DDIC data types exist in AS ABAP, not as database types.
- A DDIC database table describes a physical standard-database table and also acts as a structured ABAP type. Every database table has a primary key.
- Table changes may require database adjustment and can invalidate foreign-key consistency. Run a where-used analysis before changing shared data elements/domains and assess row volume and conversion cost.

Sources: [ABAP Dictionary](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-dictionary-ddic?locale=en-US), [DDIC Data Types](https://help.sap.com/docs/abap-cloud/abap-keyword/ddic-data-types?locale=en-US), [DDIC Database Tables](https://help.sap.com/docs/abap-cloud/abap-keyword/ddic-database-tables?locale=en-US).

## DDIC Activation and Dependency Handling

- Activation creates/updates a DDIC runtime object (nametab) with an activation timestamp.
- Dependent DDIC objects are activated immediately. Dependent ABAP programs/dynpros are regenerated when used and during target-system transport processing.
- A failed dependent activation can leave objects **partially active**. Inspect the detailed activation log; activate dependent objects first, then the originally changed type.
- Use mass activation for interdependent object sets and transports; it determines ordering and can resolve semantic dependency cycles stepwise. Technical cycles in runtime objects remain invalid.
- A successful activation of the changed type does not prove all ABAP consumers remain syntactically valid; run syntax/ATC/tests on affected consumers.

Source: [Activating ABAP Dictionary Types](https://help.sap.com/docs/abap-cloud/abap-keyword/ddic-activating-abap-dictionary-types?locale=en-US).

## ABAP CDS Object Model

CDS source code is transported; CDS entities are created from activated source in the target system. Each entity has a globally unique name and provides a structured type/signature with metadata, elements, optional parameters, and exposed associations.

Choose explicitly among:

- **Table entity:** CDS-native database table.
- **View entity:** SQL-based reusable persistent entity and preferred modern view form.
- **Projection view:** service/consumer-specific adaptation of a projected entity.
- **Aspect:** reusable elements/calculations.
- **Table function:** tabular result implemented by AMDP.
- **External entity:** access to external database data where supported.
- **Hierarchy:** hierarchy entity usable by ABAP SQL.
- **Custom entity:** runtime implemented manually.
- **Abstract entity:** type-only entity without database artifact.
- **CDS simple/enumerated type and scalar function:** reusable type/calculation contracts.

CDS DDIC-based views are obsolete and were superseded by CDS view entities. Use them only for constrained legacy maintenance; do not select `DEFINE VIEW` for new design.

Sources: [ABAP CDS](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-core-data-services-abap-cds?locale=en-US), [CDS Data Definitions](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-data-definitions?locale=en-US), [DDIC-Based Views (Obsolete)](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-cds-ddic-based-views-obsolete?locale=en-US).

## CDS Type and Access Boundaries

- Persistent entities can be read through ABAP SQL and used as CDS data sources; transient entities are type contracts without that general read/data-source behavior.
- CDS entities can type ABAP data but cannot be used as DDIC substructures/includes or DDIC table-type row types.
- DDL source/entity names become stable after activation; renaming is not an ordinary refactor.
- Metadata extensions, annotation definitions, DCL, service definitions, and DDL use distinct source/object types and editors.
- Access control applies to the **entry-level entity directly read by ABAP SQL**. It is not automatically inherited when a protected entity is wrapped by another CDS entity.
- Evaluate DCL on every exposed entry point and do not assume interface-view DCL protects a projection/wrapper consumer.

## RAP Business Object Invariants

- A RAP BO is composed of CDS data model, behavior, implementation/provider, and optional business service; it is not itself one repository object.
- A BO has exactly one root entity. Child entities require composition plus an exposed to-parent association; each child has exactly one parent.
- A root entity can have no more than one BDEF. The BDEF references the root and defines transactional behavior and consumer/provider communication.
- Managed BOs receive all or part of standard behavior and transactional buffering from the managed provider. Unmanaged BOs require the implementation to supply behavior and buffer semantics.
- BDEF-derived types are the contract between RAP providers and consumers. Inspect generated types instead of guessing table/component shapes.
- RAP business services expose read or transactional access; EML consumes BOs inside AS ABAP.

Sources: [RAP Business Objects](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-rap-business-objects?locale=en-US), [Behavior Definitions](https://help.sap.com/docs/abap-cloud/abap-keyword/rap-behavior-definitions?locale=en-US), [ABAP for RAP BOs](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-for-rap-business-objects?locale=en-US).

## Transactional Phase Rules

Always check the exact handler/saver-method restrictions for the target release.

- Interaction plus early save form the modify transactional phase; late save is the save transactional phase.
- Direct database modifications are reserved for the allowed late-save context. Writing earlier can split the SAP LUW and persist inconsistent data.
- In RAP-owned transactional contexts, `COMMIT WORK` and `ROLLBACK WORK` are not allowed.
- Do not leave transactional phases with ordinary `RAISE EXCEPTION` where prohibited; use RAP failure/reporting contracts.
- `RAISE ENTITY EVENT` belongs in allowed save-phase contexts, normally saver `save`/`save_modified` according to the event and release.
- Contract violations can fail ABAP Unit tests and appear in ADT's ABAP Contract Check Violations feed.
- Every changed instance requires the correct lock/concurrency strategy.

Source: [Restrictions in Transactional Phases](https://help.sap.com/docs/abap-cloud/abap-keyword/restrictions-in-transactional-phases?locale=en-US).

## EML Gate

Before writing EML, verify operation, entity alias, key type, `%control`, input form, result type, and response parameters from the actual BDEF-derived types. Account explicitly for `MAPPED`, `FAILED`, and `REPORTED`; use `IN LOCAL MODE` or privileged variants only where their documented authorization/feature behavior is intended.

Source: [Common EML Statements and Operands](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-eml-common-eml-statements-and-operands?locale=en-US).
