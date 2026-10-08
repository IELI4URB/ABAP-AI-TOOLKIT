---
name: abap-api-design-versioning
description: 'Design and evolve SAP ABAP Cloud RAP APIs. Use for service-binding versions, backward compatibility, breaking changes, deprecation, versioned projections/DTOs, API lifecycle, release-state annotations, and multi-projection BO constraints.'
---

# ABAP API Design and Versioning

Load the relevant pattern from the API patterns reference inlined below.

## Workflow

1. Identify consumers, service binding, entity/action contract, and compatibility window.
2. Classify the proposed change as compatible, additive with risk, or breaking.
3. Use service-binding versions and versioned projections/contracts; do not invent URL-path versioning for RAP.
4. Define deprecation, coexistence, migration, test, and retirement evidence.

## Gates

Verify release policy and target support. Preserve old contracts during the approved deprecation period, account for LUW constraints in multi-projection BOs, and require consumer contract tests before removal.


## API Design & Versioning — Backwards Compatibility & Contract Management

### Objective

Design APIs that evolve without breaking clients. Implement versioning strategies, deprecation, and contract management for long-term maintenance.

### SAP Reference & Standards

- OData and Service Design Guidance: https://help.sap.com/docs
- ABAP RAP Service Exposure: https://help.sap.com/docs/abap-cloud/abap-rap
- SAP API Lifecycle Guidance: https://help.sap.com/docs

Landscape navigation: align API exposure choices with module 17 so contract policies match Public Cloud, Private Cloud (ABAP Cloud), or BTP ABAP constraints.

---

### API Versioning Strategies

#### Strategy 1: URL Path Versioning (Explicit)

```abap
" Version in URL path
" GET /odata/v1/Travels → Version 1
" GET /odata/v2/Travels → Version 2

" Fiori Elements service binding
@EndUserText.label: 'Travel Service V1'
define service ZSD_TRAVEL_V1 {
  expose ZC_TravelTP_V1 as Travel;
  expose ZC_BookingTP_V1 as Booking;
}

@EndUserText.label: 'Travel Service V2'
define service ZSD_TRAVEL_V2 {
  expose ZC_TravelTP_V2 as Travel;
  expose ZC_BookingTP_V2 as Booking;
}

" Both versions coexist
" Old clients use v1, new clients use v2
" Deprecate v1 after 6 months notice

" Pros: Clear, explicit versioning
" Cons: Duplicate code, maintenance overhead
```

#### Strategy 2: Header-Based Versioning (Implicit)

```abap
" Version in request header
" GET /odata/Travels
" Header: API-Version: 2

CLASS zcl_travel_api_handler.
  METHODS create_travel.
    DATA(api_version) = get_request_header( 'API-VERSION' ).
    
    IF api_version = '1'.
      expose_travel_v1( ).
    ELSEIF api_version = '2'.
      expose_travel_v2( ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

" Pros: Single endpoint, less duplication
" Cons: Less discoverable, harder to document
```

#### Strategy 3: Query Parameter Versioning

```abap
" GET /odata/Travels?apiVersion=2

" Cons: Can't use in Fiori Elements (OData doesn't support)
" Avoid for public APIs
```

**SAP RAP Recommendation:** Version via **service binding NAME** (e.g. `API_TRAVEL_V1_O4`, `API_TRAVEL_V2_O4`) — NOT URL path segments. SAP RAP does not support URL path versioning; the OData service URL is auto-generated from the service binding. For non-RAP REST APIs (custom HTTP handlers), URL path versioning (`/v1/`, `/v2/`) is acceptable.

> The URL path versioning examples above (Strategy 1) are provided as a general REST pattern for reference only. Do NOT apply URL path versioning to SAP RAP OData services — use service binding name versioning instead.

---

### Backwards Compatibility Patterns

#### Pattern 1: Add Without Removing

