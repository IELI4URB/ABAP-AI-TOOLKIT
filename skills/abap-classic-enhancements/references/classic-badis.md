# Classic BAdIs

**Landscape: Standard ABAP / ECC / S/4HANA on-premise.**

Classic BAdIs (Business Add-Ins) predate the kernel-based BAdIs of the Enhancement Framework. Still widely used in SD, MM, FI, HR function modules on ECC and S/4HANA on-premise.

> **Terminology (SAP Help):** Within the Enhancement Framework, "BAdI" always means **kernel-based** BAdI (statements `GET BADI` / `CALL BADI`, switchable, integrated in the kernel). The legacy concept — factory method `CL_EXITHANDLER=>GET_INSTANCE` + `IF_EX_*` interface — is the **classic** BAdI. This guide covers classic BAdIs; kernel-based call syntax is shown in §4 for contrast only.

---

## 1. Classic BAdI Concepts

| Concept | Description |
|---|---|
| BAdI Definition | SAP-delivered interface + filter type; lives in Enhancement Spot |
| BAdI Implementation | Customer class implementing the BAdI interface |
| Filter | Value that routes a BAdI call to the matching implementation |
| Multiple-Use | Flag: single or multiple active implementations simultaneously |
| Default Implementation | SAP-provided fallback if no active customer implementation |

---

## 2. Finding Available BAdIs

### SE18 — Enhancement Spot / BAdI Explorer

1. **SE18** → enter Enhancement Spot name (e.g., `ES_SD_SALES_ORDER`).
2. Tab **BADIs** → lists all BAdIs hosted in that spot.
3. Double-click BAdI → see interface, filter type, documentation, and existing implementations.

### SE80 Search

1. **SE80** → select **Enhancement Spot** in dropdown → enter `ES_*` pattern → Execute.

### Where-Used from Program

In SE38 or Eclipse: right-click on `CALL BADI` statement → Navigate → BAdI Definition.

---

## 3. Classic BAdI Implementation

### 3.1 Interface Pattern

SAP delivers BAdI definition with interface `IF_EX_<NAME>`:

```abap
" BAdI interface delivered by SAP (read-only; implement, never modify)
INTERFACE if_ex_sd_so_before_save.
  METHODS validate_before_save
      IMPORTING
          iv_vbeln TYPE vbeln_va
          iv_vbak  TYPE vbak
      CHANGING
          ct_messages TYPE bapiret2_t
      RETURNING
          VALUE(rv_reject) TYPE abap_bool.
ENDINTERFACE.
```

### 3.2 Create BAdI Implementation via SE19

1. **SE19** → Create → Implementation Name (Z namespace).
2. Enter BAdI name or Enhancement Spot.
3. System generates: implementation class skeleton implementing `IF_EX_<NAME>`.
4. Enter filter value (if filter-based BAdI).
5. Activate → assign transport.

### 3.3 Implementation Class

```abap
CLASS zcl_badi_sd_so_before_save DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_ex_sd_so_before_save.
    " Classic BAdIs: implement IF_EX_* not IF_BADI_INTERFACE
    " (IF_BADI_INTERFACE is Cloud pattern)

ENDCLASS.

CLASS zcl_badi_sd_so_before_save IMPLEMENTATION.

  METHOD if_ex_sd_so_before_save~validate_before_save.
    " iv_vbeln, iv_vbak available as importing
    " ct_messages: append validation errors
    " rv_reject: set to abap_true to block save

    IF iv_vbak-kunnr IN zsd_key_accounts
        AND iv_vbak-zterm IS INITIAL.

      APPEND VALUE #(
          type       = 'E'
          id         = 'ZSD_VALIDATION'
          number     = '010'
          message_v1 = iv_vbeln )
        TO ct_messages.

      rv_reject = abap_true.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
```

### 3.4 How SAP Calls a Classic BAdI (Factory Pattern)

Classic BAdIs are instantiated by the SAP framework via the exit-handler factory, **not** `GET BADI`:

```abap
" SAP framework code (classic BAdI call — factory method)
DATA: lo_badi TYPE REF TO if_ex_sd_so_before_save.

CALL METHOD cl_exithandler=>get_instance
  EXPORTING
    exit_name = 'SD_SO_BEFORE_SAVE'
  CHANGING
    instance  = lo_badi.

CALL METHOD lo_badi->validate_before_save
    EXPORTING iv_vbeln    = lv_vbeln
              iv_vbak     = ls_vbak
    CHANGING  ct_messages = lt_messages
    RECEIVING rv_reject   = lv_reject.
```

