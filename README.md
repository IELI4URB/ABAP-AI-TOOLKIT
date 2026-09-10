# How to Install These Skills & Agents in VS Code

## Install (do this — it's the only step)

1. **Windows:** double-click `install.ps1` (or right-click it → **Run with PowerShell**).
   If Windows blocks it, open a terminal in this folder and run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```
2. **macOS:** open Terminal in this folder and run:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
3. **Reload VS Code**: Command Palette (Ctrl+Shift+P / Cmd+Shift+P) → **Developer: Reload Window**.

Done. Open Copilot Chat and check the agent picker — you should see the `abap-cloud-*`
agents and `abap-ecc-to-s4hana-migration`.

If **Claude Code** is also installed (the `claude` CLI is on PATH), the installer
automatically also copies skills to `~/.claude/skills` and agents to `~/.claude/agents`
— no extra steps needed.

## What the installer does

It copies folders from here into the locations each tool actually reads from:

| From (this folder) | To (live location) | What it is |
|---|---|---|
| `skills\` | `~/.agents/skills/` (Copilot) and `~/.claude/skills/` (Claude Code) | Skill knowledge files (`SKILL.md`) — same format works for both |
| `agents\` | `~/.copilot/agents/` | Custom agents (`*.agent.md`) — shown in the Copilot agent picker |
| `claude-agents\` | `~/.claude/agents/` (only if Claude Code is detected) | Same 11 agents, pre-converted to Claude Code's `.md` + tool-name format |

`~` means your user home folder (`C:\Users\<you>` on Windows, `/Users/<you>` on Mac).

> **Note on `claude-agents\`:** Claude Code uses a different frontmatter dialect
> (`tools:` as a comma string with its own tool names, e.g. `Read, Edit, Bash`,
> instead of Copilot's `tools: [read, edit, execute]`). The files in `claude-agents\`
> are manually translated equivalents of `agents\*.agent.md` — if you edit one side,
> update the other to keep them in sync.

## Sharing this with your team

Zip this whole `Skills` folder (it must keep `skills\`, `agents\`, `claude-agents\`,
`install.ps1`, and `install.sh` together) and send it, or put it on a shared drive /
internal Git repo. Each teammate just runs the installer for their OS — no manual
file copying, and it auto-detects whether they also have Claude Code installed.

## If something looks duplicated

If an agent shows up **twice** in the picker, it means agent files also exist in the
old/legacy location: `%APPDATA%\Code\User\prompts` (Windows) or
`~/Library/Application Support/Code/User/prompts` (Mac). Delete any `*.agent.md`
files there — agents should only live in `~/.copilot/agents`.

## Keeping this backup up to date

If you edit a skill or agent directly in the live folders, copy the change back here
so the backup (and anything you share with the team) stays current:

```powershell
# Windows
Copy-Item "$HOME\.agents\skills\*" "$PSScriptRoot\skills" -Recurse -Force
Copy-Item "$HOME\.copilot\agents\*.agent.md" "$PSScriptRoot\agents" -Force
```

```bash
# macOS
cp -R "$HOME/.agents/skills/." "./skills/"
cp "$HOME/.copilot/agents/"*.agent.md "./agents/"
```

## Contents

- **37 skills** in `skills\` — ABAP/RAP/CDS/Clean Core topics plus a couple of
  general-purpose ones (`find-skills`, `cavecrew`). Portable as-is to both
  `~/.agents/skills` (Copilot) and `~/.claude/skills` (Claude Code).
- **11 agents** in `agents\` — the `abap-cloud-*` specialist agents (analyzer,
  designer, developer, reviewer, enterprise-architect, delivery-gates,
  routing/handoff, shared guardrails, syntax policy, VS Code ADT object workflow)
  plus `abap-ecc-to-s4hana-migration`. VS Code/Copilot format.
- `agents\references\` — supporting docs (`rap-overview.md`, `rap-extensibility.md`).
- **11 agents** in `claude-agents\` — the same agents, converted to Claude Code's
  plain `.md` + comma-separated `tools:` format.

## Notes

- `C:\Users\I756261\.agents` on this machine also contains a `skill-packs\` subfolder
  and helper scripts (`build_v3.py`, `gen_v3.py`, `.skill-lock.json`) used to manage
  skill installations — packaging tooling, not skill/agent content, intentionally not
  included here.
- This is a plain file copy, not a symlink — edits here don't auto-apply until you
  re-run the installer (or manually copy them over).
