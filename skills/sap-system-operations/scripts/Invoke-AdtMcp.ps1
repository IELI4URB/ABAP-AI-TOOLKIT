[CmdletBinding(DefaultParameterSetName = 'Call')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Call')]
    [string]$ToolName,

    [Parameter(ParameterSetName = 'Call')]
    [string]$ArgumentsJson = '{}',

    [Parameter(Mandatory = $true, ParameterSetName = 'List')]
    [switch]$ListTools,

    [Parameter(Mandatory = $true, ParameterSetName = 'Describe')]
    [string]$DescribeTool,

    [Parameter(ParameterSetName = 'List')]
    [Parameter(ParameterSetName = 'Describe')]
    [switch]$RefreshSchema
)

$ErrorActionPreference = 'Stop'

$settingsPath = Join-Path $env:APPDATA 'Code\User\settings.json'
if (-not (Test-Path $settingsPath)) {
    throw "VS Code settings were not found at $settingsPath"
}

$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$port = $settings.'adt.mcpServer.port'
$token = $settings.'adt.mcpServer.token'
if (-not $port -or -not $token) {
    throw 'The ADT MCP server port or token is not configured in VS Code settings.'
}

$client = [Net.Http.HttpClient]::new()
$client.DefaultRequestHeaders.Authorization =
    [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $token)
$client.DefaultRequestHeaders.Accept.ParseAdd('application/json, text/event-stream')

function ConvertFrom-McpBody {
    param([Parameter(Mandatory = $true)][string]$Body)

    $dataLines = @(
        $Body -split "`r?`n" |
            Where-Object { $_ -like 'data:*' } |
            ForEach-Object { $_.Substring(5).Trim() }
    )
    if ($dataLines.Count -gt 0) {
        for ($index = $dataLines.Count - 1; $index -ge 0; $index--) {
            try {
                return $dataLines[$index] | ConvertFrom-Json
            }
            catch {
                continue
            }
        }
    }

    return $Body | ConvertFrom-Json
}

function Invoke-McpRequest {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Payload,
        [string]$SessionId
    )

    $request = [Net.Http.HttpRequestMessage]::new(
        [Net.Http.HttpMethod]::Post,
        "http://localhost:$port/mcp")
    if ($SessionId) {
        $request.Headers.Add('Mcp-Session-Id', $SessionId)
    }
    $json = $Payload | ConvertTo-Json -Depth 40 -Compress
    $request.Content = [Net.Http.StringContent]::new(
        $json,
        [Text.Encoding]::UTF8,
        'application/json')

    $response = $client.Send($request)
    $body = $response.Content.ReadAsStringAsync().Result
    if (-not $response.IsSuccessStatusCode) {
        throw "ADT MCP request failed with HTTP $([int]$response.StatusCode): $body"
    }

    $nextSessionId = $SessionId
    if ($response.Headers.Contains('Mcp-Session-Id')) {
        $nextSessionId =
            $response.Headers.GetValues('Mcp-Session-Id') | Select-Object -First 1
    }

    [pscustomobject]@{
        SessionId = $nextSessionId
        Data = if ($body) { ConvertFrom-McpBody -Body $body } else { $null }
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Value)

    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        return -join (
            $sha256.ComputeHash($bytes) |
                ForEach-Object { $_.ToString('x2') }
        )
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-ToolSchemaCache {
    param(
        [Parameter(Mandatory = $true)][string]$SessionId,
        [Parameter(Mandatory = $true)]$ServerInfo,
        [Parameter(Mandatory = $true)][bool]$ForceRefresh
    )

    $serverName = if ($ServerInfo.name) {
        [string]$ServerInfo.name
    }
    else {
        'adt-mcp'
    }
    $serverVersion = if ($ServerInfo.version) {
        [string]$ServerInfo.version
    }
    else {
        'unknown'
    }
    $fingerprint = Get-Sha256 -Value "$port|$serverName|$serverVersion"
    $cacheDirectory = Join-Path $env:LOCALAPPDATA 'ADT-MCP\schema-cache'
    $cachePath = Join-Path $cacheDirectory "$fingerprint.json"

    if (-not $ForceRefresh -and (Test-Path $cachePath)) {
        return Get-Content $cachePath -Raw | ConvertFrom-Json
    }

    $toolResponse = Invoke-McpRequest -SessionId $SessionId -Payload @{
        jsonrpc = '2.0'
        id = 2
        method = 'tools/list'
        params = @{}
    }
    $compactTools = @(
        $toolResponse.Data.result.tools |
            ForEach-Object {
                [pscustomobject]@{
                    name = $_.name
                    inputSchema = $_.inputSchema
                }
            }
    )
    $schemaJson = $compactTools | ConvertTo-Json -Depth 40 -Compress
    $cache = [pscustomobject]@{
        serverName = $serverName
        serverVersion = $serverVersion
        serverFingerprint = $fingerprint
        schemaHash = Get-Sha256 -Value $schemaJson
        retrievedAt = [DateTimeOffset]::UtcNow.ToString('o')
        tools = $compactTools
    }

    $null = New-Item -ItemType Directory -Path $cacheDirectory -Force
    $cache | ConvertTo-Json -Depth 40 |
        Set-Content -Path $cachePath -Encoding UTF8
    return $cache
}

try {
    $initialize = Invoke-McpRequest -Payload @{
        jsonrpc = '2.0'
        id = 1
        method = 'initialize'
        params = @{
            protocolVersion = '2025-06-18'
            capabilities = @{}
            clientInfo = @{
                name = 'adt-mcp-object-workflow'
                version = '1.0'
            }
        }
    }

    $null = Invoke-McpRequest -SessionId $initialize.SessionId -Payload @{
        jsonrpc = '2.0'
        method = 'notifications/initialized'
        params = @{}
    }

    if ($ListTools -or $DescribeTool) {
        $cache = Get-ToolSchemaCache `
            -SessionId $initialize.SessionId `
            -ServerInfo $initialize.Data.result.serverInfo `
            -ForceRefresh $RefreshSchema.IsPresent
    }

    if ($ListTools) {
        $cache | ConvertTo-Json -Depth 40
    }
    elseif ($DescribeTool) {
        $tools = @($cache.tools | Where-Object { $_.name -eq $DescribeTool })
        if ($tools.Count -ne 1) {
            throw "Tool '$DescribeTool' was not found in the ADT MCP schema cache."
        }
        $tools[0] | ConvertTo-Json -Depth 40
    }
    else {
        $arguments = $ArgumentsJson | ConvertFrom-Json
        $response = Invoke-McpRequest -SessionId $initialize.SessionId -Payload @{
            jsonrpc = '2.0'
            id = 2
            method = 'tools/call'
            params = @{
                name = $ToolName
                arguments = $arguments
            }
        }

        $response.Data | ConvertTo-Json -Depth 50
    }
}
finally {
    $client.Dispose()
}