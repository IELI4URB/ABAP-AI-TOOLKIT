# Design Patterns for ABAP Cloud and RAP — Decision-Driven Guide

## Purpose

Use patterns that preserve Clean Core boundaries while keeping RAP services maintainable. Know WHEN to apply each pattern and WHY.

## Prerequisites

- Solid understanding of module 02 (OOP principles) and module 03 (layered architecture).
- Basic RAP implementation familiarity from module 01.
- Clean Core guardrails from module 04 must be accepted before introducing abstractions.

---

## Pattern Selection Matrix: When to Use Each

| Requirement | Pattern | Why | Trade-off |
|---|---|---|---|
| **Hide persistence details from domain logic** | **Repository** | Domain doesn't know if data is RAP, table, external API. Easy to test. | Extra abstraction layer. More code. |
| **Multiple business algorithms vary by country/customer** | **Strategy** | New country = new class. No if-statements. | Requires upfront design. Not worth it for 1 algorithm. |
| **Create complex objects with many dependencies** | **Factory** | Logic for wiring dependencies in one place. | Extra class. Overkill for simple constructors. |
| **Orchestrate multiple domain operations** | **Application Service** | Coordinates use cases. Transaction boundary. | Potential "god service" if too many methods. |
| **Shield domain from external API changes** | **Anti-Corruption Layer** | Internal domain model stays stable when external API changes. | Extra mapping code. More translation. |
| **Notify other domains without coupling** | **Domain Event** | Core logic publishes events. Listeners react. Decoupled. | Eventual consistency. Harder to debug. |
| **Adapt object behavior dynamically** | **Decorator** | Wrap existing object with new behavior. No modification. | Chains can get complex. |
| **Create families of related objects** | **Abstract Factory** | Ensures consistency (all German objects, all French objects). | Overkill for 2 variants. |

---

## Detailed Patterns

### 1. Repository Pattern

**Purpose:** Encapsulate persistence behind an interface. Domain logic knows nothing about storage.

**When to Use**

```
Need to:
  ✓ Swap storage (RAP → External API → Cache)
  ✓ Test domain logic without hitting DB
  ✓ Reuse business logic across multiple storage types
```

**Example**

```abap
" Interface: domain layer doesn't know HOW data is persisted
INTERFACE if_travel_repository.
  METHODS save IMPORTING travel TYPE travel.
  METHODS read_by_id IMPORTING travel_id TYPE travel_id RETURNING VALUE(travel) TYPE travel.
  METHODS read_all RETURNING VALUE(travels) TYPE travel_table.
  METHODS delete IMPORTING travel_id TYPE travel_id.
ENDINTERFACE.

" Implementation 1: RAP (production)
CLASS zcl_travel_repository_rap DEFINITION FINAL.
  INTERFACES if_travel_repository.
ENDCLASS.

CLASS zcl_travel_repository_rap IMPLEMENTATION.
  METHOD if_travel_repository~save.
    MODIFY ENTITIES OF zi_travel_tp
      ENTITY Travel CREATE FROM VALUE #( travel ).
  ENDMETHOD.
  
  METHOD if_travel_repository~read_by_id.
    READ ENTITIES OF zi_travel_tp
      ENTITY Travel BY KEY travel_id RESULT DATA(result).
    travel = result[ 1 ].
  ENDMETHOD.
ENDCLASS.

" Implementation 2: Mock (unit test)
CLASS zcl_travel_repository_mock DEFINITION FINAL.
  INTERFACES if_travel_repository.
  PRIVATE SECTION.
    DATA travels TYPE travel_table.
ENDCLASS.

CLASS zcl_travel_repository_mock IMPLEMENTATION.
  METHOD if_travel_repository~save.
    APPEND travel TO me->travels.  " In-memory only, fast
  ENDMETHOD.
  
  METHOD if_travel_repository~read_by_id.
    travel = travels[ travel_id ].  " Simple lookup
  ENDMETHOD.
ENDCLASS.

" Domain service: depends on interface, works with ANY implementation
CLASS zcl_travel_service DEFINITION FINAL.
  PRIVATE SECTION.
    DATA repository TYPE REF TO if_travel_repository.
  PUBLIC SECTION.
    METHODS constructor IMPORTING repository TYPE REF TO if_travel_repository.
    METHODS process_travel IMPORTING travel_id TYPE travel_id.
ENDCLASS.

CLASS zcl_travel_service IMPLEMENTATION.
  METHOD process_travel.
    DATA(travel) = repository->read_by_id( travel_id ).
    " Business logic — doesn't care if data came from RAP or mock
    travel-status = 'PROCESSED'.
    repository->save( travel ).
  ENDMETHOD.
ENDCLASS.

" Production usage
DATA(rap_repo) = NEW zcl_travel_repository_rap( ).
DATA(service) = NEW zcl_travel_service( rap_repo ).
service->process_travel( '001' ).

" Test usage (same code, different repository)
DATA(mock_repo) = NEW zcl_travel_repository_mock( ).
DATA(service_ut) = NEW zcl_travel_service( mock_repo ).
service_ut->process_travel( '001' ).
```

