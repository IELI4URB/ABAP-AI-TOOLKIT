# SAP DEV AI Toolkit

A shareable GitHub Copilot toolkit for SAP ABAP development. It installs:

- **11 object-focused skill groups** with progressive references
- **7 role-focused Copilot agents**
- Optional **7 Claude Code agent mirrors** for teammates who explicitly use Claude Code

All 44 former standalone skills are preserved inside the 11 groups. Only the short group routers are registered, which keeps navigation and prompt context small.

Repository: https://github.tools.sap/I756261/SAP-DEV-AI-TOOLKIT

## Quick Install

Prerequisites: VS Code, GitHub Copilot, Git, and access to the SAP corporate network/VPN.

### Windows PowerShell

```powershell
Set-Location $HOME
git clone https://github.tools.sap/I756261/SAP-DEV-AI-TOOLKIT.git
Set-Location .\SAP-DEV-AI-TOOLKIT
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& .\install.ps1
```

### macOS or Linux

```bash
cd "$HOME"
git clone https://github.tools.sap/I756261/SAP-DEV-AI-TOOLKIT.git
cd SAP-DEV-AI-TOOLKIT
chmod +x install.sh
./install.sh
```

For upgrades, run `git pull --ff-only` and rerun the installer. The installer removes only files previously managed by this toolkit, including obsolete 44-skill or 12-agent installations.

See [INSTALL.md](INSTALL.md) for ZIP installation, verification, optional Claude installation, troubleshooting, and team rollout guidance.

## Skill Groups

| Group | Covers |
|---|---|
| `abap-rap-services` | CDS, RAP behavior, OData, Fiori Elements, API lifecycle, events/extensions |
| `abap-security` | IAM, DCL, RAP authorization, validation, secrets, sensitive data |
| `abap-integration` | HTTP/SOAP/RFC/Event Mesh/AIF, exceptions, retries, logging |
| `abap-process-automation` | Application Jobs, workflows, approvals, BRFplus |
| `abap-data-performance` | ABAP SQL, AMDP, database/query performance, graph traversal |
| `abap-engineering` | Code writing, Clean ABAP, OOP, released classes, tests, review |
| `abap-cloud-governance` | Clean Core, platform versions, ATC, transports, Git, DevSecOps |
| `abap-forms` | Adobe Forms, ADS, PDF output, templates, assets |
| `sap-system-operations` | Incidents, research, ADT, Basis, SPRO, workbooks, system analysis |
| `sap-business-domains` | Finance, MM, PP/DS, SD, TM |
| `agentic-delivery` | ATQ governance, named-agent delegation, skill discovery |

Each group has one short `SKILL.md`. Former skills and supporting references/scripts are under the group's `references/` directory and load only when needed.

## Copilot Agents

| Agent | Role |
|---|---|
| `abap-cloud-routing-and-handoff` | Multi-phase routing and approval state |
| `abap-cloud-analyzer` | Requirements, feasibility, constraints, risks |
| `abap-cloud-designer` | Architecture and cross-system trade-offs |
| `abap-cloud-developer` | ABAP Cloud implementation and validation |
| `abap-cloud-reviewer` | Findings-first review and release verdict |
| `abap-classic-developer` | Classic/Standard ABAP for ECC and on-premise |
| `abap-ecc-to-s4hana-migration` | ECC-to-S/4HANA impact and remediation |

## Installed Locations

| Repository source | Installed destination |
|---|---|
| `skills/` | `~/.agents/skills/` |
| `agents/` | `~/.copilot/agents/` |
| `claude-agents/` (optional) | `~/.claude/agents/` |

After installation, run **Developer: Reload Window** from the VS Code Command Palette.

## Validate the Package

```bash
python validate_pack.py
```

Expected result: 11 skills, 7 Copilot agents, 7 Claude mirrors, no broken links, and intact 44-skill migration archives.

## Repository Layout

```text
skills/             11 registered skill groups
agents/             7 GitHub Copilot agents and shared references
claude-agents/      7 optional Claude Code mirrors
config/             44-to-11 mapping and integrity hashes
docs/               routing, governance, and SAP Help references
install.ps1         Windows installer
install.sh          macOS/Linux installer
validate_pack.py    package integrity validation
```
