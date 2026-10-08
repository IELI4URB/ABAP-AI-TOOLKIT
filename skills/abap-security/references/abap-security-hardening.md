---
name: abap-security-hardening
description: 'Harden SAP ABAP Cloud solutions. Use for input validation, SQL injection, dynamic SQL, secrets, communication arrangements, authorization, sensitive data, audit, hashing/encoding, HTTP clients, and security review.'
---

# ABAP Cloud Security Hardening

This guide is self-contained: detailed security controls are inlined below.

## Workflow

1. Identify trust boundaries, inputs, identities, sensitive data, destinations, and audit requirements.
2. Validate input before expensive or privileged work.
3. Use parameterized/static SQL; strictly validate any dynamic tokens.
4. Use communication arrangements/destinations for endpoints and credentials.
5. Apply authorization at data and operation boundaries and test negative paths.

## Gates

Never hardcode secrets, trust UI checks, concatenate untrusted SQL, expose protected data in logs/messages, or recommend unreleased security APIs. Use `abap-iam-authorization` for role/DCL/RAP authorization architecture.


---

## Security Hardening for ABAP Cloud — Comprehensive Guidelines

### Objective

Build secure applications with input validation, authorization checks, secrets management, and audit trails. Prevent SQL injection, privilege escalation, data leaks, and compliance violations.

### SAP Reference & Standards

- ABAP Security Notes: https://help.sap.com/docs/abap-cloud
- ABAP Open SQL Reference: https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- SAP BTP Security Recommendations: https://help.sap.com/docs/btp

Landscape navigation: pair this module with module 17 to apply the correct control depth for Public Cloud, Private Cloud (ABAP Cloud), and BTP ABAP.

### Snippet Execution Labels

- `COMPILE-READY`: ABAP Open SQL and language constructs that are executable with project-specific data elements/types in place.
- `PROJECT-ADAPTED`: technically valid pattern, but class names for secret/token/certificate providers must be replaced with project or platform implementations.
- `CONCEPTUAL`: design intent only; do not copy directly to productive code.

Default rule in this module:
- Security control-flow examples are `COMPILE-READY` patterns.
- Secret provider class names are `PROJECT-ADAPTED` by design.

---

### Critical Security Patterns

#### 1. Input Validation (CRITICAL)

**Anti-Pattern: Trusting User Input**

```abap
" BAD: No validation
METHODS create_travel IMPORTING destination TYPE string.
  INSERT INTO travels (destination) VALUES (destination).
  " Open SQL parameter binding prevents SQL injection here,
  " but invalid business input is still accepted and may break process integrity.
ENDMETHOD.

" Real risk in this pattern: invalid, unexpected, or policy-violating data enters the system.
" SQL injection risk appears primarily when developers build dynamic SQL strings.
```

**Solution: Validate All Input**

```abap
" GOOD: Validate before use
METHODS create_travel IMPORTING destination TYPE string.
  " 1. Length check
  IF strlen( destination ) > 100.
    RAISE EXCEPTION TYPE cx_invalid_input
      EXPORTING message = 'Destination too long (max 100 chars)'.
  ENDIF.
  
  " 2. Character whitelist and business format validation
  " Example: letters, spaces, apostrophe and hyphen only
  IF destination NA 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz -'''.
    RAISE EXCEPTION TYPE cx_invalid_input
      EXPORTING message = 'Destination contains disallowed characters'.
  ENDIF.
  
  " 3. Range validation (only existing countries)
  IF NOT EXISTS( SELECT 1 FROM countries WHERE name = destination ).
    RAISE EXCEPTION TYPE cx_invalid_destination
      EXPORTING message = |Destination '{ destination }' does not exist|.
  ENDIF.
  
  " 4. Canonicalization (normalize before persistence)
  destination = condense( destination ).
  
  " Now safe to use
  INSERT INTO travels (destination) VALUES (destination).
ENDMETHOD.
```

**Validation Decision Matrix**

