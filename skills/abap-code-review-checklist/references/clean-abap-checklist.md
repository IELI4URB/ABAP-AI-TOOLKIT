# Clean ABAP Checklist — Development Guidelines

**Use this checklist WHILE WRITING CODE**, not just during review. Apply these standards from the first class, method, and variable declaration.

---

## Names Checklist

**Apply during development:**
- ✅ All variables have descriptive, meaningful names
- ✅ **No Hungarian notation** (iv_, ev_, lv_, lt_, ls_, gt_)
- ✅ Consistent use of snake_case
- ✅ No abbreviations unless commonly understood
- ✅ Class names are nouns (e.g., `account`, `reader`, `converter`)
- ✅ Method names are verbs (e.g., `read`, `calculate`, `validate`)
- ✅ Boolean methods start with `is_`, `has_`, `can_`
- ✅ **No noise words** (data, info, object) unless meaningful
- ✅ Same abbreviations used consistently throughout
- ✅ No obscuring of built-in functions (lines, strlen, condense)

**Example (WRONG):**
```abap
DATA lv_cnt TYPE i.           " ← Hungarian notation, unclear
DATA lt_accts TYPE TABLE OF   " ← "accts" is abbreviation
DATA gs_result TYPE result.   " ← Noise word "gs_"
METHOD get_data.              " ← Verb, but vague
```

**Example (RIGHT):**
```abap
DATA account_count TYPE i.
DATA accounts TYPE TABLE OF account.
DATA result TYPE result.
METHOD read_account.
```

---

## Language Checklist

**Apply during development:**
- ✅ Uses modern syntax (`NEW` instead of `CREATE OBJECT`)
- ✅ Uses functional style (`VALUE`, `COND`, `SWITCH`, `FILTER`)
- ✅ No obsolete constructs (`MOVE`, `TRANSLATE`, `ADD`)
- ✅ `SELECT` uses `@` for host variables
- ✅ Inline declarations where appropriate
- ✅ Table expressions instead of `READ TABLE`
- ✅ Object-oriented (classes) instead of procedural (function modules)

**Example (WRONG):**
```abap
CREATE OBJECT account.
MOVE value1 TO value2.
SELECT * FROM database INTO TABLE @result WHERE id = id.
READ TABLE accounts INTO account TRANSPORTING NO FIELDS.
```

**Example (RIGHT):**
```abap
DATA(account) = NEW account( ).
value2 = value1.
SELECT * FROM database INTO TABLE @result WHERE id = @input_id.
IF line_exists( accounts[ id = input_id ] ).
```

---

## Constants Checklist

**Apply during development:**
- ✅ No magic numbers or strings in code
- ✅ All constants have descriptive names
- ✅ Related constants are grouped (`BEGIN OF`/`END OF`)
- ✅ `ENUM` used for enumerations (ABAP 7.60+)
- ✅ No constants named by value (c_01, c_x)

**Example (WRONG):**
```abap
IF amount > 1000.           " ← Magic number
  status = 'A'.             " ← Magic string
ENDIF.
```

**Example (RIGHT):**
```abap
CONSTANTS:
  BEGIN OF amount_limits,
    high TYPE i VALUE 1000,
  END OF amount_limits.

CONSTANTS status_active TYPE string VALUE 'ACTIVE'.

IF amount > amount_limits-high.
  status = status_active.
ENDIF.
```

---

## Variables Checklist

**Apply during development:**
- ✅ Inline declarations used: `DATA(name) = ...`
- ✅ Variables not used outside declaration block
- ✅ No chained DATA declarations
- ✅ Field symbols only where necessary
- ✅ Appropriate loop targets (field-symbol vs reference vs value)

**Example (WRONG):**
```abap
DATA account TYPE account.
DATA amount TYPE decimalv16_3.
DATA created_by TYPE string.
account = read_account( id ).
amount = account-amount.
```

**Example (RIGHT):**
```abap
DATA(account) = read_account( id ).
DATA(amount) = account-amount.
```

---

## Methods — Parameters Checklist

**Apply during development:**
- ✅ **<= 3 IMPORTING parameters** (split methods if more)
- ✅ No `OPTIONAL` parameters (split methods instead)
- ✅ No `PREFERRED PARAMETER`
- ✅ Exactly one output (`RETURNING`, `EXPORTING`, or `CHANGING`)
- ✅ `RETURNING` preferred to `EXPORTING`
- ✅ Not mixing `RETURNING` with `EXPORTING`/`CHANGING`
- ✅ `CHANGING` used sparingly
- ✅ No boolean input parameters (split method instead)

