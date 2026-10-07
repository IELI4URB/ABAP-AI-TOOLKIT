---
name: find-skills
description: 'Discover installed or installable skills when users ask to find a skill, inspect available capabilities, add automation, search the skill catalog, or recommend a specialized workflow.'
---

# Find Skills

The prior catalog is preserved in [the entry-point reference](./references/entrypoint-reference.md), but verify recommendations against the live skill registry before presenting them.

## Workflow

1. Restate the requested capability and scope.
2. Search the live registry for the most specific matching description.
3. Select one primary skill and normally no more than two companions.
4. Verify every recommended name exists now; do not rely on stale catalog entries.
5. Search externally only when no installed capability matches.

## Output

Return the primary skill, reason, optional companions, trigger example, and any uncovered capability. Prefer specific domain/workflow skills over broad bundles.
