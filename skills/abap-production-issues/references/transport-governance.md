# Transport and Governance Issues — Production Resolution Guide

> **Scope:** ABAP-based landscapes — Public Cloud (BTP ABAP Environment), Private Cloud Edition, and On-Premise S/4HANA.
> **Audience:** ABAP developers, basis administrators, and release managers responding to transport or governance incidents.
> **How to use:** Jump to the relevant `§N` section. Each section follows a consistent Diagnosis → Fix → Prevention flow.

---

## §1 — ATC P1 / P2 Finding Blocking Transport

**Exception / Symptom:** ATC (ABAP Test Cockpit) finding blocks transport release or pipeline promotion. The `ABAP_CLOUD_DEVELOPMENT_DEFAULT` check set raises a P1 or P2 violation. Developer cannot release the transport request; CI/CD pipeline fails at the quality gate.

**Landscapes:** All (mandatory and non-bypassable in Public Cloud; configurable severity in Private Cloud / On-Premise).

---

### Root Cause

ATC enforces the *Clean Core* contract for ABAP Cloud. The check set `ABAP_CLOUD_DEVELOPMENT_DEFAULT` validates that only C1-released APIs, correct language version constructs, and RAP-compliant patterns are used. A P1 finding means the violation is critical; the transport pipeline (gCTS, cTMS, or ABAP Git-based delivery) will refuse to promote the request until the finding is resolved or a valid exemption is granted.

**Common P1 findings and their root causes:**

| Finding | Root Cause |
|---|---|
| Use of unreleased API (class, FM, BAPI) | Developer used SAP internal API without checking release state |
| Direct `SELECT` from SAP standard table (e.g., `AFKO`, `VBAK`) | Should use a released CDS view instead |
| `EXEC SQL` / `EXECUTE IMMEDIATE` | Forbidden in ABAP Cloud language version |
| `COMMIT WORK` inside a RAP behavior class | Violates RAP transactional model; use `COMMIT ENTITIES` |
| Language version incompatibility | Object compiled as Standard ABAP but assigned to ABAP Cloud package |
| Access to obsolete/deprecated class | API was deprecated; replacement exists |

---

### Diagnosis

