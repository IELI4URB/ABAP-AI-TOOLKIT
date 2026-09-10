# IAM and Authorization Architecture for ABAP Cloud

## Objective

Design end-to-end authorization for ABAP Cloud solutions across RAP, CDS, IAM business roles, and external integration identities.

## Prerequisites

- Baseline understanding of RAP behavior definitions and CDS access control.
- Familiarity with modules 01, 04, 09, and 17.
- Confirm target landscape constraints in module 17 before modeling roles.

## Landscape Scope

- Public Cloud: prefer business role/catalog governance and strict released-scope services.
- Private Cloud (ABAP Cloud): same model, plus migration controls for inherited classic authorization objects.
- BTP ABAP Environment: emphasize identity federation and service-to-service trust boundaries.

## SAP Reference & Standards

- ABAP Cloud Authorization Concepts: https://help.sap.com/docs/abap-cloud
- RAP Authorization: https://help.sap.com/docs/abap-cloud/abap-rap
- SAP Identity and Access Management: https://help.sap.com/docs

---

## Authorization Layers

| Layer | Scope | Typical Mechanism |
|---|---|---|
| UI/App access | App launch and page-level access | Business catalog/role assignment |
| Service access | Entity/action exposure | Service binding + communication arrangement |
| Business object access | BO-level and instance-level authorization | RAP global and instance checks |
| Data row/field access | Record and field restrictions | CDS access control / field control |

## Decision Matrix: Where to Enforce

| Requirement | Preferred Layer | Why |
|---|---|---|
| Who can open app | IAM business role | Central and auditable |
| Who can execute action | RAP action authorization | Business-context aware |
| Who can see specific records | CDS/RAP instance checks | Data-level enforcement |
| Who can update sensitive fields | Field-level control | Least privilege |

---

## RAP Authorization Pattern

```abap
define behavior for ZI_TravelTP alias Travel
  authorization master ( global )
{
  field ( authorization: update ) Cost;
  action ( features: instance ) ApproveTravel result [1] $self;
}
```

Guidance:
- Implement global checks for BO-level operations.
- Implement instance checks for ownership or organizational scope.
- Protect sensitive fields explicitly.

---

## Integration Identities

### Inbound
- Use communication users/scenarios for system-to-system calls.
- Restrict technical identities to minimum required scopes.

### Outbound
- Prefer token-based trust over static credentials.
- Rotate secrets and certificates by policy.
- Keep identity mapping documented for audit.

---

## Segregation of Duties (SoD)

- Separate create/approve/release responsibilities where required by policy.
- Prevent same user from performing conflicting high-risk actions.
- Define SoD exceptions with explicit time-bound approval.

## SoD Conflict Matrix Template

| Function A | Function B | Conflict? | Risk | Control |
|---|---|---|---|---|
| Create supplier invoice | Approve supplier invoice | Yes | Fraud and unauthorized payment | Separate roles + workflow approval |
| Maintain vendor master | Release payment run | Yes | Master data manipulation | Independent approver required |
| Create travel | Approve own travel | Yes | Self-approval bypass | Instance check + manager approval |
| Read audit logs | Delete audit logs | Yes | Evidence tampering | Deletion forbidden in productive scope |

Guidance:
- Keep SoD controls in policy and in executable checks (RAP action auth, workflow conditions).
- For approved exceptions, require expiry date, approver, and compensating monitoring.

## Role Engineering Workflow

1. Identify business capabilities and sensitive actions.
2. Map each action to least-privilege role scopes.
3. Define RAP global and instance authorization rules.
4. Bind service exposure to communication scenarios for technical users.
5. Execute SoD check and log unresolved conflicts.
6. Validate with positive/negative authorization tests before release.

## Authorization Test Strategy

| Test Category | Example | Expected Outcome |
|---|---|---|
| Global authorization | User without display role reads travel | Access denied |
| Instance authorization | User reads another user's travel | Access denied |
| Field authorization | Unauthorized update to sensitive cost field | Update rejected |
| Action authorization | Unauthorized ApproveTravel action | Action forbidden |
| Technical user scope | Outbound user calls disallowed service | Request blocked |
| SoD scenario | Same user tries create + approve | Approval blocked |

## IAM Artifact Templates

### Role-to-Permission Matrix

| Role | Service Entity/Action | Data Scope | Constraints |
|---|---|---|---|
| TRAVEL_REQUESTER | Travel.Create, Travel.Read | Own records | No approve/release |
| TRAVEL_APPROVER | Travel.ApproveTravel | Team records | Cannot create own approval candidates |
| TRAVEL_AUDITOR | Travel.Read, Audit.Read | Org-wide read | No write actions |

### Time-Bound Exception Record

| Exception ID | Conflict | Approved By | Valid Until | Compensating Control |
|---|---|---|---|---|
| EXC-2026-001 | Create + Approve overlap | Security board | 2026-12-31 | Weekly audit review |

## Failure Mode and Recovery

- Failure mode: authorization gaps found in testing or audit.
- Immediate response: block transport, classify as high severity, add remediation ticket.
- Recovery: implement missing RAP/CDS checks, retest with negative cases, re-run review gate.
- Exception policy: only temporary waivers with named owner and expiry; never waive critical SoD conflicts without compensating control.

---

## IAM Governance Checklist

- [ ] IAM role-to-permission matrix documented
- [ ] RAP global + instance authorization implemented
- [ ] Sensitive fields protected with explicit field authorization
- [ ] Technical users scoped to least privilege
- [ ] Access recertification process defined
- [ ] SoD conflict checks integrated into review process
- [ ] Authorization test cases included in ABAP Unit/integration tests
- [ ] SoD exception register implemented with expiry and approver
- [ ] Role-to-permission matrix versioned with release documentation
- [ ] Identity mapping for inbound/outbound integrations documented