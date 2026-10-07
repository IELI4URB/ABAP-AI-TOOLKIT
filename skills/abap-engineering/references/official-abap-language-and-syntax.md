# Official ABAP Language, Syntax, and Terminology Guide

Use this guide to interpret ABAP Keyword Documentation and to avoid turning documentation notation or demo code into unsupported production syntax.

## Keyword Documentation Syntax Notation

- Uppercase text denotes ABAP words/keywords.
- Lowercase terms denote operands/placeholders.
- Punctuation and operators shown normally are part of the language syntax.
- Italic square brackets denote optional syntax; literal square brackets in code styling remain real syntax.
- Italic vertical bars denote alternatives and bind immediate neighbors.
- Italic curly braces group alternatives; literal braces in code styling remain real syntax.
- `...` means additional syntax can occur at that position.
- Diagrams use a semantically consistent valid order, but some statements permit other orders not shown.

Source: [ABAP Syntax Conventions](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-syntax-conventions?locale=en-US).

## Language Topic Map

Use the owning Keyword Documentation section for the question:

- syntax elements and program structure
- ABAP Objects
- data types/data objects and built-in constructors/functions
- operands, declarations, and value/object creation
- procedure calls and program flow
- internal-data processing
- database access and data interchange
- language environment/program maintenance
- enhancements and authorizations
- security notes and obsolete elements

Source: [ABAP Programming Language](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-programming-language?locale=en-US).

## Production Use Rule

Keyword Documentation examples explain syntax and semantics. They are not production solutions and can use demo artifacts that are not released for ABAP for Cloud Development.

For every example adapted into code:

1. Verify target ABAP release and effective language version.
2. Verify every referenced repository object and API state in the target system.
3. Replace demo artifacts and hard-coded assumptions with owned contracts.
4. Add authorization, validation, error, volume, transaction, and test behavior.
5. Activate and run focused tests.

Do not label syntax `verified` merely because a similar example exists.

## Syntax Verification Contract

A non-trivial syntax answer must identify:

- exact target release/FPS and language version
- statement/object-specific SAP Help topic
- all release-sensitive additions used
- unresolved API/object availability
- `Syntax confidence: verified | partial | draft`

`verified` requires that the documented construct exists for the target release and that referenced object contracts were inspected. `partial` means syntax is grounded but one or more target contracts remain unverified. `draft` blocks production code.

## Obsolescence and Modernization

- Treat topics explicitly marked obsolete as maintenance-only unless the target release leaves no supported migration path.
- Prefer the documented successor, but verify semantic differences rather than applying textual replacement.
- Run where-used, syntax, ATC, tests, and performance checks after modernization.
- For CDS, prefer view entities over obsolete DDIC-based CDS views in new development.

Source: [Obsolete Language Elements](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-obsolete-language-elements?locale=en-US).

## Glossary Discipline

Use the [ABAP Glossary](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-glossary?locale=en-US) to disambiguate terms before design or debugging, especially:

- internal table versus DDIC database table versus CDS table entity
- CDS entity versus DDL source versus CDS-managed database artifact
- release contract versus release state versus language-version visibility
- RAP BO versus root/entity/BDEF/behavior pool/business service
- SAP LUW versus RAP transactional phase/transactional buffer
- ABAP SQL versus AMDP/SQLScript

When a user term is ambiguous, state the normalized SAP term and the chosen interpretation.

## Release-News Gate

The latest documentation can describe syntax newer than the user's system. Use [ABAP Release News](https://help.sap.com/docs/abap-cloud/abap-keyword/abap-release-news?locale=en-US) to map the construct to an ABAP release, then map that release to the product/kernel/FPS. Never use publication date or the word "latest" as target-system evidence.
