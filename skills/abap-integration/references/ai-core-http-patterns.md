# SAP AI Core — HTTP Integration Patterns (On-Premise / Standard ABAP)

**Scope:** Standard ABAP (S/4HANA on-premise, ECC, ABAP Platform) calling the SAP AI Core
Generative AI Hub REST API using `CL_WEB_HTTP_CLIENT_MANAGER`.

> **ABAP Cloud path (S/4HANA Cloud / BTP ABAP Env):** Use the ABAP AI SDK + ISLM +
> communication scenario SAP_COM_0A69 instead — see the `abap-cloud-governance` skill's
> `generative-ai-abap-cloud.md`. This guide is for landscapes where the ABAP AI SDK is not available.

---

## Architecture Overview

```
S/4HANA On-Premise / Standard ABAP
        │
        │  CL_WEB_HTTP_CLIENT_MANAGER
        │  SM59 HTTP destination  +  STRUST SSL certificate
        │  OAuth 2.0 Client Credentials token fetch
        ▼
SAP AI Core REST API
  POST /v2/inference/deployments/{deploymentId}/chat/completions
  POST /v2/inference/deployments/{deploymentId}/embeddings
        │
        ▼
Generative AI Hub  →  GPT-4o / Claude / Gemini / Llama ...
```

---

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| SAP AI Core instance on BTP | `extended` plan; service key created |
| Model deployed in AI Launchpad | Deployment ID in **Running** state (see below) |
| HTTPS connectivity | On-premise system can reach `api.ai.<region>.ml.hana.ondemand.com:443` |
| SSL certificate imported | AI Core endpoint cert chain imported in STRUST |
| SM59 destination created | Two destinations: one for token endpoint, one for AI API |
| ABAP release | S/4HANA 1809+ for `CL_WEB_HTTP_CLIENT_MANAGER`; 7.50+ for classic `CL_HTTP_CLIENT` |
| Authorization | User/technical user has auth for outbound HTTP calls (`S_ICF`, `S_HTTP_CO`) |

### Retrieving AI Core Service Key Credentials

```bash
# From BTP Cockpit or CF CLI
cf service-key <aicore-instance-name> <service-key-name>
```

Extract:
| Field | Used For |
|-------|----------|
| `clientid` | OAuth2 client ID |
| `clientsecret` | OAuth2 client secret |
| `url` | Token endpoint base — append `/oauth/token` |
| `serviceurls.AI_API_URL` | AI Core REST API base URL |

### Finding the Deployment ID

```
AI Launchpad → Generative AI Hub → Deployments
→ click your deployment → Details tab → Deployment ID
Format: d<alphanumeric>  e.g. d3f8a1bc29e7
Status must be: Running
```

---

## Step 1 — Import SSL Certificate (STRUST)

The AI Core endpoint uses a certificate signed by a public CA (DigiCert / GlobalSign).
You must import the full chain into STRUST before HTTPS calls succeed.

```
Transaction: STRUST
Node: SSL client SSL Client (Standard)
  → Double-click to open
  → Certificate area → Import (from file or paste PEM)
  → Import the leaf certificate + all intermediate CAs
  → Add to Certificate List
  → Save

Alternatively:
  Use transaction SMICM → Go To → Services → check HTTPS is active
  Use STRUST → Export PSE to test connectivity with transaction SMPW or SM59 "Test Connection"
```

Common error if cert is missing:
```
HTTP_COMMUNICATION_FAILURE  with SSL error: HANDSHAKE_FAILURE
ICM_HTTP_CONNECTION_FAILED
```

---

## Step 2 — Create SM59 Destinations

Create **two** SM59 destinations: one for the OAuth2 token endpoint, one for the AI API.

### Destination A — Token Endpoint

```
Transaction: SM59 → Create → HTTP Connection to External Server

Connection Type:  G (HTTP Connection to External Server)
Description:      AI Core OAuth Token Endpoint

Technical Settings tab:
  Target Host:    <host from 'url' field in service key>
                  e.g. <subdomain>.authentication.eu10.hana.ondemand.com
  Port:           443
  Path Prefix:    /oauth/token

Logon & Security tab:
  SSL:            Active
  SSL Certificate: DFAULT (or your custom SSL client PSE)

Save → Test Connection → should return HTTP 200 or redirect
```

