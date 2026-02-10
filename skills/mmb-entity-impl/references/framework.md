# MMB 框架接口定义

## BaseDomain 抽象类

所有实体类继承自 `Materal.MergeBlock.Domain.Abstractions.BaseDomain`，自动包含以下字段：

| 属性 | 类型 | 说明 |
|------|------|------|
| ID | Guid | 主键 |
| CreateTime | DateTime | 创建时间 |
| UpdateTime | DateTime | 更新时间 |

## IDomain 接口

`Materal.MergeBlock.Domain.Abstractions.IDomain` - 标识接口，所有实体必须实现。

## IIndexDomain 接口

`Materal.MergeBlock.Domain.Abstractions.IIndexDomain` - 有序实体接口，额外包含：

| 属性 | 类型 | 说明 |
|------|------|------|
| Index | int | 位序 |

### IndexGroup 特性

用于指定位序的分组依据。可添加在实现 `IIndexDomain` 的实体中的任意属性上。

```csharp
[IndexGroup]
public Guid FlowchartID { get; set; }
```

- **不使用 IndexGroup**：整个表的数据按 Index 排序
- **使用 IndexGroup**：按指定属性值分组，每组内按 Index 排序

## ITreeDomain 接口

`Materal.MergeBlock.Domain.Abstractions.ITreeDomain` - 树形实体接口，额外包含：

| 属性 | 类型 | 说明 |
|------|------|------|
| ParentID | Guid? | 父级ID |

### TreeGroup 特性

用于指定树形结构的分组依据。可添加在实现 `ITreeDomain` 的实体中的任意属性上。

```csharp
[TreeGroup]
public Guid CategoryID { get; set; }
```

- **不使用 TreeGroup**：整个表的数据按 ParentID 构建一个树
- **使用 TreeGroup**：按指定属性值分组，每组内按 ParentID 构建独立的树

## 命名空间

```csharp
using Materal.MergeBlock.Domain.Abstractions;
```

## 代码生成

MMB 框架使用代码生成器自动生成部分代码，因此实体类必须使用 `partial class` 声明。
