---
name: abap-rap-behavior-implementation
description: 'Implement and troubleshoot RAP behavior-pool classes for ABAP Cloud. Use for lhc_* handlers, CL_ABAP_BEHAVIOR_HANDLER, FOR VALIDATE, DETERMINE, ACTION, FUNCTION, AUTHORIZATION, FEATURES, precheck, numbering, unmanaged saver, FAILED, REPORTED, MAPPED, and behavior implementation activation errors.'
metadata:
  version: 4.0.0
  tags: abap rap bdef behavior-implementation eml handler failed reported
---

# RAP Behavior Implementation

Use this skill for implementation-class mechanics below the BDEF declaration layer. Use [the official BDEF guide](./official-rap-behavior-definitions.md) for behavior declaration design and syntax; load only the relevant section of [the complete behavior implementation reference](./abap-rap-behavior-implementation/references/behavior-implementation-reference.md) for generated implementation mechanics.

## Workflow

1. Inspect the BDEF, entity aliases, implementation class, method declaration, and target release.
2. Classify the method category and implicit response types.
3. Read only the corresponding reference section.
4. Verify handler signature and caller/callee types against generated contracts.
5. Make the smallest implementation change, activate, and run focused behavior tests.

## Reference Routing

| Need | Section |
|---|---|
| Split-source behavior-pool layout | Split-source class structure |
| Instance/global authorization | Instance Authorization; method-category reference |
| `FAILED`, `REPORTED`, `MAPPED`, `%msg` | FAILED / REPORTED shape |
| Message exception class | Message-carrying exception class base |
| Validation, determination, action, function | Full method-category reference |
| Features, prechecks, numbering | Full method-category reference |
| Stale diagnostics | Diagnostics caveat |

## Gates

- Never invent handler signatures or EML response shapes; inspect generated contracts and current SAP Help.
- Match entity aliases exactly when accessing nested response components.
- Distinguish declarative BDEF design from behavior implementation mechanics.
- Treat system-specific activation findings as evidence for that release, not universal syntax.

