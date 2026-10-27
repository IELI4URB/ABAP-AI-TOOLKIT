# OOP Design Principles for ABAP Cloud — When to Use What

## Objective

Apply object-oriented design that improves maintainability, testability, and upgrade safety in ABAP Cloud. Know WHEN and WHY to apply each principle, with decision matrices and anti-pattern warnings.

## Prerequisites

- ABAP OO fundamentals (interfaces, inheritance, visibility, exception handling).
- Familiarity with architecture layering and Clean Core constraints.
- Recommended before implementation-heavy design work.

---

## SOLID Principles Comprehensive Guide

### 1. Single Responsibility Principle (SRP)

**Definition:** One class has one reason to change.

**When to Apply**

| Scenario | Action | Why |
|---|---|---|
| Class has 2+ purposes (e.g., saves data AND formats for UI) | **Split** | Each has different change driver. Harder to test. |
| Class handles only one domain concern | **Keep** | Cohesive. Easy to test and reuse. |
| Class name uses "And" (e.g., `TravelCreatorAndValidator`) | **Red flag** | Split immediately. |
| Class has 200+ lines | **Review** | Likely doing too much. |

**Anti-Pattern: God Class**

```abap
" BAD: TravelManager does everything
CLASS zcl_travel_manager.
  PUBLIC SECTION.
    METHODS create_travel.          " Creates data
    METHODS calculate_price.        " Business logic
    METHODS save_to_db.             " Persistence
    METHODS send_email.             " Integration
    METHODS format_for_ui.          " Presentation
  PRIVATE SECTION.
    DATA ztravel TYPE ztravel.
ENDCLASS.

" GOOD: Split by responsibility
CLASS zcl_travel_service.         " Use case orchestration
  METHODS create_travel.
    " Calls:
    "   - travel_factory.create()
    "   - price_calculator.calculate()
    "   - travel_repository.save()
    "   - notification_service.notify()
ENDCLASS.

CLASS zcl_travel_factory.         " Creation logic
  METHODS create.
ENDCLASS.

CLASS zcl_price_calculator.       " Price logic
  METHODS calculate.
ENDCLASS.

CLASS zcl_travel_repository.      " Persistence
  METHODS save.
ENDCLASS.

CLASS zcl_notification_service.   " Integration
  METHODS notify_travel_created.
ENDCLASS.
```

**When to Stop:** Each class ~50-100 lines. If you have 5 lines for `send_email`, don't separate — keep it together if it's one cohesive concern.

---

### 2. Open/Closed Principle (OCP)

**Definition:** Classes should be open for extension, closed for modification.

**When to Apply**

| Requirement | Approach | Why |
|---|---|---|
| Multiple country pricing rules (DE, FR, JP) | **Strategy pattern** | New country = new class, no changes to existing code. |
| Different travel approval workflows | **Behavior composition** | Each workflow = new class. Core logic untouched. |
| Special handling for VIP customers | **Decorator pattern** | Wrap TravelService with VIPTravelDecorator. |
| One-time custom logic for Client A | **Conditional if-statement OK** | Not worth abstraction if it won't be reused. |

**Anti-Pattern: Fragile Base Class (Modification Cascade)**

```abap
" BAD: Adding features by modifying existing class
CLASS zcl_travel_service DEFINITION.
  METHODS create_travel.
    IF country = 'DE'. " Germany rule
      ...
    ELSEIF country = 'FR'. " France rule
      ...
    ELSEIF country = 'JP'. " Japan rule (added later, modified existing class!)
      ...
    ENDIF.
  ENDMETHOD.
ENDCLASS.

" GOOD: Extend via composition
INTERFACE if_travel_price_calculator.
  METHODS calculate_price IMPORTING travel TYPE travel RETURNING VALUE(price) TYPE decimal.
ENDINTERFACE.

CLASS zcl_german_price_calculator DEFINITION.
  INTERFACES if_travel_price_calculator.
ENDCLASS.

CLASS zcl_french_price_calculator DEFINITION.
  INTERFACES if_travel_price_calculator.
ENDCLASS.

CLASS zcl_travel_service DEFINITION.
  PRIVATE SECTION.
    DATA calculator TYPE REF TO if_travel_price_calculator.
  PUBLIC SECTION.
    METHODS create_travel IMPORTING calculator TYPE REF TO if_travel_price_calculator.
ENDCLASS.

" Usage:
DATA(german_calc) = NEW zcl_german_price_calculator( ).
DATA(service) = NEW zcl_travel_service( german_calc ).

DATA(french_calc) = NEW zcl_french_price_calculator( ).
service = NEW zcl_travel_service( french_calc ). " No modification to TravelService!
```

