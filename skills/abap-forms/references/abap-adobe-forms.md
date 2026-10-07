---
name: abap-adobe-forms
description: 'Design and deliver Adobe Forms across S/4HANA Public Cloud, Private Cloud, on-premise, and ABAP Cloud. Use for ADS, Forms service by Adobe, Forms Objects, SFP, XDP/XSD, Output Management, RAP/OData PDF generation, templates, stored texts, logos, attachments, and rendering failures.'
---

# Adobe Forms

Use this skill as the forms architecture router. Preserve governance details in [the complete entry-point reference](./_legacy/abap-adobe-forms/references/forms-entrypoint-reference.md) and load only the domain reference needed.

## Routing

| Concern | Reference |
|---|---|
| Landscape, runtime, template lifecycle | [Landscape and architecture](./_legacy/abap-adobe-forms/references/landscape-and-architecture.md) |
| RAP/OData data provider and PDF rendering | [RAP, OData, and rendering](./_legacy/abap-adobe-forms/references/rap-odata-and-rendering.md) |
| Dynamic text, logos, assets | [Dynamic content and assets](./_legacy/abap-adobe-forms/references/dynamic-content-and-assets.md) |

## Workflow

1. Fix landscape, release, rendering runtime, output channel, and template technology.
2. Verify form-data, XSD/XDP, API, and transaction contracts.
3. Select the matching reference and implementation path.
4. Validate authorization, sensitive content, performance, rendering, transport, and rollback.

## Gates

Do not mix Public Cloud Forms Objects, Private/on-premise SFP, and BTP Forms service paths. Verify released APIs and template/schema compatibility for the exact target before production guidance.