### Destination B — AI Core API Endpoint

```
Transaction: SM59 → Create → HTTP Connection to External Server

Connection Type:  G
Description:      SAP AI Core Generative AI Hub

Technical Settings tab:
  Target Host:    <host from AI_API_URL>
                  e.g. api.ai.eu10.ml.hana.ondemand.com
  Port:           443
  Path Prefix:    /v2

Logon & Security tab:
  SSL:            Active
  SSL Certificate: DFAULT

Save → Test Connection → should return HTTP 404 (no path) or 401 — both confirm connectivity
```

---

## Step 3 — ABAP Implementation

### Helper: Fetch OAuth2 Token

```abap
CLASS zcl_ai_core_token DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS get_bearer_token
      IMPORTING iv_dest_token    TYPE rfcdest        " SM59 destination A
                iv_client_id     TYPE string
                iv_client_secret TYPE string
      RETURNING VALUE(rv_token)  TYPE string
      RAISING   cx_web_http_client_error
                cx_http_no_current_session.
ENDCLASS.

CLASS zcl_ai_core_token IMPLEMENTATION.
  METHOD get_bearer_token.
    " Create HTTP client from SM59 destination
    DATA(lo_client) = cl_web_http_client_manager=>create_by_destination(
      i_destination = iv_dest_token ).

    DATA(lo_req) = lo_client->get_http_request( ).
    lo_req->set_method( if_web_http_request=>co_request_method_post ).
    lo_req->set_header_field(
      i_name  = 'Content-Type'
      i_value = 'application/x-www-form-urlencoded' ).

    " Client credentials grant
    DATA(lv_body) = 'grant_type=client_credentials'
      && '&client_id='     && cl_http_utility=>escape_url( iv_client_id )
      && '&client_secret=' && cl_http_utility=>escape_url( iv_client_secret ).
    lo_req->set_text( lv_body ).

    DATA(lo_resp) = lo_client->execute(
      i_method = if_web_http_request=>co_request_method_post ).

    DATA(lv_status) = lo_resp->get_http_response( )->get_status( ).
    IF lv_status-code <> 200.
      RAISE EXCEPTION TYPE cx_web_http_client_error.
    ENDIF.

    " Parse access_token from JSON response
    " Response: {"access_token":"...","token_type":"bearer","expires_in":43199}
    DATA(lv_json) = lo_resp->get_http_response( )->get_text( ).
    FIND REGEX '"access_token"\s*:\s*"([^"]+)"'
      IN lv_json SUBMATCHES rv_token.

    lo_client->close( ).
  ENDMETHOD.
ENDCLASS.
```

### Chat Completion — Full Example

