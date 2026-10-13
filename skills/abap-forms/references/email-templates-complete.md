# ABAP Email Templates — Complete Reference

> **Audience:** ABAP developers implementing email notifications and output in S/4HANA on-premise, private cloud, and ABAP Cloud / public cloud.
> **Platforms covered:** S/4HANA on-premise, S/4HANA Private Cloud, S/4HANA Cloud Public Edition, BTP ABAP Environment
> **Sources:** SAP Community blog (2019/2022), SAP Help Portal (ABAP Cloud ADT, S/4HANA Cloud Developer Extensibility, CL_BCS_MAIL_MESSAGE API docs)

---

## 1. Decision Matrix (Apply First)

| Environment | Primary API | Renderer | Send | Creation tool | CDS constraint |
|---|---|---|---|---|---|
| On-Prem / Private Cloud (standard ABAP) | `CL_SMTG_EMAIL_API` | `render_bcs` or `render` | `CL_BCS->send()` | SE80 / `SMTG_WB_START` | Any CDS view |
| ABAP Cloud / S/4HANA Cloud Public Edition | `CL_SMTG_EMAIL_TEMPL_RENDERER` | `render_email_message` | `CL_BCS_MAIL_MESSAGE->send()` | ADT Email Template Editor | Must annotate `OUTPUT_EMAIL_DATA_PROVIDER` AND be C1-released or same package |

**Quick rule:** Check language version first. Standard ABAP → `CL_SMTG_EMAIL_API`. ABAP Cloud → `CL_BCS_MAIL_MESSAGE` + `CL_SMTG_EMAIL_TEMPL_RENDERER`.

> **`CL_SMTG_EMAIL_API` is NOT released in ABAP Cloud.** Any code using it in cloud context will fail ATC / upgrade checks.

---

## 2. Template Anatomy

All templates (SMTG object type) share this structure:

| Section | Content |
|---|---|
| Header | Template ID (max 30 chars), description, CDS view reference |
| Texts tab | Language, CDS field reference list, email subject, body HTML, body plain text |

**Dynamic variables:** `{{cds_field_name}}` in subject or body. Field name must match the CDS view field name exactly (case-insensitive at runtime, but use exact casing to avoid surprises).

**Runtime behaviour:** Renderer selects exactly one row from the CDS view using the provided key values, then replaces all `{{...}}` placeholders. Key values map to the CDS primary key fields.

---

## 3. On-Premise / Private Cloud

### 3.1 Creation

- **SE80:** right-click package → Create → More → Email Template
- **View / edit existing:** run program `SMTG_WB_START`
- **Object type:** `SMTG`
- Template ID: max 30 characters, customer namespace (`Z_` / `Y_`)

### 3.2 CDS View (On-Prem)

No special annotation required. Any CDS view works. Must expose the fields referenced in `{{...}}` placeholders. Primary key fields are passed as data keys at runtime.

Example:
```abap
@AbapCatalog.sqlViewName: 'ZRSCDS_INVDATA'
@EndUserText.label: 'Invoice Data'
define view ZRSCDS_INVOICE_DATA as select from vbrk as h
  join vbrp as i on h.vbeln = i.vbeln {
    key h.vbeln,
    key i.posnr,
    h.fkdat,
    h.netwr,
    h.waerk,
    h.kunag,
    i.matnr,
    i.fkimg
  }
```

### 3.3 Simple Send (render_bcs)

Use `render_bcs` when the template supplies both subject and body. Simplest path — no manual document packaging.

`ty_gt_data_key` is a public type alias on `CL_SMTG_EMAIL_API`. Declare the table with the full class qualifier.

