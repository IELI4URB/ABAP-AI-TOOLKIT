---
name: transport-task-overlap-check
description: 'Compare one SAP CTS task with sibling tasks and tasks in other open transport requests for a user. Use for duplicate transported objects, cross-TR dependencies, shared task objects, task overlap checks, or objects locked in another developer task or request.'
---

# Transport Task Object Overlap Check

Use this read-only workflow to find repository objects recorded in both a developer's task and another open task. Check sibling tasks under the same parent request and tasks under other open parent requests in the requested user scope.

## Terminology

- **Parent request**: the workbench transport request that owns developer tasks.
- **Source task**: the developer task whose objects are being checked.
- **Sibling tasks**: other open developer tasks under the same parent request.
- **External tasks**: open developer tasks under other parent requests.
- **Task overlap**: an object recorded in more than one task under the same parent request.
- **Transport lock conflict**: an object locked by a different parent request.

Do not describe a same-parent task overlap as a cross-transport lock. CTS normally owns the lock at parent-request level.

## Required Input

Collect or confirm:

1. Connected ABAP destination.
2. Parent transport request number.
3. Source task number and owner.
4. Open sibling task numbers and owners.
5. User or owner whose other open transport tasks must be checked.
6. Open external parent requests and tasks in that user scope.

Prefer an authoritative CTS task hierarchy or transport search when an approved ADT tool exposes it. Otherwise ask the user for the open sibling and external task lists. Never infer tasks by scanning sequential transport numbers.

Clarify the external scope when needed:

- **User scope**: open tasks owned by the specified user under other parent requests.
- **System scope**: all visible open tasks, including tasks owned by other developers.

Use system scope when the question is whether another developer or request holds the same object. User scope alone cannot exclude conflicts owned by other users.

## Procedure

1. Verify that the source and sibling task numbers belong to the stated parent request when hierarchy data is available.
2. Discover open external tasks using an authoritative CTS transport search, filtered by the requested user when user scope applies.
3. Record the parent request, task number, owner, status, and description for every candidate task.
4. Read the source task object list using the configured read-only CTS/ADT transport tool.
5. Read every open sibling and external task object list in parallel when possible.
6. Follow pagination until each task reports completion and zero remaining objects.
7. Preserve each raw CTS object key as `(object type, object name)`.
8. Build an additional owning-object key only for a known subobject mapping:
   - `CLAS/OM <class>  <method>` maps to owning class `CLAS/OC <class>`.
9. Compare both exact raw keys and known owning-object keys.
10. For each source object, use an authoritative CTS object-lock check when available to identify a lock held by another parent request.
11. Report each match with classification, parent request, task, owner, raw object type/name, and owning object when normalization was needed.

Use `abap_transport-unifiedDifference` when it is the available read-only transport tool. Pass the task number, not the parent request number, and continue with `nextCursor` until `status` is `completed`.

## Completeness Gate

Before concluding that no overlap exists, verify all of the following:

- Every supplied open sibling task was checked.
- Every discovered open external task in the requested scope was checked.
- Transport search results were complete for the requested owner/system scope.
- Every paginated response completed with zero remaining objects.
- Parsed object coverage reconciles with the tool's reported task object count.
- No response failed, timed out, or omitted object identity data.

If a diff tool reports more objects than can be identified from its output, mark the result **incomplete**. Do not claim that no overlap exists; request an authoritative CTS object list or inspect the task in Transport Organizer.

## Output

Return a compact result in this order:

1. Parent request, source task, and requested user/system scope.
2. Same-parent tasks checked, including owner and object count.
3. Other open parent requests and tasks checked, including owner and object count.
4. Same-parent overlaps.
5. Cross-request lock conflicts or dependencies.
6. Completeness status and any tool limitation.

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