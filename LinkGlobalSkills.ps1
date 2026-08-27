[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TargetRoot = (Join-Path $HOME '.codex\skills'),

    [string[]]$SkillName,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$sourceRoot = Join-Path $PSScriptRoot 'skills'

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Test-SameTarget {
    param(
        [Parameter(Mandatory = $true)]$Item,
        [Parameter(Mandatory = $true)][string]$ExpectedTarget
    )

    if ($Item.LinkType -ne 'SymbolicLink' -or -not $Item.Target) {
        return $false
    }

    $actualTarget = @($Item.Target)[0]
    return [string]::Equals(
        (Get-NormalizedPath $actualTarget),
        (Get-NormalizedPath $ExpectedTarget),
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Skill source directory not found: $sourceRoot"
}

$availableSkills = Get-ChildItem -LiteralPath $sourceRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf }

if ($SkillName) {
    $requestedNames = $SkillName | Sort-Object -Unique
    $missingNames = $requestedNames | Where-Object { $_ -notin $availableSkills.Name }
    if ($missingNames) {
        throw "Unknown skill name(s): $($missingNames -join ', ')"
    }
    $skillsToLink = $availableSkills | Where-Object { $_.Name -in $requestedNames }
}
else {
    $skillsToLink = $availableSkills
}

if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($TargetRoot, 'Create global skills directory')) {
        New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null
    }
}

$results = foreach ($skill in $skillsToLink) {
    $linkPath = Join-Path $TargetRoot $skill.Name
    $existingItem = if (Test-Path -LiteralPath $linkPath) { Get-Item -LiteralPath $linkPath -Force } else { $null }

    if ($existingItem) {
        if (Test-SameTarget -Item $existingItem -ExpectedTarget $skill.FullName) {
            [pscustomobject]@{ Skill = $skill.Name; Status = 'Reused'; Target = $skill.FullName }
            continue
        }

        if ($existingItem.LinkType -eq 'SymbolicLink' -and $Force) {
            if ($PSCmdlet.ShouldProcess($linkPath, "Replace symbolic link with $($skill.FullName)")) {
                Remove-Item -LiteralPath $linkPath -Force
                New-Item -ItemType SymbolicLink -Path $linkPath -Target $skill.FullName | Out-Null
            }
            [pscustomobject]@{ Skill = $skill.Name; Status = 'Replaced'; Target = $skill.FullName }
            continue
        }

        $reason = if ($existingItem.LinkType -eq 'SymbolicLink') {
            'already links to another target; rerun with -Force to replace that link'
        }
        else {
            'a real file or directory already exists; it will never be replaced automatically'
        }
        Write-Warning "Skipped $($skill.Name): $reason ($linkPath)"
        [pscustomobject]@{ Skill = $skill.Name; Status = 'Skipped'; Target = $skill.FullName }
        continue
    }

    if ($PSCmdlet.ShouldProcess($linkPath, "Create symbolic link to $($skill.FullName)")) {
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $skill.FullName | Out-Null
    }
    [pscustomobject]@{ Skill = $skill.Name; Status = 'Created'; Target = $skill.FullName }
}

$results | Format-Table -AutoSize
