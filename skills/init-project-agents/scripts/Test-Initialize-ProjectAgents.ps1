[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'Initialize-ProjectAgents.ps1'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-PathDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Assert-True -Condition (Test-Path -LiteralPath $Path -PathType Container) -Message "Expected directory to exist: $Path"
}

function Assert-PathFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Assert-True -Condition (Test-Path -LiteralPath $Path -PathType Leaf) -Message "Expected file to exist: $Path"
}

function Assert-CrlfFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        if ($bytes[$index] -eq 10 -and ($index -eq 0 -or $bytes[$index - 1] -ne 13)) {
            throw "Expected file to use CRLF line endings: $Path"
        }
    }
}

function Get-NormalizedPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Assert-ProjectDocs {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedProjectName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedProjectDescription
    )

    $agentsFile = Join-Path -Path $ProjectPath -ChildPath 'AGENTS.md'
    $claudeFile = Join-Path -Path $ProjectPath -ChildPath 'CLAUDE.md'

    Assert-PathFile -Path $agentsFile
    Assert-PathFile -Path $claudeFile
    Assert-CrlfFile -Path $agentsFile
    Assert-CrlfFile -Path $claudeFile

    $claudeContent = Get-Content -LiteralPath $claudeFile -Raw
    Assert-True -Condition ($claudeContent.Trim() -eq 'AGENTS.md') -Message 'Expected CLAUDE.md to contain only AGENTS.md.'

    $agentsContent = Get-Content -LiteralPath $agentsFile -Raw
    Assert-True -Condition ($agentsContent.Contains("# $ExpectedProjectName")) -Message 'Expected AGENTS.md to contain the project name.'
    Assert-True -Condition ($agentsContent.Contains($ExpectedProjectDescription)) -Message 'Expected AGENTS.md to contain the project description.'
    Assert-RequiredAgentsContent -Content $agentsContent
}

