---
name: adt-api-discovery
description: 'Investigate SAP ADT REST endpoints, HTTP methods, request and response XML, content types, handlers, Simple Transformations, and schemas by tracing discovery documents through RES_APP registration and implementation classes.'
---

# ADT API Discovery

SAP Help baseline: https://help.sap.com/docs/ABAP_Cloud

Use [the complete ADT API discovery reference](./_legacy/adt-api-discovery/references/api-discovery-reference.md) as a staged investigation. Load only the current stage.

## Workflow

1. Locate the endpoint and media types in ADT discovery output.
2. Find the owning `RES_APP` class and `register_resources` implementation.
3. Resolve the handler class and supported HTTP methods.
4. Trace request and response serialization to Simple Transformations or schemas.
5. Read transformations to derive exact XML elements, attributes, namespaces, and optionality.
6. Validate conclusions against a captured request/response when available.

## Gates

- Do not infer payload shape from endpoint names or handler signatures alone.
- Distinguish request from response transformations and media types.
- Preserve namespaces, content types, and release-specific behavior.
- Clearly separate verified endpoint facts from hypotheses requiring a trace.

## Output

Return endpoint, method, media types, registration class, handler, transformations, request/response shape, evidence, and unresolved questions.

