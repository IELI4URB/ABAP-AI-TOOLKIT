---
name: abap-oops-design-patterns
description: 'Apply OOP and design patterns in SAP ABAP Cloud. Use for SOLID, Repository, Strategy, Factory, Application Service, Decorator, anti-corruption layers, dependency inversion, interfaces, testability, composition, and RAP placement decisions.'
---

# ABAP Cloud OOP and Patterns

SOLID principles and design patterns are included below; apply them selectively.

## Workflow

1. Identify the concrete change pressure, responsibility, dependencies, and test boundary.
2. Prefer the simplest design satisfying current requirements.
3. Select a pattern only when it removes real duplication/coupling or matches an established boundary.
4. Place it correctly relative to RAP handlers, domain/application services, repositories, and adapters.
5. Validate substitutions, dependency direction, behavior, and testability.

## Gates

Avoid pattern-driven ceremony, service locators, hidden globals, broad interfaces, and abstractions without a second use or clear volatility boundary.

## Topics

| Topic | Guide |
|---|---|
| OOP design principles (SOLID, class design, layering) | [OOP design principles](./abap-oop-design-principles.md) |
| Design patterns catalog (Repository, Strategy, Factory, and more) | [Design patterns catalog](./abap-oop-design-patterns-catalog.md) |