```abap
" GOOD: Extend fields without breaking old clients
" OLD CDS view (v1)
DEFINE VIEW zc_travel_tp_v1 AS SELECT FROM zi_travel_tp {
  id,
  status,
  destination,
  amount
};

" NEW CDS view (v2) - adds optional new field
DEFINE VIEW zc_travel_tp_v2 AS SELECT FROM zi_travel_tp {
  id,
  status,
  destination,
  amount,
  estimated_cost  // NEW FIELD (optional)
};

" Old clients get response without estimated_cost (ignore unknown fields)
" New clients get response with estimated_cost
" No breaking change!
```

#### Pattern 2: Type Expansion (Compatible)

```abap
" GOOD: Expand type range without breaking
" OLD: Status can be 'OPEN', 'APPROVED'
" NEW: Status can be 'OPEN', 'APPROVED', 'CANCELLED', 'EXPIRED'

" Old clients receive 'CANCELLED': They don't know this value
" But they handle it as string, no crash
" Backwards compatible!

" BAD: Change type
" OLD: amount TYPE decimal (2 decimals)
" NEW: amount TYPE decimal (4 decimals)
" 
" Old clients parse as 2 decimals: 1234.56 becomes 12.3456 (wrong!)
" Breaking change!
```

#### Pattern 3: Deprecation Warning

```abap
" Warn clients about deprecated fields
DEFINE VIEW zc_travel_tp_v2 AS SELECT FROM zi_travel_tp {
  id,
  status,
  destination,
  amount,
  
  // Deprecated: Use 'estimated_cost' instead
  // Will be removed in v3 (2027-01-01)
  calculated_amount  // OLD FIELD
};

" Include in response header
" Warning: "calculated_amount is deprecated, use estimated_cost instead. Remove by 2027-01-01."

" Log deprecation warnings
METHODS get_travel IMPORTING travel_id TYPE travel_id.
  logger->log(
    severity = 'WARN'
    message = 'Deprecated field accessed'
    context = VALUE #(
      field = 'calculated_amount'
      deprecation_deadline = '2027-01-01'
      recommendation = 'Use estimated_cost instead'
      client_id = get_client_id( )  // Track which clients use deprecated fields
    )
  );
  
  RETURN get_travel( travel_id ).
ENDMETHOD.
```

---

### API Contract Management

#### Pattern 1: Versioned DTOs (Data Transfer Objects)

```abap
" GOOD: Separate DTO per API version
" Ensures contract doesn't change

TYPES: BEGIN OF travel_dto_v1,
  id TYPE travel_id,
  status TYPE string,
  destination TYPE string,
  amount TYPE decimal,
END OF travel_dto_v1.

TYPES: BEGIN OF travel_dto_v2,
  id TYPE travel_id,
  status TYPE string,
  destination TYPE string,
  amount TYPE decimal,
  estimated_cost TYPE decimal,
  customer_segment TYPE string,
END OF travel_dto_v2.

" Map from internal domain to DTO
METHODS to_dto_v1 RETURNING VALUE(dto) TYPE travel_dto_v1.
  dto = VALUE #(
    id = me->id
    status = me->status
    destination = me->destination
    amount = me->amount
  ).
ENDMETHOD.

METHODS to_dto_v2 RETURNING VALUE(dto) TYPE travel_dto_v2.
  dto = VALUE #(
    id = me->id
    status = me->status
    destination = me->destination
    amount = me->amount
    estimated_cost = me->estimated_cost
    customer_segment = me->customer_segment
  ).
ENDMETHOD.

" Each version has immutable contract
" Changes go to new version only
```

#### Pattern 2: Versioned Exception Handling

```abap
" GOOD: Different error responses per version
METHODS create_travel.
  TRY.
    validate_travel( travel ).
  CATCH cx_invalid_travel INTO DATA(error).
    " v1 response: Simple error message
    IF api_version = '1'.
      RETURN VALUE #(
        success = abap_false
        error = 'Validation failed'
      ).
    ENDIF.
    
    " v2 response: Detailed error info
    IF api_version = '2'.
      RETURN VALUE #(
        success = abap_false
        error = VALUE #(
          code = error->code
          message = error->message
          details = error->details
          suggested_action = error->suggestion
        )
      ).
    ENDIF.
  ENDTRY.
ENDMETHOD.

" Old clients get simple response, still works
" New clients get detailed debugging info
```

