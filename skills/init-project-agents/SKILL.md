---
name: init-project-agents
description: Initialize a project directory for agent-local skills by creating or reusing .agents and .agents/skills, creating a .claude symbolic link that points to .agents, and creating AGENTS.md plus CLAUDE.md project guidance files. Use when setting up any new project workspace, preparing a repository for local agent skills, generating project agent instructions, or migrating an existing .claude folder into .agents.
---

# Init Project Agents

## 概述

用于把一个项目目录初始化为可存放本地 agent 技能的结构：

1. 在目标目录下创建或复用 `.agents`。
2. 在 `.agents` 下创建或复用 `skills`。
3. 在目标目录下创建名为 `.claude` 的目录符号链接，链接目标为 `.agents`。
4. 在目标目录下创建或复用 `AGENTS.md` 和 `CLAUDE.md`。

## 工作流程

1. 确认用户提供的目标目录；若未提供，使用当前工作目录作为目标目录。
2. 运行 `scripts/Initialize-ProjectAgents.ps1`，传入目标目录。
3. `.agents` 已存在时不创建；若存在但不是目录，停止并报告冲突。
4. `.agents/skills` 已存在时不创建；若存在但不是目录，停止并报告冲突。
5. `AGENTS.md` 不存在时创建项目说明、按业务主题组织的计划文档目录规范、文档维护策略、工作树约定与注意事项；已存在时保留原内容，并检查是否包含这些必需章节，缺失时追加补齐。注意事项必须要求新增或修改文件时保持 CRLF 行尾；若工具产生 LF 行尾，提交前需转换为 CRLF 并检查确认。计划目录编号只用于排序，不表示开发阶段、迭代批次或历史顺序；每份计划文档只保留最终有效的当前状态，不保留历史记录。若文档含有完整的 GitNexus 区块（`<!-- gitnexus:start -->` 至 `<!-- gitnexus:end -->`），更新后将该区块整体置于文件末尾。文档维护策略要求计划文档只反映当前或已批准计划的最终状态，优先更新既有文档，且仅在用户明确要求且范围确实独立时新建计划目录。工作树约定要求代理手工创建工作树时默认使用仓库根目录的 `.worktrees/<工作树名称>`，并忽略 `.worktrees/`；它不试图修改 Codex App 自动创建工作树的宿主路径。
6. `CLAUDE.md` 已存在时不覆盖；不存在时创建，内容只写 `AGENTS.md`。
7. 处理 `.claude`：
   - 不存在时，创建 `.claude -> .agents` 的目录符号链接。
   - 已经是目录符号链接且指向当前目录下的 `.agents` 时，跳过创建。
   - 是目录符号链接但目标不正确时，默认停止；用户明确允许重建时传入 `-Force`。
   - 是真实目录时，将其中内容复制到 `.agents`，删除原 `.claude` 目录，再创建 `.claude -> .agents`。
   - 是普通文件时，直接删除该文件，再创建 `.claude -> .agents`。
8. 汇报创建、复用、迁移或删除的路径。

## 脚本用法

```powershell
& "<skill-dir>\scripts\Initialize-ProjectAgents.ps1" -TargetDirectory "<project-dir>"
```

指定项目名与项目说明：

```powershell
& "<skill-dir>\scripts\Initialize-ProjectAgents.ps1" -TargetDirectory "<project-dir>" -ProjectName "<项目名字>" -ProjectDescription "<项目说明>"
```

不传 `-ProjectName` 时，默认使用目标目录名；不传 `-ProjectDescription` 时，默认使用 `暂无项目说明`。

允许重建已有但目标错误的 `.claude` 符号链接：

```powershell
& "<skill-dir>\scripts\Initialize-ProjectAgents.ps1" -TargetDirectory "<project-dir>" -Force
```

脚本内部使用 PowerShell 的目录符号链接命令：

```powershell
New-Item -ItemType SymbolicLink -Path "<project-dir>\.claude" -Value "<project-dir>\.agents"
```

## 验证

执行后检查：

1. `<project-dir>\.agents` 存在且为目录。
2. `<project-dir>\.agents\skills` 存在且为目录。
3. `<project-dir>\.claude` 存在且为目录符号链接，目标为 `<project-dir>\.agents`。
4. 若原先存在真实 `.claude` 目录，其内容已经复制到 `.agents`。
5. `<project-dir>\AGENTS.md` 存在。新建文件时包含项目名、项目说明、`docs\plans\` 按业务主题组织的目录规范、文档维护策略、工作树约定、要求新增或修改文件使用 CRLF 行尾并在提交前转换和检查 LF 行尾的约束、中文提交约束、通用提交示例和创建分支确认约束；目录编号仅用于排序，文档只保留最终有效的当前状态。已有文件时至少补齐文档目录规范、文档维护策略、工作树约定和注意事项。存在完整 GitNexus 区块时，该区块位于文件末尾。
6. `<project-dir>\CLAUDE.md` 存在，内容只包含 `AGENTS.md`。
