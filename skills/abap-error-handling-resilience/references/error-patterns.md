# Error Handling & Resilience — Enterprise Patterns

## Objective

Design robust error handling, graceful degradation, and recovery strategies. Prevent cascading failures and ensure system stability under stress.

## Prerequisites

- ABAP exception model and RAP message/reporting basics.
- Integration flow context from module 10 for retry and idempotency alignment.
- Observability requirements from module 12 for diagnosable failure handling.

## SAP Reference & Standards

- ABAP Exception Handling Reference: https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- ABAP Cloud Programming Model: https://help.sap.com/docs/abap-cloud
- RAP Error Reporting Patterns: https://help.sap.com/docs/abap-cloud/abap-rap

---

## Exception Hierarchy Design

**Anti-Pattern: Catch All, Lose Context**

```abap
" BAD: Single generic exception, no context
TRY.
  process_travel( travel ).
CATCH cx_error.  " Catches everything, lose details
  LOG-write( message = 'Error' ).  " No context!
ENDTRY.
```

**Solution: Structured Exception Hierarchy**

```abap
" Define clear exception hierarchy
CLASS cx_travel_error DEFINITION INHERITING FROM cx_static_check.
  PUBLIC SECTION.
    METHODS constructor IMPORTING message TYPE string.
    DATA message TYPE string READ-ONLY.
ENDCLASS.

" Specific exceptions for different error types
CLASS cx_invalid_travel DEFINITION INHERITING FROM cx_travel_error.
ENDCLASS.

CLASS cx_travel_not_found DEFINITION INHERITING FROM cx_travel_error.
ENDCLASS.

CLASS cx_booking_failed DEFINITION INHERITING FROM cx_travel_error.
ENDCLASS.

CLASS cx_payment_declined DEFINITION INHERITING FROM cx_travel_error.
ENDCLASS.

" Usage: Specific handling per error
TRY.
  book_travel( travel ).
CATCH cx_invalid_travel INTO DATA(e).
  LOG-write( severity = 'WARNING' message = |Validation failed: { e->message }| ).
  RAISE EXCEPTION TYPE cx_invalid_input EXPORTING message = e->message.
CATCH cx_travel_not_found INTO e.
  LOG-write( severity = 'INFO' message = |Travel not found| ).
  RAISE EXCEPTION TYPE cx_not_found.
CATCH cx_payment_declined INTO e.
  LOG-write( severity = 'ERROR' message = |Payment failed: { e->message }| ).
  RAISE EXCEPTION TYPE cx_booking_failed.
CATCH cx_travel_error INTO e.
  LOG-write( severity = 'ERROR' message = |Unexpected travel error: { e->message }| ).
  RAISE.
ENDTRY.
```

**Exception Decision Matrix**

| Error Type | Exception Class | Action | User Message |
|---|---|---|---|
| **Invalid input** | cx_invalid_* | Reject, don't retry | "Invalid date format" |
| **Not found** | cx_not_found | 404, don't retry | "Travel not found" |
| **Unauthorized** | cx_not_authorized | 401/403, don't retry | "Not authorized" |
| **Network timeout** | cx_timeout_error | Retry, backoff | (Transparent, retry) |
| **API rate limit** | cx_rate_limited | Retry, backoff | (Transparent, retry) |
| **Temporary server error** | cx_temporary_error | Retry, backoff | (Transparent, retry) |
| **Business rule violation** | cx_business_rule_violation | Reject, inform user | "Amount exceeds limit" |

---

## Error Handling Patterns

### Pattern 1: Try-Catch-Retry-Circuit Breaker

