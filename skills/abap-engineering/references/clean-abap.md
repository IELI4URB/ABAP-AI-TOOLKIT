---
name: clean-abap
description: 'Apply SAP Clean ABAP standards when writing, reviewing, or refactoring ABAP. Use for naming, modern language constructs, classes, methods, parameters, internal tables, errors, comments, formatting, and unit-test style.'
argument-hint: '[ABAP code task or review request]'
user-invocable: true
disable-model-invocation: false
---

# Clean ABAP

Use this skill as the style router. Read only the relevant section of [the complete Clean ABAP rules](./_legacy/clean-abap/references/clean-abap-complete.md).

## Workflow

1. Confirm target ABAP release and language version before selecting modern syntax.
2. Classify the review concern: names, language, data structures, classes, methods, errors, formatting, or tests.
3. Load only the corresponding reference section.
4. Apply rules to the touched code; do not perform unrelated style churn.
5. Validate syntax and behavior after refactoring.

## Core Rules

- Prefer intention-revealing names, small cohesive methods, and explicit contracts.
- Prefer modern supported syntax and object orientation without speculative abstractions.
- Select internal-table type and keys from the real access pattern.
- Use class-based exceptions and preserve root causes.
- Keep comments focused on why, not what the code already says.
- Keep tests readable, isolated, deterministic, and behavior-focused.

## Ownership

This skill owns style and maintainability. Use `abap-code-writing` for delivery workflow, `abap-unit-testing` for test-double mechanics, and performance/security skills for their respective gates.

