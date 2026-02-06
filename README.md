# Materal MMB Skills

![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-blue?style=flat-square)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)

A collection of Claude Code skills for the [Materal.MergeBlock (MMB)](https://github.com/MateralStore) framework - a multi-module .NET backend framework.

## Overview

Materal.MergeBlock (MMB) is a modular framework for building .NET backend applications. This skill collection provides specialized tools to streamline the development workflow, from requirements analysis to implementation and testing.

## Features

- **Full Development Lifecycle Support** - From requirements analysis to implementation
- **Multi-Module Architecture** - Designed for MMB's modular project structure
- **Interactive Workflow** - Step-by-step guidance with user confirmation at each stage
- **Code Generation** - Automated code generation for entities, services, and controllers
- **Chinese Language Support** - Primary language is Chinese for better local developer experience

## Available Skills

### Requirements & Design

| Skill | Description |
|-------|-------------|
| `mmb-requirements-analysis` | 需求分析 - 逐个提问式交互收集完整需求信息 |
| `mmb-feature-design` | 功能设计 - 将需求拆分为多个功能模块 |
| `mmb-entity-design` | 实体设计 - 设计业务实体和属性 |
| `mmb-task-breakdown` | 任务拆解 - 将功能拆分为具体实现任务 |

### Implementation

| Skill | Description |
|-------|-------------|
| `mmb-generator` | 代码生成 - 基于设计生成实体、服务、控制器代码 |
| `mmb-impl` | 业务实现 - 实现具体业务逻辑 |
| `mmb-repository-impl` | 仓储实现 - 实现数据访问层 |
| `mmb-service-impl` | 服务实现 - 实现业务服务层 |
| `mmb-controller-design` | 控制器设计 - 设计API控制器结构 |
| `mmb-controller-impl` | 控制器实现 - 实现API控制器 |
| `mmb-jwt-auth` | JWT认证 - 添加JWT授权支持 |

### Utilities

| Skill | Description |
|-------|-------------|
| `mmb-build` | 构建验证 - 验证项目构建是否成功 |
| `mmb-fix` | 错误修复 - 自动修复构建错误 |
| `mmb-file-split` | 文件拆分 - 拆分大型文件 |
| `mmb-exception-handling` | 异常处理 - 统一异常处理 |
| `mmb-controller-return` | 控制器返回 - 统一返回格式 |

## Installation

```bash
# Add this repository as a marketplace
/plugin marketplace add https://github.com/MateralStore/materal-skills

# Install the plugin
/plugin install materal-skills@materal-skills
```

## Usage

### Basic Workflow

The MMB development process follows these steps:

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

### Example

```
我需要开发一个用户管理功能
```

Claude Code will automatically invoke the appropriate skills and guide you through the development process.

## Project Structure

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

## Development

```bash
# Clone repository
git clone https://github.com/MateralStore/materal-skills.git
cd materal-skills

# Test a skill locally (copy to Claude skills directory)
cp -r skills/mmb-* ~/.claude/skills/
```

## Contributing

We welcome contributions! To add a new skill:

1. Read the [AGENTS.md](AGENTS.md) documentation for structure guidelines
2. Create a new skill directory in `skills/`
3. Add a `SKILL.md` file with proper frontmatter
4. Add reference documentation in `references/` if needed
5. Test thoroughly with MMB projects
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- [Documentation](https://github.com/MateralStore/materal-skills)
- [Issue Tracker](https://github.com/MateralStore/materal-skills/issues)

## Related Projects

- [Materal.MergeBlock Framework](https://github.com/MateralStore)

## Acknowledgments

Built for the Claude Code ecosystem to accelerate MMB framework development.
