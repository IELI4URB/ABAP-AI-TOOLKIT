[CmdletBinding()]
param(
    [string] $RepositoryPath = (Split-Path -Parent $PSScriptRoot),
    [int] $DebounceSeconds = 5
)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path $RepositoryPath).Path
$skillPack = Join-Path $HOME '.agents\skill-packs\SAP-ABAP-Cloud-Skills'
$syncScript = Join-Path $PSScriptRoot 'sync_toolkit.py'
$python = (Get-Command python -ErrorAction Stop).Source
$logDirectory = Join-Path $env:LOCALAPPDATA 'ABAP-DEVELOPMENT-AI-TOOLKIT'
$watcherLog = Join-Path $logDirectory 'watcher.log'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

function Write-WatcherLog {
    param([Parameter(Mandatory)] [string] $Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -LiteralPath $watcherLog -Value $line -Encoding utf8
}

function Invoke-ToolkitSync {
    Write-WatcherLog 'Invoking managed skill and agent synchronization.'
    & $python $syncScript --repository $repository
    if ($LASTEXITCODE -ne 0) {
        Write-WatcherLog "Synchronization failed with exit code $LASTEXITCODE."
    } else {
        Write-WatcherLog 'Synchronization completed.'
    }
}

function Test-IgnoredEvent {
    param([Parameter(Mandatory)] $EventRecord)
    $path = [string] $EventRecord.SourceEventArgs.FullPath
    $name = Split-Path -Leaf $path
    return $name -eq '.sap-dev-ai-toolkit-manifest' -or
        $name.EndsWith('.tmp') -or
        $name.EndsWith('.swp') -or
        $name.EndsWith('~') -or
        $path -match '[\\/]__pycache__[\\/]'
}

$roots = @(
    (Join-Path $HOME '.agents\skills'),
    (Join-Path $skillPack 'skills'),
    (Join-Path $skillPack 'prompts'),
    (Join-Path $HOME '.copilot\agents')
) | Where-Object { Test-Path $_ } | Select-Object -Unique

if ($roots.Count -lt 2) {
    throw 'Expected managed skill and agent directories were not found.'
}

$watchers = @()
$sourceIdentifiers = @()
try {
    $index = 0
    foreach ($root in $roots) {
        $watcher = [System.IO.FileSystemWatcher]::new($root)
        $watcher.IncludeSubdirectories = $true
        $watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
        $watcher.EnableRaisingEvents = $true
        $watchers += $watcher

        foreach ($eventName in @('Changed', 'Created', 'Deleted', 'Renamed')) {
            $identifier = "ABAPToolkit.$index.$eventName"
            Register-ObjectEvent -InputObject $watcher -EventName $eventName -SourceIdentifier $identifier | Out-Null
            $sourceIdentifiers += $identifier
        }
        Write-WatcherLog "Watching $root"
        $index++
    }

    Invoke-ToolkitSync
    while ($true) {
        $eventRecord = Wait-Event -Timeout 30
        if ($null -eq $eventRecord) { continue }
        Remove-Event -EventIdentifier $eventRecord.EventIdentifier -ErrorAction SilentlyContinue
        if (Test-IgnoredEvent $eventRecord) { continue }

        $changedPath = [string] $eventRecord.SourceEventArgs.FullPath
        Write-WatcherLog "Detected change: $changedPath"
        $deadline = (Get-Date).AddSeconds($DebounceSeconds)
        while ((Get-Date) -lt $deadline) {
            $remaining = [Math]::Max(1, [int]($deadline - (Get-Date)).TotalSeconds)
            $nextEvent = Wait-Event -Timeout $remaining
            if ($null -eq $nextEvent) { continue }
            Remove-Event -EventIdentifier $nextEvent.EventIdentifier -ErrorAction SilentlyContinue
            if (-not (Test-IgnoredEvent $nextEvent)) {
                $deadline = (Get-Date).AddSeconds($DebounceSeconds)
            }
        }
        Invoke-ToolkitSync
    }
} finally {
    foreach ($identifier in $sourceIdentifiers) {
        Unregister-Event -SourceIdentifier $identifier -ErrorAction SilentlyContinue
    }
    foreach ($watcher in $watchers) {
        $watcher.Dispose()
    }
    Write-WatcherLog 'Watcher stopped.'
}