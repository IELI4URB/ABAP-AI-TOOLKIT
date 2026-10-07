---
name: abap-oops-design-patterns
description: 'Apply OOP and design patterns in SAP ABAP Cloud. Use for SOLID, Repository, Strategy, Factory, Application Service, Decorator, anti-corruption layers, dependency inversion, interfaces, testability, composition, and RAP placement decisions.'
---

# ABAP Cloud OOP and Patterns

Use [SOLID principles](./_legacy/abap-oops-design-patterns/references/solid-principles.md) and [design patterns](./_legacy/abap-oops-design-patterns/references/design-patterns.md) selectively. Prior entry-point guidance is preserved in [the entry-point reference](./_legacy/abap-oops-design-patterns/references/entrypoint-reference.md).

## Workflow

1. Identify the concrete change pressure, responsibility, dependencies, and test boundary.
2. Prefer the simplest design satisfying current requirements.
3. Select a pattern only when it removes real duplication/coupling or matches an established boundary.
4. Place it correctly relative to RAP handlers, domain/application services, repositories, and adapters.
5. Validate substitutions, dependency direction, behavior, and testability.

## Gates

Avoid pattern-driven ceremony, service locators, hidden globals, broad interfaces, and abstractions without a second use or clear volatility boundary.

