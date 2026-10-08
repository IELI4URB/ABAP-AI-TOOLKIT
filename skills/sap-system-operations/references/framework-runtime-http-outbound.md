# Framework and Runtime Issues — HTTP / SOAP Outbound

## §4 — HTTP Outbound: 401 Unauthorized / 403 Forbidden / Timeout

**Exception / Symptom:** An outbound HTTP call from ABAP to an external system fails. The ABAP exception `CX_WEB_HTTP_CLIENT_ERROR` is raised, or the response status code is 401, 403, 408, 503, or 504. The interface stops working after a weekend or after a password rotation. No data reaches the target system; downstream process stalls.

**Landscapes:** Public Cloud (BTP ABAP) · Private Cloud · On-Premise S/4HANA

---

### Root Cause

| Status | Root Cause | Typical Trigger |
|--------|-----------|-----------------|
| **401** | Authentication failed — credentials rejected | Password rotated in target system; OAuth token expired; wrong username in destination |
| **403** | Authenticated but not authorized for the resource | Service user missing role/scope in target; IP allowlist changed; API key revoked |
| **408 / 504** | Request timeout | Target system under load; network latency spike; connection pool exhausted |
| **503** | Service unavailable | Target system in maintenance; load balancer returning 503 |
| `CX_WEB_HTTP_CLIENT_ERROR` (network) | TCP connection refused or DNS failure | Destination host unreachable; firewall rule change; wrong port in destination config |

**Most common real-world cause:** An OAuth2 client credentials flow token is cached and used beyond its expiry (`expires_in`). Over a weekend the token expires, the first Monday-morning call returns 401, and the interface appears to have "stopped working by itself."

---

### Diagnosis

| Step | Fiori App (Public Cloud) | T-Code (On-Premise / Private Cloud) |
|------|--------------------------|--------------------------------------|
| 1 — Confirm status code | Read from exception / log | Read from `lo_response->get_status( )-code` in error log / ST22 |
| 2 — Test destination manually | **Communication Arrangements** Fiori app → select arrangement → *Check Connection* | `SM59` → select destination → *Connection Test* |
| 3 — Check service user (401) | **Communication Arrangements** → service user → check locked/expired | `SU01` → check user status; `SM59` → Logon & Security tab |
| 4 — Check authorization (403) | Target system admin: check role/scope assigned to service user | Target system: `SU53` for the service user; check API gateway authorization |
| 5 — Check network timeout | BTP Connectivity service logs; check target system response time | `SMICM` → *Goto → Active Services* to verify ICM; network team |
| 6 — App log of HTTP call | **Application Logs** Fiori app | `SLG1` → filter by interface application log object |

---

### Fix Pattern (ABAP code)

**Fix A — Complete HTTP client with status-code-based error routing**