```abap
TRY.
  " 1. Get API instance for the template
  DATA(lo_email_api) = cl_smtg_email_api=>get_instance( iv_template_id = 'Z_MY_TEMPLATE' ).

  " 2. Create BCS send request
  DATA(lo_bcs) = cl_bcs=>create_persistent( ).

  " 3. CDS key — one entry per key field of the CDS view
  DATA(lt_cds_key) = VALUE cl_smtg_email_api=>ty_gt_data_key(
    ( name = 'VBELN' value = lv_billing_doc ) ).

  " 4. Render: sets subject + HTML body + plain text on lo_bcs
  lo_email_api->render_bcs(
    io_bcs      = lo_bcs
    iv_language = sy-langu
    it_data_key = lt_cds_key ).

  " 5. Sender (SAP user or internet address)
  DATA(lo_sender) = cl_sapuser_bcs=>create( sy-uname ).
  lo_bcs->set_sender( i_sender = lo_sender ).

  " 6. Recipient (internet email address)
  DATA(lo_recip) = cl_cam_address_bcs=>create_internet_address( lv_email ).
  lo_bcs->add_recipient( EXPORTING i_recipient = lo_recip ).

  " 7. Send — queued in SAPconnect (SCOT/SOST)
  lo_bcs->send( ).
  COMMIT WORK AND WAIT.

CATCH cx_smtg_email_common INTO DATA(lx_tmpl).
  " template not found, not active, CDS view inaccessible
CATCH cx_address_bcs INTO DATA(lx_addr).
  " invalid or missing email address
CATCH cx_send_req_bcs INTO DATA(lx_send).
  " BCS send request failure
ENDTRY.
```

### 3.4 Advanced Send — HTML Table Injection

Use `render` (not `render_bcs`) to get raw HTML as a string, inject dynamic table rows, then package and send manually. Required when the email body must contain a variable number of rows that cannot be bound via a single CDS key.

**Step A — Template HTML: add a comment placeholder where rows go**

```html
<table border="1" cellpadding="3"
       style="border-collapse:collapse;font-size:14px" width="100%">
  <tbody>
    <tr>
      <th>EmpID</th>
      <th>Project</th>
      <th>Planned Hrs</th>
      <th>Remaining Hrs</th>
    </tr>
    <!--///EmpContent-->
  </tbody>
</table>
```

The `<!--///EmpContent-->` comment is the injection target. Name it uniquely — use `///` prefix to avoid collision with standard HTML comments.

**Step B — ABAP: build rows, render, inject, send**

```abap
" Build HTML rows from internal table before rendering
DATA lv_rows TYPE string.
LOOP AT lt_detail INTO DATA(ls_row).
  lv_rows = |{ lv_rows }<tr>|.
  lv_rows = |{ lv_rows }<td>{ ls_row-pernr }</td>|.
  lv_rows = |{ lv_rows }<td>{ ls_row-project }</td>|.
  lv_rows = |{ lv_rows }<td>{ ls_row-planned }</td>|.
  lv_rows = |{ lv_rows }<td>{ ls_row-remaining }</td>|.
  lv_rows = |{ lv_rows }</tr>|.
ENDLOOP.

TRY.
  DATA(lo_email_api) = cl_smtg_email_api=>get_instance( iv_template_id = 'Z_MY_TEMPLATE' ).

  " render() returns raw HTML string — does NOT write to BCS
  DATA(lt_key) = VALUE cl_smtg_email_api=>ty_gt_data_key(
    ( name = 'PERNR' value = ls_emp-pernr ) ).
  lo_email_api->render(
    EXPORTING iv_language = sy-langu it_data_key = lt_key
    IMPORTING ev_body_html = DATA(lv_body_html)
              ev_subject   = DATA(lv_subject) ).

  " Inject rows at the placeholder
  REPLACE '<!--///EmpContent-->' WITH lv_rows INTO lv_body_html.

  " Package as multipart HTML document
  DATA(lo_soli)      = cl_bcs_convert=>string_to_soli( lv_body_html ).
  DATA(lo_multipart) = NEW cl_gbt_multirelated_service( ).
  lo_multipart->set_main_html(
    EXPORTING content     = lo_soli
              description = 'EmailBody' ).

  DATA(lo_doc) = cl_document_bcs=>create_from_multirelated(
    EXPORTING i_subject          = lv_subject
              i_multirel_service = lo_multipart ).

  DATA(lo_bcs) = cl_bcs=>create_persistent( ).
  lo_bcs->set_document( lo_doc ).

  DATA(lo_sender) = cl_sapuser_bcs=>create( 'SAP_WFRT' ).
  lo_bcs->set_sender( i_sender = lo_sender ).

  DATA(lo_recip) = cl_cam_address_bcs=>create_internet_address( lv_email ).
  lo_bcs->add_recipient( EXPORTING i_recipient = lo_recip ).

  lo_bcs->send( ).
  COMMIT WORK AND WAIT.

CATCH cx_smtg_email_common cx_address_bcs cx_send_req_bcs INTO DATA(lx).
  " handle: log lx->get_text( )
ENDTRY.
```

