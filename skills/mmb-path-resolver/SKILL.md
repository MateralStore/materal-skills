---
name: mmb-path-resolver
description: 根据 MMB (Materal.MergeBlock) 框架规范解析模块内各类文件的路径。接收模块名称、代码类型、可选的类名称、可选的相关实体，返回对应的文件路径或文件夹路径。支持：实体、枚举、DTO、请求模型、服务接口/实现、仓储接口/实现、控制器接口/实现、服务模型、事件等所有 MMB 框架代码类型的路径解析。用于：(1) 定位实体定义位置，(2) 查找服务接口/实现路径，(3) 确定仓储实现位置，(4) 解析控制器路径，(5) 其他 MMB 框架代码文件的路径定位。
---

# MMB 路径解析器

根据 MMB 框架规范解析各类代码文件的路径。

## 模块结构参考

```
{ProjectName}.{ModuleName}/
├── {ProjectName}.{ModuleName}.Abstractions/
│   ├── Domain/           ← 实体定义
│   ├── Enums/            ← 枚举定义
│   ├── DTO/              ← 自定义DTO
│   ├── RequestModel/     ← 自定义请求模型
│   ├── Services/         ← 自定义服务接口
│   │   └── Models/       ← 自定义服务模型
│   ├── Controllers/      ← 自定义控制器接口
│   ├── Events/           ← 事件定义
│   └── MGC/              ← 自动生成（禁止修改）
├── {ProjectName}.{ModuleName}.Application/
│   ├── Services/         ← 自定义服务实现
│   ├── Controllers/      ← 自定义控制器实现
│   ├── AutoMapperProfile/← 自动映射配置
│   ├── ScheduledTasks/   ← 定时任务
│   ├── EventHandlers/    ← 事件处理器
│   └── MGC/              ← 自动生成（禁止修改）
└── {ProjectName}.{ModuleName}.Repository/
    ├── Migrations/       ← 迁移文件（禁止修改）
    ├── Repositories/     ← 自定义仓储实现
    └── MGC/              ← 自动生成（禁止修改）
```

## 路径解析规则

### 输入参数
- **模块名称** (ModuleName): 如 `ZhiTu.Main`
- **代码类型** (CodeType): 实体、枚举、DTO、请求模型、服务接口、服务实现、服务模型、仓储接口、仓储实现、控制器接口、控制器实现、事件等
- **类名称** (ClassName): 可选，具体的类名称
- **相关实体** (EntityName): 可选，关联的实体名称（用于 DTO、请求模型、服务模型等类型的末级目录）

### 输出格式

使用反斜杠 `\` 作为路径分隔符（Windows 风格），以模块根目录结尾。

| 代码类型 | 相关实体 | 输出路径 |
|---------|---------|---------|
| 实体 | - | `{ProjectName}.{ModuleName}.Abstractions\Domain\` |
| 枚举 | - | `{ProjectName}.{ModuleName}.Abstractions\Enums\` |
| DTO | {EntityName} | `{ProjectName}.{ModuleName}.Abstractions\DTO\{EntityName}\` |
| 请求模型 | {EntityName} | `{ProjectName}.{ModuleName}.Abstractions\RequestModel\{EntityName}\` |
| 服务接口 | - | `{ProjectName}.{ModuleName}.Abstractions\Services\` |
| 服务实现 | - | `{ProjectName}.{ModuleName}.Application\Services\` |
| 服务模型 | {EntityName} | `{ProjectName}.{ModuleName}.Abstractions\Services\Models\{EntityName}` |
| 仓储接口 | - | `{ProjectName}.{ModuleName}.Abstractions\Repositories\` |
| 仓储实现 | - | `{ProjectName}.{ModuleName}.Repository\Repositories\` |
| 控制器接口 | - | `{ProjectName}.{ModuleName}.Abstractions\Controllers\` |
| 控制器实现 | - | `{ProjectName}.{ModuleName}.Application\Controllers\` |
| 事件 | - | `{ProjectName}.{ModuleName}.Abstractions\Events\` |
| 事件处理器 | - | `{ProjectName}.{ModuleName}.Application\EventHandlers\` |
| 定时任务 | - | `{ProjectName}.{ModuleName}.Application\ScheduledTasks\` |
| 自动映射配置 | - | `{ProjectName}.{ModuleName}.Application\AutoMapperProfile\` |

### 示例

```
输入: ZhiTu.Main | 实体 | - | -
输出: ZhiTu.Main\ZhiTu.Main.Abstractions\Domain\

输入: ZhiTu.Main | 枚举 | - | -
输出: ZhiTu.Main\ZhiTu.Main.Abstractions\Enums\

输入: ZhiTu.Main | 服务接口 | IUserService | -
输出: ZhiTu.Main\ZhiTu.Main.Abstractions\Services\

输入: ZhiTu.Main | 服务实现 | UserService | -
输出: ZhiTu.Main\ZhiTu.Main.Application\Services\

输入: ZhiTu.Main | 服务模型 | UserQueryModel | User
输出: ZhiTu.Main\ZhiTu.Main.Abstractions\Services\Models\User

输入: ZhiTu.Main | DTO | AddUserDTO | User
输出: ZhiTu.Main\ZhiTu.Main.Abstractions\DTO\User\

输入: ZhiTu.Main | 仓储接口 | IUserRepository | -
输出: ZhiTu.Main\ZhiTu.Main.Abstractions\Repositories\

输入: ZhiTu.Main | 仓储实现 | UserRepository | -
输出: ZhiTu.Main\ZhiTu.Main.Repository\Repositories\

输入: ZhiTu.Main | 控制器接口 | IUserController | -
输出: ZhiTu.Main\ZhiTu.Main.Abstractions\Controllers\

输入: ZhiTu.Main | 控制器实现 | UserController | -
输出: ZhiTu.Main\ZhiTu.Main.Application\Controllers\

输入: ZhiTu.Main | 请求模型 | AddUserRequestModel | User
输出: ZhiTu.Main\ZhiTu.Main.Abstractions\RequestModel\User\

输入: ZhiTu.Main | 请求模型 | UpdateUserRequestModel | User
输出: ZhiTu.Main\ZhiTu.Main.Abstractions\RequestModel\User\
```

## 代码类型别名

支持以下类型别名：

| 别名 | 标准类型 |
|-----|---------|
| Entity, 实体 | 实体 |
| Enum, 枚举 | 枚举 |
| Domain | 实体 |
| IService, Service Interface, 服务接口 | 服务接口 |
| Service, Service Implementation, 服务实现 | 服务实现 |
| Service Model, 服务模型 | 服务模型 |
| IRepository, Repository Interface, 仓储接口 | 仓储接口 |
| Repository, Repository Implementation, 仓储实现 | 仓储实现 |
| IController, Controller Interface, 控制器接口 | 控制器接口 |
| Controller, Controller Implementation, 控制器实现 | 控制器实现 |
| Event, 事件 | 事件 |
| EventHandler, Event Handler, 事件处理器 | 事件处理器 |
| ScheduledTask, 定时任务 | 定时任务 |
| AutoMapperProfile, Auto Mapper | 自动映射配置 |