```abap
"════════════════════════════════════════════════════════════════
" Production-grade outbound HTTP call with explicit status routing
" Uses IF_WEB_HTTP_CLIENT (Public Cloud compatible)
"════════════════════════════════════════════════════════════════
METHOD call_external_service.

  DATA: lo_client   TYPE REF TO if_web_http_client,
        lo_response TYPE REF TO if_web_http_response,
        lv_status   TYPE i,
        lv_body     TYPE string.

  TRY.
      " ── Create HTTP client from destination ──────────────────
      " On Public Cloud: destination = Communication Arrangement
      " On-Premise:      destination = SM59 RFC/HTTP destination
      DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                        comm_scenario = 'ZEXTERNAL_SYSTEM_CS'
                        service_id    = 'ZEXTERNAL_HTTP_SRV'  ).

      lo_client = cl_web_http_client_manager=>create_by_http_destination(
                    i_destination = lo_dest ).

      " ── Set headers and request body ─────────────────────────
      lo_client->get_http_request( )->set_header_fields(
        VALUE #(
          ( name = 'Content-Type' value = 'application/json' )
          ( name = 'Accept'       value = 'application/json' )
        ) ).

      lo_client->get_http_request( )->set_text( iv_text ).

      " ── Execute and route on status code ─────────────────────
      lo_response = lo_client->execute( if_web_http_client=>post ).
      lv_status   = lo_response->get_status( )-code.

      CASE lv_status.

        WHEN 200 OR 201 OR 204.
          " Success
          IF lv_status <> 204.  " 204 = No Content
            lv_body = lo_response->get_text( ).
          ENDIF.
          ev_response_body = lv_body.

        WHEN 400.
          " Bad Request — our payload is malformed; do not retry
          DATA(lv_err_body) = lo_response->get_text( ).
          RAISE EXCEPTION TYPE zcx_http_bad_request
            EXPORTING
              status_code   = lv_status
              response_body = lv_err_body.

        WHEN 401.
          " Unauthorized — token/credential issue
          " Alert operations; do NOT retry immediately (will lock account)
          me->write_app_log(
            iv_severity = 'E'
            iv_text     = |HTTP 401 from { iv_endpoint }: |
                       && |credentials rejected. Manual intervention required.| ).

          RAISE EXCEPTION TYPE zcx_http_auth_error
            EXPORTING status_code = lv_status.

        WHEN 403.
          " Forbidden — authenticated but no authorization for resource
          me->write_app_log(
            iv_severity = 'E'
            iv_text     = |HTTP 403 from { iv_endpoint }: |
                       && |service user lacks authorization for this resource.| ).

          RAISE EXCEPTION TYPE zcx_http_forbidden
            EXPORTING status_code = lv_status.

        WHEN 408 OR 502 OR 503 OR 504.
          " Transient error — safe to retry with exponential backoff
          RAISE EXCEPTION TYPE zcx_http_transient_error
            EXPORTING
              status_code = lv_status
              retry_after = COND #( WHEN lv_status = 503
                                    THEN CONV i(
                                           lo_response->get_header_field( 'Retry-After' ) )
                                    ELSE 30 ).

        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_http_call_failed
            EXPORTING
              status_code   = lv_status
              response_body = lo_response->get_text( ).

      ENDCASE.

    CATCH cx_web_http_client_error INTO DATA(lx_http).
      " Network-level failure (TCP refused, DNS error, TLS error)
      me->write_app_log(
        iv_severity = 'E'
        iv_text     = |HTTP client error connecting to { iv_endpoint }: |
                   && lx_http->get_text( ) ).

      RAISE EXCEPTION TYPE zcx_connectivity_error
        EXPORTING previous = lx_http.

    CLEANUP.
      " Always release the HTTP client to avoid connection pool exhaustion
      IF lo_client IS BOUND.
        lo_client->close( ).
      ENDIF.
  ENDTRY.

ENDMETHOD.
```

**Fix B — OAuth2 token refresh via Communication Arrangement (Public Cloud — never hardcode tokens)**

```abap
"════════════════════════════════════════════════════════════════
" ✅  CORRECT — let the Communication Arrangement / BTP
"     Destination Service manage token lifecycle automatically.
"     cl_http_destination_provider handles token caching and
"     refresh transparently when the destination is typed as
"     OAuth2 Client Credentials in the Communication Arrangement.
"════════════════════════════════════════════════════════════════
DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                  comm_scenario = 'ZEXTERNAL_OAUTH_CS'
                  service_id    = 'ZEXTERNAL_OAUTH_SRV' ).
" The framework fetches and caches the token automatically.
" Token refresh on expiry is handled by the framework — no
" manual token management needed.
DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination(
                    i_destination = lo_dest ).


"════════════════════════════════════════════════════════════════
" ❌  WRONG — manual token fetch and caching in a static variable
"     Token will expire and calls will return 401 until restart
"════════════════════════════════════════════════════════════════
" CLASS-DATA: gv_token TYPE string,
"             gv_token_expiry TYPE timestamp.
"
" IF sy-uzeit > gv_token_expiry.  " ← unreliable; use framework!
"   gv_token = fetch_new_oauth_token( ).
" ENDIF.
" lo_request->set_header_field( name = 'Authorization'
"                                value = |Bearer { gv_token }| ).
```

**Fix C — Retry with exponential backoff for transient errors**

