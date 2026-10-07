# Automatic Skill and Agent Synchronization

This Windows automation watches managed local ABAP skills and GitHub Copilot agents, validates changes, commits them, and pushes them to:

`https://github.tools.sap/I756261/ABAP-DEVELOPMENT-AI-TOOLKIT`

## Managed Scope

The automation synchronizes only:

- The 11 registered skill-group directories under `~/.agents/skills`
- Their canonical copies under `~/.agents/skill-packs/SAP-ABAP-Cloud-Skills/skills`
- The seven toolkit-managed `.agent.md` files under `~/.copilot/agents`
- Their canonical copies under `~/.agents/skill-packs/SAP-ABAP-Cloud-Skills/prompts`

It does not synchronize unrelated skills, extension-contributed agents such as `abap-developer`, package-level READMEs, agent support references, Claude mirrors, manifests, secrets, logs, or immutable `_legacy` source snapshots.

## Safety Behavior

Before a push, the engine:

1. Requires branch `main` and the expected renamed `origin` URL.
2. Stops when the Git worktree is dirty.
3. Fetches `origin/main` and accepts only a fast-forward update.
4. Detects independent edits to the same file and stops on conflicts.
5. Mirrors the selected version across Git, canonical, and runtime copies.
6. Runs canonical skill validation, routing tests, package validation, and `git diff --check`.
7. Stages only managed skill groups and managed Copilot agent files.
8. Blocks common secret-bearing file types.
9. Commits and pushes only after all checks pass.

If validation, authentication, connectivity, or conflict checks fail, changes remain local and nothing is pushed. Review the logs and resolve the reported condition manually.

## Install

Run from the repository in PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& .\automation\Install-ToolkitAutoSync.ps1
```

This creates and starts the current-user Scheduled Task `ABAP-Development-AI-Toolkit-AutoSync`. The task starts at logon and keeps a debounced filesystem watcher running. Administrator rights are not required.

Git authentication must already work without an interactive prompt. The standard Git Credential Manager used by a successful manual `git push` satisfies this requirement.

## Check Status

```powershell
& .\automation\Install-ToolkitAutoSync.ps1 -Action Status
Get-Content "$env:LOCALAPPDATA\ABAP-DEVELOPMENT-AI-TOOLKIT\sync.log" -Tail 50
Get-Content "$env:LOCALAPPDATA\ABAP-DEVELOPMENT-AI-TOOLKIT\watcher.log" -Tail 50
```

## Manual Dry Run

```powershell
python .\automation\sync_toolkit.py --dry-run
```

A dry run reports planned managed changes without copying, committing, pushing, or updating synchronization state.

## Maintainer Integration Test

```powershell
& .\automation\Test-ToolkitAutoSync.ps1
```

The test uses a temporary Git clone and temporary home directory. It verifies state initialization, runtime skill and agent propagation, validation, local commit creation, and conflicting-edit refusal without pushing to GitHub or modifying production files.

## Uninstall

```powershell
& .\automation\Install-ToolkitAutoSync.ps1 -Action Uninstall
```

Uninstalling the Scheduled Task does not remove skills, agents, Git history, logs, or synchronization state.

## Conflict Recovery

When the same managed file has different changes in Git, canonical, and runtime copies, the engine stops instead of choosing one. Resolve the copies manually, run the normal validators, then run:

```powershell
python .\automation\sync_toolkit.py
```

Do not edit files below `references/_legacy/`; their hashes are integrity controls.