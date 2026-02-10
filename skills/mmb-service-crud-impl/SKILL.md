---
name: mmb-service-crud-impl
description: MMB (Materal.MergeBlock) 框架标准 CRUD 功能实现技能。仅实现实体的标准 CRUD 操作（添加、修改、删除、查询详情、查询列表），不包含额外的业务功能。包括：添加实体特性（NotAdd、NotEdit、NotDTO、NotListDTO、查询特性等）、识别特殊处理需求、重写服务方法、运行代码生成器。使用场景：(1) 实现新实体的标准 CRUD 功能，(2) 修改现有实体的 CRUD 逻辑，(3) 为实体添加查询筛选条件，(4) 处理添加/修改时的特殊验证或数据处理需求。
---

# MMB 框架 CRUD 实现指南

本技能指导实现实体的**标准 CRUD 操作**。

> **重要说明**：本技能仅实现**标准 CRUD 操作**（添加、修改、删除、查询详情、查询列表）。

---

## 🎯 使用场景识别

### 何时使用本技能？

当用户提供**完整的任务文档**（如 UserManagement.md）时，请按以下步骤判断：

**第一步：识别CRUD任务**

优先按**操作语义**识别标准 CRUD，任务编号仅作辅助，不作为硬约束。
即使文档没有 `01-05` 编号，只要语义匹配也应判定为 CRUD。

| 识别维度 | 内容 | 说明 |
|-------------|---------|---------|
| 操作语义（主判断） | 获取列表（筛选、分页） | ✅ CRUD |
| 操作语义（主判断） | 获取详情 | ✅ CRUD |
| 操作语义（主判断） | 添加 | ✅ CRUD |
| 操作语义（主判断） | 修改 | ✅ CRUD |
| 操作语义（主判断） | 删除 | ✅ CRUD |
| 常见编号示例（非必需） | `T-{模块}-CRUD-01~05` | 仅示例，不要求固定编号 |

**第二步：跳过非CRUD任务**

以下任务类型**不在本技能处理范围**：

| 常见任务标识（编号仅示例） | 功能类型 |
|-------------|---------|
| `T-{模块}-PWD-*` | 密码相关（重置、修改） |
| `T-{模块}-STATUS-*` | 状态更新（启用/停用） |
| `T-{模块}-PROFILE-*` | 个人中心（当前用户信息） |
| 其他自定义业务任务 | 扩展业务功能 |

---

## 功能范围

### 包含的功能（标准 CRUD）

| 操作 | 说明 | 典型场景 |
|------|------|---------|
| **获取列表** | 支持筛选条件、排序、分页 | 用户列表、商品列表 |
| **获取详情** | 根据ID获取单个实体的详细信息 | 用户详情、订单详情 |
| **添加** | 创建新实体，支持数据验证和默认值设置 | 添加用户、添加商品 |
| **修改** | 更新实体信息（仅允许修改特定字段） | 修改用户姓名、修改商品价格 |
| **删除** | 删除指定实体 | 删除用户、删除订单 |

### 不包含的功能

以下功能不属于标准CRUD范围：

- 重置密码、修改密码
- 启用/停用用户
- 获取/修改当前用户信息
- 批量操作
- 数据导出
- 统计报表

---

## 快速开始

CRUD 实现遵循以下流程：

```
1. 读取任务文档 → 分析CRUD特殊需求
2. 添加实体特性 → 为实体属性添加MMB特性
3. 运行代码生成 → 调用 /mmb-generator 技能
4. 创建服务实现 → 重写需要特殊处理的方法
```

---

## MMB 实体特性

### 数据操作特性

| 特性 | 用途 | 典型场景 | 生效范围 |
|------|------|---------|---------|
| `[NotAdd]` | 添加模型不包含 | Status（默认启用）、CreateTime（自动设置） | AddModel |
| `[NotEdit]` | 修改模型不包含 | Account（不可改）、Password（不可改） | EditModel |
| `[NotDTO]` | 详情 DTO 不包含 | Password（敏感字段） | DetailDTO |
| `[NotListDTO]` | 列表 DTO 不包含 | Password（敏感字段）、Description（太长） | ListDTO |

### 查询特性

