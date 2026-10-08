# Framework and Runtime Issues — AIF

## §3 — AIF Message in Error Status / Stuck Queue

**Exception / Symptom:** SAP Application Interface Framework (AIF) interface monitor displays messages with status **ERROR** or **QUEUED** (stuck, not being processed). The interface pipeline has stalled; downstream system is not receiving data. Operations team receives alert or discovers backlog on morning check.

**Landscapes:** On-Premise S/4HANA · Private Cloud (AIF installed) · Public Cloud (limited AIF availability; SAP Integration Suite often used instead — see Landscape Notes)

---

### Root Cause

| Root Cause ID | Type | Description |
|---------------|------|-------------|
| **A** | Data error | Wrong, missing, or out-of-range field value in the message payload; AIF mapping or validation BAdI rejects the message |
| **B** | Connectivity error | Target system unavailable (RFC/HTTP timeout, destination unreachable); message processed but delivery failed |
| **C** | Code error | Custom BAdI implementation raised an unhandled exception during processing |
| **D** | Configuration error | Namespace/structure version mismatch between sender and AIF interface definition; message cannot be deserialized |
| **E** | Queue saturation | High message volume or previous processing failure caused queue backlog; messages are valid but not yet processed |

---

### Diagnosis

| Step | Fiori App (Public Cloud / Private Cloud) | T-Code (On-Premise) |
|------|------------------------------------------|----------------------|
| 1 — Open interface monitor | **Interface Monitor** Fiori app (`/AIF/IFMON` Fiori equivalent) | `/AIF/IFMON` |
| 2 — Filter by interface/date | Use filter panel: Namespace, Interface Name, Version, Date range, Status = ERROR | Same filter options in `/AIF/IFMON` |
| 3 — Read error detail | Select failed message → *Error Log* tab → read exception class + message | Select message → *Error Info* → read error text and stack |
| 4 — Distinguish data vs. system error | Data error: error in mapping/validation step; System error: error in send/deliver step | Same — note which processing step failed |
| 5 — Check queue status | **Queue Monitor** Fiori app | `/AIF/QMON` |
| 6 — Check RFC/HTTP destination | Communication Arrangements (cloud) | `SM59` → connection test |
| 7 — Check custom BAdI code | ADT → find BAdI implementation class | `SE18`/`SE19` → locate BAdI impl |

**Reading error detail in `/AIF/IFMON`:**
Select a failed message → click *Error Log* (bottom panel). The log entry shows:
- **Error Class:** the exception class (e.g. `CX_AIF_MAPPING_ERROR`, custom `ZCX_*`)
- **Error Text:** the exception message text
- **Processing Step:** which AIF step failed (Mapping, Validation, Send, Post)
- **Stack Trace:** (if a dump occurred) link to ST22

---

### Fix Pattern (ABAP code)

**Fix A — Reprocess a correctable data error message**

```abap
"════════════════════════════════════════════════════════════════
" Option 1 (preferred for single messages):
" No code needed — use the AIF message editor
"
" /AIF/IFMON or Interface Monitor Fiori app:
"   1. Select the failed message
"   2. Click "Edit Message" (pencil icon)
"   3. Correct the offending field value
"   4. Click "Reprocess" (green arrow)
"
" This is the recommended path for business-user-correctable
" data errors (wrong cost center, missing plant code, etc.)
"════════════════════════════════════════════════════════════════


"════════════════════════════════════════════════════════════════
" Option 2 — Programmatic reprocess (for batch recovery scripts
" or when messages must be corrected and reprocessed en masse)
"════════════════════════════════════════════════════════════════
REPORT zr_aif_reprocess.

PARAMETERS:
  p_ns      TYPE /aif/namespace   DEFAULT '/ZNAM/',
  p_ifname  TYPE /aif/ifname      DEFAULT 'ZINTERFACE',
  p_ifver   TYPE /aif/ifversion   DEFAULT 1,
  p_guid    TYPE /aif/msg_guid.

START-OF-SELECTION.

  " Get the AIF message API instance
  DATA(lo_api) = cl_aif_message_api=>get_instance( ).

  TRY.
      " Reprocess the message identified by its GUID
      lo_api->reprocess_message(
        EXPORTING
          iv_namespace  = p_ns
          iv_ifname     = p_ifname
          iv_ifversion  = p_ifver
          iv_msg_guid   = p_guid ).

      MESSAGE |Message { p_guid } submitted for reprocessing| TYPE 'S'.

    CATCH cx_aif_api_error INTO DATA(lx_aif).
      MESSAGE lx_aif->get_text( ) TYPE 'E'.
  ENDTRY.
```

**Fix B — Catching exceptions in a custom AIF BAdI implementation (prevention of Root Cause C)**

```abap
"════════════════════════════════════════════════════════════════
" ❌  WRONG — unhandled exception in BAdI causes message ERROR
"     status with no useful error text; the exception class name
"     appears in the AIF error log but no corrective info is given
"════════════════════════════════════════════════════════════════
METHOD if_aif_application_check~check.
  DATA(lo_service) = NEW zcl_vendor_service( ).
  lo_service->validate( iv_vendor_id = is_payload-vendor_id ).
  " ← if validate( ) raises ZCX_VENDOR_NOT_FOUND, message → ERROR
ENDMETHOD.


"════════════════════════════════════════════════════════════════
" ✅  CORRECT — catch expected exceptions; write to AIF message log
"     so the operator sees a meaningful error and can correct/retry
"════════════════════════════════════════════════════════════════
METHOD if_aif_application_check~check.
  TRY.
      DATA(lo_service) = NEW zcl_vendor_service( ).
      lo_service->validate( iv_vendor_id = is_payload-vendor_id ).

    CATCH zcx_vendor_not_found INTO DATA(lx_vendor).
      " Write correctable error to AIF message log
      " The operator will see this text in the Error Log tab
      mo_msg_log->add_msg(
        EXPORTING
          iv_msg_type = /aif/if_aif_message_log=>gc_msg_type_error
          iv_msg_text = |Vendor { is_payload-vendor_id } not found in system. |
                     && |Please correct vendor ID and reprocess.|
          iv_msg_class = 'ZVENDOR'
          iv_msg_no    = '001' ).

      " Set return code so AIF marks message as ERROR (not DONE)
      ev_check_passed = abap_false.

    CATCH cx_root INTO DATA(lx_unexpected).
      " Unexpected technical error — log details for developer
      mo_msg_log->add_msg(
        EXPORTING
          iv_msg_type = /aif/if_aif_message_log=>gc_msg_type_error
          iv_msg_text = |Technical error in vendor validation: |
                     && lx_unexpected->get_text( ) ).

      ev_check_passed = abap_false.
  ENDTRY.
ENDMETHOD.
```

