[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetDirectory,

    [switch]$Force,

    [string]$ProjectName,

    [string]$ProjectDescription = '暂无项目说明'
)

$ErrorActionPreference = 'Stop'

function Get-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$BaseDirectory
    )

    $isFullyQualified = ($Path -match '^[A-Za-z]:[\\/]' -or $Path.StartsWith('\\'))

    if (-not $isFullyQualified) {
        if ([string]::IsNullOrWhiteSpace($BaseDirectory)) {
            $BaseDirectory = (Get-Location).ProviderPath
        }

        $Path = Join-Path -Path $BaseDirectory -ChildPath $Path
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-SamePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Left,

        [Parameter(Mandatory = $true)]
        [string]$Right
    )

    $normalizedLeft = (Get-FullPath -Path $Left).TrimEnd('\')
    $normalizedRight = (Get-FullPath -Path $Right).TrimEnd('\')

    return [string]::Equals($normalizedLeft, $normalizedRight, [System.StringComparison]::OrdinalIgnoreCase)
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDirectory,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory
    )

    Get-ChildItem -LiteralPath $SourceDirectory -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $DestinationDirectory -Recurse -Force
    }
}

function New-AgentsContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $template = @'
# __PROJECT_NAME__
__PROJECT_DESCRIPTION__
__REQUIRED_CONTENT__
'@

    return $template.Replace('__PROJECT_NAME__', $Name).Replace('__PROJECT_DESCRIPTION__', $Description).Replace('__REQUIRED_CONTENT__', (New-RequiredAgentsContent))
}

function New-RequiredAgentsContent {
    return (
        (New-AgentsDocsSection) + [Environment]::NewLine + [Environment]::NewLine +
        (New-AgentsDocumentationMaintenanceSection) + [Environment]::NewLine + [Environment]::NewLine +
        (New-AgentsWorktreeSection) + [Environment]::NewLine + [Environment]::NewLine +
        (New-AgentsNotesSection)
    )
}

function New-AgentsDocsSection {
    return @'
# 文档目录

```text
docs\
└─ plans\
   ├─ 001-总体计划\
   │  ├─ requirements.md
   │  ├─ <总体设计说明>.md
   │  └─ <总体图或补充说明>.mmd
   ├─ 002-引擎核心\
   │  ├─ design.md
   │  └─ impl.md
   └─ NNN-业务主题\
      ├─ design.md
      ├─ impl.md
      ├─ testPlan.md
      ├─ Client\
      │  ├─ design.md
      │  ├─ impl.md
      │  ├─ Pages\<页面名称>\
      │  │  ├─ design.md
      │  │  └─ impl.md
      │  └─ Components\<组件名称>\
      │        ├─ design.md
      │        └─ impl.md
      └─ Server\
         ├─ design.md
         ├─ impl.md
         └─ <复杂服务或模块>\
            ├─ design.md
            └─ impl.md
```

- 计划目录按业务主题拆分，命名格式为 `NNN-业务主题`，例如 `002-引擎核心`、`005-默认节点`；`NNN` 仅用于排序，不表示开发阶段、迭代批次或历史顺序。
- `001-总体计划` 保存项目整体的当前需求、总体设计和必要图示，不是变更记录目录。
- 其余主题目录应包含 `design.md` 和 `impl.md`；需要实施验证时，在目录根部补充 `testPlan.md`，并按实际范围拆分 `Client`、`Server`、页面、组件和复杂服务文档。
- 每一份文档只描述最终有效的当前状态。需求变化时更新既有文档并删除失效内容；不保留修订历史、实施过程、旧方案、变更日志或“曾经如此”的说明。
- 只有需求确实引入与现有目录不重叠的独立业务主题，且用户明确要求新建目录时，才创建新的 `NNN-业务主题` 目录。
'@
}