| Step | Fiori App | T-Code / Tool |
|---|---|---|
| Open ATC result overview | **ABAP Test Cockpit** (Fiori launchpad tile) | `ATC` |
| Read finding detail and example fix | ABAP Test Cockpit → open finding → **Show Example Fix** button | `ATC` → finding → F4 help |
| Check exemption status of finding | ABAP Test Cockpit → **Manage Exemptions** | `ATC` → Exemptions view |
| Navigate to source location | ADT (Eclipse) → ATC Results view → double-click finding | N/A (ADT only) |
| Check release state of a specific object | ADT → right-click class/FM → **Properties** → *Release State* tab | `SE80` → object → Display → Properties |
| Browse released alternatives | ADT → **Released Objects** browser (CTRL+SHIFT+A → filter by `Released`) | N/A (ADT browser) |
| Find migration path for unreleased API | **Cloudification Repository Viewer** (external SAP tool: [https://cxp.sap.com/cloudification](https://cxp.sap.com/cloudification)) | N/A |

**ADT: Checking release state of a class**
```
ADT (Eclipse)
  └─ Project Explorer → navigate to class
       └─ Right-click → Properties
            └─ Tab: "ABAP" → field "Release State"
                 Values: Released (C1) | Deprecated | Not Released | Internal
```

---

### Fix Pattern

#### Fix A — Replace Unreleased API with Released Alternative

1. Note the unreleased API name from the ATC finding.
2. In ADT: open **Released Objects** browser → search by functional area keyword.
3. Cross-reference with the **Cloudification Repository Viewer** for the official migration path.
4. Replace usage in code and re-run ATC locally before releasing transport.

```abap
" ❌ BEFORE — direct access to unreleased SAP table
SELECT SINGLE aufnr, auart
  FROM aufk
  INTO @DATA(ls_order)
  WHERE aufnr = @lv_order_number.

" ✅ AFTER — use the released CDS view
SELECT SINGLE ManufacturingOrder, ManufacturingOrderType
  FROM I_ManufacturingOrder
  INTO @DATA(ls_order)
  WHERE ManufacturingOrder = @lv_order_number.
```

```abap
" ❌ BEFORE — COMMIT WORK inside RAP behavior class (P1 violation)
COMMIT WORK.

" ✅ AFTER — use RAP-compliant transactional commit
COMMIT ENTITIES
  RESPONSE OF zi_my_entity
  FAILED   DATA(lt_failed)
  REPORTED DATA(lt_reported).
```

```abap
" ❌ BEFORE — unreleased UTC class
DATA(lv_timestamp) = cl_abap_context_info=>get_system_date( ).  " internal / unverified

" ✅ AFTER — released XCO framework
DATA(lo_moment) = xco_cp_time=>moment(
  iv_year   = xco_cp_time=>year( sy-datum(4) )
  iv_month  = xco_cp_time=>month( sy-datum+4(2) )
  iv_day    = xco_cp_time=>day( sy-datum+6(2) )
).
```

#### Fix B — Request ATC Exemption (Emergency / Justified Exception)

Use only when a released alternative does not yet exist or when a time-boxed exception is genuinely required.

**On-Premise / Private Cloud (transaction `ATC`):**
```
ATC → Results → select finding → right-click → Request Exemption
  ├─ Reason:       "No released alternative available until <date>" (be specific)
  ├─ Validity:     Set explicit end date (max 90 days recommended)
  └─ Approver:     Route to your Clean Core approver / architect
```

**Public Cloud (Fiori — ABAP Test Cockpit):**
```
ABAP Test Cockpit → Manage Exemptions → Create
  ├─ Object:       <your class / FM name>
  ├─ Check:        ABAP_CLOUD_DEVELOPMENT_DEFAULT / specific check ID
  ├─ Justification: Mandatory — describe why exemption is needed
  ├─ Valid Until:   Set date — exemptions without end date are rejected by audit
  └─ Approver:      Clean Core champion or line manager
```

> ⚠️ **Exemptions are not technical bypasses.** They are time-limited waivers tracked in the system. Expired exemptions re-block the transport automatically.

---

### Landscape Notes

| Landscape | P1 Behaviour | Bypass Possible? | Exemption Mechanism |
|---|---|---|---|
| **Public Cloud (BTP ABAP)** | Always blocks transport release — enforced by platform | ❌ No bypass | ABAP Test Cockpit → Manage Exemptions |
| **Private Cloud Edition** | Typically blocks; depends on pipeline configuration | ⚠️ Configurable by basis | ATC transaction + approval workflow |
| **On-Premise S/4HANA** | Configurable; project governance defines enforcement | ✅ Configurable waivers | ATC transaction → Request Exemption |

---

### Prevention

- Configure `ABAP_CLOUD_DEVELOPMENT_DEFAULT` as a **mandatory pre-release check** in your CI/CD pipeline (gCTS hook or ABAP Git pre-push check).
- Run ATC locally in ADT **before every transport release** — configure ADT to auto-run on save for Cloud packages.
- Add an architecture guardrail: every new external dependency must be reviewed in the ADT Released Objects browser **before** coding begins.
- Schedule monthly ATC sweep runs across all custom packages to catch drift.
- Maintain a team-internal *Approved API Catalogue* — a curated list of confirmed C1-released APIs for your functional domain.

---

## §2 — Activation Error After Transport Import

**Exception / Symptom:** Transport import completes without a hard error (return code 0 or 4 in STMS) but the transported object is **inactive** in the target system. Calling the class/function at runtime results in `CX_SY_NO_HANDLER`, `CLASS_NOT_FOUND`, or a syntax error dump in `ST22`. The object appears to exist in SE80/ADT but has no active version.

**Landscapes:** All.

---

### Root Cause

| Root Cause | Description |
|---|---|
| **A — Missing dependency** | A referenced class, interface, type, or CDS view was not included in the transport; the object cannot activate because its dependency is unresolved in the target |
| **B — Merge conflict** | The object was independently modified in the target system (e.g., a hotfix); the imported version conflicts with local state |
| **C — Activation sequence issue** | Class pool or local type defined in a sequence that the compiler cannot resolve (inner class used before its definition in the same include) |
| **D — Wrong import order** | Transport B references an object created by Transport A, but B was imported before A; the reference is unresolvable at activation time |

---

### Diagnosis

| Step | Fiori App | T-Code / Tool |
|---|---|---|
| Check active/inactive state of object | N/A | `SE80` → object → icon: green = active, grey/yellow = inactive |
| Check active/inactive state in ADT | ADT → Project Explorer → object icon overlay | ADT (Eclipse) |
| Read transport activation log | N/A | `STMS` → double-click transport → **Transport Log** → filter step "Activation" |
| Read transport log (Public Cloud) | **Manage Software Components** or **Release Management** | N/A |
| Find all inactive objects in package | N/A | `SE80` → Edit → **Activate → All Inactive Objects in Package** |
| Check where-used for dependencies | ADT → right-click object → **Where Used** | `SE80` → right-click → Where Used (or `WHERE_USED_LIST`) |
| Identify objects in a transport | N/A | `SE03` → Search in Transport Requests → object name |
| Check transport return code | N/A | `STMS` → Transport Log → RC column (0=OK, 4=warning, 8=error) |

**Reading the activation log in STMS:**
```
STMS
  └─ Import Queue (target system)
       └─ Double-click transport request
            └─ Tab: "Transport Log"
                 └─ Expand step: "Activation of Repository Objects"
                      └─ Read error messages — note: object name + activation error text
```

---

### Fix Pattern

#### Fix A — Missing Dependency (Most Common Cause)

Identify every object that the inactive object depends on, verify they are all present and active in the target, and retransport anything missing.

```abap
" Step 1: In ADT — right-click the inactive class → Where Used
"         Note every class, interface, CDS view, type group it references

" Step 2: For each referenced object, check if it exists and is active in target:
"         SE80 → navigate to object → check active flag

" Step 3: In DEV — create a new transport; add all missing dependencies:
"         SE09 → create correction request → add objects manually

" Step 4: Import the dependency transport FIRST, then re-import the original
```

**SE03 — Find which transport contains a specific object:**
```
SE03
  └─ Search in Requests/Tasks → Object Name: <class name>
       └─ Identifies all transports that contain the object
            └─ Verify the correct transport was imported in target
```

#### Fix B — Wrong Import Order

```
STMS (target system)
  └─ Import Queue
       └─ Sort transports by creation date (ascending)
            └─ Import in strict chronological order
                 └─ If queue is already mixed: use "Import All" with
                    "Ignore Non-Transportable Objects" = No
                    "Overwrite Originals" = Yes (with basis approval)
```

If the queue order cannot be corrected, create a **consolidation transport** in DEV:
```
SE09 → create new Workbench request
  └─ Add ALL objects from both conflicting transports into this single new request
       └─ This guarantees a single atomic import with correct internal activation order
```

#### Fix C — Manual Activation After Import

```abap
" Option 1: Activate a single object
" SE80 → navigate to inactive object → Activate button (or F8)

" Option 2: Activate all inactive objects in a package
" SE80 → Edit → Activate → All Inactive Objects in Package → <package name>

" Option 3: Mass activation via report (On-Premise)
" SA38 / SE38 → report SGEN → generate all objects in system
"   (use after large transports importing many objects)

" Option 4: ADT — right-click inactive object → Activate
```

> ⚠️ **If manual activation fails with a syntax error:** do NOT attempt to edit in the target system. Fix the root cause in DEV, retransport, and re-import. Direct modification in QAS/PRD breaks the transport chain.

#### Fix D — Object Active but Runtime Error Persists

If the object shows as active but `ST22` still dumps at runtime, the active version in the target may be a *stale* compiled version. Force recompilation:

```abap
" SE38 / SA38 — run report RS_REFRESH_FROM_FILESYSTEM
" Or: reactivate the specific class pool:
" SE24 → open class → Activate (this recompiles the full class pool including all methods)
```

---

### Landscape Notes

| Landscape | Transport Mechanism | Activation Behaviour | Key Tool |
|---|---|---|---|
| **Public Cloud (BTP ABAP)** | ABAP Git / cTMS (managed) | Activation is automatic on import; failures visible in transport log | **Manage Software Components** Fiori app → log tab |
| **Private Cloud Edition** | cTMS or gCTS | Automatic activation; RC 8 = activation failed | STMS → Transport Log |
| **On-Premise** | STMS | Automatic activation; can fall back to manual `SE80` / `SGEN` | `SE80`, `SA38` → `SGEN`, `SE03` |

**Public Cloud — reading activation failure:**
```
Manage Software Components (Fiori)
  └─ Select software component
       └─ Transport Requests tab
            └─ Select failed request
                 └─ "Import Log" → expand "Activation" phase
                      └─ Error text identifies the specific object and reason
```

---

### Prevention

- Define **transport dependency rules** in your development process: every transport must include all objects created or changed in the same logical unit of work.
- Use **ADT Where Used** as a mandatory pre-release checklist step.
- In gCTS-based landscapes, use **branch-per-feature** — merging a complete branch guarantees all related objects travel together.
- After large transport waves, run `SE80 → Activate All Inactive Objects` as a post-import health check step.
- Integrate a post-import activation check into your pipeline: RC > 4 on activation step = block promotion.

---

## §3 — Downgrade Check Failure

**Exception / Symptom:** STMS blocks import with error: *"Downgrade check failed"* or *"Object version in target system is newer than in transport"*. The transport sits in the import queue with return code 8. The object version number in the target system is higher than the version being transported in.

**Landscapes:** On-Premise, Private Cloud Edition. (Public Cloud manages object versioning through Git-based delivery and does not use the STMS downgrade check in the same way.)

---

### Root Cause

Every ABAP Repository object carries an internal version counter. STMS compares the version of the object in the transport against the version currently active in the target system. If the target already has a higher version number, importing would **overwrite a newer state with an older one** — a downgrade.

| Scenario | Description |
|---|---|
| **A — Parallel development** | Two developers modified the same object in DEV; developer 1 transported first; developer 2's transport now carries the older pre-merge version |
| **B — Emergency fix in higher system** | A hotfix was applied directly in QAS or PRD (violating the no-edit-in-target rule); target version is now ahead of DEV |
| **C — Wrong source system** | Transport was created in a sandbox or secondary DEV system that was not synchronised with the main DEV landscape |
| **D — Reimport of old transport** | An old, previously superseded transport is being reimported after a refresh or system copy |

---

### Diagnosis

| Step | Fiori App | T-Code |
|---|---|---|
| Read downgrade error detail | N/A | `STMS` → Import Queue → double-click transport → **Transport Log** → expand error |
| Check current object version in target | N/A | `SE80` (in target) → object → Display → Version history (Utilities → Versions) |
| Check version in transport | N/A | `SE03` → Display Transport Objects → select transport → display object |
| Find all transports touching an object | N/A | `SE03` → Search in Requests/Tasks → object name |
| Compare object versions across systems | N/A | `SE80` → Utilities → **Version Management** → compare system versions |

**Reading the downgrade message in STMS:**
```
STMS (target system)
  └─ Import Queue
       └─ Double-click the blocked transport (RC = 8)
            └─ Transport Log
                 └─ Phase: "Check import conditions"
                      └─ Error: "Object <name> — version in target (<vX>) is newer
                                 than version in transport (<vY>). Import blocked."
                                 Note the object name and both version numbers.
```

**Checking version history in SE80:**
```
SE80 (run in the TARGET system)
  └─ Navigate to the blocked object
       └─ Utilities → Versions → Version Management
            └─ List of all versions with: version number, date, transport request
                 └─ Confirm which transport/date created the "newer" version
```

---

### Fix Pattern

#### Fix A — Correct Approach: Merge and Retransport

This is the only correct resolution in almost all cases.

```
Step 1: Identify the content difference
  SE80 (DEV) → object → Utilities → Versions → Compare with:
    Option A: Download the object from the target system using RFC compare
    Option B: Use ADT → right-click → Compare With → System Version in QAS/PRD

Step 2: In DEV — incorporate the newer target-system changes
  - If target had a hotfix: replicate that fix into DEV manually
  - If parallel development: merge both sets of changes into one version in DEV
  - Activate and test in DEV

Step 3: Release a new transport from DEV
  SE09 → release the transport with the merged, up-to-date version

Step 4: Import the new transport to target
  STMS → import the new transport → downgrade check now passes because
  DEV version >= target version
```

#### Fix B — Keep Target Version (Your Transport is Obsolete)

If investigation confirms the target already contains the correct and complete fix:

```
STMS (target system)
  └─ Import Queue
       └─ Select the conflicting transport
            └─ Transport → Set Status → "Transport Obsolete" (or equivalent skip flag)
                 └─ Document reason in transport description field
                      └─ Do NOT delete — keep for audit trail
```

Ensure the content of the skipped transport is reviewed: if it contained additional changes beyond the downgraded object, those changes need to be extracted and retransported separately.

#### Fix C — Force Import (Use Only with Basis Team Approval)

Only use as a last resort when you are absolutely certain the transport version is correct and the target version is wrong (e.g., the target has a corrupted or erroneous version).

```
STMS (target system — basis administrator only)
  └─ Import Queue
       └─ Select transport
            └─ Transport → Options
                 └─ ☑ "Ignore Non-Transportable Objects" — leave default
                    ☑ "Overwrite Originals" — set if needed
                    ☑ "Ignore Downgrade Check" — only with explicit architect sign-off
            └─ Execute import
```

> ⚠️ **Force import is a last resort.** It bypasses a safety mechanism and can overwrite changes that were correctly in production. Always get written approval from the basis/release manager and document the decision.

---

### Landscape Notes

| Landscape | Downgrade Check | Notes |
|---|---|---|
| **Public Cloud (BTP ABAP)** | Not applicable in STMS sense | Git-based delivery; conflicts surfaced as merge conflicts in the Git repository; resolve via standard Git merge |
| **Private Cloud Edition** | Active in cTMS | Same resolution as On-Premise; escalate to SAP Basis for force-import scenarios |
| **On-Premise** | Active in STMS | Full fix/force-import options available to basis administrator |

---

### Prevention

- **Never modify objects directly in QAS or PRD.** This is the single biggest cause of downgrade failures. All changes must originate in DEV.
- Implement a **transport lock policy**: only the object owner may release a transport containing a given object; parallel transports on the same object require coordinator sign-off.
- Use **feature branches** in gCTS-based systems: parallel development on the same object is resolved at the Git merge level before a transport is even created.
- After any emergency fix in a higher system (which should be exceptional), immediately create a **remediation transport** in DEV to synchronise the version counter.
- Configure STMS to send automatic notifications when a downgrade check failure occurs, so the responsible developer is alerted immediately.

---

## §4 — Clean Core Violation After Transport (Released API)

**Exception / Symptom:** ATC raises a P1 finding in the quality system after transport import, even though the code appeared to work in DEV. Alternatively: code passes DEV and QAS but fails at runtime in PRD with `CX_SY_DYN_CALL_ILLEGAL_TYPE`, `CLASS_NOT_FOUND`, or a similar exception referencing an unreleased or missing class. Root cause is use of an API that is unreleased, release-level-dependent, or only present in the DEV system's specific software level.

**Landscapes:** Private Cloud Edition, Public Cloud.

---

### Root Cause

| Root Cause | Description |
|---|---|
| **A — ATC not run in DEV** | Developer did not run `ABAP_CLOUD_DEVELOPMENT_DEFAULT` locally; P1 violation was only caught at the QAS quality gate |
| **B — Release gap between systems** | The API is released (C1) in the DEV system's software level but is **not yet released** (or does not exist) in the target system's software level — a version lag between landscapes |
| **C — Add-on / third-party API** | Developer used a class from a customer add-on, partner solution, or industry add-on without verifying it is released for the target landscape |
| **D — Deprecated API** | API was C1-released but has since been deprecated; deprecated status may differ between system releases |

---

### Diagnosis

| Step | Fiori App | T-Code / Tool |
|---|---|---|
| Read ATC P1 finding detail | **ABAP Test Cockpit** → open finding | `ATC` |
| Check release state of specific API | ADT → right-click object → Properties → Release State | `SE80` → Properties |
| Browse released alternatives by functional area | ADT → **Released Objects** browser | N/A (ADT feature) |
| Check official SAP migration guidance | **Cloudification Repository Viewer** (SAP BTP tool) | External: [https://cxp.sap.com/cloudification](https://cxp.sap.com/cloudification) |
| Verify which software level an API was released in | SAP API Business Hub / SAP Help Portal | External documentation |
| Check runtime error in target | N/A | `ST22` (in target system) |

**ADT Released Objects Browser — Step-by-step:**
```
ADT (Eclipse)
  └─ Menu: Navigate → Open ABAP Development Object (CTRL+SHIFT+A)
       └─ Type filter: select "Released Objects" from dropdown
            └─ Search: enter functional keyword (e.g., "ProductionOrder", "GoodsMovement")
                 └─ Results show: object name | release state | package
                      └─ Only use objects marked "Released" (C1)
```

---

### Fix Pattern

#### Fix A — Replace with Released CDS View (Data Access)

```abap
" ❌ BEFORE — direct SELECT from SAP standard table (P1: unreleased data access)
SELECT aufnr, auart, gamng
  FROM aufk
  INTO TABLE @DATA(lt_orders)
  WHERE werks = @lv_plant.

" ✅ AFTER — use released CDS view
SELECT ManufacturingOrder,
       ManufacturingOrderType,
       TotalQuantity
  FROM I_ManufacturingOrder
  INTO TABLE @DATA(lt_orders)
  WHERE Plant = @lv_plant.
```

```abap
" ❌ BEFORE — BAPI call (unreleased in ABAP Cloud context)
CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
  EXPORTING goodsmvt_header  = ls_header
  TABLES    goodsmvt_item    = lt_items
            return           = lt_return.

" ✅ AFTER — Tier 2 wrapper via released interface
" (Implement a local wrapper class that encapsulates the BAPI behind a
"  released interface — see Tier 2 Wrapper Pattern below)
DATA(lo_goods_movement) = NEW zcl_mm_goods_movement_wrapper( ).
lo_goods_movement->post(
  EXPORTING is_header = ls_header
            it_items  = lt_items
  IMPORTING et_return = lt_return ).
```

**Common unreleased API → released replacement table:**

| ❌ Unreleased / Forbidden | ✅ Released Alternative | Notes |
|---|---|---|
| `SELECT FROM aufk` | `I_ManufacturingOrder` (CDS) | Production orders |
| `SELECT FROM vbak / vbap` | `I_SalesOrder`, `I_SalesOrderItem` (CDS) | Sales orders |
| `SELECT FROM ekko / ekpo` | `I_PurchaseOrder`, `I_PurchaseOrderItem` (CDS) | Purchase orders |
| `BAPI_GOODSMVT_CREATE` | Tier 2 wrapper → `MBND_GOODS_MOVEMENT` service (check release per release) | Goods movements |
| `CL_SYSTEM_UTC` | `xco_cp_time=>moment` | Time/date handling |
| `CL_ABAP_DATFM` | `xco_cp_time` framework | Date formatting |
| `CL_GUI_FRONTEND_SERVICES` | Not available in Cloud; use Fiori/UI5 frontend | File dialogs |

#### Fix B — Tier 2 Wrapper Pattern (Unavoidable Unreleased API)

When no released alternative exists and the API must be used, isolate it behind a released interface. This confines the violation to a single, documented, exempted class.

```abap
" Step 1: Define a released interface (this IS releasable — it uses only clean types)
INTERFACE zif_mm_goods_movement
  PUBLIC.
  TYPES: BEGIN OF ty_return,
           type    TYPE bapiret2-type,
           message TYPE bapiret2-message,
         END OF ty_return,
         tt_return TYPE STANDARD TABLE OF ty_return WITH EMPTY KEY.

  METHODS post
    IMPORTING is_header TYPE zif_mm_goods_movement=>ty_header   " define clean type
              it_items  TYPE zif_mm_goods_movement=>tt_items
    EXPORTING et_return TYPE zif_mm_goods_movement=>tt_return.
ENDINTERFACE.

" Step 2: Implement wrapper class — this class gets the ATC exemption
CLASS zcl_mm_goods_movement_wrapper DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_mm_goods_movement.
  PRIVATE SECTION.
    " ATC exemption documented here: Exemption ID <XXXX>, valid until <date>
    " Reason: No released API for goods movement posting as of release 2024
ENDCLASS.

CLASS zcl_mm_goods_movement_wrapper IMPLEMENTATION.
  METHOD zif_mm_goods_movement~post.
    " Unreleased BAPI call is isolated here — exemption applied to THIS class only
    CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
      EXPORTING goodsmvt_header = <mapped header>
      TABLES    goodsmvt_item   = <mapped items>
                return          = <lt_bapi_return>.
    " Map return to clean type
  ENDMETHOD.
ENDCLASS.

" Step 3: All callers depend ONLY on the released interface — no ATC findings in callers
DATA(lo_post) = CAST zif_mm_goods_movement(
                  NEW zcl_mm_goods_movement_wrapper( ) ).
lo_post->post( EXPORTING is_header = ls_header
                         it_items  = lt_items
               IMPORTING et_return = lt_return ).
```

> The ATC exemption is granted to `zcl_mm_goods_movement_wrapper` only. All business logic classes depend on `zif_mm_goods_movement` (the released interface) and pass ATC without exemption.

#### Fix C — Release Gap (API Exists in DEV but Not in Target)

```
Diagnosis:
  1. Note the exact API name from the ATC finding
  2. Check SAP release notes for the API's "available from" release
  3. Compare with your target system's software level:
     SM51 (or Fiori System Info) → note SP / Release level

Resolution Options:
  A. Wait for target system to be upgraded to the release that includes the API
     → Plan the feature for a post-upgrade sprint

  B. Use an alternative API available in the lower release
     → Cloudification Repository Viewer → check "available from" column

  C. Request time-limited exemption and track the technical debt
     → ABAP Test Cockpit → Manage Exemptions → reference the planned upgrade date
```

---

### Landscape Notes

| Landscape | ATC Enforcement | Release Gap Risk | Key Action |
|---|---|---|---|
| **Public Cloud (BTP ABAP)** | Enforced by platform; no override | Lower — SAP manages system updates | Always use Released Objects browser before coding |
| **Private Cloud Edition** | Pipeline-configured; P1 typically blocks | Higher — customer controls update schedule | Verify target release level before using new APIs |
| **On-Premise** | Project governance; configurable | Highest — long update cycles possible | Check API availability in all landscape tiers before adoption |

---

### Prevention

- **Make ATC mandatory before transport release** — configure `ABAP_CLOUD_DEVELOPMENT_DEFAULT` as a pre-release check set in SE91/ATC configuration; no transport can be released without a clean ATC result.
- **Run ATC in ADT on every save** for ABAP Cloud packages — configure in ADT preferences → ABAP → ATC → "Run on Save".
- Establish a team **API Approval Gate**: any new external dependency (SAP class, FM, BAPI) must be reviewed for release state before implementation begins — not after.
- Maintain a team **Approved API Catalogue**: a shared document listing confirmed C1-released APIs for your domain, reviewed after every system upgrade.
- After every system upgrade, run a full ATC sweep to detect APIs that have changed from Released → Deprecated.

---

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

---

*End of Transport and Governance Issues — Production Resolution Guide*