**Anti-Pattern: Leaky Repository**

```abap
" BAD: Repository returns RAP-specific objects
INTERFACE if_travel_repository.
  METHODS read_by_id RETURNING VALUE(entity) TYPE ref_to_zi_travel.  " Leaks RAP!
ENDINTERFACE.

" Domain now knows about RAP specifics — not portable

" GOOD: Repository returns domain objects only
INTERFACE if_travel_repository.
  METHODS read_by_id RETURNING VALUE(travel) TYPE travel.  " Pure value object
ENDINTERFACE.
```

---

### 2. Strategy Pattern

**Purpose:** Multiple algorithms, selected at runtime based on context (country, customer type, etc.).

**When to Use**

```
Have 3+ variations of same logic:
  ✓ Country-specific pricing (DE, FR, JP, etc.)
  ✓ Customer-type approval flows (regular, VIP, corporate)
  ✓ Shipment routing algorithms (ground, air, sea)
```

**Example: Country-Specific Pricing**

```abap
" Strategy Interface
INTERFACE if_pricing_strategy.
  METHODS calculate_price IMPORTING travel TYPE travel RETURNING VALUE(price) TYPE decimal.
ENDINTERFACE.

" Strategy 1: German pricing (20% VAT)
CLASS zcl_german_pricing DEFINITION FINAL.
  INTERFACES if_pricing_strategy.
ENDCLASS.

CLASS zcl_german_pricing IMPLEMENTATION.
  METHOD if_pricing_strategy~calculate_price.
    price = ( travel-base_price * 1.20 ).  " 20% VAT
  ENDMETHOD.
ENDCLASS.

" Strategy 2: French pricing (differential VAT)
CLASS zcl_french_pricing DEFINITION FINAL.
  INTERFACES if_pricing_strategy.
ENDCLASS.

CLASS zcl_french_pricing IMPLEMENTATION.
  METHOD if_pricing_strategy~calculate_price.
    IF travel-category = 'LUXURY'.
      price = travel-base_price * 1.19.   " 19% VAT
    ELSE.
      price = travel-base_price * 1.055.  " 5.5% VAT
    ENDIF.
  ENDMETHOD.
ENDCLASS.

" Strategy 3: Japan pricing (8% VAT)
CLASS zcl_japan_pricing DEFINITION FINAL.
  INTERFACES if_pricing_strategy.
ENDCLASS.

CLASS zcl_japan_pricing IMPLEMENTATION.
  METHOD if_pricing_strategy~calculate_price.
    price = travel-base_price * 1.08.
  ENDMETHOD.
ENDCLASS.

" Context: Select strategy based on country
INTERFACE if_pricing_strategy_factory.
  METHODS get_strategy IMPORTING country TYPE country RETURNING VALUE(strategy) TYPE REF TO if_pricing_strategy.
ENDINTERFACE.

CLASS zcl_pricing_strategy_factory DEFINITION FINAL.
  INTERFACES if_pricing_strategy_factory.
ENDCLASS.

CLASS zcl_pricing_strategy_factory IMPLEMENTATION.
  METHOD if_pricing_strategy_factory~get_strategy.
    CASE country.
      WHEN 'DE'.
        strategy = NEW zcl_german_pricing( ).
      WHEN 'FR'.
        strategy = NEW zcl_french_pricing( ).
      WHEN 'JP'.
        strategy = NEW zcl_japan_pricing( ).
      WHEN OTHERS.
        strategy = NEW zcl_german_pricing( ).  " Default
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

" Domain service: uses strategy without knowing which one
CLASS zcl_travel_pricing_service DEFINITION FINAL.
  PRIVATE SECTION.
    DATA factory TYPE REF TO if_pricing_strategy_factory.
  PUBLIC SECTION.
    METHODS constructor IMPORTING factory TYPE REF TO if_pricing_strategy_factory.
    METHODS calculate_price IMPORTING travel TYPE travel RETURNING VALUE(price) TYPE decimal.
ENDCLASS.

CLASS zcl_travel_pricing_service IMPLEMENTATION.
  METHOD calculate_price.
    DATA(strategy) = factory->get_strategy( travel-country ).
    price = strategy->calculate_price( travel ).  " No if-statements in domain!
  ENDMETHOD.
ENDCLASS.

" Usage: Add new country WITHOUT modifying existing code!
" Just create zcl_spain_pricing IMPLEMENTING if_pricing_strategy
" Add to factory's CASE statement
" Done! Open/Closed principle respected.
```

