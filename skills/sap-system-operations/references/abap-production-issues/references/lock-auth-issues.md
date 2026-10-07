# Lock Conflicts and Authorization Issues — Production Resolution Guide

---

## §1 — ENQUEUE_FAILED (Lock Conflict)

**Exception / Symptom:** `CX_SY_NO_HANDLER` raised when enqueue call fails; or `ENQUEUE_FAILED` message; or function module `ENQUEUE_*` returns `LOCKED` return code. User cannot save a document; "Document is locked by user X"; concurrent edit conflicts.

**Landscapes:** All

---

### Root Cause

| # | Cause |
|---|-------|
| A | Another user or background process holds the same lock |
| B | Previous process crashed without releasing lock — orphaned lock |
| C | Lock object not matching the document key correctly |
| D | Deadlock (two processes locking objects in different order) |

---

### Diagnosis

| Fiori App | T-Code | Action |
|-----------|--------|--------|
| Lock Monitor (if available) | **SM12** | List all active locks → identify who holds the lock → can release manually if the owning process is confirmed dead |
| *(no cloud equivalent for SM12)* | — | In Public Cloud: check if the user session that created the lock is still active; escalate to system admin if lock is orphaned |

> **Note:** SM12 is OnPrem/Private Cloud only. Public Cloud does not expose SM12; use the Lock Monitor Fiori app if configured, or admin APIs.

---

### Fix Pattern

**Fix A — Retry with exponential backoff for transient locks:**

```abap
DATA lv_retry TYPE i.
DATA lv_locked TYPE abap_bool VALUE abap_true.

WHILE lv_locked = abap_true AND lv_retry < 5.
  CALL FUNCTION 'ENQUEUE_EZTRAVEL'
    EXPORTING  travel_id    = lv_travel_id
               _scope       = '2'
    EXCEPTIONS foreign_lock = 1
               system_lock  = 2
               OTHERS       = 3.
  IF sy-subrc = 0.
    lv_locked = abap_false.
  ELSE.
    lv_retry += 1.
    WAIT UP TO ipow( base = 2 exponent = lv_retry ) SECONDS.  " 2, 4, 8, 16, 32 sec
  ENDIF.
ENDWHILE.

IF lv_locked = abap_true.
  RAISE EXCEPTION TYPE zcx_document_locked
    EXPORTING locked_by = lv_locked_by.
ENDIF.
```

**Fix B — Release orphaned lock (OnPrem only):**
`SM12` → find the lock entry → **Delete** (only if you are certain the owning process is dead).
Public Cloud: Escalate to system admin; use admin APIs if available.

**Fix C — RAP managed scenario:**
Locks are managed automatically by the RAP framework. Do **not** use `ENQUEUE_*` function modules directly in RAP-managed business objects. Use pessimistic locking via the behavior definition instead.

---

### Landscape Notes

| Landscape | Notes |
|-----------|-------|
| **Public Cloud** | `ENQUEUE_*` FMs are **NOT released** for ABAP Cloud. Use RAP pessimistic lock defined in the behavior definition (`with lock`). |
| **Private Cloud / OnPrem** | Classic `ENQUEUE_*` FMs are still available in the Standard ABAP tier alongside RAP. |

---

### Prevention

- Prefer RAP managed locking for new development — the framework handles enqueue/dequeue lifecycle automatically.
- For classic ABAP, always pair every `ENQUEUE_*` call with a corresponding `DEQUEUE_*` in a `CLEANUP` or `FINAL` section to prevent orphaned locks on crash.
- Standardize lock object key fields to match the document key exactly — mismatches cause silent lock failures.
- Monitor lock table size via SM12 / equivalent periodically in batch-heavy systems.

---

## §2 — RAP Draft Lock / "Object Already Being Edited"

**Exception / Symptom:** User sees "Object is already being edited" or "Draft locked by \<user\>". Cannot open a Fiori object for edit; draft exists but the original user is gone (closed browser tab, session timeout, network drop).

**Landscapes:** ☁️ Public Cloud, 🔒 Private Cloud (RAP with draft enabled)

---

### Root Cause

User navigated away, closed the browser tab, or the session timed out before the draft was explicitly discarded. The draft record and its associated lock remain in the draft table, blocking any other user (or the same user in a new session) from opening the object in edit mode.

---

### Diagnosis

