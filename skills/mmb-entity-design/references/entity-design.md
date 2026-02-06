# 实体设计规范

本文档描述了在 Materal.MergeBlock 项目中设计实体（Domain）时需要遵循的规范。

## 实体继承体系

### 继承关系

```
IEntity<T> (Materal.TTA.Common)
    ↓
IDomain (Materal.MergeBlock.Domain.Abstractions)
    ↓
BaseDomain (Materal.MergeBlock.Domain.Abstractions)
    ↓
{EntityName} (项目实体类)
```

### 基类源码

**BaseDomain** - 所有实体的基类：

```csharp
public abstract class BaseDomain : IDomain, IEntity<Guid>
{
    /// <summary>
    /// 唯一标识
    /// </summary>
    public Guid ID { get; set; }

    /// <summary>
    /// 创建时间
    /// </summary>
    public DateTime CreateTime { get; set; }

    /// <summary>
    /// 修改时间
    /// </summary>
    public DateTime UpdateTime { get; set; }
}
```

**IDomain** - 领域接口：

```csharp
public interface IDomain : IEntity<Guid>
{
    /// <summary>
    /// 创建时间
    /// </summary>
    DateTime CreateTime { get; }

    /// <summary>
    /// 修改时间
    /// </summary>
    DateTime UpdateTime { get; }
}
```

## 基本要求

### 命名规范

- **类名**：使用 PascalCase，如 `User`、`ClassCategory`
- **命名空间**：格式为 `{ProjectName}.{ModuleName}.Abstractions.Domain`
- **文件路径**：放在 `Abstractions/Domain/` 目录下

### 实体定义

```csharp
namespace {ProjectName}.{ModuleName}.Abstractions.Domain;

/// <summary>
/// 实体描述
/// </summary>
public class {EntityName} : BaseDomain, IDomain
{
    // 属性定义
}
```

### 文档注释

所有实体和属性必须包含 XML 文档注释。

## 实体类型

### 标准实体

最常见的实体类型，生成完整的 CRUD 功能。

```csharp
/// <summary>
/// 用户
/// </summary>
public class User : BaseDomain, IDomain
{
    /// <summary>
    /// 昵称
    /// </summary>
    [Required, StringLength(20)]
    [Contains]
    public string Nickname { get; set; } = string.Empty;

    /// <summary>
    /// 账号
    /// </summary>
    [Required, StringLength(20)]
    [Equal]
    [NotEdit]  // 账号创建后不可修改
    public string Account { get; set; } = string.Empty;

    /// <summary>
    /// 角色
    /// </summary>
    [Equal]
    [DTOText]  // 在 DTO 中显示为文本
    public Role Role { get; set; }
}
```

### 树形实体

支持树形结构的实体，需要实现 `ITreeDomain` 接口。

```csharp
/// <summary>
/// 部门
/// </summary>
public class Department : BaseDomain, IDomain, ITreeDomain
{
    /// <summary>
    /// 父级唯一标识
    /// </summary>
    [NotAdd, NotEdit, NotListDTO]
    public Guid? ParentID { get; set; }

    /// <summary>
    /// 名称
    /// </summary>
    [Required, StringLength(50)]
    [Contains]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// 分组（用于树分组查询）
    /// </summary>
    [TreeGroup]
    public Guid? GroupID { get; set; }
}
```

**ITreeDomain 接口**：

```csharp
public interface ITreeDomain : IDomain
{
    /// <summary>
    /// 父级
    /// </summary>
    Guid? ParentID { get; }
}
```

### 位序实体

支持位序排序的实体，需要实现 `IIndexDomain` 接口。

```csharp
/// <summary>
/// 菜单
/// </summary>
public class Menu : BaseDomain, IDomain, IIndexDomain
{
    /// <summary>
    /// 名称
    /// </summary>
    [Required, StringLength(50)]
    [Contains]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// 位序
    /// </summary>
    [NotAdd, NotEdit]
    public int Index { get; set; }

    /// <summary>
    /// 分组（用于位序分组）
    /// </summary>
    [IndexGroup]
    public Guid? GroupID { get; set; }
}
```

**IIndexDomain 接口**：

```csharp
public interface IIndexDomain : IDomain
{
    /// <summary>
    /// 位序
    /// </summary>
    int Index { get; }
}
```

### 视图实体

用于关联查询，将多个实体的数据聚合展示。