**Example (WRONG):**
```abap
METHOD process_data
  IMPORTING
    id TYPE string
    account TYPE account
    amount TYPE decimalv16_3
    include_fee TYPE abap_bool OPTIONAL
  EXPORTING
    result TYPE result
    message TYPE string.
```

**Example (RIGHT):**
```abap
METHOD process_account
  IMPORTING
    id TYPE string
    account TYPE account
    amount TYPE decimalv16_3
  RETURNING
    VALUE(result) TYPE result.

METHOD process_with_fee
  IMPORTING
    id TYPE string
    account TYPE account
    amount TYPE decimalv16_3
  RETURNING
    VALUE(result) TYPE result.
```

---

## Methods — Body Checklist

**Apply during development:**
- ✅ Method does **one thing**
- ✅ Method length **<= 20 lines** (ideally 3-5)
- ✅ Focus on happy path OR error handling (not both)
- ✅ One level of abstraction
- ✅ Fail fast pattern used
- ✅ `CHECK` only at start of method
- ✅ `RETURN` used for guards

**Example (WRONG — 40+ lines, mixed concerns):**
```abap
METHOD process_order
  DATA(order) = read_order( order_id ).
  
  CHECK order IS NOT INITIAL.
  
  IF order-status = 'PENDING'.
    DATA(items) = read_order_items( order_id ).
    LOOP AT items INTO DATA(item).
      IF item-quantity > 0.
        DATA(price) = calculate_price( item-id item-quantity ).
        IF price > 10000.
          APPEND calculate_discount( price ) TO discounts.
        ENDIF.
      ENDIF.
    ENDLOOP.
    
    IF discounts IS NOT INITIAL.
      order-total = reduce_by_discounts( order-total discounts ).
    ENDIF.
    
    DATA(payment) = process_payment( order ).
    IF payment-status = 'SUCCESS'.
      order-status = 'PAID'.
    ELSE.
      out->write( payment-error ).
      RETURN.
    ENDIF.
  ENDIF.
  
  update_order( order ).
ENDMETHOD.
```

**Example (RIGHT — small, focused methods):**
```abap
METHOD process_order
  CHECK validate_order( order_id ) = abap_true.
  
  DATA(order) = read_order( order_id ).
  calculate_order_total( order ).
  process_payment( order ).
  update_order( order ).
ENDMETHOD.

METHOD calculate_order_total
  IMPORTING order TYPE order
  DATA(items) = read_order_items( order-id ).
  LOOP AT items INTO DATA(item).
    order-total = order-total + calculate_item_price( item ).
  ENDLOOP.
ENDMETHOD.

METHOD process_payment
  IMPORTING order TYPE order
  DATA(payment) = create_payment( order ).
  IF payment-status NE payment_status-success.
    RAISE EXCEPTION TYPE payment_failed.
  ENDIF.
ENDMETHOD.
```

---

## Classes — Scope Checklist

**Apply during development:**
- ✅ Global classes by default
- ✅ Local classes only where appropriate
- ✅ `FINAL` if not designed for inheritance
- ✅ Members `PRIVATE` by default
- ✅ `PROTECTED` only if needed for inheritance
- ✅ `READ-ONLY` used appropriately (public immutables)

**Example:**
```abap
CLASS account DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    METHODS:
      static create
        IMPORTING id TYPE string
        RETURNING VALUE(result) TYPE REF TO account,
      
      get_balance
        RETURNING VALUE(balance) TYPE decimalv16_3,
      
      deposit
        IMPORTING amount TYPE decimalv16_3.
    
    DATA account_id TYPE string READ-ONLY.
  
  PRIVATE SECTION.
    DATA balance TYPE decimalv16_3.
    DATA created_at TYPE timestamp READ-ONLY.
ENDCLASS.
```

---

## Error Handling Checklist

**Apply during development:**
- ✅ Exceptions used instead of return codes
- ✅ Class-based exceptions (not message classes)
- ✅ `CX_STATIC_CHECK` for manageable errors
- ✅ `CX_NO_CHECK` for unrecoverable errors
- ✅ `RAISE EXCEPTION NEW` instead of `RAISE EXCEPTION TYPE`
- ✅ Foreign exceptions wrapped
- ✅ No catching `CX_ROOT` (too generic)
- ✅ No silent catches