**Decision:** If adding a new feature requires modifying 3+ existing methods → apply OCP. If it's a one-line config change → keep it simple.

---

### 3. Liskov Substitution Principle (LSP)

**Definition:** Subtypes must preserve contracts. `Derived d = Base b;` must work without surprise.

**When to Apply**

| Scenario | Issue | Fix |
|---|---|---|
| Subclass throws exception where superclass returns value | **LSP violation** | Make subclass return the same contract type. |
| Subclass requires stricter input than parent | **LSP violation** | Move stricter checks to parent or redesign. |
| Subclass returns restricted output | **LSP violation** | Parent promises T, subclass delivers T (same range). |

**Anti-Pattern: Narrowing Contract**

```abap
" BAD: Subclass violates Liskov
INTERFACE if_travel_validator.
  METHODS validate IMPORTING travel TYPE travel RETURNING VALUE(valid) TYPE abap_bool.
ENDINTERFACE.

CLASS zcl_basic_validator DEFINITION.
  INTERFACES if_travel_validator.
  METHODS validate.
    " Returns TRUE/FALSE based on date logic
  ENDMETHOD.
ENDCLASS.

CLASS zcl_strict_validator DEFINITION.
  INTERFACES if_travel_validator.
  METHODS validate.
    " Throws EXCEPTION if date logic fails (violates contract!)
    IF travel-start_date <= sy-datlo.
      RAISE EXCEPTION.  " WRONG: Interface promises return TRUE/FALSE
    ENDIF.
  ENDMETHOD.
ENDCLASS.

" GOOD: Preserve contract
CLASS zcl_strict_validator DEFINITION.
  INTERFACES if_travel_validator.
  METHODS validate.
    IF travel-start_date <= sy-datlo.
      RETURN false.  " Consistent with interface contract
    ENDIF.
    RETURN true.
  ENDMETHOD.
ENDCLASS.
```

**When to enforce LSP:** When your code does `DATA(valid) = validator->validate( travel ).` and you can swap implementations without surprises.

---

### 4. Interface Segregation Principle (ISP)

**Definition:** Many client-specific interfaces are better than one general-purpose interface.

**When to Apply**

| Code | Issue | Fix |
|---|---|---|
| Interface has 10 methods, client uses only 3 | **Fat interface** | Split into 3 focused interfaces. |
| "Do I implement method X?" (forced stub) | **Fat interface** | Client doesn't need it. Remove from interface. |
| Interface changes, affects unrelated clients | **Fat interface** | Split by client need. |

**Anti-Pattern: Fat Interface**

```abap
" BAD: One huge interface
INTERFACE if_travel_service.
  METHODS create_travel.
  METHODS update_travel.
  METHODS delete_travel.
  METHODS approve_travel.         " Only managers need this
  METHODS calculate_price.        " Only accounting needs this
  METHODS send_notification.      " Only integration needs this
  METHODS export_to_xml.          " Only reporting needs this
ENDINTERFACE.

" GOOD: Segregated interfaces
INTERFACE if_travel_crud.
  METHODS create_travel.
  METHODS update_travel.
  METHODS delete_travel.
ENDINTERFACE.

INTERFACE if_travel_approval.
  METHODS approve_travel.
ENDINTERFACE.

INTERFACE if_travel_pricing.
  METHODS calculate_price.
ENDINTERFACE.

INTERFACE if_travel_notification.
  METHODS send_notification.
ENDINTERFACE.

" Usage: Classes implement only what they need
CLASS zcl_travel_service DEFINITION.
  INTERFACES if_travel_crud.
  INTERFACES if_travel_approval.
ENDCLASS.

CLASS zcl_travel_export DEFINITION.
  " Implements only export, not CRUD or approval
  METHODS export_to_xml.
ENDCLASS.
```

**Decision:** If interface has >5 methods, review for segregation. If a class implements an interface but leaves 3+ methods as stubs → segregate.