| 特性 | 说明 | 示例 |
|------|------|------|
| `[Equal]` | 精准匹配 | 账号、角色、状态 |
| `[Contains]` | 模糊匹配（包含） | 姓名、标题 |
| `[NotEqual]` | 不等于 | 排除某个状态 |
| `[GreaterThan]` | 大于 | 创建时间、金额 |
| `[LessThan]` | 小于 | 截止时间 |
| `[GreaterThanOrEqual]` | 大于等于 | 开始时间 |
| `[LessThanOrEqual]` | 小于等于 | 结束时间 |
| `[Between]` | 之间（范围查询） | 日期范围 |
| `[StartContains]` | 以XXX开始 | 编号前缀 |
| `[EndContains]` | 以XXX结束 | 文件扩展名 |

### 特性组合示例

```csharp
public partial class User : BaseDomain
{
    // 账号：添加时需要，修改时不能改，查询时精准匹配
    [Required]
    [NotEdit]
    [Equal]
    public string Account { get; set; } = string.Empty;

    // 密码：添加时需要，不在DTO中显示
    [Required]
    [NotEdit]
    [NotDTO]
    [NotListDTO]
    public string Password { get; set; } = string.Empty;

    // 姓名：添加时需要，修改时可改，查询时模糊匹配
    [Required]
    [Contains]
    public string Name { get; set; } = string.Empty;

    // 状态：添加时不需要（默认启用），修改时不能改，查询时精准匹配
    [Required]
    [NotAdd]
    [NotEdit]
    [Equal]
    public UserStatus Status { get; set; }

    // 最后登录时间：添加时不需要（自动设置），修改时不能改
    [NotAdd]
    [NotEdit]
    public DateTime? LastLoginTime { get; set; }
}
```

---

## 仓储与工作单元

### 默认仓储提供的方法

MMB 框架的默认仓储已提供丰富的查询方法，标准 CRUD 通常无需自定义仓储。

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

> 完整仓储接口定义见 [framework-interfaces.md](references/framework-interfaces.md)

### 工作单元操作

MMB 框架使用**工作单元模式**进行数据库写操作。

```csharp
// 注册添加
UnitOfWork.RegisterAdd(entity);

// 注册修改
UnitOfWork.RegisterEdit(entity);

// 注册删除
UnitOfWork.RegisterDelete(entity);

// 提交事务
await UnitOfWork.CommitAsync();
```

### 仓储与工作单元的关系

1. **仓储**：负责查询操作（Read）
2. **工作单元**：负责写操作（Write）
3. **配合使用**：
   - 读取：使用 `DefaultRepository.FirstOrDefaultAsync()`
   - 写入：使用 `UnitOfWork.RegisterEdit()` + `CommitAsync()`

### 需要自定义仓储的情况

标准 CRUD 通常不需要自定义仓储。仅在以下情况考虑：
- 复杂多表联合查询
- 需要优化性能的特殊查询
- 批量操作
- 复杂聚合计算

如果需要，使用 `/mmb-repository-impl` 技能实现。

---

## 服务实现重写模式

### 常用重写方法速查

| 需求 | 推荐重写方法 | 示例场景 |
|------|-------------|---------|
| 数据验证、数据处理、设置默认值 | `AddAsync(TAddModel model)` | 验证账号唯一性、密码加密 |
| 软删除 | `DeleteAsync(TDomain domain)` | 设置删除标记而非物理删除 |
| 删除前验证 | `DeleteAsync(Guid id)` | 不允许删除自己 |
| 修改前验证 | `EditAsync(TEditModel model)` | 验证数据权限 |
| DTO 格式化、过滤 | `GetInfoAsync(TDTO dto)` | 隐藏敏感信息 |
| DTO 批量处理 | `GetListAsync(List<TListDTO> listDto, ...)` | 批量设置额外字段 |

## 异常处理

所有异常处理必须遵循 MMB 框架规范，使用 `/mmb-exception-handling` 技能来实现。

**基本规则**：
- 所有异常统一抛出业务异常（如 `ZhiTuException`）
- 参数验证失败：抛出业务异常
- 数据不存在：抛出业务异常
- 业务规则违反：抛出业务异常
- 所有异常消息应清晰、友好