**Fix C — Restart a stuck queue after connectivity is restored**

```abap
"════════════════════════════════════════════════════════════════
" Via transaction (On-Premise / Private Cloud):
"   /AIF/QMON → Queue Monitor
"   → Filter by Interface / Status = STUCK or WAITING
"   → Select queue entries
"   → Click "Restart Queue" button
"
" Programmatic queue restart (for automation / post-failover):
"════════════════════════════════════════════════════════════════
REPORT zr_aif_restart_queue.

PARAMETERS:
  p_ns     TYPE /aif/namespace DEFAULT '/ZNAM/',
  p_ifname TYPE /aif/ifname    DEFAULT 'ZINTERFACE',
  p_ifver  TYPE /aif/ifversion DEFAULT 1.

START-OF-SELECTION.

  TRY.
      " Restart all waiting/stuck queue items for the interface
      /aif/cl_queue_api=>restart_queue(
        EXPORTING
          iv_namespace  = p_ns
          iv_ifname     = p_ifname
          iv_ifversion  = p_ifver ).

      MESSAGE 'Queue restart triggered' TYPE 'S'.

    CATCH /aif/cx_queue_error INTO DATA(lx_q).
      MESSAGE lx_q->get_text( ) TYPE 'E'.
  ENDTRY.
```

**Fix D — Configuring AIF alert for automatic error notification**

```abap
"════════════════════════════════════════════════════════════════
" AIF alert configuration is done via Customizing (no direct ABAP
" required), but the relevant path is:
"
" SPRO → SAP Application Interface Framework
"        → Error Handling → Define Alerts
"        → Assign Alert to Interface
"
" Alert types available:
"   • Email notification to responsible team
"   • System message / workflow item
"   • Connection to SAP Alert Framework (/SALERT/)
"
" Programmatic check of alert status (for monitoring reports):
"════════════════════════════════════════════════════════════════
DATA(lo_alert_api) = cl_aif_alert_api=>get_instance( ).

DATA(lt_alerts) = lo_alert_api->get_open_alerts(
  iv_namespace = '/ZNAM/'
  iv_ifname    = 'ZINTERFACE' ).

IF lt_alerts IS NOT INITIAL.
  " Send summary to operations team distribution list
  LOOP AT lt_alerts INTO DATA(ls_alert).
    WRITE: / ls_alert-alert_id, ls_alert-alert_text, ls_alert-created_at.
  ENDLOOP.
ENDIF.
```

---

### Landscape Notes

| Aspect | Public Cloud (BTP ABAP) | Private Cloud (AIF installed) | On-Premise |
|--------|-------------------------|-------------------------------|------------|
| AIF availability | Limited / not standard — use **SAP Integration Suite** (CPI) for new integrations | Available if installed | Full AIF available |
| Interface Monitor | **Interface Monitor** Fiori app | `/AIF/IFMON` + Fiori app | `/AIF/IFMON` |
| Queue Monitor | **Queue Monitor** Fiori app | `/AIF/QMON` + Fiori app | `/AIF/QMON` |
| Lock entries | Not accessible directly | `SM12` (if applicable) | `SM12` |
| Message editor | Fiori app *Edit Message* | Fiori app or `/AIF/IFMON` | `/AIF/IFMON` |
| RFC destination check | Communication Arrangements | `SM59` | `SM59` |
| Recommended new integrations | SAP Integration Suite (CPI flows) | AIF or Integration Suite | AIF |

> **Public Cloud — AIF vs. Integration Suite:** For greenfield Public Cloud implementations, SAP recommends **SAP Integration Suite** (Cloud Integration / CPI) for process-to-process integration rather than AIF. AIF may still be present via compatibility add-ons or private cloud extensions. For monitoring CPI flows: **Integration Operations** monitoring app in the BTP Integration Suite cockpit. Error handling and reprocess patterns differ from AIF — use the *Integration Flow Monitor* and *Message Processing Log* instead.

---

### Prevention

- Implement and test all BAdI methods with `TRY/CATCH cx_root` wrappers. Write meaningful error text to the AIF message log so that operators can self-service correct and reprocess without developer involvement.
- Configure AIF alerts (SPRO) to send email notifications to the interface operations team immediately when a message enters ERROR status — do not rely on manual monitoring.
- For connectivity-type errors (B), implement a retry scheduler: configure the AIF queue to auto-retry N times with a backoff interval before alerting. This avoids false alarms during short target-system maintenance windows.
- Maintain a **Message Error Catalog** in your operations wiki: for each interface, document the top 10 expected data errors, their AIF error text pattern, and the correction steps. This enables Level 1 support to resolve without developer escalation.
- After any transport that changes AIF interface structure or version, run a smoke-test message through the interface in the target system before declaring the transport complete.
