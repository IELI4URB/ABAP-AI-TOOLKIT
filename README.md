# SAP DEV AI Toolkit

Skills and specialist agents for SAP ABAP Cloud, ECC/on-premise, and functional
modules (PP/MM/SD/Finance/TM) development — for use with **GitHub Copilot** in
VS Code.

> **Copilot-only install.** The installer sets things up for GitHub Copilot only.
> Claude Code agents are intentionally **not** installed: VS Code surfaces
> `~/.claude/agents` in the Copilot agent picker too, so installing them produced
> **duplicate agents** in Copilot chat. The `claude-agents/` folder is kept in the
> repo for reference/manual use only.

Repo: https://github.tools.sap/I756261/SAP-DEV-AI-TOOLKIT

## Get it

```bash
git clone https://github.tools.sap/I756261/SAP-DEV-AI-TOOLKIT.git
cd SAP-DEV-AI-TOOLKIT
```

Or download the repo as a ZIP from the GitHub Enterprise page (Code → Download ZIP)
if you don't have git.

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

## What the installer does

It copies folders from here into the locations GitHub Copilot in VS Code reads from:

| From (this folder) | To (live location) | What it is |
|---|---|---|
| `skills\` | `~/.agents/skills/` (Copilot) | Skill knowledge files (`SKILL.md`) |
| `agents\` | `~/.copilot/agents/` | Custom agents (`*.agent.md`) — shown in the Copilot agent picker |

`~` means your user home folder (`C:\Users\<you>` on Windows, `/Users/<you>` on Mac).

> **`claude-agents\` is not installed.** It holds the same agents pre-converted to
> Claude Code's format, kept only for reference. Installing them into `~/.claude/agents`
> caused duplicate entries in the Copilot picker, so the installer skips it. If you
> genuinely use Claude Code, copy `claude-agents\*.md` to `~/.claude/agents` manually.

## Sharing this with your team

Zip this whole `Skills` folder (it must keep `skills\`, `agents\`,
`install.ps1`, and `install.sh` together) and send it, or put it on a shared drive /
internal Git repo. Each teammate just runs the installer for their OS — no manual
file copying.

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

- **42 skills** in `skills\` — ABAP/RAP/CDS/Clean Core topics plus a couple of
  general-purpose ones (`find-skills`, `cavecrew`). Installed to `~/.agents/skills`
  (Copilot). The same `SKILL.md` format also works for Claude Code if copied manually.
- **11 agents** in `agents\` — the `abap-cloud-*` specialist agents (analyzer,
  designer, developer, reviewer, enterprise-architect, delivery-gates,
  routing/handoff, shared guardrails, syntax policy, VS Code ADT object workflow)
  plus `abap-ecc-to-s4hana-migration`. VS Code/Copilot format. **These are the only
  agents the installer installs.**
- `agents\references\` — supporting docs (`rap-overview.md`, `rap-extensibility.md`).
- **11 agents** in `claude-agents\` — the same agents converted to Claude Code's
  plain `.md` + comma-separated `tools:` format. **Not installed** (see the note at
  the top) — kept for reference / manual Claude Code use only.

## Notes

- Connected-system development loads the `adt-mcp-object-workflow` skill first to
  create, populate, activate, and test ABAP repository objects through the configured
  ADT MCP server. The VS Code ABAP remote-fs workflow remains available as fallback.
- This is a plain file copy, not a symlink — edits here don't auto-apply until you
  re-run the installer (or manually copy them over).
