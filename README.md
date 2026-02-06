# Materal MMB 技能集

![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue?style=flat-square)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)

这是一套为 [Materal.MergeBlock (MMB)](https://github.com/MateralStore) 框架开发的 Claude Code 技能集 - 一个多模块 .NET 后端框架。

## 概述

Materal.MergeBlock (MMB) 是一个用于构建 .NET 后端应用程序的模块化框架。该技能集提供了专门的工具来简化开发工作流程，从需求分析到实现和测试。

## 特性

- **全开发生命周期支持** - 从需求分析到实现
- **多模块架构** - 专为 MMB 的模块化项目结构设计
- **交互式工作流** - 在每个阶段提供逐步指导并需要用户确认
- **代码生成** - 自动生成实体、服务和控制器代码
- **中文语言支持** - 主要使用中文以提供更好的本地开发者体验

## 可用技能

### 需求与设计

| 技能 | 描述 |
|-------|-------------|
| `mmb-requirements-analysis` | 需求分析 - 逐个提问式交互收集完整需求信息 |
| `mmb-feature-design` | 功能设计 - 将需求拆分为多个功能模块 |
| `mmb-entity-design` | 实体设计 - 设计业务实体和属性 |
| `mmb-task-breakdown` | 任务拆解 - 将功能拆分为具体实现任务 |

### 实现

| 技能 | 描述 |
|-------|-------------|
| `mmb-generator` | 代码生成 - 基于设计生成实体、服务、控制器代码 |
| `mmb-impl` | 业务实现 - 实现具体业务逻辑 |
| `mmb-repository-impl` | 仓储实现 - 实现数据访问层 |
| `mmb-service-impl` | 服务实现 - 实现业务服务层 |
| `mmb-controller-design` | 控制器设计 - 设计API控制器结构 |
| `mmb-controller-impl` | 控制器实现 - 实现API控制器 |
| `mmb-jwt-auth` | JWT认证 - 添加JWT授权支持 |

### 工具

| 技能 | 描述 |
|-------|-------------|
| `mmb-build` | 构建验证 - 验证项目构建是否成功 |
| `mmb-fix` | 错误修复 - 自动修复构建错误 |
| `mmb-file-split` | 文件拆分 - 拆分大型文件 |
| `mmb-exception-handling` | 异常处理 - 统一异常处理 |
| `mmb-controller-return` | 控制器返回 - 统一返回格式 |

## 安装

### 方式一：使用 Marketplace（推荐）

```bash
# 将此仓库添加为市场
/plugin marketplace add https://github.com/MateralStore/materal-skills

# 或使用 CLI
claude plugin marketplace add https://github.com/MateralStore/materal-skills

# 安装技能（marketplace 名称：materal-skills）
/plugin install mmb-generator@materal-skills
/plugin install mmb-requirements-analysis@materal-skills
# ... 或安装其他技能

# 或使用 CLI
claude plugin install mmb-generator@materal-skills
```

### 方式二：手动安装

```bash
# 克隆仓库
git clone https://github.com/MateralStore/materal-skills.git
cd materal-skills

# 复制技能到 Claude 目录
cp -r skills/mmb-* ~/.claude/skills/
```

## 使用方法

### 基本工作流

MMB 开发流程遵循以下步骤：

```
用户提出需求
    ↓
/mmb-requirements-analysis  (需求分析)
    ↓ (用户确认)
/mmb-feature-design         (功能设计)
    ↓ (用户确认)
/mmb-entity-design          (实体设计)
    ↓
/mmb-generator              (生成代码)
    ↓
/mmb-task-breakdown         (任务拆解)
    ↓
/mmb-impl                   (业务实现)
    ↓
/mmb-build                  (构建验证)
    ↓ (失败则使用 /mmb-fix 修复)
完成
```

### 示例

```
我需要开发一个用户管理功能
```

Claude Code 将自动调用适当的技能并指导您完成开发过程。

## 项目结构

```
skills/
├── mmb-requirements-analysis/
├── mmb-feature-design/
├── mmb-entity-design/
├── mmb-task-breakdown/
├── mmb-generator/
├── mmb-impl/
├── mmb-build/
├── mmb-fix/
└── ...
```

## 开发

```bash
# 克隆仓库
git clone https://github.com/MateralStore/materal-skills.git
cd materal-skills

# 本地测试技能（复制到 Claude 技能目录）
cp -r skills/mmb-* ~/.claude/skills/
```

## 贡献

我们欢迎贡献！要添加新技能：

1. 阅读 [AGENTS.md](AGENTS.md) 文档了解结构指南
2. 在 `skills/` 中创建新的技能目录
3. 添加带有适当前置数据的 `SKILL.md` 文件
4. 如有需要在 `references/` 中添加参考文档
5. 使用 MMB 项目进行彻底测试
6. 提交 pull request

## 许可证

本项目在 MIT 许可证下授权 - 详情请参阅 [LICENSE](LICENSE) 文件。

## 支持

- [文档](https://github.com/MateralStore/materal-skills)
- [问题跟踪](https://github.com/MateralStore/materal-skills/issues)

## 相关项目

- [Materal.MergeBlock 框架](https://github.com/MateralStore)

## 致谢

为 Claude Code 生态系统构建，以加速 MMB 框架开发。
