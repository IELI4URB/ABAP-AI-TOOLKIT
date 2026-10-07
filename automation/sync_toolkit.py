from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable


EXPECTED_REMOTE = "https://github.tools.sap/I756261/ABAP-DEVELOPMENT-AI-TOOLKIT"
BRANCH = "main"
MANIFEST_NAME = ".sap-dev-ai-toolkit-manifest"
STATE_VERSION = 1


@dataclass(frozen=True)
class Roots:
    repository: Path
    canonical_skills: Path
    runtime_skills: Path
    canonical_agents: Path
    runtime_agents: Path


@dataclass(frozen=True)
class Change:
    area: str
    relative_path: str
    selected_hash: str | None
    source: str


class SyncError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    home = Path.home()
    default_repository = Path(__file__).resolve().parents[1]
    local_state = Path(os.environ.get("LOCALAPPDATA", home)) / "ABAP-DEVELOPMENT-AI-TOOLKIT"
    parser = argparse.ArgumentParser(
        description="Synchronize managed ABAP skills and Copilot agents with Git safely."
    )
    parser.add_argument("--repository", type=Path, default=default_repository)
    parser.add_argument(
        "--skill-pack",
        type=Path,
        default=home / ".agents" / "skill-packs" / "SAP-ABAP-Cloud-Skills",
    )
    parser.add_argument(
        "--runtime-skills",
        type=Path,
        default=home / ".agents" / "skills",
    )
    parser.add_argument(
        "--runtime-agents",
        type=Path,
        default=home / ".copilot" / "agents",
    )
    parser.add_argument("--state", type=Path, default=local_state / "sync-state.json")
    parser.add_argument("--log", type=Path, default=local_state / "sync.log")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-push", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--allow-dirty", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--skip-fetch", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--expected-remote", default=EXPECTED_REMOTE, help=argparse.SUPPRESS)
    parser.add_argument(
        "--message",
        default=f"Sync local skills and agents {datetime.now():%Y-%m-%d %H:%M}",
    )
    return parser.parse_args()


class Logger:
    def __init__(self, path: Path) -> None:
        self.path = path
        path.parent.mkdir(parents=True, exist_ok=True)

    def write(self, message: str) -> None:
        line = f"{datetime.now():%Y-%m-%d %H:%M:%S} {message}"
        print(line)
        with self.path.open("a", encoding="utf-8") as stream:
            stream.write(line + "\n")


def run(
    command: list[str],
    *,
    cwd: Path,
    check: bool = True,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=env,
        encoding="utf-8",
        errors="replace",
    )
    if check and result.returncode:
        output = result.stdout.strip()
        raise SyncError(f"Command failed ({result.returncode}): {' '.join(command)}\n{output}")
    return result


def git(repository: Path, *arguments: str, check: bool = True) -> str:
    environment = os.environ.copy()
    environment["GIT_TERMINAL_PROMPT"] = "0"
    return run(
        ["git", *arguments], cwd=repository, check=check, env=environment
    ).stdout.strip()


def file_hash(path: Path) -> str:
    content = path.read_bytes()
    try:
        text = content.decode("utf-8-sig")
        if "\x00" in text:
            raise UnicodeDecodeError("utf-8", content, 0, 1, "NUL byte")
        normalized = text.replace("\r\n", "\n").replace("\r", "\n")
        content = normalized.encode("utf-8")
    except UnicodeDecodeError:
        pass
    return hashlib.sha256(content).hexdigest().upper()


def collect_files(root: Path, relative_roots: Iterable[str]) -> dict[str, str]:
    files: dict[str, str] = {}
    for relative_root in relative_roots:
        target = root / Path(relative_root)
        if target.is_file():
            files[Path(relative_root).as_posix()] = file_hash(target)
            continue
        if not target.exists():
            continue
        for path in target.rglob("*"):
            if not path.is_file() or path.name == MANIFEST_NAME:
                continue
            relative_path = path.relative_to(root)
            if "_legacy" in relative_path.parts:
                continue
            files[relative_path.as_posix()] = file_hash(path)
    return files


