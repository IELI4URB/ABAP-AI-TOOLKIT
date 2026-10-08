# Dynamic Texts, Logos, and Reusable Form Assets

Last source review: 2026-09-24

Dynamic content must be classified before storage or binding is chosen. Do not solve every text/logo requirement with XDP scripting.

#### Content Classification

| Content | Examples | Preferred owner |
|---|---|---|
| Static translated label | "Invoice", column headings | XDP translation/template language |
| Organization branding | company logo, sender address, bank/footer block | Master form + managed logo/text configuration where supported |
| Business-document data | customer, items, totals, tax, dates | Form data provider/service payload |
| Business-dynamic paragraph | payment clause, legal note, delivery instruction | Authorized text/config repository resolved into payload |
| User-entered note | order note, free text | Business object/persistence with validation and authorization |
| Runtime image | product image, signature, QR/barcode source | Payload or verified URL/reference pattern |
| Template fragment | reusable page/header/footer layout | Master form fragment or controlled template fragment |

#### Public Cloud Managed Assets

For SAP S/4HANA Cloud Public Edition Output Management:

- Use Maintain Form Templates to copy/download/upload/version custom XDP templates.
- Use Manage Logos for organization logos used by customized master forms.
- Use Manage Texts for reusable sender/footer text blocks supported by master-form configuration.
- Use Define Rules for Determination of Master Form Template to select the master template and associated assets by supported organizational conditions.
- Master forms contain placeholders for logos, sender addresses, and footer blocks that are filled dynamically by configuration.
- Application/content forms supply business content; standalone forms combine content and layout.

Do not hardcode company logos or footer addresses into every application form when master-form determination is available. Central assets reduce duplication and make organizational selection explicit.

The exact apps, condition fields, transport behavior, file constraints, and roles are release-sensitive. Verify them in the target tenant.

#### Stored Business Text Strategy

Use this decision order:

1. Is the text a translated static template label?
   - Maintain it as template translation, not business data.
2. Is the text a managed master-form sender/footer block?
   - Use the landscape's Manage Texts/master-form mechanism.
3. Is the text part of the business document and versioned with it?
   - Store it on/with the business object and include it in the form payload.
4. Is it reusable business configuration selected by rules?
   - Use a governed configuration/text repository with keys such as tenant, company, form type, text type, language, validity dates, and status.
5. Is it a classic SAPscript standard text in on-premise/Private Cloud?
   - Use the application's supported text API in Standard ABAP. In ABAP Cloud, verify a released API or isolate classic access behind a governed wrapper where permitted.

##### Recommended Dynamic Text Key

```text
Tenant/client
+ application/form type
+ text type/qualifier
+ organization (company/sales org/plant as needed)
+ language
+ valid-from / valid-to
+ active/version status
```

Resolution should be deterministic:

1. Exact organization + requested language + validity.
2. Documented fallback language or generic organization fallback.
3. Explicit error or omission according to business rules.

Do not silently choose an arbitrary text when more than one active version matches.

##### Text Contract

Define:

- Plain text versus rich/formatted text.
- Maximum length and line count.
- Paragraph/line-break representation.
- Allowed characters/markup.
- Translation and fallback behavior.
- Effective dating and approval.
- Snapshot versus current-at-render semantics.

For legal or financial wording, persist the resolved text/version with the document or generated output so later reprints are reproducible.

#### Logo and Image Strategy

##### Managed Master-Form Logo

Preferred for organization branding in SAP S/4HANA Output Management:

- Upload/manage logo using the supported app.
- Keep an XDP placeholder in the master form.
- Select through master-form determination/configuration.
- Test each organization/country/language/layout variant.

##### Embedded Runtime Image

For developer-owned/classic forms, an image can be part of the data contract where the target form technology supports it.

Official classic Adobe form documentation describes:

- Graphic Content with binary `XSTRING` or Base64 `STRING` data.
- An associated MIME type supported by the target ADS/Designer release. The cited classic documentation includes examples such as `image/bmp` and `image/jpeg`; verify PNG separately.
- Binding the context graphic to an Image Field in Adobe LiveCycle Designer.

For a RAP/service-definition XML payload, verify how the binary field is represented in generated XSD/XML before choosing `XSTRING`, Base64 string, or another type. Treat classic SFP examples as conceptual until activated in the target Forms Object/data provider.

Recommended payload fields:

```text
LogoContent        binary/Base64 according to verified schema
LogoMimeType       image/png or image/jpeg
LogoAlternativeText
LogoWidth/Height   only if required by layout contract
```

Controls:

- Allow only approved MIME types.
- Enforce byte-size and dimension limits.
- Reject malformed image content.
- Normalize/crop outside XDP when consistent branding is required.
- Avoid per-item duplicate image payloads; place shared logo at header/root level.
- Do not log image content.

##### Graphic Reference/URL

Use only when the renderer can securely reach the resource and reproducibility is not compromised.

Risks:

- ADS network/DNS/proxy access.
- Authentication and expiring URLs.
- SSRF/untrusted URL injection.
- Content changing after document creation.
- Outage/latency during rendering.
- Cross-region data access.

For legal output, embedded/versioned content is usually safer than a mutable external URL.

#### Master Forms and Fragments

SAP Forms service strategy supports master forms for reusable static appearance such as:

- Logo.
- Sender address.
- Bank details.
- Footer blocks.
- Page size/orientation and overall page design.

