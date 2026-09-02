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

function New-GitIgnoreContent {
    $content = @'
# 操作系统文件
.DS_Store
Thumbs.db
ehthumbs.db
Desktop.ini

# IDE 文件
.vs/
.vscode/
.idea/
*.suo
*.user
*.userosscache
*.sln.docstates
*.swp

# .NET 构建输出和工具
**/[Bb]in/
**/[Oo]bj/
TestResults/
BenchmarkDotNet.Artifacts/
artifacts/
*.nupkg
packages/
project.lock.json
project.fragment.lock.json
*.tmp_proj
*.csproj.user
*.rsuser

# 前端依赖和包管理器文件
node_modules/
.npm/
.pnpm-store/
.yarn/*
!.yarn/patches
!.yarn/plugins
!.yarn/releases
!.yarn/versions
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# 前端构建输出和缓存
dist/
build/
coverage/
.next/
.nuxt/
.svelte-kit/
.parcel-cache/
.cache/
.vite/
.turbo/
.eslintcache

# 本地开发文件
.worktrees/
.env
.env.*
!.env.example

# 日志和临时文件
*.log
*.tmp
*.cache

# agent相关文件
.gitnexus
.claude
.agents/skills/generated
.agents/skills/gitnexus
CLAUDE.md
'@

    return $content + [Environment]::NewLine
}

function New-AgentsContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $header = "# $Name 项目"
    if (-not [string]::IsNullOrWhiteSpace($Description) -and $Description -ne '暂无项目说明') {
        $header += [Environment]::NewLine + $Description
    }

    return $header + [Environment]::NewLine + (New-RequiredAgentsContent -Name $Name) + [Environment]::NewLine
}

function New-RequiredAgentsContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return (
        (New-AgentsProjectStructureSection -Name $Name) + [Environment]::NewLine + [Environment]::NewLine +
        (New-AgentsDocumentationMaintenanceSection) + [Environment]::NewLine + [Environment]::NewLine +
        (New-AgentsWorktreeSection) + [Environment]::NewLine + [Environment]::NewLine +
        (New-AgentsNotesSection)
    )
}

function New-AgentsProjectStructureSection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $content = @'
# 项目目录结构

```text
__PROJECT_NAME__\
├─ docs\
│  ├─ plans\
│  │  ├─ 001-总体计划\
│  │  │  └─ design.md
│  │  └─ NNN-业务主题\
│  │     ├─ design.md
│  │     ├─ impl.md
│  │     ├─ testPlan.md
│  │     ├─ Client\
│  │     │  ├─ design.md
│  │     │  ├─ impl.md
│  │     │  ├─ Pages\
│  │     │  │  └─ <页面>\
│  │     │  │     ├─ design.md
│  │     │  │     └─ impl.md
│  │     │  └─ Components\
│  │     │     └─ <组件>\
│  │     │        ├─ design.md
│  │     │        └─ impl.md
│  │     └─ Server\
│  │        ├─ design.md
│  │        └─ impl.md
│  ├─ 需求分析\
│  │  ├─ <业务主题>.md
│  │  └─ <流程图>.mmd
│  └─ uml\
│     ├─ <模型或业务主题>.puml
│     ├─ <模型或业务主题>.wsd
│     └─ <补充图示>.mmd
├─ Server\
│  └─ <后端项目或服务>\
├─ Client\
│  └─ <客户端项目>\
└─ Demo\
   ├─ <技术主题或预研方向>\
   │  └─ <示例项目>\
   └─ <独立示例项目>\
```

- `docs` 存放项目文档，包含 `plans`、`需求分析`、`uml`；`Server` 存放后端项目，`Client` 存放 UI 客户端项目，`Demo` 存放示例和技术预研项目。
- 客户端项目直接位于 `Client/<客户端项目>`；每个 Demo 独立管理自己的目录结构和文件。
- 先在 `docs/需求分析/` 编写并确认需求，再编写 `docs/plans/001-总体计划/design.md`，最后由总体计划拆分业务主题；总体计划只保存总体设计和主题拆分依据。
- 计划目录命名为 `NNN-业务主题`，`NNN` 仅用于排序；每个业务主题包含 `design.md`、`impl.md`、`testPlan.md`，并按范围拆分 `Client`、`Server`、`Pages`、`Components` 等文档目录。
- `docs/plans/` 下的所有子目录只存放设计、实现和测试文档，不存放源代码。
- 仅当需求引入独立业务主题且用户明确要求时，才新建 `NNN-业务主题` 目录。
'@

    return $content.Replace('__PROJECT_NAME__', $Name)
}

function New-AgentsNotesSection {
    return @'
# 注意事项

- **新增或修改文件时应保持 CRLF 行尾；若工具产生 LF 行尾，提交前需转换为 CRLF 并检查确认**
- **不要主动提交代码**：执行 `git commit` 前必须询问用户确认
- **提交说明必须使用中文**：标题使用“`类型: 中文描述`”，类型可用 `feat`、`fix`、`refactor`、`docs`，例如 `feat: 添加数据导入功能`
- **禁止自己创建分支**：创建分支的动作需要获得用户的确定
'@
}

function New-AgentsWorktreeSection {
    return @'
# 工作树

- 未指定位置时，手工创建的 Git 工作树统一放在仓库根目录 `.worktrees/<工作树名称>`，并确保 `.worktrees/` 被忽略。
- 用户指定位置、名称、分支或创建方式时以用户要求为准；
'@
}

function New-AgentsDocumentationMaintenanceSection {
    return @'
# 文档维护策略

- `docs` 中的文档只保留当前有效状态，不保留历史版本、变更记录、实施日志或失效内容。
- 修改文档前先检索 `docs/`，直接更新最贴合的已有文件；既有主题范围内的增量继续维护该主题，归属不明确时先询问用户。
- 需求流程图和 UML 图使用可编辑源文件，分别存放于 `docs/需求分析/` 和 `docs/uml/`；渲染图片不能替代源文件。
- 除非用户明确要求，不创建 changelog、会议纪要、迁移记录、执行日志或临时设计；完成后说明更新的文件及新建文件的必要性和授权。
'@
}

function Add-MissingAgentsContent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ProjectName
    )

    $originalContent = Get-Content -LiteralPath $Path -Raw
    $content = $originalContent
    $gitNexusPattern = '(?s)<!-- gitnexus:start -->.*?<!-- gitnexus:end -->'
    $gitNexusMatch = [regex]::Match($content, $gitNexusPattern)
    if ($gitNexusMatch.Success) {
        $content = $content.Remove($gitNexusMatch.Index, $gitNexusMatch.Length)
    }

    $managedSections = @(
        @{ Headings = @('项目目录结构', '文档目录'); Content = (New-AgentsProjectStructureSection -Name $ProjectName) },
        @{ Headings = @('文档维护策略'); Content = (New-AgentsDocumentationMaintenanceSection) },
        @{ Headings = @('工作树'); Content = (New-AgentsWorktreeSection) },
        @{ Headings = @('注意事项'); Content = (New-AgentsNotesSection) }
    )

    foreach ($section in $managedSections) {
        $headingPattern = ($section.Headings | ForEach-Object { [regex]::Escape($_) }) -join '|'
        $sectionPattern = "(?ms)^# (?:$headingPattern)\s*$.*?(?=^# |\z)"
        $replacement = $section.Content.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine
        if ([regex]::IsMatch($content, $sectionPattern)) {
            $content = [regex]::Replace($content, $sectionPattern, $replacement, 1)
        }
        else {
            $content = $content.TrimEnd()
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $content += [Environment]::NewLine + [Environment]::NewLine
            }
            $content += $replacement
        }
    }

    $updatedContent = $content.TrimEnd()
    if ($gitNexusMatch.Success) {
        $updatedContent += [Environment]::NewLine + [Environment]::NewLine + $gitNexusMatch.Value.Trim()
    }
    $updatedContent += [Environment]::NewLine
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
$gitPath = Join-Path -Path $targetPath -ChildPath '.git'
$gitIgnorePath = Join-Path -Path $targetPath -ChildPath '.gitignore'
$linkPath = Join-Path -Path $targetPath -ChildPath '.claude'
$agentsFilePath = Join-Path -Path $targetPath -ChildPath 'AGENTS.md'
$claudeFilePath = Join-Path -Path $targetPath -ChildPath 'CLAUDE.md'

$gitInitialized = $false
$gitReused = $false
$gitIgnoreCreated = $false
$gitIgnoreReused = $false
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

if (Test-Path -LiteralPath $gitPath) {
    $gitReused = $true
}
else {
    & git -C $targetPath init | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to initialize Git repository: $targetPath"
    }

    $gitInitialized = $true
}

if (Test-Path -LiteralPath $gitIgnorePath) {
    if (-not (Test-Path -LiteralPath $gitIgnorePath -PathType Leaf)) {
        throw ".gitignore already exists and is not a file: $gitIgnorePath"
    }

    $gitIgnoreReused = $true
}
else {
    Write-Utf8File -Path $gitIgnorePath -Content (New-GitIgnoreContent)
    $gitIgnoreCreated = $true
}

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
    $agentsFileUpdated = Add-MissingAgentsContent -Path $agentsFilePath -ProjectName $projectNameValue
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
    GitPath = $gitPath
    GitInitialized = $gitInitialized
    GitReused = $gitReused
    GitIgnorePath = $gitIgnorePath
    GitIgnoreCreated = $gitIgnoreCreated
    GitIgnoreReused = $gitIgnoreReused
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
