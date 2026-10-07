# Official ABAP Program Flow Logic Guide

This guide synthesizes the complete [ABAP - Program Flow Logic](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-program-flow-logic?locale=en-US) subtree reviewed on 2026-10-07: **130 topics / 59,877 words** with zero crawl failures. It provides production decision rules without copying SAP page bodies.

## Scope Map

| Branch | Topics | Use it for |
|---|---:|---|
| Expressions and Functions for Conditions | 59 | comparisons, predicates, Boolean operators/functions, truth evaluation |
| Exception Handling | 33 | class-based exceptions, `TRY`, `CATCH`, `CLEANUP`, raise/retry/resume, runtime errors |
| Control Structures | 18 | sequences, `IF`, `CASE`, `DO`, `WHILE`, nesting and loop exits |
| Iteration Expressions | 11 | `FOR`, table comprehensions, conditional iteration, `REDUCE` |
| Conditional Expressions | 6 | `COND`, `SWITCH`, result typing and `THROW` |
| Program Interruption | 2 | `WAIT UP TO` and its runtime/transaction effects |

## Working Rule

Before changing flow logic, identify:

1. Exact ABAP release and language version.
2. Processing-block boundary and the target of every early exit.
3. Evaluation order, side effects, catchable exceptions, and result type of each condition/expression.
4. Loop bounds, progress invariant, collection mutation, and termination behavior.
5. Exception category, handler ownership, cleanup obligations, retry limit, and caller contract.
6. Transaction/session effects of statements that wait, leave, commit, or terminate.

Syntax validity does not prove termination, side-effect safety, catchability, transactional correctness, or readable intent.

## Conditions and Logical Expressions

A logical expression consists of relational expressions combined using `NOT`, `AND`, `OR`, and `EQUIV`. Implicit precedence is:

1. `NOT`
2. `AND`
3. `OR`
4. `EQUIV`

Within a parenthesis level, evaluation is left to right and stops when the overall result is known. Dynamic operands and functional methods in skipped relational expressions are not evaluated.

Apply these rules:

- Add parentheses when business intent is not immediately obvious, even when precedence would produce the same result.
- Order guards so unsafe or expensive operands appear only after prerequisites that short-circuit them.
- Do not hide important state changes in functional methods used as condition operands. Methods inside one relational expression execute left to right and inside to outside before that relation is evaluated.
- Verify comparison type and conversion rules; assignment and comparison rules are not interchangeable.
- Use predicates such as `IS INITIAL`, `IS BOUND`, `IS INSTANCE OF`, `IS SUPPLIED`, and table/string predicate functions only for their documented operand contracts.
- ABAP logical-expression results are not native Boolean data objects. Choose `xsdbool`, `boolc`, or `boolx` only after checking the required representation and trailing-blank behavior.