| Fiori App | T-Code / Tool | Action |
|-----------|---------------|--------|
| **Draft Administration** (if configured) | — | View all active drafts → identify stale entries by user / timestamp → delete |
| — | **ADT** | Query draft table directly (e.g., `Z*_D` or SAP-standard draft table) for the locked entry and its `LASTCHANGEDATETIME` |
| — | **EML / BOPF** | Read draft administrative data programmatically to identify owner and age of draft |

---

### Fix Pattern

**Fix A — Programmatic draft discard (admin or background job use only):**

```abap
MODIFY ENTITIES OF ZI_TravelTP
  ENTITY Travel
  EXECUTE Discard
  FROM VALUE #( ( %is_draft    = if_abap_behv=>mk-on
                  TravelID     = lv_travel_id ) )
  FAILED   DATA(lt_failed)
  REPORTED DATA(lt_reported).

IF lt_failed IS INITIAL.
  COMMIT ENTITIES.
ENDIF.
```

> ⚠️ Only execute this from a trusted admin program or scheduled cleanup job — never expose it to end users without authorization protection.

**Fix B — Enable admin discard via the Draft Administration Fiori app:**

```abap
" In the Behavior Definition (BDEF):
managed implementation in class zbp_i_traveltp unique;
with draft;
manage with draft;  " enables the Draft Administration Fiori app
```

**Fix C — Set draft expiry to prevent accumulation:**
Configure draft garbage collection in Customizing (`SPRO`) or via Fiori Draft Administration settings. A common policy is to expire drafts after 24–48 hours of inactivity.

---

### Landscape Notes

| Landscape | Notes |
|-----------|-------|
| **Public Cloud** | Draft table is managed by the RAP framework. Direct SQL access to draft tables is restricted; always use EML for programmatic interaction. |
| **Private Cloud / OnPrem** | Direct database access to draft tables is technically possible but strongly discouraged; use EML or BOPF APIs. |

---

### Prevention

- Set session timeout shorter than draft expiry so the draft is cleaned up before another user is blocked for an extended period.
- Educate users to always use the explicit **Discard** button rather than closing the browser tab.
- Schedule a periodic draft cleanup background job using the programmatic discard pattern (Fix A) for drafts older than a configurable threshold.
- Implement a `before_modify` check in the behavior implementation that warns if a draft was last changed more than N hours ago.

---

## §3 — Database Deadlock (DBIF_RSQL_SQL_ERROR)

**Exception / Symptom:** `CX_SY_OPEN_SQL_DB` with message text containing `"deadlock"`, `ORA-00060` (Oracle), or a HANA deadlock error code. Intermittent document save failures under concurrent load; not reproducible with a single user in isolation.

**Landscapes:** All

---

### Root Cause

Two concurrent processes attempt to acquire row-level database locks in opposite orders, creating a circular dependency. The database engine detects the cycle and forcibly rolls back one of the transactions (the "deadlock victim"), which surfaces as a short dump in ABAP.

**Classic scenario:**

| Step | Process A | Process B |
|------|-----------|-----------|
| 1 | Locks row: Order **1** ✅ | Locks row: Order **2** ✅ |
| 2 | Tries to lock: Order **2** ⏳ | Tries to lock: Order **1** ⏳ |
| 3 | ← circular wait → | ← circular wait → |
| 4 | DB kills one process | Short dump: `DBIF_RSQL_SQL_ERROR` |

---

### Diagnosis

| Fiori App | T-Code / Tool | Action |
|-----------|---------------|--------|
| — | **ST22** | Short dump analysis → look for `"deadlock"` in the error text → note exact timestamp and both transaction IDs involved |
| — | **HANA Studio / HANA Cockpit** | SQL Performance Analysis → Deadlock trace → identify the two competing statements |
| — | **SM21** | System log → filter for DB error messages at the same timestamp |

---

### Fix Pattern

**Principle:** Prevent the circular dependency by enforcing a consistent lock acquisition order, and recover gracefully via retry when a deadlock does occur.

```abap
DATA lv_retry TYPE i.
DO 3 TIMES.
  lv_retry += 1.
  TRY.
      perform_critical_update( ).
      EXIT.  " success — leave the loop
    CATCH cx_sy_open_sql_db INTO DATA(lx_db).
      IF lx_db->get_text( ) CS 'deadlock' AND lv_retry < 3.
        WAIT UP TO 1 SECONDS.
        CONTINUE.  " retry the entire operation
      ELSE.
        RAISE EXCEPTION lx_db.  " non-deadlock DB error or retry exhausted
      ENDIF.
  ENDTRY.
ENDDO.
```

