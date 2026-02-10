---
name: mmb-entity-impl
description: MMB (Materal.MergeBlock) 框架实体类编写技能。根据实体设计文档编写符合 MMB 规范的实体类和枚举。支持：(1) 从 EntityDesign.md 创建实体类，(2) 编写新的实体定义，(3) 确保实体符合 MMB 框架接口规范。参考 [references/framework.md](references/framework.md) 了解 MMB 框架接口定义，使用 [assets/](assets/) 下的模板。
---

# MMB 实体类编写

根据 MMB (Materal.MergeBlock) 框架规范编写实体类和枚举。

## 快速开始

1. **确定实体类型和接口**
   - 基础实体：继承 `BaseDomain`
   - 有序实体：实现 `IIndexDomain` 接口（添加 `Index` 字段）
   - 树形实体：实现 `ITreeDomain` 接口（添加 `ParentID` 字段）

2. **编写实体类**
   - 使用 `partial class`
   - 添加 XML 文档注释
   - 使用特性

3. **编写枚举**
   - 使用 XML 文档注释描述每个枚举值
   - 添加 `[Description]` 特性提供中文描述

## 代码规范

### 枚举模板

```csharp
namespace ZhiTu.Main.Abstractions.Enums;

/// <summary>
/// 枚举描述
/// </summary>
public enum EnumName
{
    /// <summary>
    /// 枚举值描述
    /// </summary>
    [Description("枚举值中文描述")]
    Value1 = 0,

    /// <summary>
    /// 枚举值描述
    /// </summary>
    [Description("枚举值中文描述")]
    Value2 = 1
}
```

**枚举规范**：
- 每个枚举值都必须指定明确的数值（从 0 开始递增）
- 每个枚举值都需要 `[Description("中文描述")]` 特性
- Description 的内容应与 XML 文档注释的描述一致

### 实体类模板

```csharp
namespace ZhiTu.Main.Abstractions.Domain;

/// <summary>
/// 实体描述
/// </summary>
public partial class EntityName : BaseDomain[, IIndexDomain, ITreeDomain]
{
    /// <summary>
    /// 属性描述
    /// </summary>
    [Required, MaxLength(50)]
    public string PropertyName { get; set; } = string.Empty;
}
```

**实体类必要引用**：
- `System.ComponentModel.DataAnnotations` - 验证特性（Required、MaxLength 等）
- `Materal.MergeBlock.Domain.Abstractions` - 框架基类和接口（BaseDomain、IDomain、IIndexDomain、ITreeDomain）
- `ZhiTu.Main.Abstractions.Enums` - 如果实体使用了自定义枚举类型

### 特性使用

| 特性 | 说明 | 影响 |
|------|------|------|
| `[MaxLength(n)]` | 最大长度 | 数据库字段长度限制 |
| `[Required]` | 必填字段 | **数据库字段 NOT NULL** |
| `[IndexGroup]` | 位序分组 | Index 在组内排序 |
| `[TreeGroup]` | 树形分组 | ParentID 在组内构建树 |

### IndexGroup 特性

用于实现了 `IIndexDomain` 接口的实体，指定位序的分组依据。

```csharp
/// <summary>
/// 流程图节点
/// </summary>
public partial class FlowchartNode : BaseDomain, IIndexDomain
{
    /// <summary>
    /// 流程图ID（位序分组依据）
    /// </summary>
    [Required]
    [IndexGroup]
    public Guid FlowchartID { get; set; }

    /// <summary>
    /// 位序（在相同 FlowchartID 内排序）
    /// </summary>
    public int Index { get; set; }
}
```

- **不使用 IndexGroup**：整个表的数据按 Index 排序
- **使用 IndexGroup**：按指定属性值分组，每组内按 Index 排序

### TreeGroup 特性

用于实现了 `ITreeDomain` 接口的实体，指定树形结构的分组依据。

