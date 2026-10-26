---
name: abap-forms
description: 'Design and deliver SAP output across S/4HANA and ABAP Cloud. Use for Adobe Forms (ADS, Forms service by Adobe, Forms Objects, SFP, XDP/XSD, PDF generation), SMTG email templates (CL_SMTG_EMAIL_API, CL_BCS_MAIL_MESSAGE, CL_SMTG_EMAIL_TEMPL_RENDERER, render_bcs, HTML table injection, CDS OUTPUT_EMAIL_DATA_PROVIDER, SAP_COM_0548, SCOT, SOST, SAPconnect), Output Management, RAP/OData output, CX_SMTG_EMAIL_COMMON, CX_BCS_MAIL, template lifecycle, and transport.'
metadata:
  version: 2.0.0
  tags: abap forms adobe-forms pdf email smtg output-management sfp xdp s4hana
---

# ABAP Forms and Output

This skill covers SAP output channels: PDF via Adobe Forms and email via SMTG email templates.

## Routing by Output Type

| Output type | Load guide |
|---|---|
| Adobe Forms, PDF, ADS, XDP/XSD, SFP, Output Management | [Adobe Forms](./references/abap-adobe-forms.md) |
| Email templates, SMTG, CL_BCS_MAIL_MESSAGE, CL_SMTG_EMAIL_API | [Email Templates](./references/email-templates-complete.md) |

## Workflow

1. Fix output type: PDF/forms or email.
2. Fix landscape (on-prem / private cloud / public cloud / BTP ABAP).
3. Load the matching guide and follow its workflow.

Do not mix Adobe Forms and email template paths. Do not mix Public Cloud Forms Objects, BTP Forms service, and Private/on-premise SFP paths.
