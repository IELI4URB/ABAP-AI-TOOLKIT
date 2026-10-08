---
name: adt-mcp-object-workflow
description: 'Create, populate, activate, and test ABAP repository objects through the SAP ADT MCP server configured in VS Code. Use whenever the user asks to create ABAP classes, interfaces, CDS views, behavior definitions, service definitions/bindings, tables, RAP objects, application-job artifacts, or other objects directly in a connected ABAP system. Triggers: ADT MCP, create ABAP object, create class, create CDS, create RAP object, create in SAP, connected system, transport request, activate object.'
argument-hint: '[object type, name, package, and destination]'
user-invocable: true
disable-model-invocation: false
---

# ADT MCP Object Workflow

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

Use the already configured SAP ADT MCP server for ABAP repository object creation.
Do not rediscover which extension or MCP server to use on every request.

## Server Selection

1. Use the local MCP endpoint configured by these VS Code settings:
   - `adt.mcpServer.port`
   - `adt.mcpServer.token`
2. Read the settings from `%APPDATA%\Code\User\settings.json` only at runtime.
3. Never print, log, persist, or return the bearer token.
4. Derive the ABAP destination from the active `abap:/repotree-v1/<destination>/...`
   workspace URI. If multiple ABAP destinations are open and the requested target is
   ambiguous, ask the user once. Do not assume that every system is SD9.
5. When native ADT MCP tools are unavailable in the current tool palette, use
   [Invoke-AdtMcp.ps1](../scripts/Invoke-AdtMcp.ps1). Do not probe unrelated MCP
   servers or inspect extensions first.

## Mandatory Development Preflight

Before creating or editing repository objects, confirm once with the user:

1. Destination/system and client.
2. Package and package ABAP language version.
3. Clean Core ownership: Tier 1 Cloud Development or explicitly approved Tier 2.
4. Transport request and development scope.
5. Approved object list and naming convention.
6. Direct ADT MCP development versus an explicitly approved local prototype.

For Tier 1 Clean Core, the package must use **ABAP for Cloud Development**. If it
uses Standard ABAP, stop and ask the user to change or create the correct package.
Standard ABAP is valid only for an explicitly approved Tier 2 wrapper or classic
scope.

Do not create virtual/local ABAP files as a substitute for repository creation.
Create new objects through ADT MCP first, then populate the returned shell through
the ABAP remote filesystem. A local prototype requires explicit user approval or an
unavailable ADT MCP connection plus acceptance that no repository object is created.

## Tool Contract Cache

Stable workflow rules belong in this guide. Runtime MCP input schemas belong in the
local machine cache maintained by `Invoke-AdtMcp.ps1`:

```text
%LOCALAPPDATA%\ADT-MCP\schema-cache\<server-fingerprint>.json
```

Cache only the server name/version, retrieval time, schema fingerprint, tool name,
and input schema. Never cache tokens, authorization headers, passwords, destination
credentials, or call arguments.

- Use `-DescribeTool <tool>` to print one compact cached schema.
- Use `-RefreshSchema` only when the cache is absent, server/version changes, a call
   reports an unknown or missing parameter, or the user explicitly requests it.
- Never print the complete tool catalog merely to inspect one tool.
- Do not refresh schemas just because a new chat starts.

Verified compact baseline:

| Tool | Required input |
|---|---|
| `abap_creation-get_all_creatable_objects` | `destination` |
| `abap_creation-get_object_type_details` | `destination`, `objectType` |
| `abap_creation-run_validation` | `destination`, `objectType`, serialized JSON string `objectContent` |
| `abap_transport-get` | `destination`, `objectName`, `objectType`, `developmentPackage`, `isCreation` |
| `abap_creation-create_object` | `destination`, `objectType`, serialized JSON string `objectContent`, `transportRequestNumber` |
| `abap_activate_objects` | encoded workspace `uris` |
| `abap_run_unit_tests` | encoded workspace `uris` |

Refresh only the targeted runtime schema when a server mismatch proves this baseline
stale.

## Mandatory Creation Sequence

For every new repository object, follow this order:

1. Confirm the approved TSD or explicit scope, target option, naming convention,
   package, object name, and description.
