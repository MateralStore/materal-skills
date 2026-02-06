---
name: mmb-file-split
description: MMB (Materal.MergeBlock) 框架类文件拆分与合并技能。指导 LLM 按功能职责拆分 MMB 框架中臃肿的类文件，或将单一的简单自定义文件合并到主文件中，使用 partial class 方式组织代码。适用于：(1) 服务接口（I{Entity}Service）- Abstractions/Services/ 目录，(2) 服务实现（{Entity}ServiceImpl）- Application/Services/ 目录，(3) 控制器接口（I{Entity}Controller）- Abstractions/Controllers/ 目录，(4) 控制器实现（{Entity}Controller）- Application/Controllers/ 目录。使用场景：类变得臃肿需要重构时，代码生成后手动编写自定义方法时需要拆分文件，代码审查时发现类包含多个独立功能职责需要拆分时，只有一个简单自定义文件应该合并到主文件时。
---

# MMB 类文件拆分与合并

按功能职责拆分臃肿的类文件，或合并单一简单的自定义文件到主文件。

## 概述

本技能适用于 MMB 框架下的所有类文件：
- **服务接口**（`I{Entity}Service`）- `Abstractions/Services/`
- **服务实现**（`{Entity}ServiceImpl`）- `Application/Services/`
- **控制器接口**（`I{Entity}Controller`）- `Abstractions/Controllers/`
- **控制器实现**（`{Entity}Controller`）- `Application/Controllers/`

## 工作流程

### 第一步：识别目标类

1. **确定处理类型**：根据用户指定或上下文确定要处理的类类型
   - 服务接口：搜索 `**/Abstractions/Services/I*Service*.cs`
   - 服务实现：搜索 `**/Application/Services/*ServiceImpl*.cs`
   - 控制器接口：搜索 `**/Abstractions/Controllers/I*Controller*.cs`
   - 控制器实现：搜索 `**/Application/Controllers/*Controller*.cs`

2. **使用 Grep 搜索 partial class 定义**
   ```bash
   Grep "partial class {ClassName}" --glob "**/{Type}s/*.cs"
   ```

3. **忽略 MGC 文件夹**：MGC 下的文件是自动生成的，禁止修改

4. **列出所有相关文件**：
   - 主文件（如 `{ClassName}.cs`）
   - 自定义文件（如 `.Custom.cs`、`.Extended.cs` 等）
   - 拆分文件（如 `.{FeatureName}.cs`）

### 第二步：判断操作类型

检查文件结构并判断需要拆分还是合并：

#### 判断标准速查表

| 判断维度 | 合并条件 | 拆分条件 |
|---------|---------|---------|
| **文件数量** | 只有 1 个自定义文件 | 有多个拆分文件或需要拆分 |
| **方法数量** | < 10 个方法 | ≥ 10 个方法 |
| **文件行数** | < 300 行 | ≥ 300 行 |
| **功能领域** | 单一领域/高度关联 | 多个独立领域/低耦合 |
| **文件命名** | 无功能后缀（如 `.Custom.cs`） | 有功能后缀（如 `.UserManage.cs`） |

**决策逻辑**：
```
满足「任一拆分条件」→ 拆分
否则「全部合并条件」→ 合并
```

#### 需要合并的情况

满足以下**全部条件**时执行合并：

- ✅ 该类只有 1 个自定义文件（如 `.Custom.cs`、`.Extended.cs` 等）
- ✅ 没有按功能拆分的文件（文件名不包含功能后缀如 `.UserManage.cs`）
- ✅ 方法数量 < 10 个
- ✅ 总行数 < 300 行
- ✅ 功能属于单一紧密相关的领域
- ✅ 方法间高度关联

→ 执行**合并流程**（第三步 A）

#### 需要拆分的情况

满足以下**任一条件**时执行拆分：

- ✅ 文件行数 ≥ 300 行
- ✅ 方法数量 ≥ 10 个
- ✅ 包含多个独立功能领域（如用户管理、权限管理、数据导入导出等）
- ✅ 不同功能方法之间耦合度低
- ✅ 已存在拆分文件但组织不当需要重新拆分

→ 执行**拆分流程**（第三步 B）

### 第三步：执行操作

#### 3A. 合并流程

**操作步骤**：

1. 读取所有相关文件
2. 创建或更新主文件 `{ClassName}.cs`
3. 将所有内容合并到主文件中
4. 删除原自定义文件

**主文件结构**：
- 服务接口：接口声明、所有方法定义
- 服务实现：类声明、基类、构造函数、依赖注入字段、所有方法实现
- 控制器接口：接口声明、所有方法定义
- 控制器实现：类声明、基类、构造函数、所有端点实现