### 3.5 SMTP Setup — On-Premise (SAPconnect)

`lo_bcs->send()` queues mail in SAPconnect. A background job dispatches it via SMTP. Without this config, mail queues but never leaves.

| Step | Transaction / Action |
|---|---|
| Configure SMTP node | `SCOT` → Fax / SMTP → create or edit SMTP node, set mail server host and port |
| Set default domain | `SCOT` → Settings → Default domain (used when no explicit From domain) |
| Schedule send job | `SCOT` → Utilities → Start Send Process (or schedule `RSCONN01` periodically) |
| Inspect send queue | `SOST` → view queued / failed / sent items |
| Test single send | `SOST` → select item → Repeat Send |

**Common SCOT settings to verify:**

```
Node type:    SMTP
Description:  Corporate SMTP relay
Host:         mail.yourcompany.com
Port:         25 (or 587 for TLS)
Supported address types: Internet (check "Internet" box)
```

After any send call, check `SOST` if no email arrives. A status of `Error` there indicates SMTP relay rejection, not an ABAP code issue.

---

## 4. ABAP Cloud / S/4HANA Cloud Public Edition

### 4.1 Creation in ADT

1. File → New → Other → ABAP → Email Template (or right-click in Project Explorer → New → Other ABAP Repository Object)
2. Provide name (max 30 chars), description, package, transport request
3. Email Template Editor opens automatically
4. Assign CDS view (must meet annotation requirement — see 4.2)
5. Enter subject and HTML / plain text body
6. Use `{{cds_field_name}}` placeholders — field names match CDS view element names
7. Save and activate — template is not renderable until active

**Fiori app alternative:** "Maintain Email Templates" app (Launchpad) for business user maintenance.

### 4.2 CDS View Requirements (ABAP Cloud — Mandatory)

The CDS view **must** carry one of these annotations:

```abap
@ObjectModel.supportedCapabilities: [ #OUTPUT_EMAIL_DATA_PROVIDER ]
" OR
@ObjectModel.modelingPattern: #OUTPUT_EMAIL_DATA_PROVIDER
```

**Additionally:**
- Must be **released** for cloud development (C1 access contract) **OR** be in the same package as the calling code
- Must be in **active** state
- Without the annotation, the ADT editor will not accept the view as a template data source

Example CDS view for ABAP Cloud:

```abap
@EndUserText.label: 'Purchase Order Email Data'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.supportedCapabilities: [ #OUTPUT_EMAIL_DATA_PROVIDER ]
define view entity ZC_PO_EMAIL_DATA
  as select from ekko
{
  key  ekko.ebeln   as PurchaseOrder,
       ekko.lifnr   as Vendor,
       ekko.bedat   as OrderDate,
       ekko.netwr   as NetValue,
       ekko.waers   as Currency
}
```

### 4.3 Email Template State Requirements

Template must be **active**. States that prevent rendering:
- `Inactive` — saved but not activated
- `Deprecated` — intentionally marked as superseded
- `Obsolete` — replaced by a newer version

### 4.4 ABAP Cloud API (Released)

`ty_gt_data_key` is defined on `IF_SMTG_EMAIL_TEMPLATE`. Use the interface qualifier.