function New-AgentsNotesSection {
    return @'
# 注意事项

- **新增或修改文件时应保持 CRLF 行尾；若工具产生 LF 行尾，提交前需转换为 CRLF 并检查确认**
- **不要主动提交代码**：完成代码修改后不要自动执行 `git commit`，需要提交时询问用户确认
- **提交说明必须使用中文**：任何 `git commit` 的提交信息都必须使用中文，不要使用英文提交描述
- **提交标题格式建议**：`类型: 中文描述`，类型使用英文前缀，描述使用中文
  - 常用类型：`feat`（新功能）、`fix`（修复）、`refactor`（重构）、`docs`（文档）
  - 示例：`feat: 添加数据导入功能`、`fix: 修复保存失败问题`、`refactor: 优化服务处理流程`、`docs: 补充接口使用说明`
- **禁止自己创建分支**：创建分支的动作需要获得用户的确定
'@
}

function New-AgentsWorktreeSection {
    return @'
# 工作树

- 用户要求创建 Git 工作树且未指定位置时，在仓库根目录使用 `.worktrees/<工作树名称>`；先确认当前目录对应的 Git 仓库根目录，再执行 `git worktree add`。
- 将仓库根目录的 `.worktrees/` 作为本地工作目录，并确保它已被该仓库的 `.gitignore` 忽略；不要将其中的工作树文件纳入版本控制。
- 用户指定工作树位置、名称、分支或创建方式时，以用户要求为准。
- 此约定用于代理手工执行的 Git 工作树操作，不宣称或尝试通过 `AGENTS.md` 修改 Codex App 自动创建工作树的宿主路径。
'@
}

function New-AgentsDocumentationMaintenanceSection {
    return @'
# 文档维护策略

- `docs/plans/` 中的文档是**当前或已批准计划的最终状态**，不是工作日志、变更记录或历史档案；不要为保留旧版本、记录本次修改过程或描述一次小改动而新增 Markdown 文件或计划目录。
- 用户要求“修改文档”“补充文档”“同步文档”时，必须先检索 `docs/plans/`，按业务主题定位已有计划目录和已有 `design.md`、`impl.md`（以及对应 Client/Server、页面、组件文档），直接更新最贴合的现有文件。
- 目录编号仅用于排序，不表示开发阶段、迭代批次或历史顺序；对既有业务主题范围内的增量，继续维护该主题的既有文档。
- 只有在需求确实引入与现有目录不重叠的独立业务主题，且用户明确要求新建目录时，才能创建新的 `NNN-业务主题` 目录。若归属不明确，先询问用户；不得以新建文档代替判断。
- 更新时清理已失效的描述；保留仍然适用的约束、验收标准和未来计划，并明确其状态。除非用户明确要求，不创建 changelog、会议纪要、迁移记录、执行日志、临时设计等旁路文档。
- 完成文档修改后，说明更新了哪些既有文件；如新建了文件或目录，必须说明其与现有文档无法合并的原因及用户的明确授权。
'@
}

function Test-HasAgentsDocsSection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    return (
        $Content.Contains('文档目录') -and
        $Content.Contains('docs') -and
        $Content.Contains('plans') -and
        $Content.Contains('NNN-业务主题') -and
        $Content.Contains('仅用于排序') -and
        $Content.Contains('最终有效的当前状态') -and
        $Content.Contains('design.md') -and
        $Content.Contains('impl.md') -and
        $Content.Contains('按业务主题拆分')
    )
}

function Test-HasAgentsNotesSection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    return (
        $Content.Contains('新增或修改文件时应保持 CRLF 行尾') -and
        $Content.Contains('若工具产生 LF 行尾，提交前需转换为 CRLF 并检查确认') -and
        $Content.Contains('不要主动提交代码') -and
        $Content.Contains('提交说明必须使用中文') -and
        $Content.Contains('提交标题格式建议') -and
        $Content.Contains('禁止自己创建分支')
    )
}

function Test-HasAgentsDocumentationMaintenanceSection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    return (
        $Content.Contains('文档维护策略') -and
        $Content.Contains('当前或已批准计划的最终状态') -and
        $Content.Contains('直接更新最贴合的现有文件') -and
        $Content.Contains('用户明确要求新建目录')
    )
}

