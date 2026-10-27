# Classic Enhancement Framework

**Landscape: Standard ABAP / ECC / S/4HANA on-premise.**

SAP Help baselines:
- Enhancement Framework (2025 FPS02): https://help.sap.com/docs/ABAP_PLATFORM_NEW/46a2cfc13d25463b8b9a3d2a3c3ba0d9/949cdc40132a8531e10000000a1550b0.html?locale=en-US — §1 hierarchy, §2A Switch Framework, §2B Enhancement Append Packages.
- Changing the SAP Standard (BC): https://help.sap.com/docs/ABAP_PLATFORM_BW4HANA/2b28ffa716c24348903f8ffbfeb81df8/c819756543b111d1896f0000e8322d00.html?locale=en-US — §3 Customer Exits (types, discovery via SAP enhancements), §5 Modification / SPDD / SPAU.

---

## 1. Enhancement Mechanism Hierarchy

```
Enhancement Spot (SE18/SE20)            ← preferred, upgrade-stable
  ├─ Kernel-based BAdI                   ← current standard (GET BADI / CALL BADI, switchable)
  └─ Enhancement Implementation (SE19)  ← explicit/implicit source options

Classic BAdI (SE18 / SE19)              ← legacy (CL_EXITHANDLER factory, IF_EX_*)
User Exit / Customer Exit (SMOD/CMOD)   ← SAP-delivered exit points ("Previous Concept")
Modification (SE80 + SSCR)             ← last resort, SPAU at every upgrade
```

Choose from top down. Document reason if skipping a tier. Per SAP Help (2025 FPS02), the Enhancement Framework treats customer exits, user exits, ABAP Dictionary appends/includes, and **classic** BAdIs as "Previous Concepts" — prefer Enhancement Spots + kernel-based BAdIs for new work.

---

## 2. Enhancement Spots and Implementations

### 2.1 Enhancement Spot Types

| Type | Transaction | Description |
|---|---|---|
| Simple Enhancement Spot | SE18 | Container for Explicit Enhancement Options in a single program |
| Composite Enhancement Spot | SE18 | Groups multiple simple spots (cross-program) |
| BAdI-based Enhancement Spot | SE18 | Hosts one or more classic BAdIs |

### 2.2 Explicit Enhancement Options

SAP defines explicit hook points directly in source code:

```abap
" SAP-delivered code — explicit enhancement point
ENHANCEMENT-POINT ZSD_SO_BEFORE_SAVE
    SPOTS ES_SD_SALES_DOCUMENT
    STATIC.
" STATIC restricts the point to static enhancements (statement insertions);
" surrounding local data of the enclosing unit is visible in the implementation.
" Omit STATIC to also allow class-based (dynamic) enhancement implementations.
```

```abap
" SAP-delivered — explicit enhancement section (replace a code block)
ENHANCEMENT-SECTION ZSD_SO_VALIDATION
    SPOTS ES_SD_SALES_DOCUMENT.
  " SAP original code here — replaced by enhancement implementation
END-ENHANCEMENT-SECTION.
```

### 2.3 Implicit Enhancement Options

Implicit options exist at fixed structural positions in every ABAP program, class, and function module — no SAP activation needed:

| Position | Available at |
|---|---|
| Start of program / form / method | After first line of definition block |
| End of program / form / method | Before final statement |
| After INCLUDE directives | After each INCLUDE |
| Before/after SELECT loops, IF blocks | Depends on SAP release and syntax |

Access: **SE38 → Edit → Enhancement Operations → Show Implicit Enhancement Options**

### 2.4 Creating an Enhancement Implementation (SE19)

1. **SE19** → Create → Enhancement Implementation name (Z namespace).
2. Assign to Enhancement Spot.
3. Select the Enhancement Point or Section to implement.
4. Write customer code in the editor.
5. Activate → assign to workbench transport.

