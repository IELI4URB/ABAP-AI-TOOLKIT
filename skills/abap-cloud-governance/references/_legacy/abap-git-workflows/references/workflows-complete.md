---
name: abap-git-workflows
description: Manage ABAP development with abapGit — repository setup, cloning, branching strategies, .abapgit.xml configuration, transport-vs-git workflows, and CI/CD integration for on-premise and BTP systems.
---

# abapGit Workflows for ABAP Development

Complete guide to managing ABAP development objects in Git repositories using **abapGit** — covering repository setup, cloning, branching strategies, configuration, and CI/CD integration. Use this skill for on-premise S/4HANA systems (ECC/S/4HANA) and SAP BTP ABAP Environment.

> **Key:** abapGit bridges ABAP and Git, enabling modern version control and CI/CD for ABAP without SAP transports. On BTP, use gCTS or cTMS; on-premise, abapGit is the primary Git integration.

---

## Quick Start: Setup & Clone

### 1. Install abapGit (On-Premise)

**Via ABAP:**
1. Open SE24 → Class Browser
2. Create a new class or download `zcl_abapgit_standalone` from GitHub
3. Run the class via SE38 (Report abapGit_starter)
4. Follow web UI for repository management

**Via ADT (Recommended for BTP):**
- BTP includes native Git support in ADT
- Use `Clone Repository` in ADT Git view
- No separate abapGit installation needed

### 2. Clone a Repository

**From Web UI (On-Premise abapGit):**
```
1. Go to abapGit instance: http://localhost:8000/sap/bc/zcl_abapgit_standalone/go
2. Click "New Repository"
3. Paste GitHub URL: https://github.com/user/my-abap-repo.git
4. Select branch, package, and click "Pull"
5. Confirm import; abapGit fetches objects into ABAP system
```

**From ADT (BTP/On-Premise):**
```
1. Team > Clone Repository
2. Enter Git URL
3. Select local branch (main/develop)
4. Choose target ABAP package
5. Finish — ADT clones into ABAP Packages
```

### 3. Create & Link Local Package

**On-Premise with abapGit:**
```abap
" In abapGit web UI:
- Create ABAP package (e.g., ZMY_PROJECT)
- Go to abapGit > Repositories
- Link package to existing Git repo
- Clone/pull objects into package
```

**BTP with ADT:**
```
- File > New > ABAP Cloud Project
- Choose existing Git repository
- ADT auto-creates package structure
- Objects are Git-tracked immediately
```

---

## Repository Configuration: .abapgit.xml

The `.abapgit.xml` file controls how abapGit serializes and deserializes ABAP objects. Store this in your Git repo root.

### Minimal Configuration

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_DEVC" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <DATA>
    <DOTABAPGIT>
     <MASTER_LANGUAGE>E</MASTER_LANGUAGE>
     <STARTING_FOLDER>/src/</STARTING_FOLDER>
     <FOLDER_LOGIC>PREFIX</FOLDER_LOGIC>
     <IGNORE>
      <item>/.gitignore</item>
      <item>/LICENSE</item>
      <item>/README.md</item>
     </IGNORE>
    </DOTABAPGIT>
   </DATA>
  </asx:values>
 </asx:abap>
</abapGit>
```

> **Note:** `.abapgit.xml` and `apack.xml` are two different files. `apack.xml` is a separate ABAP Package Manager manifest — do not confuse the two schemas.

### Advanced Configuration

**Ignore patterns:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<abapgit>
  <ignore>
    <folder>/.git</folder>
    <folder>/src/local</folder>
    <pattern>.*\.json$</pattern>
    <pattern>^ZCUSTOM_TEST.*</pattern>
  </ignore>
</abapgit>
```

**Folder structure (for complex projects):**
```xml
<folders>
  <folder>
    <prefix>Z</prefix>
    <path>src/Z*</path>
  </folder>
  <folder>
    <prefix>Y</prefix>
    <path>src/Y*</path>
  </folder>
</folders>
```

**Serialization options:**
```xml
<abapgit>
  <serialize>
    <delete_folder_contents>true</delete_folder_contents>
    <ignore_deletes>false</ignore_deletes>
  </serialize>
</abapgit>
```

---

## Branching Strategy: Trunk-Based Development