Filter values for a classic BAdI are passed **with the method call** (in a flt_val parameter / structure), not at instantiation.

---

## 4. Filters — Classic vs Kernel-Based

Filters route a BAdI call to the matching implementation when multiple active implementations coexist.

**Classic BAdI** — filter value passed on the method call:

```abap
" SE19: implementation tagged with filter value (e.g. BUKRS = 1000)
" SAP passes the comparison value as a method parameter (flt_val):
CALL METHOD lo_badi->validate_before_save
    EXPORTING flt_val     = lv_bukrs    " framework matches impl filter
              iv_vbeln    = lv_vbeln
    CHANGING  ct_messages = lt_messages.
```

**Kernel-based BAdI (contrast only — Enhancement Framework)** — comparison value passed at instantiation with `GET BADI`:

```abap
" NOT classic. Kernel-based: filter resolved when object created.
GET BADI lo_badi
    FILTERS bukrs = lv_bukrs.

CALL BADI lo_badi->validate_before_save
    EXPORTING iv_vbeln    = lv_vbeln
    CHANGING  ct_messages = lt_messages.
```

Key difference (SAP Help): classic passes filter values **with the method call**; kernel-based passes comparison values **when the BAdI object is created** via `GET BADI`.

> Sections below (extendable filter types, BAdI-definition changes, country-specific, sorting) are grounded on SAP Help *Changing the SAP Standard (BC) → Enhancements to the Standard → Classic Techniques → Classic BAdIs*.

### Extendable filter types

A filter type flagged **Extendable** lets you create implementations for filter values that did not exist before (SE18 *Implementation* menu becomes *Filter Value → Create*). Requirements on the filter domain:

- Domain linked to a **cross-client value table** with exactly one key field typed by the filter's data element.
- A **text table** with two key fields (filter type + language), containing a field whose name includes `TEXT`/`TXT`.
- Delivery class of both tables = **E or G**.
- New filter values must not already exist in the value table — they are added on save, removed when the implementation/BAdI is deleted.

### Changing a BAdI definition (upgrade awareness)

Allowed changes: **filter type**, **multiple-use** flag, **internal flag**. Interface changes are risky:
- Deleting/renaming/creating a method can make existing implementations syntactically invalid. Clean up with SE19 → *Interface* tab → *Name of Implementing Class* → Class Builder → **Utilities → Clean Up → Method Includes** (runs automatically after a transport import).
- Adding parameters is safe; changing parameter types or deleting parameters can cause syntax errors or runtime termination.

### Country-specific BAdIs

Use the ISO country code data element **`INTCA`** (e.g. `US`, not `USA`) as filter. Determine it with `SELECT ... INTCA FROM T005` before the call, then pass as the filter value (SAP example: the `Address-Check` BAdI).

---

## 5. Multiple-Use BAdIs

When BAdI definition has **Multiple Use = X**: multiple active implementations execute.

By default execution order is **arbitrary** — so implementations should be independent. But order **can** be controlled by a **sort mechanism** (SAP Help: *Sorting Classic BAdI Implementations*):

- **SE18 → Utilities → Sort.**
- **Standard Sort** — numeric sort values entered in the **Layer Value** field when creating each implementation; stored in a table; implementations run in that numeric order.
- **Special Sort** — non-numeric ordering via an implementation of the delivered BAdI definition `BADI_LAYER` (interface `IF_EX_BADI_LAYER`, method `SORT_DATA` sorts a value table at runtime; data transmission via a subscreen).
- **No Sort** — arbitrary order (default).
- Turning sort **on** is **not** a modification (BAdI definition unchanged). Turning it **off** or changing it **counts as a modification**.

```abap
" Multiple implementations active:
"   ZCL_BADI_SD_VALIDATION_BASIC   — filter: * (all)
"   ZCL_BADI_SD_VALIDATION_KEYA    — filter: customer group Z001
" Without sort: order arbitrary — both must be idempotent and must not
" cancel each other's messages. With Standard Sort: Layer Value sets order.
```

---

## 5A. Screen Enhancements (BAdI-based)