```abap
" Full resilience stack
METHODS call_external_api IMPORTING params TYPE params.
  DATA(max_retries) = 3.

  TRY.
    external_api->execute( params ).
    RETURN.
  CATCH cx_timeout_error cx_rate_limited cx_temporary_error INTO DATA(temp_error).
    IF params-retry_count < max_retries.
      schedule_retry(
        payload = params
        retry_count = params-retry_count + 1
        next_run_at = add_seconds( sy-tstmp, 2 ** params-retry_count )
      ).
      RETURN.
    ENDIF.
    RAISE EXCEPTION TYPE cx_api_unavailable
      EXPORTING message = |Retry limit reached: { temp_error->get_text( ) }|.
  CATCH cx_permanent_error INTO DATA(perm_error).
    LOG-write( severity = 'ERROR' message = |Permanent API error: { perm_error->message }| ).
    RAISE EXCEPTION TYPE cx_api_error
      EXPORTING message = |Request failed permanently: { perm_error->message }|.
  CATCH cx_circuit_breaker_open.
    LOG-write( severity = 'WARNING' message = 'API circuit breaker open' ).
    RAISE EXCEPTION TYPE cx_api_unavailable.
  ENDTRY.
ENDMETHOD.
```

### Pattern 2: Graceful Degradation

```abap
" App works even if external service is down
METHODS get_travel_with_fallback IMPORTING travel_id TYPE travel_id.
  TRY.
    " Try to fetch enhanced data from external AI service
    DATA(recommendation) = ai_service->get_recommendation( travel_id ).
    travel-recommendation = recommendation.
  CATCH cx_api_error.
    " AI service down: show default recommendation
    LOG-write( severity = 'WARNING' message = 'AI service unavailable, using default' ).
    travel-recommendation = 'Popular destination, good reviews'.
  ENDTRY.
  
  " Core travel data always available
  SELECT * FROM travels WHERE id = travel_id INTO travel.
  RETURN travel.
ENDMETHOD.

" User still gets travel info, just without AI recommendation
" No cascade failure
```

### Pattern 3: Bulkhead Isolation

```abap
" Separate resource pools prevent one slow service from blocking others
CLASS zcl_api_client.
  CONSTANTS payment_timeout TYPE integer VALUE 10.  " seconds
  CONSTANTS airline_timeout TYPE integer VALUE 5.
  CONSTANTS notification_timeout TYPE integer VALUE 3.
  
  METHODS process_travel.
    TRY.
      " Payment: high priority, longer timeout
      call_with_runtime_limit(
        operation = 'PAYMENT'
        timeout_seconds = payment_timeout
        payload = VALUE #( amount = amount )
      ).
    CATCH cx_timeout_error.
      " Payment timeout is critical, fail
      RAISE.
    ENDTRY.
    
    TRY.
      " Airline: medium priority, medium timeout
      call_with_runtime_limit(
        operation = 'AIRLINE_BOOK'
        timeout_seconds = airline_timeout
        payload = VALUE #( destination = destination )
      ).
    CATCH cx_timeout_error.
      " Airline timeout is acceptable, queue for retry
      queue_for_retry( ).
    ENDTRY.
    
    TRY.
      " Notification: low priority, short timeout
      call_with_runtime_limit(
        operation = 'NOTIFICATION'
        timeout_seconds = notification_timeout
        payload = VALUE #( )
      ).
    CATCH cx_timeout_error.
      " Notification timeout is acceptable, queue for retry
      queue_async_notification( ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

" Each service has its own timeout, doesn't block others
```

---

## Failure Recovery Strategies

### Strategy 1: Automatic Compensation

```abap
" If operation fails partway, undo what was done
METHODS book_travel_with_compensation IMPORTING travel_id TYPE travel_id.
  TRY.
    " Step 1: Create booking
    booking_id = airline_api->create_booking( travel_id ).
    ROLLBACK.  " Save point
    
    " Step 2: Process payment
    payment_ref = payment_api->charge( amount ).
    ROLLBACK.  " Save point
    
    " Step 3: Send confirmation
    email_service->send_confirmation( travel_id ).
    
    COMMIT.  " All success
  
  CATCH cx_booking_failed INTO DATA(e1).
    ROLLBACK.  " Undo create_booking
    RAISE EXCEPTION TYPE cx_booking_error.
  
  CATCH cx_payment_declined INTO DATA(e2).
    ROLLBACK.  " Undo payment
    airline_api->cancel_booking( booking_id ).  " Compensation: cancel airline booking
    RAISE EXCEPTION TYPE cx_payment_error.
  
  CATCH cx_notification_failed INTO DATA(e3).
    " Partial success: booking and payment done, notification failed
    " Queue notification for retry
    queue_for_retry( ).
    " Don't fail the entire transaction
  ENDTRY.
ENDMETHOD.
```

