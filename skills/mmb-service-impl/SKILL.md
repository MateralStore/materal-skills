---
name: mmb-service-impl
description: MMB (Materal.MergeBlock) 框架服务层扩展功能实现技能。用于在标准CRUD之外实现额外的业务功能，包括：(1) 添加自定义服务接口方法，(2) 创建服务模型，(3) 创建自定义DTO（可选），(4) 实现服务方法，(5) 使用工作单元模式进行数据操作。与 mmb-service-crud-impl 不同，本技能专注于非标准CRUD的业务功能实现。当需要添加标准CRUD之外的额外业务方法时使用此技能。
---

# MMB 服务扩展实现技能

本技能指导在 MMB 框架中实现标准 CRUD 之外的额外业务功能。

> **重要说明**：本技能仅用于实现**超出标准 CRUD 范围**的业务功能。

---

## 🎯 使用场景识别

### 何时使用本技能？

当用户提供**完整的任务文档**（如 UserManagement.md）时，请按以下步骤判断：

**判断任务类型**

本技能适用于以下非标准CRUD任务：

| 任务编号模式 | 任务类型 |
|-------------|---------|
| `T-{模块}-PWD-*` | 密码相关（重置、修改） |
| `T-{模块}-STATUS-*` | 状态更新（启用/停用） |
| `T-{模块}-PROFILE-*` | 个人中心（当前用户信息） |
| 其他自定义业务任务 | 扩展业务功能 |

## 功能边界

### 本技能处理

1. 标准 CRUD 之外的服务接口/服务实现扩展。
2. 业务扩展方法对应的服务模型、DTO（按需）、仓储配合与事务处理。
3. 密码、状态、个人中心、统计、批量等非标准业务能力。

### 本技能不处理

1. 标准 CRUD 五类动作：获取列表、获取详情、添加、修改、删除。
2. 标准 CRUD 服务实现（转 `mmb-service-crud-impl`）。
3. 标准 CRUD 控制器介入（转 `mmb-controller-crud-impl`）。
4. 非标准控制器实现细节（转 `mmb-controller-impl`）。

判定规则：优先按**操作语义**识别标准 CRUD，任务编号仅作辅助，不作为硬约束。

### 典型扩展功能示例

| 功能类型 | 示例 | 返回类型 | 是否需要DTO |
|---------|------|---------|------------|
| 重置密码 | ResetUserPasswordAsync | `string`（新密码） | 否 |
| 更新状态 | UpdateUserStatusAsync | `Task` | 否 |
| 获取当前用户 | GetCurrentUserAsync | `UserDTO` | 否（复用） |
| 修改个人信息 | UpdateCurrentUserAsync | `Task` | 否 |
| 修改密码 | ChangePasswordAsync | `Task` | 否 |
| 批量操作 | BatchDeleteAsync | `bool` | 否 |
| 统计数据 | GetStatisticsAsync | 自定义DTO | 是 |

---

## 工作流程

### 1. 创建/扩展服务接口

使用 `/mmb-path-resolver` 获取服务接口路径。

**⚠️ 重要：代码组织方式**

> **默认使用单文件模式**：所有扩展方法应集中在一个服务接口文件中，而不是分散到多个部分类文件。这样便于代码管理和维护。

**文件选择**：
- 如果 `{Module}.Abstractions\Services\I{Entity}Service.cs` 已存在 → 直接在该文件中添加新方法
- 如果不存在 → 创建 `I{Entity}Service.cs` 文件

**命名规范**：`I{Entity}Service.cs`

```csharp
public partial interface I{Entity}Service
{
    Task<ResultType> MethodNameAsync(ServiceModel model);
}
```

**示例**：
```csharp
// IUserService.cs（单个文件，包含所有扩展方法）
public partial interface IUserService
{
    Task<string> ResetUserPasswordAsync(ResetUserPasswordModel model);
    Task UpdateUserStatusAsync(UpdateUserStatusModel model);
    Task<UserDTO> GetCurrentUserAsync();
    Task UpdateCurrentUserAsync(UpdateCurrentUserModel model);
    Task ChangePasswordAsync(ChangePasswordModel model);
}
```

### 2. 创建服务模型

使用 `/mmb-path-resolver` 获取服务模型路径，在 `{Module}.Abstractions\Services\Models\{Entity}\` 创建模型文件。

**命名规范**：`{Purpose}{Entity}Model.cs`

```csharp
namespace ZhiTu.{Module}.Abstractions.Services.Models.{Entity}

public class {Purpose}{Entity}Model
{
    public Guid UserId { get; set; }
    public string Name { get; set; }
}
```

### 3. 判断是否需要创建 DTO

根据返回类型决定是否需要创建自定义 DTO：

| 返回类型 | 需要创建 DTO | 说明 |
|---------|-------------|------|
| 现有 DTO（如 `UserDTO`） | ❌ | 复用已有 DTO |
| 新的复合类型 | ✅ | 需要创建自定义 DTO |
| `string` | ❌ | 如返回新密码 |
| `bool` | ❌ | 如操作结果 |
| `void` / `Task` | ❌ | 无返回值 |

**如需创建 DTO**，使用 `/mmb-path-resolver` 获取路径，在 `{Module}.Abstractions\DTO\{Entity}\` 创建：

```csharp
namespace ZhiTu.{Module}.Abstractions.DTO.{Entity}