```abap
" Customer enhancement implementation — appears inside enhancement point
" Visible in SE19 under the Enhancement Implementation

DATA: lv_cust_check TYPE abap_bool.

" Check custom rule before save
lv_cust_check = zcl_custom_so_rules=>check_before_save(
    iv_vbeln = ls_vbak-vbeln ).

IF lv_cust_check = abap_false.
  MESSAGE e001(zsd_custom) WITH ls_vbak-vbeln INTO DATA(lv_msg).
  " Signal the error per the enhancement's contract (set a return flag,
  " SY-SUBRC, or raise the exception type declared by the host).
ENDIF.
```

---

## 2A. Switch Framework

Enhancement Implementations can be bound to the Switch Framework so their activation is controlled centrally, not just by their active/inactive flag.

| Concept | Transaction | Description |
|---|---|---|
| Switch | SFW1 | On/off control; toggles a package-switch assignment |
| Business Function | SFW5 | Groups switches; activated per customer need |
| Package assignment | — | Enhancement Implementation assigned to a switchable package |

Key points:
- A switch controls whole repository objects (enhancement implementations, screens, menu entries, DDIC enhancements) via the package it is assigned to.
- Kernel-based BAdIs are **switchable**; classic BAdIs are not.
- Business Function activation (SFW5) is **irreversible** in production — validate in sandbox first.
- If an enhancement is not firing, verify the controlling switch/business function is active, not only the implementation flag.

---

## 2B. Enhancement Append Packages

SAP source-code and DDIC enhancements are organized into **append packages** that are assigned to the original SAP package. This keeps customer additions physically separate from the SAP original while binding them to it.

- Each original (SAP) package can have append packages holding source-code enhancements and DDIC enhancements (appends/includes).
- The append package is created in the customer namespace and transported independently.
- Benefit: enhancement content survives upgrades because it is not inside the SAP original object.
- ABAP Dictionary appends/includes cooperate with the Enhancement Framework but are **not yet fully integrated** into it (SAP Help, 2025 FPS02) — treat them as a classic "Previous Concept".

---

### 3.1 User Exits (Function Module Exits)

SAP delivers empty function modules in Z namespace called at fixed points:

```
SMOD   — display/extend user exit definitions (SAP delivered)
CMOD   — manage customer projects that activate user exits
```

```abap
" SAP calls: CALL FUNCTION 'EXIT_SAPMV45A_001' ...
" Customer fills: include ZXVVAU01 (generated include inside function module)

INCLUDE ZXVVAU01.
" Content of ZXVVAU01 — customer writes here:

FORM user_exit_save_document_prepare.
  " Access global data of the calling program via TABLES/USING parameters
  " lv_vbak is passed from SAP framework
  IF vbak-kunnr IN zsd_key_accounts.
    " Custom logic
  ENDIF.
ENDFORM.
```

### 3.2 Activating User Exits via CMOD

1. **CMOD** → Create Project (Z name).
2. Assign Enhancement (from SMOD).
3. Go to Components → select function module exit includes.
4. Write code in generated Z include.
5. Activate project → transport.

### 3.3 Customer Exits (Menu/Screen/Field Exits)

| Type | Description |
|---|---|
| Menu Exit | Add custom menu entries. SAP defines them in the Menu Painter with function codes starting with **`+`**; you supply the menu text when activating the add-on project. |
| Screen Exit | SAP places a reserved **subscreen area** on a standard screen and issues `CALL CUSTOMER-SUBSCREEN` in its flow logic; you build the subscreen in a customer function group. |
| Field Exit | Validate/format individual screen fields |

Field exit example:
```abap
" Field exit for VBAK-BSTKD (Customer PO Number)
FUNCTION EXIT_SAPMV45A_010.
  " IMPORTING: FIELD_NAME, FIELD_VALUE
  " EXPORTING: FIELD_VALUE (modified)

  IF field_name = 'VBAK-BSTKD'.
    " Convert to uppercase
    TRANSLATE field_value TO UPPER CASE.
  ENDIF.
ENDFUNCTION.
```

### 3.4 Finding Applications That Have Exits

SAP groups exits into **SAP enhancements** (one enhancement = several individual exits, possibly of different types). Discovery:

