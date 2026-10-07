---
name: abap-code-writing
description: 'Structure ABAP implementation from requirement through system research, design, code, and tests. Use before writing reports, classes, function modules, enhancements, CDS/RAP code, or ABAP Unit tests, especially when object contracts and live-system reuse must be verified.'
argument-hint: '[description of what to build in ABAP]'
user-invocable: true
disable-model-invocation: false
---

# ABAP Code Writing

SAP Help baseline: https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm

Use [the complete code-writing process](./abap-code-writing/references/code-writing-process.md) for non-trivial implementation. Load only the active phase and keep completed findings compressed.

## Workflow

1. Confirm requirement, inputs, outputs, landscape, constraints, and acceptance criteria.
2. Inspect the SAP system and search for standard or existing custom capabilities.
3. Define architecture and capability boundaries.
4. Verify every reused object, signature, DDIC type, key, and release contract.
5. Produce an implementation-ready object and method plan.
6. Write one bounded change, then run the smallest falsifying validation.
7. Add focused tests and complete review/release gates appropriate to risk.

## Hard Rules

- Do not invent objects, parameters, fields, enhancement points, or syntax.
- Prefer standard released capability over new custom code when it satisfies the need.
- Match generated identifiers to ABAP limits and project naming conventions.
- Use SQL/CDS test environments for database-dependent ABAP Unit tests.
- Keep explanations outside copy-ready code blocks and clearly label partial snippets.

## Ownership

Use `clean-abap` for style, `abap-unit-testing` for detailed test mechanics, domain skills for business semantics, and `adt-mcp-object-workflow` for connected-system object creation.

