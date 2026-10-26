# ADT MCP Servers

Two MCP servers are approved for ABAP development. Use the comparison table to pick the right one, then follow the relevant setup section.

---

## Comparison

| | SAP ADT MCP Server | EPOD ADT MCP Server |
|---|---|---|
| **ID / version** | `com.sap.adt/mcp` v3.62.0 | EPOD v2.10.0 |
| **Status** | SAP-approved (official) | SAP-internal (GLOFINDEFICA) |
| **Host** | ADT for VS Code extension | Eclipse ADT plugin (or standalone) |
| **Port** | `localhost:2236` | `localhost:3000` (configurable) |
| **Auth** | Bearer token (from VS Code preferences) | Bearer token (from Eclipse MCP Server view) |
| **Multi-system** | Yes — ABAP destinations in VS Code workspace | Yes — `systemId` = Eclipse project name |
| **RAP generators** | Yes — create full RAP UI service in one call | No |
| **ATC quickfixes** | Yes — AI-assisted | No |
| **Business services** | Yes — OData service info | No |
| **Element-level edits** | No — full source | Yes — one METHOD block, server merges |
| **Compact DDIC reads** | No | Yes — `path = value` lines |
| **One-call edit** | No — separate lock/write/activate | Yes — `sap_push_source` runs full pipeline |
| **Token efficiency** | Standard | Optimised (see EPOD section) |
| **Repository** | https://github.wdf.sap.corp/adt/com.sap.adt | https://github.tools.sap/GLOFINDEFICA/epod-adt-mcp-updatesite |

**When to use which:**
- Use **SAP ADT MCP** when working in VS Code, generating RAP services, requesting ATC exemptions, or following SAP-standard toolchain.
- Use **EPOD** when working in Eclipse, when token cost matters (large classes, frequent reads), or when fine-grained element-level edits are needed.

---

## SAP ADT MCP Server (`com.sap.adt/mcp`)

### Prerequisites
- ADT for VS Code extension installed and configured
- At least one ABAP destination added to the workspace (see Getting Started in VS Code extension docs)

> **No separate install from MCP Server Gallery needed.** Enable via VS Code preferences only.

### Setup

**Enable the server:**
`VS Code Preferences → search "ADT MCP Server" → enable`
Server starts at `http://localhost:2236/mcp`.

**GitHub Copilot / VS Code Chat:**
1. Configure GitHub Copilot in VS Code (use Hyperspace LLM proxy if no direct license)
2. Enable ADT MCP Server in VS Code preferences
3. Start via `MCP: List Servers` command → find "ADT MCP Server" → Start

**Other MCP clients (Claude Code, Joule Work, Cursor, etc.):**
1. Enable in VS Code preferences (starts server at port 2236)
2. Get Port + Token from `VS Code Preferences → ADT MCP Server`
3. Configure your client:

```json
{
  "mcpServers": {
    "adt": {
      "type": "streamable-http",
      "url": "http://localhost:2236/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

**Consumption guides (internal wiki):**
- Claude Code (VS Code extension or CLI)
- ADT for VS Code
- ADT for Eclipse
- Standalone mode (experimental, internal only)

**Support:** https://github.wdf.sap.corp/adt/adt-ls/discussions

### Capabilities

| Area | What it can do |
|---|---|
| Systems | List available ABAP systems / destinations |
| Objects | Create new ABAP development objects |
| Source | Read, edit, and check source / file contents |
| Activation | Activate ABAP objects |
| Transports | Get relevant transports, create requests, unified diff, assign objects |
| Testing | Run ABAP Unit tests |
| Quality | Run ATC checks, request exemptions, apply AI-assisted quickfixes |
| Runtime | Fetch short dumps, gateway error log, system messages |
| Search | Search repository objects / code, find references |
| Services | Fetch OData business services and service information |
| Generators | Run ABAP generators (e.g. RAP UI service — creates multiple objects in one call) |

### LLM Rules

Add to `AGENTS.md` (global or project-level):

```markdown
# General
- Always use cloud compliant ABAP syntax and APIs
- The package $tmp/zlocal is used for local development. No transports are needed
- Use the adt-mcp-server for creating new ABAP development objects and performing other
  ABAP development tasks like creating RAP applications, running unit tests, activating objects etc
- To find ABAP development objects by name pattern, use the ABAP search objects tool
- To get the URI of an ABAP object in ABAP's virtual filesystem (for reading or editing),
  use the ABAP resolve file URIs tool or the ABAP list AFF files tool for a specific include
