#!/usr/bin/env bash
# Installs the bundled skills and agents for GitHub Copilot in VS Code, and (optionally) Claude Code (macOS/Linux).
# Usage: chmod +x install.sh && ./install.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skills_src="$root/skills"
agents_src="$root/agents"
claude_agents_src="$root/claude-agents"

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

# Claude Code support: skills use the same SKILL.md format; agents are pre-converted to Claude's frontmatter dialect
if command -v claude >/dev/null 2>&1; then
  claude_skills_dst="$HOME/.claude/skills"
  claude_agents_dst="$HOME/.claude/agents"

  echo "Claude Code detected - installing skills to $claude_skills_dst ..."
  mkdir -p "$claude_skills_dst"
  cp -R "$skills_src"/. "$claude_skills_dst"/

  echo "Installing agents to $claude_agents_dst ..."
  mkdir -p "$claude_agents_dst"
  cp "$claude_agents_src"/*.md "$claude_agents_dst"/
else
  echo "Claude Code CLI not found on PATH - skipping Claude install."
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
