---
name: sap-system-operations
description: 'Investigate and operate SAP ABAP systems. Use for production incidents, dumps, jobs, locks, authorization failures, transport problems, object/API research, ADT REST discovery, SAP ADT MCP Server (com.sap.adt/mcp v3.62.0, VS Code, port 2236, RAP generators, ATC quickfixes, OData service info) or EPOD ADT MCP Server (Eclipse plugin, port 3000, 33 tools, element-level edits, compact DDIC, multi-system routing), SPRO/Customizing tracing, SAP data workbooks, system personality reports, Basis administration, monitoring, profiles, RFC, ICM, and health analysis.'
metadata:
  version: 2.0.0
  tags: sap operations adt mcp production-issues transport basis incidents authorization abap-research
---

# SAP System Operations and Discovery

| Need | Guide |
|---|---|
| Production incident diagnosis | [Production issues](./references/abap-production-issues.md) |
| Find SAP/custom objects, APIs, transactions | [ABAP research](./references/abap-research.md) |
| ADT endpoint internals | [ADT API discovery](./references/adt-api-discovery.md) |
| Create/activate/test repository objects (VS Code ADT extension) | [ADT MCP workflow](./references/adt-mcp-object-workflow.md) |
| SAP ADT MCP Server (`com.sap.adt/mcp`, VS Code) or EPOD ADT MCP Server (Eclipse) — setup, tool reference, multi-system routing | [ADT MCP Servers](./references/adt-mcp-community-servers.md) |
| Compare locked objects and contract dependencies across explicit sibling tasks or other open requests | [Transport task overlap check](./references/transport-task-overlap-check.md) |
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

onal safety boundaries.

