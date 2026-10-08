# Clean Core and ATC Governance — Transport Resolution Guide

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
