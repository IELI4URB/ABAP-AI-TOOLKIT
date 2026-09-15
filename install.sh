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

echo "Installing skills to $skills_dst (VS Code / Copilot) ..."
mkdir -p "$skills_dst"
cp -R "$skills_src"/. "$skills_dst"/

echo "Installing agents to $agents_dst (VS Code / Copilot) ..."
mkdir -p "$agents_dst"
cp "$agents_src"/*.agent.md "$agents_dst"/

if [ -d "$agents_src/references" ]; then
  mkdir -p "$agents_dst/references"
  cp -R "$agents_src/references"/. "$agents_dst/references"/
fi

# Warn about the legacy prompts folder, which causes duplicate agent-picker entries if used alongside .copilot/agents
legacy_prompts="$HOME/Library/Application Support/Code/User/prompts"
if [ -d "$legacy_prompts" ] && ls "$legacy_prompts"/*.agent.md >/dev/null 2>&1; then
  echo "WARNING: Found *.agent.md files in the legacy prompts folder ($legacy_prompts)."
  echo "WARNING: These cause duplicate entries in the Copilot agent picker. Remove them:"
  echo "  rm \"$legacy_prompts\"/*.agent.md"
fi

echo ""
echo "Done. Restart VS Code (or run 'Developer: Reload Window') to load the new skills and agents."