A master template can contain fragments/layout variants. Application/content forms reference a master-form layout variant. Standalone forms do not use a separate master page.

Use fragments/master forms when:

- Many forms share branding/layout.
- Organization-specific branding is determined centrally.
- Footer/sender changes must affect multiple forms consistently.

Avoid excessive fragment scripting or hidden coupling. Version and regression-test every consuming form when a shared fragment changes.

#### Language and Translation

Separate:

- Template labels/translations.
- Business master-data descriptions.
- Managed sender/footer texts.
- User-entered document language text.
- Locale-sensitive date/number/currency formatting.

Rules:

- Determine output language explicitly from business/output rules.
- Use the template translation matching the intended output language.
- Resolve dynamic stored text in the same language, with documented fallback.
- Pass language/locale to the renderer through the supported API.
- Test translated XDP versions and business texts together.
- Verify fonts contain all required glyphs and are available/embedded as required.
- Test RTL mirroring only where supported and configured.

#### XDP Scripting Guidance

Prefer declarative bindings, subform presence rules, and backend-prepared values over complex JavaScript/FormCalc.

Use scripting only when:

- The requirement cannot be expressed through binding/layout/configuration.
- The target ADS/runtime supports it.
- It has deterministic behavior and tests.
- It does not perform security-sensitive data retrieval.

Never place secrets, endpoints, authorization logic, or business-rule source of truth in XDP scripts.

The Public Cloud Optimize data service option statically detects fields used directly in data bindings. SAP documents that fields accessed only through scripting are not detected and can be omitted. Test previews before enabling optimization.

#### QR Codes, Barcodes, and Signatures

- Treat barcode/QR source strings as form data; validate format and size.
- Prefer renderer-native barcode objects only where supported by the chosen runtime/template version.
- A scanned signature image is sensitive personal data; secure storage, consent, access, and retention are required.
- Cryptographic/digital PDF signatures are not equivalent to displaying a signature image. Verify a supported signing service/workflow; do not claim ADS rendering alone provides legal signing.

#### Caching

Safe candidates:

- Immutable XDP template version.
- Immutable logo version.
- Approved static text version.

Cache key must include applicable boundaries:

```text
tenant + environment + organization + form type + language + validity/version
```

Do not cache authorization-filtered business data globally. Invalidate caches on template/logo/text publication or version change.

#### Determination and Fallback Rules

A complete design states:

- How application/content template is selected.
- How master template/layout variant is selected.
- How logo and sender/footer texts are selected.
- How language is selected.
- What happens when no exact match exists.
- Whether preview and final output use identical determination.
- Whether reprint uses current or historical assets.

Missing configuration should produce an explicit diagnosable error, not a silently blank legal footer/logo unless business rules allow it.

#### Asset Security and Governance

- Separate creator, approver, publisher, and runtime roles where required.
- Scan/review uploaded templates and images.
- Restrict template-store write/delete APIs.
- Maintain version history and approval evidence.
- Validate that logos/texts are tenant and organization scoped.
- Prevent users from selecting unauthorized organization branding.
- Apply accessibility requirements: alternative text, contrast, reading order, tagged PDF where required and supported.
- Document copyright/licensing for fonts and images.

#### Test Matrix

##### Texts

- Exact and fallback language.
- Missing text and overlapping validity.
- Empty, maximum-length, multiline, and special-character text.
- HTML/rich text injection where markup is allowed.
- Legal text snapshot/reprint behavior.

##### Logos/Images

- PNG/JPEG and unsupported MIME type.
- Missing/empty/corrupt/oversized image.
- Transparent and high-resolution images.
- Different company/country determinations.
- External URL unavailable or unauthorized.
- PDF size and rendering latency.

##### Master Forms

- Every application form against each required master variant.
- First/middle/last page fragments.
- Page breaks, footer collision, and repeating header.
- Translation and RTL variants.
- Version rollback.

#### Sources

- SAP S/4HANA Cloud Form Templates:
  https://help.sap.com/docs/SAP_S4HANA_CLOUD/a630d57fc5004c6383e7a81efee7a8bb/aaad0f198a634014b0776e001e4980bc.html
- Customized master forms, Manage Logos/Manage Texts, determination:
  https://help.sap.com/docs/SAP_S4HANA_CLOUD/a630d57fc5004c6383e7a81efee7a8bb/f776f77564e04331b5e891d9569b6d12.html
- Maintain Form Templates and translations/fonts/optimization:
  https://help.sap.com/docs/SAP_S4HANA_CLOUD/a630d57fc5004c6383e7a81efee7a8bb/da488f76078447b0b42792226cfcf9b1.html
- SAP form strategy/master forms:
  https://learning.sap.com/courses/getting-started-with-sap-forms-service-by-adobe/explaining-sap-s-form-strategy_fe64fe10-e7ee-48a0-a0c2-3d6904904c58
- Classic graphic-content/reference concepts:
  https://help.sap.com/doc/saphelp_nw74/7.4.16/en-US/4a/92512e66193898e10000000a42189c/content.htm
- Forms service template-store schema:
  https://help.sap.com/docs/forms-service-by-adobe/sap-forms-service-cf/schema

#### Evidence Boundary

Managed logo/text/master-form guidance is officially documented for SAP S/4HANA Output Management. Binary/Base64 image binding is documented for classic Adobe form context; verify its exact representation for modern Forms Objects and generated service-definition schemas before implementation.
