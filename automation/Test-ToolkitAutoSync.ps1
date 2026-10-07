[CmdletBinding()]
param(
    [string] $RepositoryPath = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$sourceRepository = (Resolve-Path $RepositoryPath).Path
$sourcePack = Join-Path $HOME '.agents\skill-packs\SAP-ABAP-Cloud-Skills'
$sourceRuntimeSkills = Join-Path $HOME '.agents\skills'
$sourceRuntimeAgents = Join-Path $HOME '.copilot\agents'
$syncEngine = Join-Path $PSScriptRoot 'sync_toolkit.py'
$testId = ([guid]::NewGuid().ToString('N')).Substring(0, 8)
$temporaryRoot = Join-Path $env:PUBLIC ("atqsync-$testId")
$temporaryRepository = Join-Path $temporaryRoot 'repo'
$temporaryHome = Join-Path $temporaryRoot 'home'
$temporaryPack = Join-Path $temporaryHome '.agents\skill-packs\SAP-ABAP-Cloud-Skills'
$state = Join-Path $temporaryRoot 'sync-state.json'
$log = Join-Path $temporaryRoot 'sync.log'

$oldHome = $env:HOME
$oldUserProfile = $env:USERPROFILE
$oldLocalAppData = $env:LOCALAPPDATA

function Invoke-TestSync {
    param([switch] $DryRun, [switch] $SkipFetch)
    $arguments = @(
        $syncEngine,
        '--repository', $temporaryRepository,
        '--skill-pack', $temporaryPack,
        '--runtime-skills', (Join-Path $temporaryHome '.agents\skills'),
        '--runtime-agents', (Join-Path $temporaryHome '.copilot\agents'),
        '--state', $state,
        '--log', $log,
        '--expected-remote', $sourceRepository,
        '--no-push'
    )
    if ($DryRun) { $arguments += '--dry-run' }
    if ($SkipFetch) { $arguments += '--skip-fetch' }
    & python @arguments | Out-Host
    $exitCode = $LASTEXITCODE
    return $exitCode
}

    function Get-NormalizedTextHash {
        param([Parameter(Mandatory)] [string] $Path)
        $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
        $bytes = [Text.Encoding]::UTF8.GetBytes($text)
        return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
    }

try {
    Write-Host 'Creating isolated Git and home-directory fixture...'
    New-Item -ItemType Directory -Path $temporaryPack -Force | Out-Null
    git clone --quiet --no-hardlinks $sourceRepository $temporaryRepository
    if ($LASTEXITCODE -ne 0) { throw 'Temporary Git clone failed.' }
    Copy-Item (Join-Path $sourceRepository 'validate_pack.py') $temporaryRepository -Force
    Copy-Item (Join-Path $sourceRepository 'automation') $temporaryRepository -Recurse -Force
    git -C $temporaryRepository add validate_pack.py automation
    git -C $temporaryRepository commit --quiet -m 'Prepare automation integration fixture'
    if ($LASTEXITCODE -ne 0) { throw 'Temporary fixture commit failed.' }

    Get-ChildItem $sourcePack -Force |
        Where-Object { $_.Name -notin @('_internal', '__pycache__') } |
        Copy-Item -Destination $temporaryPack -Recurse -Force
    Copy-Item $sourceRuntimeSkills (Join-Path $temporaryHome '.agents\skills') -Recurse
    Copy-Item $sourceRuntimeAgents (Join-Path $temporaryHome '.copilot\agents') -Recurse

    $env:HOME = $temporaryHome
    $env:USERPROFILE = $temporaryHome
    $env:LOCALAPPDATA = Join-Path $temporaryHome 'AppData\Local'

    Write-Host 'Initializing synchronization state...'
    if ((Invoke-TestSync) -ne 0) { throw 'Synchronization-state initialization failed.' }

    Write-Host 'Testing runtime skill and agent propagation...'
    Add-Content (Join-Path $temporaryHome '.agents\skills\abap-forms\SKILL.md') '<!-- integration-test -->'
    Add-Content (Join-Path $temporaryHome '.copilot\agents\abap-cloud-analyzer.agent.md') '<!-- integration-test -->'
    if ((Invoke-TestSync) -ne 0) { throw 'Managed change synchronization failed.' }

    $skillCopies = @(
        (Join-Path $temporaryRepository 'skills\abap-forms\SKILL.md'),
        (Join-Path $temporaryPack 'skills\abap-forms\SKILL.md'),
        (Join-Path $temporaryHome '.agents\skills\abap-forms\SKILL.md')
    )
    $agentCopies = @(
        (Join-Path $temporaryRepository 'agents\abap-cloud-analyzer.agent.md'),
        (Join-Path $temporaryPack 'prompts\abap-cloud-analyzer.agent.md'),
        (Join-Path $temporaryHome '.copilot\agents\abap-cloud-analyzer.agent.md')
    )
    if (@($skillCopies | ForEach-Object { Get-NormalizedTextHash $_ } | Select-Object -Unique).Count -ne 1) {
        throw 'Skill copies differ after synchronization.'
    }
    if (@($agentCopies | ForEach-Object { Get-NormalizedTextHash $_ } | Select-Object -Unique).Count -ne 1) {
        throw 'Agent copies differ after synchronization.'
    }
    $subject = git -C $temporaryRepository log -1 --format=%s
    if ($subject -notlike 'Sync local skills and agents*') {
        throw "Expected automatic sync commit, found: $subject"
    }

    Write-Host 'Testing conflicting-edit refusal...'
    Add-Content (Join-Path $temporaryHome '.agents\skills\abap-forms\SKILL.md') 'runtime-conflict'
    Add-Content (Join-Path $temporaryPack 'skills\abap-forms\SKILL.md') 'canonical-conflict'
    if ((Invoke-TestSync -DryRun -SkipFetch) -eq 0) {
        throw 'Conflicting edits were not rejected.'
    }

    Write-Host 'Automatic synchronization integration test PASSED.' -ForegroundColor Green
} finally {
    $env:HOME = $oldHome
    $env:USERPROFILE = $oldUserProfile
    $env:LOCALAPPDATA = $oldLocalAppData
    if (Test-Path $temporaryRoot) {
        Remove-Item $temporaryRoot -Recurse -Force
    }
}