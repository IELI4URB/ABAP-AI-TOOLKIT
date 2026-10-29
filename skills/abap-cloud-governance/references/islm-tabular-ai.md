---
name: islm-tabular-ai
description: 'ISLM tabular and predictive AI in ABAP. Use for SAP-RPT model family (classification, regression, anomaly detection, time-series), ISLM classic scenario lifecycle (train/deploy/activate/infer), how tabular AI differs from GenAI in ISLM, landscape support, ABAP consumption via IF_ISLM_INTELLIGENT_SCENARIO, and current vs. announced model availability.'
metadata:
  version: 1.0.0
  tags: abap islm tabular-ai rpt predictive sap-ai-core structured-data intelligent-scenario s4hana
---

# ISLM — Tabular and Predictive AI in ABAP

> **Scope of this guide:** SAP-RPT tabular foundation models consumed through ISLM from ABAP.
> For generative AI / LLM consumption via the ABAP AI SDK, see the `abap-cloud-governance`
> skill's `generative-ai-abap-cloud.md`.

Source: [SAP AI Core — SAP-RPT](https://www.sap.com/products/artificial-intelligence/sap-rpt.html) ·
[Tabular AI on SAP](https://www.sap.com/products/artificial-intelligence/tabular-ai.html) ·
[ISLM for S/4HANA](https://pages.community.sap.com/topics/intelligent-scenario-lifecycle-management-s4hana)

---

## Tabular AI vs. Generative AI — Key Difference

| Dimension | Generative AI (LLM) | Tabular AI (RPT) |
|-----------|--------------------|--------------------|
| Input | Unstructured text (prompts) | Structured rows and columns (ABAP internal tables, business data) |
| Output | Generated text | Prediction: class label, numeric value, anomaly score, embedding vector |
| ISLM scenario kind | Gen AI Intelligent Scenario | Classic / Side-by-Side Intelligent Scenario |
| ABAP API layer | ABAP AI SDK (`IF_AIC_COMPLETION_API` via `CL_AIC_ISLM_COMPL_API_FACTORY`) | ISLM inference APIs (`IF_ISLM_INTELLIGENT_SCENARIO`) |
| Model training | Not required (in-context learning) | Not required for RPT (in-context learning); required for custom classical ML |
| SAP_COM_0A69 | Required | Not required — AI Core connectivity is managed differently for tabular scenarios |

---

## SAP-RPT Model Family

SAP-RPT (Relational Pretrained Transformer) is SAP's **table-native foundation model** trained on real SAP business tables and use cases. It uses **in-context learning** — you provide example rows at inference time, no task-specific training required.

Source: [SAP-RPT Model Card 1.6](https://d.dam.sap.com/x/DAQr1bG/Model_Card_SAP-RPT-1.6.pdf) · [SAP-RPT-1.5 Model Card](https://www.sap.com/documents/2026/07/b8cb2cd1-5d7f-0010-bca6-c68f7e60039b.html)

### Currently Released and Documented

| Model | Tasks | Available Via | SAP Help / Docs |
|-------|-------|---------------|-----------------|
| **SAP-RPT-1.6** | Classification, regression | SAP AI Core model library, SAP HANA Cloud (SQL) | [Model Card PDF](https://d.dam.sap.com/x/DAQr1bG/Model_Card_SAP-RPT-1.6.pdf) |
| **SAP-RPT-1.5** | Classification, regression | SAP AI Core model library, SAP HANA Cloud (SQL) | [Model Card](https://www.sap.com/documents/2026/07/b8cb2cd1-5d7f-0010-bca6-c68f7e60039b.html) |

### Announced at SAP TechEd 2026 — No ABAP Docs Yet

> These models were announced October 27, 2026. SAP Help pages and ABAP-specific consumption docs are not yet published. Do not add code patterns for these until official SAP Help documentation is available. Track: [TechEd Innovation News Guide 2026](https://www.sap.com/topics/events/teched/innovation-news-guide-2026)

| Model | Additional Tasks vs. RPT-1.x | Primary Target |
|-------|------------------------------|----------------|
| **SAP-RPT-2.0** | Anomaly and outlier detection; structured-data embeddings | Broader tabular analytics and decision support |
| **SAP-RPT-TS** | Time-series forecasting (univariate + multivariate) | Business metrics over time — demand forecasting, IBP |

Source: [SAP TechEd 2026 announcement](https://news.sap.com/2026/10/sap-hpe-orbit-to-enterprise-next-tabular-ai-frontier/)

---

## System Requirements by Landscape

| Landscape | ISLM Tabular Scenarios | SAP AI Core Required | Min Release |
|-----------|----------------------|---------------------|-------------|
| S/4HANA Cloud Public Edition | Supported | Yes | 2023 FPS01+ |
| S/4HANA Cloud Private Edition | Supported | Yes | Check with SAP for exact FPS |
| S/4HANA On-Premise | Supported (side-by-side) | Yes | Check ABAP Platform version |
| BTP ABAP Environment | Supported | Yes | Any current |
| ECC / classical ABAP | Not supported | — | — |

Source: [ISLM overview — ABAP Platform](https://help.sap.com/docs/ABAP_PLATFORM_NEW/7989a582039547ae91d8f483e487058d/436151b128614f0e84024015136043d3.html)

**BTP prerequisites (same as Gen AI path):**
- SAP AI Core service instance (`extended` plan recommended for productive use)
- SAP AI Core service key (`clientid`, `clientsecret`, `url`, `AI_API_URL`)
- SAP-RPT model deployed in AI Launchpad → Running status → Deployment ID noted

---

## ISLM Tabular Scenario Lifecycle

ISLM manages the full lifecycle of an intelligent scenario. For tabular AI with SAP-RPT, the lifecycle is:

```
1. CREATE   Developer creates an intelligent scenario
            (ABAP repository object, type: Side-by-Side)
            in ADT or the Intelligent Scenarios Fiori app

2. PUBLISH  Scenario is published and made available
            in Intelligent Scenario Management app

3. DEPLOY   Admin deploys the scenario — this links it
            to the SAP-RPT model deployment on AI Core

4. ACTIVATE Admin activates the scenario for a
            specific business domain / client

5. INFER    ABAP business code calls the activated
            scenario to fetch a prediction at runtime
```

Source: [ISLM — Create an Intelligent Scenario](https://help.sap.com/docs/ABAP_PLATFORM_NEW/7989a582039547ae91d8f483e487058d/61775589fa6c43008c555cbaf028ca50.html) · [Intelligent Scenario Management app](https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/4e67f075b34c4044802d0418efdef3b3.html)

### Fiori Apps Involved

| App | Role | Transaction Equivalent |
|-----|------|------------------------|
| **Intelligent Scenarios** | Create, review, publish custom scenarios | Development |
| **Intelligent Scenario Management** | Deploy, activate, deactivate, monitor | Operations |

---

## ABAP Consumption — Released API Entry Point

The released ABAP interface for intelligent scenario consumption is **`IF_ISLM_INTELLIGENT_SCENARIO`**.

Source: [SAP Help — Create an Intelligent Scenario (example)](https://help.sap.com/docs/ABAP_PLATFORM_NEW/7989a582039547ae91d8f483e487058d/5e5b62672c7b4f02966213585614f657.html) · [ABAP AI SDK — Developer prerequisites](https://help.sap.com/docs/ABAP_AI/c7f5ef43ab274d078baf22f995fd2161/e7a518da0ecf4f7faac331edf682dd0d.html)

> **Do not guess class names.** The exact factory and client classes for tabular RPT consumption are documented in the ISLM API Reference. Always verify against:
> - [ISLM ABAP Platform Help](https://help.sap.com/docs/ABAP_PLATFORM_NEW/7989a582039547ae91d8f483e487058d/436151b128614f0e84024015136043d3.html)
> - [ABAP AI SDK API Reference](https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/api-reference-guide-for-abap-ai-sdk)
> - ABAP cheat sheets: [Generative AI chapter](https://github.com/SAP-samples/abap-cheat-sheets/blob/main/30_Generative_AI.md)

### High-Level Consumption Pattern (confirmed conceptually)

```abap
" Conceptual pattern — verify exact class/interface names
" from SAP Help API Reference before implementing

" 1. Get activated intelligent scenario
DATA(lo_scenario) = " use released factory class
                    " from IF_ISLM_INTELLIGENT_SCENARIO
                    " — confirm from ISLM API reference.

" 2. Provide context rows (in-context learning examples)
"    and query rows (the records to predict)
"    as structured input — exact input format
"    depends on the intelligent scenario configuration.

" 3. Trigger inference
" 4. Consume prediction result
```

For a fully worked example, follow the official SAP tutorial:
[Implement a Simple Custom ABAP AI Scenario](https://developers.sap.com/tutorials/abap-islm-simple-genai-scenario/)
[Implement a Custom ABAP AI Scenario Consuming SAP AI Core Orchestration Service](https://developers.sap.com/tutorials/abap-islm-orchestration-service-consumption/)

---

## Two Consumption Paths for SAP-RPT

SAP-RPT can be consumed from two paths. Choose based on where your data lives:

| Path | When to Use | Entry Point |
|------|------------|-------------|
| **SAP AI Core REST API** | Data outside HANA Cloud; calling from an app or service; non-ABAP consumers | REST `POST /v2/inference/deployments/{id}/...` with OAuth2 bearer token |
| **SAP HANA Cloud (SQL)** | Data already in HANA Cloud; want lowest latency; no BTP call overhead | SQL stored procedure call from HANA — no ABAP AI SDK needed |
| **ISLM + ABAP AI SDK** | Data in S/4HANA; embedding prediction in a business process; governed lifecycle | ISLM intelligent scenario + `IF_ISLM_INTELLIGENT_SCENARIO` |

Source: [Classic ML on SAP BTP with HANA Cloud](https://architecture.learning.sap.com/docs/golden-path/ai-golden-path/build-and-deliver/classic-ml) · [Predictive & Tabular AI with SAP-RPT-1 on SAP AI Core](https://architecture.learning.sap.com/docs/golden-path/ai-golden-path/build-and-deliver/predictive-tabular-ai)

---

## Governance Rules (same as Gen AI)

- **Released API discipline:** use only released ISLM and ABAP AI SDK interfaces; verify release state before coding — see `clean-core-api-extension-governance.md`.
- **No training data with PII or secrets:** input rows sent to the model may transit SAP AI Core. Apply the same data-privacy controls as for LLM prompts.
- **Determinism:** RPT outputs a probability-weighted prediction — validate before acting on it in a critical business process. Do not treat a prediction as a verified fact.
- **Availability is edition/release-dependent:** confirm the exact ISLM scenario kind and SAP-RPT model version supported on the target landscape before development begins.
- **RPT-2 and RPT-TS:** announced but not yet fully documented for ABAP. Do not add custom ABAP code against undocumented APIs. Watch official SAP Help for updates.

---

## SAP Help References

### SAP-RPT Model Family
| Resource | URL |
|----------|-----|
| SAP-RPT product page | https://www.sap.com/products/artificial-intelligence/sap-rpt.html |
| SAP-RPT Playground + API docs | https://rpt.cloud.sap/docs |
| SAP-RPT-1.5 Model Card | https://www.sap.com/documents/2026/07/b8cb2cd1-5d7f-0010-bca6-c68f7e60039b.html |
| SAP-RPT-1.6 Model Card PDF | https://d.dam.sap.com/x/DAQr1bG/Model_Card_SAP-RPT-1.6.pdf |
| Tabular AI on SAP (product page) | https://www.sap.com/products/artificial-intelligence/tabular-ai.html |
| SAP-RPT concepts index — Developer Center | https://developers.sap.com/concepts/sap-rpt-foundation-models/ |
| Foundation Model for Tabular Data — Developer Center | https://developers.sap.com/concepts/foundation-model-tabular/ |
| RPT on SAP AI Core (Python SDK) | https://help.sap.com/doc/generative-ai-hub-sdk/CLOUD/en-US/_reference/gen_ai_hub.html |
| Predictive & Tabular AI with SAP-RPT on AI Core (Architecture Center) | https://architecture.learning.sap.com/docs/golden-path/ai-golden-path/build-and-deliver/predictive-tabular-ai |
| Classic ML + Tabular AI on BTP + HANA Cloud (Architecture Center) | https://architecture.learning.sap.com/docs/golden-path/ai-golden-path/build-and-deliver/classic-ml |

### ISLM — Lifecycle and Consumption
| Resource | URL |
|----------|-----|
| ISLM overview — ABAP Platform | https://help.sap.com/docs/ABAP_PLATFORM_NEW/7989a582039547ae91d8f483e487058d/436151b128614f0e84024015136043d3.html |
| ISLM overview — S/4HANA Cloud | https://help.sap.com/docs/SAP_S4HANA_CLOUD/a630d57fc5004c6383e7a81efee7a8bb/3fa32d7a1e21465f8d9696f6b8cb6ee9.html |
| Create an intelligent scenario | https://help.sap.com/docs/ABAP_PLATFORM_NEW/7989a582039547ae91d8f483e487058d/61775589fa6c43008c555cbaf028ca50.html |
| IF_ISLM_INTELLIGENT_SCENARIO example | https://help.sap.com/docs/ABAP_PLATFORM_NEW/7989a582039547ae91d8f483e487058d/5e5b62672c7b4f02966213585614f657.html |
| Intelligent Scenarios app | https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/63ae9cdcc68f4f0c8352ff9fd57c659d.html |
| Intelligent Scenario Management app | https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/4e67f075b34c4044802d0418efdef3b3.html |
| Create using SAP AI Core (ISLM) | https://help.sap.com/docs/ABAP_PLATFORM_NEW/7989a582039547ae91d8f483e487058d/f6f3d33945d04e29b564a1fa352fd6e5.html |
| ISLM FAQ — SAP Community | https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-sap/intelligent-scenario-lifecycle-management-frequently-asked-questions/ba-p/13521020 |
| ISLM concepts — Developer Center | https://developers.sap.com/concepts/islm-intelligent-scenario-management/ |

### ABAP AI SDK API Reference
| Resource | URL |
|----------|-----|
| ABAP AI SDK API Reference Guide | https://help.sap.com/docs/abap-ai/generative-ai-in-abap-cloud/api-reference-guide-for-abap-ai-sdk |
| Developer prerequisites (intelligent scenarios + models) | https://help.sap.com/docs/ABAP_AI/c7f5ef43ab274d078baf22f995fd2161/e7a518da0ecf4f7faac331edf682dd0d.html |
| ABAP Cheat Sheets — Generative AI | https://github.com/SAP-samples/abap-cheat-sheets/blob/main/30_Generative_AI.md |

### Tutorials
| Resource | URL |
|----------|-----|
| Configure S/4HANA for ISLM | https://developers.sap.com/tutorials/abap-islm-setup-prepare/ |
| Set up BTP + integrate AI Core with ISLM (OAuth) | https://developers.sap.com/tutorials/abap-islm-setup-oauth/ |
| Implement a simple custom ABAP AI scenario | https://developers.sap.com/tutorials/abap-islm-simple-genai-scenario/ |
| Implement a custom ABAP AI scenario — Orchestration Service | https://developers.sap.com/tutorials/abap-islm-orchestration-service-consumption/ |
| Set up S/4HANA for custom AI scenarios (tutorial group) | https://developers.sap.com/tutorials/group-set-up-your-sap-s-4hana-system-for-custom-ai-scenarios/ |

### RPT-2 and RPT-TS — Watch for Official Docs
| Resource | URL |
|----------|-----|
| SAP TechEd 2026 Innovation News Guide | https://www.sap.com/topics/events/teched/innovation-news-guide-2026 |
| SAP-RPT-2 announcement | https://news.sap.com/2026/10/sap-hpe-orbit-to-enterprise-next-tabular-ai-frontier/ |
| SAP-RPT-TS community blog | https://community.sap.com/t5/technology-blog-posts-by-sap/sap-rpt-ts-sap-s-new-time-series-foundation-model/ba-p/14507166 |
| Zero-shot forecasting with SAP-RPT-TS | https://community.sap.com/t5/artificial-intelligence-blogs-posts/zero-shot-time-series-forecasting-with-sap-rpt-ts-in-sap-hana-cloud-and-sap/ba-p/14507879 |