```csharp
/// <summary>
/// 班级视图
/// </summary>
[NotService, NotController, NotAdd, NotEdit, NotQuery, NotListDTO, NotDTO]
[View]
public class ClassView : BaseDomain, IDomain
{
    /// <summary>
    /// 班级类型名称
    /// </summary>
    [Required, StringLength(50)]
    [Contains]
    public string ClassCategoryName { get; set; } = string.Empty;

    /// <summary>
    /// 班级类型最小人数
    /// </summary>
    [GreaterThanOrEqual]
    public uint? ClassCategoryMinPeopleNumber { get; set; }
}
```

**关联查询配置**：在主实体上使用 `[QueryView(nameof(ViewEntity))]`：

```csharp
/// <summary>
/// 班级
/// </summary>
[QueryView(nameof(ClassView))]
public class Class : BaseDomain, IDomain
{
    // ...
}
```

### 关系实体

表示多对多关系的中间表实体。

```csharp
/// <summary>
/// 班级学生关系
/// </summary>
[NotService, NotController, NotAdd, NotEdit, NotQuery, NotListDTO, NotDTO]
public class ClassStudent : BaseDomain, IDomain
{
    /// <summary>
    /// 班级唯一标识
    /// </summary>
    [Required]
    [Equal]
    public Guid ClassID { get; set; }

    /// <summary>
    /// 学生唯一标识
    /// </summary>
    [Required]
    [Equal]
    public Guid StudentID { get; set; }

    /// <summary>
    /// 有效标识
    /// </summary>
    [NotAdd, NotEdit]
    [Required]
    [Equal]
    public bool IsValid { get; set; } = true;
}
```

### 附件实体

用于关联文件的实体，需要实现 `IAdjunctDomain` 接口。

```csharp
/// <summary>
/// 收款单附件
/// </summary>
[NotService, NotController, NotAdd, NotEdit, NotQuery, NotListDTO, NotDTO]
public class ReceiptBillAdjunct : BaseDomain, IDomain, IAdjunctDomain
{
    /// <summary>
    /// 收款单唯一标识
    /// </summary>
    [Required]
    public Guid ReceiptBillID { get; set; }

    /// <summary>
    /// 上传文件唯一标识
    /// </summary>
    [Required]
    public Guid UploadFileID { get; set; }
}
```

**IAdjunctDomain 接口**：

```csharp
public interface IAdjunctDomain : IDomain
{
    /// <summary>
    /// 上传文件唯一标识
    /// </summary>
    Guid UploadFileID { get; }
}
```

### 类特性

#### 代码生成控制特性

| 特性 | 说明 | 使用场景 |
|------|------|----------|
| `[NotAdd]` | 不生成 AddRequestModel 和 AddModel | 只读实体、自动生成字段的实体 |
| `[NotEdit]` | 不生成 EditRequestModel 和 EditModel | 不可修改的实体、业务规则不允许修改的字段 |
| `[NotQuery]` | 不生成 QueryRequestModel、QueryModel、树查询相关代码 | 只写不查的实体、敏感属性、大字段 |
| `[NotService]` | 不生成服务接口和实现 | 中间表、配置表、内部实体 |
| `[NotController]` | 不生成控制器接口、实现和访问器 | 内部实体、中间表、敏感数据表 |
| `[NotRepository]` | 不生成仓储接口和实现 | 纯内存对象、视图模型、聚合服务 |
| `[NotDTO]` | 不生成 DTO 和 ListDTO | 敏感属性、导航属性、大字段 |
| `[NotListDTO]` | 不生成 ListDTO | 大字段、详情属性、性能优化 |
| `[NotEntityConfig]` | 不生成实体配置类 | 计算属性、导航属性、手动配置 |
| `[NotInDBContext]` | 不在 DbContext 中生成 DbSet | 视图实体、只读查询实体、跨数据库实体 |

#### 特殊功能特性

| 特性 | 说明 | 使用场景 |
|------|------|----------|
| `[EmptyController]` | 生成空白控制器（不包含标准 CRUD） | 完全自定义控制器方法、只读模型 |
| `[EmptyService]` | 生成空白服务（不包含标准 CRUD） | 完全自定义服务方法、聚合服务 |
| `[EmptyTree]` | 树形实体不生成树相关代码 | 父子关系由业务控制、不需要树形展示 |
| `[EmptyIndex]` | 位序实体不生成位序交换代码 | 位序由系统自动维护、不允许手动调整 |
| `[Cache]` | 使用缓存仓储（继承 ICacheRepository） | 字典表、组织架构、读多写少的数据 |
| `[View]` | 标识为视图实体（调用 ToView 而非 ToTable） | 数据库视图、只读数据、聚合查询 |
| `[QueryView(nameof(ViewName))]` | 查询时使用指定视图/实体的属性 | 读写分离、查询优化、关联表冗余字段 |

