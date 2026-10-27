#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [switch] $InstallClaudeAgents,
    [string] $HomePath = $HOME
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestName = '.sap-dev-ai-toolkit-manifest'
$expectedSkillCount = 12
$expectedAgentCount = 7

function Reset-ManagedItems {
    param(
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string[]] $CurrentNames
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $manifestPath = Join-Path $Destination $manifestName
    if (Test-Path $manifestPath) {
        foreach ($oldName in Get-Content $manifestPath) {
            if (-not $oldName -or $oldName -match '[\\/]') { continue }
            $oldPath = Join-Path $Destination $oldName
            if (Test-Path $oldPath) {
                Write-Host "Refreshing toolkit item $oldPath"
                Remove-Item $oldPath -Recurse -Force
            }
        }
    }

    $CurrentNames | Sort-Object -Unique | Set-Content $manifestPath -Encoding utf8
}

function Install-AgentSet {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Destination,
        [Parameter(Mandatory)] [string] $Pattern,
        [Parameter(Mandatory)] [int] $ExpectedCount
    )

    $agentFiles = @(Get-ChildItem $Source -File -Filter $Pattern)
    if ($agentFiles.Count -ne $ExpectedCount) {
        throw "Expected $ExpectedCount agent files in $Source, found $($agentFiles.Count)."
    }

    $managedNames = @($agentFiles | ForEach-Object Name)
    $references = Join-Path $Source 'references'
    if (Test-Path $references) { $managedNames += 'references' }
    Reset-ManagedItems -Destination $Destination -CurrentNames $managedNames

    Copy-Item -LiteralPath $agentFiles.FullName -Destination $Destination -Force
    if (Test-Path $references) {
        Copy-Item -LiteralPath $references -Destination $Destination -Recurse -Force
    }
}

$skillsSrc = Join-Path $root 'skills'
$agentsSrc = Join-Path $root 'agents'
$claudeSrc = Join-Path $root 'claude-agents'
$skillsDst = Join-Path $HomePath '.agents\skills'
$agentsDst = Join-Path $HomePath '.copilot\agents'
$claudeDst = Join-Path $HomePath '.claude\agents'

$skillDirs = @(Get-ChildItem $skillsSrc -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName 'SKILL.md')
})
if ($skillDirs.Count -ne $expectedSkillCount) {
    throw "Expected $expectedSkillCount grouped skills, found $($skillDirs.Count)."
}

$skillNames = @($skillDirs | ForEach-Object Name)
if (Test-Path (Join-Path $skillsSrc 'README.md')) { $skillNames += 'README.md' }
Write-Host "Installing $expectedSkillCount grouped skills to $skillsDst ..."
Reset-ManagedItems -Destination $skillsDst -CurrentNames $skillNames
foreach ($skillDir in $skillDirs) {
    Copy-Item -LiteralPath $skillDir.FullName -Destination $skillsDst -Recurse -Force
}
if (Test-Path (Join-Path $skillsSrc 'README.md')) {
    Copy-Item -LiteralPath (Join-Path $skillsSrc 'README.md') -Destination $skillsDst -Force
}

Write-Host "Installing $expectedAgentCount Copilot agents to $agentsDst ..."
Install-AgentSet -Source $agentsSrc -Destination $agentsDst -Pattern '*.agent.md' -ExpectedCount $expectedAgentCount

if ($InstallClaudeAgents) {
    Write-Warning 'Claude agents may also appear in the VS Code Copilot picker and cause duplicate entries.'
    Write-Host "Installing $expectedAgentCount Claude agents to $claudeDst ..."
    Install-AgentSet -Source $claudeSrc -Destination $claudeDst -Pattern '*.md' -ExpectedCount $expectedAgentCount
}

$legacyPrompts = Join-Path $env:APPDATA 'Code\User\prompts'
if (Test-Path $legacyPrompts) {
    $duplicates = Get-ChildItem $legacyPrompts -Filter '*.agent.md' -ErrorAction SilentlyContinue
    if ($duplicates) {
        Write-Warning "Legacy agents found in $legacyPrompts; remove them to avoid duplicate picker entries."
    }
}

Write-Host ''
Write-Host 'Installation complete. Run Developer: Reload Window in VS Code.' -ForegroundColor Green
