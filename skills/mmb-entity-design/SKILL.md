---
name: mmb-entity-design
description: MMB 框架实体设计技能。指导 LLM 按照 Materal.MergeBlock 框架规范设计实体类。在以下场景使用：(1) 用户明确要求设计实体时；(2) 开发流程中需要进行实体设计时（需求分析与功能设计完成后）；(3) 涉及创建、修改或审查 Domain 实体类时。读取技能内置的实体设计规范，输出符合 MMB 框架的实体类代码。此技能适用于所有使用 Materal.MergeBlock 框架的项目。
---

# MMB 实体设计

实体设计是 MMB 框架开发流程中的关键步骤（第3步），在**需求分析和功能设计完成后**进行。

## 工作流程

```
需求分析 → 功能设计 → 实体设计 → 任务拆解 → 代码生成 → 构建验证
                      ↑         ↓
                      └─────────┘
                    (可能需要迭代)
```

## 执行步骤

### 1. 环境检测

首先检测当前项目的模块结构：

```bash
# 查找项目模块结构
Glob "*/**/*.Abstractions/Domain/*.cs"
```

根据检测结果确定：
- **项目命名空间格式**：固定为 `{ProjectName}.{ModuleName}.Abstractions.Domain`
- **目标模块**：用户指定或自动推断

### 2. 检查输入

首先判断用户输入类型：

**用户已完成了需求分析和功能设计？**
→ 跳转到步骤 3

**用户只提供了简单需求描述？**
→ 提示用户先完成需求分析和功能设计：
  - 需求分析：收集功能概述、业务场景、涉及实体、业务规则
  - 功能设计：拆分功能模块，明确输入输出和处理逻辑
  - 完成后再进行实体设计

### 3. 读取规范文档

在开始设计前，阅读技能内置的规范文档：

```bash
# 读取实体设计规范
Read .claude/skills/entity-design/references/entity-design.md
```

### 4. 设计实体

根据规范文档，设计每个实体：

#### 4.1 检查已存在实体

**首先检查实体是否已存在：**

```bash
# 查找已存在的实体
Glob "**/{EntityName}.cs" --path "**/Abstractions/Domain"
```

**实体已存在？**
→ 读取现有代码，分析需要修改的内容：
```bash
Read {检测到的实体文件路径}
```
→ 跳转到 4.2，在现有基础上修改

**实体不存在？**
→ 直接跳转到 4.2 进行新实体设计

#### 4.2 确定实体类型

- **类型选择**：根据业务需求选择合适的实体类型
- **接口实现**：
  - 标准实体：`IDomain`
  - 树形实体：`IDomain, ITreeDomain`
  - 位序实体：`IDomain, IIndexDomain`
  - 视图实体：`IDomain` + `[View]`
  - 关系实体：`IDomain`
  - 附件实体：`IDomain, IAdjunctDomain`
- **类特性**：
  - 控制特性：`[NotService]`、`[NotController]`、`[NotRepository]`、`[NotDTO]`、`[NotListDTO]`、`[NotAdd]`、`[NotEdit]`、`[NotQuery]`、`[NotEntityConfig]`、`[NotInDBContext]`
  - 功能特性：`[View]`、`[QueryView(nameof(ViewName))]`、`[Cache]`、`[EmptyController]`、`[EmptyService]`、`[EmptyTree]`、`[EmptyIndex]`
- **必含属性**：
  - 树形实体：`Guid? ParentID`（可选 `Guid? TreeGroupID` 用于分组）
  - 位序实体：`int Index`（可选 `Guid? IndexGroupID` 用于分组）
  - 附件实体：`Guid UploadFileID`

#### 4.3 设计属性

- **命名**：使用 PascalCase
- **类型**：根据业务选择合适的数据类型
- **特性**：
  - 验证特性：`[Required]`、`[StringLength]`、`[Min]`、`[Max]`
  - 查询特性：`[Equal]`、`[Contains]`、`[StartContains]`、`[NotEqual]`、`[Between]`、`[GreaterThan]`、`[GreaterThanOrEqual]`、`[LessThan]`、`[LessThanOrEqual]`
  - 控制特性：`[NotAdd]`、`[NotEdit]`、`[NotDTO]`、`[NotListDTO]`、`[NotQuery]`、`[NotEntityConfig]`、`[LoginUserID]`
  - 显示特性：`[DTOText]`
  - 数据库特性：`[ColumnType]`
  - 结构特性：`[TreeGroup]`、`[IndexGroup]`

**重要**：同一属性上只能有一个查询特性（如 `[Equal]` 或 `[Contains]`），不能同时使用多个查询特性。

#### 4.4 验证特性合理性设计

设计验证特性时需考虑前端传参和后端处理的合理性：

