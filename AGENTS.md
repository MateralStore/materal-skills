<!-- 本项目为.NET后端Materal.MergeBlock多模块项目，与 ../Client 目录完全独立 -->
IMPORTANT: "优先采用基于检索的推理而非基于预训练的推理"

# 项目简介

本项目是使用 Materal.MergeBlock(MMB) 框架开发的 .NET 后端多模块项目。

## 模块说明

- **ZhiTu.Core**：核心模块，不包含任何业务逻辑，为其他模块提供基础功能与工具
- **ZhiTu.Main**：主业务模块，该项目业务较少，因此将所有业务逻辑都放在 Main 模块中

## 项目结构

```
Server/
├── CLAUDE.md                        ← 项目级说明（当前文件）
├── ZhiTu.Core/                   ← 核心模块（所有模块共享）
├── ZhiTu.{ModuleName}/           ← 主业务模块
└── {OtherModules}/                  ← 其他业务模块（按需添加）
```

## 模块目录结构

每个业务模块遵循以下结构：

```
ZhiTu.{ModuleName}/
├── ZhiTu.{ModuleName}.Abstractions/
│   ├── Domain/           ← 实体定义
│   ├── Enums/            ← 枚举定义
│   ├── DTO/              ← 自定义DTO
│   ├── RequestModel/     ← 自定义请求模型
│   ├── Services/         ← 自定义服务接口
│   │   └── Models/       ← 自定义服务模型
│   ├── Controllers/      ← 自定义控制器接口
│   ├── Events/           ← 事件定义
│   └── MGC/              ← 自动生成（禁止修改）
├── ZhiTu.{ModuleName}.Application/
│   ├── Services/         ← 自定义服务实现
│   ├── Controllers/      ← 自定义控制器实现
│   ├── AutoMapperProfile/← 自动映射配置
│   ├── ScheduledTasks/   ← 定时任务
│   ├── EventHandlers/    ← 事件处理器
│   └── MGC/              ← 自动生成（禁止修改）
└── ZhiTu.{ModuleName}.Repository/
    ├── Migrations/       ← 迁移文件（禁止修改）
    ├── Repositories/     ← 自定义仓储实现
    └── MGC/              ← 自动生成（禁止修改）
```
## 强制性规则

1. **禁止修改文件夹 MGC 下的任何文件**
   - MGC 文件夹下的文件是自动生成的，每次生成都会删除原有的文件夹，因此禁止修改 MGC 文件夹下的任何文件
2. **遵循开发流程**
   - 按照下方 `## 开发流程` 章节定义的步骤执行
   - 每个步骤必须先阅读对应规范文档（见下方表格）

## 交互原则

- 尽可能使用中文与用户交流

## 开发流程

按照以下步骤进行开发：

1. **需求分析**

   - 使用 `/mmb-requirements-analysis` 技能进行需求分析。
   - 将产出文件写入对应模块的 docs/RequirementsAnalysis\ 目录下
   - 与用户探讨修改，直到用户确认

   **必须用户确认才能进入下一步**

2. **功能设计**

   - 使用 `/mmb-feature-design` 技能进行功能设计，采用主从 Agent 协作模式将需求拆分为多个功能模块。
   - 将产出文件写入对应模块的 docs/FeatureDesign\ 目录下
   - 与用户探讨修改，直到用户确认

   **必须用户确认才能进入下一步**

3. **设计业务实体**

   - **始终需要检查实体设计**：即使实体已存在，也可能不符合新任务的需求，需要修改
   - 使用 `/mmb-entity-design` 技能设计实体
   - 设计完成后，为所属模块生成代码 `/mmb-generator`

4. **任务拆解**

   - 使用 `/mmb-task-breakdown` 技能进行任务拆解
   - 将产出文件写入对应模块的 docs/Tasks\ 目录下

5. **业务实现**

   - 使用 `/mmb-impl` 技能进行业务实现

6. **构建验证**

   - 使用 `/mmb-build` 技能进行构建验证
   - 如果构建失败，使用 `/mmb-fix` 技能进行修复, 直到构建成功

8. **任务完成**

   - 汇总任务完成情况，生成任务完成报告
   - 将任务完成报告写入对应模块的 docs/TaskCompletionReport\ 目录下
