---
name: abapgit-and-branch-workflows
description: 'Manage ABAP development with abapGit and Git. Use for repository setup, clone, pull, push, branching, .abapgit.xml, abaplint, CI/CD, gCTS, and transport-versus-Git workflow decisions for on-premise or BTP systems.'
---

# abapGit and Branch Workflows

Use this skill as the ABAP Git workflow router. Load only the relevant section of [the complete workflow reference](./_legacy/abap-git-workflows/references/workflows-complete.md).

## Workflow

1. Establish landscape, repository ownership, package, transport policy, and deployment path.
2. Decide between abapGit, native Git/gCTS, transports, or a governed hybrid.
3. Read only the matching reference section.
4. Verify branch, serialization, object ownership, CI checks, and rollback before changing repository state.

## Reference Routing

| Need | Reference section |
|---|---|
| Install, setup, clone, package link | Quick Start |
| `.abapgit.xml` | Repository Configuration |
| Branches and pull requests | Branching Strategy |
| Pull, push, merge conflict | Pull/Push Operations |
| abaplint or GitHub Actions | CI/CD Integration |
| Git plus SAP transports | Hybrid Workflow |
| Failures | Troubleshooting |
| Technology selection | Decision Matrix |

## Gates

- Verify the target platform actually supports the recommended Git mechanism.
- Do not treat Git as a replacement for required SAP transport and deployment controls.
- Preserve package and object ownership, serialization compatibility, and rollback paths.
- Never include credentials or tokens in repository configuration or examples.

