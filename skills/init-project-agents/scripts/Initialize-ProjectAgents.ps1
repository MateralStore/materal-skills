[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetDirectory,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Get-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

$targetPath = Get-FullPath -Path $TargetDirectory

if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
    throw "Target directory does not exist: $targetPath"
}

$agentsPath = Join-Path -Path $targetPath -ChildPath '.agents'
$skillsPath = Join-Path -Path $agentsPath -ChildPath 'skills'
$linkPath = Join-Path -Path $targetPath -ChildPath '.calude'

New-Item -ItemType Directory -Path $agentsPath -Force | Out-Null
New-Item -ItemType Directory -Path $skillsPath -Force | Out-Null

$linkCreated = $false
$linkReused = $false

if (Test-Path -LiteralPath $linkPath) {
    $linkItem = Get-Item -LiteralPath $linkPath -Force
    $isReparsePoint = (($linkItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)

    if (-not $isReparsePoint) {
        throw ".calude already exists and is not a symbolic link: $linkPath"
    }

    $existingTarget = $linkItem.Target
    if ($existingTarget -is [array]) {
        $existingTarget = $existingTarget[0]
    }

    $normalizedExistingTarget = Get-FullPath -Path $existingTarget
    $normalizedAgentsPath = Get-FullPath -Path $agentsPath

    if ([string]::Equals($normalizedExistingTarget.TrimEnd('\'), $normalizedAgentsPath.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
        $linkReused = $true
    }
    elseif ($Force) {
        Remove-Item -LiteralPath $linkPath -Force
        New-Item -ItemType SymbolicLink -Path $linkPath -Value $agentsPath | Out-Null
        $linkCreated = $true
    }
    else {
        throw ".calude already exists but points to '$existingTarget'. Re-run with -Force to recreate it."
    }
}
else {
    New-Item -ItemType SymbolicLink -Path $linkPath -Value $agentsPath | Out-Null
    $linkCreated = $true
}

[PSCustomObject]@{
    TargetDirectory = $targetPath
    AgentsDirectory = $agentsPath
    SkillsDirectory = $skillsPath
    LinkPath = $linkPath
    LinkTarget = $agentsPath
    LinkCreated = $linkCreated
    LinkReused = $linkReused
}
