# Emergency Transport Procedure — Resolution Guide

## §5 — Emergency Transport Procedure

**Symptom:** A P1 production incident requires an emergency fix. The standard transport timeline (DEV → QAS → PRD with scheduled import windows) is too slow. Business operations are impacted and a same-day or same-hour fix is required.

**Landscapes:** All.

> ⚠️ **This section describes a process, not a code pattern.** Emergency transports are high-risk. Follow every step. Document everything. Never skip DEV.

---

### Root Cause

Not applicable — this is a response procedure for any production issue requiring accelerated transport.

---

### Diagnosis

| Step | Fiori App | T-Code |
|---|---|---|
| Read runtime error in PRD | N/A | `ST22` (read-only in PRD) |
| Read application log in PRD | **Application Logs** (Fiori) | `SLG1` |
| Check interface / message errors | **Interface Monitor (AIF)** (Fiori) | `AIF` or `/AIF/ERR` |
| Check update task errors | N/A | `SM13` |
| Check RFC errors | N/A | `SM58` |
| Check IDoc errors | N/A | `BD87` |
| Check background job status | **Application Jobs** (Fiori) | `SM37` |

---

### Fix Pattern (Emergency Process — 6 Steps)

#### Step 1 — Diagnose First (Always)

```
NEVER touch any system until you understand the root cause.

Actions (PRD — READ ONLY):
  ST22  → read the dump; note: exception class, program, line, short dump text
  SLG1  → read application logs; filter by: object, subobject, date/time of incident
  SM13  → check for stuck update tasks (symptom: database changes not committed)
  SM58  → check for stuck RFC calls (symptom: remote calls queued/failed)
  AIF   → check interface monitor if the issue involves inbound/outbound interfaces

Goal: Confirm the exact root cause and the exact object(s) that need to change.
      Do NOT proceed to Step 2 until root cause is confirmed.
```

#### Step 2 — Fix in Development System (Non-Negotiable)

```
Rule: NEVER make changes directly in PRD or QAS. No exceptions.
      A direct PRD fix may resolve the symptom today but will be
      overwritten by the next transport and creates version chaos.

Actions in DEV:
  1. Reproduce the issue in DEV (use DEV or a sandbox with similar data)
  2. Apply the fix in DEV
  3. Run ATC locally (ABAP_CLOUD_DEVELOPMENT_DEFAULT)
     → If P1 finding: either fix properly OR request emergency waiver from
       Clean Core approver with explicit justification and time limit
  4. Create an EMERGENCY transport request:
     SE09 → Create → type: Workbench → description: "EMERGENCY: <incident ticket> <date>"
  5. Add ONLY the minimum objects required for the fix — no housekeeping changes
  6. Release the transport from DEV
```

#### Step 3 — Accelerated Testing in QAS

```
Actions in QAS:
  1. Import the emergency transport to QAS immediately
     STMS (QAS) → Import Queue → select transport → Import Now
  2. Execute targeted smoke test:
     → Test ONLY the specific scenario that was failing in PRD
     → Full regression is not required for an emergency transport
     → Document: what was tested, by whom, result
  3. Obtain explicit written approval from the business owner / incident manager
     → Email or incident ticket comment with: "Approved for PRD import — <name> <time>"
  4. If QAS test fails: STOP. Return to Step 2. Do not import to PRD.
```

#### Step 4 — Emergency Import to PRD

```
On-Premise (STMS):
  STMS → PRD import queue → select transport
    └─ Transport → Import → Options:
         └─ ☑ "Schedule Background Job" → uncheck for immediate import
         └─ Import Now → confirm
  Alternative: STMS Express Import (if configured by basis)
    STMS → Express Import → enter transport number → execute

Private Cloud (cTMS):
  → If an emergency lane is configured in cTMS: use it
  → Otherwise: raise an expedited import request with your basis/Cloud Operations team
  → SAP Cloud ALM → Change Management → create emergency change record

Public Cloud (BTP ABAP / Release Management):
  → Managed service: raise an expedited release request via:
    Release Management Fiori app → create release with "Emergency" classification
  → SAP may need to be involved for Managed systems; contact SAP support if needed
```

