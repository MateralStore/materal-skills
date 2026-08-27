---
name: dbctl
description: 使用 MateralDBTools 的 dbctl 命令行工具管理命名数据库连接，并查询 SQL Server、PostgreSQL、Oracle 或 SQLite 数据库。用户请求查询数据库、验证连接、浏览表结构或执行经明确确认的写入 SQL 时使用。
---

# dbctl 数据库工具

## 发现与调用

`dbctl` 必须预先作为 .NET global tool 安装，并能在当前终端直接调用。执行数据库任务前先验证：

```powershell
Get-Command dbctl -CommandType Application
dotnet tool list --global
dbctl --help
```

找不到 `dbctl` 时停止并报告工具未安装或 `%USERPROFILE%\.dotnet\tools` 未加入 `PATH`。不要搜索解决方案、源码项目、`bin`、`publish` 目录，也不要在数据库任务中临时运行或构建 MateralDBTools。安装所需的包 ID、版本和 NuGet 源必须以 MateralDBTools 的实际发布配置为准，不得猜测。

## 安全规则

1. 优先使用命名连接配置。连接配置只保存环境变量引用，不把密码写入项目文件、示例配置或回复。
2. 临时连接使用 `--provider` 与 `--connection-env`，连接字符串只能来自环境变量。
3. 默认只执行只读查询。非只读 SQL 必须获得用户明确授权并使用 `--write`；非交互执行还必须加 `--yes-really`。
4. 删除命名连接配置前获得用户确认。添加配置不会覆盖同名配置，遇到冲突时先报告。
5. 使用 `--max-rows` 控制结果规模，不在通用示例中使用 `LIMIT`、`TOP` 或 `ROWNUM` 等数据库专用语法。
6. 查询结果如包含密码、密码散列、令牌、手机号、身份证件或医疗信息，只总结必要结论，不在回复中回显原始敏感值。

## 常用命令

```powershell
dbctl profiles list
dbctl profiles test <连接配置>
dbctl tables <连接配置> --format json
dbctl query <连接配置> --sql "SELECT * FROM example" --max-rows 10 --format json
dbctl query --provider postgres --connection-env DB_TEMP_CONNECTION --sql "SELECT 1" --max-rows 10
```

添加命名连接配置时，传入保存完整连接字符串的环境变量名：

```powershell
dbctl profiles add <连接配置> --provider postgres --connection-env DB_HIS_PG
```

## 验证

完成操作后报告实际执行的只读或写入范围、成功与否、返回行数限制，以及是否创建或清理了连接配置。不得将连接字符串或密码写入回复。