Sources: [Expressions and Functions for Conditions](https://help.sap.com/docs/abap-cloud/abap-keyword/expressions-and-functions-for-conditions?locale=en-US), [Logical Expressions](https://help.sap.com/docs/abap-cloud/abap-keyword/logical-expressions-log-exp?locale=en-US), [Boolean Operators and Parentheses](https://help.sap.com/docs/abap-cloud/abap-keyword/log-exp-boolean-operators-and-parentheses?locale=en-US).

## Branches

- `IF`/`ELSEIF` conditions are tested from top to bottom; at most one statement block executes.
- `CASE` tests `WHEN` alternatives from top to bottom and executes the first match. Its operand and comparison operands follow their documented calculation/comparison typing.
- Prefer `CASE` for one stable discriminator and constant alternatives; avoid functional-method side effects in `WHEN` operands because they can change values used by later comparisons.
- Use `CASE TYPE OF` only when runtime subtype distinction is the actual design contract; prefer polymorphism when behavior belongs to the subtype.
- Use `COND` or `SWITCH` when a branch produces one value in an operand position. Use statement branches when multiple commands, mutations, or error-handling steps are involved.

Sources: [Control Structures](https://help.sap.com/docs/abap-cloud/abap-keyword/control-structures?locale=en-US), [IF](https://help.sap.com/docs/abap-cloud/abap-keyword/if?locale=en-US), [CASE](https://help.sap.com/docs/abap-cloud/abap-keyword/case?locale=en-US).

## Loops and Exit Scope

- `DO n TIMES` evaluates the maximum pass count when entering the loop; later changes to the source expression do not change that bound. A value less than or equal to zero executes no passes.
- `DO` without a bound requires an explicit, testable progress invariant and exit path.
- `WHILE` evaluates its logical expression before every pass. Ensure the body changes state toward termination on every reachable path.
- `sy-index` belongs to the current `DO`/`WHILE` loop; nested loops replace its relevant current-loop value.
- `CONTINUE` ends only the current loop pass and starts the next pass.
- `EXIT` inside a loop exits that loop and continues after its closing statement. Outside a loop it exits the processing block, but SAP recommends using it only for loops.
- `CHECK` inside a loop acts as a pass guard. Outside a loop, a false condition exits the current processing block and passes procedure output parameters like a regular exit.
- Prefer `RETURN` for an explicit procedure exit and guard clauses whose scope should be obvious.

For nested loops, document or refactor any exit whose target is not visually obvious. Test zero-pass, one-pass, maximum-bound, non-progress, and nested-exit cases.

Sources: [DO](https://help.sap.com/docs/abap-cloud/abap-keyword/do?locale=en-US), [WHILE](https://help.sap.com/docs/abap-cloud/abap-keyword/while?locale=en-US), [CONTINUE](https://help.sap.com/docs/abap-cloud/abap-keyword/continue?locale=en-US), [EXIT](https://help.sap.com/docs/abap-cloud/abap-keyword/exit-loop?locale=en-US), [CHECK](https://help.sap.com/docs/abap-cloud/abap-keyword/check-processing-block?locale=en-US).

## Conditional Expressions

`COND` selects by logical conditions; `SWITCH` selects by a discriminator. A selected result is converted to the expression result type when needed. A selected branch may use `THROW` to raise a class-based exception; `THROW SHORTDUMP` deliberately raises a runtime error.

- Make the result type explicit when inference or numeric calculation types could surprise the caller.
- Ensure every domain value has an intentional branch. Use `ELSE THROW` for invalid states when silent initial/default output would violate the contract.
- Do not use `THROW SHORTDUMP` for recoverable business or integration failures.
- Keep branch operands free of unrelated side effects; only the selected result is required for the result.

Sources: [Conditional Expressions](https://help.sap.com/docs/abap-cloud/abap-keyword/conditional-expressions?locale=en-US), [COND/SWITCH Results](https://help.sap.com/docs/abap-cloud/abap-keyword/cond-switch-result?locale=en-US).

## Iteration Expressions

`FOR` is available inside relevant `VALUE`, `NEW`, and `REDUCE` constructor expressions. Conditional iteration uses `UNTIL` or `WHILE`; table iteration uses `IN`. `REDUCE` requires at least one iteration expression.

Use iteration expressions when they express a bounded value construction or reduction more clearly than a statement loop. Keep a statement loop when the work requires multiple side effects, complex exception recovery, tracing, early exits, or mutation whose order must be obvious.

- Verify the generated result type, row count, ordering, grouping, and duplicate behavior.
- Check that conditional iteration always progresses toward termination.
- Treat nested `FOR` expressions as multiplicative work and test realistic cardinalities.
- Local iteration and `LET` helper variables are scoped to iteration expressions; do not design later statements around them.
- In `REDUCE`, make accumulator initialization, type, update order, and empty-input result explicit.

Sources: [Iteration Expressions](https://help.sap.com/docs/abap-cloud/abap-keyword/iteration-expressions?locale=en-US), [FOR](https://help.sap.com/docs/abap-cloud/abap-keyword/for-iteration-expressions?locale=en-US).

## Class-Based Exception Flow

Catchable exceptions are class-based and can be raised by the runtime, `RAISE EXCEPTION`, or `THROW`. Uncatchable exceptions and uncaught catchable exceptions terminate processing with a runtime error/short dump.

### TRY and CATCH

- Keep a `TRY` block as narrow as the operation whose documented failures are handled.
- Order exception classes from subclasses to superclasses, both within one `CATCH` and across handlers. A handler also catches subclasses of every listed class.
- Catch only exceptions the current layer can translate, compensate, retry, enrich, or report meaningfully. Otherwise propagate them according to the procedure contract.
- Use `INTO` when exception attributes, text, previous exception, or logging context are needed.
- By default, the raising context is unwound before `CATCH` executes. `BEFORE UNWIND` preserves it temporarily and is chiefly required for resumable exception handling; it is not a routine logging pattern.

### CLEANUP

A `CLEANUP` block runs when an exception from its `TRY` block is handled by an outer `TRY`, immediately before the raising context is deleted. It does not act like an unconditional `finally` block.

- Use it to restore consistency or release resources inaccessible to an outer handler.
- It must complete normally so propagation can continue; exceptions raised during cleanup must be handled inside the cleanup block.
- If a resumable exception is resumed without deleting the context, the cleanup block is not executed.

### RETRY and RESUME

- `RETRY` restarts the complete current `TRY` block from its `CATCH`. Remove the failure cause and enforce a finite attempt policy; otherwise it can loop forever.
- `RESUME` is only valid for a resumable exception handled with `CATCH BEFORE UNWIND` and continues after the raising location. Use it only where the resumed operation has a documented consistent state.
- Preserve causal chains using the exception contract rather than replacing the original failure without context.

Sources: [Exception Handling](https://help.sap.com/docs/abap-cloud/abap-keyword/exception-handling?locale=en-US), [TRY](https://help.sap.com/docs/abap-cloud/abap-keyword/try?locale=en-US), [CATCH](https://help.sap.com/docs/abap-cloud/abap-keyword/catch?locale=en-US), [CLEANUP](https://help.sap.com/docs/abap-cloud/abap-keyword/cleanup?locale=en-US), [RETRY](https://help.sap.com/docs/abap-cloud/abap-keyword/retry?locale=en-US).

## WAIT UP TO Is a Transaction Boundary

`WAIT UP TO sec SECONDS` interrupts execution, changes the work process, sets `sy-subrc` to 0, and triggers a database commit every time it executes. It must not be placed between ABAP SQL statements that open and close a database cursor.

Therefore:

- Do not use `WAIT UP TO` as an in-LUW retry delay or generic polling sleep.
- Before using it, prove that committing the current database LUW is intended and that locks/cursors/state remain valid.
- Prefer an application job, asynchronous/event-driven design, or framework-approved retry scheduling when waiting crosses a business transaction.
- Test commit visibility, lock release, duplicate processing, cancellation, and restart behavior.

Source: [WAIT UP TO](https://help.sap.com/docs/abap-cloud/abap-keyword/wait-up-to?locale=en-US).

## Validation Checklist

- Exact release and language version verified
- Condition precedence, evaluation order, conversions, and side effects reviewed
- Every branch has an intentional domain outcome
- Loop bound/progress invariant and each exit target tested
- Constructor iterations checked for cardinality, ordering, accumulator type, and memory
- Exception hierarchy and handler order verified
- Catch scope limited to recoverable/translated failures
- Cleanup and resource ownership proven for propagation paths
- Retry/resume behavior bounded and state-safe
- `WAIT UP TO` database commit and work-process effects explicitly accepted
- Zero/one/many, invalid-state, exception, cancellation, and transaction-boundary tests included
