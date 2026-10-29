---
name: generative-ai-abap-cloud
description: 'Generative AI in ABAP Cloud. Use for the two AI use cases — AI-assisted ABAP development (Joule for Developers) and embedding generative AI into custom ABAP apps via the SAP AI SDK for ABAP and Intelligent Scenario Lifecycle Management (ISLM). Covers system requirements by landscape, BTP + ABAP setup steps, SAP_COM_0A69 communication arrangement, ABAP AI SDK code examples, model availability, deployment ID wiring, and data-privacy governance.'
metadata:
  version: 2.1.0
  tags: abap generative-ai joule ai-sdk islm intelligent-scenario abap-cloud btp sap-com-0a69 generative-ai-hub
---

# Generative AI in ABAP Cloud

Source: SAP Help — [Generative AI in ABAP Cloud](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/generative-ai-in-abap-cloud).

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

All classes/interfaces below are the **released** ABAP AI SDK Completion API, verified against
SAP Help — [API Reference Guide for ABAP AI SDK](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/api-reference-guide-for-abap-ai-sdk)
and [Calling The Completion API](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/calling-completion-api).
Confirm your release level in ADT; the objects are released APIs.

### Released Objects

| Object | Type | Role |
|--------|------|------|
| `CL_AIC_ISLM_COMPL_API_FACTORY` | Class | Factory; static method `GET( )` |
| `IF_AIC_ISLM_COMPL_API_FACTORY` | Interface | Factory instance; `CREATE_INSTANCE( <scenario> )` |
| `IF_AIC_COMPLETION_API` | Interface | `EXECUTE_FOR_STRING`, `EXECUTE_FOR_MESSAGES`, `CREATE_MESSAGE_CONTAINER`, `GET_PARAMETER_SETTER` |
| `IF_AIC_COMPLETION_API_RESULT` | Interface | `GET_COMPLETION`, `GET_PROMPT_TOKEN_COUNT`, `GET_COMPLETION_TOKEN_COUNT`, `GET_TOTAL_TOKEN_COUNT`, `GET_FINISH_REASON`, `GET_ORIGINAL_FINISH_REASON`, `GET_RUNTIME_MS` |
| `IF_AIC_COMPLETION_PARAMETERS` | Interface | `SET_TEMPERATURE`, `SET_MAXIMUM_TOKENS`, `SET_ANY_PARAMETER` |
| `CX_AIC_COMPLETION_API` | Exception | API/LLM errors; attribute `API_ERROR` → `IF_AIC_API_ERROR` |
| `IF_AIC_API_ERROR` | Interface | `GET_CODE` (ENUM), `GET_ORIGINAL_CODE`, `GET_ORIGINAL_MESSAGE` |

The API is **vendor-independent** — the same calls work regardless of the LLM behind the
intelligent scenario. The scenario name (configured in ISLM, Step 4) carries the connection and
the model, so **no deployment ID or credentials appear in application code**.

### Chat Completion — Single Prompt

```abap
" Factory → completion API for an ISLM intelligent scenario
FINAL(api) = cl_aic_islm_compl_api_factory=>get(
  )->create_instance( 'Z_MY_AI_SCENARIO' ).

" Optional: set model parameters (bound to this API instance, reused across calls)
FINAL(params) = api->get_parameter_setter( ).
params->set_temperature( '0.5' ).
params->set_maximum_tokens( 1000 ).

FINAL(response) = api->execute_for_string( 'How are you?' )->get_completion( ).
```

### Multi-Turn Chat (message container)

```abap
FINAL(api) = cl_aic_islm_compl_api_factory=>get(
  )->create_instance( 'Z_MY_AI_SCENARIO' ).

FINAL(messages) = api->create_message_container( ).
messages->set_system_role( 'You are an ABAP expert' ).
messages->add_user_message( 'Does ABAP support OO programming?' ).
messages->add_assistant_message( 'Yes' ).
messages->add_user_message( 'Can you build RESTful applications in ABAP?' ).

FINAL(response) = api->execute_for_messages( messages )->get_completion( ).
```

### Reading Token Counts and Finish Reason

```abap
FINAL(result)       = api->execute_for_string( 'How are you?' ).
FINAL(response)     = result->get_completion( ).
FINAL(total_tokens) = result->get_total_token_count( ).
FINAL(finish)       = result->get_finish_reason( ).           " standardized
FINAL(orig_finish)  = result->get_original_finish_reason( ).  " as returned by the LLM
```

### Error Handling

`EXECUTE_FOR_*` raise `CX_AIC_COMPLETION_API` for connection/configuration errors and for
LLM / service-provider errors that carry a known error code. Unknown codes or programming errors
(for example wrong parameters) raise a **short dump**, not a catchable exception — so do not
blanket-catch to hide bugs.

