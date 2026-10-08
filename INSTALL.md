# Team Installation Guide

## Prerequisites

- Visual Studio Code with GitHub Copilot installed and signed in
- Git for clone/update workflows
- SAP corporate network or VPN access for `github.tools.sap`
- PowerShell on Windows, or bash/zsh on macOS/Linux
- Python 3.10+ only for maintainers running package validation

No administrator rights are required.

## Windows

Open a PowerShell terminal in VS Code.

### First installation

```powershell
Set-Location $HOME
git clone https://github.tools.sap/I756261/ABAP-DEVELOPMENT-AI-TOOLKIT.git
Set-Location .\ABAP-DEVELOPMENT-AI-TOOLKIT
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& .\install.ps1
```

### Upgrade an existing installation

```powershell
Set-Location "$HOME\ABAP-DEVELOPMENT-AI-TOOLKIT"
git pull --ff-only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& .\install.ps1
```

The execution-policy change lasts only for that terminal session.

## macOS or Linux

### First installation

```bash
cd "$HOME"
git clone https://github.tools.sap/I756261/ABAP-DEVELOPMENT-AI-TOOLKIT.git
cd ABAP-DEVELOPMENT-AI-TOOLKIT
chmod +x install.sh
./install.sh
```

### Upgrade an existing installation

```bash
cd "$HOME/ABAP-DEVELOPMENT-AI-TOOLKIT"
git pull --ff-only
./install.sh
```

## Install from ZIP

1. Open the repository in SAP GitHub Enterprise.
2. Select **Code → Download ZIP**.
3. Extract the complete archive; keep `skills/`, `agents/`, and the installer together.
4. Open the extracted folder in VS Code.
5. Run `install.ps1` on Windows or `install.sh` on macOS/Linux.

## Optional Claude Code Agents

Copilot installation is the default. Claude mirrors are not installed automatically because VS Code can surface `~/.claude/agents` in the Copilot picker and show duplicates.

Install them only when your team intentionally uses Claude Code:

```powershell
& .\install.ps1 -InstallClaudeAgents
```

```bash
INSTALL_CLAUDE_AGENTS=1 ./install.sh
```

## Verify Installation

### Windows

```powershell
$skills = Get-ChildItem "$HOME\.agents\skills" -Directory |
  Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }
$agents = Get-ChildItem "$HOME\.copilot\agents" -Filter '*.agent.md'

$skills.Count  # expected: 11 toolkit skill groups (plus any other packages)
$agents.Count  # expected: 7 toolkit agents (plus any other packages)
```

### macOS or Linux

```bash
find "$HOME/.agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l
find "$HOME/.copilot/agents" -maxdepth 1 -name '*.agent.md' | wc -l
```

Then run **Developer: Reload Window** in VS Code and inspect Copilot Chat's skill/agent picker.

## Safe Upgrades and Cleanup

The installer writes `.sap-dev-ai-toolkit-manifest` files in both destination folders. On upgrades it:

1. Reads the previous toolkit-owned item list.
2. Removes only obsolete toolkit-owned items.
3. Reinstalls the current 11 groups and 8 agents.
4. Leaves unrelated skills and agents from other packages untouched.

Obsolete toolkit-managed entries recorded by an earlier installation are removed automatically.

## Optional Automatic Git Synchronization

Maintainers on Windows can watch managed local skills and agents and push validated changes automatically:

```powershell
& .\automation\Install-ToolkitAutoSync.ps1
```

See the local auto-sync tooling (maintained outside this repository) before enabling it. Git authentication must already work non-interactively, and conflicts or validation failures always require manual resolution.

## Duplicate Agents

If agents appear twice, remove old `.agent.md` files from the legacy VS Code prompts directory:

- Windows: `%APPDATA%\Code\User\prompts`
- macOS: `~/Library/Application Support/Code/User/prompts`
- Linux: `~/.config/Code/User/prompts`

The toolkit agents should live only in `~/.copilot/agents`.

## Maintainer Validation

Before sharing or publishing:

```bash
python validate_pack.py
```

The validator checks group count, ownership indexes, self-contained references, frontmatter, local links, agent topology, Claude mirrors, and grouped routing.