- To add or edit ABAP source, use the VS Code editor or the ABAP edit file tool.
  If needed open the editor first using the object's URI in ABAP's virtual filesystem
- Always activate the ABAP Object after editing

## Testing instructions
- ALWAYS run unit tests after adding new tests or changing source code
- You MUST add unit tests to the testclass include which is a dedicated file
```

---

## EPOD ADT MCP Server (v2.10.0)

Eclipse plugin that exposes SAP ABAP systems to MCP-compatible AI clients via an embedded HTTP server. Authentication is handled by the Eclipse ADT framework — no credentials stored or transmitted by the plugin.

```
AI Client  --(HTTP/JSON-RPC)-->  Eclipse Plugin  --(ADT REST API / SNC)-->  SAP System(s)
```

**Two modes:**
- **Eclipse mode** — runs inside Eclipse ADT, reuses existing SNC/SSO session
- **Standalone mode** — runs without Eclipse open, on the ADT for VS Code runtime; adds `sap_system_list_sapgui` and `sap_system_add`

### Requirements

| Item | Minimum |
|---|---|
| Eclipse | 2024-03 with SAP ADT installed |
| Java | 21 (required by ADT bundles `com.sap.adt.communication` and `com.sap.adt.tools.core`) |
| ABAP projects | One or more with active SNC/SSO connections |

### Installation (Eclipse Mode)

Internal GitHub Enterprise serves files only to a signed-in browser session — Eclipse cannot use the URL directly. Install from a local clone:

```bash
git clone https://github.tools.sap/GLOFINDEFICA/epod-adt-mcp-updatesite.git
```

1. Eclipse → **Help > Install New Software...**
2. **Add... > Local...** → select the cloned folder (contains `compositeContent.xml`)
3. Select **EPOD ADT MCP Server** → Next → accept licence → Finish
4. Restart Eclipse

To update: `git pull` in the clone, then repeat the install.  
Full guide: `install/eclipse.md` in the cloned repo.

### Setup

**1. Open the MCP Server view**
`Window > Show View > Other... > ABAP MCP Server`

**2. Connect projects**
Click **Connect All** or select a project and click **Connect** (reuses ADT session — no password).

**3. Start server**
Click **Start Server** → server starts on `http://127.0.0.1:3000/mcp`.
Copy client config block (with bearer token) via the **Copy client config** button.

**4. Configure client**

