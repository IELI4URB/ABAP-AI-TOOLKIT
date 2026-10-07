# ABAP Agent and Skill Routing

## Role Flow

```text
Analyzer -> Designer -> Developer -> Reviewer
                 |          |
                 |          +-> Classic Developer for Standard/ECC ownership
                 +-> Migration specialist for ECC-to-S/4 work
```

`abap-cloud-routing-and-handoff` coordinates governed multi-phase work and delegates one bounded task to one specialist.

## Object-Group Routing

| Request signal | Primary skill group |
|---|---|
| CDS, RAP BO, BDEF, EML, OData, Fiori Elements, API version, events | `abap-rap-services` |
| Authorization, DCL, IAM, input validation, secrets, sensitive data | `abap-security` |
| REST/SOAP/RFC/Event Mesh/AIF, retry, exceptions, logging | `abap-integration` |
| Application Jobs, workflow, approvals, BRFplus, My Inbox | `abap-process-automation` |
| SQL, AMDP, database/query performance, pagination, graph traversal | `abap-data-performance` |
| Writing/refactoring, Clean ABAP, OOP, tests, review, released classes | `abap-engineering` |
| Clean Core, release state, platform release, ATC, transports, Git | `abap-cloud-governance` |
| Adobe Forms, PDF, ADS, XDP/XSD, templates, output | `abap-forms` |
| Dumps, object research, ADT, Basis, SPRO, workbooks, system reports | `sap-system-operations` |
| FI, MM, PP/DS, SD, TM business behavior | `sap-business-domains` |
| ATQ, delegation, approvals, recovery, skill discovery | `agentic-delivery` |

## Constraints

- Keep the selected group primary and normally add no more than two companions.
- Read only the matching guide under the group's `references/` directory.
- Domain skill guides own business semantics; technical groups own implementation contracts.
- Shared agent policies are under `agents/references/` and must not be copied into every agent.
- Connected-system object creation uses the ADT MCP guide inside `sap-system-operations`.
- Reviewer owns the final definition-of-done and release-readiness verdict.