**Structural fixes to eliminate the root cause:**

| Fix | Description |
|-----|-------------|
| **A — Consistent lock ordering** | Always acquire locks on multiple rows in the **same order** across all code paths (e.g., sort by primary key ascending before updating in a loop). |
| **B — Minimize lock duration** | Lock → update → commit in the tightest possible sequence. Avoid user interaction or external service calls while holding DB locks. |
| **C — SELECT FOR UPDATE** | Where applicable, use database-native row locking rather than application-level ENQUEUE locks to let the DB manage contention natively. |
| **D — Retry on deadlock** | Implement the retry pattern above; HANA deadlock detection is extremely fast (sub-millisecond), so the first retry almost always succeeds. |

---

### Landscape Notes

| Landscape | Notes |
|-----------|-------|
| **SAP HANA (all cloud variants)** | HANA's deadlock detection runs in milliseconds — a single retry with a 1-second wait succeeds in the vast majority of real-world cases. |
| **OnPrem (non-HANA)** | Oracle (`ORA-00060`) and DB2 deadlock detection latency varies; tune retry wait time accordingly. Check DB-specific error codes when inspecting `lx_db->get_text()`. |

---

### Prevention

- Code review checklist: any routine that updates multiple rows in a loop must sort the input set by primary key before iterating.
- Performance tests with realistic concurrency (at least 10 simultaneous users on the same document range) should be part of the test strategy for any batch-intensive feature.
- Set up HANA Cockpit deadlock alerts to detect recurring patterns before they become production incidents.

---

## §4 — AUTHORITY-CHECK sy-subrc = 4 in Production

**Exception / Symptom:** Not a thrown exception — `sy-subrc = 4` after `AUTHORITY-CHECK`; user receives an authorization error message. User can perform the action in the test system but not in production, or only a subset of users is affected.

**Landscapes:** All

---

### Root Cause

| # | Cause |
|---|-------|
| A | Role is missing the required authorization object entirely |
| B | Role contains the object but with an incorrect field value (e.g., activity `03 = Display` granted, but code requires `02 = Change`) |
| C | Cloud restriction type set too narrowly (e.g., restricted to one company code when the user needs all) |
| D | Role assigned to test/dev user but not transported to or assigned in the production system |

---

### Diagnosis

| Fiori App | T-Code | Step | Action |
|-----------|--------|------|--------|
| *(not standard)* | **SU53** | 1 — OnPrem first response | Run **immediately** after the failed action, in the same session. Shows the last failed authorization check: object name, field, value needed vs. value held by the user. |
| *(not standard)* | **ST01** | 2 — OnPrem hard-to-reproduce | `ST01 → Trace → Authorization Check → Activate` → reproduce the error → deactivate → analyze trace log. |
| **Maintain Business Roles** | — | 3 — Public Cloud | Check that the correct business role is assigned to the user; verify restriction type values match the data scope required. |
| **Display Business Catalogs** | — | 4 — Public Cloud | Confirm the catalog containing the relevant app and OData service is included in the role. |

---

### Fix Pattern

**Role fix — OnPrem (PFCG):**
`PFCG` → open the role → **Authorizations** tab → add the missing authorization object with the correct field values → generate the profile → transport the role to production.

**Role fix — Public Cloud:**
`Maintain Business Roles` → open the role → add the required business catalog → adjust restriction type values to grant the necessary scope.

**Code pattern — raise a meaningful error rather than silently failing:**

```abap
AUTHORITY-CHECK OBJECT 'ZTRAVEL'
  ID 'ZAGENCY' FIELD ls_travel-agency_id
  ID 'ACTVT'   FIELD '02'.  " 02 = Change

IF sy-subrc <> 0.
  " Option 1 — classic ABAP: raise a typed exception
  RAISE EXCEPTION TYPE cx_sy_no_authority
    EXPORTING object_name = 'ZTRAVEL'.

  " Option 2 — RAP behavior implementation: populate REPORTED
  " APPEND VALUE #(
  "   %msg = new_message_with_text(
  "     severity = if_abap_behv_message=>severity-error
  "     text     = 'You are not authorized to change this travel booking'
  "   )
  " ) TO reported-travel.
ENDIF.
```

