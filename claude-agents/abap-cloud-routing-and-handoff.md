## Multi-Agent Operating Model

Use the specialist agents in this order when it reduces risk or uncertainty:
1. `abap-cloud-analyzer`
2. `abap-cloud-designer`
3. `abap-cloud-developer`
4. `abap-cloud-reviewer`

Escalation rule:
- Start with analyzer when the request is ambiguous, risky, cross-domain, or missing constraints.
- Move to designer when the problem is understood but the architecture is not yet fixed.
- Move to developer when the design is approved and implementation is next.
- Move to reviewer before merge, release, or sign-off.

Cross-agent handoff protocol:
- If reviewer blocks, send the findings back to developer when the issue is implementation-specific.
- If reviewer blocks architecture or contract assumptions, send the findings back to designer.
- If the issue is feasibility, scope, or missing constraints, send it back to analyzer.
- Each handoff should include severity, affected artifacts, the concrete correction, and whether the blocker is functional, technical, security, performance, or release-related.

Functional routing:
- PP requests: ground the business domain in `sap-pp` first.
- MM requests: ground the business domain in `sap-mm` first.
- SD requests: ground the business domain in `sap-sd` first.
- Finance requests: ground the business domain in `sap-finance` first.
- TM requests: ground the business domain in `sap-tm` first.
- Mixed functional plus ABAP work: ground the domain first, then use ABAP Cloud architecture and delivery skills.

Specialized review signals:
- Security/authorization changes must be checked before coding and again at review time.
- Performance-sensitive changes must be checked for volume, N+1, pushdown, and pagination at design, build, and review time. Use `abap-performance-hana` for S/4HANA/HANA systems and `abap-performance-ecc` for ECC/traditional-DB systems.
- Integration work must include retry, idempotency, failure classification, and observability.
- Application jobs must be designed and reviewed for scheduling, restart-safety, and idempotency.
- Transport and release work must include rollback and handover evidence.
- Any new class, method, or feature must apply `abap-code-writing` before coding and `clean-abap` standards throughout.
- System exploration or unfamiliar codebase work must load `abap-research` before analysis.
- Customizing or SPRO-related analysis must load `sap-customizing` to trace config tables.
- ADT API or REST endpoint investigation must load `adt-api-discovery`.
- Production incidents, short dumps, job failures, AIF errors, lock conflicts, or authorization errors must load `abap-production-issues` first.
- When the user asks about abapGit, branching strategy, or transport-vs-git, load `abap-git-workflows`.
- When the user asks what released classes or APIs are available, load `abap-released-classes`.
- When the request spans an entire Clean Core solution end-to-end, load `sap-clean-core-enterprise`.
- When the request is anchored in SAP Public Cloud ABAP quick-start, naming, or BDEF baseline, load `sap-cloud-dev`.
- When the request requires multi-agent orchestration or subagent delegation decisions, load `cavecrew`.
- When the user asks for new skills, capabilities, or automation support not yet available, load `find-skills`.

Evidence-first handoff requirement:
- Before handing off to any next specialist agent, include:
1. Exact artifacts inspected.
2. Reproduction attempts and dataset used.
3. Evidence-backed root cause candidates with confidence.
4. Rejected alternatives.
5. Explicit blocked-by list if evidence is incomplete.
- Do not hand off assumption-only findings.

Object-contract handoff requirement:
- For requests involving code or test generation, include contract verification evidence in handoff:
1. Behavior or API signature artifacts reviewed.
2. Parameter and result type checks completed.
3. Field-level data-type and key-linking verification notes.
4. Any unresolved contract artifacts blocking final output.
5. Caller-callee dependency checks for class-to-class, interface, FM, RAP, CDS, and API interactions.

Anti-vague handoff requirement:
- Handoff notes must include a concrete interim diagnosis, not only data requests.
- If requesting runtime evidence, include exact variable capture list and explicit decision outcomes that will be concluded from the capture.
- Do not hand off with generic phrases such as "needs more context" without listing inspected artifacts and rejected alternatives.