**Anti-Pattern: Conditional Logic Instead of Strategy**

```abap
" BAD: All logic hardcoded with if-statements
METHODS calculate_price IMPORTING travel TYPE travel RETURNING VALUE(price) TYPE decimal.
  IF travel-country = 'DE'.
    price = travel-base_price * 1.20.
  ELSEIF travel-country = 'FR'.
    price = travel-base_price * 1.055.
  ELSEIF travel-country = 'JP'.
    price = travel-base_price * 1.08.
  ELSEIF travel-country = 'ES'.  " Adding new country? Modify this method! OCP violation.
    price = travel-base_price * 1.21.
  ENDIF.
ENDMETHOD.

" GOOD: Strategy pattern (no modification needed for new country)
```

---

### 3. Factory Pattern

**Purpose:** Centralize object construction, especially with complex dependency wiring.

**When to Use**

```
Need to:
  ✓ Select implementation based on config/country
  ✓ Centralize dependency wiring (multiple parameters)
  ✓ Create families of related objects
```

**Example**

```abap
INTERFACE if_travel_factory.
  METHODS create_travel_service RETURNING VALUE(service) TYPE REF TO if_travel_service.
ENDINTERFACE.

CLASS zcl_travel_factory DEFINITION FINAL.
  INTERFACES if_travel_factory.
ENDCLASS.

CLASS zcl_travel_factory IMPLEMENTATION.
  METHOD if_travel_factory~create_travel_service.
    " Wire all dependencies in one place
    DATA(repository) = NEW zcl_travel_repository_rap( ).
    DATA(pricing_factory) = NEW zcl_pricing_strategy_factory( ).
    DATA(pricing_service) = NEW zcl_travel_pricing_service( pricing_factory ).
    DATA(notification) = NEW zcl_notification_service( ).
    
    " Return fully configured service
    service = NEW zcl_travel_service(
      repository = repository
      pricing = pricing_service
      notification = notification
    ).
  ENDMETHOD.
ENDCLASS.

" Usage: One line, all dependencies resolved
DATA(factory) = NEW zcl_travel_factory( ).
DATA(service) = factory->create_travel_service( ).
```

**Anti-Pattern: Overkill**

