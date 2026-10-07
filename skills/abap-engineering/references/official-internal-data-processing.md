# Official ABAP Internal Data Processing Guide

This guide synthesizes the complete [ABAP - Processing Internal Data](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-processing-internal-data?locale=en-US) subtree reviewed on 2026-10-07: **478 topics / 324,407 words** with zero crawl failures. It provides decision rules, not copies of SAP page bodies.

## Scope Map

| Branch | Topics | Use it for |
|---|---:|---|
| Internal Tables | 139 | table category, keys, access, expressions, statements, memory, and performance |
| Character and Byte Strings | 116 | string/byte semantics, templates, functions, regex, and comparisons |
| Assignments | 113 | compatibility, conversion, references, structures, initialization, and lossless assignment |
| Numeric Calculations | 39 | numeric types, arithmetic expressions, functions, rounding, and overflow |
| Meshes | 30 | mesh nodes, associations, paths, expressions, and processing statements |
| Date and Time | 26 | dates, times, UTC timestamps, time zones, and daylight-saving rules |
| Streaming | 5 | reader/writer and character/binary stream contracts |
| Enumerated Objects | 5 | enum declaration, values, conversion, and comparison |
| Data Object Properties | 4 | `DESCRIBE` and Runtime Type Services (RTTS) |

## Working Rule

Before recommending internal-data code, establish:

1. Exact ABAP release and language version.
2. Static and runtime source/target types.
3. Expected cardinality, mutation frequency, access keys, ordering, and memory limits.
4. Conversion, rounding, overflow, invalid-value, not-found, and time-zone behavior.
5. Whether a released ABAP Cloud API is required for supporting classes.

Syntax acceptance alone does not prove compatible conversion, bounded memory, efficient access, or correct framework behavior.

## Assignment and Conversion Contract

ABAP distinguishes three assignment cases:

- **Compatible types:** technical type properties match; assignment does not convert the value.
- **Convertible types:** a conversion rule exists; conversion can raise an exception and is slower than assignment without conversion.
- **Neither compatible nor convertible:** the syntax check rejects statically known cases; otherwise execution can raise an uncatchable exception.

Apply these gates:

- Use `CONV` to make an intended target type explicit, not to hide an uncertain contract.
- Use `EXACT` when truncation, rounding, invalid values, or other information loss must be rejected before assignment.
- Remember that assignment rules also apply implicitly in many operand positions. Catchability can differ between direct assignments, functional method calls, expressions, and comparisons.
- Compatible assignment does not validate an already invalid date/time value.
- For generic data, verify runtime compatibility before assignment. SAP documents `CL_ABAP_DATADESCR->APPLIES_TO_DATA`; confirm its target-system API release before using it in ABAP Cloud.
- After a failed converting assignment, do not assume the target retained its previous value; behavior depends on the target category.