#### Step 5 — Post-Import Verification (30-Minute Watch)

```
Immediately after import — verify in PRD:
  1. Confirm the fix resolves the original incident
     → Reproduce the failing scenario → confirm it now works
  2. Monitor for 30 minutes:
     ST22  → no new dumps related to the fix
     SLG1  → no new error log entries from the affected objects
     SM13  → no stuck update tasks
     AIF   → no new interface errors (if interfaces were involved)
  3. Notify incident manager: "Fix confirmed in PRD as of <time>"
  4. Keep the incident ticket open for 30 minutes; close only after monitoring period
```

#### Step 6 — Backport and Documentation (Mandatory — Do Not Skip)

```
This step is often neglected under time pressure. It is not optional.

Actions:
  1. Merge-back to main branch (if using gCTS/Git-based development):
     → Ensure the emergency fix commit is merged into the main development branch
     → A fix that exists only in PRD will be overwritten by the next regular transport

  2. Document the incident (in your incident management system):
     ┌─────────────────────────────────────────────────────────┐
     │ Root cause:        <exact technical cause>              │
     │ Fix applied:       <what was changed, transport number> │
     │ DEV transport:     <transport request number>           │
     │ QAS tested by:     <name, time>                        │
     │ PRD approved by:   <name, role, time>                  │
     │ PRD import time:   <timestamp>                         │
     │ Verified by:       <name, time>                        │
     │ ATC exemptions:    <if any — exemption ID, expiry>     │
     └─────────────────────────────────────────────────────────┘

  3. Create regression test:
     → Write an automated ATC/unit test or integration test that would
       have caught this issue before it reached PRD
     → Add to the standard test suite so it runs on every future transport

  4. Review and close ATC exemptions:
     → If an emergency waiver was granted, set a calendar reminder for
       the waiver expiry date to ensure the proper fix is implemented
```

---

### Landscape Notes

**On-Premise Emergency Tools:**

| Tool | T-Code | Use Case |
|---|---|---|
| Update Records | `SM13` | Cancel or restart stuck update tasks (e.g., posting stuck mid-flight) |
| RFC Error Log | `SM58` | View and reprocess stuck asynchronous RFC calls |
| IDoc Reprocessing | `BD87` | Reprocess failed inbound/outbound IDocs after fix is in place |
| ABAP Dump Analysis | `ST22` | Read and analyse runtime errors in PRD |
| Application Log | `SLG1` | Read structured application logs |
| System Log | `SM21` | Low-level system events and kernel errors |
| Job Monitor | `SM37` | Cancel or restart background jobs |
| Express Import | `STMS` | Bypass import schedule for emergency transport |

**Public Cloud Emergency Tools:**

| Tool | Fiori App / Service | Use Case |
|---|---|---|
| Application Logs | **Application Logs** | Structured error logs — equivalent to `SLG1` |
| Interface Monitor | **Interface Monitor (AIF)** | Reprocess failed interface messages |
| Application Jobs | **Application Jobs** | Cancel stuck jobs; restart failed jobs |
| Release Management | **Release Management** | Expedited transport lane for emergencies |
| ABAP Test Cockpit | **ABAP Test Cockpit** | Manage emergency ATC exemptions |
| System Monitor | **System Monitoring (Cloud ALM)** | Real-time system health during and after fix |

---

### Prevention

- Define and publish an **Emergency Transport Runbook** before you ever need it — not during an incident.
- Pre-configure an **emergency import lane** in cTMS / STMS so the mechanism is ready and tested.
- Designate an **emergency transport approver** (business + technical) per system — named individuals, not just roles.
- Run **post-incident reviews** after every emergency transport: identify what process or test gap allowed the issue to reach PRD and close it.
- Instrument PRD with proactive monitoring (Cloud ALM, SAP Focused Run, or custom `SLG1`-based alerting) so incidents are detected before the business reports them.
- Treat emergency transports as **architectural debt signals**: two emergency transports in the same area within one quarter means a deeper design or test coverage problem needs to be solved.