```abap
" BAD: Factory for simple object
INTERFACE if_person_factory.
  METHODS create_person IMPORTING name TYPE string RETURNING VALUE(person) TYPE REF TO zcl_person.
ENDINTERFACE.

CLASS zcl_person_factory IMPLEMENTATION.
  METHOD create_person.
    person = NEW zcl_person( name ).  " Just one line? Not worth factory pattern
  ENDMETHOD.
ENDCLASS.

" GOOD: Direct instantiation
DATA(person) = NEW zcl_person( 'Alice' ).
```

---

### 4. Application Service Pattern

**Purpose:** Orchestrate a business use case. Coordinates domain services, manages transaction scope.

**When to Use**

```
Need to:
  ✓ Implement a complete user journey (create order → calculate price → notify → save)
  ✓ Manage transaction boundaries
  ✓ Coordinate multiple domain objects
```

**Example**

```abap
CLASS zcl_travel_app_service DEFINITION FINAL.
  PRIVATE SECTION.
    DATA repository TYPE REF TO if_travel_repository.
    DATA pricing_service TYPE REF TO if_travel_pricing_service.
    DATA notification_service TYPE REF TO if_notification_service.
  PUBLIC SECTION.
    METHODS constructor IMPORTING
      repository TYPE REF TO if_travel_repository
      pricing_service TYPE REF TO if_travel_pricing_service
      notification_service TYPE REF TO if_notification_service.
    
    METHODS create_travel IMPORTING
      agency_id TYPE agency_id
      destination TYPE destination
      RETURNING VALUE(travel) TYPE travel.
    
    METHODS approve_travel IMPORTING travel_id TYPE travel_id.
    
    METHODS cancel_travel IMPORTING travel_id TYPE travel_id.
ENDCLASS.

CLASS zcl_travel_app_service IMPLEMENTATION.
  METHOD create_travel.
    " Orchestrate: create → price → save → notify
    travel = NEW zcl_travel( ).
    travel->set_agency_id( agency_id ).
    travel->set_destination( destination ).
    
    DATA(price) = pricing_service->calculate_price( travel ).
    travel->set_price( price ).
    
    repository->save( travel ).
    notification_service->notify_created( travel ).
  ENDMETHOD.

  METHOD approve_travel.
    DATA(travel) = repository->read_by_id( travel_id ).
    travel->approve( ).
    repository->save( travel ).
    notification_service->notify_approved( travel ).
  ENDMETHOD.

  METHOD cancel_travel.
    DATA(travel) = repository->read_by_id( travel_id ).
    travel->cancel( ).
    repository->save( travel ).
    notification_service->notify_cancelled( travel ).
  ENDMETHOD.
ENDCLASS.
```

**Anti-Pattern: God Service**

```abap
" BAD: Service with 20+ methods, doing everything
CLASS zcl_mega_service.
  METHODS create_travel.
  METHODS update_travel.
  METHODS delete_travel.
  METHODS approve_travel.
  METHODS send_email.
  METHODS export_to_xml.
  METHODS import_from_csv.
  METHODS calculate_statistics.
  METHODS generate_report.
  ... 11 more methods
ENDCLASS.

" GOOD: Split by responsibility
CLASS zcl_travel_app_service.       " Travel use cases only
  METHODS create_travel.
  METHODS update_travel.
  METHODS approve_travel.
ENDCLASS.

CLASS zcl_travel_export_service.    " Export only
  METHODS export_to_xml.
ENDCLASS.

CLASS zcl_travel_import_service.    " Import only
  METHODS import_from_csv.
ENDCLASS.

CLASS zcl_travel_analytics_service. " Reporting only
  METHODS calculate_statistics.
  METHODS generate_report.
ENDCLASS.
```

---

### 5. Anti-Corruption Layer (ACL)

**Purpose:** Shield internal domain from external API changes. Translate between models.

**When to Use**

```
Need to:
  ✓ Call third-party API but don't want domain to depend on it
  ✓ Protect from external API breaking changes
  ✓ Translate between internal domain model and external API model
```

