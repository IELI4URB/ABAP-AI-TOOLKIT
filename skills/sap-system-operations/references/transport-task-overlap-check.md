---
name: transport-task-overlap-check
description: 'Compare one SAP CTS task with explicitly supplied sibling tasks or discovered tasks in other open transport requests. Use for duplicate transported objects, cross-task contract dependencies, shared task objects, task overlap checks, or objects locked in another developer task or request.'
---

# Transport Task Object Overlap Check

Use this read-only workflow to find repository objects recorded in both a developer's task and another open task. Check sibling tasks under the same parent request and tasks under other open parent requests in the requested user scope.

## Mode Selection

Choose one mode before calling transport tools:

- **Explicit-task mode:** The user supplies the parent request, source task, and exact open sibling tasks. Check only those tasks. Do not discover or inspect the parent request, other siblings, external requests, or sequential task numbers. Task owner is optional metadata and must not block comparison.
- **Discovery mode:** The user asks to find sibling or external tasks without supplying the complete list. Use an authoritative CTS hierarchy/search when available; otherwise ask for the missing task numbers once.

When the user corrects the scope to explicit tasks, discard broader discovery results and restart the comparison from the supplied task list.

## Terminology

- **Parent request**: the workbench transport request that owns developer tasks.
- **Source task**: the developer task whose objects are being checked.
- **Sibling tasks**: other open developer tasks under the same parent request.
- **External tasks**: open developer tasks under other parent requests.
- **Task overlap**: an object recorded in more than one task under the same parent request.
- **Transport lock conflict**: an object locked by a different parent request.

Do not describe a same-parent task overlap as a cross-transport lock. CTS normally owns the lock at parent-request level.

## Required Input

For explicit-task mode, collect or confirm only:

1. Connected ABAP destination.
2. Parent transport request number.
3. Source task number.
4. Exact open sibling task numbers to compare.

For discovery mode, additionally collect:

5. Source/sibling owners when available.
6. User or owner whose other open transport tasks must be checked.
7. Open external parent requests and tasks in that user scope.

Prefer an authoritative CTS task hierarchy or transport search when an approved ADT tool exposes it. Otherwise ask the user for the open sibling and external task lists. Never infer tasks by scanning sequential transport numbers.

Clarify the external scope when needed:

- **User scope**: open tasks owned by the specified user under other parent requests.
- **System scope**: all visible open tasks, including tasks owned by other developers.

Use system scope when the question is whether another developer or request holds the same object. User scope alone cannot exclude conflicts owned by other users.

## Procedure

1. Select explicit-task or discovery mode. In explicit-task mode, create the candidate list directly from the supplied task numbers and do not inspect the parent request as a substitute.
2. Verify that source and sibling tasks belong to the stated parent when hierarchy data is available. Lack of owner metadata does not block explicit-task comparison.
3. In discovery mode only, discover external tasks using an authoritative CTS transport search and record parent request, task, owner, status, and description.
4. Read the source task and every candidate task with the configured read-only CTS/ADT transport tool. Pass task numbers, never the parent request number.
5. Read independent tasks in parallel. Follow every `nextCursor` until `status = completed` and `remainingCount = 0`.
6. Preserve each raw CTS key as `(object type, object name)` and reconcile identified keys with `totalObjects`.
7. If a multi-object batch omits identities or identified keys do not equal `totalObjects`, rerun that task with `pageSize = 1` and follow all cursors. Record the one object identity from every page, including pages with no source diff.
8. Resolve large-output artifacts to the full saved output before parsing. Treat each task response independently; a failed parse must not reuse data from a previous task.
9. Build owning-object keys only for known mappings:
   - `CLAS/OC <class>` owns itself.
   - `CLAS/OM <class><method>` maps to `CLAS/OC <class>`; CTS class names occupy the first 30 characters when no separator is displayed.
   - `CLAS/OCN <class><include>` maps to `CLAS/OC <class>`; this includes local test (`CCAU`) and definition (`CCDEF`) includes.
10. Compare exact raw keys first, then owning-object keys. Report same-parent matches as **task overlaps**, not cross-transport locks.
11. When dependency analysis is requested, run the contract pass below even when no object overlap exists.
12. For source objects under other parent requests, use an authoritative lock check when available and classify matches as cross-request conflicts.

## Contract Dependency Pass

Object overlap and dependency are different checks. Absence of overlap does not prove absence of dependency.

1. From the current source and source-task diff, collect repository contracts consumed by each source owning object: tables, CDS entities, classes/interfaces, BDEFs, data elements, and other static references.
2. Intersect those references with raw or normalized objects changed in each sibling task.
3. For every candidate intersection, inspect the sibling diff and compare changed members with the members consumed by the source object.
4. Classify each candidate:
   - **Hard dependency:** the source task consumes a type, field, method, behavior contract, or semantic change introduced/changed by the sibling task. Release/import sequencing is required.
   - **Non-impacting reference:** the source consumes the object, but the sibling changes different members and does not alter the consumed contract.
   - **Unresolved:** object identity is known but the diff/member contract is unavailable. Do not claim independence.
5. Activation in the development system is not proof of transport independence because active sibling-task changes may already be present there.

Example: if the source class selects fields from `Z_I_ITEM` and a sibling task changes `Z_I_ITEM`, inspect the changed fields. Adding an unrelated field is a non-impacting reference; changing a selected field or its type is a hard dependency.

Use `abap_transport-unifiedDifference` when it is the available read-only transport tool. Pass the task number, not the parent request number, and continue with `nextCursor` until `status` is `completed`.

## Completeness Gate

Before concluding that no overlap exists, verify all of the following:

- Every supplied open sibling task was checked.
- Every discovered open external task in the requested scope was checked.
- Transport search results were complete for the requested owner/system scope.
- Every paginated response completed with zero remaining objects.
- Parsed object coverage reconciles with the tool's reported task object count.
- No response failed, timed out, or omitted object identity data.
- When dependency analysis was requested, every source-to-sibling contract intersection was classified as hard, non-impacting, or unresolved.

If a diff tool reports more objects than can be identified, retry with `pageSize = 1`. If identities are still unavailable, mark the result **incomplete**. Do not claim that no overlap or dependency exists; request an authoritative CTS object list or inspect the task in Transport Organizer.

## Output

Return a compact result in this order:

1. Parent request, source task, and requested user/system scope.
2. Same-parent tasks checked, including owner and object count.
3. Other open parent requests and tasks checked, including owner and object count.
4. Same-parent overlaps.
5. Contract dependencies, including non-impacting references that were inspected.
6. Cross-request lock conflicts.
7. Completeness status and any tool limitation.

Example:

```text
Parent request: GMWK900001
Source task: GMWK900010 (DEVELOPER_A), 12 objects
External scope: user DEVELOPER_A

Same-parent tasks checked:
- GMWK900011 (DEVELOPER_B), 15 objects

Other open tasks checked:
- GMWK900101 under GMWK900100 (DEVELOPER_A), 4 objects

Same-parent overlap:
- BDEF/BDO /NAMESPACE/I_ENTITY - GMWK900011 (DEVELOPER_B)

Cross-request conflict:
- CLAS/OC /NAMESPACE/CL_SERVICE - GMWK900101 under GMWK900100

Completeness: Complete for user DEVELOPER_A; all discovered open tasks and pages checked.
```

## Safety

- Keep the workflow read-only.
- Never release, reassign, delete, or modify a task or request.
- Never auto-select a transport.
- Do not expose credentials or bypass the configured ADT connection.
- State clearly when task hierarchy or object identity data is unavailable.