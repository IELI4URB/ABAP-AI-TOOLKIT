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

## Before you install

1. Install [Visual Studio Code](https://code.visualstudio.com/) and the GitHub
  Copilot extension, then sign in to GitHub Copilot.
2. Connect to the SAP corporate network or VPN so `github.tools.sap` is reachable.
3. Install Git if you want to clone the repository. A ZIP download also works.

## Install on Windows

Use the **PowerShell terminal inside VS Code**:

1. Open VS Code.
2. Select **Terminal → New Terminal** from the top menu.
3. In the terminal panel, use the profile dropdown beside the `+` button and select
  **PowerShell**. The prompt normally starts with `PS`.
4. For a first installation, run:

  ```powershell
  Set-Location $HOME
  git clone https://github.tools.sap/I756261/SAP-DEV-AI-TOOLKIT.git
  Set-Location .\SAP-DEV-AI-TOOLKIT
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  & .\install.ps1
  ```

5. For an existing clone, update and reinstall with:

  ```powershell
  Set-Location "$HOME\SAP-DEV-AI-TOOLKIT"
  git pull --ff-only
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  & .\install.ps1
  ```

The execution-policy change applies only to the current terminal and is discarded
when that terminal closes.

## Install on macOS

Use the **zsh terminal inside VS Code**:

1. Open VS Code and select **Terminal → New Terminal**.
2. Select **zsh** from the terminal profile dropdown if it is not already active.
3. For a first installation, run:

  ```bash
  cd "$HOME"
  git clone https://github.tools.sap/I756261/SAP-DEV-AI-TOOLKIT.git
  cd SAP-DEV-AI-TOOLKIT
  chmod +x install.sh
  ./install.sh
  ```

4. For an existing clone, run:

  ```bash
  cd "$HOME/SAP-DEV-AI-TOOLKIT"
  git pull --ff-only
  ./install.sh
  ```

## Install on Linux

Use the **bash terminal inside VS Code**:

1. Open VS Code and select **Terminal → New Terminal**.
2. Select **bash** from the terminal profile dropdown.
3. For a first installation, run:

  ```bash
  cd "$HOME"
  git clone https://github.tools.sap/I756261/SAP-DEV-AI-TOOLKIT.git
  cd SAP-DEV-AI-TOOLKIT
  chmod +x install.sh
  ./install.sh
  ```

4. For an existing clone, run:

  ```bash
  cd "$HOME/SAP-DEV-AI-TOOLKIT"
  git pull --ff-only
  ./install.sh
  ```

## Install from a ZIP

1. On the repository page, select **Code → Download ZIP**.
2. Extract the ZIP.
3. In VS Code, select **File → Open Folder** and open the extracted
  `SAP-DEV-AI-TOOLKIT` folder.
4. Open **Terminal → New Terminal** and run the installer for your operating system:

  ```powershell
  # Windows PowerShell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  & .\install.ps1
  ```

  ```bash
  # macOS zsh or Linux bash
  chmod +x install.sh
  ./install.sh
  ```

## Verify the installation

On Windows PowerShell:

```powershell
Test-Path "$HOME\.agents\skills\atq-principles\SKILL.md"
Get-ChildItem "$HOME\.copilot\agents" -Filter '*.agent.md' | Select-Object Name
```

On macOS or Linux:

```bash
test -f "$HOME/.agents/skills/atq-principles/SKILL.md" && echo "ATQ skill installed"
ls "$HOME/.copilot/agents/"*.agent.md
```

The agent list should include `abap-cloud-developer`, `abap-developer`, and
`abap-cloud-routing-and-handoff`. Finally, open the VS Code Command Palette with
**Ctrl+Shift+P** on Windows/Linux or **Cmd+Shift+P** on macOS, run
**Developer: Reload Window**, then open Copilot Chat and check the agent picker.

Maintainers can validate the repository before installation with:

```bash
python validate_pack.py
```

## What the installer does

It copies folders from here into the locations GitHub Copilot in VS Code reads from:

| From (this folder) | To (live location) | What it is |
|---|---|---|
| `skills\` | `~/.agents/skills/` (Copilot) | Skill knowledge files (`SKILL.md`) |
| `agents\` | `~/.copilot/agents/` | Custom agents (`*.agent.md`) — shown in the Copilot agent picker |

`~` means your user home folder (`C:\Users\<you>` on Windows, `/Users/<you>` on Mac).

Each destination receives a `.sap-dev-ai-toolkit-manifest` file. On later runs,
the installer removes only obsolete items previously installed by this toolkit;
skills and agents managed by other packages are left untouched.

> **`claude-agents\` is not installed.** It holds the same agents pre-converted to
> Claude Code's format, kept only for reference. Installing them into `~/.claude/agents`
> caused duplicate entries in the Copilot picker, so the installer skips it. If you
> genuinely use Claude Code, copy `claude-agents\*.md` to `~/.claude/agents` manually.

## Sharing this with your team

Zip this whole `SAP-DEV-AI-TOOLKIT` folder (it must keep `skills\`, `agents\`,
`install.ps1`, and `install.sh` together) and send it, or put it on a shared drive /
internal Git repo. Each teammate just runs the installer for their OS — no manual
file copying.

## If something looks duplicated

If an agent shows up **twice** in the picker, it means agent files also exist in the
old/legacy location: `%APPDATA%\Code\User\prompts` (Windows) or
`~/Library/Application Support/Code/User/prompts` (macOS) or
`~/.config/Code/User/prompts` (Linux). Delete any `*.agent.md` files there — agents
should only live in `~/.copilot/agents`.

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

- **44 skills** in `skills\` — ABAP/RAP/CDS/Clean Core topics plus agentic
  governance and general-purpose guidance (`atq-principles`, `find-skills`, `cavecrew`). Installed to `~/.agents/skills`
  (Copilot). The same `SKILL.md` format also works for Claude Code if copied manually.
- **12 agents** in `agents\` — the `abap-cloud-*` specialist agents (analyzer,
  designer, developer, reviewer, enterprise-architect, delivery-gates,
  routing/handoff, shared guardrails, syntax policy, VS Code ADT object workflow)
  plus `abap-developer` for standard ABAP and `abap-ecc-to-s4hana-migration` for
  migration work. VS Code/Copilot format. **These are the only agents the installer installs.**
- `agents\references\` — supporting docs (`rap-overview.md`, `rap-extensibility.md`).
- **12 agents** in `claude-agents\` — the same agents converted to Claude Code's
  plain `.md` + comma-separated `tools:` format. **Not installed** (see the note at
  the top) — kept for reference / manual Claude Code use only.

## Notes

- Connected-system development loads the `adt-mcp-object-workflow` skill first to
  create, populate, activate, and test ABAP repository objects through the configured
  ADT MCP server. The VS Code ABAP remote-fs workflow remains available as fallback.
- This is a plain file copy, not a symlink — edits here don't auto-apply until you
  re-run the installer (or manually copy them over).