**Example: Calling External Airline API**

```abap
" External API model (not owned by us, subject to change)
TYPES: BEGIN OF airline_api_booking,
  booking_id TYPE string,
  flight_code TYPE string,
  passenger_names TYPE table OF string,
  total_cost TYPE decimal,
  currency_code TYPE currency,
END OF airline_api_booking.

" Internal domain model (stable, under our control)
CLASS zcl_travel.
  PRIVATE SECTION.
    DATA travel_id TYPE travel_id.
    DATA flight_code TYPE string.
    DATA passengers TYPE passenger_table.
    DATA price TYPE price.
ENDCLASS.

" Anti-Corruption Layer: Translates between external and internal
INTERFACE if_airline_api.
  METHODS call_external_api IMPORTING RETURNING VALUE(booking) TYPE airline_api_booking.
ENDINTERFACE.

CLASS zcl_airline_acl DEFINITION FINAL.
  PRIVATE SECTION.
    DATA airline_api TYPE REF TO if_airline_api.
  PUBLIC SECTION.
    METHODS constructor IMPORTING airline_api TYPE REF TO if_airline_api.
    METHODS book_travel IMPORTING travel TYPE zcl_travel RETURNING VALUE(travel_id) TYPE travel_id.
ENDCLASS.

CLASS zcl_airline_acl IMPLEMENTATION.
  METHOD book_travel.
    " Call external API
    DATA(external_booking) = airline_api->call_external_api( ).
    
    " Translate external model → internal domain model
    DATA(internal_travel) = NEW zcl_travel( ).
    internal_travel->set_flight_code( external_booking-flight_code ).
    
    " Handle currency conversion if needed
    internal_travel->set_price( convert_to_euro( external_booking-total_cost, external_booking-currency_code ) ).
    
    " Store in repository
    repository->save( internal_travel ).
    
    travel_id = internal_travel->get_id( ).
  ENDMETHOD.
ENDCLASS.

" Usage: Domain service doesn't know about external API
CLASS zcl_travel_service.
  PRIVATE SECTION.
    DATA acl TYPE REF TO zcl_airline_acl.  " ACL hides external API
  PUBLIC SECTION.
    METHODS book_travel IMPORTING travel TYPE zcl_travel.
      acl->book_travel( travel ).  " Domain never sees external API model!
ENDCLASS.

" Benefit: If external API changes, only ACL needs update, domain is protected.
```

---

### 6. Domain Event Pattern

**Purpose:** Decouple domains by publishing events. One domain publishes, others listen.

**When to Use**

```
Need to:
  ✓ Notify other domains without coupling
  ✓ Implement asynchronous workflows
  ✓ Keep domain logic pure (no side effects in domain)
```

**Example**