```csharp
// 示例：数据验证
if (string.IsNullOrEmpty(model.Name))
{
    throw new ZhiTuException("姓名不能为空");
}

// 示例：数据不存在
User user = await DefaultRepository.FirstOrDefaultAsync(id);
if (user == null)
{
    throw new ZhiTuException("用户不存在");
}

// 示例：业务规则验证
if (await DefaultRepository.ExistedAsync(m => m.Account == model.Account))
{
    throw new ZhiTuException("账号已存在");
}
```

> **重要**：调用 `/mmb-exception-handling` 技能获取完整的异常处理规范。

> **完整方法列表**：查看 [BaseServiceImpl 源码](references/base-service-impl.md) 获取所有可重写方法的签名和默认实现。

---

## 工作流程

### 1. 读取任务文档

分析标准 CRUD 操作的特殊需求，**跳过非 CRUD 任务**。

**只处理（按语义判断）**：
- 获取列表（筛选、分页）
- 获取详情
- 添加
- 修改
- 删除
- `T-{模块}-CRUD-01~05` 仅为常见示例，不要求固定编号

**跳过**：
- T-{模块}-PWD-*、T-{模块}-STATUS-*、T-{模块}-PROFILE-* 等

### 2. 添加实体特性

根据任务需求添加特性到实体属性。

**特性决策表**：
| 需求 | 添加特性 |
|------|---------|
| 添加时不需要（自动设置） | `[NotAdd]` |
| 修改时不允许修改 | `[NotEdit]` |
| 详情中不显示（敏感信息） | `[NotDTO]` |
| 列表中不显示 | `[NotListDTO]` |
| 查询时精准匹配 | `[Equal]` |
| 查询时模糊匹配 | `[Contains]` |

### 3. 运行代码生成

```bash
MMB GeneratorCode --ModulePath <模块路径>
```

### 4. 创建服务实现

在 `Application\Services\` 创建或编辑 `{Entity}ServiceImpl.cs`

**⚠️ 重要：代码组织方式**

> **默认使用单文件模式**：所有重写方法和扩展方法应集中在一个服务实现文件中。

**文件选择**：
- 如果 `{Module}.Application\Services\{Entity}ServiceImpl.cs` 已存在 → 直接在该文件中添加重写方法
- 如果不存在 → 创建 `{Entity}ServiceImpl.cs` 文件

### 5. 重写方法

处理特殊需求（验证、数据处理、默认值设置等）

---

## 重要说明

### 本技能职责范围

本技能专注于**服务层实现**：

| 负责内容 | 说明 |
|---------|------|
| ✅ 实体特性配置 | 添加 NotAdd、NotEdit、NotDTO 等特性 |
| ✅ 服务实现 | 创建/编辑 `{Entity}ServiceImpl.cs` 单个文件，包含所有重写方法 |
| ✅ 服务模型 | 创建自定义服务模型 |
| ✅ DTO | 创建自定义 DTO（如需要） |
| ❌ 控制器接口 | 由代码生成器自动生成 |
| ❌ 控制器实现 | 由代码生成器自动生成 |
| ❌ 请求模型 | 由代码生成器自动生成 |

### 代码组织方式

> **默认使用单文件模式**：所有重写方法应集中在 `{Entity}ServiceImpl.cs` 单个文件中，而不是分散到多个部分类文件。

**原因**：
- 便于代码管理和维护
- 避免文件碎片化
- 更容易查看所有自定义逻辑

**控制器相关内容**：MMB 代码生成器会根据服务接口自动生成控制器代码。如需自定义控制器行为，由其他专门技能处理，本技能不涉及。

---

## 工具和技能

| 工具/技能 | 用途 |
|----------|------|
| `/mmb-path-resolver` | 解析文件路径 |
| `/mmb-generator` | 自动生成代码 |
| `/mmb-exception-handling` | 异常处理规范 |

---

## 详细参考

- [MMB 框架特性详解](references/mmb-features.md)
- [BaseServiceImpl 源码](references/base-service-impl.md) - 所有可重写方法的完整签名
- [framework-interfaces.md](references/framework-interfaces.md) - 仓储接口定义