public class {Purpose}{Entity}DTO
{
    public Guid Id { get; set; }
    public string Name { get; set; }
}
```

### 4. 判断是否需要自定义仓储方法

分析业务需求，判断默认仓储是否满足需要。

**默认仓储提供的方法**：
| 方法类别 | 方法 | 说明 |
|---------|------|------|
| 根据ID获取 | `FirstOrDefaultAsync(id)` | 获取单个实体或null |
| 条件获取 | `FirstOrDefaultAsync(expression)` | 根据条件获取单个实体 |
| 检查存在 | `ExistedAsync(expression)` | 检查数据是否存在 |
| 计数 | `CountAsync(expression)` | 统计符合条件的数量 |
| 查询列表 | `FindAsync(expression)` | 查询所有符合条件的数据 |
| 带排序查询 | `FindAsync(expression, orderExpression, sortOrder)` | 查询并排序 |
| 分页查询 | `PagingAsync(...)` | 分页查询 |
| 范围查询 | `RangeAsync(...)` | 范围查询（skip/take） |

**需要自定义仓储的情况**：
- 复杂多表联合查询
- 需要优化性能的特殊查询
- 批量操作
- 复杂聚合计算

如果需要自定义仓储方法，使用 `/mmb-repository-impl` 技能实现。

### 5. 创建/扩展服务实现

使用 `/mmb-path-resolver` 获取服务实现路径。

**⚠️ 重要：代码组织方式**

> **默认使用单文件模式**：所有扩展方法的实现应集中在一个服务实现文件中，而不是分散到多个部分类文件。

**文件选择**：
- 如果 `{Module}.Application\Services\{Entity}ServiceImpl.cs` 已存在 → 直接在该文件中添加新方法
- 如果不存在 → 创建 `{Entity}ServiceImpl.cs` 文件

**命名规范**：`{Entity}ServiceImpl.cs`

```csharp
public partial class {Entity}ServiceImpl
{
    // 字段定义（如有需要）
    private readonly ApplicationConfig _applicationConfig;

    // 构造函数（如有需要）
    public {Entity}ServiceImpl(IOptions<ApplicationConfig> applicationConfig)
    {
        _applicationConfig = applicationConfig.Value;
    }

    public async Task<ResultType> MethodNameAsync(ServiceModel model)
    {
        // 业务逻辑实现
    }
}
```

### 6. 运行代码生成器

```bash
MMB GeneratorCode --ModulePath <模块路径>
```

---

## 数据操作指南

### 获取数据

```csharp
// 根据ID获取单个实体
User user = await DefaultRepository.FirstOrDefaultAsync(userId)
    ?? throw new ZhiTuException("用户不存在");

// 检查是否存在
bool existed = await DefaultRepository.ExistedAsync(m => m.Account == account);
```

### 保存更改

```csharp
// 注册修改
UnitOfWork.RegisterEdit(user);

// 提交事务
await UnitOfWork.CommitAsync();
```

### 当前用户

```csharp
// 从登录上下文获取当前用户ID
Guid currentUserId = LoginUserID;
```

---

## 常见操作

| 操作 | 仓储方法 | 说明 |
|-----|---------|------|
| 根据ID获取 | `FirstOrDefaultAsync(id)` | 返回单个实体或null |
| 条件查询 | `FirstOrDefaultAsync(expression)` | 根据条件获取单个实体 |
| 检查存在 | `ExistedAsync(expression)` | 检查数据是否存在 |
| 注册添加 | `UnitOfWork.RegisterAdd(entity)` | 注册添加操作 |
| 注册修改 | `UnitOfWork.RegisterEdit(entity)` | 注册修改操作 |
| 注册删除 | `UnitOfWork.RegisterDelete(entity)` | 注册删除操作 |
| 提交事务 | `UnitOfWork.CommitAsync()` | 提交所有操作 |

---

## 注意事项

1. **⚠️ 代码组织方式 - 默认使用单文件模式**
   - **服务接口**：所有扩展方法应集中在 `I{Entity}Service.cs` 单个文件中
   - **服务实现**：所有扩展方法实现应集中在 `{Entity}ServiceImpl.cs` 单个文件中
   - **不要**创建多个分散的部分类文件（如 `I{Entity}Service.{Purpose}.cs`）
   - **原因**：单文件模式便于代码管理和维护，避免文件碎片化
2. **禁止修改 MGC 文件**：所有自定义代码必须在部分类中实现（使用 `partial class`，但集中在单个文件中）
3. **使用工作单元**：所有写操作必须通过 `UnitOfWork.RegisterXxx` + `CommitAsync`
4. **异常处理**：所有异常处理必须使用 `/mmb-exception-handling` 技能实现
   - 统一抛出业务异常（如 `ZhiTuException`）
   - 参数验证、数据不存在、业务规则违反等都抛出业务异常
5. **密码加密**：使用 `PasswordHelper.HashPassword()` 进行 SHA256 加密
6. **权限验证**：在服务层验证权限（如管理员角色检查）
7. **不涉及控制器**：本技能专注于服务层实现，**不创建**控制器接口、控制器实现或请求模型。控制器相关内容由代码生成器自动生成，或在需要自定义时由其他专门技能处理

---

## 相关技能

- `mmb-path-resolver`：解析文件路径
- `mmb-repository-impl`：实现自定义仓储
- `mmb-generator`：运行代码生成器
- `mmb-exception-handling`：异常处理规范
