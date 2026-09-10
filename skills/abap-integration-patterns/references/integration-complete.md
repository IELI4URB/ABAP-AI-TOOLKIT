# Integration Patterns for ABAP Cloud — Async, Events, Idempotency

## Objective

Design reliable, decoupled integrations with external systems. Handle failures gracefully, ensure idempotency, and maintain eventual consistency.

## SAP Reference & Standards

- SAP BTP Integration Guidance: https://help.sap.com/docs/btp
- ABAP Cloud Extensibility Guidance: https://help.sap.com/docs/abap-cloud
- SAP API Management Overview: https://help.sap.com/docs

Landscape navigation: check module 17 first to choose the right integration execution model for Public Cloud, Private Cloud (ABAP Cloud), and BTP ABAP.

## Snippet Execution Labels

- `COMPILE-READY`: ABAP control-flow and Open SQL patterns that compile after binding to local dictionary types/interfaces.
- `PROJECT-ADAPTED`: valid architecture pattern where helper functions (for example JSON mapping, UUID generation, queue orchestration) must be replaced by project implementations.
- `CONCEPTUAL`: reference pattern only.

Default rule in this module:
- Outbox, retry, and circuit-breaker flows are `PROJECT-ADAPTED` unless explicitly tied to concrete project interfaces.
- Idempotency and error-decision matrices are `COMPILE-READY` logic patterns.

---

## Critical Integration Anti-Patterns

### 1. Synchronous Coupling (BLOCKING)

**Anti-Pattern: Wait for External API**

```abap
" BAD: Synchronous call blocks user
METHODS create_travel IMPORTING destination TYPE string.
  " 1. Create travel
  INSERT INTO travels VALUES travel.
  
  " 2. Call external airline API (synchronous, blocks)
  DATA(booking) = airline_api->book_flight( destination ).
  " User waits 5-10 seconds if API is slow or down! 😞
  
  " 3. If API fails, entire transaction fails
  " User sees error, travel creation rolled back
ENDMETHOD.
```

**Problem:**
- User waits for external system (bad UX)
- If airline API is down, travel creation fails
- Response time = travel create + airline booking (slow)
- Cascading failures (one API down = all dependent services fail)

**Solution 1: Asynchronous with Event**

```abap
" GOOD: Fire-and-forget with async processing
METHODS create_travel IMPORTING destination TYPE string RETURNING VALUE(travel_id) TYPE travel_id.
  " 1. Create travel (fast, synchronous)
  INSERT INTO travels VALUES travel RETURNING INTO travel_id.
  
  " 2. Write integration outbox record for async worker
  INSERT INTO z_integration_outbox VALUES VALUE #(
    event_id = generate_uuid( )
    event_type = 'TRAVEL_CREATED'
    payload = to_json( VALUE #( travel_id = travel_id destination = destination ) )
    status = 'NEW'
    created_at = sy-tstmp
  ).
  " Returns immediately to user, external calls are deferred
  
  RETURN travel_id.
ENDMETHOD.

" 3. Background worker handles booking (asynchronous)
CLASS zcl_outbox_worker.
  METHODS process_new_events.
    SELECT * FROM z_integration_outbox
      WHERE status = 'NEW'
      INTO TABLE @DATA(lt_events).

    LOOP AT lt_events INTO DATA(ls_event).
      DATA(ls_payload) = from_json( ls_event-payload ).
    TRY.
      airline_api->book_flight( ls_payload-destination ).
      UPDATE z_integration_outbox
        SET status = 'DONE'
        WHERE event_id = @ls_event-event_id.
    CATCH cx_api_error INTO DATA(error).
      " If airline API fails, keep for retry worker
      UPDATE z_integration_outbox
        SET status = 'RETRY'
            retry_count = retry_count + 1
            last_error = error->get_text( )
        WHERE event_id = @ls_event-event_id.
    ENDTRY.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
```

**Solution 2: Synchronous Entry with Asynchronous Recovery**

```abap
" Alternative: keep user flow synchronous and defer recovery to retry workers
METHODS create_travel_with_timeout.
  INSERT INTO travels VALUES travel.
  
  TRY.
    DATA(booking) = airline_api->book_flight( destination ).
    travel-booking_status = 'CONFIRMED'.
  CATCH cx_api_error INTO DATA(error).
    travel-booking_status = 'PENDING'.
    enqueue_retry_job(
      operation = 'BOOK_FLIGHT'
      payload = VALUE #( travel_id = travel-id destination = destination )
      retry_count = 0
    ).
    LOG-write( severity = 'WARNING' message = |Airline booking deferred: { error->get_text( ) }| ).
  ENDTRY.
  
  UPDATE travels SET booking_status = travel-booking_status.
ENDMETHOD.
```