Adding custom fields/subscreens to a standard SAP screen. Since **Release 7.0**, screen enhancements are integrated into the classic BAdI concept (replacing the old customer-exit screen exits that used "X" function groups).

Source: SAP Help — [Changing the SAP Standard (BC) → Classic BAdIs → Screen Enhancements](https://help.sap.com/docs/ABAP_PLATFORM_BW4HANA/2b28ffa716c24348903f8ffbfeb81df8/9d12233a0edd7978e10000000a11402f.html?locale=en-US).

Mechanics:
- A classic BAdI definition can carry a **subscreen**. **Not supported for multiple-use BAdIs.**
- Data retention/processing moves to a **user function group or module pool** in the implementer's namespace (no "X" prefix — eliminated). The BAdI class instance is used only to **transport data** between the calling application and the subscreen.
- The BAdI class exposes a generated public static read-only attribute **`DYNPRO_INSTANCE`**.
- App side calls static **`SET_INSTANCE_FOR_SUBSCREEN`** to publish the instance; the subscreen (PBO/PAI of the user function group) reads it via static **`GET_INSTANCE_FOR_SUBSCREEN`**.
- Different subscreen states are represented by **different instances**.

Two steps (SE18 define / SE19 implement):

1. **Define** (SE18) — add a screen enhancement (subscreen) to the BAdI definition; a subscreen area is reserved in the SAP screen.
2. **Implement** (SE19) — create the subscreen in a Z function group; in its PBO read the data via `GET_INSTANCE_FOR_SUBSCREEN`, in PAI write back to the instance.

```abap
" PBO of the customer subscreen (user function group)
MODULE status_subscreen OUTPUT.
  DATA(lo_badi_inst) = zcl_badi_flight_scr=>get_instance_for_subscreen( ).
  gs_scr = lo_badi_inst->get_display_data( ).   " fill screen fields
ENDMODULE.

" Application side (SAP program, before calling the subscreen)
zcl_badi_flight_scr=>set_instance_for_subscreen( lo_badi_inst ).
```

> **Persistence vs display are two steps.** A `CI_` include on the underlying DDIC structure (e.g. `CI_COBL`, `CI_EKKO`) makes the field *exist/persist*; the subscreen BAdI makes it *display*. Both are required for a custom field to stick.

Discovery of screen hooks: **SE84 → Enhancements → BAdI Definitions** (look for GUI/subscreen BAdIs, e.g. `ME_GUI_PO_CUST`), or **SE51/SE80** → open the SAP screen flow logic → search `CALL CUSTOMER-SUBSCREEN` (classic) / `CALL SUBSCREEN`. Menu enhancements use the same BAdI mechanism (menu exit) but are distinct from subscreen enhancements.

---

## 6. Fallback / Default Implementation

SAP may deliver a default implementation that runs when no customer implementation is active. Check in SE18 under the BAdI → tab **Default Implementation**.

Do not activate default implementation in customer systems — it is SAP-owned. If you need to extend default behavior: create your own implementation and call helper class if needed.

---

## 7. Classic BAdI vs Cloud BAdI Comparison

| Aspect | Classic BAdI | Cloud BAdI (ABAP Cloud) |
|---|---|---|
| Interface prefix | `IF_EX_*` | `IF_BADI_INTERFACE` + domain IF |
| Instantiation | `CL_EXITHANDLER=>GET_INSTANCE` factory | `GET BADI` (kernel-based) |
| Transaction | SE18 / SE19 | ADT Enhancement Spot |
| Landscape | ECC / S/4HANA on-premise | ABAP Cloud / BTP |
| Transport | Workbench transport | Workbench transport |
| Filter passed | On method call (flt_val) | At `GET BADI` creation |
| Multiple Use | Flag on definition | Same |
| Release contract | N/A (on-premise) | C0 extensibility contract required |

---

## 8. Common Issues

| Issue | Cause | Fix |
|---|---|---|
| Implementation not firing | Inactive or wrong filter value | SE19 → check activation status and filter |
| Multiple active — wrong sequence | Default order is arbitrary | Decouple implementations, or set order via SE18 → Utilities → Sort (Standard/Special Sort) |
| `GET BADI` returns empty | No active implementation, not a runtime error | Check for active impl in SE19; verify filter match |
| Classic BAdI on Cloud system | Object not released for Cloud | Use Cloud BAdI in ADT instead |
| Implementation lost after transport | Transport captured wrong client | Re-transport; check CTS |
