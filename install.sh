#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest_name=".sap-dev-ai-toolkit-manifest"
expected_skill_count=11
expected_agent_count=7

reset_managed_items() {
  local destination="$1"
  shift
  local current_names=("$@")
  local manifest="$destination/$manifest_name"
  mkdir -p "$destination"

  if [ -f "$manifest" ]; then
    while IFS= read -r old_name; do
      [ -n "$old_name" ] || continue
      case "$old_name" in */*|.|..) continue ;; esac
      if [ -e "$destination/$old_name" ]; then
        echo "Refreshing toolkit item $destination/$old_name"
        rm -rf -- "$destination/$old_name"
      fi
    done < "$manifest"
  fi

  printf '%s\n' "${current_names[@]}" | sort -u > "$manifest"
}

install_agent_set() {
  local source="$1"
  local destination="$2"
  local suffix="$3"
  local files=()
  while IFS= read -r -d '' file; do files+=("$file"); done < <(
    find "$source" -maxdepth 1 -type f -name "*$suffix" -print0
  )
  if [ "${#files[@]}" -ne "$expected_agent_count" ]; then
    echo "ERROR: Expected $expected_agent_count agent files in $source, found ${#files[@]}." >&2
    exit 1
  fi

  local names=()
  for file in "${files[@]}"; do names+=("$(basename "$file")"); done
  if [ -d "$source/references" ]; then names+=("references"); fi
  reset_managed_items "$destination" "${names[@]}"
  cp "${files[@]}" "$destination/"
  if [ -d "$source/references" ]; then cp -R "$source/references" "$destination/"; fi
}

skills_src="$root/skills"
agents_src="$root/agents"
claude_src="$root/claude-agents"
home_dir="${TOOLKIT_HOME:-$HOME}"
skills_dst="$home_dir/.agents/skills"
agents_dst="$home_dir/.copilot/agents"
claude_dst="$home_dir/.claude/agents"

skill_dirs=()
while IFS= read -r -d '' directory; do skill_dirs+=("$directory"); done < <(
  find "$skills_src" -mindepth 1 -maxdepth 1 -type d -print0
)
if [ "${#skill_dirs[@]}" -ne "$expected_skill_count" ]; then
  echo "ERROR: Expected $expected_skill_count grouped skills, found ${#skill_dirs[@]}." >&2
  exit 1
fi
for directory in "${skill_dirs[@]}"; do
  [ -f "$directory/SKILL.md" ] || { echo "ERROR: Missing $directory/SKILL.md" >&2; exit 1; }
done

skill_names=()
for directory in "${skill_dirs[@]}"; do skill_names+=("$(basename "$directory")"); done
if [ -f "$skills_src/README.md" ]; then skill_names+=("README.md"); fi

echo "Installing $expected_skill_count grouped skills to $skills_dst ..."
reset_managed_items "$skills_dst" "${skill_names[@]}"
for directory in "${skill_dirs[@]}"; do cp -R "$directory" "$skills_dst/"; done
if [ -f "$skills_src/README.md" ]; then cp "$skills_src/README.md" "$skills_dst/"; fi

echo "Installing $expected_agent_count Copilot agents to $agents_dst ..."
install_agent_set "$agents_src" "$agents_dst" ".agent.md"

if [ "${INSTALL_CLAUDE_AGENTS:-0}" = "1" ]; then
  echo "WARNING: Claude agents may also appear in the VS Code Copilot picker and cause duplicates."
  echo "Installing $expected_agent_count Claude agents to $claude_dst ..."
  install_agent_set "$claude_src" "$claude_dst" ".md"
fi

case "$(uname -s)" in
  Darwin*) legacy_prompts="$HOME/Library/Application Support/Code/User/prompts" ;;
  Linux*) legacy_prompts="$HOME/.config/Code/User/prompts" ;;
  *) legacy_prompts="" ;;
esac
if [ -n "$legacy_prompts" ] && [ -d "$legacy_prompts" ] && compgen -G "$legacy_prompts/*.agent.md" >/dev/null; then
  echo "WARNING: Legacy agents found in $legacy_prompts; remove them to avoid duplicates."
fi

echo
echo "Installation complete. Run Developer: Reload Window in VS Code."
