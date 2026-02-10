param(
    [Parameter(Mandatory = $true)]
    [string]$MigrationName,
    [string]$ModuleName = "Main",
    [string]$RepositoryProject,
    [string]$StartupProject,
    [string]$OutputDir = "Migrations",
    [string[]]$ExtraEfArgs = @(),
    [string]$WorkspaceRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

function Resolve-SingleProject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchRoot,
        [Parameter(Mandatory = $true)]
        [string]$Filter,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    $matches = Get-ChildItem -Path $SearchRoot -Recurse -Filter $Filter -File
    if (-not $matches -or $matches.Count -eq 0) {
        throw "未找到 $DisplayName 项目: 搜索根目录=$SearchRoot, 过滤器=$Filter"
    }
    if ($matches.Count -gt 1) {
        $paths = $matches | ForEach-Object { $_.FullName } | Out-String
        throw "找到多个 $DisplayName 项目，请通过参数显式指定。候选项:`n$paths"
    }
    return $matches[0].FullName
}

function Resolve-ProjectPath {
    param(
        [string]$InputPath,
        [string]$FallbackSearchRoot,
        [string]$FallbackFilter,
        [string]$DisplayName
    )

    if ($InputPath) {
        $resolved = Resolve-Path $InputPath -ErrorAction Stop
        return $resolved.Path
    }

    return Resolve-SingleProject -SearchRoot $FallbackSearchRoot -Filter $FallbackFilter -DisplayName $DisplayName
}

$workspace = (Resolve-Path $WorkspaceRoot).Path
$moduleRoot = Join-Path $workspace ("ZhiTu.{0}" -f $ModuleName)
if (-not (Test-Path $moduleRoot)) {
    throw "模块目录不存在: $moduleRoot"
}

$repositoryProjectPath = Resolve-ProjectPath -InputPath $RepositoryProject -FallbackSearchRoot $moduleRoot -FallbackFilter "*.Repository.csproj" -DisplayName "Repository"
$startupProjectPath = Resolve-ProjectPath -InputPath $StartupProject -FallbackSearchRoot $moduleRoot -FallbackFilter "*.WebAPI.csproj" -DisplayName "WebAPI"

$null = & dotnet ef --version 2>$null
if ($LASTEXITCODE -ne 0) {
    throw @"
未检测到 dotnet-ef。
可执行以下命令安装：
1) 全局安装: dotnet tool install --global dotnet-ef
2) 本地安装: dotnet new tool-manifest; dotnet tool install dotnet-ef
"@
}

$args = @(
    "ef", "migrations", "add", $MigrationName,
    "--project", $repositoryProjectPath,
    "--startup-project", $startupProjectPath,
    "--output-dir", $OutputDir
)

if ($ExtraEfArgs -and $ExtraEfArgs.Count -gt 0) {
    $args += $ExtraEfArgs
}

$printArgs = $args | ForEach-Object {
    if ($_ -match "\s") { '"' + $_ + '"' } else { $_ }
}

Write-Host "Repository project: $repositoryProjectPath"
Write-Host "Startup project   : $startupProjectPath"
Write-Host ("Run command      : dotnet " + ($printArgs -join " "))

& dotnet @args
exit $LASTEXITCODE
