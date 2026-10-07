---
name: sap-basis-compilation-guides
description: 'Find and apply SAP Basis administration guidance with evidence-first troubleshooting. Use for SAP Basis tips, tutorials, troubleshooting guides, system administration, startup or shutdown, work processes, profiles, transports, RFC, ICM, locks, updates, dumps, monitoring, or when the user references the SAP Basis Compilation Guides or ITsiti page.'
argument-hint: '[Basis issue, symptom, system, or administration topic]'
user-invocable: true
disable-model-invocation: false
---

# SAP Basis Guide Discovery and Troubleshooting

Use this skill to turn a Basis administration question into a scoped, evidence-backed investigation and an operationally safe answer.

## Source Boundary

The source page is a landing page for SAP Basis administration tips, tutorials, and troubleshooting guides. It contains no individual procedures, commands, prerequisites, or fixes. SAP labels it as **Additional Content**, not Documentation under the applicable SAP terms.

Read [source-notes.md](./references/source-notes.md) before citing or characterizing the source. Never attribute a specific technical procedure to this landing page.

## Workflow

1. Establish the environment:
   - Product and exact release or support package
   - Operating system and database
   - Single system, distributed system, or high-availability setup
   - Development, quality, or production tier
2. Capture the symptom:
   - Exact error text, return code, timestamp, affected instance, and user
   - Reproduction steps and business impact
   - Recent transports, patches, profile changes, restarts, or infrastructure changes
3. Classify the topic before searching:
   - Availability and instance lifecycle
   - Work processes, jobs, locks, updates, and dumps
   - Connectivity, RFC, HTTP, ICM, gateway, and message server
   - Users, authorizations, certificates, and secure communication
   - Transports, upgrades, patches, and maintenance
   - Database, storage, performance, monitoring, and housekeeping
4. Gather read-only evidence first. Prefer logs, traces, monitoring output, configuration values, and timestamps over assumptions. Redact credentials, tokens, personal data, and private host details.
5. Research in authority order:
   - Product-specific SAP Help documentation for the exact release
   - Applicable SAP Notes, Knowledge Base Articles, and security notes
   - SAP support content, including the Basis Compilation Guides landing page
   - Community or external articles only as supplementary evidence
6. Verify that every proposed command, transaction, parameter, and file path applies to the stated release and topology. Do not infer applicability from a similarly named product.
7. Present the result as:
   - Likely cause and confidence
   - Evidence supporting or contradicting it
   - Lowest-risk diagnostic step
   - Remediation with prerequisites and expected result
   - Validation and rollback steps
   - Sources, clearly distinguishing official documentation from additional content

## Safety Rules

- Do not recommend production changes without identifying impact, backup or rollback, and required authorization.
- Do not restart services, terminate processes, delete files, clear queues, unlock users, or change profiles as an exploratory step.
- Separate diagnostic commands from mutating commands and label them clearly.
- Ask for missing release or topology details when they materially change the procedure.
- Treat external links and copied commands as untrusted until verified against SAP guidance for the target system.

## Response Standard

Keep the answer operational: state assumptions, provide the shortest discriminating checks first, and stop when evidence invalidates the current hypothesis. If authoritative guidance cannot be found, say so and provide a safe escalation package containing the symptom, timestamps, affected components, relevant logs, recent changes, and attempted checks.