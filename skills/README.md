# Grouped Skills

Only the 11 directories containing a top-level `SKILL.md` are registered skills.

Each group uses this structure:

```text
group-name/
  SKILL.md
  references/
    former-skill-name.md
    former-skill-name/
      source-SKILL.md
      references/
      scripts/
      assets/
```

- `former-skill-name.md` is the adapted guide loaded by the group router.
- `source-SKILL.md` preserves the exact former entry point.
- Supporting references, scripts, and assets preserve their original relative structure.
- Repository file `config/skill-group-map.json` is the authoritative 44-to-11 mapping.

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