```abap
CLASS zcl_ai_core_chat DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS chat_completion
      IMPORTING iv_system_prompt  TYPE string
                iv_user_prompt    TYPE string
                iv_deployment_id  TYPE string  " e.g. 'd3f8a1bc29e7'
                iv_resource_group TYPE string  " e.g. 'default'
                iv_dest_token     TYPE rfcdest " SM59 token destination
                iv_dest_api       TYPE rfcdest " SM59 AI API destination
                iv_client_id      TYPE string
                iv_client_secret  TYPE string
      RETURNING VALUE(rv_answer)  TYPE string
      RAISING   cx_web_http_client_error
                cx_http_no_current_session.
ENDCLASS.

CLASS zcl_ai_core_chat IMPLEMENTATION.
  METHOD chat_completion.
    " Step 1: Get OAuth2 bearer token
    DATA(lv_token) = zcl_ai_core_token=>get_bearer_token(
      iv_dest_token    = iv_dest_token
      iv_client_id     = iv_client_id
      iv_client_secret = iv_client_secret ).

    " Step 2: Build request JSON payload
    " Escape user content to prevent JSON injection
    DATA(lv_sys_esc)  = iv_system_prompt.
    DATA(lv_usr_esc)  = iv_user_prompt.
    REPLACE ALL OCCURRENCES OF '"'  IN lv_sys_esc WITH '\"'.
    REPLACE ALL OCCURRENCES OF '"'  IN lv_usr_esc WITH '\"'.
    REPLACE ALL OCCURRENCES OF '\'  IN lv_sys_esc WITH '\\'.
    REPLACE ALL OCCURRENCES OF '\'  IN lv_usr_esc WITH '\\'.

    DATA(lv_payload) =
      |{ "messages": [| &&
      |  { "role": "system", "content": "{ lv_sys_esc }" },| &&
      |  { "role": "user",   "content": "{ lv_usr_esc }" }| &&
      |], "max_tokens": 1000, "temperature": 0.7 }|.

    " Step 3: Call AI Core chat completion endpoint
    DATA(lo_client) = cl_web_http_client_manager=>create_by_destination(
      i_destination = iv_dest_api ).

    DATA(lo_req) = lo_client->get_http_request( ).
    lo_req->set_method( if_web_http_request=>co_request_method_post ).

    " Set path: /v2/inference/deployments/{id}/chat/completions
    lo_req->set_header_field(
      i_name  = ':path'
      i_value = |/v2/inference/deployments/{ iv_deployment_id }/chat/completions| ).
    lo_req->set_header_field(
      i_name  = 'Content-Type'
      i_value = 'application/json' ).
    lo_req->set_header_field(
      i_name  = 'Authorization'
      i_value = |Bearer { lv_token }| ).
    lo_req->set_header_field(
      i_name  = 'AI-Resource-Group'
      i_value = iv_resource_group ).

    lo_req->set_text( lv_payload ).

    DATA(lo_resp)   = lo_client->execute(
      i_method = if_web_http_request=>co_request_method_post ).
    DATA(lo_http)   = lo_resp->get_http_response( ).
    DATA(lv_status) = lo_http->get_status( ).

    IF lv_status-code <> 200.
      DATA(lv_err) = lo_http->get_text( ).
      " Log and raise — do not swallow errors silently
      RAISE EXCEPTION TYPE cx_web_http_client_error.
    ENDIF.

    " Step 4: Parse response
    " Response structure:
    " { "choices": [{ "message": { "role": "assistant", "content": "..." } }],
    "   "usage": { "total_tokens": 123 } }
    DATA(lv_response_json) = lo_http->get_text( ).

    " Extract content from first choice using regex
    FIND REGEX '"content"\s*:\s*"((?:[^"\\]|\\.)*)"'
      IN lv_response_json
      SUBMATCHES rv_answer.

    " Unescape JSON string escapes
    REPLACE ALL OCCURRENCES OF '\n'  IN rv_answer WITH cl_abap_char_utilities=>newline.
    REPLACE ALL OCCURRENCES OF '\t'  IN rv_answer WITH cl_abap_char_utilities=>horizontal_tab.
    REPLACE ALL OCCURRENCES OF '\"'  IN rv_answer WITH '"'.
    REPLACE ALL OCCURRENCES OF '\\'  IN rv_answer WITH '\'.

    lo_client->close( ).
  ENDMETHOD.
ENDCLASS.
```

### Text Embedding Example