function Test-HasAgentsWorktreeSection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    return (
        $Content.Contains('工作树') -and
        $Content.Contains('.worktrees/<工作树名称>') -and
        $Content.Contains('.worktrees/') -and
        $Content.Contains('git worktree add') -and
        $Content.Contains('Codex App 自动创建工作树')
    )
}

function Move-GitNexusSectionToEnd {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $gitNexusPattern = '(?s)<!-- gitnexus:start -->.*?<!-- gitnexus:end -->'
    $match = [regex]::Match($Content, $gitNexusPattern)
    if (-not $match.Success) {
        return $Content
    }

    $contentWithoutGitNexus = $Content.Remove($match.Index, $match.Length).TrimEnd()
    if ([string]::IsNullOrWhiteSpace($contentWithoutGitNexus)) {
        return $match.Value.Trim()
    }

    return $contentWithoutGitNexus + ([Environment]::NewLine + [Environment]::NewLine) + $match.Value.Trim()
}

function Add-MissingAgentsContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $originalContent = Get-Content -LiteralPath $Path -Raw
    $content = $originalContent

    if ($content.Contains('计划文档需要按文件夹拆分')) {
        $legacyDocsPattern = '(?ms)^# 文档目录\s*$.*?(?=^# |\z)'
        $content = [regex]::Replace($content, $legacyDocsPattern, (New-AgentsDocsSection).TrimEnd(), 1)
    }

    $sectionsToAppend = @()

    if (-not (Test-HasAgentsDocsSection -Content $content)) {
        $sectionsToAppend += (New-AgentsDocsSection)
    }

    if (-not (Test-HasAgentsDocumentationMaintenanceSection -Content $content)) {
        $sectionsToAppend += (New-AgentsDocumentationMaintenanceSection)
    }

    if (-not (Test-HasAgentsWorktreeSection -Content $content)) {
        $sectionsToAppend += (New-AgentsWorktreeSection)
    }

    if (-not (Test-HasAgentsNotesSection -Content $content)) {
        $sectionsToAppend += (New-AgentsNotesSection)
    }

    $updatedContent = $content.TrimEnd()
    if ($sectionsToAppend.Count -gt 0) {
        if (-not [string]::IsNullOrWhiteSpace($updatedContent)) {
            $updatedContent += ([Environment]::NewLine + [Environment]::NewLine)
        }

        $updatedContent += ($sectionsToAppend -join ([Environment]::NewLine + [Environment]::NewLine))
    }

    $updatedContent = Move-GitNexusSectionToEnd -Content $updatedContent
    if ($updatedContent -eq $originalContent) {
        return $false
    }

    Write-Utf8File -Path $Path -Content $updatedContent

    return $true
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $normalizedContent = $Content -replace "`r`n", "`n"
    $normalizedContent = $normalizedContent -replace "`r", "`n"
    $normalizedContent = $normalizedContent -replace "`n", "`r`n"

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $normalizedContent, $utf8NoBom)
}

$targetPath = Get-FullPath -Path $TargetDirectory

if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
    throw "Target directory does not exist: $targetPath"
}

$projectNameValue = $ProjectName
if ([string]::IsNullOrWhiteSpace($projectNameValue)) {
    $projectNameValue = Split-Path -Path $targetPath -Leaf
}

if ([string]::IsNullOrWhiteSpace($projectNameValue)) {
    $projectNameValue = $targetPath
}

$agentsPath = Join-Path -Path $targetPath -ChildPath '.agents'
$skillsPath = Join-Path -Path $agentsPath -ChildPath 'skills'
$linkPath = Join-Path -Path $targetPath -ChildPath '.claude'
$agentsFilePath = Join-Path -Path $targetPath -ChildPath 'AGENTS.md'
$claudeFilePath = Join-Path -Path $targetPath -ChildPath 'CLAUDE.md'

$agentsCreated = $false
$skillsCreated = $false
$agentsFileCreated = $false
$agentsFileReused = $false
$agentsFileUpdated = $false
$claudeFileCreated = $false
$claudeFileReused = $false
$linkCreated = $false
$linkReused = $false
$linkRecreated = $false
$claudeDirectoryMigrated = $false
$claudeFileDeleted = $false

