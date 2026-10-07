# Grouped Skills

Only the 11 directories containing a top-level `SKILL.md` are registered skills.

Each group uses this structure:

```text
group-name/
  SKILL.md
  references/
    README.md
    active-guide.md
    _legacy/
      former-package-name/
      source-SKILL.md
      references/
      scripts/
      assets/
```

- `SKILL.md` is the only registered entry point.
- `references/README.md` states active ownership and routing boundaries.
- Direct Markdown files in `references/` are active guides loaded by the group router.
- `_legacy/` preserves exact former packages and must not be routed to or edited.
- The pack's `skill-group-map.json` is the authoritative 44-to-11 mapping.

## Groups

- `abap-rap-services`
- `abap-security`
- `abap-integration`
- `abap-process-automation`
- `abap-data-performance`
- `abap-engineering`
- `abap-cloud-governance`
- `abap-forms`
- `sap-system-operations`
- `sap-business-domains`
- `agentic-delivery`

Do not add a new top-level skill folder when an existing object group owns the subject. Add a guide under that group's `references/` directory and update its routing table.