---

### Deprecation Strategy

#### Phase 1: Announce (Month 1)

```abap
" In API documentation and response headers
" Deprecation: "Status field will change format in v3. Use status_code instead."

" Log warning when used
logger->log(
  severity = 'WARN'
  message = 'Deprecated API used'
  context = VALUE #(
    deprecated_field = 'status'
    replacement_field = 'status_code'
    removal_date = '2027-01-01'
    client_id = get_client_id( )
  )
);
```

#### Phase 2: Support with Warning (Months 2-12)

```abap
" Continue working but warn clients
" Provide migration guide in docs

" Deprecation Guide:
" Old API: GET /odata/v1/Travels
" New API: GET /odata/v2/Travels
" 
" Differences:
" - status field format changed
" - new estimated_cost field (optional)
" 
" Migration steps:
" 1. Update API version header
" 2. Map status: 'OPEN'→'O', 'APPROVED'→'A'
" 3. Handle new estimated_cost (optional)
" 4. Test thoroughly
```

#### Phase 3: Deprecate (Month 12-18)

```abap
" Start failing with grace
" Return 'Deprecation-Expires' header

HTTP/1.1 200 OK
Deprecation: true
Deprecation-Expires: Sun, 01 Jan 2027 00:00:00 GMT
Link: <https://api.example.org/docs/migration>; rel="deprecation"
```

#### Phase 4: Remove (Month 18+)

```abap
" Return 410 Gone (no longer available)
HTTP/1.1 410 Gone

{
  "error": "API v1 is no longer supported",
  "message": "Use API v2 instead: https://api.example.org/v2",
  "migration_guide": "https://docs.example.org/v1-to-v2"
}
```

Note: `*.example.org` URLs are placeholders for your enterprise domains.

---

### Semantic Versioning

**Format: MAJOR.MINOR.PATCH**

| Change | Version Bump | Example |
|---|---|---|
| **Breaking change** | MAJOR++ | v1.0.0 → v2.0.0 |
| **Backward-compatible addition** | MINOR++ | v1.0.0 → v1.1.0 |
| **Bug fix** | PATCH++ | v1.0.0 → v1.0.1 |

```
v1.2.3 = Backward-compatible since v1.0, but 2 minor features, 3 bug fixes
v2.0.0 = Major breaking change from v1
```

---

### Client Compatibility Rules

**Contract Guarantees:**

```
Within same MAJOR version:
  ✅ New optional fields (client ignores unknown fields)
  ✅ New endpoints (client doesn't call unknown endpoints)
  ✅ Wider types (string gets longer, integer gets bigger)
  ✅ Deprecated but still working (with warnings)

Between MAJOR versions:
  ❌ Field removal or rename
  ❌ Type change (decimal → string)
  ❌ Required field becomes optional (breaks required logic)
  ❌ Required field becomes required (old data fails validation)
```

---

### API Design Checklist

- [ ] Versioning strategy defined (URL path recommended)
- [ ] Backwards compatibility rules documented
- [ ] DTOs versioned separately from domain model
- [ ] Deprecation policy: 6+ months notice before removal
- [ ] Error responses versioned (different per API version)
- [ ] Semantic versioning used (MAJOR.MINOR.PATCH)
- [ ] Deprecated endpoints return 'Deprecation' header
- [ ] Migration guide for each version change
- [ ] Removal date announced 6+ months in advance
- [ ] Client compatibility testing (old clients still work)
- [ ] Documentation updated for each version
- [ ] Contract testing (ensure API behaves as documented)
- [ ] Monitoring for deprecated field usage (track clients)
- [ ] Removal phase with 410 Gone response

