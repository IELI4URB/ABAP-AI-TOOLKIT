#!/usr/bin/env bash
# Installs the bundled skills and agents for GitHub Copilot in VS Code (macOS/Linux).
# Copilot-only by design: Claude Code agents are NOT installed, because they surface
# in the Copilot agent picker and create duplicate entries.
# Usage: chmod +x install.sh && ./install.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skills_src="$root/skills"
agents_src="$root/agents"

skills_dst="$HOME/.agents/skills"
agents_dst="$HOME/.copilot/agents"
manifest_name=".sap-dev-ai-toolkit-manifest"

update_managed_items() {
  local destination="$1"
  shift
  local current_names=("$@")
  local manifest="$destination/$manifest_name"

  if [ -f "$manifest" ]; then
    while IFS= read -r old_name; do
      [ -n "$old_name" ] || continue
      case "$old_name" in
        */*|.|..) continue ;;
      esac

      local found=false
      for current_name in "${current_names[@]}"; do
        if [ "$old_name" = "$current_name" ]; then
          found=true
          break
        fi
      done

      if [ "$found" = false ] && [ -e "$destination/$old_name" ]; then
        echo "Removing stale toolkit item $destination/$old_name"
        rm -rf -- "$destination/$old_name"
      fi
    done < "$manifest"
  fi

  printf '%s\n' "${current_names[@]}" | sort > "$manifest"
}

echo "Installing skills to $skills_dst (VS Code / Copilot) ..."
mkdir -p "$skills_dst"
cp -R "$skills_src"/. "$skills_dst"/
skill_names=()
for item in "$skills_src"/*; do
  [ -e "$item" ] || continue
  skill_names+=("$(basename "$item")")
done
update_managed_items "$skills_dst" "${skill_names[@]}"

echo "Installing agents to $agents_dst (VS Code / Copilot) ..."
mkdir -p "$agents_dst"
cp "$agents_src"/*.agent.md "$agents_dst"/

if [ -d "$agents_src/references" ]; then
  mkdir -p "$agents_dst/references"
  cp -R "$agents_src/references"/. "$agents_dst/references"/
fi

agent_names=()
for item in "$agents_src"/*.agent.md; do
  [ -e "$item" ] || continue
  agent_names+=("$(basename "$item")")
done
if [ -d "$agents_src/references" ]; then
  agent_names+=("references")
fi
update_managed_items "$agents_dst" "${agent_names[@]}"

# Warn about the legacy prompts folder, which causes duplicate agent-picker entries if used alongside .copilot/agents
case "$(uname -s)" in
  Darwin*) legacy_prompts="$HOME/Library/Application Support/Code/User/prompts" ;;
  Linux*) legacy_prompts="$HOME/.config/Code/User/prompts" ;;
  *) legacy_prompts="" ;;
esac
if [ -n "$legacy_prompts" ] && [ -d "$legacy_prompts" ] && ls "$legacy_prompts"/*.agent.md >/dev/null 2>&1; then
  echo "WARNING: Found *.agent.md files in the legacy prompts folder ($legacy_prompts)."
  echo "WARNING: These cause duplicate entries in the Copilot agent picker. Remove them:"
  echo "  rm \"$legacy_prompts\"/*.agent.md"
fi

echo ""
echo "Done. Restart VS Code (or run 'Developer: Reload Window') to load the new skills and agents."
