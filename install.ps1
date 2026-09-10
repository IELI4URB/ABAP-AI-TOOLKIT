#!/usr/bin/env pwsh
# Installs the bundled skills and agents for GitHub Copilot in VS Code, and (optionally) Claude Code (Windows).
# Usage: run this script from anywhere - it locates its own folder automatically.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$skillsSrc = Join-Path $root 'skills'
$agentsSrc = Join-Path $root 'agents'
$claudeAgentsSrc = Join-Path $root 'claude-agents'

$skillsDst = Join-Path $HOME '.agents\skills'
$agentsDst = Join-Path $HOME '.copilot\agents'

Write-Host "Installing skills to $skillsDst (VS Code / Copilot) ..."
New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null
Copy-Item -Path (Join-Path $skillsSrc '*') -Destination $skillsDst -Recurse -Force

Write-Host "Installing agents to $agentsDst (VS Code / Copilot) ..."
New-Item -ItemType Directory -Path $agentsDst -Force | Out-Null
Copy-Item -Path (Join-Path $agentsSrc '*.agent.md') -Destination $agentsDst -Force

$refSrc = Join-Path $agentsSrc 'references'
if (Test-Path $refSrc) {
    $refDst = Join-Path $agentsDst 'references'
    New-Item -ItemType Directory -Path $refDst -Force | Out-Null
    Copy-Item -Path (Join-Path $refSrc '*') -Destination $refDst -Recurse -Force
}

# Claude Code support: skills use the same SKILL.md format; agents are pre-converted to Claude's frontmatter dialect
if (Get-Command claude -ErrorAction SilentlyContinue) {
    $claudeSkillsDst = Join-Path $HOME '.claude\skills'
    $claudeAgentsDst = Join-Path $HOME '.claude\agents'

    Write-Host "Claude Code detected - installing skills to $claudeSkillsDst ..."
    New-Item -ItemType Directory -Path $claudeSkillsDst -Force | Out-Null
    Copy-Item -Path (Join-Path $skillsSrc '*') -Destination $claudeSkillsDst -Recurse -Force

    Write-Host "Installing agents to $claudeAgentsDst ..."
    New-Item -ItemType Directory -Path $claudeAgentsDst -Force | Out-Null
    Copy-Item -Path (Join-Path $claudeAgentsSrc '*.md') -Destination $claudeAgentsDst -Force
} else {
    Write-Host "Claude Code CLI not found on PATH - skipping Claude install (run install-claude.ps1 manually if needed)."
}

# Warn about the legacy prompts folder, which causes duplicate agent-picker entries if used alongside .copilot\agents
$legacyPrompts = Join-Path $env:APPDATA 'Code\User\prompts'
if (Test-Path $legacyPrompts) {
    $dupes = Get-ChildItem -Path $legacyPrompts -Filter '*.agent.md' -ErrorAction SilentlyContinue
    if ($dupes) {
        Write-Warning "Found *.agent.md files in the legacy prompts folder ($legacyPrompts)."
        Write-Warning "These cause duplicate entries in the Copilot agent picker. Remove them:"
        Write-Warning "  Remove-Item '$legacyPrompts\*.agent.md' -Force"
    }
}

Write-Host ""
Write-Host "Done. Restart VS Code (or run 'Developer: Reload Window') to load the new skills and agents." -ForegroundColor Green