#### 3B. 拆分流程

**操作步骤**：

1. 分析所有方法，按功能分组
2. 规划拆分方案（每个功能组对应一个文件）
3. 创建/更新主文件，保留类声明、基类、构造函数、核心字段
4. 为每个功能组创建独立的拆分文件

**拆分原则**：
- 每个拆分文件包含一个独立功能领域的所有方法
- 拆分文件命名：`{ClassName}.{FeatureName}.cs`
- 所有文件都是 `partial class` 或 `partial interface`

## 各类型拆分规范

### 服务接口（I{Entity}Service）

**位置**：`ZhiTu.{Module}.Abstractions/Services/`

**主文件** `I{Entity}Service.cs` 包含：
- 接口声明
- 继承关系（如 `IApplicationService`）
- 基础 CRUD 方法（如有）
- 简单通用方法

**拆分文件** `I{Entity}Service.{FeatureName}.cs` 示例：
```
IAdminService.cs                    # 主文件
IAdminService.UserManage.cs         # 用户管理相关方法
IAdminService.RoleManage.cs         # 角色管理相关方法
IAdminService.Permission.cs         # 权限相关方法
```

**拆分文件结构**：
```csharp
public partial interface IAdminService
{
    Task<ResultDTO> CreateUserAsync(CreateUserModel model);
    Task<ResultDTO> UpdateUserAsync(UpdateUserModel model);
    Task<ResultDTO> DeleteUserAsync(Guid id);
}
```

### 服务实现（{Entity}ServiceImpl）

**位置**：`ZhiTu.{Module}.Application/Services/`

**主文件** `{Entity}ServiceImpl.cs` 包含：
- `partial class` 声明和基类继承（如 `BaseServiceImpl<...>`）
- 构造函数
- 依赖注入字段（`private readonly` 字段）
- 简单通用方法

```csharp
public partial class AdminServiceImpl : BaseServiceImpl<...>
{
    private readonly IUserService _userService;
    private readonly IRoleService _roleService;

    public AdminServiceImpl(...)
    {
        _userService = userService;
        _roleService = roleService;
    }
}
```

**拆分文件**示例：
```
AdminServiceImpl.cs                 # 主文件（类声明、字段）
AdminServiceImpl.UserManage.cs      # 用户管理实现
AdminServiceImpl.RoleManage.cs      # 角色管理实现
AdminServiceImpl.Auth.cs            # 认证实现
```

**拆分文件结构**：
```csharp
public partial class AdminServiceImpl
{
    public async Task<ResultDTO> CreateUserAsync(CreateUserModel model)
    {
        // 实现
    }

    public async Task<ResultDTO> UpdateUserAsync(UpdateUserModel model)
    {
        // 实现
    }
}
```

### 控制器接口（I{Entity}Controller）

**位置**：`ZhiTu.{Module}.Abstractions/Controllers/`

**主文件** `I{Entity}Controller.cs` 包含：
- 接口声明
- 基础端点方法

**拆分文件** `I{Entity}Controller.{FeatureName}.cs` 示例：
```
IAdminController.cs                  # 主文件
IAdminController.UserManage.cs       # 用户管理端点
IAdminController.RoleManage.cs       # 角色管理端点
IAdminController.DataExport.cs       # 数据导出端点
```

### 控制器实现（{Entity}Controller）

**位置**：`ZhiTu.{Module}.Application/Controllers/`

**主文件** `{Entity}Controller.cs` 包含：
- 控制器类声明
- `[Route]` 和 `[ApiController]` 特性
- 构造函数和依赖注入字段
- 简单通用端点

```csharp
[Route("api/admin")]
[ApiController]
public partial class AdminController : ControllerBase
{
    private readonly IAdminService _adminService;

    public AdminController(IAdminService adminService)
    {
        _adminService = adminService;
    }
}
```

**拆分文件**示例：
```
AdminController.cs                   # 主文件
AdminController.UserManage.cs        # 用户管理端点
AdminController.RoleManage.cs        # 角色管理端点
AdminController.DataExport.cs        # 数据导出端点
```

**拆分文件结构**：
```csharp
public partial class AdminController
{
    [HttpPost("users")]
    public async Task<IActionResult> CreateUserAsync([FromBody] CreateUserModel model)
    {
        var result = await _adminService.CreateUserAsync(model);
        return Ok(result);
    }

    [HttpPut("users/{id}")]
    public async Task<IActionResult> UpdateUserAsync(Guid id, [FromBody] UpdateUserModel model)
    {
        var result = await _adminService.UpdateUserAsync(model);
        return Ok(result);
    }
}
```