```abap
METHOD call_with_retry.

  CONSTANTS: c_max_retries TYPE i VALUE 3,
             c_base_wait   TYPE i VALUE 5.   " seconds

  DATA: lv_attempt    TYPE i VALUE 1,
        lv_wait_secs  TYPE i.

  DO c_max_retries TIMES.
    lv_attempt = sy-index.

    TRY.
        me->call_external_service(
          EXPORTING iv_endpoint      = iv_endpoint
                    iv_text          = iv_request_body
          IMPORTING ev_response_body = DATA(lv_response) ).

        " Success — exit retry loop
        ev_response_body = lv_response.
        RETURN.

      CATCH zcx_http_transient_error INTO DATA(lx_transient).
        IF lv_attempt < c_max_retries.
          " Exponential backoff: 5s, 10s, 20s
          lv_wait_secs = c_base_wait * ( 2 ** ( lv_attempt - 1 ) ).
          me->write_app_log(
            iv_severity = 'W'
            iv_text     = |Transient HTTP { lx_transient->status_code } — |
                       && |retry { lv_attempt }/{ c_max_retries } |
                       && |in { lv_wait_secs }s| ).
          WAIT UP TO lv_wait_secs SECONDS.
        ELSE.
          " Max retries exhausted — re-raise for caller to handle
          RAISE EXCEPTION lx_transient.
        ENDIF.

      CATCH zcx_http_auth_error
            zcx_http_forbidden
            zcx_http_bad_request
            zcx_connectivity_error.
        " Non-transient errors — do not retry; re-raise immediately
        RAISE.
    ENDTRY.
  ENDDO.

ENDMETHOD.
```

---

### Landscape Notes

| Aspect | Public Cloud (BTP ABAP) | Private Cloud / On-Premise |
|--------|-------------------------|----------------------------|
| Destination management | **Communication Arrangements** Fiori app | `SM59` (HTTP destinations) |
| Credential update (401) | Communication Arrangements → select arrangement → update service user credentials | `SM59` → destination → *Logon & Security* tab → update password |
| Service user lock check | **Communication Arrangements** → service user → check active/locked | `SU01` → user → check locked/password expired |
| OAuth2 token management | Framework handles via Communication Arrangement type = OAuth2 | Custom token management via `CL_HTTP_UTILITY` or ABAP OAuth library |
| Timeout configuration | Communication Arrangement connection timeout settings | `SM59` → *Special Options* → timeout values |
| TLS certificate errors | Managed by BTP; upload trusted CA in BTP Cockpit if needed | `STRUST` → SSL client identity → import CA certificate |
| Network routing | BTP Connectivity Service + Cloud Connector for on-premise targets | Direct network routing; check with basis for firewall rules |

> **On-Premise SM59 quick fix for 401:** Navigate to `SM59` → double-click the destination → *Logon & Security* tab → update the *Password* field → *Save* → click *Connection Test* to verify. The change takes effect immediately for new HTTP calls (no restart required).

> **Private/Public Cloud credential rotation process:** When a target system rotates its service account password, the standard process is: target system admin rotates password → sends new password to integration team via secure channel → integration admin updates Communication Arrangement or SM59 → confirms with connection test. Automate this notification with a runbook to prevent the "works on Friday, broken on Monday" pattern.

---

### Prevention

- Use the Communication Arrangement framework (Public Cloud) or SM59 (On-Premise) for all credentials — never hardcode passwords, tokens, or API keys in ABAP programs.
- Implement a **connection health-check report** that runs daily and performs a lightweight HEAD or OPTIONS request to each external HTTP endpoint; alert if status is not 2xx/401. This surfaces connectivity issues before they affect business processes.
- Design retry logic (as shown in Fix C) for all outbound integrations so that brief target-system maintenance windows do not cause data loss.
- For OAuth2 integrations, confirm the `expires_in` value of the token with the target API team and ensure the Communication Arrangement is configured with the correct token endpoint and scope.
- Establish a **credential rotation runbook**: define who is responsible for updating ABAP destination credentials when a target system rotates passwords, how quickly it must be done, and how to test. Set a calendar reminder 1 week before known password expiry dates.