```abap
DATA lt_key     TYPE if_smtg_email_template=>ty_gt_data_key.
DATA lo_renderer TYPE REF TO if_smtg_email_templ_renderer.

TRY.
  " 1. Create mail message (released class)
  DATA(lo_message) = cl_bcs_mail_message=>create_instance( ).

  " 2. Sender (must be a configured outbound email address)
  lo_message->set_sender( 'noreply@yourcompany.com' ).

  " 3. Recipient
  lo_message->add_recipient( lv_recipient_email ).

  " 4. Create renderer (released class)
  lo_renderer = cl_smtg_email_templ_renderer=>create_instance(
    iv_template_id = 'Z_MY_TEMPLATE' ).

  " 5. Provide CDS key values — one entry per primary key field
  APPEND VALUE #( name = 'PURCHASEORDER' value = lv_ebeln ) TO lt_key.

  " 6. Render: sets subject + HTML body + plain text on lo_message
  lo_renderer->render_email_message(
    io_message  = lo_message
    iv_language = sy-langu
    it_data_key = lt_key ).

  " 7. Send — dispatched via System Email Outbound communication scenario
  lo_message->send( ).

CATCH cx_bcs_mail INTO DATA(lx_mail).
  " SMTP dispatch error — check System Email Outbound config
CATCH cx_smtg_email_common INTO DATA(lx_tmpl).
  " template not found, not active, CDS view inaccessible
ENDTRY.
```

### 4.5 Released Classes and Interfaces

| Object | Type | Purpose |
|---|---|---|
| `CL_BCS_MAIL_MESSAGE` | Class (C1 released) | Create and send email via SMTP outbound |
| `CL_SMTG_EMAIL_TEMPL_RENDERER` | Class (C1 released) | Render email template content into a mail message |
| `IF_SMTG_EMAIL_TEMPLATE` | Interface (C1 released) | Type definitions — `ty_gt_data_key`, `ty_data_key` |
| `IF_SMTG_EMAIL_TEMPL_RENDERER` | Interface (C1 released) | Renderer contract — `render_email_message`, `render` |
| `CX_BCS_MAIL` | Exception (C1 released) | Mail send / SMTP errors |
| `CX_SMTG_EMAIL_COMMON` | Exception (C1 released) | Template rendering errors |

### 4.6 Translations

Add language-specific template texts in Fiori app **"Maintain Translations"**.
ADT editor shows only the original object language.
Each language variant is a separate SMTG text object — activated independently.

### 4.7 ABAP Cloud — Multi-Row Injection

`render_email_message` renders the template directly into `CL_BCS_MAIL_MESSAGE`. For multi-row content, use `IF_SMTG_EMAIL_TEMPL_RENDERER=>render` to get raw strings, inject rows, then set the modified body on the message.

> **Syntax confidence: partial** — `render` method signature and `CL_BCS_MAIL_MESSAGE` HTML body setter verified from SAP Help structure but confirm exact parameter names in ADT before use.

```abap
DATA lt_key      TYPE if_smtg_email_template=>ty_gt_data_key.
DATA lo_renderer TYPE REF TO if_smtg_email_templ_renderer.

" Build dynamic rows before rendering
DATA lv_rows TYPE string.
LOOP AT lt_items INTO DATA(ls_item).
  lv_rows = |{ lv_rows }<tr><td>{ ls_item-matnr }</td><td>{ ls_item-menge }</td><td>{ ls_item-meins }</td></tr>|.
ENDLOOP.

TRY.
  DATA(lo_message) = cl_bcs_mail_message=>create_instance( ).
  lo_message->set_sender( 'noreply@yourcompany.com' ).
  lo_message->add_recipient( lv_recipient_email ).

  lo_renderer = cl_smtg_email_templ_renderer=>create_instance(
    iv_template_id = 'Z_MY_TEMPLATE' ).
  APPEND VALUE #( name = 'PURCHASEORDER' value = lv_ebeln ) TO lt_key.

  " render() returns raw strings instead of writing to a message object
  lo_renderer->render(
    EXPORTING iv_language       = sy-langu
              it_data_key       = lt_key
    IMPORTING ev_subject        = DATA(lv_subject)
              ev_body_html      = DATA(lv_body_html)
              ev_body_plaintext = DATA(lv_body_plain) ).

  " Inject rows at placeholder
  REPLACE '<!--///ItemRows-->' WITH lv_rows INTO lv_body_html.

  " Set modified content on the message
  " Verify exact method name in ADT: add_text_part, set_html_body, or equivalent
  lo_message->add_text_part(
    iv_content      = lv_body_html
    iv_content_type = 'text/html' ).
  lo_message->set_subject( lv_subject ).

  lo_message->send( ).

CATCH cx_bcs_mail cx_smtg_email_common INTO DATA(lx).
  " handle
ENDTRY.
```

