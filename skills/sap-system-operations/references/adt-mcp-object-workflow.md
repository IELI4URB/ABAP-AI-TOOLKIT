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
   [Invoke-AdtMcp.ps1](./_legacy/adt-mcp-object-workflow/scripts/Invoke-AdtMcp.ps1). Do not probe unrelated MCP
   servers or inspect extensions first.

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

List the server tools only when a server upgrade makes a known tool unavailable:

```powershell
& "$env:USERPROFILE\.agents\skills\adt-mcp-object-workflow\scripts\Invoke-AdtMcp.ps1" -ListTools
```

Call a known tool:

```powershell
$arguments = @{ destination = 'SYSTEM_100_USER_EN' } | ConvertTo-Json -Compress
& "$env:USERPROFILE\.agents\skills\adt-mcp-object-workflow\scripts\Invoke-AdtMcp.ps1" `
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
