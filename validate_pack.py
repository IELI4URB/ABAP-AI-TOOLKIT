from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SKILLS = ROOT / "skills"
AGENTS = ROOT / "agents"
CLAUDE_AGENTS = ROOT / "claude-agents"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def frontmatter(text: str) -> str | None:
    if not text.startswith("---"):
        return None
    parts = text.split("---", 2)
    return parts[1] if len(parts) == 3 else None


def validate_skills(errors: list[str]) -> None:
    for skill_dir in sorted(path for path in SKILLS.iterdir() if path.is_dir()):
        skill_file = skill_dir / "SKILL.md"
        if not skill_file.exists():
            errors.append(f"Missing SKILL.md: {skill_dir.relative_to(ROOT)}")
            continue
        metadata = frontmatter(read(skill_file))
        if metadata is None:
            errors.append(f"Missing frontmatter: {skill_file.relative_to(ROOT)}")
            continue
        name = re.search(r"(?m)^name:\s*['\"]?([^'\"\r\n]+)", metadata)
        if not name or name.group(1).strip() != skill_dir.name:
            errors.append(f"Skill name mismatch: {skill_file.relative_to(ROOT)}")
        if not re.search(r"(?m)^description:\s*\S", metadata):
            errors.append(f"Missing skill description: {skill_file.relative_to(ROOT)}")


def validate_agents(errors: list[str]) -> None:
    agent_files = sorted(AGENTS.glob("*.agent.md"))
    agent_names = {path.name.removesuffix(".agent.md") for path in agent_files}
    for agent_file in agent_files:
        metadata = frontmatter(read(agent_file))
        if metadata is None:
            errors.append(f"Missing agent frontmatter: {agent_file.relative_to(ROOT)}")
        elif not re.search(r"(?m)^description:\s*\S", metadata):
            errors.append(f"Missing agent description: {agent_file.relative_to(ROOT)}")

    router = read(AGENTS / "abap-cloud-routing-and-handoff.agent.md")
    declared_match = re.search(r"(?m)^agents:\s*\[(.*?)\]", router)
    if not declared_match:
        errors.append("Routing agent has no agents list")
    else:
        for name in (item.strip() for item in declared_match.group(1).split(",")):
            if name not in agent_names:
                errors.append(f"Routing agent references missing agent: {name}")

    expected_claude = {f"{name}.md" for name in agent_names}
    claude_files = sorted(CLAUDE_AGENTS.glob("*.md"))
    actual_claude = {path.name for path in claude_files}
    for name in sorted(expected_claude - actual_claude):
        errors.append(f"Missing Claude agent mirror: {name}")
    for claude_file in claude_files:
        metadata = frontmatter(read(claude_file))
        if metadata is None:
            errors.append(f"Missing Claude agent frontmatter: {claude_file.relative_to(ROOT)}")
        elif not re.search(r"(?m)^description:\s*\S", metadata):
            errors.append(f"Missing Claude agent description: {claude_file.relative_to(ROOT)}")

    claude_router = read(CLAUDE_AGENTS / "abap-cloud-routing-and-handoff.md")
    if "atq-principles" not in claude_router:
        errors.append("Claude routing agent does not reference atq-principles")
    for stale_name in ("abap-performance-ecc", "abap-performance-hana"):
        if stale_name in claude_router:
            errors.append(f"Claude routing agent references stale skill: {stale_name}")


def validate_links(errors: list[str]) -> None:
    pattern = re.compile(r"\[[^\]]+\]\((?!https?://|mailto:|#)([^)#]+)(?:#[^)]+)?\)")
    for markdown in ROOT.rglob("*.md"):
        for target in pattern.findall(read(markdown)):
            resolved = markdown.parent / target.replace("%20", " ")
            if not resolved.exists():
                errors.append(f"Broken link in {markdown.relative_to(ROOT)}: {target}")


def main() -> int:
    errors: list[str] = []
    validate_skills(errors)
    validate_agents(errors)
    validate_links(errors)
    if errors:
        print("Pack validation FAILED")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("Pack validation PASSED")
    print(f"Validated {len(list(SKILLS.glob('*/SKILL.md')))} skills and {len(list(AGENTS.glob('*.agent.md')))} agents.")
    return 0


if __name__ == "__main__":
    sys.exit(main())