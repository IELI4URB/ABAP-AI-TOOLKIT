---
name: cavecrew
description: Guide for using the task tool to spawn focused subagents for investigation, implementation, and review — compressing context and enabling parallel work in long sessions.
triggers: delegate, subagent, task tool, investigate, codebase search, investigate files, find code, locate symbol, focused edit, diff review, compressed context, parallel agent, search before edit, review diff, long session, context limit, spawn agent, parallel task, isolate context
---

# Subagent Delegation Guide

Use this skill when you want to delegate focused work to a subagent via the `task` tool — for investigation, targeted implementation, or review — keeping the main thread lean and context under control.

## When to Use

- You need to search or explore files/symbols before editing (investigate first).
- You need focused implementation in 1–2 files without polluting main-thread context.
- You want a quality/risk review pass on generated diffs before committing.
- The session is long and intermediate outputs should be compressed before continuing.
- Multiple independent sub-tasks can run in parallel.

## Agent Role Patterns

Use the `task` tool with `subagent_type: "general-purpose"` for all three roles below. Define the role in the task description.

### Investigator
Locates code paths, symbols, file structures, and constraints. Returns a compact findings report.

```
task({
  subagent_type: "general-purpose",
  description: "<TITLE>Investigate X</TITLE> You are an investigator. Your job is to locate [specific symbol/pattern/file] in the codebase. Search [path]. Return: file paths, line numbers, relevant code snippets, and constraints. Be concise — no prose, just findings."
})
```

### Builder
Implements a focused edit in 1–2 files based on a spec. Returns the diff or edited content.

```
task({
  subagent_type: "general-purpose",
  description: "<TITLE>Implement X</TITLE> You are a builder. Implement [specific change] in [file path]. Acceptance criteria: [list]. Return: the exact edit made, briefly explain each change. Do not touch other files."
})
```

### Reviewer
Validates a diff or implementation for risks, regressions, and test gaps.

```
task({
  subagent_type: "general-purpose",
  description: "<TITLE>Review diff for X</TITLE> You are a reviewer. Review the following diff for correctness, regressions, missing test coverage, and production risk. Findings sorted by severity (High / Medium / Low). [paste diff]"
})
```

## Delegation Protocol

1. State the target outcome and acceptance criteria clearly in the task description.
2. Include exact file paths or search scope when known.
3. Request concise, decision-ready output — not verbose prose.
4. Apply findings in the main thread with validation.
5. For independent sub-tasks, fire multiple `task` calls in one turn (parallel).

## Task Selection Matrix

| Need | Agent role | Key instruction to include |
|---|---|---|
| Locate code paths, symbols, files | Investigator | Exact search scope + return format |
| Implement focused edit (1–2 files) | Builder | File path + acceptance criteria |
| Review diff for risk and regressions | Reviewer | Paste diff + severity sort requirement |
| Multiple independent tasks | All (parallel) | Fire all `task` calls in one turn |

## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. Context and assumptions
2. Which agent role(s) to spawn and why
3. Task descriptions (ready to use)
4. How to apply findings back in the main thread
5. Residual risks and open assumptions
