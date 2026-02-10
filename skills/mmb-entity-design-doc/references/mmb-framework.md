# MMB 框架规范

## 命名空间

```
Materal.MergeBlock.Domain.Abstractions
```

## 基类和接口

### BaseDomain（抽象基类）

所有实体类必须继承此基类。

**提供的字段**：
- `Guid ID` - 主键
- `DateTime CreateTime` - 创建时间
- `DateTime UpdateTime` - 更新时间

```csharp
public abstract class BaseDomain : IDomain, IEntity<Guid>
{
    public Guid ID { get; set; }
    public DateTime CreateTime { get; set; }
    public DateTime UpdateTime { get; set; }
}
```

### IDomain（接口）

领域模型接口，由 BaseDomain 实现。

**定义的字段**：
- `DateTime CreateTime` - 创建时间
- `DateTime UpdateTime` - 更新时间

### IIndexDomain（接口）

有序实体接口，继承自 IDomain。

**额外提供的字段**：
- `int Index` - 位序

```csharp
public interface IIndexDomain : IDomain
{
    int Index { get; set; }
}
```

### ITreeDomain（接口）

树形实体接口，继承自 IDomain。

**额外提供的字段**：
- `Guid? ParentID` - 父级ID

```csharp
public interface ITreeDomain : IDomain
{
    Guid? ParentID { get; set; }
}
```

## 命名规范

- 主键字段：`ID`（全大写）
- 外键字段：`{Entity}ID`（如 `ParentID`、`CategoryID`、`FlowchartID`）
- 时间字段：`CreateTime`、`UpdateTime`（帕斯卡命名）
