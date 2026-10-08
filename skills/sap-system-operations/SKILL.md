---
name: sap-system-operations
description: 'Investigate and operate SAP ABAP systems. Use for production incidents, dumps, jobs, locks, authorization failures, transport problems, object/API research, ADT REST discovery, ADT MCP object creation/activation, SPRO/Customizing tracing, SAP data workbooks, system personality reports, Basis administration, monitoring, profiles, RFC, ICM, and health analysis.'
---

# SAP System Operations and Discovery

| Need | Guide |
|---|---|
| Production incident diagnosis | [Production issues](./references/abap-production-issues.md) |
| Find SAP/custom objects, APIs, transactions | [ABAP research](./references/abap-research.md) |
| ADT endpoint internals | [ADT API discovery](./references/adt-api-discovery.md) |
| Create/activate/test repository objects | [ADT MCP workflow](./references/adt-mcp-object-workflow.md) |
| Basis troubleshooting and administration | [Basis guides](./references/sap-basis-compilation-guides.md) |
| SPRO, IMG, views, configuration storage | [Customizing](./references/sap-customizing.md) |
| Reproducible SAP data analysis | [Data workbook](./references/sap-data-workbook.md) |
| System inventory and health narrative | [System personality](./references/sap-system-personality-report.md) |

## Remote Workspace Routing

Use the official SAP ABAP Development Tools for VS Code and the configured `adt-mcp-server/*` tools.

| Landscape | Destination type |
|---|---|
| On-premise or SAP S/4HANA Cloud Private Edition | RFC |
| SAP BTP ABAP environment or SAP S/4HANA Cloud Public Edition | HTTP |

For repository discovery, first resolve the mounted `abap:` workspace destination and enumerate its virtual directory. Do not convert the URI to a Windows path, and do not rely on generic indexed workspace search because remote objects may not be indexed. If directory discovery is insufficient, call ADT MCP object search/source tools for that destination. Ask once when multiple destinations are ambiguous; report a missing mount or connection as the blocker.

Load one workflow guide at a time and preserve evidence, authorization, and operational safety boundaries.

