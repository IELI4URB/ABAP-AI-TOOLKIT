---
name: abap-cloud-governance
description: 'Govern SAP ABAP Cloud and Clean Core delivery. Use for Cloudification Repository lookups, released API and object status by SAP product/release/type, BDEF/CDS release checks, C0/C1 release contracts, API states, language versions, Tier 1/2 wrappers, extension models, Public versus Private Cloud, ABAP Platform 2025/FPS features, ATC, transports, gCTS, cTMS, Cloud ALM, CI/CD, abapGit, branches, rollback, and enterprise release governance.'
metadata:
  version: 2.0.0
  tags: abap clean-core governance transport atc gcts abap-cloud cicd release-management
---

# ABAP Cloud Governance

| Concern | Guide |
|---|---|
| Cloudification Repository lookup, official language versions, C0-C4 contracts, API checks, release news | [ABAP Cloud APIs and releases](./references/official-abap-cloud-apis-and-releases.md) |
| Release state, extension choice, Tier 2 | [Clean Core API and extension governance](./references/clean-core-api-extension-governance.md) |
| Pipeline, ATC, transports, rollback | [Quality gates and transports](./references/quality-gates-and-transports.md) |
| abapGit, branches, Git/transport hybrid | [abapGit and branch workflows](./references/abapgit-and-branch-workflows.md) |
| Platform 2025 and FPS-specific capability | [ABAP Platform 2025 release guide](./references/abap-platform-2025-release-guide.md) |
| End-to-end Clean Core program | [Enterprise Clean Core delivery](./references/enterprise-clean-core-delivery.md) |
| Public Cloud implementation constraints | [Public Cloud development constraints](./references/public-cloud-development-constraints.md) |
| Generative AI in ABAP (Joule for Developers, SAP AI SDK for ABAP, ISLM) | [Generative AI in ABAP Cloud](./references/generative-ai-abap-cloud.md) |

## Workflow

Establish landscape and exact release first. Load only the guide owning the current governance decision; load delivery/release guides only when that phase begins.