2. Call `abap_creation-get_all_creatable_objects` for the destination.
3. Call `abap_creation-get_object_type_details` for the exact object type.
4. Build `objectContent` from the returned fields. This payload is metadata only;
   never put ABAP/CDS source code in it.
5. Call `abap_creation-run_validation` and use the normalized `objectContent` it
   returns.
6. Call `abap_transport-get`. Never auto-select a transport. Reuse a transport only
   when the user already selected that exact request for the same development scope;
   otherwise present the returned choices and wait for selection.
7. Call `abap_creation-create_object` with the validated content and selected
   transport.
8. Use the returned `filePath` as the source anchor and read the generated shell.
9. Populate source through the ABAP remote filesystem using `apply_patch`.
10. Run focused diagnostics with `get_errors`.
11. Activate the populated object and its dependencies with
    `abap_activate_objects`.
12. Run focused ABAP Unit tests with `abap_run_unit_tests` when tests exist.
13. Run final diagnostics and report exact activation/test results.

Call `abap_transport-get` for each new object when required by the server. Once the
user approves a transport for the same package and development scope, reuse it
without asking again unless the server rejects it, returns a decision-requiring
warning, or the package/scope changes.

## Critical Lock Rule

Do not activate an empty shell between object creation and source population.

The supported sequence is:

```text
validate metadata -> select transport -> create shell -> populate source
-> diagnostics -> activate once -> test
```

Activating a new empty shell through one ADT MCP session and then editing it through
the ABAP remote filesystem can leave a stale lock handle. If activation reports
`Resource ... is not locked (invalid lock handle ...)`:

1. Stop retrying activation.
2. Preserve the current source; do not recreate or delete the object.
3. Run the VS Code command `ABAP FS: Refresh ABAP filesystem` or reload the VS Code
   window, reopen the object, and verify the source is still present.
4. Save/activate through one owner session, then rerun diagnostics and tests.

## Existing Objects

Do not run object creation for an object that already exists. Read its current source,
apply the smallest edit, run diagnostics, activate the owning main object, and test.
Never replace or recreate an object to work around a lock problem.

Before editing an existing object, read its current source again. User or formatter
changes are authoritative and must be preserved.

## Validation Evidence

- Run focused diagnostics before activation.
- Successful backend activation is authoritative for repository state.
- If VS Code retains a pre-activation diagnostic after successful activation,
   refresh the ABAP filesystem once. Do not repeatedly repair a cached problem unless
   backend activation or runtime testing also fails.
- After changing a BDEF contract, activate the BDEF and behavior pool together. If
   generated-contract refresh leaves the class inactive, reactivate the class once
   before testing.
- Do not infer success from a process exit code alone. Inspect MCP `isError`,
   activation text, and test output.

## Tool Names

Use these configured ADT MCP tools directly:

- `abap_creation-get_all_creatable_objects`
- `abap_creation-get_object_type_details`
- `abap_creation-run_validation`
- `abap_transport-get`
- `abap_transport-create` only after explicit user approval
- `abap_creation-create_object`
- `abap_activate_objects`
- `abap_run_unit_tests`
- `abap_generators-generate_objects` only for an explicitly approved generator flow

## Helper Examples

Inspect one cached tool schema:

```powershell
& "$env:USERPROFILE\.agents\skills\sap-system-operations\scripts\Invoke-AdtMcp.ps1" `
   -DescribeTool 'abap_creation-create_object'
```

Refresh the compact cache only when required:

```powershell
& "$env:USERPROFILE\.agents\skills\sap-system-operations\scripts\Invoke-AdtMcp.ps1" `
   -DescribeTool 'abap_creation-create_object' -RefreshSchema
```

Call a known tool:

```powershell
$arguments = @{ destination = 'SYSTEM_100_USER_EN' } | ConvertTo-Json -Compress
& "$env:USERPROFILE\.agents\skills\sap-system-operations\scripts\Invoke-AdtMcp.ps1" `
  -ToolName 'abap_creation-get_all_creatable_objects' `
  -ArgumentsJson $arguments
```

## Safety and Reporting

- Never expose credentials.
- Never create extra objects beyond the approved object list.
- Never modify SAP standard objects.
- Never bypass transport selection for transportable packages.
- Never claim success until activation succeeds.
- Report created object names, package, transport, activation result, and test result.
- If blocked, report the exact ADT response and the next safe recovery step.
