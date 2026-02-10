# EF Core 迁移命令映射（MMB 项目）

## 目的

用于在终端环境中替代 VS 包管理控制台（PMC）的迁移操作。

## 命令映射

- `Add-Migration Name -Project Repo -StartupProject WebApi`
  - `dotnet ef migrations add Name --project Repo.csproj --startup-project WebApi.csproj`
- `Remove-Migration -Project Repo -StartupProject WebApi`
  - `dotnet ef migrations remove --project Repo.csproj --startup-project WebApi.csproj`
- `Update-Database -Project Repo -StartupProject WebApi`
  - `dotnet ef database update --project Repo.csproj --startup-project WebApi.csproj`

## 本仓库示例

```powershell
dotnet ef migrations add InitMain `
  --project .\ZhiTu.Main\ZhiTu.Main.Repository\ZhiTu.Main.Repository.csproj `
  --startup-project .\ZhiTu.Main\ZhiTu.Main.WebAPI\ZhiTu.Main.WebAPI.csproj `
  --output-dir Migrations
```

## 参考链接

- EF Core CLI `dotnet ef`：
  - https://learn.microsoft.com/en-us/ef/core/cli/dotnet
- EF Core PMC（`Add-Migration`、`Update-Database` 等）：
  - https://learn.microsoft.com/en-us/ef/core/cli/powershell
- 设计时 DbContext 创建（启动项目相关）：
  - https://learn.microsoft.com/en-us/ef/core/cli/dbcontext-creation