```abap
" Event interface
INTERFACE if_domain_event.
  METHODS get_aggregate_id RETURNING VALUE(id) TYPE aggregate_id.
ENDINTERFACE.

" Concrete event
CLASS zcl_travel_created DEFINITION FINAL.
  INTERFACES if_domain_event.
  PRIVATE SECTION.
    DATA travel TYPE travel.
  PUBLIC SECTION.
    METHODS constructor IMPORTING travel TYPE travel.
    METHODS get_travel RETURNING VALUE(t) TYPE travel.
ENDCLASS.

" Domain publishes event (no coupling to listeners)
CLASS zcl_travel DEFINITION FINAL.
  PRIVATE SECTION.
    DATA events TYPE TABLE OF REF TO if_domain_event.
  PUBLIC SECTION.
    METHODS publish_events RETURNING VALUE(published) TYPE TABLE OF REF TO if_domain_event.
      published = events.
      CLEAR events.
    ENDMETHOD.
  PROTECTED SECTION.
    METHODS raise_event IMPORTING event TYPE REF TO if_domain_event.
      APPEND event TO events.
    ENDMETHOD.
ENDCLASS.

CLASS zcl_travel IMPLEMENTATION.
  METHODS create.
    " Domain logic
    me->status = 'CREATED'.
    
    " Publish event (domain doesn't know who listens)
    raise_event( NEW zcl_travel_created( me ) ).
  ENDMETHOD.
ENDCLASS.

" Event handler (notification domain)
CLASS zcl_travel_notification_listener DEFINITION FINAL.
  INTERFACES if_event_listener.
  PUBLIC SECTION.
    METHODS handle_event IMPORTING event TYPE REF TO if_domain_event.
ENDCLASS.

CLASS zcl_travel_notification_listener IMPLEMENTATION.
  METHOD handle_event.
    IF event IS INSTANCE OF zcl_travel_created.
      DATA(created_event) = CAST zcl_travel_created( event ).
      DATA(travel) = created_event->get_travel( ).
      send_confirmation_email( travel ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

" Event handler (billing domain)
CLASS zcl_billing_listener DEFINITION FINAL.
  INTERFACES if_event_listener.
  PUBLIC SECTION.
    METHODS handle_event IMPORTING event TYPE REF TO if_domain_event.
ENDCLASS.

CLASS zcl_billing_listener IMPLEMENTATION.
  METHOD handle_event.
    IF event IS INSTANCE OF zcl_travel_created.
      DATA(created_event) = CAST zcl_travel_created( event ).
      DATA(travel) = created_event->get_travel( ).
      create_invoice( travel ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

" Result: Travel domain doesn't know about notification or billing
" But both are notified when travel is created!
" Domains are decoupled — can be deployed separately.
```

---

## Full Pattern Catalog and Decision Matrix

This section consolidates all major patterns referenced in ABAP Objects guidance and maps them to ABAP Cloud usage decisions.

### Complete Pattern Catalog

| Pattern | Primary Intent | Use When | Avoid When |
|---|---|---|---|
| Repository | Hide persistence details | Domain must stay storage-agnostic | Domain and storage are trivial and fixed |
| Application Service | Orchestrate use-case flow | One use case needs multiple domain steps | Service starts accumulating unrelated responsibilities |
| Anti-Corruption Layer | Isolate external model drift | External API is unstable or differently modeled | External model is stable and identical to domain model |
| Domain Event | Decouple side effects | Multiple subscribers react to domain changes | You need strict synchronous transactional behavior |
| Strategy | Swap algorithms at runtime | 3+ rule variants by market/customer/context | Only one stable algorithm exists |
| Factory Method | Centralize object creation | Creation varies by input/context | Constructor logic is simple and fixed |
| Abstract Factory | Create related object families | You need coherent family variants together | Only one object type varies |
| Adapter | Translate incompatible interface | Existing provider contract cannot change | Contracts already align |
| Facade | Simplify subsystem access | Clients need one entry point across many services | Only one simple service is involved |
| Proxy | Control access/lifecycle | Lazy init, access control, or remote indirection needed | Direct access is cheap and safe |
| Decorator | Add behavior without subclassing | Optional cross-cutting behavior is layered | A single fixed behavior is sufficient |
| Composite | Uniform tree handling | Parent-child object trees need same operations | Data is flat and not hierarchical |
| Iterator | Traverse collections cleanly | Traversal rules are complex/reusable | Plain LOOP over internal table is enough |
| Observer | Event-based notification | Multiple consumers listen to one subject | There is exactly one tightly coupled consumer |
| Prototype | Clone configured instances | Object setup is expensive and repeated | Fresh instances are cheap and safer |
| Singleton | Single shared instance | One instance is a hard technical constraint | State leaks or test isolation become difficult |
| Singleton Factory (Object Pool) | Reuse keyed instances | Same key should return same instance, different keys need different instances | Lifecycle management is unnecessary |
| MVC | Separate model/view/controller | UI interaction logic must be isolated from domain | There is no UI-specific interaction layer |
| Callback Local-Data Reference | Pass context through deep callback stack safely | API callback cannot be extended with parameters | Regular parameter passing is possible |

### Decision Matrix by Requirement

