---
name: bgpf-background-processing
description: 'Background Processing Framework (bgPF) in ABAP Cloud. Use for asynchronous, reliable execution of application methods via CL_BGMC_PROCESS_FACTORY, transactional vs queued background processes, transactional-control (RAP / Controlled SAP LUW) vs transactional-uncontrolled scenarios, bgRFC basis, and unit-testing transactional background processes. Distinct from Application Jobs (scheduling).'
metadata:
  version: 1.0.0
  tags: abap bgpf background-processing bgrfc async controlled-luw rap abap-cloud
---

# Background Processing Framework (bgPF)

Source: SAP Help — [Background Processing Framework](https://help.sap.com/docs/abap-cloud/abap-concepts/background-processing-framework?locale=en-US).

The **bgPF** asynchronously and reliably executes methods of an application as background processes. Use it to move time-consuming work out of the current (dialog/OData) session so the end user does not wait — process continues, result is collected later.

> **bgPF vs Application Jobs:** Application Jobs = user/admin-scheduled, recurring or event-based *jobs* (see `abap-application-jobs.md`). bgPF = programmatic async execution of a method *within or after the current LUW*. Different concerns — don't conflate.

## Technical basis

- Built on **bgRFC** (background RFC) — the successor to `tRFC`/`qRFC`; efficient, scalable, transactional processing of large volumes of sequential calls.
- bgPF wraps bgRFC and supports the **inbound** scenario only: sending and receiving system are the same; the call runs in a **new session**. You do **not** define your own RFC destination.
- Available since **SAP BTP ABAP environment 2308** (verify availability for your exact release).

## Quality of service

| Process type | QoS | Ordering |
|---|---|---|
| **Transactional** background process | exactly once | no specific order |
| **Queued** background process | exactly once in order | strict order within the queue |

## Transactional control (RAP) vs uncontrolled

- **Transactional control** (with RAP / the **Controlled SAP LUW**): bgPF differentiates the **modify** phase (data changed in the transactional buffer, possibly inconsistent) from the **save** phase (ensures consistency, performs the final DB commit). Use this to extract code safely from the current SAP LUW while preserving consistency.
- **Transactional uncontrolled**: outside RAP or when no modify/save differentiation is needed.
- Do **not** confuse *transactional control* (the LUW contract) with *transactional background process* (the QoS type).

## Pattern

```abap
" Create a background process, add the operation, then schedule it.
DATA(lo_factory) = cl_bgmc_process_factory=>get_default( ).
DATA(lo_process) = lo_factory->create( ).

" Bind the operation (a class implementing the bgPF operation interface)
lo_process->set_operation_tx_uncontrolled( NEW zcl_my_bg_operation( iv_key = lv_key ) ).
" ...or set_operation( ) for a transactionally controlled operation in a RAP save.

lo_process->save_for_execution( ).   " scheduled on COMMIT WORK / end of RAP save
COMMIT WORK.
```

> Verify the exact factory/operation method names and the controlled vs uncontrolled setter for your release in `CL_BGMC_PROCESS_FACTORY` / the bgPF interfaces — the controlled variant is only valid inside a RAP save handler whose transaction contract permits it.

## Advantages

- **Transactional consistency** — with RAP transactional control, extract work from the current SAP LUW safely.
- **End-user performance** — the current LUW responds faster when post-processing runs in a separate session.
- **Reliability** — exactly-once execution (bgRFC-backed), with monitoring.

## Monitoring & tests

- Monitor background processes via the bgPF/bgRFC monitor (Fiori app / bgRFC monitor).
- Write **ABAP Unit tests for transactional background processes** using the bgPF test support (test double / environment for background operations) — verify the test API for your release.