**Verification required:**
- `IF_SMTG_EMAIL_TEMPL_RENDERER=>render` — confirm method exists and parameter names `ev_body_html`, `ev_subject`
- `CL_BCS_MAIL_MESSAGE=>add_text_part` / `set_html_body` — confirm the correct method name and signature for setting HTML body after manual render

### 4.8 SMTP Setup — ABAP Cloud (System Email Outbound)

In ABAP Cloud, `CL_BCS_MAIL_MESSAGE->send()` dispatches via a communication arrangement. Without this, the `send()` call throws `CX_BCS_MAIL`.

| Step | Location |
|---|---|
| Create Communication System | Fiori: **Communication Systems** app → New → set outbound SMTP host and port |
| Create Communication Arrangement | Fiori: **Communication Arrangements** app → scenario `SAP_COM_0548` (System Email Outbound) |
| Set sender address | In the arrangement, set the default sender email address |
| Test | Trigger a send; check **Application Logs** (`SLG1` / Application Logs Fiori app) for errors |

**Required communication scenario:** `SAP_COM_0548` — "System Email Outbound". This must be active for any `CL_BCS_MAIL_MESSAGE->send()` call to succeed.

---

## 5. HTML Best Practices

- Develop and test HTML in a browser or VS Code first, then paste into the template editor
- Use **inline CSS** — most email clients (Outlook, Gmail) strip `<style>` blocks
- `{{field_name}}` field names must match CDS view element names (case-insensitive at runtime; use exact case for readability)
- Table injection placeholder: use a unique HTML comment `<!--///MyPlaceholder-->` — the `///` prefix avoids collision
- **Tidy HTML** button (ADT editor only) auto-formats HTML — use before saving to avoid whitespace issues
- Test with both HTML and plain-text variants — some recipients or clients show plain text only
- Keep `<table>` widths in percentage, not fixed pixels — Outlook renders fixed-width tables inconsistently

---

## 6. Anti-Patterns

| Anti-pattern | Correct approach |
|---|---|
| `CL_SMTG_EMAIL_API` in ABAP Cloud | Use `CL_BCS_MAIL_MESSAGE` + `CL_SMTG_EMAIL_TEMPL_RENDERER` |
| CDS view without annotation in ABAP Cloud | Add `@ObjectModel.supportedCapabilities: [#OUTPUT_EMAIL_DATA_PROVIDER]` |
| `VALUE ty_gt_data_key(...)` without class qualifier | Use `VALUE cl_smtg_email_api=>ty_gt_data_key(...)` (on-prem) or `if_smtg_email_template=>ty_gt_data_key` (cloud) |
| `render_bcs` when HTML table injection needed | Use `render( ... IMPORTING ev_body_html = ... )` to get raw HTML string |
| Template in inactive state | Activate in SE80 / ADT before any render call |
| No SCOT SMTP node on-prem | Configure SMTP node in SCOT; schedule RSCONN01 send job |
| No `SAP_COM_0548` arrangement in cloud | Create Communication Arrangement for System Email Outbound |
| Hardcoding email content in ABAP | Use templates — maintainable by basis/functional team without code change |
| `COMMIT WORK` missing after `send()` on-prem | BCS queues email in a DB table — `COMMIT WORK AND WAIT` required to persist |

