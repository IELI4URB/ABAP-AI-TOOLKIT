# ABAP Development AI Toolkit

Give your AI coding agent an SAP ABAP engineering brain, grounded in Clean Core, RAP, released APIs, and verified landscape context before implementation begins.

An end-to-end agentic SAP ABAP engineering toolkit for AI coding assistants. It provides ready-to-use agents for GitHub Copilot and Claude Code, 
while its reusable SAP skills can be adapted to other platforms that support custom agents, skills, or instructions. Role-specific agents and progressively loaded SAP skills keep analysis, 
architecture, implementation, review, and migration on consistent evidence, quality, and delivery standards — across ABAP Cloud, 
classic/Standard ABAP, and ECC-to-S/4HANA, without mixing their landscape-specific rules.

**At a glance**

- **7 role agents** — analyzer, architect, developer, reviewer, classic developer, ECC→S/4 migration, and a router that sequences them.
- **11 SAP skill groups** — RAP/CDS, performance, security, integration, process automation, governance, forms, business domains, operations, and delivery.
- **Evidence-first gates** — Clean Core, released-API, security, performance, testing, transport, and rollback checks applied *while building*, not just at release.
- **Light by default** — short skill routers keep Copilot context small and load deep references only when the task needs them.

> New here? Jump to [Installation](#installation) — clone, run one installer, reload VS Code.

## What It Does

- Routes work to a focused analyzer, architect, developer, reviewer, or migration specialist.
- Separates ABAP Cloud implementation from classic/Standard ABAP development.
- Provides SAP-specific guidance for RAP, CDS, OData, SQL, security, integration, jobs, workflow, forms, operations, and business domains.
- Grounds syntax and platform decisions in SAP Help and verified system evidence.
- Applies Clean Core, released-API, security, performance, testing, transport, rollback, and production-readiness checks.
- Loads detailed guidance progressively, keeping routine Copilot context smaller.
- Supports connected-system workflows through ADT and MCP tools when those tools are available and configured.

**The toolkit turns ADT MCP into a repeatable development workflow. Agents no longer rediscover the server, tools, schemas, and creation sequence for every task. They reuse the active SAP destination and follow a predefined lifecycle for object discovery, validation, transport selection, creation, source population, activation, testing, and ATC.**

## Practical Benefits

- **Correct role for each phase:** analysis, architecture, implementation, and review have separate owners, reducing conflicting responsibilities and self-review bias.
- **Landscape-aware guidance:** Cloud-only restrictions, released APIs, classic APIs, database assumptions, and migration concerns remain explicitly separated.
- **Evidence before confidence:** agents require syntax, object-contract, data, and system evidence before presenting non-trivial conclusions as verified.
- **Quality during development:** security, performance, testing, operability, ATC, transport, and rollback checks are applied while work is designed and built, not only at release time.
- **Focused Copilot context:** agents select one primary skill and only the companion guidance needed for the active concern.
- **Independent release review:** the reviewer reports findings by severity and blocks release-ready language when required evidence is missing.
- **Useful with or without a live SAP connection:** the toolkit can analyze and draft from repository evidence, then use ADT/MCP workflows for object operations when configured and authorized.
- **Repeatable team setup:** manifest-based installers update toolkit-managed content without deleting unrelated agents or skills.

## Why Use It Instead of a General Agent?

A general coding agent can answer ABAP questions, but it does not automatically establish the SAP landscape, language version, API release state, database, transport model, or business-process ownership.

| General agent | SAP DEV AI Toolkit |
|---|---|
| Broad software-development behavior | SAP ABAP role and task-specific behavior |
| May mix ABAP Cloud and classic patterns | Explicit Cloud, classic, and migration ownership |
| Relies mainly on the prompt for SAP constraints | Built-in landscape, Clean Core, and release-state gates |
| One agent analyzes, designs, codes, and reviews | Separate agents for analysis, architecture, implementation, and independent review |
| Generic testing guidance | ABAP Unit, RAP, activation, ATC, transport, and rollback expectations |
| Large static instruction sets can consume context | Short skill routers load detailed references only when relevant |
| Limited SAP business context | Finance, MM, PP/DS, SD, and TM guidance |

The toolkit improves consistency and decision quality; it does not replace developer judgment, code review, SAP authorization, system testing, or release approval.

## Choose an Agent

Select the agent from the Copilot Chat agent picker before entering the request.

| Agent | Use it when |
|---|---|
| `abap-cloud-analyzer` | Assessing feasibility, constraints, evidence gaps, landscape fit, Clean Core impact, or delivery risk before design |
| `abap-cloud-enterprise-architect` | Designing target architecture, RAP BO boundaries, CDS layers, integrations, NFRs, and the implementation blueprint |
| `abap-cloud-developer` | Implementing or fixing production-oriented ABAP Cloud, RAP, CDS, integrations, jobs, forms, or tests |
| `abap-cloud-reviewer` | Reviewing code or design and issuing a findings-first release-readiness verdict |
| `abap-classic-developer` | Implementing Standard ABAP for ECC or S/4HANA on-premise, including reports, enhancements, function modules, and classic APIs |
| `abap-ecc-to-s4hana-migration` | Assessing or remediating custom code for an ECC-to-S/4HANA conversion |
| `abap-cloud-routing-and-handoff` | Coordinating a multi-phase requirement across analysis, architecture, implementation, review, and approval |

### Which Developer Agent?

- Choose `abap-cloud-developer` for ABAP Cloud, RAP, released-only APIs, S/4HANA Cloud, or BTP ABAP Environment.
- Choose `abap-classic-developer` for Standard ABAP, ECC, classic enhancements, function modules, or unreleased on-premise APIs.
- Choose `abap-ecc-to-s4hana-migration` when migration impact and remediation are the primary goal.

If VS Code also shows `abap-developer`, that agent is contributed by the SAP ADT extension, not this toolkit. It is configured for cloud-compliant local `$TMP` development through ADT MCP. Use the toolkit agents when landscape decisions, governance, transports, production quality gates, or classic ABAP ownership matter.

| Capability | SAP ADT `abap-developer` | Toolkit `abap-cloud-developer` |
|---|---|---|
| Primary use | Local cloud-compliant development in `$TMP` | Governed ABAP Cloud implementation for team delivery |
| Package and transport assumption | `$TMP`; no transport | Real package, transport, release, and rollback requirements |
| System interaction | ADT MCP object creation, activation, and tests | Guidance with or without a live system; governed ADT/MCP workflow when connected |
| Validation | Activation and mandatory unit tests | Syntax, activation, tests, Clean Core, security, performance, ATC, transport, and production-readiness gates |
| Landscape scope | Fixed cloud-compliant assumptions | S/4HANA Cloud, BTP ABAP Environment, and verified landscape/release constraints |

Neither agent replaces `abap-classic-developer` for Standard ABAP or ECC work.

## Skill Groups

Agents use these skills as focused knowledge modules. Copilot loads the applicable guide based on the request; users normally select an agent and describe the task rather than manually opening skill files.

| Skill | Use it for |
|---|---|
| `abap-rap-services` | CDS models, RAP behavior, EML, OData, Fiori Elements annotations, events, enhancements, and API versioning |
| `abap-engineering` | ABAP language mechanics, implementation workflow, Clean ABAP, OOP, released classes, ABAP Unit, and code review |
| `abap-data-performance` | ABAP SQL, AMDP, joins, pushdown, pagination, N+1 removal, database tuning, memory, and graph traversal |
| `abap-security` | IAM, DCL, RAP authorization, input validation, injection prevention, secrets, sensitive data, and audit |
| `abap-integration` | HTTP/REST, SOAP, RFC wrappers, communication arrangements, Event Mesh, AIF, retries, logging, and resilience |
| `abap-process-automation` | Application Jobs, scheduling, Flexible Workflow, Classic Workflow, BRFplus, approvals, and monitoring |
| `abap-cloud-governance` | Clean Core, released APIs, extension models, platform versions, ATC, transports, CI/CD, abapGit, and rollback |
| `abap-forms` | Adobe Forms, ADS, XDP/XSD, Output Management, PDF rendering, templates, and assets |
| `sap-business-domains` | Finance, Materials Management, Production Planning/PP-DS, Sales and Distribution, and Transportation Management |
| `sap-system-operations` | Incidents, dumps, jobs, locks, object research, ADT APIs, MCP object lifecycle, Basis, SPRO, and system analysis |
| `agentic-delivery` | Multi-step planning, approval gates, named-agent delegation, handoffs, recovery, and validation |

## Installation

### Prerequisites

- Visual Studio Code with GitHub Copilot installed and signed in
- Git
- Access to the SAP corporate network or VPN for `github.tools.sap`
- PowerShell on Windows, or bash/zsh on macOS and Linux
- SAP ADT and MCP configuration only when direct connected-system operations are required

No administrator rights are required.

### Windows PowerShell

```powershell
Set-Location $HOME
git clone https://github.tools.sap/I756261/ABAP-DEVELOPMENT-AI-TOOLKIT.git
Set-Location .\ABAP-DEVELOPMENT-AI-TOOLKIT
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& .\install.ps1
```

### macOS or Linux

```bash
cd "$HOME"
git clone https://github.tools.sap/I756261/ABAP-DEVELOPMENT-AI-TOOLKIT.git
cd ABAP-DEVELOPMENT-AI-TOOLKIT
chmod +x install.sh
./install.sh
```

After installation, run **Developer: Reload Window** from the VS Code Command Palette.

For ZIP installation, optional Claude Code agents, and platform-specific troubleshooting, see [INSTALL.md](INSTALL.md).

## Verify Installation

Open Copilot Chat and confirm that the seven toolkit agents appear in the agent picker.

On Windows, you can also run:

```powershell
$skills = Get-ChildItem "$HOME\.agents\skills" -Directory |
	Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }
$agents = Get-ChildItem "$HOME\.copilot\agents" -Filter '*.agent.md'

$skills.Count  # 11 toolkit skills, plus any unrelated installed skills
$agents.Count  # 7 toolkit agents, plus any unrelated installed agents
```

Installed locations:

| Content | Destination |
|---|---|
| Skills | `~/.agents/skills/` |
| GitHub Copilot agents | `~/.copilot/agents/` |
| Optional Claude Code agents | `~/.claude/agents/` |

## Using the Toolkit

Include enough system context for the selected agent to make a defensible decision:

- Business goal and expected outcome
- SAP product and deployment model
- SAP/ABAP release and database when known
- Package, application, or affected objects
- ABAP language version
- Data volume and performance constraints
- Security and authorization requirements
- Transport, testing, and rollback expectations

For a multi-phase feature, use this sequence:

1. Analyze feasibility and risks with `abap-cloud-analyzer`.
2. Establish the target design with `abap-cloud-enterprise-architect`.
3. Implement and validate with the appropriate cloud or classic developer.
4. Request an independent findings-first review from `abap-cloud-reviewer`.

Use `abap-cloud-routing-and-handoff` when one conversation must coordinate the complete sequence.

Example requests:

```text
Analyze whether this unmanaged RAP requirement is feasible in S/4HANA Cloud
Private Edition 2025. Identify released-API and authorization risks. Do not code yet.
```

```text
Design a RAP business object for purchase requisition approval. Define CDS layers,
behavior ownership, authorization, integration boundaries, and test strategy.
```

```text
Implement this ABAP Cloud validation in package ZMM_APP, activate the affected
objects, run the relevant ABAP Unit tests, and report remaining transport risks.
```

```text
Review these changed RAP objects for correctness, Clean Core, security,
performance, missing tests, and release readiness. List findings by severity.
```

## Updates

Pull the latest version and rerun the installer:

### Windows

```powershell
Set-Location "$HOME\ABAP-DEVELOPMENT-AI-TOOLKIT"
git pull --ff-only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& .\install.ps1
```

### macOS or Linux

```bash
cd "$HOME/ABAP-DEVELOPMENT-AI-TOOLKIT"
git pull --ff-only
./install.sh
```

The installer refreshes only toolkit-managed items recorded in its manifest. Unrelated skills and agents remain untouched.

## Optional Claude Code Agents

Claude mirrors are not installed by default because some VS Code configurations display them alongside Copilot agents and create duplicate picker entries.

```powershell
& .\install.ps1 -InstallClaudeAgents
```

```bash
INSTALL_CLAUDE_AGENTS=1 ./install.sh
```

## Important Limitations

- The toolkit does not include SAP credentials, destinations, certificates, or system authorizations.
- Direct SAP changes require a configured ADT/MCP connection and the user's own permissions.
- SAP release and API availability must be verified against the target system; a documented feature may not be installed, configured, licensed, or released for the intended use.
- Generated code still requires activation, executable tests, peer review, and the team's transport and release process.
- Do not enter passwords, API keys, tokens, personal data, or production secrets into chat prompts.

## Troubleshooting

**Agents do not appear**

Run **Developer: Reload Window**, then confirm the files exist under `~/.copilot/agents/`.

**Duplicate agents appear**

Remove obsolete `.agent.md` files from the legacy VS Code prompts directory. Do not remove the `abap-developer` agent if it is supplied by the SAP ADT extension and your team uses it.

- Windows: `%APPDATA%\Code\User\prompts`
- macOS: `~/Library/Application Support/Code/User/prompts`
- Linux: `~/.config/Code/User/prompts`

**Connected SAP operations are unavailable**

Verify that the SAP ADT extension, ADT connection, and MCP server are installed, configured, and authorized. The toolkit can still provide analysis and code guidance without a live connection, but it must not claim activation or test execution.

## Maintainer Validation

Python 3.10 or newer is required only for repository validation:

```bash
python validate_pack.py
```

The validator checks skill and agent counts, ownership boundaries, self-contained references, frontmatter, local links, routing, and package structure.

## Additional Documentation

- [Detailed installation guide](INSTALL.md)
- [SAP Help source index](docs/REFERENCE_SAP_HELP.md)

## Repository Layout

```text
skills/           SAP knowledge and workflow modules
agents/           GitHub Copilot role agents and shared policies
claude-agents/    Optional Claude Code mirrors
config/           Skill ownership (group) map
docs/             Team, governance, and SAP Help documentation
scripts/          Documentation inventory and maintenance tooling
install.ps1       Windows installer
install.sh        macOS/Linux installer
validate_pack.py  Repository validator
```

## Author

[Pratibha Pandey](https://github.com/pratibha-pandey01_sap) [Shrikrushna Kulkarni](https://github.com/shrikrushna-kulkarni_sap)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). All contributors must sign off commits under the Developer Certificate of Origin and follow SAP's guidance for AI-assisted contributions.

## License

Licensed under the [Apache License 2.0](LICENSE).