```json
{
  "mcpServers": {
    "abap-adt": {
      "type": "streamable-http",
      "url": "http://127.0.0.1:3000/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

Claude Code:
```bash
claude mcp add --transport http --scope user epod-abap-mcp http://127.0.0.1:3000/mcp --header "Authorization: Bearer <token>"
```

**5. Verify**
```
GET http://127.0.0.1:3000/health
```

**Preferences:** `Window > Preferences > ABAP MCP Server` — port, auto-start, security log level.  
Token survives Eclipse restart. **Regenerate token** button invalidates old token immediately.

### Multi-System Routing

Pass `systemId` (= Eclipse project name) to route to the right system:

```json
{ "query": "ZCL*", "systemId": "DEV_001" }
```

| Scenario | Behaviour |
|---|---|
| Single system | `systemId` optional; auto-routed |
| Multiple systems | `systemId` required; omitting returns error listing available systems |

Call `sap_list_systems` to see connected systems and their access modes.

### Access Modes

Each system is **write** (default) or **read-only** (toggle in the ABAP MCP Server view). Mode persists across restarts.

**11 write tools refused on read-only:**
`sap_push_source` · `sap_push_source_from_file` · `sap_push_element` · `sap_push_message` · `sap_push_fields` · `sap_create_object` · `sap_activate` · `sap_lock` · `sap_unlock` · `sap_transport_create` · `sap_transport_release`

### Token Efficiency

| Pattern | Detail |
|---|---|
| Member list without source | `sap_object_members` returns a 2 000-line class in ~300 tokens |
| Element-level read/write | Pull one METHOD block; server merges it back — model never holds the full class |
| One-call edit | `sap_push_source` runs lock → write → unlock → activate in a single call |
| Compact DDIC | Data element / domain / table type as `path = value` lines (BUKRS: 733 bytes vs 2 377 as ADT XML) |
| One-call quality check | `sap_check_object` runs syntax + ATC + ABAP Unit in one call, returns findings only |
| No silent fallbacks | Tool states any fallback explicitly or returns an error |

### Tool Reference (33 Tools)

#### Search & Navigation

| Tool | Description |
|---|---|
| `sap_search_object` | Search by name pattern and/or object type |
| `sap_object_structure` | Structure, metadata, includes, source URLs |
| `sap_object_members` | Members of a class/interface/program/function group — name, kind, visibility, include — no source. `includeLocal=true` adds local and test classes |
| `sap_usage_references` | All where-used references (parsed JSON) |
| `sap_element_info` | Resolve to signature, type, and documentation |
| `sap_object_versions` | Version history (compact): number, date, author, transport, request text |
| `sap_object_diff` | git-style unified diff between two versions. No version numbers → active vs newest transported. `element` limits to one member |
| `sap_compare_systems` | Compare same object across two connected systems. DDIC: one line per differing field. Message class: one line per differing message |
| `sap_inactive_objects` | List currently inactive (not yet activated) objects |

#### Read & Write Source

| Tool | Description |
|---|---|
| `sap_pull_source` | Read source into context. `element=<member>` returns one METHOD block. `includeType`: `main` (default), `definitions`, `implementations`, `macros`, `testclasses`, `all`. DDIC as `path = value` lines. Message class: one line per message |
| `sap_pull_source_to_file` | Same as above but writes to a local file (preferred for large objects) |
| `sap_push_source` | Write source to SAP — single call: lock → write → unlock → activate. `testclasses` creates the include if missing |
| `sap_push_source_from_file` | Save a local file back to SAP through the same one-call pipeline |
| `sap_push_element` | Write one member block; server merges into full source. CLAS and INTF |
| `sap_push_fields` | Change fields of a data element, domain, table type, or table/structure. `path = value` format. Adds/removes fixed values, secondary keys, key components |
| `sap_push_message` | Write one or more messages into an existing message class. Server reads, merges, writes back |
| `sap_pretty_print` | Format ABAP source through ADT pretty-printer. Returns plain text |

#### Lifecycle

| Tool | Description |
|---|---|
| `sap_lock` | Lock object for editing (returns lock handle). Includes DDIC and type group |
| `sap_unlock` | Release lock |
| `sap_activate` | Activate one or several objects in one call (`objects` parameter) |
| `sap_create_object` | Create: CLAS, INTF, PROG, FUGR, FUNC, DTEL, DOMA, TABL, STRU, TTYP, MSAG, or CDS-family (DDLS, DDLX, SRVD, DCLS, DDLA). Reads back DDIC objects to verify. Runs name + transport checks before create |

#### Transport Management

| Tool | Description |
|---|---|
| `sap_transport_of_object` | Find which transport an object is assigned to |
| `sap_transport_list` | List transport requests; filter by status / owner |
| `sap_transport_create` | Create a new transport request |
| `sap_transport_release` | Release a transport request |

#### Quality, Testing & Runtime

| Tool | Description |
|---|---|
| `sap_syntax_check` | Syntax check with line-numbered errors/warnings. `source` checks unsaved text for each reporter type |
| `sap_run_unit_test` | Execute ABAP Unit tests; return pass/fail |
| `sap_atc_run` | Run ATC checks; return findings. Without variant uses system default |
| `sap_check_object` | **Syntax + ATC + ABAP Unit in one call.** Findings only. `coverage=true` adds statement coverage |
| `sap_run_class` | Run a class implementing `IF_OO_ADT_CLASSRUN` (ABAP console / F9) |
| `sap_short_dumps` | List short dumps (ST22), newest first. Filters: user, runtimeError, objectName, package, from, to. `maxDumps` default 100 / max 500. `group=true` groups by error + frame with count |
| `sap_analyze_short_dump` | Read one dump by ID: header, termination point, source with failing line marked, call stack, variables. Typically 480–4 298 chars |

#### Systems

| Tool | Description |
|---|---|
| `sap_list_systems` | List connected systems with access mode |

**Standalone-only:** `sap_system_list_sapgui` · `sap_system_add`

### Supported Object Types

`CLAS` · `INTF` · `PROG` · `FUGR` · `FUNC` · `TABL` · `STRU` · `DDLS` · `DTEL` · `DOMA` · `SRVD` · `DDLX` · `DCLS` · `DDLA` · `SRVB` · `TTYP` · `ENQU` · `MSAG` · `BDEF` · `TYPE`

### Protocol

| Property | Value |
|---|---|
| MCP version | 2024-11-05 |
| Transport | Streamable HTTP |
| Messaging | JSON-RPC 2.0 |
| Session | `Mcp-Session-Id` header |

| Endpoint | Method | Purpose |
|---|---|---|
| `/mcp` | POST | JSON-RPC (initialize, tools/list, tools/call) |
| `/mcp` | GET | SSE stream |
| `/mcp` | DELETE | Close session |
| `/health` | GET | Server status |