---

## 7. Troubleshooting

### 7.1 `CX_SMTG_EMAIL_COMMON` on `get_instance` / `create_instance`

**Symptom:** Exception immediately when getting the API or renderer instance.

**Causes and fixes:**

| Cause | Check | Fix |
|---|---|---|
| Template ID wrong or misspelled | SE80 / ADT — confirm exact ID (case-sensitive) | Correct ID in code |
| Template not activated | SE80 / ADT — check status shows Active | Activate template |
| Template deprecated or obsolete | ADT status shows Deprecated / Obsolete | Create new version or activate predecessor |
| Template ID > 30 chars | — | Shorten template ID |

### 7.2 `CX_SMTG_EMAIL_COMMON` on `render` / `render_email_message`

**Symptom:** Exception during rendering (after successful instance creation).

| Cause | Check | Fix |
|---|---|---|
| CDS view not annotated (cloud) | ADT — check CDS view annotations | Add `@ObjectModel.supportedCapabilities: [#OUTPUT_EMAIL_DATA_PROVIDER]` |
| CDS view not released / different package (cloud) | SE80 / ADT — check C1 release | Release CDS view or move to same package |
| CDS view returns zero rows for the given key | Test CDS view in ADT with same key values | Verify key values and CDS WHERE logic |
| Missing key field in `it_data_key` | Compare key fields in CDS with names in `it_data_key` | Add all key fields |
| Language not available for template | Template texts exist only for some languages | Add template text for `sy-langu` or fall back to default language |

### 7.3 Email Queued but Never Sent (On-Prem)

**Symptom:** `send()` returns no error; `SOST` shows status `Ready` or `Error`; no email received.

| Cause | Check | Fix |
|---|---|---|
| No `COMMIT WORK` | Check if LUW includes COMMIT | Add `COMMIT WORK AND WAIT` after `send()` |
| SMTP node not configured | `SCOT` — check SMTP node exists and is active | Create SMTP node, set host/port, activate |
| Send job not scheduled | `SCOT` → Utilities → Job Overview | Schedule `RSCONN01` or trigger manually |
| SMTP relay rejects connection | `SOST` → error message text | Fix SMTP host/port/auth in SCOT node |

### 7.4 `CX_BCS_MAIL` on `send()` in ABAP Cloud

**Symptom:** Exception on `lo_message->send()`.

| Cause | Check | Fix |
|---|---|---|
| `SAP_COM_0548` arrangement missing | Communication Arrangements Fiori app | Create arrangement for System Email Outbound |
| Sender address not configured | Check arrangement default sender | Set valid sender address in arrangement |
| Invalid recipient address format | Validate `lv_recipient_email` value | Ensure RFC 5321-compliant email address |

### 7.5 `{{field_name}}` Not Replaced in Email Body

**Symptom:** Email arrives with literal `{{MATNR}}` or similar in body.

| Cause | Check | Fix |
|---|---|---|
| Field name mismatch | Compare `{{name}}` in template vs CDS element name | Align names exactly |
| CDS field not in SELECT list | Check CDS view definition | Add missing field to view |
| Template texts not saved after editing | Check template activation state | Save and activate template |

---

## 8. SAP Help Evidence Links

- https://help.sap.com/docs/abap-cloud/abap-development-tools-user-guide/creating-e-mail-templates
- https://help.sap.com/docs/abap-cloud/abap-development-tools-user-guide/working-with-e-mail-templates
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/659df8de83524516bbbd5a2a326e1028.html
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/b11428e38ad043b5bb407e62a5d78ed4.html
- https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/8d1f989deca1455dabc3d81b433fbdaf.html
- https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-members/e-mail-templates-in-s-4-hana/ba-p/13397719
- https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-members/e-mail-templates-in-s-4-hana-display-table-in-email-template/ba-p/13546304