| Requirement Signal | First Pattern Choice | Second Option | Key Decision Rule |
|---|---|---|---|
| Country or customer specific algorithm | Strategy | Decorator | Prefer Strategy if behavior fully replaces algorithm |
| Complex multi-dependency object creation | Factory Method | Abstract Factory | Use Abstract Factory only for related families |
| External API contract mismatch | Adapter | Anti-Corruption Layer | Use ACL when model translation and boundary protection are both required |
| Need one simplified integration entry point | Facade | Application Service | Facade for subsystem simplification, service for use-case orchestration |
| Lazy object creation or guarded access | Proxy | Factory Method | Proxy when post-creation calls must stay transparent |
| Optional behavior layering (logging/enrichment) | Decorator | Observer | Use Decorator for in-call behavior; Observer for event reaction |
| Hierarchical structure operations | Composite | Iterator | Composite models hierarchy; Iterator controls traversal behavior |
| Broadcast domain change to many consumers | Domain Event | Observer | Domain Event for business events; Observer for technical subject listeners |
| Reuse by key with stable identity | Singleton Factory | Singleton | Prefer keyed pool over global singleton for multi-tenant contexts |
| Clone baseline configuration repeatedly | Prototype | Factory Method | Use Prototype when copying is cheaper than rebuilding |
| UI flow separation requirement | MVC | Facade | MVC for interaction boundaries, Facade for backend simplification |
| Deep callback needs caller context | Callback Local-Data Reference | Explicit parameter flow | Use only if interfaces are fixed and non-extendable |

### ABAP Cloud Pattern Selection Rules

- Start from the smallest pattern that solves the requirement.
- Favor interface-first designs to satisfy DIP and testability.
- Prefer composition over inheritance for extensibility.
- Reject patterns that introduce global mutable state unless lifecycle constraints are proven.
- For new integrations, evaluate Adapter versus ACL explicitly and document the decision.
- For variant-heavy logic, require Strategy plus Factory Method as the default pair.

---

## Pattern Anti-Patterns Summary

| Pattern | Misuse | Fix |
|---|---|---|
| **Repository** | Repository returns technical objects (entity refs) | Return domain value objects only |
| **Strategy** | Strategy for 1 algorithm | Just use conditional if-statement |
| **Factory** | Factory for simple 1-line objects | Direct instantiation is fine |
| **Service** | Service has 20+ methods (god service) | Split into focused services |
| **ACL** | ACL unnecessarily translates similar models | Use external model directly if no risk |
| **Event** | Sync events (defeats purpose) | Use events for async workflows, not blocking calls |

---

## Consolidated Quick Reference (Canonical)

This section combines the compact design reference with the deeper pattern catalog above.

### Pattern Selection Matrix (Need/Pattern/Skip)

| Need | Pattern | Skip When |
|---|---|---|
| Hide persistence from domain | Repository | Simple one-table CRUD without test isolation need |
| Multiple algorithms by context | Strategy | Only one algorithm and no extension planned |
| Complex object construction | Factory | Simple NEW is enough |
| Orchestrate multiple domain operations | Application Service | Single-class use case |
| Shield domain from external API | Anti-Corruption Layer | Internal API is already under your control |
| Decouple domain from side effects | Domain Event | Same-system synchronous flow is acceptable |
| Add behavior dynamically | Decorator | Static behavior is enough |

### Canonical Repository Snippet