---

### 5. Dependency Inversion Principle (DIP)

**Definition:** Depend on abstractions (interfaces), not concretions (classes).

**When to Apply**

| Code | Problem | Fix |
|---|---|---|
| `NEW zcl_concrete_class()` inside method | **Hard dependency** | Inject interface via constructor. |
| Calling static methods (`ZCL_CLASS=>METHOD()`) | **Hard dependency** | Use instance interface. |
| Direct SELECT from DB inside domain class | **Hard dependency** | Inject repository interface. |

**Anti-Pattern: Tight Coupling**

```abap
" BAD: Hard dependency on concrete class
CLASS zcl_travel_service DEFINITION.
  PUBLIC SECTION.
    METHODS create_travel.
  PRIVATE SECTION.
    DATA repository TYPE REF TO zcl_travel_repository.  " Concrete class!
    DATA calculator TYPE REF TO zcl_price_calculator.   " Concrete class!
ENDCLASS.

CLASS zcl_travel_service IMPLEMENTATION.
  METHOD create_travel.
    repository = NEW zcl_travel_repository( ).          " Hard dependency
    calculator = NEW zcl_price_calculator( ).           " Hard dependency
    " Impossible to test with test doubles!
  ENDMETHOD.
ENDCLASS.

" GOOD: Depend on interfaces, inject via constructor
INTERFACE if_travel_repository.
  METHODS save IMPORTING travel TYPE travel.
  METHODS read_by_id IMPORTING travel_id TYPE travel_id RETURNING VALUE(travel) TYPE travel.
ENDINTERFACE.

INTERFACE if_price_calculator.
  METHODS calculate_price IMPORTING travel TYPE travel RETURNING VALUE(price) TYPE decimal.
ENDINTERFACE.

CLASS zcl_travel_service DEFINITION.
  PUBLIC SECTION.
    METHODS constructor IMPORTING
      repository TYPE REF TO if_travel_repository
      calculator TYPE REF TO if_price_calculator.
    METHODS create_travel.
  PRIVATE SECTION.
    DATA repository TYPE REF TO if_travel_repository.
    DATA calculator TYPE REF TO if_price_calculator.
ENDCLASS.

CLASS zcl_travel_service IMPLEMENTATION.
  METHOD constructor.
    me->repository = repository.
    me->calculator = calculator.
  ENDMETHOD.
  
  METHOD create_travel.
    DATA(price) = calculator->calculate_price( travel ).
    repository->save( travel ).
  ENDMETHOD.
ENDCLASS.

" Usage: Production
DATA(repo) = NEW zcl_travel_repository( ).
DATA(calc) = NEW zcl_price_calculator( ).
DATA(service) = NEW zcl_travel_service( repo, calc ).

" Usage: Unit test (with test doubles)
DATA(mock_repo) = NEW zcl_travel_repository_mock( ).
DATA(mock_calc) = NEW zcl_price_calculator_mock( ).
DATA(service_under_test) = NEW zcl_travel_service( mock_repo, mock_calc ).
```

**Decision:** Every external dependency (repository, API client, clock, random generator) → inject via constructor.

---

## ABAP Cloud Class Design Rules

### Rule 1: Public vs Private vs Package

```abap
" GLOBAL (exported, everyone can use)
CLASS zcl_travel_service DEFINITION PUBLIC FINAL.
  PUBLIC SECTION.
    METHODS create_travel.  " This is the contract
ENDCLASS.

" PACKAGE (only within package, not exported)
CLASS zcl_travel_factory DEFINITION PACKAGE.  " Hidden from outside
  PUBLIC SECTION.
    METHODS create.
ENDCLASS.

" PRIVATE (only within same source)
CLASS zcl_internal_helper DEFINITION PRIVATE.  " Internal only
  PUBLIC SECTION.
    METHODS helper_method.
ENDCLASS.
```

**Rule:** Export only stable contracts. Keep factories and helpers package-private.

### Rule 2: Fail Fast on Invalid State

