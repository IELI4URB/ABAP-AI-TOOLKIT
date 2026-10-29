---
name: generative-ai-abap-cloud
description: 'Generative AI in ABAP Cloud. Use for the two AI use cases — AI-assisted ABAP development (Joule for Developers) and embedding generative AI into custom ABAP apps via the SAP AI SDK for ABAP and Intelligent Scenario Lifecycle Management (ISLM). Covers system requirements by landscape, BTP + ABAP setup steps, SAP_COM_0A69 communication arrangement, ABAP AI SDK code examples, model availability, deployment ID wiring, and data-privacy governance.'
metadata:
  version: 2.0.0
  tags: abap generative-ai joule ai-sdk islm intelligent-scenario abap-cloud btp sap-com-0a69 generative-ai-hub
---

# Generative AI in ABAP Cloud

Source: SAP Help — [Generative AI in ABAP Cloud](https://help.sap.com/docs/btp/sap-business-technology-platform/generative-ai-in-abap-cloud?locale=en-US).

Two distinct use cases:

## 1. AI-assisted ABAP development (developer productivity)

Generative AI helps with day-to-day ABAP coding tasks — code explanation, unit-test generation, ATC-finding explanation and fix proposals, CDS/annotation generation. Delivered through **SAP Joule for Developers (ABAP AI capabilities)** inside ADT (Eclipse / VS Code) and the **ADT MCP server**.

- Requires the **SAP Joule for Developers, ABAP AI capabilities** license.
- This is a tooling capability — it assists the developer; it does not change Clean Core / released-API rules for the code produced. All AI-generated code is still subject to the normal gates (syntax verification, released-object check, ATC, tests).

## 2. Embedding generative AI into custom ABAP apps

Include generative AI in your own business applications via the **SAP AI SDK for ABAP**, governed by **Intelligent Scenario Lifecycle Management (ISLM)**:

- The **SAP AI SDK for ABAP** is the released ABAP API layer for consuming generative-AI / foundation-model services through SAP AI Core / the Generative AI Hub from ABAP Cloud code.
- **ISLM** is the lifecycle framework for intelligent scenarios: register, deploy, activate, and monitor an AI scenario that your ABAP app consumes.
- Connectivity is established via communication scenario **SAP_COM_0A69**.
- Treat the AI service as an external dependency: consume only released APIs, keep orchestration thin, and apply the same integration resilience (timeouts, retries, error handling) as any outbound call — see `abap-integration`.

> **Landscape boundary:** The ABAP AI SDK + ISLM + SAP_COM_0A69 path is ABAP Cloud only.
> For on-premise S/4HANA or ECC calling AI Core via raw HTTP, load the `abap-integration`
> skill's `ai-core-http-patterns.md`.

---

## System Requirements by Landscape

| Landscape | ABAP AI SDK + ISLM | SAP_COM_0A69 | Min Release |
|-----------|-------------------|--------------|-------------|
| SAP BTP ABAP Environment (Steampunk) | Supported | Available | Any current |
| S/4HANA Cloud Public Edition | Supported | Available | 2023 FPS01+ |
| S/4HANA Cloud Private Edition | Supported | Available | 2025 |
| S/4HANA On-Premise (standard ABAP) | Not available | Not available | — |
| ECC / classical ABAP | Not available | Not available | — |

**BTP prerequisites:**
- SAP AI Core service instance — plan `extended` for full Generative AI Hub model access; `standard` covers limited models; `free` for trial only.
- SAP AI Core service key created (provides `clientid`, `clientsecret`, `url`, `AI_API_URL`).
- Generative AI Hub model deployed and in **Running** state (deployment ID noted from AI Launchpad).
- BTP subaccount in a supported region: eu10, eu20, us10, us20, ap10, jp10, br10.

---

## Setup Steps

### Step 1 — BTP: Subscribe and configure SAP AI Core

```
1. BTP Cockpit → Subaccount → Entitlements → Add Service Plans:
     SAP AI Core → extended

2. Instances and Subscriptions → Create Instance:
     Service:  SAP AI Core
     Plan:     extended
     Name:     <sysid>-aicore

3. Create Service Key:
     Instance → ⋮ → Create Service Key → name: <sysid>-aicore-key
     From the JSON, note:
       clientid                        OAuth client ID
       clientsecret                    OAuth client secret
       url                             Token endpoint base (append /oauth/token)
       serviceurls.AI_API_URL          AI Core REST API base URL

4. AI Launchpad → Administration → Resource Groups → Create:
     Resource Group ID: <rg-id>        e.g. "default" or project-specific name

5. AI Launchpad → Generative AI Hub → Deployments → Create:
     Resource Group: <rg-id>
     Model:          gpt-4o            (see model table below)
     Resource Plan:  infer.s           (dev) / infer.m (production)
     Wait for status: Running
     NOTE the Deployment ID            format: d<alphanumeric>  e.g. d1a2b3c4e5f6
```

### Step 2 — ABAP System: Create Communication System

```
Fiori App: Communication Systems  (or SPRO → SAP NetWeaver → Communication)

1. New Communication System:
     ID:        AICORE_<ENV>            e.g. AICORE_DEV
     Host:      <AI_API_URL host only>  e.g. api.ai.eu10.ml.hana.ondemand.com
     Port:      443
     HTTPS:     Enabled

2. Users for Outbound Communication → Add:
     Authentication Method:  OAuth 2.0
     OAuth 2.0 Client ID:    <clientid from service key>
     Client Secret:          <clientsecret from service key>
     Token Endpoint:         <url from service key>/oauth/token
     Token Endpoint Scope:   (leave blank — AI Core does not require a scope)

3. Save
```

### Step 3 — ABAP System: Create Communication Arrangement (SAP_COM_0A69)

```
Fiori App: Communication Arrangements

1. New → Communication Scenario: SAP_COM_0A69
   (SAP_COM_0A69 = "SAP AI Core — Embedded AI Scenarios")

2. Communication System: AICORE_<ENV>   (from Step 2)

3. Additional Properties:
     AI-Resource-Group: <rg-id>         must match the resource group in AI Launchpad

4. Verify outbound service URL is auto-populated from the communication system.

5. Save and Activate.
   Record the Communication Arrangement ID — referenced by ISLM in Step 4.
```

### Step 4 — ISLM: Register and Activate an Intelligent Scenario

```
Fiori App: Intelligent Scenario Management  (or /AIC/ISLM_APP)

1. New Intelligent Scenario:
     Scenario ID:    Z_<NAME>           must start with Z or Y for custom scenarios
     Scenario Type:  Generative AI for ISLM
     Description:    <purpose>

2. Connection:
     Communication Arrangement:  <arrangement ID from Step 3>
     Deployment ID:              <deployment ID from Step 1 — e.g. d1a2b3c4e5f6>
     Model:                      gpt-4o   (must match the deployed model exactly)

3. Activate:
     Click Activate — status must reach: Active
     If activation fails, verify:
       - Communication arrangement credentials are correct (test via Check Connection)
       - AI Core deployment is in Running state in AI Launchpad
       - Resource group ID in arrangement matches AI Launchpad
       - Deployment ID is copied correctly (case-sensitive)
```

### Deployment ID — Where to Find It

The deployment ID is the key link between ISLM and the running model in AI Core.

```
AI Launchpad → Generative AI Hub → Deployments
→ Click your deployment → Details tab → Deployment ID field
   Format: d followed by ~12 alphanumeric characters
   Example: d3f8a1bc29e7

This ID is:
  - Entered in ISLM Step 4 above
  - Specific to a model + resource group + resource plan combination
  - Must be updated in ISLM if you redeploy the model (new deployment = new ID)
  - NOT the same as the model name
```

---

## Model Availability Table (Generative AI Hub)

| Model Name | Provider | Context Window | Best For | Embedding |
|------------|----------|---------------|----------|-----------|
| `gpt-4o` | OpenAI | 128k tokens | Chat, reasoning, code | No |
| `gpt-4o-mini` | OpenAI | 128k tokens | Fast, cost-effective | No |
| `gpt-4.1` | OpenAI | 1M tokens | Large context analysis | No |
| `claude-3-5-sonnet` | Anthropic | 200k tokens | Long docs, nuanced reasoning | No |
| `claude-3-haiku` | Anthropic | 200k tokens | Fast lightweight chat | No |
| `gemini-1.5-pro` | Google | 1M tokens | Multimodal, large context | No |
| `meta-llama-3-70b-instruct` | Meta | 8k tokens | Open model, data sovereignty | No |
| `text-embedding-ada-002` | OpenAI | 8k tokens | Text embeddings for RAG | Yes |
| `text-embedding-3-large` | OpenAI | 8k tokens | High-quality embeddings | Yes |
| `sap-rpt-ts` | SAP | — | SAP time-series forecasting | No |

> Model availability is region and plan dependent. Always confirm in AI Launchpad → Generative AI Hub → Model Library for your subaccount before development.

---

## ABAP AI SDK — Code Examples

### Verify Released API Availability

Before coding, confirm the following released classes/interfaces exist in your landscape via ADT or SE24:

| Object | Type | Purpose |
|--------|------|---------|
| `IF_AIC_SDK_LLM_CLIENT` | Interface | LLM client contract |
| `CL_AIC_SDK_LLM_FACTORY` | Class | Creates client instances via ISLM |
| `IF_AIC_SDK_LLM_RESPONSE` | Interface | Parses LLM response |
| `CX_AIC_SDK_ERROR` | Exception | Base exception for AI SDK errors |

### Chat Completion — Single Turn

```abap
CLASS zcl_ai_chat DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS ask
      IMPORTING iv_prompt        TYPE string
                iv_scenario_id   TYPE /aic/scenario_id
      RETURNING VALUE(rv_answer) TYPE string
      RAISING   cx_aic_sdk_error.
ENDCLASS.

CLASS zcl_ai_chat IMPLEMENTATION.
  METHOD ask.
    " Factory resolves credentials from SAP_COM_0A69 via ISLM
    DATA(lo_client) = cl_aic_sdk_llm_factory=>get_client(
      iv_scenario_id = iv_scenario_id ).

    DATA(lt_messages) = VALUE if_aic_sdk_llm_client=>tt_message(
      ( role    = if_aic_sdk_llm_client=>co_role_system
        content = 'You are a helpful SAP business assistant.' )
      ( role    = if_aic_sdk_llm_client=>co_role_user
        content = iv_prompt )
    ).

    DATA(lo_response) = lo_client->chat_completion(
      it_messages    = lt_messages
      iv_max_tokens  = 1000
      iv_temperature = '0.7'
    ).

    rv_answer = lo_response->get_content( ).
  ENDMETHOD.
ENDCLASS.
```

### Multi-Turn Chat (conversation history)

```abap
METHOD ask_with_history.
  DATA(lo_client) = cl_aic_sdk_llm_factory=>get_client(
    iv_scenario_id = iv_scenario_id ).

  " Start with system message
  DATA(lt_messages) = VALUE if_aic_sdk_llm_client=>tt_message(
    ( role    = if_aic_sdk_llm_client=>co_role_system
      content = iv_system_prompt )
  ).

  " Append prior turns from DB or session cache
  LOOP AT it_history INTO DATA(ls_turn).
    APPEND VALUE #(
      role    = ls_turn-role       " 'user' or 'assistant'
      content = ls_turn-message
    ) TO lt_messages.
  ENDLOOP.

  " Append current user prompt
  APPEND VALUE #(
    role    = if_aic_sdk_llm_client=>co_role_user
    content = iv_current_prompt
  ) TO lt_messages.

  DATA(lo_response) = lo_client->chat_completion(
    it_messages   = lt_messages
    iv_max_tokens = 1500
  ).

  rv_answer = lo_response->get_content( ).
ENDMETHOD.
```

### Text Embedding Generation

```abap
METHOD generate_embedding.
  " Use a dedicated ISLM scenario pointing to an embedding model deployment
  " (text-embedding-3-large or text-embedding-ada-002)
  DATA(lo_client) = cl_aic_sdk_llm_factory=>get_client(
    iv_scenario_id = iv_embed_scenario_id ).

  DATA(lo_response) = lo_client->embedding(
    iv_input = iv_text   " max ~8000 tokens — truncate if needed
  ).

  " Returns number[] — store as JSON string for HANA Vector Engine
  rt_vector = lo_response->get_embedding( ).  " TYPE float_t TAB
ENDMETHOD.
```

### Error Handling

```abap
TRY.
    DATA(lo_client) = cl_aic_sdk_llm_factory=>get_client(
      iv_scenario_id = 'Z_MY_AI_SCENARIO' ).

    DATA(lo_resp) = lo_client->chat_completion(
      it_messages   = lt_messages
      iv_max_tokens = 500
    ).

    lv_answer = lo_resp->get_content( ).

  CATCH cx_aic_sdk_error INTO DATA(lx_ai).
    " Covers: scenario not active, deployment not running,
    "         token fetch failure, HTTP 4xx/5xx from AI Core
    cl_bali_log=>...   " Log via Application Log
    RAISE EXCEPTION TYPE zcx_ai_integration_error
      EXPORTING previous = lx_ai.
ENDTRY.
```

---

## Governance for AI Features

- **Released-API discipline:** use only the released SAP AI SDK for ABAP / ISLM APIs. Verify release state and C1 contract exactly as for any consumed API (see `clean-core-api-extension-governance.md`, `official-abap-cloud-apis-and-releases.md`).
- **Data privacy / grounding:** prompts and grounding data may leave the ABAP boundary to the model service. Do not send PII, secrets, personal data, or unreleased SAP content to a model without proper data-privacy and masking controls. Never embed credentials in prompts.
- **Determinism:** generative output is non-deterministic — validate and constrain model output before acting on it in a business process. Do not treat raw model output as verified fact or production-ready code.
- **Availability** is edition/release-dependent and some capabilities require an additional Joule for Developers license — confirm for the target landscape before development commitment.
- **Resilience:** apply the same timeout, retry, and circuit-breaker patterns as for any external HTTP call — see `abap-integration/references/abap-error-handling-resilience.md`.
