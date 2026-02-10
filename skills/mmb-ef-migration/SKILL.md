---
name: mmb-ef-migration
description: MMB (Materal.MergeBlock) 项目 EF Core 迁移技能。用于在非 Visual Studio 环境（终端/Codex/CI）中添加、回滚与检查迁移，重点解决“VS 包管理控制台 Add-Migration 如何映射到 dotnet ef 命令”的问题。使用场景：(1) 用户提到 Add-Migration/Update-Database/迁移文件，(2) 需要指定 WebAPI 启动项目与 Repository 目标项目，(3) 需要在 MMB 多模块结构中稳定生成 Migrations 文件。
---

# MMB EF 迁移

## 概述

此技能用于在 MMB 项目中执行 EF Core 迁移命令，避免依赖 Visual Studio 的包管理控制台。
核心原则：优先检索真实项目路径，再执行命令；不手改 `Migrations/` 与 `MGC/` 文件。

## VS 与 CLI 对照

`Add-Migration` 是 VS 包管理控制台命令。在终端中使用 `dotnet ef migrations add` 完成同等操作。

参数映射：

- VS PMC `-Project` (默认项目) -> CLI `--project`
- VS PMC `-StartupProject` (启动项目) -> CLI `--startup-project`
- VS PMC `-OutputDir` -> CLI `--output-dir`

## 工作流

1. 检索模块路径：先定位 `ZhiTu.{ModuleName}`。
2. 检索项目文件：在模块下查找 `*.Repository.csproj` 与 `*.WebAPI.csproj`。
3. 校验工具链：确认 `dotnet ef` 可用，不可用时先安装。
4. 执行迁移：运行 `dotnet ef migrations add` 并指定 `--project` 和 `--startup-project`。
5. 验证输出：确认 `Repository/Migrations` 下新增迁移文件。
6. 约束说明：迁移文件只允许工具生成，不手动编辑；禁止修改 `MGC/`。

## 快速命令（本仓库示例）

```powershell
dotnet ef migrations add InitMain `
  --project .\ZhiTu.Main\ZhiTu.Main.Repository\ZhiTu.Main.Repository.csproj `
  --startup-project .\ZhiTu.Main\ZhiTu.Main.WebAPI\ZhiTu.Main.WebAPI.csproj `
  --output-dir Migrations
```

如需指定环境参数：

```powershell
dotnet ef migrations add InitMain `
  --project .\ZhiTu.Main\ZhiTu.Main.Repository\ZhiTu.Main.Repository.csproj `
  --startup-project .\ZhiTu.Main\ZhiTu.Main.WebAPI\ZhiTu.Main.WebAPI.csproj `
  --output-dir Migrations `
  -- --environment Development
```

## 脚本化执行

使用脚本自动解析模块中的 Repository/WebAPI：

```powershell
powershell -ExecutionPolicy Bypass -File .\.agents\skills\mmb-ef-migration\scripts\add-migration.ps1 `
  -MigrationName InitMain `
  -ModuleName Main
```

可选参数：

- `-RepositoryProject`：手动指定仓储项目 `.csproj`
- `-StartupProject`：手动指定启动项目 `.csproj`
- `-OutputDir`：迁移输出目录（默认 `Migrations`）
- `-ExtraEfArgs`：附加 EF 参数（例如 `-- --environment Development`）

## 常见问题

1. `dotnet ef` 不存在
   处理：先安装工具，再重试。
   - 全局：`dotnet tool install --global dotnet-ef`
   - 本地：`dotnet new tool-manifest` 后 `dotnet tool install dotnet-ef`
2. 提示找不到 `DbContext`
   处理：检查 `--startup-project` 是否指向能加载配置和依赖的 WebAPI 项目。
3. 多个项目匹配
   处理：显式传入 `-RepositoryProject` 与 `-StartupProject`，避免误选。

## 参考资料

需要查命令细节时读取 `references/ef-core-command-mapping.md`。
