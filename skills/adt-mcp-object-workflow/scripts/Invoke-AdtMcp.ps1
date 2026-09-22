[CmdletBinding(DefaultParameterSetName = 'Call')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Call')]
    [string]$ToolName,

    [Parameter(ParameterSetName = 'Call')]
    [string]$ArgumentsJson = '{}',

    [Parameter(Mandatory = $true, ParameterSetName = 'List')]
    [switch]$ListTools
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

    if ($ListTools) {
        $response = Invoke-McpRequest -SessionId $initialize.SessionId -Payload @{
            jsonrpc = '2.0'
            id = 2
            method = 'tools/list'
            params = @{}
        }
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
    }

    $response.Data | ConvertTo-Json -Depth 50
}
finally {
    $client.Dispose()
}