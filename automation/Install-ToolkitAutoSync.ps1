[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall', 'Status')]
    [string] $Action = 'Install',
    [string] $RepositoryPath = (Split-Path -Parent $PSScriptRoot),
    [string] $TaskName = 'ABAP-Development-AI-Toolkit-AutoSync',
    [switch] $DoNotStart
)

$ErrorActionPreference = 'Stop'

if ($Action -eq 'Status') {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -eq $task) {
        Write-Host "Scheduled task '$TaskName' is not installed."
        exit 1
    }
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
    [pscustomobject]@{
        TaskName       = $task.TaskName
        State          = $task.State
        LastRunTime    = $taskInfo.LastRunTime
        LastTaskResult = $taskInfo.LastTaskResult
        NextRunTime    = $taskInfo.NextRunTime
    } | Format-List
    exit 0
}

if ($Action -eq 'Uninstall') {
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed scheduled task '$TaskName'."
    exit 0
}

$repository = (Resolve-Path $RepositoryPath).Path
$watcher = Join-Path $PSScriptRoot 'Watch-ToolkitChanges.ps1'
$syncEngine = Join-Path $PSScriptRoot 'sync_toolkit.py'
$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$currentUserSid = $currentIdentity.User.Value
if (-not (Test-Path $watcher) -or -not (Test-Path $syncEngine)) {
    throw 'Automation files are incomplete.'
}

$pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
$arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$watcher`" -RepositoryPath `"$repository`""
$taskAction = New-ScheduledTaskAction -Execute $pwsh -Argument $arguments -WorkingDirectory $repository
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUserSid
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUserSid `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $taskAction `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description 'Synchronizes managed ABAP skills and Copilot agents with Git after local changes.' `
    -Force | Out-Null

if (-not $DoNotStart) {
    Start-ScheduledTask -TaskName $TaskName
}

Write-Host "Installed scheduled task '$TaskName'."
Write-Host "Repository: $repository"
Write-Host "Logs: $env:LOCALAPPDATA\ABAP-DEVELOPMENT-AI-TOOLKIT"