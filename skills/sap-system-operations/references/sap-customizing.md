---
name: sap-customizing
description: 'Trace SAP Customizing and SPRO configuration to IMG activities, transactions, maintenance views, view clusters, base tables, domains, and stored values. Use for SPRO paths, configuration tables, maintenance objects, and reverse lookup from table to IMG activity.'
---

# SAP Customizing Discovery

SAP Help baseline: https://help.sap.com/docs/SAP_S4HANA_CLOUD

Use this skill as the SPRO-to-storage router. Load only the relevant procedure from [the complete Customizing trace reference](./sap-customizing/references/customizing-trace-reference.md).

## Workflow

1. Establish landscape, client, application area, and whether the starting point is an IMG label, transaction, view, cluster, or table.
2. Use SAP metadata relationships rather than guessing tables from names.
3. Follow the matching lookup procedure in the reference.
4. Distinguish configuration definition from client-dependent stored values.
5. Report the IMG path, maintenance object, base storage, keys, and evidence gaps.

## Reference Routing

| Starting point | Procedure |
|---|---|
| IMG/SPRO description | Find activity by description |
| Table or view | Reverse lookup to SPRO activity |
| Activity ID | Find SPRO menu path |
| View cluster | Resolve cluster to views and tables |
| Coded field value | Domain value lookup |

## Safety

- Treat configuration reads as landscape- and client-specific.
- Do not recommend direct table updates; use supported maintenance activities or APIs.
- Verify authorization and transport/client behavior before proposing changes.

