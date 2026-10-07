---
name: abap-odata-service-development
description: 'Design, implement, consume, and troubleshoot OData V2 and V4 for ABAP Cloud and on-premise. Use for RAP service definitions/bindings, SEGW, query options, expand, filter, batch, deep operations, actions/functions, ETags, pagination, metadata, errors, and OData clients.'
metadata:
  version: 2.0.0
  tags: abap odata v2 v4 rap segw service-binding etag batch
---

# OData Service Development

Load only the relevant section of [the complete OData patterns](./_legacy/abap-odata-service-development/references/odata-complete-patterns.md). Prior entry-point guidance is preserved in [the entry-point reference](./_legacy/abap-odata-service-development/references/odata-entrypoint-reference.md).

## Workflow

1. Establish landscape, OData version, provider model, consumer, and compatibility requirements.
2. Inspect service metadata, entity/action contracts, keys, types, navigation, and concurrency semantics.
3. Select RAP V4/V2 compatibility, SEGW V2, or consumption pattern.
4. Validate query behavior, paging, batch boundaries, ETags, authorization, and error payloads.

## Routing

Use the reference for V2/V4 selection, query options, expand, analytics, paging, service consumption, RAP compatibility, and common errors.

## Gates

- Prefer OData V4 for new RAP APIs unless a verified consumer constraint requires V2.
- Treat generated `$metadata` as the service contract.
- Require deterministic paging, ETag/concurrency handling, bounded expansions, and contract tests.
- Verify syntax and feature availability for the exact release.

