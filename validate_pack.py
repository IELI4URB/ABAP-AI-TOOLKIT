from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SKILLS = ROOT / "skills"
AGENTS = ROOT / "agents"
CLAUDE_AGENTS = ROOT / "claude-agents"
CONFIG = ROOT / "config"
EXPECTED_AGENT_NAMES = {
    "abap-cloud-routing-and-handoff",
    "abap-cloud-analyzer",
    "abap-cloud-designer",
    "abap-cloud-developer",
    "abap-cloud-reviewer",
    "abap-classic-developer",
    "abap-ecc-to-s4hana-migration",
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    try:
        end = lines.index("---", 1)
    except ValueError:
        return {}
    fields: dict[str, str] = {}
    for line in lines[1:end]:
        match = re.match(r"^([A-Za-z][A-Za-z0-9-]*):\s*(.*)$", line)
        if match:
            fields[match.group(1)] = match.group(2).strip().strip("'\"")
    return fields


def local_links(text: str) -> list[str]:
    return re.findall(r"\]\((?!https?://|mailto:|#)([^)#]+)(?:#[^)]*)?\)", text)


def validate_skills(errors: list[str]) -> set[str]:
    group_map = json.loads(read(CONFIG / "skill-group-map.json"))["groups"]
    integrity = json.loads(read(CONFIG / "skill-group-integrity.json"))["packages"]
    expected_groups = set(group_map)
    skill_files = sorted(SKILLS.glob("*/SKILL.md"))
    actual_groups = {path.parent.name for path in skill_files}

    if actual_groups != expected_groups:
        errors.append(
            f"Skill groups differ: missing={sorted(expected_groups - actual_groups)}, "
            f"extra={sorted(actual_groups - expected_groups)}"
        )
    if len(expected_groups) != 11:
        errors.append(f"Expected 11 groups, found {len(expected_groups)}")

    legacy_names = [name for members in group_map.values() for name in members]
    if len(legacy_names) != 44 or len(legacy_names) != len(set(legacy_names)):
        errors.append("Group map must preserve 44 unique former skills")
    if set(integrity) != set(legacy_names):
        errors.append("Integrity package names differ from group map")

    nested_skills = sorted(SKILLS.glob("*/*/SKILL.md"))
    for nested in nested_skills:
        errors.append(f"Nested registered SKILL.md: {nested.relative_to(ROOT)}")

    for skill_file in skill_files:
        metadata = frontmatter(read(skill_file))
        if metadata.get("name") != skill_file.parent.name:
            errors.append(f"Skill name mismatch: {skill_file.relative_to(ROOT)}")
        if not metadata.get("description"):
            errors.append(f"Missing skill description: {skill_file.relative_to(ROOT)}")

    for legacy, record in integrity.items():
        group = record["group"]
        guide = SKILLS / group / "references" / f"{legacy}.md"
        module = SKILLS / group / "references" / legacy
        if not guide.exists():
            errors.append(f"Missing adapted guide: {guide.relative_to(ROOT)}")
        for relative, expected_hash in record["files"].items():
            archived = module / ("source-SKILL.md" if relative == "SKILL.md" else relative)
            if not archived.exists():
                errors.append(f"Missing archived file: {archived.relative_to(ROOT)}")
            elif sha256(archived) != expected_hash.lower():
                errors.append(f"Archived hash mismatch: {archived.relative_to(ROOT)}")
        if (SKILLS / legacy).exists():
            errors.append(f"Former top-level skill remains: {legacy}")

    official_guides = (
        SKILLS / "abap-cloud-governance" / "references" / "official-abap-cloud-apis-and-releases.md",
        SKILLS / "abap-rap-services" / "references" / "official-ddic-cds-rap-semantics.md",
        SKILLS / "abap-engineering" / "references" / "official-abap-language-and-syntax.md",
        SKILLS / "abap-security" / "references" / "official-cds-access-control.md",
        SKILLS / "abap-data-performance" / "references" / "official-ddic-cds-data-access.md",
    )
    for guide in official_guides:
        if not guide.exists():
            errors.append(f"Missing official ABAP Keyword guide: {guide.relative_to(ROOT)}")

    crawl_report = ROOT / "docs" / "ABAP_KEYWORD_CRAWL_REPORT.md"
    crawler = ROOT / "scripts" / "ingest_abap_keyword_docs.py"
    if not crawl_report.exists() or not crawler.exists():
        errors.append("Missing ABAP Keyword crawl report or reproducible ingestion script")
    else:
        report_text = read(crawl_report)
        if "Unique pages retrieved: **4962**" not in report_text:
            errors.append("ABAP Keyword crawl report does not prove 4,962-page coverage")
        if "Failed pages: **0**" not in report_text:
            errors.append("ABAP Keyword crawl report contains failures")

    forbidden_guidance = {
        "C0 is internal": "C0 is an extension contract",
        "Use in Cloud Development | **C1**": "Cloud visibility is separate from C1",
        "will inherit the restriction": "CDS DCL does not automatically propagate",
        "[C0 — not released]": "C0 is a valid extension contract",
    }
    for markdown in SKILLS.rglob("*.md"):
        text = read(markdown)
        for marker, reason in forbidden_guidance.items():
            if marker in text:
                errors.append(
                    f"Obsolete guidance in {markdown.relative_to(ROOT)}: {marker} ({reason})"
                )

    return expected_groups


def validate_agents(errors: list[str], expected_groups: set[str]) -> None:
    agent_files = sorted(AGENTS.glob("*.agent.md"))
    agent_names = {path.name.removesuffix(".agent.md") for path in agent_files}
    if agent_names != EXPECTED_AGENT_NAMES:
        errors.append(
            f"Copilot agents differ: missing={sorted(EXPECTED_AGENT_NAMES - agent_names)}, "
            f"extra={sorted(agent_names - EXPECTED_AGENT_NAMES)}"
        )

    for agent_file in agent_files:
        metadata = frontmatter(read(agent_file))
        if metadata.get("name") != agent_file.name.removesuffix(".agent.md"):
            errors.append(f"Agent name mismatch: {agent_file.relative_to(ROOT)}")
        if not metadata.get("description"):
            errors.append(f"Missing agent description: {agent_file.relative_to(ROOT)}")

    router_text = read(AGENTS / "abap-cloud-routing-and-handoff.agent.md")
    match = re.search(r"(?m)^agents:\s*\[(.*?)\]", router_text)
    declared = {item.strip() for item in match.group(1).split(",")} if match else set()
    expected_delegates = EXPECTED_AGENT_NAMES - {"abap-cloud-routing-and-handoff"}
    if declared != expected_delegates:
        errors.append("Routing-agent allowlist does not match six specialists")

    legacy_names = {
        name
        for members in json.loads(read(CONFIG / "skill-group-map.json"))["groups"].values()
        for name in members
    }
    for agent_file in agent_files:
        text = read(agent_file)
        for legacy in legacy_names:
            if re.search(rf"(?<![a-z0-9-]){re.escape(legacy)}(?![a-z0-9-])", text):
                errors.append(f"{agent_file.name} references former skill {legacy}")
        mentioned_groups = {
            group for group in expected_groups
            if re.search(rf"(?<![a-z0-9-]){re.escape(group)}(?![a-z0-9-])", text)
        }
        if agent_file.name != "abap-cloud-routing-and-handoff.agent.md" and not mentioned_groups:
            errors.append(f"{agent_file.name} does not route to a grouped skill")

    claude_files = sorted(
        path for path in CLAUDE_AGENTS.glob("*.md") if path.name != "README.md"
    )
    claude_names = {path.stem for path in claude_files}
    if claude_names != EXPECTED_AGENT_NAMES:
        errors.append(
            f"Claude mirrors differ: missing={sorted(EXPECTED_AGENT_NAMES - claude_names)}, "
            f"extra={sorted(claude_names - EXPECTED_AGENT_NAMES)}"
        )
    for claude_file in claude_files:
        metadata = frontmatter(read(claude_file))
        if metadata.get("name") != claude_file.stem:
            errors.append(f"Claude agent name mismatch: {claude_file.relative_to(ROOT)}")
        if not metadata.get("description") or not metadata.get("tools"):
            errors.append(f"Incomplete Claude frontmatter: {claude_file.relative_to(ROOT)}")


def validate_links(errors: list[str]) -> None:
    for markdown in ROOT.rglob("*.md"):
        for target in local_links(read(markdown)):
            resolved = markdown.parent / target.replace("%20", " ")
            if not resolved.exists():
                errors.append(f"Broken link in {markdown.relative_to(ROOT)}: {target}")


def validate_installers(errors: list[str]) -> None:
    for installer in (ROOT / "install.ps1", ROOT / "install.sh"):
        text = read(installer)
        if "11" not in text or "7" not in text:
            errors.append(f"Installer lacks expected-count guards: {installer.name}")
        if ".sap-dev-ai-toolkit-manifest" not in text:
            errors.append(f"Installer lacks managed-item manifest: {installer.name}")


def main() -> int:
    errors: list[str] = []
    groups = validate_skills(errors)
    validate_agents(errors, groups)
    validate_links(errors)
    validate_installers(errors)

    if errors:
        print("Pack validation FAILED")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("Pack validation PASSED")
    print("Validated 11 skill groups, 44 archived skill packages, 7 Copilot agents, and 7 Claude mirrors.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
