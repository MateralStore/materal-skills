---
name: init-project-agents
description: Initialize a project directory for agent-local skills by creating .agents, creating .agents/skills, and creating a .calude directory symbolic link that points to .agents. Use when setting up any new project workspace, preparing a repository for local agent skills, or when the user asks to initialize project agent folders/skills/link structure.
---

# Init Project Agents

## 概述

用于把一个项目目录初始化为可存放本地 agent 技能的结构：

1. 在目标目录下创建 `.agents`。
2. 在 `.agents` 下创建 `skills`。
3. 在目标目录下创建名为 `.calude` 的目录符号链接，链接目标为 `.agents`。

注意：链接名按用户约定写作 `.calude`，不要自动改成 `.claude`。

## 工作流程

1. 确认用户提供的目标目录；若未提供，使用当前工作目录作为目标目录。
2. 运行 `scripts/Initialize-ProjectAgents.ps1`，传入目标目录。
3. 若 `.calude` 已存在：
   - 已经是指向 `.agents` 的符号链接时，视为已完成。
   - 是其他符号链接时，只有用户明确允许重建时才传入 `-Force`。
   - 是真实文件或真实目录时，不要覆盖，报告冲突并等待用户处理。
4. 汇报创建或复用的路径。

## 脚本用法

```powershell
& "<skill-dir>\scripts\Initialize-ProjectAgents.ps1" -TargetDirectory "<project-dir>"
```

允许重建已有但目标错误的 `.calude` 符号链接：

```powershell
& "<skill-dir>\scripts\Initialize-ProjectAgents.ps1" -TargetDirectory "<project-dir>" -Force
```

脚本内部使用 PowerShell 的目录符号链接命令：

```powershell
New-Item -ItemType SymbolicLink -Path "<project-dir>\.calude" -Value "<project-dir>\.agents"
```

## 验证

执行后检查：

1. `<project-dir>\.agents` 存在且为目录。
2. `<project-dir>\.agents\skills` 存在且为目录。
3. `<project-dir>\.calude` 存在且为目录符号链接，目标为 `<project-dir>\.agents`。
