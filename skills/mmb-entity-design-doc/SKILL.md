---
name: mmb-entity-design-doc
description: 从功能设计文档生成符合 MMB (Materal.MergeBlock) 框架规范的实体设计文档。使用场景：(1) 根据 FunctionalDesign.md 生成 EntityDesign.md，(2) 设计新的实体类时参考文档格式，(3) 确保实体设计符合 MMB 框架规范。读取 [MMB 框架规范](references/mmb-framework.md) 了解框架接口定义，参考 [文档模板](assets/EntityDesign.template.md) 查看标准格式。
---

# MMB 实体设计文档生成器

## 工作流程

### 1. 读取功能设计文档

首先读取项目的功能设计文档（通常位于 `docs/FunctionalDesign.md`），分析：
- API 功能模块
- 数据存储需求
- 业务实体关系

### 2. 识别实体和关系

根据功能设计，识别：
- 业务实体（如用户、分类、流程图等）
- 实体间关系（一对一、一对多、多对多）
- 特殊需求（树形结构、有序、复合主键等）

### 3. 应用 MMB 框架规范

**必须遵循的规则**：
- 所有实体继承 `BaseDomain`，获得 `ID`、`CreateTime`、`UpdateTime` 字段
- 有序实体实现 `IIndexDomain`，获得 `Index` 字段
- 树形实体实现 `ITreeDomain`，获得 `ParentID` 字段
- 字段命名：`ID`（全大写）而非 `Id`
- 不允许有例外情况

详见 [MMB 框架规范](references/mmb-framework.md)

### 4. 生成实体设计文档

按照 [文档模板](assets/EntityDesign.template.md) 的结构生成文档：

**文档结构**：
1. 基础字段 - 说明 MMB 框架提供的基类和接口
2. 实体定义 - 每个实体的字段和约束
3. 实体关系图 - Mermaid ER Diagram 格式

**实体定义格式**：
- 实现框架接口时，使用引用块标注：`> 实现 IIndexDomain 和 ITreeDomain 接口`
- 框架提供的字段（ID、CreateTime、UpdateTime、Index、ParentID）不需要在表格中列出
- 只列出业务字段

### 5. 生成 Mermaid ER 图

使用 `erDiagram` 格式，仅展示实体间关系：
- 定义实体间关系：`||--o{`（一对多）、`||--||`（一对一）
- 关系说明使用简洁的中文名称
- 不列举字段（字段已在上方实体定义中详细说明）

## 注意事项

1. **字段类型一致性**：C# 类型名使用规范（Guid、string、int、DateTime、long 等）
2. **约束说明**：MaxLength、Required、FK 关系等需清晰标注
3. **枚举定义**：枚举类型需单独定义，使用 C# 代码格式
4. **复杂字段**：JSON 序列化字段需说明其结构
5. **特殊说明**：需要补充的信息使用"特殊说明"部分，如索引说明、数据结构说明等
6. **文档边界**：实体设计文档专注于实体结构和字段定义，不包含级联删除规则等业务逻辑，这些内容应在功能设计文档中体现