```abap
INTERFACE if_travel_repository.
  METHODS save   IMPORTING travel    TYPE ztravel.
  METHODS read   IMPORTING travel_id TYPE ztravel_id
                 RETURNING VALUE(travel) TYPE ztravel.
  METHODS delete IMPORTING travel_id TYPE ztravel_id.
ENDINTERFACE.

" Production repository
CLASS zcl_travel_repo_rap DEFINITION FINAL.
  INTERFACES if_travel_repository.
ENDCLASS.
CLASS zcl_travel_repo_rap IMPLEMENTATION.
  METHOD if_travel_repository~save.
    MODIFY ENTITIES OF zi_travel_tp ENTITY Travel CREATE FROM VALUE #( travel ).
  ENDMETHOD.
ENDCLASS.

" Test double repository
CLASS zcl_travel_repo_mock DEFINITION FINAL.
  INTERFACES if_travel_repository.
  PRIVATE SECTION.
    DATA travels TYPE TABLE OF ztravel.
ENDCLASS.
CLASS zcl_travel_repo_mock IMPLEMENTATION.
  METHOD if_travel_repository~save.
    INSERT travel INTO TABLE travels.
  ENDMETHOD.
ENDCLASS.
```

### Canonical Strategy Snippet

```abap
INTERFACE if_pricing_strategy.
  METHODS calculate IMPORTING travel TYPE ztravel
                    RETURNING VALUE(price) TYPE p.
ENDINTERFACE.

CLASS zcl_travel_service DEFINITION.
  METHODS constructor IMPORTING strategy TYPE REF TO if_pricing_strategy.
  PRIVATE SECTION.
    DATA pricing TYPE REF TO if_pricing_strategy.
ENDCLASS.
```

### Canonical Factory Snippet

```abap
CLASS zcl_travel_factory DEFINITION FINAL.
  CLASS-METHODS create_service RETURNING VALUE(s) TYPE REF TO if_travel_service.
ENDCLASS.
CLASS zcl_travel_factory IMPLEMENTATION.
  METHOD create_service.
    s = NEW zcl_travel_service(
      repository = NEW zcl_travel_repo_rap( )
      pricing    = NEW zcl_standard_pricing( )
      notifier   = NEW zcl_email_notifier( ) ).
  ENDMETHOD.
ENDCLASS.
```

### Canonical Application Service Snippet

```abap
CLASS zcl_travel_app_service DEFINITION.
  METHODS approve_travel IMPORTING travel_id TYPE ztravel_id
                         RAISING   cx_travel_error.
  PRIVATE SECTION.
    DATA repository TYPE REF TO if_travel_repository.
    DATA authorizer TYPE REF TO if_travel_authorizer.
    DATA event_bus  TYPE REF TO if_event_bus.
ENDCLASS.
CLASS zcl_travel_app_service IMPLEMENTATION.
  METHOD approve_travel.
    DATA(travel) = repository->read( travel_id ).
    authorizer->check_can_approve( travel ).
    travel-status = 'A'.
    repository->save( travel ).
    event_bus->publish( NEW zcl_travel_approved_event( travel_id ) ).
  ENDMETHOD.
ENDCLASS.
```

### Dependency Injection Rule

```abap
" BAD: hard-coded and hard to unit test
METHOD create.
  DATA(repo) = NEW zcl_travel_repository( ).
ENDMETHOD.

" GOOD: injected dependency
METHOD constructor.
  IMPORTING repository TYPE REF TO if_travel_repository.
  me->repository = repository.
ENDMETHOD.
```

### Canonical Anti-Patterns

| Pattern | Why Bad | Fix |
|---|---|---|
| God class (200+ lines) | Untestable and high coupling | Split by responsibility |
| Data class only (get/set) | Missing domain behavior | Add behavior to the class |
| Concrete dependency | Cannot mock in tests | Depend on interfaces |
| Inheritance for reuse only | Fragile base class risk | Prefer composition |
| Static methods with stateful logic | Hard to mock and test | Use instance methods |

---

## Minimal Checklist

- [ ] Repository used to hide persistence details
- [ ] No domain logic in persistence layer
- [ ] Strategy pattern used for 3+ variants (not 1-2)
- [ ] Factory used only for complex dependency wiring
- [ ] Services have <10 public methods
- [ ] ACL used for external API boundaries
- [ ] Events for async workflows (not sync calls)
- [ ] No conditional if-statements replacing patterns
- [ ] Patterns don't create unnecessary abstractions
- [ ] Each pattern solves a specific problem

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
