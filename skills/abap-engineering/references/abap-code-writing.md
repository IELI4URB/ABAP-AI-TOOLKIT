---
name: abap-code-writing
description: 'Structure ABAP implementation from requirement through system research, design, code, and tests. Use before writing reports, classes, function modules, enhancements, CDS/RAP code, or ABAP Unit tests, especially when object contracts and live-system reuse must be verified.'
argument-hint: '[description of what to build in ABAP]'
user-invocable: true
disable-model-invocation: false
---

# ABAP Code Writing

SAP Help baseline: https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm

Use [the complete code-writing process](./_legacy/abap-code-writing/references/code-writing-process.md) for non-trivial implementation. Load only the active phase and keep completed findings compressed.

## Workflow

1. Confirm requirement, inputs, outputs, landscape, constraints, acceptance criteria,
   destination, package, package language version, Clean Core tier, transport, and
   direct ADT MCP versus explicitly approved local-prototype mode.
2. Inspect the SAP system and search for standard or existing custom capabilities.
3. Define architecture and capability boundaries.
4. Verify every reused object, signature, DDIC type, key, and release contract.
5. Produce an implementation-ready object and method plan.
6. Write one bounded change, then run the smallest falsifying validation.
7. Add focused tests and complete review/release gates appropriate to risk.

For Tier 1 Clean Core implementation, do not edit or create until the package uses
ABAP for Cloud Development. If it uses Standard ABAP, stop and request a package
correction. Use Standard ABAP only for an explicitly approved Tier 2/classic scope.

For connected-system development, create new repository objects through ADT MCP
before populating their returned shells. Do not first create equivalent virtual or
local files.

## Hard Rules

- Do not invent objects, parameters, fields, enhancement points, or syntax.
- Prefer standard released capability over new custom code when it satisfies the need.
- Match generated identifiers to ABAP limits and project naming conventions.
- Use SQL/CDS test environments for database-dependent ABAP Unit tests.
- Keep explanations outside copy-ready code blocks and clearly label partial snippets.
- Before each repair, state one local hypothesis and one discriminating check. Do
	not change multiple independent boundaries before running that check.
- Limit speculative repair attempts for the same failure to three. Then inspect the
	typed failure (`FAILED`, `%fail-cause`, `REPORTED`, activation error), step to the
	owning abstraction, or stop with a handoff.
- Prefer backend activation/runtime evidence over stale editor diagnostics. Refresh
	the ABAP filesystem once after successful activation before investigating a cached
	problem.
- Re-read files reported as user-modified immediately before editing and preserve
	those changes.

## Ownership

Use `clean-abap` for style, `abap-unit-testing` for detailed test mechanics, domain skills for business semantics, and `adt-mcp-object-workflow` for connected-system object creation.