Recommended for ABAP teams using abapGit.

### Branch Structure

```
main                  ← Production-ready code (CI/CD tested)
  ↑
feature-branches      ← Development (short-lived, max 2 weeks)
  - feature/odata-v4-service
  - feature/rap-bo-redesign
  - feature/performance-fix
```

### Workflow

**1. Create feature branch from main:**
```bash
git checkout main
git pull origin main
git checkout -b feature/my-feature
```

**2. Develop in ABAP (on-premise or BTP):**
- Create/modify objects in ABAP package
- In ADT/BTP, changes do **not** auto-commit — you must explicitly commit via **Team → Commit** in Eclipse. The staging view shows which objects are modified and ready to commit.
- Push to feature branch regularly

**3. Push to Git:**
```bash
# On-premise (manual push from abapGit UI):
- Go to abapGit Repository > Pull/Push
- Select "Push" → commits to feature branch

# BTP (ADT auto-syncs):
- Team > Commit (Ctrl+Shift+Q)
- Enter commit message
- Team > Push
```

**4. Create Pull Request:**
```
GitHub/GitLab: feature/my-feature → main
- Trigger CI/CD pipeline (abaplint)
- Await code review
- Merge after approval
```

**5. Merge to main:**
```bash
# After PR approval:
git checkout main
git merge feature/my-feature
git push origin main
# CI/CD auto-runs ATC, abaplint, tests
# Auto-deploy to productive transport if passing
```

---

## Pull/Push Operations

### Pull (Clone/Update from Git)

**Workflow:**
1. Fetch latest code from Git repository
2. abapGit compares Git commits with ABAP objects
3. Deserializes files → creates/updates ABAP objects
4. Resolves conflicts (merge logic)

**Steps (on-premise):**
```
abapGit Web UI > Repositories > [Your Repo]
  ↓
  Click "Pull"
  ↓
  Select branch (main, develop, feature/xyz)
  ↓
  abapGit compares commits & ABAP state
  ↓
  [Conflict? → Resolve or abort]
  ↓
  Import objects into ABAP package
  ↓
  "Pull completed" message
```

### Push (Commit ABAP → Git)

**Workflow:**
1. Compare ABAP objects in package vs. Git history
2. Serialize changed objects to files
3. Commit message (generated or custom)
4. Push to Git branch

**Steps (on-premise):**
```
abapGit Web UI > Repositories > [Your Repo]
  ↓
  Click "Staging" (review changes)
  ↓
  Select objects to commit (checkboxes)
  ↓
  Click "Commit" → enter message
  ↓
  Push to branch
  ↓
  "Commit pushed to origin/[branch]"
```

### Merge Conflicts

**Scenario:** Same object modified in Git and ABAP.

**Resolution (on-premise abapGit):**
```
Pull → Merge conflict detected
  ↓
  abapGit shows:
    - Git version (from .xml file)
    - ABAP version (from system)
    - Incoming/Outgoing changes
  ↓
  Choose:
    [Keep ABAP] [Accept Git] [Manual Merge]
  ↓
  Resolve → Import result
```

**Best practice:** Avoid conflicts via:
- Short-lived feature branches
- Frequent pulls from main
- Clear object ownership (who modifies what)

---

## CI/CD Integration: abaplint + GitHub Actions

Automate code quality checks before merge.

### Setup abaplint

**Install globally:**
```bash
npm install @abaplint/cli -g
```

**Create `.abaplintrc.json` in repo root:**
```json
{
  "global": {
    "files": ["/src/**/*.abap"],
    "ignore": ["/src/local/**/*.abap"]
  },
  "rules": {
    "indentation": {
      "severity": "error",
      "expected": 2
    },
    "max_one_statement_per_line": {
      "severity": "error"
    },
    "naming_conventions": {
      "severity": "error",
      "patternKind": "required",
      "pattern": "^(Z|Y)[A-Z_]{0,29}$"
    },
    "parser_missing_space": {
      "severity": "error"
    },
    "unused_variables": {
      "severity": "warning"
    }
  }
}
```

### GitHub Actions Workflow

