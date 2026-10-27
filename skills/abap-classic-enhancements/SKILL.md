---
name: abap-classic-enhancements
description: 'Classic and Standard ABAP enhancement mechanisms for ECC and S/4HANA on-premise. Use for Enhancement Spots, Enhancement Implementations, classic BAdIs, User Exits, Customer Exits, implicit and explicit enhancement options, modification adjustments (SPAU), and the SMOD/CMOD framework. NOT for ABAP Cloud or BTP — use abap-rap-services for Cloud BAdIs and BDEF extensions.'
metadata:
  version: 1.0.0
  tags: abap classic enhancement badi user-exit customer-exit smod cmod spau ecc s4hana standard-abap
---

# Classic ABAP Enhancements

**Landscape: Standard ABAP / ECC / S/4HANA on-premise only.**
For ABAP Cloud (BTP, Public Cloud, Private Cloud with ABAP Cloud enforcement): use `abap-rap-services` → BAdIs and enhancements.

## Guide Routing

| Request | Guide |
|---|---|
| Enhancement Spots, Enhancement Implementations, implicit/explicit options | [Classic Enhancement Framework](./references/classic-enhancement-framework.md) |
| Classic BAdIs (IF_EX_* / CL_EXITHANDLER factory), kernel-based BAdIs (GET BADI/CALL BADI) on-premise, screen/menu enhancements (BAdI subscreens) | [Classic BAdIs](./references/classic-badis.md) |
| User Exits (SMOD/CMOD), Customer Exits, Function Module Exits | [Classic Enhancement Framework](./references/classic-enhancement-framework.md) |
| Modification adjustments, SPAU, upgrade impact | [Classic Enhancement Framework](./references/classic-enhancement-framework.md) |

## Landscape Decision Gate

Before implementing any classic enhancement:

1. **Confirm landscape** — ECC or S/4HANA on-premise? If ABAP Cloud or BTP: stop, use Cloud extensibility.
2. **Confirm modification vs enhancement** — direct source modification requires SSCR key and SPAU at every upgrade; always prefer enhancement over modification.
3. **Check SAP Note / OSS** — enhancement spot may already exist; search SE18 before requesting modification.
4. **Transport assignment** — all enhancement implementations need workbench transport in customer namespace.

## Workflow

1. Identify the SAP program, function module, or class to extend.
2. Determine mechanism tier: Enhancement Spot (preferred) → classic BAdI → User Exit → Customer Exit → modification (last resort).
3. Verify namespace: customer objects in Z/Y namespace or registered namespace.
4. Implement in customer package with transport.
5. Test in DEV → QA → PRD pipeline; validate upgrade behaviour in sandbox.

## Mandatory Gates

- Never modify SAP standard without SSCR key and documented business justification.
- Modifications break on upgrade — always document SPAU obligation and assign upgrade owner.
- Classic BAdIs are not thread-safe by default; verify filter usage for multi-instance scenarios.
- Enhancement Implementations must be transportable — never create in $TMP.
- Cross-client enhancements: verify client-dependent vs client-independent activation.