### Strategy 2: Retry Fallback

```abap
" If API fails, use cached version
METHODS get_data_with_fallback IMPORTING key TYPE string.
  TRY.
    " Try fresh data from API
    result = api->fetch( key ).
    " Update cache
    cache->set( key = key value = result ).
  CATCH cx_api_error INTO DATA(error).
    LOG-write( severity = 'WARNING' message = |API failed: { error->message }| ).
    
    " Try cache
    result = cache->get( key ).
    IF result IS INITIAL.
      " Cache miss too, fail
      RAISE EXCEPTION TYPE cx_data_unavailable.
    ENDIF.
    " Return cached version (may be stale, but better than nothing)
  ENDTRY.
  
  RETURN result.
ENDMETHOD.
```

### Strategy 3: Eventual Consistency (Accept Delay)

```abap
" Don't require synchronous consistency, accept eventual sync
METHODS create_travel_async.
  " Step 1: Create travel immediately (fast)
  INSERT INTO travels VALUES travel.
  
  " Step 2: Async sync to other systems (eventual)
  queue_async_job( job_name = 'SYNC_TRAVEL' params = travel ).
  
  " User gets immediate response, sync happens in background
  " If sync fails, retry job automatically
ENDMETHOD.
```

---

## Observability for Resilience

### Pattern 1: Structured Logging

```abap
" Log errors with full context
METHODS process_with_logging.
  DATA(operation_id) = generate_uuid( ).  " Correlation ID
  
  TRY.
    LOG-write(
      severity = 'INFO'
      message = |Starting travel processing|
      correlation_id = operation_id
    ).
    
    process_travel( travel ).
    
    LOG-write(
      severity = 'INFO'
      message = |Travel { travel-id } processed successfully|
      correlation_id = operation_id
      duration_ms = get_elapsed_time( )
    ).
  
  CATCH cx_error INTO DATA(error).
    LOG-write(
      severity = 'ERROR'
      message = |Travel processing failed: { error->message }|
      correlation_id = operation_id
      error_code = error->code
      travel_id = travel-id
      user = sy-uname
    ).
    RAISE.
  ENDTRY.
ENDMETHOD.
```

### Pattern 2: Health Checks

```abap
" Monitor external dependencies
INTERFACE if_health_check.
  METHODS check RETURNING VALUE(status) TYPE health_status.  " OK, DEGRADED, DOWN
ENDINTERFACE.

CLASS zcl_airline_api_health DEFINITION FINAL.
  INTERFACES if_health_check.
ENDCLASS.

CLASS zcl_airline_api_health IMPLEMENTATION.
  METHOD if_health_check~check.
    TRY.
      airline_api->health_check( ).  " Lightweight ping
      status = 'OK'.
    CATCH cx_timeout_error.
      status = 'DEGRADED'.  " Slow but working
    CATCH cx_api_error.
      status = 'DOWN'.  " Not working
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

" Usage: Dashboard shows API health
METHODS get_system_health.
  DATA(airline_status) = zcl_airline_api_health=>check( ).
  DATA(payment_status) = zcl_payment_api_health=>check( ).
  
  IF airline_status = 'DOWN'.
    system_status = 'DEGRADED'.  " Some functionality unavailable
  ELSE.
    system_status = 'HEALTHY'.
  ENDIF.
ENDMETHOD.
```

---

## Resilience Checklist

- [ ] Exception hierarchy defined (specific exception classes)
- [ ] Retry logic for transient errors (exponential backoff)
- [ ] Timeout configured (don't wait forever)
- [ ] Circuit breaker for flaky APIs
- [ ] Bulkhead isolation (separate resource pools)
- [ ] Graceful degradation (app works even if API down)
- [ ] Compensation logic for partial failures
- [ ] Fallback strategy (cache, default value)
- [ ] Dead letter queue for failed jobs
- [ ] Structured logging with correlation IDs
- [ ] Health checks for external dependencies
- [ ] Monitoring alerts for failures
- [ ] Incident runbooks documented
- [ ] Load testing for resilience validation