```abap
METHOD generate_embedding.
  DATA(lv_token) = zcl_ai_core_token=>get_bearer_token(
    iv_dest_token    = iv_dest_token
    iv_client_id     = iv_client_id
    iv_client_secret = iv_client_secret ).

  DATA(lo_client) = cl_web_http_client_manager=>create_by_destination(
    i_destination = iv_dest_api ).

  DATA(lo_req) = lo_client->get_http_request( ).
  lo_req->set_method( if_web_http_request=>co_request_method_post ).
  lo_req->set_header_field(
    i_name  = ':path'
    i_value = |/v2/inference/deployments/{ iv_embed_deployment_id }/embeddings| ).
  lo_req->set_header_field( i_name = 'Content-Type'    i_value = 'application/json' ).
  lo_req->set_header_field( i_name = 'Authorization'   i_value = |Bearer { lv_token }| ).
  lo_req->set_header_field( i_name = 'AI-Resource-Group' i_value = iv_resource_group ).

  " Escape and send the input text
  DATA(lv_text_esc) = iv_text.
  REPLACE ALL OCCURRENCES OF '"' IN lv_text_esc WITH '\"'.
  lo_req->set_text( |{ "input": "{ lv_text_esc }" }| ).

  DATA(lo_resp) = lo_client->execute(
    i_method = if_web_http_request=>co_request_method_post ).

  " Response: { "data": [{ "embedding": [0.123, -0.456, ...] }] }
  " Parse the float array from data[0].embedding
  DATA(lv_json) = lo_resp->get_http_response( )->get_text( ).
  " ... parse lv_json into a float table using /ui2/cl_json or regex ...

  lo_client->close( ).
ENDMETHOD.
```

---

## AI Core REST API Reference

| Operation | Method | Path |
|-----------|--------|------|
| Chat completion | POST | `/v2/inference/deployments/{deploymentId}/chat/completions` |
| Text embedding | POST | `/v2/inference/deployments/{deploymentId}/embeddings` |
| List deployments | GET | `/v2/admin/deployments?resourceGroup={rg}` |
| Deployment status | GET | `/v2/admin/deployments/{deploymentId}` |

**Required headers on every inference call:**
```
Authorization:    Bearer <access_token>
AI-Resource-Group: <resource_group_id>
Content-Type:     application/json
```

---

## Error Handling and Resilience

Apply the same resilience patterns as any outbound call — see `abap-error-handling-resilience.md`.

| HTTP Status | Meaning | Action |
|-------------|---------|--------|
| 200 | Success | Parse response |
| 400 | Bad request | Log payload; fix JSON structure |
| 401 | Unauthorized | Token expired — re-fetch token; check clientid/secret |
| 403 | Forbidden | Wrong resource group; check `AI-Resource-Group` header |
| 404 | Not found | Deployment ID wrong or deployment stopped; check AI Launchpad |
| 429 | Rate limit | Retry with exponential backoff; upgrade plan for higher quota |
| 500/503 | AI Core error | Log and retry; check AI Launchpad for service health |

**Token caching:** OAuth2 tokens are valid for ~43,000 seconds (~12 hours). Cache the token in memory or a shared buffer (e.g. shared memory object) rather than fetching a new one on every call. Re-fetch when the token is within 60 seconds of expiry.

```abap
" Simple token cache using class attribute
CLASS-DATA gv_token      TYPE string.
CLASS-DATA gv_expiry_utc TYPE utclong.

METHOD get_cached_token.
  DATA(lv_now) = utclong_current( ).
  " Re-fetch if expired or within 60-second safety margin
  IF gv_token IS INITIAL
    OR cl_abap_utclong=>diff( i_utclong1 = gv_expiry_utc
                               i_utclong2 = lv_now ) < 60.
    gv_token = zcl_ai_core_token=>get_bearer_token( ... ).
    " Set expiry: now + 43000 seconds
    gv_expiry_utc = cl_abap_utclong=>add(
      i_utclong = lv_now
      i_seconds = 43000 ).
  ENDIF.
  rv_token = gv_token.
ENDMETHOD.
```

---

## Governance Notes

- **No hardcoded credentials:** store `clientid` and `clientsecret` in a secure store (RFC Destination with encrypted password, SAP Credential Store, or system profile parameter) — never in source code.
- **Never log raw prompts** containing business data to standard application logs without masking.
- **On-premise data boundary:** data leaves the system boundary to the AI Core endpoint. Apply the same data privacy controls as for any external REST call.
- **Deployment IDs are not permanent:** if a model is redeployed, the deployment ID changes. Store the ID in a customizing table (e.g. maintained via SM30 / Custom Business Configuration), not hardcoded.