**File: `.github/workflows/abaplint.yml`**
```yaml
name: ABAP Lint

on:
  push:
    branches: [main, develop, 'feature/**']
  pull_request:
    branches: [main]

jobs:
  abaplint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install abaplint
        run: npm install @abaplint/cli -g

      - name: Run abaplint
        id: abaplint
        run: |
          npx abaplint --output-file abaplint-results.json || echo "abaplint_failed=true" >> $GITHUB_OUTPUT

      - name: Comment abaplint results
        if: always() && hashFiles('abaplint-results.json') != ''
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const results = fs.readFileSync('abaplint-results.json', 'utf8');
            await github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '### abaplint Results\n```\n' + results + '\n```'
            });
```

**Run locally:**
```bash
abaplint

# Outputs summary of issues:
# - Parser errors
# - Naming convention violations
# - Unused variables
# - Max line length violations
```

---

## Hybrid Workflow: Git + Transport

Combine abapGit with traditional SAP transports for production safety.

### Scenario: On-Premise S/4HANA with Transport Requirements

**Architecture:**
```
[Development System]
   ↓ Git Push
[Git Repository] ← CI/CD triggers
   ↓ Transport Request Created
[QA System] ← Transport deployed
   ↓ Approval + Tests
[Production System] ← Final transport
```

**Workflow:**

1. **Develop in Dev system with abapGit:**
   ```
   Create feature branch in Git
   ↓
   Develop in ABAP (Dev package)
   ↓
   abapGit push to feature/my-feature
   ```

2. **Create transport request (manual or CI/CD):**
   ```bash
   # Manual (SE10):
   - Create transport request in Dev
   - Add ABAP objects to transport
   - Release transport
   
   # CI/CD (optional):
   - GitHub Actions detects merge to main
   - Calls ABAP RFC to create transport
   - Auto-populate with objects from git
   ```

3. **Export transport to QA:**
   ```
   SE01 > Transport > Release
   ↓
   stmsctrl -t RELEASE -r "/usr/sap/trans/data/[transport].cofile"
   ↓
   Transport moved to QA queue
   ```

4. **Pull in QA system:**
   ```
   stmsctrl -t IMPORT -r "/usr/sap/trans/incoming/[transport]"
   ↓
   ABAP objects updated in QA
   
   (Optional) abapGit pull to sync Git state
   ```

---

## Best Practices

### Do ✅

- **Commit frequently** — Small, logical commits (one feature = one commit)
- **Write clear messages** — "Add RAP BO for sales order" not "fix"
- **Branch for each feature** — `feature/`, `bugfix/`, `docs/` prefixes
- **Pull before push** — Avoid conflicts: `git pull origin [branch]`
- **Test locally** — Run abaplint before push
- **Code review** — Require PR approval before merge
- **Automate checks** — CI/CD pipeline runs abaplint, ATC on every PR

### Don't ❌

- **Push to main directly** — Always use feature branches
- **Commit test data** — Use `.abapgitignore` for local objects
- **Mix features** — One branch = one feature
- **Force push** — Never `git push --force` on shared branches
- **Commit generated code** — Only hand-written code belongs in Git
- **Ignore conflicts** — Resolve merge conflicts carefully

---

## Troubleshooting

### Conflict: Object exists in Git but not ABAP

**Cause:** Object was deleted in ABAP, but Git still has it.

**Solution:**
```
abapGit Pull > Conflict
  ↓
  Choose: [Delete from Git] or [Recreate in ABAP]
  ↓
  Resolve → Commit
```

### Push fails: "Objects differ"

**Cause:** Git and ABAP state mismatch (object modified offline).

**Solution:**
1. Pull latest from Git: `git pull origin main`
2. Pull in abapGit to sync ABAP
3. Resolve conflicts
4. Push again

### Feature branch stuck in ABAP

**Cause:** Objects modified in feature but merged to main in Git.

**Solution:**
1. Delete feature package in ABAP (SE15)
2. Switch branch: `git checkout feature/xyz`
3. Pull again in abapGit to recreate objects
4. Continue development

---

## Reference: Git Commands (Terminal)

```bash
# Setup
git clone https://github.com/user/my-abap-repo.git
cd my-abap-repo

# Branching
git checkout main
git checkout -b feature/my-feature
git branch -a                        # List branches

# Push/Pull
git pull origin main                 # Fetch & merge
git fetch origin                     # Fetch without merge
git push origin feature/my-feature   # Push changes

# Commit
git add .
git commit -m "Add RAP BO for travel"
git log --oneline                    # View commit history

# Merge (via PR on GitHub preferred)
git checkout main
git merge feature/my-feature
git push origin main

# Stash (temporary save)
git stash                            # Save work in progress
git stash pop                        # Restore work
```