## 属性定义

### 基本类型

#### 字符串属性

```csharp
// 必填字符串
public string Name { get; set; } = string.Empty;

// 可空字符串
public string? Description { get; set; }
```

#### 数值属性

```csharp
// 非空整数
public int Count { get; set; } = 0;

// 可空整数
public uint? MinPeopleNumber { get; set; }

// 金额
public decimal Amount { get; set; }
```

#### 布尔属性

```csharp
// 带默认值
public bool IsValid { get; set; } = true;

// 可空布尔
public bool? IsOnline { get; set; }
```

#### 枚举属性

```csharp
// 必填枚举
public Role Role { get; set; }

// 可空枚举
public SocialProperty? SocialProperty { get; set; }
```

### 属性特性

#### 验证特性

| 特性 | 说明 | 来源 | 示例 |
|------|------|------|------|
| `[Required]` | 必填验证 | System.ComponentModel.DataAnnotations | `[Required(ErrorMessage = "名称为空")]` |
| `[StringLength]` | 字符串长度限制 | System.ComponentModel.DataAnnotations | `[StringLength(50)]` |
| `[Min]` | 最小值验证 | Materal.Utils.Validation | `[Min(0)]` |
| `[Max]` | 最大值验证 | Materal.Utils.Validation | `[Max(100)]` |

#### 查询特性

| 特性 | 说明 | 生成内容 | 适用场景 |
|------|------|-----------|----------|
| `[Equal]` | 等值查询 | 单个查询参数 | 精确匹配（ID、状态、外键、布尔值） |
| `[Contains]` | 字符串包含 | 单个查询参数 | 模糊搜索（名称、描述） |
| `[StartContains]` | 字符串开头匹配 | 单个查询参数 | 前缀搜索（编号、区号） |
| `[NotEqual]` | 不等查询 | 单个查询参数 | 排除过滤（黑名单、已删除） |
| `[Between]` | 范围查询 | Min/Max 两个参数 | 价格范围、日期范围、数量范围 |
| `[GreaterThan]` | 大于查询 | 单个查询参数 | 范围查询下限（不包含边界） |
| `[GreaterThanOrEqual]` | 大于等于查询 | 单个查询参数 | 范围查询下限（包含边界） |
| `[LessThan]` | 小于查询 | 单个查询参数 | 范围查询上限（不包含边界） |
| `[LessThanOrEqual]` | 小于等于查询 | 单个查询参数 | 范围查询上限（包含边界） |

#### 代码生成控制特性（属性级别）

| 特性 | 说明 | 使用场景 |
|------|------|----------|
| `[NotAdd]` | 不在添加接口中暴露 | 系统自动生成的字段 |
| `[NotEdit]` | 不在编辑接口中暴露 | 不可修改的字段 |
| `[NotListDTO]` | 不生成列表 DTO | 敏感信息或不需要在列表中显示 |
| `[NotDTO]` | 不生成 DTO | 内部使用的字段 |
| `[NotQuery]` | 不在查询接口中暴露 | 不需要查询的字段 |
| `[NotEntityConfig]` | 不生成实体配置 | 特殊配置的属性 |
| `[LoginUserID]` | 登录用户唯一标识 | 自动填充当前登录用户ID |

#### 显示特性

| 特性 | 说明 | 生成内容 |
|------|------|----------|
| `[DTOText]` | 枚举类型自动生成文本属性 | 生成 `{PropertyName}Text` 属性，调用 `GetDescription()` 返回枚举的 Description 值 |

#### 数据库特性

| 特性 | 说明 | 生成代码 | 示例 |
|------|------|----------|------|
| `[ColumnType]` | 指定数据库列类型 | `HasColumnType(SqlType)` | `[ColumnType("decimal(18,2)")]` |

#### 结构特性

| 特性 | 说明 | 使用场景 |
|------|------|----------|
| `[TreeGroup]` | 树形实体的分组属性 | 多租户系统、分类树等需要独立树形结构的场景 |
| `[IndexGroup]` | 位序实体的分组属性 | 分类内独立排序、分组内位序管理等场景 |

## 字段命名规范

### 系统字段

系统字段由 `BaseDomain` 自动提供：

| 字段 | 类型 | 说明 | 特性 |
|------|------|------|------|
| `ID` | Guid | 唯一标识 | 自动生成 |
| `CreateTime` | DateTime | 创建时间 | 自动记录 |
| `UpdateTime` | DateTime | 修改时间 | 自动记录 |

### 外键命名

格式：`{RelatedEntityName}ID`

