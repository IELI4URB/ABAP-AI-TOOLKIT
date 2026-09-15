#!/usr/bin/env pwsh
# Installs the bundled skills and agents for GitHub Copilot in VS Code (Windows).
# Copilot-only by design: Claude Code agents are NOT installed, because they surface
# in the Copilot agent picker and create duplicate entries.
# Usage: run this script from anywhere - it locates its own folder automatically.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$skillsSrc = Join-Path $root 'skills'
$agentsSrc = Join-Path $root 'agents'

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