```abap
TRY.
    FINAL(response) = api->execute_for_string( xxl_prompt )->get_completion( ).

  CATCH cx_aic_completion_api INTO FINAL(lx).
    " api_error is populated when the LLM / AI service provider reports a code
    CASE lx->api_error->get_code( ).
      WHEN if_aic_api_error=>context_length_exceeded.
        " prompt too large — truncate or summarize, then retry
      WHEN if_aic_api_error=>content_filter.
        " blocked by content policy — do not retry unchanged
      WHEN if_aic_api_error=>invalid_prompt.
        " malformed / repetitive prompt
    ENDCASE.
    " raw provider values for logging
    FINAL(raw_code) = lx->api_error->get_original_code( ).
    FINAL(raw_msg)  = lx->api_error->get_original_message( ).
ENDTRY.
```

> **ADT quota exception:** When implementing an IDE action, do **not** catch
> `CX_AIQUOTA_ADT_LIMIT_EXCEEDED` — let the ADT action framework handle it in the client.

> **Embeddings / multi-model routing:** The Completion API covers text generation. For embeddings
> or routing across several models from one deployment, use the Generative AI Hub **Orchestration**
> service — see the `abap-integration` skill's `ai-core-http-patterns.md` (raw REST) or SAP Help
> [Orchestration](https://help.sap.com/docs/sap-ai-core/sap-ai-core-service-guide/orchestration-8d022355037643cebf775cd3bf662cc5).

---

## Governance for AI Features

- **Released-API discipline:** use only the released SAP AI SDK for ABAP / ISLM APIs. Verify release state and C1 contract exactly as for any consumed API (see `clean-core-api-extension-governance.md`, `official-abap-cloud-apis-and-releases.md`).
- **Data privacy / grounding:** prompts and grounding data may leave the ABAP boundary to the model service. Do not send PII, secrets, personal data, or unreleased SAP content to a model without proper data-privacy and masking controls. Never embed credentials in prompts.
- **Determinism:** generative output is non-deterministic — validate and constrain model output before acting on it in a business process. Do not treat raw model output as verified fact or production-ready code.
- **Availability** is edition/release-dependent and some capabilities require an additional Joule for Developers license — confirm for the target landscape before development commitment.
- **Resilience:** apply the same timeout, retry, and circuit-breaker patterns as for any external HTTP call — see `abap-integration/references/abap-error-handling-resilience.md`.

---

## Authoritative Sources

**Generative AI in ABAP Cloud (`abap-ai`)**
- [Overview — two use cases](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/generative-ai-in-abap-cloud)
- [ABAP AI SDK powered by ISLM](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/abap-ai-sdk-powered-by-intelligent-scenario-lifecycle-management)
- [Set Up ABAP AI SDK powered by ISLM](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/set-up-abap-ai-sdk-powered-by-intelligent-scenario-lifecycle-management)
- [API Reference Guide for ABAP AI SDK](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/api-reference-guide-for-abap-ai-sdk)
- [Calling The Completion API](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/calling-completion-api)
- [Catchable Exceptions](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/catchable-exceptions)
- [Joule for Developers, ABAP AI Capabilities](https://help.sap.com/docs/abap-ai)
- [ABAP Cloud Documentation Landscape](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/abap-cloud-documentation-landscape)

**SAP_COM_0A69 — communication arrangement**
- [Create Communication Arrangement for SAP_COM_0A69](https://help.sap.com/docs/btp/sap-business-technology-platform/how-to-create-communication-arrangement-for-sap-com-0a69-20014a0910124c18aca114d4477c797e)
- [Configure Communication System for SAP_COM_0A69](https://help.sap.com/docs/btp/sap-business-technology-platform/how-to-configure-communication-system-for-sap-com-0a69-7d691a07627442a3b1d07000417c8056)
- [Troubleshooting SAP_COM_0A69](https://help.sap.com/docs/btp/sap-business-technology-platform/troubleshooting-84f2c28cc208493aadf5be709ec947cc)

**SAP AI Core — Generative AI Hub**
- [Generative AI Hub in SAP AI Core](https://help.sap.com/docs/sap-ai-core/sap-ai-core-service-guide/generative-ai-hub-in-sap-ai-core)
- [Create a Deployment for a Generative AI Model](https://help.sap.com/docs/sap-ai-core/sap-ai-core-service-guide/create-deployment-for-generative-ai-model-in-sap-ai-core)
- [Orchestration — single deployment, multiple models](https://help.sap.com/docs/sap-ai-core/sap-ai-core-service-guide/orchestration-8d022355037643cebf775cd3bf662cc5)

**Developer tutorials**
- [Generative AI in ABAP Cloud — tutorials index](https://developers.sap.com/concepts/generative-ai-abap-cloud/)
- [ABAP AI SDK for Generative AI](https://developers.sap.com/concepts/abap-ai-sdk/)
- [ISLM for Generative AI](https://developers.sap.com/concepts/islm-generative-ai-framework/)