if (Test-Path -LiteralPath $agentsPath) {
    if (-not (Test-Path -LiteralPath $agentsPath -PathType Container)) {
        throw ".agents already exists and is not a directory: $agentsPath"
    }
}
else {
    New-Item -ItemType Directory -Path $agentsPath | Out-Null
    $agentsCreated = $true
}

if (Test-Path -LiteralPath $skillsPath) {
    if (-not (Test-Path -LiteralPath $skillsPath -PathType Container)) {
        throw ".agents\skills already exists and is not a directory: $skillsPath"
    }
}
else {
    New-Item -ItemType Directory -Path $skillsPath | Out-Null
    $skillsCreated = $true
}

if (Test-Path -LiteralPath $agentsFilePath) {
    if (-not (Test-Path -LiteralPath $agentsFilePath -PathType Leaf)) {
        throw "AGENTS.md already exists and is not a file: $agentsFilePath"
    }

    $agentsFileReused = $true
    $agentsFileUpdated = Add-MissingAgentsContent -Path $agentsFilePath
}
else {
    Write-Utf8File -Path $agentsFilePath -Content (New-AgentsContent -Name $projectNameValue -Description $ProjectDescription)
    $agentsFileCreated = $true
}

if (Test-Path -LiteralPath $claudeFilePath) {
    if (-not (Test-Path -LiteralPath $claudeFilePath -PathType Leaf)) {
        throw "CLAUDE.md already exists and is not a file: $claudeFilePath"
    }

    $claudeFileReused = $true
}
else {
    Write-Utf8File -Path $claudeFilePath -Content 'AGENTS.md'
    $claudeFileCreated = $true
}

$linkItem = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue

if ($null -ne $linkItem) {
    $isReparsePoint = (($linkItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
    $isDirectory = (($linkItem.Attributes -band [System.IO.FileAttributes]::Directory) -ne 0)

    if ($isReparsePoint) {
        $existingTarget = $linkItem.Target
        if ($existingTarget -is [array]) {
            $existingTarget = $existingTarget[0]
        }

        $normalizedExistingTarget = Get-FullPath -Path $existingTarget -BaseDirectory $targetPath

        if ($isDirectory -and (Test-SamePath -Left $normalizedExistingTarget -Right $agentsPath)) {
            $linkReused = $true
        }
        elseif ($Force) {
            Remove-Item -LiteralPath $linkPath -Force
            New-Item -ItemType SymbolicLink -Path $linkPath -Value $agentsPath | Out-Null
            $linkCreated = $true
            $linkRecreated = $true
        }
        else {
            throw ".claude already exists as a symbolic link but does not point to '$agentsPath'. Re-run with -Force to recreate it."
        }
    }
    elseif ($isDirectory) {
        Copy-DirectoryContents -SourceDirectory $linkPath -DestinationDirectory $agentsPath
        Remove-Item -LiteralPath $linkPath -Recurse -Force
        New-Item -ItemType SymbolicLink -Path $linkPath -Value $agentsPath | Out-Null
        $linkCreated = $true
        $claudeDirectoryMigrated = $true
    }
    else {
        Remove-Item -LiteralPath $linkPath -Force
        New-Item -ItemType SymbolicLink -Path $linkPath -Value $agentsPath | Out-Null
        $linkCreated = $true
        $claudeFileDeleted = $true
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
    AgentsCreated = $agentsCreated
    SkillsCreated = $skillsCreated
    AgentsFilePath = $agentsFilePath
    ClaudeFilePath = $claudeFilePath
    AgentsFileCreated = $agentsFileCreated
    AgentsFileReused = $agentsFileReused
    AgentsFileUpdated = $agentsFileUpdated
    ClaudeFileCreated = $claudeFileCreated
    ClaudeFileReused = $claudeFileReused
    LinkCreated = $linkCreated
    LinkReused = $linkReused
    LinkRecreated = $linkRecreated
    ClaudeDirectoryMigrated = $claudeDirectoryMigrated
    ClaudeFileDeleted = $claudeFileDeleted
}