- **ABAP Workbench → Utilities → Enhancements → Project Management → Utilities → SAP Enhancements** — selection screen to list enhancements; search by **development class** if the name is unknown, or Execute with no criteria to list all. Each entry shows documentation and its exit types.
- **Application Hierarchy** (ABAP Workbench → Overview → Application Hierarchy) + Repository Information System — locate exits for a specific application area (e.g. Materials Management).

---

## 4. Implicit Enhancement Implementation

### 4.1 Adding Code at Implicit Point

```abap
" In SE38 or Eclipse: position cursor, right-click →
" Enhancement Operations → Create Enhancement

ENHANCEMENT 1  ZSD_CUSTOM_VALIDATION.    "#EC NOTEXT
  " Your code here — runs at the implicit point position

  DATA: lv_result TYPE abap_bool.
  lv_result = zcl_custom_check=>validate( iv_vbeln = vbak-vbeln ).

  IF lv_result = abap_false.
    MESSAGE e005(zsd_messages) INTO DATA(lv_msg).
    APPEND lv_msg TO lt_messages.
  ENDIF.

ENDENHANCEMENT.
```

---

## 5. Modification (Last Resort)

### 5.1 When Permitted

Only when:
- No Enhancement Spot, BAdI, User Exit, or Customer Exit covers the requirement.
- Business justification documented and signed off.
- SSCR key registered for the object.

### 5.2 SSCR Registration

1. **SE03** → Register Object in Object Catalog → register SAP object to customer namespace modification.
2. Or via SAP Support Portal: System SSCR Key request.

### 5.3 Upgrade Adjustment — SPDD and SPAU

A system update compares modified objects against the new SAP standard. Two transactions, run during the update:

- **SPDD — ABAP Dictionary objects** (domains, data elements, tables, **structures**). Run **first**, before mass activation of DDIC objects, to avoid **loss of data / table fields**. Adjust or reset the objects SPDD lists; **do not activate adjusted objects** (with SPAM, activate only new objects, except appends); release the transport tasks; mark via **Modification Adjustment → Assign Transport**. With SUM the request is released automatically.
- **SPAU — repository objects** (programs, function modules, classes, screens, menus, text elements). Adjust after SPDD.

General:
- All modifications appear in the SPDD/SPAU delta lists.
- Assign an upgrade owner per modification; document in change management.
- SAP recommends all project members register the adjustment transport as their **default transport**.

```abap
" Modified SAP standard — marked by modification assistant
*{   MODIFICATION   ZSAP_CUSTOM   27.10.2026   I756261
*    Original SAP code removed or commented
*}
  " Customer replacement code
  PERFORM z_custom_so_validation USING ls_vbak.
```

---

## 6. Upgrade Impact Comparison

| Mechanism | Upgrade Impact | SPDD/SPAU Required | Risk |
|---|---|---|---|
| Enhancement Spot (explicit) | None — spot survives | No | Low |
| Enhancement Spot (implicit) | Low — position-based | Rare | Low |
| Classic BAdI | None — interface versioned | No | Low |
| User Exit / Customer Exit | None — exit contract stable | No | Low |
| Modification (repository) | **High — re-apply each upgrade** | **SPAU** | High |
| Modification (DDIC structure/table) | **High — field/data loss risk** | **SPDD** | High |

---

## 7. Transaction Quick Reference

| Transaction | Purpose |
|---|---|
| SE18 | Display Enhancement Spots and classic BAdI definitions |
| SE19 | Create/manage Enhancement Implementations |
| SMOD | Display SAP User Exit definitions |
| CMOD | Create/manage customer projects (activate user exits) |
| SFW1 | Switch maintenance (Switch Framework) |
| SFW5 | Business Function activation |
| SE03 | Transport Organizer Tools; SSCR key registration |
| SPDD | ABAP Dictionary modification adjustment after upgrade |
| SPAU | Repository modification adjustment after upgrade |
| SE80 | Repository Browser — navigate to any object for modification |