```csharp
/// <summary>
/// 分类项
/// </summary>
public partial class CategoryItem : BaseDomain, ITreeDomain
{
    /// <summary>
    /// 分类ID（树形分组依据）
    /// </summary>
    [Required]
    [TreeGroup]
    public Guid CategoryID { get; set; }

    /// <summary>
    /// 父级ID（在相同 CategoryID 内构建树）
    /// </summary>
    public Guid? ParentID { get; set; }
}
```

- **不使用 TreeGroup**：整个表的数据按 ParentID 构建一个树
- **使用 TreeGroup**：按指定属性值分组，每组内按 ParentID 构建独立的树

### 同时实现 IIndexDomain 和 ITreeDomain

当实体同时实现有序接口和树形接口时（如分类），通常需要在 `ParentID` 上添加 `[IndexGroup]`，使 Index 在同级（相同父级）内排序：

```csharp
/// <summary>
/// 分类
/// </summary>
public partial class Category : BaseDomain, IIndexDomain, ITreeDomain
{
    /// <summary>
    /// 分类名称
    /// </summary>
    [Required, MaxLength(50)]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// 位序（同级分类之间的排序顺序）
    /// </summary>
    [Required]
    public int Index { get; set; }

    /// <summary>
    /// 父级ID（根分类为 null，也是 Index 的分组依据）
    /// </summary>
    [IndexGroup]
    public Guid? ParentID { get; set; }
}
```

### ⚠️ 特性重要性说明

**`[Required]` 和 `[MaxLength]` 特性直接影响数据库表结构：**

MMB 代码生成器会读取实体类的特性，自动生成 EF Core 配置：

| 实体特性 | 生成的 EF 配置 | 数据库约束 |
|---------|---------------|-----------|
| `[Required]` | `.IsRequired()` | **NOT NULL** |
| `[MaxLength(n)]` | `.HasMaxLength(n)` | 长度限制 |
| 无特性 | 不调用 `.IsRequired()` | **NULL** |

如果遗漏 `[Required]` 特性，数据库字段将允许 NULL，这与设计文档不符！

### 字段默认值

| 类型 | 默认值 |
|------|--------|
| `string` | `string.Empty` |
| 可空类型 | `null` (无需设置) |

## 文件路径

使用 `/mmb-path-resolver` 技能获取正确的文件路径：

```
实体: {ModuleName}.Abstractions/Domain/
枚举: {ModuleName}.Abstractions/Enums/
```

## 框架接口定义

详细接口定义见 [references/framework.md](references/framework.md)。

## ✅ 编写完成检查清单

### 枚举检查

- [ ] **每个枚举值都指定了明确的数值**（从 0 开始递增）
- [ ] **每个枚举值都有 `[Description("中文描述")]` 特性**
  - Description 内容与 XML 文档注释描述一致

### 实体类检查

- [ ] **必要的 using 引用完整**
  - `System.ComponentModel.DataAnnotations` - 验证特性
  - `Materal.MergeBlock.Domain.Abstractions` - 框架基类和接口
  - `ZhiTu.Main.Abstractions.Enums` - 如果使用了枚举
- [ ] **所有必填字段都添加了 `[Required]` 特性**
  - 对照设计文档的"约束"列，标有 `Required` 的都必须添加
  - 外键字段（如 `CategoryID`）通常也是必填的
- [ ] **字符串字段都添加了 `[MaxLength]` 特性**
  - 对照设计文档的"约束"列
- [ ] **同时实现 `IIndexDomain` 和 `ITreeDomain` 时**
  - 如果 Index 表示同级排序，在 `ParentID` 上添加 `[IndexGroup]`
- [ ] **字段默认值设置正确**
  - `string` 类型 = `string.Empty`
  - 可空类型无需设置默认值
- [ ] **XML 文档注释完整**
  - 每个属性都有 `/// <summary>` 注释

## 完成后处理

所有实体类和枚举编写完成并检查无误后，**必须**调用 `/remove-duplicate-usings` 技能处理所有创建的文件，移除与 `GlobalUsings.cs` 重复的 using 语句。

```bash
/remove-duplicate-usings ZhiTu.Main.Abstractions/Domain/*.cs ZhiTu.Main.Abstractions/Enums/*.cs
```
