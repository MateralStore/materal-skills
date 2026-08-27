[CmdletBinding()]
param(
    [string]$ChromePath,

    [ValidateRange(1, 65535)]
    [int]$DebugPort = 9222,

    [string]$ProfilePath = (Join-Path $env:LOCALAPPDATA 'chrome-devtools-profile'),

    [ValidateRange(1, 60)]
    [int]$StartupTimeoutSeconds = 15
)

$ErrorActionPreference = 'Stop'

$candidateChromePaths = @(
    (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
    (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }

if ([string]::IsNullOrWhiteSpace($ChromePath)) {
    $ChromePath = $candidateChromePaths | Select-Object -First 1
}

if ([string]::IsNullOrWhiteSpace($ChromePath) -or -not (Test-Path -LiteralPath $ChromePath -PathType Leaf)) {
    throw 'Chrome not found. Pass -ChromePath with the full path to chrome.exe.'
}

$profileFullPath = [System.IO.Path]::GetFullPath($ProfilePath)
$endpoint = "http://127.0.0.1:$DebugPort/json/version"

try {
    $existingEndpoint = Invoke-RestMethod -Uri $endpoint -TimeoutSec 2
    [PSCustomObject]@{
        Status = 'Reused'
        Endpoint = $endpoint
        Browser = $existingEndpoint.Browser
        ProfilePath = $null
    }
    return
}
catch {
    # No endpoint is listening yet; start the dedicated Chrome instance below.
}

New-Item -ItemType Directory -Force -Path $profileFullPath | Out-Null

$process = Start-Process -FilePath $ChromePath -ArgumentList @(
    "--remote-debugging-address=127.0.0.1",
    "--remote-debugging-port=$DebugPort",
    "--user-data-dir=`"$profileFullPath`"",
    '--no-first-run',
    '--no-default-browser-check'
) -PassThru

$deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
do {
    Start-Sleep -Milliseconds 250
    try {
        $version = Invoke-RestMethod -Uri $endpoint -TimeoutSec 2
        [PSCustomObject]@{
            Status = 'Started'
            Endpoint = $endpoint
            Browser = $version.Browser
            ProfilePath = $profileFullPath
            ProcessId = $process.Id
        }
        return
    }
    catch {
        if ($process.HasExited) {
            throw "Chrome exited before the DevTools endpoint became available. Exit code: $($process.ExitCode)"
        }
    }
} while ([DateTime]::UtcNow -lt $deadline)

throw "Chrome started, but the DevTools endpoint did not become available within $StartupTimeoutSeconds seconds: $endpoint"