Sources: [Assignments](https://help.sap.com/docs/abap-cloud/abap-keyword/assignments?locale=en-US), [Assignment and Conversion Rules](https://help.sap.com/docs/abap-cloud/abap-keyword/assignment-and-conversion-rules?locale=en-US), [Lossless Assignments](https://help.sap.com/docs/abap-cloud/abap-keyword/lossless-assignments?locale=en-US).

## Numeric Processing

Choose numeric types from business precision and range, not convenience. Verify:

- operand and calculation type of the complete expression,
- decimal scaling and rounding point,
- overflow/division-by-zero behavior,
- whether binary floating-point is acceptable,
- whether `EXACT` is required for a lossless calculation or assignment, and
- boundary values with production-scale data.

Prefer arithmetic expressions and current numeric functions. Obsolete calculation statements are not a production design target.

Source: [Numeric Calculations](https://help.sap.com/docs/abap-cloud/abap-keyword/numeric-calculations?locale=en-US).

## Character and Byte Processing

Character-like and byte-like data follow different processing and comparison contracts. Verify the operand type, trailing-blank behavior, encoding boundary, case/text environment, regex flavor, offset/length units, and catchable exceptions.

For repeated string growth, use only compiler-optimizable append forms inside loops. SAP documents direct optimization for forms such as `str &&= dobj1 && dobj2` and a template beginning with the target followed by directly specified data objects. Method calls, expressions, repeated target use, or formatting the target can disable optimization and make loop runtime grow quadratically. Compute dynamic expressions into helper variables before appending, or use an appropriate stream/buffer design for large output.

Sources: [Character String and Byte String Processing](https://help.sap.com/docs/abap-cloud/abap-keyword/character-string-and-byte-string-processing?locale=en-US), [String Expression Performance Note](https://help.sap.com/docs/abap-cloud/abap-keyword/string-exp-performance-note?locale=en-US).

## Internal Table Design

An internal table type defines line type, table category, and table key. Select all three from measured usage:

- access by index versus key,
- full-key versus left-aligned partial-key lookup,
- uniqueness requirements,
- stable sorted traversal,
- append/insert/delete frequency,
- expected line count and line width,
- mutation after initial load, and
- required secondary access paths.

Do not default every table to `STANDARD TABLE WITH EMPTY KEY`. Do not add sorted, hashed, or secondary keys without an access pattern that uses them.

### Access and Key Gates

- Sorted-table free-key access is optimized when the complete key or an initial key section is supplied; lookup is logarithmic.
- Hashed-table optimized lookup requires the complete table key; resource consumption is constant on average as documented by SAP.
- Secondary keys improve reads but consume memory and maintenance time. They fit tables populated once and changed rarely better than mutation-heavy tables.
- Explicitly select the intended key for reads, loops, deletes, and expressions when multiple keys exist.
- Verify not-found and duplicate-key behavior for the chosen statement/expression; do not infer it from another access form.

### Mutation, Memory, and Transport

- Prefer `APPEND` over `INSERT` when building a standard table in append order; it avoids logical-index maintenance.
- Prefer block operations over line-by-line work when the statement supports a line range or table operation.
- Use selective transport when wide/deep components need not be copied.
- Inserting/deleting away from the end of an index table can create and maintain a logical index with substantial time and memory cost.
- Deleting rows usually does not release internal-table memory. Use the semantically appropriate `CLEAR` or `FREE` only when memory release is actually needed and lifetime measurements justify it.
- Same-typed table assignment can initially use table sharing; write access triggers copy-on-write. Do not assume assignment always creates an immediate full copy, or that later mutation is free.
- Let the runtime choose the initial block size unless a measured nested-small-table case justifies `INITIAL SIZE`.

Sources: [Internal Tables](https://help.sap.com/docs/abap-cloud/abap-keyword/internal-tables?locale=en-US), [Internal Table Processing](https://help.sap.com/docs/abap-cloud/abap-keyword/internal-tables-itab?locale=en-US), [Internal Table Performance Notes](https://help.sap.com/docs/abap-cloud/abap-keyword/itab-performance-notes?locale=en-US).

## Date, Time, and Timestamp Contract

- ABAP dates use the Gregorian calendar and are generally interpreted as local dates.
- Times are local times in 24-hour form unless converted with an explicit time-zone contract.
- ABAP timestamps represent UTC reference time; conversion to/from local date and time depends on time-zone rules, including daylight-saving transitions.
- Do not combine a local date and time without naming the applicable time zone.
- Test ambiguous and missing local times at daylight-saving transitions, leap-day/month-end boundaries, initial/invalid values, and precision loss between short and long timestamps.
- Persist and exchange global instants as timestamps where the business contract requires an instant; convert for display at the boundary.

Source: [Date, Time, Time Stamp, and Time Zones](https://help.sap.com/docs/abap-cloud/abap-keyword/date-time-time-stamp-and-time-zones?locale=en-US).

## Structures, Enumerations, and Meshes

- For whole or corresponding structure assignments, verify component mapping, deep components, conversion, and lossless requirements explicitly.
- Prefer enumerated types when the domain is closed and target-release support is verified; do not bypass enum conversion/comparison rules with unchecked representation assumptions.
- A mesh is a special structure whose nodes are structured internal tables or references to them. Mesh associations express semantic relationships evaluated through mesh paths.
- Treat a mesh node as a normal structure component when no mesh path is used. For path use, verify association conditions, cardinality/result shape, missing relationships, mutation semantics, and performance with realistic node sizes.

Source: [Meshes](https://help.sap.com/docs/abap-cloud/abap-keyword/meshes?locale=en-US).

## Data Object Introspection

Use static typing when the contract is known. Use `DESCRIBE` or RTTS only when runtime introspection is genuinely required. For generic operations:

- distinguish type description from data-object state,
- validate casts and assignability before mutation,
- cache repeated type descriptions only when profiling justifies it, and
- verify every RTTS class/method is released for the target ABAP Cloud environment.

Source: [Properties of Data Objects](https://help.sap.com/docs/abap-cloud/abap-keyword/properties-of-data-objects?locale=en-US).

## Streaming

Streams are class instances characterized by direction (reader/writer) and type (character/binary); filter streams can transform data between boundaries. Use streaming when incremental transfer avoids materializing a large complete value, but verify:

- released interfaces/classes in the target system,
- character encoding versus binary handling,
- ownership and close/finalization behavior,
- chunk and error semantics,
- maximum memory under backpressure or buffering, and
- whether ABAP SQL streaming has separate transaction/resource constraints.

Source: [Streaming](https://help.sap.com/docs/abap-cloud/abap-keyword/streaming?locale=en-US).

## Validation Checklist

- Exact release/language version and API state verified
- Source/target types and implicit conversions identified
- Loss, rounding, overflow, invalid-value, and exception behavior tested
- Internal-table category and primary/secondary keys justified by access pattern
- Lookup, mutation, memory, and copy behavior measured at realistic volume
- String growth in loops checked for optimizer-compatible form
- Trailing blanks, encoding, regex, and text-environment behavior tested
- UTC/local time and daylight-saving boundary cases tested
- Generic assignments/casts guarded by runtime compatibility checks
- Mesh paths and streams tested for result shape, resource lifetime, and failure behavior
