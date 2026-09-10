# SAP Workflow — Classic SWDD, Flexible, and SAP Build PA

Sources: SAP Help Portal, SAP Community.

## 1. Decision Matrix (Apply First)

| Scenario | Type | Why |
|---|---|---|
| PO / PR / FI document approvals in S/4HANA | **Flexible Workflow** | Pre-delivered scenarios, Fiori-configurable |
| Custom approval beyond delivered scenarios | **Flexible + SWDD_SCENARIO** | Extend scenario, configure in Fiori |
| Complex: loops, branches, custom logic | **Classic SWDD** | Full ABAP control |
| Cross-system (S/4 + Ariba + SuccessFactors) | **SAP Build Process Automation** | Multi-system, low-code |
| Public Cloud — standard approvals | **Flexible Workflow** | Only available model |
| Public Cloud — cross-system | **SAP Build Process Automation** | No SWDD in Public Cloud |
| Private Cloud — any scenario | **All three** | Full access |

**Quick rule:** Flexible first → if insufficient, SWDD → if cross-system, Build PA.

## 2. Flexible Workflow

### What It Is
Scenario-based extension of SAP Business Workflow coded for S/4HANA. Uses pre-delivered WS7… templates. Business experts configure approval steps in Fiori without ABAP coding.

### Prerequisites
1. Activate workflow environment (SWU3 equivalent for S/4HANA)
2. SPRO: SAP NetWeaver → Business Management → SAP Business Workflow → Scenario Activation → activate WS7… scenarios
3. Assign Fiori roles for Manage Workflows app
4. Employees linked as Business Partners

### Configure via Fiori
1. Launchpad → search **"Manage Workflows for Purchase Orders"** (or PR, FI, etc.)
2. Create workflow: name, valid-from/to dates
3. Define **start conditions** (company code, amount, doc type)
4. Add **approval steps**: single or multi-level, parallel or sequential
5. Set **recipients** (users, roles, org units, or BAdI-based)
6. **Activate** → test with real document

### Custom Scenarios (SWDD_SCENARIO)
- Transaction `SWDD_SCENARIO` to create new workflow scenarios
- These appear in Fiori Manage Workflows apps
- Requires ABAP/workflow expertise; day-to-day config stays Fiori-based

## 3. Classic Business Workflow (SWDD)

### When to Use
- Approval workflows not covered by Flexible scenarios
- Multi-branch, loops, heavy custom logic
- Full container/binding/event control
- Integrating with custom ABAP apps or legacy ECC workflows

### Key Transactions
| TCode | Purpose |
|---|---|
| SWDD | Workflow Builder — design templates |
| SWDD_SCENARIO | Scenario Editor (for Flexible Workflow extension) |
| SWU3 | Automatic workflow customizing |
| SWI1 | Workflow Log — monitor workflows |
| SWIA | Work item administration |
| PFTC | Task catalog |
| PPOMW | Organizational management (agents) |

### Development Steps
1. SWDD → Create workflow template (WS number)
2. Define start event (business object + event)
3. Add steps: User Decision, Activity (TS task), Fork, Condition, Loop
4. Define container elements (data flow between steps)
5. Configure agent determination (role, org unit, rule PFAC)
6. SWU3 → verify environment → Test

## 4. SAP Build Process Automation (BPA)

### When to Use
- Workflows spanning multiple SAP and non-SAP systems
- Low-code / citizen developer modeling
- Public Cloud with cross-system orchestration
- Business rules management alongside workflow

### Architecture
- Runs on **SAP BTP**
- Connects to S/4HANA via OData/REST (BTP destinations)
- Work items visible in **SAP Task Center** (unified inbox)
- Drag-and-drop process builder + automation bots

## 5. Anti-Patterns
- SWDD for simple standard approvals — use Flexible Workflow
- Flexible Workflow via SWDD in Public Cloud — configure in Fiori only
- Multi-system workflow in SWDD — use Build PA
- No My Inbox role assignment — users cannot see work items
- No SWU3 activation — workflows fail at runtime
## SAP Help Evidence Links

<!-- sap-help-evidence:added -->
- https://help.sap.com/docs/SAP_S4HANA_CLOUD
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abenabap.htm
- https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model
- https://help.sap.com/docs/abap-cloud/abap-data-models/abap-data-models