| Input Type | Validations | Example |
|---|---|---|
| **String/Text** | Length, allowed chars, pattern | destination: max 100, alphanumeric |
| **Number** | Range, type, decimal places | amount: 0-999999, 2 decimals |
| **Date** | Range (not past), format | travel_date: >= today |
| **ID/Key** | Exists in master data | agency_id: must exist in ZAGENCY |
| **Email** | Format, length, domain | regex: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$` |
| **URL** | Format, domain whitelist | https only, trusted domains only |
| **JSON/XML** | Schema validation, encoding | Parse + validate structure |
| **File Upload** | Type check, size limit, scan | .pdf/.doc only, max 10MB, virus scan |

**When to Apply:**
- ✅ ALL external input (OData, REST API, UI)
- ✅ User parameters in queries
- ✅ File uploads
- ✅ Imported data

---

#### 2. SQL Injection Prevention (CRITICAL)

**Anti-Pattern: String Concatenation in Queries**

```abap
" BAD: String concatenation = SQL injection vulnerability
METHODS search_travels IMPORTING destination TYPE string.
  DATA query TYPE string.
  query = 'SELECT * FROM travels WHERE destination = ''' && destination && ''''.
  " If destination = "PARIS'; DELETE FROM travels; --"
  " Query becomes: SELECT * FROM travels WHERE destination = 'PARIS'; DELETE FROM travels; --'
  " Table gets deleted! 💥
  
  EXECUTE IMMEDIATE query INTO TABLE result.
ENDMETHOD.

" GOOD: Use parameterized queries (automatic escaping)
METHODS search_travels IMPORTING destination TYPE string.
  SELECT * FROM travels WHERE destination = destination
    INTO TABLE result.
  " Database automatically escapes special characters
  " Even if destination = "PARIS'; DROP TABLE--", it's treated as literal string
ENDMETHOD.
```

**SQL Injection Prevention Rules**

| Approach | Safe? | Reason |
|---|---|---|
| **Native ABAP SELECT** | ✅ YES | Parameters automatically escaped |
| **CDS Views** | ✅ YES | Parameters bound safely |
| **Dynamic WHERE with parameters** | ✅ YES (if parameterized) | WHERE field IN (param1, param2, ...) |
| **String concatenation** | ❌ NO | Attacker can inject SQL keywords |
| **ABAP SQL (native)** | ✅ YES (ABAP 7.53+) | Parameters bound |

**Safe Pattern: Use ABAP SQL**

```abap
" SAFE: Parameter binding (ABAP 7.53+)
SELECT * FROM travels
  WHERE destination = @destination
    AND status = @status
  INTO TABLE @result.
" @ prefix = bind parameter safely
```

**Don't Do This:**

```abap
" ❌ DANGEROUS: Build WHERE clause with string concatenation
DATA where_clause TYPE string.
where_clause = 'WHERE destination = ''' && user_input && ''''.
SELECT * FROM travels WHERE (where_clause) INTO TABLE result.  " SQL injection!

" ❌ DANGEROUS: EXECUTE IMMEDIATE with concatenation
EXECUTE IMMEDIATE 'SELECT * FROM travels WHERE id = ' && travel_id.

" ❌ DANGEROUS: SET clause with concatenation
UPDATE travels SET status = '' && user_input. 
```

---

#### 3. Authorization Checks (CRITICAL)

**Anti-Pattern: No Authorization Checks**

```abap
" BAD: No authorization, user can access any travel
METHODS get_travel IMPORTING travel_id TYPE travel_id.
  SELECT * FROM travels WHERE id = travel_id
    INTO CORRESPONDING FIELDS OF result.
  RETURN result.
  " Any user can read any travel, even others' private data! 🔓
ENDMETHOD.
```

**Solution: Multi-Level Authorization**

```abap
" GOOD: Global + Instance authorization
METHODS get_travel IMPORTING travel_id TYPE travel_id.
  " 1. Global authorization: Does user have permission to access Travel BO?
  AUTHORITY-CHECK OBJECT 'ZTRAVEL' ID 'ACTVT' FIELD '03'.  " Display
  IF sy-subrc <> 0.
    RAISE EXCEPTION TYPE cx_authorization_error
      EXPORTING message = 'No permission to view travels'.
  ENDIF.
  
  " 2. Read from DB
  SELECT * FROM travels WHERE id = travel_id
    INTO CORRESPONDING FIELDS OF result.
  
  " 3. Instance authorization: Can user access THIS specific travel?
  IF result-owner_id <> sy-uname.
    RAISE EXCEPTION TYPE cx_authorization_denied_instance
      EXPORTING message = |Not authorized for travel { travel_id }|.
  ENDIF.
  
  RETURN result.
ENDMETHOD.
```

**Authorization Checklist**

- [ ] Global check: AUTHORITY-CHECK for object/activity
- [ ] Instance check: User is owner, or in approved group
- [ ] Field-level check: Sensitive fields (cost, salary) hidden or restricted
- [ ] Action-level check: Edit/delete only by owner or approver
- [ ] No bypass via technical user: All code uses normal auth
- [ ] Audit trail: Log who accessed what

**Decision Matrix: When to Add Authorization**

| Data | Level | Example |
|---|---|---|
| **Public data** | None | Airport list, status codes |
| **User data** | Instance | User can view own profile only |
| **Sensitive** | Global + Instance | Travel cost (manager only) |
| **Personal/PII** | Strict | Employee salary, medical records |

---

#### 4. Secrets Management (CRITICAL)

**Anti-Pattern: Hard-Coded Credentials**

```abap
" BAD: Password in source code (NEVER!)
METHODS call_airline_api.
  DATA(api_url) = 'https://api.airline.com'.
  DATA(api_user) = 'myuser'.
  DATA(api_password) = 'MySecretPassword123'.  " 🔓 EXPOSED!
  
  " If code is transported to production, password leaks
  " If source is stolen, password is known
  " If someone reads the code, they have the password
ENDMETHOD.
```

**Solution: Use Secrets from Secure Storage**

```abap
" GOOD: Fetch secrets from secure storage
METHODS call_airline_api.
  " 1. Fetch from SAP Credential Store or environment variable
  DATA(api_url) = cl_bcs_api_config=>get_value( 'AIRLINE_API_URL' ).
  DATA(api_user) = cl_bcs_api_config=>get_value( 'AIRLINE_API_USER' ).
  DATA(api_password) = cl_bcs_api_config=>get_value( 'AIRLINE_API_PASSWORD' ).
  
  " 2. OR: Use OAuth token (temporary, expiring)
  DATA(token) = cl_oauth_provider=>get_token( 'AIRLINE_PROVIDER' ).
  
  " 3. OR: Use mTLS certificate (mutual TLS, no password)
  DATA(cert) = cl_certificate_store=>get_cert( 'AIRLINE_CERT' ).
  
  " 4. Call API with credentials
  result = airline_client->call( url = api_url token = token ).
ENDMETHOD.
```

**Secrets Management Rules**

| Secret Type | Storage | Rotation | Tool |
|---|---|---|---|
| **API passwords** | SAP Credential Store | Every 90 days | /IWFND/CONF_DESTINAT |
| **OAuth tokens** | Token cache (in-memory) | Automatic (expires) | OAuth provider |
| **Certificates (mTLS)** | Certificate store | Every year | SAP PSE |
| **Database passwords** | SAP Credential Store | Every 6 months | /IWFND/CONFIG |
| **API keys** | Environment variables (cloud) | Every 90 days | SAP BTP Secret Manager |

**Never:**
- ❌ Hard-code passwords in source
- ❌ Commit secrets to Git
- ❌ Log passwords
- ❌ Email secrets unencrypted
- ❌ Share via chat/Slack

---

#### 5. Sensitive Data Protection

**Anti-Pattern: Logging Sensitive Data**

```abap
" BAD: Log contains PII
LOG-write( severity = 'INFO' message = |Travel created: { travel } | ).
" travel includes: id, cost, owner_email, credit_card, passport_number
" If logs are accessed by unauthorized user, PII leaks! 🔓
```

**Solution: Mask Sensitive Fields**

```abap
" GOOD: Log only non-sensitive, include business context
LOG-write( severity = 'INFO'
  message = |Travel { travel-id } created by { sy-uname } with destination { travel-destination }| ).
" Non-sensitive: id (anonymized), username (audit), destination (business context)
" Never log: cost, credit card, passport, email, phone

" GOOD: Mask sensitive in error messages
IF payment_failed = abap_true.
  LOG-write( severity = 'ERROR'
    message = |Payment failed for card ending in { card[ -4: ] } - { error_msg }| ).
  " Shows last 4 digits only, masks full card number
ENDIF.
```

**Sensitive Data Classification**

| Data | Sensitivity | Action |
|---|---|---|
| **Travel ID, status** | Low | Log OK |
| **Destination, date** | Low | Log OK |
| **Cost, revenue** | Medium | Mask or restrict |
| **Credit card** | High | Never log, encrypt at rest |
| **Passport number** | High | Never log, encrypt at rest |
| **Email, phone** | Medium | Mask in logs, audit trail only |
| **Password, token** | Critical | Never store, never log |

---

#### 6. Audit Trails (COMPLIANCE)

**Anti-Pattern: No Audit Logging**

```abap
" BAD: User deletes critical data, no trace
METHODS delete_travel IMPORTING travel_id TYPE travel_id.
  DELETE FROM travels WHERE id = travel_id.
  " No record of who deleted it, when, or why!
  " Compliance violation (SOX, GDPR, audit requirements)
ENDMETHOD.
```

**Solution: Log All Sensitive Operations**

```abap
" GOOD: Audit trail for sensitive operations
METHODS delete_travel IMPORTING travel_id TYPE travel_id.
  " Read before delete (to log what was deleted)
  SELECT * FROM travels WHERE id = travel_id
    INTO DATA(old_travel).
  
  " 1. Authorization check (logged automatically by SAP)
  AUTHORITY-CHECK OBJECT 'ZTRAVEL' ID 'ACTVT' FIELD '06'.  " Delete
  IF sy-subrc <> 0.
    RAISE EXCEPTION TYPE cx_authorization_error.
  ENDIF.
  
  " 2. Delete
  DELETE FROM travels WHERE id = travel_id.
  
  " 3. Audit trail: Log change
  INSERT INTO z_audit_log VALUES VALUE #(
    operation = 'DELETE'
    object_type = 'TRAVEL'
    object_id = travel_id
    user = sy-uname
    timestamp = sy-tstmp
    before_value = old_travel  " Full record deleted
    after_value = INITIAL
  ).
ENDMETHOD.
```

**Audit Logging Checklist**

- [ ] Create operation: log new ID, created_by, created_at
- [ ] Update operation: log before/after values, changed_by, changed_at
- [ ] Delete operation: log entire deleted record, deleted_by, deleted_at
- [ ] Sensitive action: log approve/reject/transfer, actor, timestamp
- [ ] Authorization failure: log attempt, user, timestamp, reason
- [ ] Query sensitive data: log query, user, timestamp (read audit)
- [ ] Retention: keep audit log 7 years minimum (compliance)
- [ ] Immutable: audit trail cannot be deleted/modified

---

### Secure Code Patterns

#### Pattern 1: Fail-Secure Error Handling

```abap
" GOOD: Errors are informative but don't leak system details
TRY.
  airline_api->book_flight( travel ).
CATCH cx_api_error INTO DATA(error).
  " Don't expose internal error to user
  LOG-write( severity = 'ERROR' message = |API error: { error->get_text( ) }| ).
  " Tell user generic message
  RAISE EXCEPTION TYPE cx_booking_failed
    EXPORTING message = 'Booking could not be completed. Please contact support.'.
ENDTRY.
```

#### Pattern 2: Rate Limiting & Brute Force Prevention

```abap
" GOOD: Track failed login attempts
DATA(failed_attempts) = get_login_attempts( user = user_input ).
IF failed_attempts >= 5.
  RAISE EXCEPTION TYPE cx_too_many_attempts
    EXPORTING message = 'Too many login attempts. Account locked for 1 hour.'.
ENDIF.

TRY.
  authenticate( user = user_input password = password_input ).
CATCH cx_auth_failed.
  increment_login_attempts( user = user_input ).
  RAISE.
ENDTRY.

" Lock account after 5 failed attempts
reset_login_attempts( user = user_input ).
```

#### Pattern 3: Defense in Depth

```abap
" GOOD: Multiple security layers
METHODS approve_travel_payment IMPORTING travel_id TYPE travel_id.
  " Layer 1: Authentication (user logged in?)
  IF sy-uname = 'NOBODY'.
    RAISE EXCEPTION TYPE cx_not_authenticated.
  ENDIF.
  
  " Layer 2: Global authorization (user is approver?)
  AUTHORITY-CHECK OBJECT 'ZTRAVEL_APPROVE' ID 'ACTVT' FIELD '02'.
  IF sy-subrc <> 0.
    RAISE EXCEPTION TYPE cx_not_authorized.
  ENDIF.
  
  " Layer 3: Instance authorization (approver for this travel?)
  DATA(travel) = get_travel( travel_id ).
  IF travel-assigned_approver <> sy-uname.
    RAISE EXCEPTION TYPE cx_not_assigned_to_travel.
  ENDIF.
  
  " Layer 4: Business rule (is amount within approval limit?)
  DATA(user_limit) = get_approval_limit( sy-uname ).
  IF travel-amount > user_limit.
    RAISE EXCEPTION TYPE cx_amount_exceeds_limit.
  ENDIF.
  
  " Layer 5: Audit & execute
  AUDIT_LOG->write( action = 'APPROVE' travel_id = travel_id ).
  update_travel_status( travel_id = travel_id status = 'APPROVED' ).
ENDMETHOD.
```

---

### Security Checklist

- [ ] All input validated (length, type, range, whitelist)
- [ ] No SQL injection (use parameterized queries, not string concat)
- [ ] Global authorization: AUTHORITY-CHECK for all operations
- [ ] Instance authorization: User can only access own data
- [ ] Sensitive data masked in logs
- [ ] Secrets stored securely (not hard-coded)
- [ ] Audit trail for sensitive operations (create/update/delete)
- [ ] Error messages don't leak system details
- [ ] Rate limiting for repeated operations
- [ ] Defense in depth: Multiple auth layers
- [ ] No bypass for technical users
- [ ] Encryption for data at rest & in transit
- [ ] Regular security review (ATC checks)
- [ ] OWASP Top 10 compliance verified

---

### SAP Security Standards

| Standard | Requirement | How to Verify |
|---|---|---|
| **C1 - Released** | Use only released APIs with auth contracts | ATC check |
| **OWASP Top 10** | Prevent injection, broken auth, sensitive data exposure | Code review |
| **SOX 404** | Change tracking, approval workflows, audit trails | Audit log |
| **GDPR** | Data access logging, retention limits, right to delete | Audit & config |
| **ISO 27001** | Security controls, access management, incident response | ISMS |

