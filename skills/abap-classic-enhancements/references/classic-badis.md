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

---

## 5. Multiple-Use BAdIs

When BAdI definition has **Multiple Use = X**: multiple active implementations execute in sequence.

Order of execution not guaranteed — implementations must be independent and not rely on execution order.

```abap
" Multiple implementations active:
"   ZCL_BADI_SD_VALIDATION_BASIC   — filter: * (all)
"   ZCL_BADI_SD_VALIDATION_KEYA    — filter: customer group Z001

" Both execute for key account orders. Both must be idempotent
" and must not cancel each other's messages.
```

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
| Multiple active — wrong sequence | Order not guaranteed | Decouple implementations; no sequence dependency |
| `GET BADI` returns empty | No active implementation, not a runtime error | Check for active impl in SE19; verify filter match |
| Classic BAdI on Cloud system | Object not released for Cloud | Use Cloud BAdI in ADT instead |
| Implementation lost after transport | Transport captured wrong client | Re-transport; check CTS |