**Decision Matrix: Synchronous vs Asynchronous**

| Scenario | Pattern | Why |
|---|---|---|
| **Payment (critical, must succeed)** | Synchronous + retry | Can't create order without payment |
| **Notification (non-critical)** | Asynchronous (event) | User gets travel immediately, email sent later |
| **Audit logging** | Asynchronous (queue) | Log doesn't block user |
| **Data sync (eventual consistency)** | Asynchronous (event + listener) | Sync happens in background |
| **Analytics/BI update** | Asynchronous (batch job) | Can wait hours |

---

### 2. Missing Idempotency (Duplicate Calls)

**Anti-Pattern: No Idempotency Key**

```abap
" BAD: No way to detect duplicate calls
METHODS create_travel IMPORTING destination TYPE string.
  INSERT INTO travels VALUES travel.
  
  airline_api->book_flight( destination ).
  " If network fails after booking but before response,
  " caller thinks it failed and retries
  " Airline API creates DUPLICATE booking! 💥
ENDMETHOD.

" Scenario:
" Call 1: Create travel → booking created → network fails
" Caller timeout, assumes failure
" Call 2: Retry → DUPLICATE booking created
```

**Solution: Idempotency Key**

```abap
" GOOD: Use idempotency key (external ID)
METHODS create_travel IMPORTING destination TYPE string.
  " 1. Generate idempotency key (uniquely identifies this operation)
  DATA(idempotency_key) = generate_uuid( ).  " UUID or {timestamp}-{user}-{travel_id}
  
  " 2. Check if already processed
  IF EXISTS( SELECT 1 FROM z_airline_bookings 
    WHERE idempotency_key = idempotency_key ).
    RETURN get_existing_booking( idempotency_key ).
  ENDIF.
  
  " 3. Create travel
  INSERT INTO travels VALUES travel.
  
  " 4. Call API with idempotency key
  DATA(booking) = airline_api->book_flight(
    destination = destination
    idempotency_key = idempotency_key  " API returns same result if called twice
  ).
  
  " 5. Store result with key
  INSERT INTO z_airline_bookings VALUES VALUE #(
    idempotency_key = idempotency_key
    travel_id = travel-id
    booking_id = booking-id
  ).
ENDMETHOD.

" Retry scenario:
" Call 1: Create travel, booking created, store key → network fails
" Caller retries
" Call 2: Key exists → return cached booking (no duplicate!)
```

**Idempotency Implementation Options**

| Method | Pros | Cons | Use Case |
|---|---|---|---|
| **External ID (UUID)** | Simple, works anywhere | Must match API format | REST APIs, SFTP |
| **Request fingerprint (hash)** | Auto-deduplicates identical requests | Complex to match on API side | SOAP, internal APIs |
| **Distributed cache (Redis)** | Fast dedup | Extra infrastructure | High-volume APIs |
| **Database unique constraint** | Guaranteed at DB level | Slower, eventual consistency | Guaranteed dedup |

---

### 3. No Retry Logic (Transient Failures)

**Anti-Pattern: Fail on First Error**

```abap
" BAD: No retry on transient failures
METHODS sync_with_external_system.
  TRY.
    airline_api->sync_travels( lt_travels ).
  CATCH cx_api_error.
    " Network blip = permanent failure? No retry!
    RAISE.  " User gets error, data not synced
  ENDTRY.
ENDMETHOD.

" Network timeout (transient) → treated as permanent failure
" User retries manually → same error
" Data inconsistency grows
```

**Solution: Exponential Backoff with Job Rescheduling**

```abap
" GOOD: Retry by queue/job orchestration to avoid blocking worker threads
METHODS process_sync_job IMPORTING job TYPE zsync_job.
  DATA(max_retries) = 3.

  TRY.
    airline_api->sync_travels( job-payload ).
    mark_job_success( job-id ).
  CATCH cx_timeout_error cx_temporary_error INTO DATA(temp_error).
    IF job-retry_count < max_retries.
      DATA(next_delay_seconds) = 2 ** job-retry_count.  " 1,2,4
      reschedule_job(
        job_id = job-id
        retry_count = job-retry_count + 1
        next_run_at = add_seconds( sy-tstmp, next_delay_seconds )
      ).
    ELSE.
      move_to_dlq( job-id, temp_error->get_text( ) ).
    ENDIF.
  CATCH cx_permanent_error INTO DATA(perm_error).
    move_to_dlq( job-id, perm_error->get_text( ) ).
  ENDTRY.
ENDMETHOD.
```