function Assert-RequiredAgentsContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    Assert-True -Condition ($Content.Contains('# 文档目录')) -Message 'Expected AGENTS.md to include docs section heading.'
    Assert-True -Condition ($Content.Contains('docs\')) -Message 'Expected AGENTS.md to describe docs directory.'
    Assert-True -Condition ($Content.Contains('plans\')) -Message 'Expected AGENTS.md to describe plans directory.'
    Assert-True -Condition ($Content.Contains('testPlan.md')) -Message 'Expected AGENTS.md to describe test plans.'
    Assert-True -Condition ($Content.Contains('Pages\<页面名称>\')) -Message 'Expected AGENTS.md to describe page design docs.'
    Assert-True -Condition ($Content.Contains('NNN-业务主题')) -Message 'Expected AGENTS.md to use business-topic plan directories.'
    Assert-True -Condition ($Content.Contains('仅用于排序')) -Message 'Expected AGENTS.md to distinguish directory ordering from development phases.'
    Assert-True -Condition ($Content.Contains('最终有效的当前状态')) -Message 'Expected AGENTS.md to retain only current final documentation.'
    Assert-True -Condition ($Content.Contains('# 文档维护策略')) -Message 'Expected AGENTS.md to include documentation maintenance policy.'
    Assert-True -Condition ($Content.Contains('当前或已批准计划的最终状态')) -Message 'Expected AGENTS.md to treat plans as current-state documents.'
    Assert-True -Condition ($Content.Contains('直接更新最贴合的现有文件')) -Message 'Expected AGENTS.md to require updating existing documents first.'
    Assert-True -Condition ($Content.Contains('用户明确要求新建目录')) -Message 'Expected AGENTS.md to require explicit authorization for a new plan directory.'
    Assert-True -Condition ($Content.Contains('# 工作树')) -Message 'Expected AGENTS.md to include worktree guidance.'
    Assert-True -Condition ($Content.Contains('.worktrees/<工作树名称>')) -Message 'Expected AGENTS.md to use the project .worktrees convention.'
    Assert-True -Condition ($Content.Contains('.worktrees/')) -Message 'Expected AGENTS.md to ignore the local worktrees directory.'
    Assert-True -Condition ($Content.Contains('Codex App 自动创建工作树')) -Message 'Expected AGENTS.md to distinguish the App-managed worktree path.'
    Assert-True -Condition ($Content.Contains('新增或修改文件时应保持 CRLF 行尾')) -Message 'Expected AGENTS.md to require CRLF line endings for new and modified files.'
    Assert-True -Condition ($Content.Contains('若工具产生 LF 行尾，提交前需转换为 CRLF 并检查确认')) -Message 'Expected AGENTS.md to require converting and checking LF line endings before commit.'
    Assert-True -Condition ($Content.Contains('不要主动提交代码')) -Message 'Expected AGENTS.md to include no-auto-commit instruction.'
    Assert-True -Condition ($Content.Contains('提交说明必须使用中文')) -Message 'Expected AGENTS.md to require Chinese commit messages.'
    Assert-True -Condition ($Content.Contains('feat: 添加数据导入功能')) -Message 'Expected AGENTS.md to include generic commit examples.'
    Assert-True -Condition ($Content.Contains('禁止自己创建分支')) -Message 'Expected AGENTS.md to require branch creation confirmation.'
}

function Assert-ClaudeLinkTargetsAgents {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $agentsPath = Join-Path -Path $ProjectPath -ChildPath '.agents'
    $linkPath = Join-Path -Path $ProjectPath -ChildPath '.claude'
    $linkItem = Get-Item -LiteralPath $linkPath -Force

    Assert-True -Condition (($linkItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) -Message "Expected .claude to be a symbolic link: $linkPath"
    Assert-True -Condition ($linkItem.LinkType -eq 'SymbolicLink') -Message "Expected .claude LinkType to be SymbolicLink: $linkPath"

    $target = $linkItem.Target
    if ($target -is [array]) {
        $target = $target[0]
    }

    Assert-True -Condition ([string]::Equals((Get-NormalizedPath -Path $target), (Get-NormalizedPath -Path $agentsPath), [System.StringComparison]::OrdinalIgnoreCase)) -Message "Expected .claude to target .agents. Actual target: $target"
}

function New-TestProject {
    $path = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('init-project-agents-test-' + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

$testRoot = New-TestProject

try {
    $emptyProject = Join-Path -Path $testRoot -ChildPath 'empty-project'
    New-Item -ItemType Directory -Path $emptyProject | Out-Null

    & $scriptPath -TargetDirectory $emptyProject | Out-Null

    Assert-PathDirectory -Path (Join-Path -Path $emptyProject -ChildPath '.agents')
    Assert-PathDirectory -Path (Join-Path -Path $emptyProject -ChildPath '.agents\skills')
    Assert-ClaudeLinkTargetsAgents -ProjectPath $emptyProject
    Assert-ProjectDocs -ProjectPath $emptyProject -ExpectedProjectName 'empty-project' -ExpectedProjectDescription '暂无项目说明'

    $fileProject = Join-Path -Path $testRoot -ChildPath 'file-project'
    New-Item -ItemType Directory -Path $fileProject | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $fileProject -ChildPath '.claude') -Value 'legacy file' -NoNewline

    & $scriptPath -TargetDirectory $fileProject | Out-Null

    Assert-PathDirectory -Path (Join-Path -Path $fileProject -ChildPath '.agents')
    Assert-PathDirectory -Path (Join-Path -Path $fileProject -ChildPath '.agents\skills')
    Assert-ClaudeLinkTargetsAgents -ProjectPath $fileProject
    Assert-ProjectDocs -ProjectPath $fileProject -ExpectedProjectName 'file-project' -ExpectedProjectDescription '暂无项目说明'

    $directoryProject = Join-Path -Path $testRoot -ChildPath 'directory-project'
    New-Item -ItemType Directory -Path (Join-Path -Path $directoryProject -ChildPath '.claude\commands') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path -Path $directoryProject -ChildPath '.claude\skills') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $directoryProject -ChildPath '.claude\settings.json') -Value '{"ok":true}' -NoNewline
    Set-Content -LiteralPath (Join-Path -Path $directoryProject -ChildPath '.claude\commands\launch.md') -Value 'launch' -NoNewline
    Set-Content -LiteralPath (Join-Path -Path $directoryProject -ChildPath '.claude\skills\legacy-skill.md') -Value 'legacy skill' -NoNewline

    & $scriptPath -TargetDirectory $directoryProject | Out-Null

    Assert-PathDirectory -Path (Join-Path -Path $directoryProject -ChildPath '.agents')
    Assert-PathDirectory -Path (Join-Path -Path $directoryProject -ChildPath '.agents\skills')
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path -Path $directoryProject -ChildPath '.agents\settings.json') -PathType Leaf) -Message 'Expected .claude/settings.json to migrate into .agents.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path -Path $directoryProject -ChildPath '.agents\commands\launch.md') -PathType Leaf) -Message 'Expected nested .claude content to migrate into .agents.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path -Path $directoryProject -ChildPath '.agents\skills\legacy-skill.md') -PathType Leaf) -Message 'Expected .claude/skills content to merge into .agents/skills.'
    Assert-ClaudeLinkTargetsAgents -ProjectPath $directoryProject
    Assert-ProjectDocs -ProjectPath $directoryProject -ExpectedProjectName 'directory-project' -ExpectedProjectDescription '暂无项目说明'

    $linkProject = Join-Path -Path $testRoot -ChildPath 'link-project'
    $agentsPath = Join-Path -Path $linkProject -ChildPath '.agents'
    New-Item -ItemType Directory -Path (Join-Path -Path $agentsPath -ChildPath 'skills') -Force | Out-Null
    New-Item -ItemType SymbolicLink -Path (Join-Path -Path $linkProject -ChildPath '.claude') -Value $agentsPath | Out-Null

    $result = & $scriptPath -TargetDirectory $linkProject

    Assert-ClaudeLinkTargetsAgents -ProjectPath $linkProject
    Assert-True -Condition ([bool]$result.LinkReused) -Message 'Expected correct .claude link to be reused.'
    Assert-ProjectDocs -ProjectPath $linkProject -ExpectedProjectName 'link-project' -ExpectedProjectDescription '暂无项目说明'

    $namedProject = Join-Path -Path $testRoot -ChildPath 'named-project'
    New-Item -ItemType Directory -Path $namedProject | Out-Null

    & $scriptPath -TargetDirectory $namedProject -ProjectName '命令面板扩展' -ProjectDescription '用于快速启动场景的扩展项目。' | Out-Null

    Assert-ProjectDocs -ProjectPath $namedProject -ExpectedProjectName '命令面板扩展' -ExpectedProjectDescription '用于快速启动场景的扩展项目。'

    $existingAgentsProject = Join-Path -Path $testRoot -ChildPath 'existing-agents-project'
    New-Item -ItemType Directory -Path $existingAgentsProject | Out-Null
    $existingAgentsPath = Join-Path -Path $existingAgentsProject -ChildPath 'AGENTS.md'
    Set-Content -LiteralPath $existingAgentsPath -Value "# Existing Project`r`n保留这段已有说明。" -NoNewline

    & $scriptPath -TargetDirectory $existingAgentsProject | Out-Null

    $existingAgentsContent = Get-Content -LiteralPath $existingAgentsPath -Raw
    Assert-True -Condition ($existingAgentsContent.Contains('保留这段已有说明。')) -Message 'Expected existing AGENTS.md content to be preserved.'
    Assert-CrlfFile -Path $existingAgentsPath
    Assert-RequiredAgentsContent -Content $existingAgentsContent

    & $scriptPath -TargetDirectory $existingAgentsProject | Out-Null

    $rerunAgentsContent = Get-Content -LiteralPath $existingAgentsPath -Raw
    $docsHeadingCount = ([regex]::Matches($rerunAgentsContent, [regex]::Escape('# 文档目录'))).Count
    $maintenanceHeadingCount = ([regex]::Matches($rerunAgentsContent, [regex]::Escape('# 文档维护策略'))).Count
    $worktreeHeadingCount = ([regex]::Matches($rerunAgentsContent, [regex]::Escape('# 工作树'))).Count
    $notesHeadingCount = ([regex]::Matches($rerunAgentsContent, [regex]::Escape('# 注意事项'))).Count
    Assert-True -Condition ($docsHeadingCount -eq 1) -Message 'Expected docs section to be appended only once.'
    Assert-True -Condition ($maintenanceHeadingCount -eq 1) -Message 'Expected documentation maintenance section to be appended only once.'
    Assert-True -Condition ($worktreeHeadingCount -eq 1) -Message 'Expected worktree section to be appended only once.'
    Assert-True -Condition ($notesHeadingCount -eq 1) -Message 'Expected notes section to be appended only once.'

    $legacyDocsProject = Join-Path -Path $testRoot -ChildPath 'legacy-docs-project'
    New-Item -ItemType Directory -Path $legacyDocsProject | Out-Null
    $legacyDocsAgentsPath = Join-Path -Path $legacyDocsProject -ChildPath 'AGENTS.md'
    Set-Content -LiteralPath $legacyDocsAgentsPath -Value @'
# Legacy Project

# 文档目录

- 计划文档需要按文件夹拆分，文件夹命名格式为 `001-XXXXXXXX`、`002-XXXXXXXXX`。

# 注意事项

- **不要主动提交代码**
'@ -NoNewline

    & $scriptPath -TargetDirectory $legacyDocsProject | Out-Null

    $legacyDocsContent = Get-Content -LiteralPath $legacyDocsAgentsPath -Raw
    $legacyDocsHeadingCount = ([regex]::Matches($legacyDocsContent, [regex]::Escape('# 文档目录'))).Count
    Assert-True -Condition ($legacyDocsHeadingCount -eq 1) -Message 'Expected legacy docs section to be replaced instead of duplicated.'
    Assert-True -Condition (-not $legacyDocsContent.Contains('计划文档需要按文件夹拆分')) -Message 'Expected legacy phase-oriented docs guidance to be removed.'
    Assert-True -Condition ($legacyDocsContent.Contains('NNN-业务主题')) -Message 'Expected legacy docs guidance to be replaced with business-topic guidance.'

    $gitNexusProject = Join-Path -Path $testRoot -ChildPath 'gitnexus-project'
    New-Item -ItemType Directory -Path $gitNexusProject | Out-Null
    $gitNexusAgentsPath = Join-Path -Path $gitNexusProject -ChildPath 'AGENTS.md'
    Set-Content -LiteralPath $gitNexusAgentsPath -Value @'
# Existing Project

<!-- gitnexus:start -->
# GitNexus
GitNexus instructions.
<!-- gitnexus:end -->

# Existing Tail
'@ -NoNewline

    & $scriptPath -TargetDirectory $gitNexusProject | Out-Null

    $gitNexusAgentsContent = Get-Content -LiteralPath $gitNexusAgentsPath -Raw
    $gitNexusSection = [regex]::Match($gitNexusAgentsContent, '(?s)<!-- gitnexus:start -->.*?<!-- gitnexus:end -->')
    Assert-True -Condition $gitNexusSection.Success -Message 'Expected GitNexus section to be preserved.'
    Assert-True -Condition ($gitNexusAgentsContent.TrimEnd().EndsWith($gitNexusSection.Value)) -Message 'Expected GitNexus section to be placed last.'

    & $scriptPath -TargetDirectory $gitNexusProject | Out-Null

    $rerunGitNexusContent = Get-Content -LiteralPath $gitNexusAgentsPath -Raw
    $gitNexusHeadingCount = ([regex]::Matches($rerunGitNexusContent, [regex]::Escape('<!-- gitnexus:start -->'))).Count
    Assert-True -Condition ($gitNexusHeadingCount -eq 1) -Message 'Expected GitNexus section to be preserved exactly once.'
    Assert-True -Condition ($rerunGitNexusContent.TrimEnd().EndsWith($gitNexusSection.Value)) -Message 'Expected GitNexus section to remain last after rerun.'

    'All Initialize-ProjectAgents tests passed.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedRoot = (Resolve-Path -LiteralPath $testRoot).ProviderPath
        $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())

        if (-not $resolvedRoot.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to clean path outside temp: $resolvedRoot"
        }

        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