def load_state(path: Path) -> dict[str, dict[str, str]] | None:
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("version") != STATE_VERSION:
        raise SyncError(f"Unsupported synchronization state version in {path}")
    return {
        "skills": dict(data.get("skills", {})),
        "agents": dict(data.get("agents", {})),
    }


def save_state(path: Path, skills: dict[str, str], agents: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    payload = {
        "version": STATE_VERSION,
        "updated": datetime.now().isoformat(timespec="seconds"),
        "skills": dict(sorted(skills.items())),
        "agents": dict(sorted(agents.items())),
    }
    temporary.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def acquire_lock(path: Path) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        try:
            process_id = int(path.read_text(encoding="ascii").strip())
            os.kill(process_id, 0)
        except (OSError, ValueError):
            path.unlink(missing_ok=True)
        else:
            raise SyncError(f"Another synchronization run is active: PID {process_id}")
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as error:
        raise SyncError(f"Another synchronization run is active: {path}") from error
    os.write(descriptor, str(os.getpid()).encode("ascii"))
    return descriptor


def release_lock(path: Path, descriptor: int | None) -> None:
    if descriptor is None:
        return
    os.close(descriptor)
    path.unlink(missing_ok=True)


def normalize_remote(url: str) -> str:
    return url.strip().removesuffix(".git").rstrip("/").lower()


def verify_repository(
    repository: Path,
    *,
    expected_remote: str,
    allow_dirty: bool,
    skip_fetch: bool,
) -> None:
    if not (repository / ".git").is_dir():
        raise SyncError(f"Not a Git repository: {repository}")
    branch = git(repository, "branch", "--show-current")
    if branch != BRANCH:
        raise SyncError(f"Automatic synchronization requires branch '{BRANCH}', found '{branch}'")
    remote = git(repository, "remote", "get-url", "origin")
    if normalize_remote(remote) != normalize_remote(expected_remote):
        raise SyncError(f"origin must be {expected_remote}, found {remote}")
    status = git(repository, "status", "--porcelain")
    if status and not allow_dirty:
        raise SyncError("Repository has uncommitted changes; automatic synchronization stopped")
    if skip_fetch:
        return
    git(repository, "fetch", "--prune", "origin")
    counts = git(repository, "rev-list", "--left-right", "--count", f"HEAD...origin/{BRANCH}")
    ahead, behind = (int(value) for value in counts.split())
    if ahead and behind:
        raise SyncError("Local and remote main branches diverged; resolve them manually")
    if behind:
        git(repository, "pull", "--ff-only", "origin", BRANCH)


def managed_inventory(roots: Roots) -> tuple[list[str], list[str]]:
    skill_groups = sorted(
        path.name
        for path in (roots.repository / "skills").iterdir()
        if path.is_dir() and (path / "SKILL.md").is_file()
    )
    agent_files = sorted(
        path.name for path in (roots.repository / "agents").glob("*.agent.md")
    )
    if len(skill_groups) != 11:
        raise SyncError(f"Expected 11 managed skill groups, found {len(skill_groups)}")
    if len(agent_files) != 7:
        raise SyncError(f"Expected 7 managed Copilot agents, found {len(agent_files)}")
    return skill_groups, agent_files


def reconcile_area(
    area: str,
    baseline: dict[str, str] | None,
    repository: dict[str, str],
    canonical: dict[str, str],
    runtime: dict[str, str],
) -> list[Change]:
    paths = sorted(set(repository) | set(canonical) | set(runtime) | set(baseline or {}))
    changes: list[Change] = []
    conflicts: list[str] = []
    initial = baseline is None

    for relative in paths:
        hashes = {
            "repository": repository.get(relative),
            "canonical": canonical.get(relative),
            "runtime": runtime.get(relative),
        }
        if initial:
            distinct = set(hashes.values())
            if len(distinct) > 1:
                conflicts.append(relative)
                continue
            continue

        old_hash = baseline.get(relative)
        changed = {name: value for name, value in hashes.items() if value != old_hash}
        distinct_changed = set(changed.values())
        if len(distinct_changed) > 1:
            conflicts.append(relative)
            continue
        if not changed:
            continue

        selected_hash = next(iter(distinct_changed))
        source = next(name for name, value in changed.items() if value == selected_hash)
        changes.append(Change(area, relative, selected_hash, source))

    if conflicts:
        preview = "\n  - ".join(conflicts[:20])
        suffix = "\n  - ..." if len(conflicts) > 20 else ""
        if initial:
            raise SyncError(
                f"Cannot initialize {area}: repository, canonical, and runtime copies differ:\n"
                f"  - {preview}{suffix}"
            )
        raise SyncError(f"Conflicting {area} edits detected:\n  - {preview}{suffix}")
    return changes


def source_path(roots: Roots, change: Change) -> Path:
    if change.area == "skills":
        bases = {
            "repository": roots.repository / "skills",
            "canonical": roots.canonical_skills,
            "runtime": roots.runtime_skills,
        }
    else:
        bases = {
            "repository": roots.repository / "agents",
            "canonical": roots.canonical_agents,
            "runtime": roots.runtime_agents,
        }
    return bases[change.source] / Path(change.relative_path)


def target_roots(roots: Roots, area: str) -> tuple[Path, Path, Path]:
    if area == "skills":
        return roots.repository / "skills", roots.canonical_skills, roots.runtime_skills
    return roots.repository / "agents", roots.canonical_agents, roots.runtime_agents


def apply_changes(roots: Roots, changes: list[Change], logger: Logger) -> None:
    for change in changes:
        source = source_path(roots, change)
        for root in target_roots(roots, change.area):
            destination = root / Path(change.relative_path)
            if change.selected_hash is None:
                if destination.exists():
                    destination.unlink()
                    logger.write(f"Deleted {change.area}/{change.relative_path} from {root}")
                continue
            if destination.exists() and file_hash(destination) == change.selected_hash:
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            logger.write(
                f"Copied {change.area}/{change.relative_path} from {change.source} to {root}"
            )


def validate(roots: Roots, logger: Logger) -> None:
    python = sys.executable
    checks = [
        ([python, "check_skills.py"], roots.canonical_skills.parent),
        ([python, "validate_agent_routing.py"], roots.canonical_skills.parent),
        ([python, "validate_pack.py"], roots.repository),
        (["git", "diff", "--check"], roots.repository),
    ]
    for command, cwd in checks:
        logger.write(f"Running {' '.join(command)}")
        run(command, cwd=cwd)


def check_staged_paths(repository: Path, allowed_prefixes: list[str]) -> list[str]:
    staged = [
        line.strip()
        for line in git(repository, "diff", "--cached", "--name-only").splitlines()
        if line.strip()
    ]
    forbidden = [
        path
        for path in staged
        if not any(path == prefix or path.startswith(prefix + "/") for prefix in allowed_prefixes)
    ]
    if forbidden:
        raise SyncError(f"Refusing to commit unmanaged paths: {', '.join(forbidden)}")
    secret_suffixes = {".env", ".key", ".pem", ".pfx", ".p12", ".log"}
    suspicious = [path for path in staged if Path(path).suffix.lower() in secret_suffixes]
    if suspicious:
        raise SyncError(f"Refusing to commit sensitive file types: {', '.join(suspicious)}")
    return staged


def current_maps(
    roots: Roots, skill_groups: list[str], agent_files: list[str]
) -> tuple[dict[str, dict[str, str]], dict[str, dict[str, str]]]:
    skills = {
        "repository": collect_files(roots.repository / "skills", skill_groups),
        "canonical": collect_files(roots.canonical_skills, skill_groups),
        "runtime": collect_files(roots.runtime_skills, skill_groups),
    }
    agents = {
        "repository": collect_files(roots.repository / "agents", agent_files),
        "canonical": collect_files(roots.canonical_agents, agent_files),
        "runtime": collect_files(roots.runtime_agents, agent_files),
    }
    return skills, agents


def main() -> int:
    args = parse_args()
    logger = Logger(args.log)
    repository = args.repository.resolve()
    skill_pack = args.skill_pack.resolve()
    roots = Roots(
        repository=repository,
        canonical_skills=skill_pack / "skills",
        runtime_skills=args.runtime_skills.resolve(),
        canonical_agents=skill_pack / "prompts",
        runtime_agents=args.runtime_agents.resolve(),
    )

    lock_path = args.state.with_suffix(".lock")
    lock_descriptor: int | None = None
    try:
        lock_descriptor = acquire_lock(lock_path)
        logger.write("Synchronization started")
        verify_repository(
            repository,
            expected_remote=args.expected_remote,
            allow_dirty=args.allow_dirty or args.dry_run,
            skip_fetch=args.skip_fetch,
        )
        skill_groups, agent_files = managed_inventory(roots)
        state = load_state(args.state)
        skills, agents = current_maps(roots, skill_groups, agent_files)
        skill_changes = reconcile_area(
            "skills",
            None if state is None else state["skills"],
            skills["repository"],
            skills["canonical"],
            skills["runtime"],
        )
        agent_changes = reconcile_area(
            "agents",
            None if state is None else state["agents"],
            agents["repository"],
            agents["canonical"],
            agents["runtime"],
        )
        changes = [*skill_changes, *agent_changes]

        if state is None:
            if args.dry_run:
                logger.write("Initial state is consistent; dry run did not create state")
                return 0
            save_state(args.state, skills["repository"], agents["repository"])
            logger.write(f"Initialized synchronization state at {args.state}")
            return 0

        if not changes:
            ahead = int(
                git(repository, "rev-list", "--count", f"origin/{BRANCH}..HEAD") or "0"
            )
            if ahead and not args.dry_run and not args.no_push:
                git(repository, "push", "origin", BRANCH)
                logger.write(f"Pushed {ahead} existing local commit(s)")
            else:
                logger.write("No managed skill or agent changes detected")
            return 0

        for change in changes:
            action = "delete" if change.selected_hash is None else "update"
            logger.write(
                f"Planned {action}: {change.area}/{change.relative_path} from {change.source}"
            )
        if args.dry_run:
            logger.write(f"Dry run complete; {len(changes)} change(s) would be synchronized")
            return 0

        apply_changes(roots, changes, logger)
        validate(roots, logger)

        path_specs = [f"skills/{name}" for name in skill_groups]
        path_specs.extend(f"agents/{name}" for name in agent_files)
        git(repository, "add", "-A", "--", *path_specs)
        staged = check_staged_paths(repository, ["skills", "agents"])
        if staged:
            git(repository, "diff", "--cached", "--check")
            git(repository, "commit", "-m", args.message)
            if args.no_push:
                logger.write(f"Committed {len(staged)} managed file(s); push skipped")
            else:
                git(repository, "push", "origin", BRANCH)
                logger.write(f"Committed and pushed {len(staged)} managed file(s)")

        skills, agents = current_maps(roots, skill_groups, agent_files)
        save_state(args.state, skills["repository"], agents["repository"])
        logger.write("Synchronization completed successfully")
        return 0
    except (OSError, ValueError, json.JSONDecodeError, SyncError) as error:
        logger.write(f"ERROR: {error}")
        return 1
    finally:
        release_lock(lock_path, lock_descriptor)


if __name__ == "__main__":
    raise SystemExit(main())