**Example (WRONG):**
```abap
METHOD read_account
  IMPORTING id TYPE string
  RETURNING VALUE(account) TYPE account.
  
  TRY.
    SELECT * FROM database INTO account WHERE id = @id.
  CATCH CX_ROOT.
    " Silently ignore all errors
  ENDTRY.
  
  RETURN account.
ENDMETHOD.
```

**Example (RIGHT):**
```abap
METHOD read_account
  IMPORTING id TYPE string
  RETURNING VALUE(account) TYPE account
  RAISING account_not_found_error.
  
  SELECT * FROM database INTO account WHERE id = @id.
  
  IF account IS INITIAL.
    RAISE EXCEPTION NEW account_not_found_error(
      message = |Account { id } not found|
    ).
  ENDIF.
  
  RETURN account.
ENDMETHOD.
```

---

## Testing Checklist

**Apply during development (before/alongside code):**
- ✅ Code is testable (dependency injection)
- ✅ Public methods have tests
- ✅ Test class names describe purpose
- ✅ Test method names describe scenario
- ✅ Given-When-Then structure used
- ✅ One When per test method
- ✅ Few, focused assertions
- ✅ Right assert type used
- ✅ Content assertions, not quantity
- ✅ No unnecessary test doubles

**Example:**
```abap
CLASS account_test DEFINITION FOR TESTING.
  PRIVATE SECTION.
    DATA account TYPE REF TO account.
    
    METHODS:
      setup FOR TESTING,
      test_deposit_increases_balance FOR TESTING,
      test_deposit_zero_fails FOR TESTING.
ENDCLASS.

CLASS account_test IMPLEMENTATION.
  METHOD setup.
    account = account=>create( id = 'ACC123' ).
    account->deposit( 100 ).
  ENDMETHOD.
  
  METHOD test_deposit_increases_balance FOR TESTING.
    " Given: Account with balance 100
    
    " When: Deposit 50
    account->deposit( 50 ).
    
    " Then: Balance is 150
    cl_abap_unit_assert=>assert_equals(
      EXPORTING
        act = account->get_balance( )
        exp = 150
    ).
  ENDMETHOD.
  
  METHOD test_deposit_zero_fails FOR TESTING.
    " Given: Account
    
    " When: Try to deposit 0
    " Then: Raises exception
    TRY.
      account->deposit( 0 ).
      cl_abap_unit_assert=>fail( 'Should have raised exception' ).
    CATCH invalid_amount_error.
      " Expected
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
```

---

## Priority Assessment

### Critical Issues (Must Fix — Blocks Code Commit)
- Magic numbers without constants
- Deep nesting (>3 levels)
- Methods with >5 parameters
- Multiple output parameters
- Empty IF branches
- Static classes without good reason
- Return codes instead of exceptions
- DEFAULT KEY usage
- Silent exception catching
- Commented-out code in production
- **Naming >30 characters**
- **Hungarian notation**

### Major Issues (Should Fix — Code Review)
- Non-descriptive names
- Long methods (>20 lines)
- Up-front declarations where inline is clearer
- APPEND TO instead of INSERT INTO TABLE
- Old-style READ TABLE
- EXPORTING instead of RETURNING
- Methods doing multiple things
- No interfaces for public methods
- Non-FINAL classes not designed for inheritance

### Minor Issues (Nice to Have — Polish)
- Single quotes instead of backticks for strings
- Unnecessary me-> references
- Concatenation instead of string templates
- RECEIVING keyword usage
- Multiple blank lines
- Minor formatting inconsistencies

---

## Quick Self-Check Before Commit

Run through these before committing code:

```
☐ All variable names are descriptive (no lv_, iv_, etc.)
☐ No naming longer than 30 characters
☐ All methods <= 20 lines (ideally 5-10)
☐ All methods have <= 3 parameters
☐ One RETURNING output per method (no EXPORTING)
☐ No magic numbers (all constants defined)
☐ No empty IF branches or silent catches
☐ Used NEW instead of CREATE OBJECT
☐ Used inline declarations (DATA(x) = ...)
☐ All public methods have unit tests
☐ ATC clean (no warnings)
☐ All exception handling uses class-based exceptions
```

---

## References

- SAP Clean ABAP Style Guide: https://github.com/SAP/styleguides/blob/master/clean-abap/CleanABAP.md
- ABAP Unit Testing: CL_ABAP_UNIT_ASSERT, CL_ABAP_TESTDOUBLE
- Skill: abap-code-review-checklist (for comprehensive 8-section review)


## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