```csharp
/// <summary>
/// 班主任唯一标识
/// </summary>
[Required]
[Equal]
public Guid ClassSponsorID { get; set; }

/// <summary>
/// 班级类型唯一标识
/// </summary>
[Required]
[Equal]
public Guid ClassCategoryID { get; set; }
```

### 状态字段

```csharp
/// <summary>
/// 对账状态
/// </summary>
[NotAdd, NotEdit]
[Required]
[DTOText]
public ReconciliationState ReconciliationState { get; set; }
```

### 系统管理字段

```csharp
/// <summary>
/// 添加人
/// </summary>
[NotAdd, NotEdit]
[Required]
[LoginUserID]  // 自动填充当前登录用户ID
public Guid AddUserID { get; set; }

/// <summary>
/// 对账时间
/// </summary>
[NotAdd, NotEdit]
public DateTime? ReconciliationTime { get; set; }
```

### 金额字段

```csharp
/// <summary>
/// 收取金额
/// </summary>
[Required, Min(0)]
[ColumnType("decimal(18, 2)")]
public decimal ReceivedAmount { get; set; }
```

### 日期字段

```csharp
/// <summary>
/// 到账日期
/// </summary>
[Required]
[ColumnType("date")]
[Between]  // 生成 MinReceivedDate 和 MaxReceivedDate
public DateTime ReceivedDate { get; set; }

/// <summary>
/// 结束日期
/// </summary>
[NotAdd, NotEdit]
[Required]
[LessThanOrEqual]
[ColumnType("date")]
public DateTime EndDate { get; set; }
```

### 编号字段

```csharp
/// <summary>
/// 单号
/// </summary>
[NotAdd, NotEdit]
[Required, StringLength(16, MinimumLength = 16)]
public string Number { get; set; } = string.Empty;
```

## 完整示例

```csharp
namespace XMJ.Educational.Abstractions.Domain;

/// <summary>
/// 班级
/// </summary>
[QueryView(nameof(ClassView))]
public class Class : BaseDomain, IDomain
{
    /// <summary>
    /// 班级名称
    /// </summary>
    [Required(ErrorMessage = "名称为空"), StringLength(50)]
    [Contains]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// 班主任唯一标识
    /// </summary>
    [Required(ErrorMessage = "班主任唯一标识为空")]
    [Equal]
    public Guid ClassSponsorID { get; set; }

    /// <summary>
    /// 班级类型唯一标识
    /// </summary>
    [Required(ErrorMessage = "班级类型唯一标识为空")]
    [Equal]
    public Guid ClassCategoryID { get; set; }

    /// <summary>
    /// 结束日期
    /// </summary>
    [NotAdd, NotEdit]
    [Required(ErrorMessage = "结束日期为空")]
    [LessThanOrEqual]
    [ColumnType("date")]
    public DateTime EndDate { get; set; }

    /// <summary>
    /// 有效标识
    /// </summary>
    [NotAdd, NotEdit]
    [Required(ErrorMessage = "有效标识为空")]
    [Equal]
    public bool IsValid { get; set; } = true;
}
```

## 设计建议

1. **使用特性明确意图**：通过 `[Equal]`、`[Contains]`、`[Between]` 等特性明确字段的查询方式
2. **保护系统字段**：使用 `[NotAdd]`、`[NotEdit]` 保护系统自动生成的字段
3. **合理使用视图**：对于需要关联查询的场景，创建 View 实体并配合 `[NotService]`、`[NotController]` 等特性
4. **控制 DTO 生成**：使用 `[NotListDTO]`、`[NotDTO]` 控制敏感字段不暴露给前端
5. **命名一致性**：遵循 `{EntityName}ID` 外键命名规范，保持项目统一性
6. **使用登录用户标识**：对于需要记录操作人的字段，使用 `[LoginUserID]` 特性自动填充当前用户ID
7. **合理使用缓存**：对于频繁查询但不常变更的数据（如字典表），使用 `[Cache]` 特性
8. **树形结构设计**：树形实体需要实现 `ITreeDomain` 接口，并使用 `[TreeGroup]` 支持分组查询
9. **位序设计**：需要排序的实体应实现 `IIndexDomain` 接口，并使用 `[IndexGroup]` 支持分组排序
10. **枚举类型显示**：枚举字段使用 `[DTOText]` 自动生成 `{PropertyName}Text` 描述文本
11. **数据库列类型**：对于金额字段使用 `[ColumnType("decimal(18,2)")]`，日期字段使用 `[ColumnType("date")]`
12. **附件实体**：实现 `IAdjunctDomain` 接口的附件实体，配合 `[NotService]`、`[NotController]` 使用