**Retry Decision Matrix**

| Error Type | Retry? | Reason |
|---|---|---|
| **Network timeout** | ✅ YES | Transient, may succeed next time |
| **API rate limit (429)** | ✅ YES | Retry after delay |
| **Temporary error (5xx)** | ✅ YES | Server recovering |
| **Permanent error (400/401)** | ❌ NO | Won't change on retry |
| **Not found (404)** | ❌ NO | Resource doesn't exist |
| **Unauthorized (403)** | ❌ NO | Auth failed, won't fix by retry |

---

### 4. No Dead Letter Queue (Failed Jobs Lost)

**Anti-Pattern: No DLQ, Jobs Disappear**

```abap
" BAD: Job fails, no trace
DATA(job) = schedule_async_job( 'sync_travels' ).
job->execute( ).
" If job fails (API down, data error), job is lost
" No one knows it failed, data not synced
```

**Solution: Dead Letter Queue**

```abap
" GOOD: Failed jobs go to DLQ
CLASS zcl_travel_sync_job.
  METHODS execute.
    TRY.
      airline_api->sync_travels( lt_travels ).
    CATCH cx_sync_error INTO DATA(error).
      " Job failed, move to DLQ
      INSERT INTO z_sync_dlq VALUES VALUE #(
        job_id = me->job_id
        job_name = 'SYNC_TRAVELS'
        error_message = error->get_text( )
        error_count = 1
        next_retry_time = cl_abap_tstmp=>add( sy-tstmp SECONDS 3600 )  " Retry in 1 hour
        payload = lt_travels  " Store data for retry
      ).
      
      " Alert ops team
      send_alert( message = |Travel sync failed: { error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

" DLQ monitoring:
SELECT * FROM z_sync_dlq WHERE error_count > 3 AND next_retry_time <= sy-tstmp
  INTO TABLE lt_dlq_items.

" Manual retry or auto-retry
LOOP AT lt_dlq_items INTO DATA(item).
  TRY.
    airline_api->sync_travels( item-payload ).
    DELETE FROM z_sync_dlq WHERE job_id = item-job_id.
  CATCH cx_error.
    " Still failing, increment retry count
    UPDATE z_sync_dlq SET error_count = item-error_count + 1.
  ENDTRY.
ENDLOOP.
```

---

## Event-Driven Integration Patterns

### Pattern 1: Event Publishing (Domain Events)

```abap
" Define outbox event record to decouple producer/consumer
DEFINE TABLE z_integration_outbox (
  event_id UUID,
  event_type STRING,
  payload STRING,
  status STRING,
  retry_count INT4,
  created_at TIMESTAMP
).

" Write outbox entry when travel created
METHODS create_travel IMPORTING destination TYPE string.
  INSERT INTO travels VALUES travel.
  
  INSERT INTO z_integration_outbox VALUES VALUE #(
    event_id = generate_uuid( )
    event_type = 'TRAVEL_CREATED'
    payload = to_json( VALUE #( travel_id = travel-id destination = destination ) )
    status = 'NEW'
    retry_count = 0
    created_at = sy-tstmp
  ).
ENDMETHOD.

" Worker-specific handlers react independently
CLASS zcl_airline_booking_worker.
  METHODS handle IMPORTING event_payload TYPE string.
    DATA(event) = from_json( event_payload ).
    airline_api->book_flight( event-destination ).
  ENDMETHOD.
ENDCLASS.

CLASS zcl_notification_worker.
  METHODS handle IMPORTING event_payload TYPE string.
    DATA(event) = from_json( event_payload ).
    email->send( to = event-creator_email subject = 'Travel created' ).
  ENDMETHOD.
ENDCLASS.

" Benefits:
" ✅ Decoupled: Travel doesn't depend on airline or notification
" ✅ Extensible: Add new listener without modifying travel code
" ✅ Async: Each listener processes independently
" ✅ Resilient: If one fails, others continue
```

### Pattern 2: Event Sourcing (Store All Changes)