## 拆分决策示例

### 需要拆分的情况

**服务实现包含多个独立功能**：
```csharp
public class AdminServiceImpl
{
    // 用户管理相关 (5个方法)
    // 角色管理相关 (4个方法)
    // 权限管理相关 (3个方法)
    // 系统配置相关 (2个方法)
}
```
→ 拆分为 `AdminServiceImpl.UserManage.cs`、`AdminServiceImpl.RoleManage.cs` 等

**控制器包含多个功能模块端点**：
```csharp
public class UserController
{
    // 用户 CRUD 端点
    // 用户头像上传端点
    // 用户数据导出端点
    // 用户统计分析端点
}
```
→ 拆分为 `UserController.UserManage.cs`、`UserController.Avatar.cs`、`UserController.DataExport.cs` 等

### 无需拆分的情况

**单一紧密功能**：
```csharp
public class UserServiceImpl
{
    // 都是用户 CRUD 操作
    // 方法间高度关联
    // 总共 6 个方法
}
```
→ 保持单一文件

## 合并决策示例

### 需要合并的情况

**单一自定义文件**：

当前结构：
```
Services/
├── AdminServiceImpl.Custom.cs     # 只有 Custom.cs，包含简单登录功能
└── (无其他拆分文件)
```

判断条件：
- 只存在一个该类的自定义文件
- 功能属于单一领域（如管理员登录）
- 方法数量少（3-5 个）且高度相关
- 方法包括：登录、修改密码、重置密码、设置状态等

→ 合并到 `{ClassName}.cs` 主文件

合并后：
```
Services/
└── AdminServiceImpl.cs            # 包含所有实现
```

### 无需合并的情况

**已有合理拆分**：
```
Services/
├── AdminServiceImpl.cs
├── AdminServiceImpl.UserManage.cs
└── AdminServiceImpl.RoleManage.cs
```
→ 保持现有拆分结构

## 命名规范

### 拆分文件命名

格式：`{ClassName}.{FeatureName}.cs`

**常见功能后缀**：

| 后缀 | 用途 | 示例 |
|------|------|------|
| `.UserManage` | 用户管理 | `IAdminService.UserManage.cs` |
| `.RoleManage` | 角色管理 | `AdminController.RoleManage.cs` |
| `.Permission` | 权限管理 | `AdminServiceImpl.Permission.cs` |
| `.Auth` | 认证相关 | `UserController.Auth.cs` |
| `.DataExport` | 数据导出 | `ReportController.DataExport.cs` |
| `.DataImport` | 数据导入 | `UserController.DataImport.cs` |
| `.Statistics` | 统计分析 | `DashboardController.Statistics.cs` |
| `.Config` | 配置管理 | `SystemController.Config.cs` |
| `.Log` | 日志管理 | `AdminController.Log.cs` |

### 自定义文件命名

常见模式（用于合并前识别）：
- `{ClassName}.Custom.cs`
- `{ClassName}.Extended.cs`
- `{ClassName}Impl.cs`（服务实现直接写）
- 其他单一自定义文件命名

## 通用注意事项

1. **禁止修改 MGC**：始终忽略 MGC 文件夹下的文件（自动生成，禁止修改）
2. **命名空间一致**：拆分/合并后所有文件的命名空间必须一致
3. **Partial 限制**：partial class/interface 必须在同一程序集内
4. **访问权限**：拆分/合并不应影响访问权限和可见性
5. **依赖字段**：服务实现的主文件必须包含所有依赖注入字段
6. **接口对应**：服务接口和方法签名必须在服务实现中保持一致
7. **文件标识**：文件名包含 `.` 的（如 `XXX.UserManage.cs`）表示已按功能拆分
8. **合并规则**：只有一个非拆分的自定义文件 + 功能简单 → 合并到主文件

## 输出格式

完成拆分或合并后，输出：

```markdown
## 文件组织操作完成

### 操作类型
- 拆分 / 合并

### 目标类
- **类型**：{服务接口/服务实现/控制器接口/控制器实现}
- **类名**：{ClassName}
- **模块**：{ModuleName}

### 文件结构
**操作前**：
```
{文件列表}
```

**操作后**：
```
{文件列表}
```

### 操作详情
- 创建的文件：{列表}
- 修改的文件：{列表}
- 删除的文件：{列表}

### 功能分组
{拆分时显示}
- {FeatureName}：{方法列表}
```