**涉及加密的字段**（如密码）：
```csharp
// ❌ 错误：Password 有长度限制，前端无法传递原始密码
[Required(ErrorMessage = "密码为空")]
[StringLength(64, MinimumLength = 64)]
public string Password { get; set; } = string.Empty;

// ✅ 正确：Password 不限制长度，让前端传递原始密码，加密后存储自然满足要求
[Required(ErrorMessage = "密码为空")]
[NotDTO]      // 不在 DTO 中暴露
[NotListDTO]  // 不在列表 DTO 中暴露
public string Password { get; set; } = string.Empty;
```

**一般字段验证**：
```csharp
// ✅ 正确：普通字段可以有合理的长度限制
[Required(ErrorMessage = "名称为空")]
[StringLength(50, MinimumLength = 2, ErrorMessage = "名称长度2-50字符")]
[Contains]  // 用于模糊查询
public string Name { get; set; } = string.Empty;

// ✅ 正确：账号等唯一标识字段
[Required(ErrorMessage = "账号为空")]
[StringLength(20, MinimumLength = 3, ErrorMessage = "账号长度3-20字符")]
[Equal]     // 用于精确匹配查询
[NotEdit]   // 不允许修改
public string Account { get; set; } = string.Empty;
```

**设计原则**：
1. 加密字段（密码、密钥等）不应在实体层面限制长度，让前端传递原始数据
2. 普通字段可以设置合理的业务长度限制
3. 使用 `[NotDTO]`、`[NotListDTO]` 保护敏感字段不在接口中暴露
4. 使用 `[NotEdit]` 保护不应被修改的字段

### 5. 生成实体代码

#### 5.1 确定文件路径

```
{ProjectName}.{ModuleName}/Abstractions/Domain/{EntityName}.cs
```

#### 5.2 生成代码模板

**首先生成类上方的设计摘要注释**：

```csharp
/*
 * ## 实体设计摘要
 *
 * ### 实体类说明
 * - {实体描述}
 * - 类型：{标准/树形/位序/视图/关系/附件}实体
 * - 特性：{无/列出类级别特性如 NotService 等}
 *
 * ### 实体属性说明
 *
 * | 属性 | 类型 | 特性 | 说明 |
 * |------|------|------|------|
 * | `{PropertyName1}` | {Type1} | `{特性列表}` | {属性说明} |
 * | `{PropertyName2}` | {Type2} | `{特性列表}` | {属性说明} |
 * ...
 *
 * ### 关键设计决策
 * 1. **决策标题**：{设计决策说明}
 * 2. **决策标题**：{设计决策说明}
 * ...
 */
```

**然后生成实体类代码**：

```csharp
namespace {ProjectName}.{ModuleName}.Abstractions.Domain;

/// <summary>
/// {实体描述}
/// </summary>
[可选特性]
public class {EntityName} : BaseDomain, IDomain[, 可选接口]
{
    /// <summary>
    /// {属性描述}
    /// </summary>
    [特性]
    public {Type} {PropertyName} { get; set; }[ = defaultValue];
}
```

#### 5.3 写入文件

```bash
# 写入实体文件
Write {检测到的模块路径}/Abstractions/Domain/{EntityName}.cs
```

### 6. 汇总设计结果

输出设计摘要，包括：

```markdown
## 实体设计摘要

### 设计的实体
1. **{EntityName}** - {描述}
   - 类型：{标准/树形/位序/视图/关系/附件}
   - 路径：`{ProjectName}.{ModuleName}/Abstractions/Domain/{EntityName}.cs`

### 关键设计决策
- {决策1说明}
- {决策2说明}

### 下一步
运行 `/mmb-generator` 生成代码
```

**注意**：生成的实体类文件上方必须包含完整的设计摘要注释，以便后续维护和理解设计意图。

## 参考资源

### 完整规范

详见技能内置规范：[entity-design.md](references/entity-design.md)

### 常见模式

| 场景 | 模式 |
|------|------|
| 外键属性 | `{Entity}ID` + `[Equal]` + `[Required]` |
| 状态枚举 | `[NotAdd, NotEdit]` + `[DTOText]` |
| 金额字段 | `[ColumnType("decimal(18,2)")]` |
| 日期范围 | `[Between]` → 生成 Min/Max 参数 |
| 系统字段 | `[NotAdd, NotEdit]` + `[LoginUserID]` |
| 敏感字段 | `[NotDTO]` 或 `[NotListDTO]` |
| 查询特性选择 | 账号/ID 用 `[Equal]`，姓名/描述用 `[Contains]`，**同一属性只能有一个查询特性** |

## 注意事项

1. **禁止修改 MGC 文件夹**：MGC 下的文件是自动生成的
2. **检查现有实体**：设计前先检查实体是否已存在
3. **遵循命名规范**：类名 PascalCase，外键 `{Entity}ID` 格式
4. **合理使用特性**：通过特性控制代码生成行为
5. **文档注释**：所有实体和属性必须包含 XML 注释
6. **自动检测项目结构**：从现有代码推断命名空间和路径模式
7. **查询特性限制**：同一属性上只能有一个查询特性，不能同时使用 `[Equal]` 和 `[Contains]` 等多个查询特性