```abap
" Instead of storing current state only, store all events
DEFINE TABLE z_travel_events (
  event_id UUID,
  travel_id UUID,
  event_type STRING,  " CREATED, APPROVED, BOOKED, CANCELLED
  event_data JSON,    " Full event details
  created_by STRING,
  created_at TIMESTAMP
).

" When anything happens, append event
METHODS create_travel.
  INSERT INTO travels VALUES travel.
  INSERT INTO z_travel_events VALUES VALUE #(
    event_id = generate_uuid( )
    travel_id = travel-id
    event_type = 'CREATED'
    event_data = travel->to_json( )
    created_by = sy-uname
    created_at = sy-tstmp
  ).
ENDMETHOD.

" Replay events to reconstruct state
METHODS get_travel_history IMPORTING travel_id TYPE travel_id.
  SELECT * FROM z_travel_events WHERE travel_id = travel_id
    ORDER BY created_at
    INTO TABLE lt_events.
  
  DATA(travel) = INITIAL.
  LOOP AT lt_events INTO DATA(event).
    CASE event-event_type.
      WHEN 'CREATED'.
        travel = event-event_data->from_json( ).
      WHEN 'APPROVED'.
        travel-status = 'APPROVED'.
      WHEN 'CANCELLED'.
        travel-status = 'CANCELLED'.
    ENDCASE.
  ENDLOOP.
  
  RETURN travel.
ENDMETHOD.

" Benefit: Complete audit trail, can replay to any point in time
```

---

## Integration Resilience Patterns

### Pattern 1: Circuit Breaker

```abap
" Track API failures, stop calling when threshold reached
CLASS zcl_airline_api_circuit_breaker.
  CONSTANTS max_failures TYPE integer VALUE 5.
  CONSTANTS timeout TYPE integer VALUE 300.  " seconds
  
  DATA state TYPE string VALUE 'CLOSED'.  " CLOSED, OPEN, HALF_OPEN
  DATA failure_count TYPE integer VALUE 0.
  DATA last_failure_time TYPE timestamp.
  
  METHODS call IMPORTING params TYPE params RETURNING VALUE(result) TYPE result.
    CASE state.
      WHEN 'OPEN'.
        " Circuit open: stop calling, check if ready to try
        IF ( sy-tstmp - last_failure_time ) > timeout.
          state = 'HALF_OPEN'.  " Try again
        ELSE.
          RAISE EXCEPTION TYPE cx_circuit_breaker_open.
        ENDIF.
      
      WHEN 'HALF_OPEN'.
        " Try one call
        TRY.
          result = airline_api->call( params ).
          state = 'CLOSED'.  " Success, close circuit
          failure_count = 0.
        CATCH cx_api_error.
          state = 'OPEN'.  " Failed again, reopen
          last_failure_time = sy-tstmp.
        ENDTRY.
      
      WHEN 'CLOSED'.
        " Normal operation
        TRY.
          result = airline_api->call( params ).
        CATCH cx_api_error.
          failure_count += 1.
          last_failure_time = sy-tstmp.
          IF failure_count >= max_failures.
            state = 'OPEN'.  " Too many failures, open circuit
          ENDIF.
          RAISE.
        ENDTRY.
    ENDCASE.
  ENDMETHOD.
ENDCLASS.

" Usage
TRY.
  circuit_breaker->call( params ).
CATCH cx_circuit_breaker_open.
  " API is down, don't overwhelm it
  LOG-write( message = 'Airline API circuit open, skipping call' ).
ENDTRY.
```

### Pattern 2: Timeout & Bulkhead

```abap
" Isolate slow operations, don't block entire app
METHODS call_airline_with_isolation.
  DATA(worker_result) = integration_worker->execute_with_limit(
    operation = 'BOOK_FLIGHT'
    timeout_seconds = 5
    payload = VALUE #( destination = destination )
  ).
  IF worker_result-status = 'TIMEOUT' OR worker_result-status = 'FAILED'.
    queue_for_retry( destination ).
    RETURN initial.
  ENDIF.
  
  " Bulkhead: partition workers by integration domain (queue isolation)
  " Example domains: AIRLINE_API, PAYMENT_API, NOTIFICATION
  " One congested queue must not starve other outbound integrations.
  enqueue_worker_queue(
    queue_name = 'AIRLINE_API'
    payload = VALUE #( destination = destination )
  ).
ENDMETHOD.
```

---

## Integration Checklist

- [ ] Identify synchronous vs asynchronous dependencies
- [ ] Async for non-critical operations (notifications, logging)
- [ ] Sync for critical operations (payments), but with timeout
- [ ] Idempotency key for all mutations
- [ ] Retry logic with exponential backoff
- [ ] Dead letter queue for failed jobs
- [ ] Circuit breaker for flaky external APIs
- [ ] Timeout configured (don't wait forever)
- [ ] Bulkhead isolation (separate resource pools)
- [ ] Error handling doesn't leak sensitive data
- [ ] Audit trail for all integration calls
- [ ] Monitoring alerts for failures
- [ ] Graceful degradation (app works even if API down)
- [ ] Eventual consistency acknowledged (sync will happen later)