# Transport Import Failures — Resolution Guide

## §2 — Activation Error After Transport Import

**Exception / Symptom:** Transport import completes without a hard error (return code 0 or 4 in STMS) but the transported object is **inactive** in the target system. Calling the class/function at runtime raises a load/generation error (e.g. `SYNTAX_ERROR`, `LOAD_PROGRAM_CLASS_MISMATCH`, or `CLASS_NOT_FOUND`) in `ST22`. The object appears to exist in SE80/ADT but has no active version.

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
