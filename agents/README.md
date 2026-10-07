# GitHub Copilot Agents

Seven agents are installed into `~/.copilot/agents`.

| Agent | Ownership |
|---|---|
| `abap-cloud-routing-and-handoff` | Governed multi-phase routing and handoffs |
| `abap-cloud-analyzer` | Requirements, feasibility, constraints, risks |
| `abap-cloud-designer` | Architecture and cross-system design |
| `abap-cloud-developer` | ABAP Cloud implementation and validation |
| `abap-cloud-reviewer` | Findings-first review and final release verdict |
| `abap-classic-developer` | Classic/Standard ABAP on ECC/on-premise |
| `abap-ecc-to-s4hana-migration` | ECC-to-S/4HANA impact and remediation |

Shared trust, syntax, delivery, architecture, and ADT fallback policies live under `references/`; they are supporting documents, not extra agents.

The routing agent can invoke the six specialists. Other agents select one primary object-focused skill group and normally no more than two companions.
