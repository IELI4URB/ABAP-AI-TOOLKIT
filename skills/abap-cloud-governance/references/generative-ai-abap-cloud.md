---
name: generative-ai-abap-cloud
description: 'Generative AI in ABAP Cloud. Use for the two AI use cases — AI-assisted ABAP development (Joule for Developers) and embedding generative AI into custom ABAP apps via the SAP AI SDK for ABAP and Intelligent Scenario Lifecycle Management (ISLM). Covers grounding, released-API/Clean-Core and data-privacy governance for AI features.'
metadata:
  version: 1.0.0
  tags: abap generative-ai joule ai-sdk islm intelligent-scenario abap-cloud btp
---

# Generative AI in ABAP Cloud

Source: SAP Help — SAP BTP → Development in the ABAP Environment → Generative AI in ABAP Cloud.

Two distinct use cases:

## 1. AI-assisted ABAP development (developer productivity)

Generative AI helps with day-to-day ABAP coding tasks to raise efficiency and lower cost of development — code explanation, unit-test generation, ATC-finding explanation and fix proposals, CDS/annotation generation, etc. Delivered through **SAP Joule for Developers (ABAP AI capabilities)** inside ADT (Eclipse / VS Code) and the **ADT MCP server**.

- Requires the **SAP Joule for Developers, ABAP AI capabilities** license (see `sap-system-operations/adt-mcp-community-servers.md` for the ADT MCP server + Joule login requirement).
- This is a tooling capability — it assists the developer; it does not change the Clean Core / released-API rules for the code produced. All AI-generated code is still subject to the normal gates (syntax verification, released-object check, ATC, tests).

## 2. Embedding generative AI into custom ABAP apps

Include generative AI in your own business applications via the **SAP AI SDK for ABAP**, governed by **Intelligent Scenario Lifecycle Management (ISLM)**:

- The **SAP AI SDK for ABAP** is the released ABAP API layer for consuming generative-AI / foundation-model services (through SAP AI Core / the generative-AI hub) from ABAP Cloud code.
- **ISLM** is the lifecycle framework for intelligent scenarios: register, deploy, activate, and monitor an AI scenario that your ABAP app consumes.

### Intelligent Scenario Lifecycle Management (ISLM)

ISLM is a **self-service framework** for lifecycle-managing machine-learning scenarios in the ABAP environment. An **intelligent scenario** is the **ABAP representation of a business-specific ML use case**. ISLM operations: **train, deploy, activate**, and fetch an accurate **inference** result from the trained scenario. There are two scenario kinds — classic ML scenarios and **Generative AI for ISLM** (GenAI-backed scenarios). The app consumes the activated scenario's inference; ISLM owns the model lifecycle, not the consuming business logic.
- Treat the AI service as an external dependency: consume only released APIs, keep orchestration thin, and apply the same integration resilience (timeouts, retries, error handling) as any outbound call — see `abap-integration`.

## Governance for AI features

- **Released-API discipline:** use the released SAP AI SDK for ABAP / ISLM APIs; verify release state and visibility like any other consumed API (see `clean-core-api-extension-governance.md`, `official-abap-cloud-apis-and-releases.md`).
- **Data privacy / grounding:** prompts and grounding data may leave the ABAP boundary to the model service. Do not send secrets, personal data, or unreleased SAP content to a model without the proper data-privacy and masking controls. Never embed credentials in prompts (see shared guardrails: secrets).
- **Determinism:** generative output is non-deterministic — validate and constrain it before acting on it in a business process; do not treat raw model output as verified fact or as production-ready code.
- **Availability** is edition/release-dependent (BTP ABAP environment, S/4HANA Cloud Public/Private Edition) and some capabilities need an additional license — confirm for the target landscape.

> Landscape note: AI-assisted development (Joule) and the SAP AI SDK for ABAP are ABAP Cloud / BTP capabilities. For classic ECC / on-premise, these do not apply.