---

### Landscape Notes

| Landscape | Notes |
|-----------|-------|
| **OnPrem / Private Cloud** | SU53 and ST01 are the primary diagnostic tools. PFCG manages roles and authorization profiles. Transport roles via standard CTS. |
| **Public Cloud** | No PFCG; authorization is managed through the IAM / Business Role framework. CDS DCL (access control) also contributes to data visibility — a user may pass `AUTHORITY-CHECK` but still see no data if the DCL role is not granted. |

---

### Prevention

- Maintain a **dedicated integration-test user** in every landscape who holds only the target business role(s) — never the developer or administrator role. Run all acceptance tests with this user.
- Include authorization testing as a mandatory step in the transport checklist: verify SU53 is clean for the test user after every role change.
- In RAP, prefer `@ObjectModel.authorizationCheck` annotations combined with CDS DCL so authorization is enforced consistently at the data model layer.

---

## §5 — IAM / Business Role Issues (Cloud-Specific)

**Exception / Symptom:** User sees empty Fiori tile groups; app loads but displays no data; action buttons (Edit, Create, Delete) are missing or disabled; navigation to sub-object pages fails silently.

**Landscapes:** ☁️ Public Cloud only (Business Role framework)

---

### Root Cause

| # | Cause |
|---|-------|
| A | Business catalog not assigned to the user's business role |
| B | Restriction type value set too narrowly (e.g., `CompanyCode = ''` or a single value when the user needs all) |
| C | CDS DCL access control role not granting access — `pfcg_auth` aspect requires correct authorization object values in the role |
| D | IAM app activation pending — new service binding or app not yet published to the Fiori Launchpad |

---

### Diagnosis

| Fiori App | Step | Action |
|-----------|------|--------|
| **Maintain Business Roles** | 1 | Open the user's assigned role → verify the correct business catalog is included |
| **Display Business Catalogs** | 2 | Confirm the catalog references the correct app ID and activated OData / EML service binding |
| **Maintain Restriction Types** | 3 | Check restriction values — look for overly narrow restrictions (blank values, single org unit) |
| *(ADT — CDS source)* | 4 | Review `@AccessControl.authorizationCheck` annotation and the associated DCL source; verify `pfcg_auth` aspect maps to the correct authorization object |
| *(ADT — Service Binding)* | 5 | Confirm the service binding is in **Active** state and referenced correctly in the business catalog configuration |

---

### Fix Pattern

**Fix A — Isolate DCL from AUTHORITY-CHECK (development systems only):**

```abap
" DEV ENVIRONMENT ONLY — revert before transporting to test or production
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZC_Travel
  as select from ZI_Travel
{
  key TravelID,
  AgencyID,
  CustomerID
}
```

> ⚠️ **Never transport `#NOT_REQUIRED` to a production system.** Use this only in a sandbox to isolate the problem.

**Fix B — Correct role restriction values:**

```
Maintain Business Roles
  → [Select Role]
  → Restriction Values
    → [Expand the relevant restriction type]
    → Set value to "Unrestricted" or add the required specific values
  → Save
```

---

### Landscape Notes

| Topic | Detail |
|-------|--------|
| **Launchpad cache** | After role changes, instruct the user to clear browser cache and log out/in. Fiori Launchpad caches tile visibility aggressively. |
| **IAM app objects** | Every activated service binding generates a corresponding IAM app object. If the binding is re-created, the IAM app must be re-assigned to the catalog manually. |
| **CDS DCL propagation** | Access control is evaluated at the CDS view layer. A projection view that selects from a base view with DCL will inherit the restriction — check both layers. |
| **Restriction type `#UNRESTRICTED` vs. blank** | Setting a restriction type to "Unrestricted" is not the same as leaving it blank. A blank value may be interpreted as "no value matches" by certain restriction type implementations. |

---

### Prevention

- Maintain a **business-role-only test user** (no developer privileges) in every non-production cloud system. After every transport, verify this user can open the app, see data, and execute all relevant actions.
- Document the mapping of each service binding → business catalog → business role in the solution design; include it in the transport checklist.
- Add CDS DCL review to the code review checklist: confirm `@AccessControl.authorizationCheck: #CHECK` is set on all production-bound CDS entities.
- Include the **IAM App** object explicitly in transport requests — it is a separate object type from the service binding and is sometimes missed.

---

*End of guide — 5 issues documented.*