```abap
" GOOD: Fail fast
METHODS process_travel IMPORTING travel TYPE travel.
  IF travel-status IS INITIAL.
    RAISE EXCEPTION TYPE cx_travel_error EXPORTING msg = 'Status required'.
  ENDIF.
  ...
ENDMETHOD.

" BAD: Silently return (hidden failure)
METHODS process_travel IMPORTING travel TYPE travel RETURNING VALUE(success) TYPE abap_bool.
  IF travel-status IS INITIAL.
    RETURN false.  " Caller might ignore result
  ENDIF.
  ...
ENDMETHOD.
```

**Rule:** Use exceptions for errors, not return codes.

### Rule 3: Immutable Value Objects

```abap
" GOOD: Immutable travel snapshot
CLASS zcl_travel_snapshot DEFINITION FINAL IMMUTABLE.
  PUBLIC SECTION.
    METHODS constructor IMPORTING
      travel_id TYPE travel_id
      status TYPE travel_status.
    METHODS get_travel_id RETURNING VALUE(id) TYPE travel_id.
    METHODS get_status RETURNING VALUE(s) TYPE travel_status.
ENDCLASS.

" GOOD: Use value objects in domain logic
METHODS can_approve IMPORTING snapshot TYPE zcl_travel_snapshot RETURNING VALUE(can) TYPE abap_bool.
  can = snapshot->get_status( ) = 'PENDING'.
ENDMETHOD.

" BAD: Mutable state passed around
DATA travel TYPE travel.
travel-status = 'PENDING'.
travel-status = 'APPROVED'.  " Changed somewhere else — hard to trace
```

**Rule:** Value objects for core calculations. Make them immutable when possible.

---

## Class Layering Strategy

### Recommended Layer Architecture

```
RAP Behavior Handler (entry point)
    ↓
Application Service (orchestration)
    ↓
Domain Services (business logic)
    ↓
Value Objects (calculations)
    ↓
Repository (persistence abstraction)
    ↓
RAP EML / CDS
```

### Example: Travel Creation Flow

```abap
" Layer 1: RAP Behavior Handler
METHODS create FOR MODIFY IMPORTING entities FOR CREATE Travel.
  CREATE OBJECT(zcl_travel_app_service)->create_travel( entity-AgencyID ).
ENDMETHOD.

" Layer 2: Application Service (orchestration)
CLASS zcl_travel_app_service.
  METHODS create_travel IMPORTING agency_id TYPE agency_id.
    DATA(travel) = factory->create( agency_id ).
    DATA(price) = pricing_service->calculate( travel ).
    repository->save( travel ).
    notification->notify_created( travel ).
  ENDMETHOD.
ENDCLASS.

" Layer 3: Domain Service (business logic)
CLASS zcl_pricing_service.
  METHODS calculate IMPORTING travel TYPE travel RETURNING VALUE(price) TYPE decimal.
    RETURN base_price * quantity * country_factor.
  ENDMETHOD.
ENDCLASS.

" Layer 4: Value Object (pure calculation)
CLASS zcl_price_calculator.
  METHODS calculate IMPORTING base TYPE decimal qty TYPE qty country TYPE country
    RETURNING VALUE(total) TYPE decimal.
    RETURN base * qty * get_factor( country ).
  ENDMETHOD.
ENDCLASS.

" Layer 5: Repository (persistence)
INTERFACE if_travel_repository.
  METHODS save.
  METHODS read_by_id.
ENDINTERFACE.
```

---

## Anti-Patterns Summary

| Anti-Pattern | Problem | Solution |
|---|---|---|
| **Singleton** | Static state, hard to test, hidden dependency | Use constructor injection |
| **ServiceLocator** | `SERVICE_MANAGER->get( 'Repository' )` | Explicit constructor injection |
| **Anemic Domain** | All logic in service layer, objects are data bags | Move business logic to domain classes |
| **Circular Dependencies** | ClassA → ClassB → ClassA | Reorganize layers, introduce interfaces |
| **Static Helpers** | `ZCL_UTILS=>format_date( )` | Instance methods in focused classes |

---

## Minimal Checklist

- [ ] Each class has one clear responsibility
- [ ] No class directly instantiates dependencies (inject via constructor)
- [ ] All external dependencies are behind interfaces
- [ ] Interfaces are focused (not fat)
- [ ] Public methods expose business intent, not technical details
- [ ] No static mutable state
- [ ] Errors use exceptions, not return codes
- [ ] Classes can be swapped with test doubles
- [ ] Package visibility used correctly (public / package / private)

## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
