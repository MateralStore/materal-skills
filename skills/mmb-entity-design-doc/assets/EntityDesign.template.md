# {项目名称} - 实体类设计

## 基础字段

所有实体类继承自 MMB 框架的 `BaseDomain` 抽象类，并实现 `IDomain` 接口，自动包含以下字段：

| 属性 | 类型 | 说明 |
|------|------|------|
| ID | Guid | 主键 |
| CreateTime | DateTime | 创建时间 |
| UpdateTime | DateTime | 更新时间 |

**有序实体**：如果实体是有序的，还需要实现 `IIndexDomain` 接口，额外包含以下字段：

| 属性 | 类型 | 说明 |
|------|------|------|
| Index | int | 位序 |

**树形实体**：如果实体是树形结构，还需要实现 `ITreeDomain` 接口，额外包含以下字段：

| 属性 | 类型 | 说明 |
|------|------|------|
| ParentID | Guid? | 父级ID |

**框架定义路径**：
- 基类：`Materal.MergeBlock.Domain.Abstractions.BaseDomain`
- 接口：`Materal.MergeBlock.Domain.Abstractions.IDomain`
- 位序接口：`Materal.MergeBlock.Domain.Abstractions.IIndexDomain`
- 树形接口：`Materal.MergeBlock.Domain.Abstractions.ITreeDomain`

---

## 1. {实体名称}（{中文说明}）

> 实现 `IIndexDomain` 和 `ITreeDomain` 接口（可选）

| 属性 | 类型 | 说明 | 约束 |
|------|------|------|------|
| {PropertyName} | {Type} | {说明} | {约束} |

### 枚举定义（可选）

```csharp
// {枚举说明}
public enum {EnumName}
{
    // {枚举值}
}
```

**特殊说明**（可选）：
- {补充说明，如索引、数据结构等}

---

## {N}. {实体名称}

（重复实体定义格式）

---

## 实体关系图

```mermaid
erDiagram
    {Entity1} ||--o{ {Entity2} : "{关系说明}"
    {Entity2} ||--o{ {Entity3} : "{关系说明}"
    {Entity3} ||--o{ {Entity4} : "{关系说明}"
```