---

## Decision Matrix: abapGit vs. Transport vs. gCTS

| Factor | abapGit | Transport (SE01) | gCTS (BTP) |
|--------|---------|-----------------|-----------|
| System | On-premise S/4HANA | On-premise | BTP ABAP Cloud |
| Version Control | ✅ Full Git history | ❌ Limited | ✅ Native Git |
| CI/CD | ✅ Easy integration | ⚠️ Manual steps | ✅ Native |
| Branching | ✅ Full support | ❌ No branches | ✅ Recommended |
| Learning Curve | Medium | Low | Medium |
| Cross-account transport | ❌ No | ✅ Yes (RFC) | ✅ Yes (cTMS) |

---

## References

- GitHub: https://github.com/abapGit/abapGit
- abapGit Docs: http://abapgit.org/
- SAP Help: Transport Management System (stmsctrl)
- abaplint Rules: https://rules.abaplint.org/


## Unified Response Contract

For non-trivial requests, respond using this minimum structure:
1. Context and landscape assumptions (Public Cloud, Private Cloud ABAP Cloud, or BTP ABAP Environment)
2. Recommended approach with rationale and Clean Core impact
3. Implementation outline (objects, APIs, contracts, and constraints)
4. Validation plan (tests, checks, and rollback considerations)
5. Evidence and risk notes (source references, version sensitivity, and open assumptions)

Hard rules:
- Do not invent SAP objects, APIs, CDS entities, annotations, or transactions.
- Prefer released APIs and upgrade-safe extension mechanisms.
- Flag version-sensitive guidance explicitly when release context is uncertain.

## Trigger-to-Action Matrix

| If user asks about | Then prioritize |
|---|---|
| Architecture or design trade-offs | decision matrix + constraints + target-state blueprint |
| New implementation | modeling flow + API contract + test strategy |
| Performance issue | hotspot isolation + pushdown/pagination/index strategy |
| Security or authorization | threat points + authorization model + hardening controls |
| Integration behavior | protocol contract + resilience patterns + observability |
| Code review or readiness | findings first + risk ranking + concrete remediation steps |


## SAP Help Syntax Grounding (Mandatory)

For ABAP/CDS/BDL/EML syntax, use SAP Help as source of truth.

Rules:
- Do not provide unverified syntax for ABAP statements, CDS DDL, behavior definitions, EML, or RAP annotations/options.
- For non-trivial syntax responses, add a short "Syntax references" section with SAP Help links used.
- If exact syntax is uncertain, explicitly mark it as draft and require SAP Help verification.
- Never invent statement additions, annotation names, or behavior options.

Core SAP Help references:
- https://help.sap.com/doc/abapdocu_latest_index_htm/latest/en-US/index.htm
- https://help.sap.com/docs/ABAP_Cloud
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/cbb86e63a8464e63bbdd43b7bfa5fc4f.html
- https://help.sap.com/docs/ABAP_Cloud/bbcee501b99848bdadecd4e290db3ae4/404edb8b4c0648dca4d8f5a2fdfa6c58.html
- https://help.sap.com/docs/ABAP_Cloud/f055b8bf582d4f34b91da667bc1fcce6/c35896101f8c417482fd040d477bbbe1.html

Syntax verification steps:
1. Validate keywords and clause names against ABAP Keyword Documentation terminology.
2. Validate RAP strict mode and BDEF/BDL constructs against RAP docs.
3. Validate CDS form and annotation usage against CDS docs.
4. Validate EML operation form and response handling pattern.
5. Reconfirm clean-core and released-object constraints.
Syntax output contract (mandatory when providing ABAP/CDS/BDL/EML syntax):
1. Add `Syntax confidence` with exactly one value: `verified`, `partial`, or `draft`.
2. Add `Syntax references` with SAP Help links for each non-trivial syntax area used.
3. If confidence is `partial` or `draft`, add `Verification required` with unresolved syntax items.
4. Do not provide final production code when confidence is `draft`.
