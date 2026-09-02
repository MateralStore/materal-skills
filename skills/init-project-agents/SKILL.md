---
name: init-project-agents
description: Initialize a project directory by running git init when needed, creating a standard .gitignore, creating or reusing .agents and .agents/skills, creating a .claude symbolic link that points to .agents, and creating AGENTS.md plus CLAUDE.md project guidance files. Use when setting up any new project workspace, preparing a repository for local agent skills, generating project agent instructions, or migrating an existing .claude folder into .agents.
---

# Init Project Agents

## 概述

用于把一个项目目录初始化为可存放本地 agent 技能的结构：

1. 在目标目录下创建或复用 `.agents`。
2. 在 `.agents` 下创建或复用 `skills`。
3. 在目标目录下创建名为 `.claude` 的目录符号链接，链接目标为 `.agents`。
4. 在目标目录下创建或复用 `AGENTS.md` 和 `CLAUDE.md`。
5. 目标目录尚未初始化 Git 时执行 `git init`；已有 `.git` 时复用，不重置或覆盖现有仓库。
6. `.gitignore` 不存在时创建标准模板；已存在时保留原内容，不覆盖。

## 工作流程

1. 确认用户提供的目标目录；若未提供，使用当前工作目录作为目标目录。
2. 运行 `scripts/Initialize-ProjectAgents.ps1`，传入目标目录。
3. 目标目录尚未初始化 Git 时执行 `git init`；已有 `.git` 时复用，不重置或覆盖现有仓库。
4. `.gitignore` 不存在时创建标准模板；已存在时保留原内容，不覆盖。
5. `.agents` 已存在时不创建；若存在但不是目录，停止并报告冲突。
6. `.agents/skills` 已存在时不创建；若存在但不是目录，停止并报告冲突。
7. `AGENTS.md` 不存在时创建项目说明、项目目录结构、文档维护策略、工作树约定与注意事项；已存在时保留未受管理的自定义内容，并将这些受管理区块升级或补齐为最新版本。项目目录结构中的根目录名称、标题和说明必须根据实际项目动态生成，不得写死示例项目名。模板包含 `docs`、`Server`、`Client`、`Demo` 的目录结构，以及 `001-总体计划` 和 `NNN-业务主题`。注意事项必须要求新增或修改文件时保持 CRLF 行尾；若工具产生 LF 行尾，提交前需转换为 CRLF 并检查确认。文档只保留当前有效状态；需求分析和 UML 图保留可编辑源文件。若文档含有完整的 GitNexus 区块（`<!-- gitnexus:start -->` 至 `<!-- gitnexus:end -->`），更新后将该区块整体置于文件末尾。
8. `CLAUDE.md` 已存在时不覆盖；不存在时创建，内容只写 `AGENTS.md`。
9. 处理 `.claude`：
   - 不存在时，创建 `.claude -> .agents` 的目录符号链接。
   - 已经是目录符号链接且指向当前目录下的 `.agents` 时，跳过创建。
   - 是目录符号链接但目标不正确时，默认停止；用户明确允许重建时传入 `-Force`。
   - 是真实目录时，将其中内容复制到 `.agents`，删除原 `.claude` 目录，再创建 `.claude -> .agents`。
   - 是普通文件时，直接删除该文件，再创建 `.claude -> .agents`。
10. 汇报 Git 初始化、`.gitignore` 创建或复用，以及其他创建、复用、迁移或删除的路径。

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

1. `<project-dir>\.git` 存在，目标目录是 Git 仓库。
2. `<project-dir>\.gitignore` 存在。新建文件时内容与标准模板一致并使用 CRLF；已有文件时内容保持不变。
3. `<project-dir>\.agents` 存在且为目录。
4. `<project-dir>\.agents\skills` 存在且为目录。
5. `<project-dir>\.claude` 存在且为目录符号链接，目标为 `<project-dir>\.agents`。
6. 若原先存在真实 `.claude` 目录，其内容已经复制到 `.agents`。
7. `<project-dir>\AGENTS.md` 存在。标题为 `# <实际项目名> 项目`，项目目录结构的根节点也使用实际项目名；未指定 `-ProjectName` 时使用目标目录名。模板包含 `docs`、`Server`、`Client`、`Demo`，以及 `docs/plans`、`docs/需求分析`、`docs/uml` 的约定；包含 `001-总体计划` 和 `NNN-业务主题`。已有文件时升级或补齐项目目录结构、文档维护策略、工作树和注意事项，并保留其他自定义内容。存在完整 GitNexus 区块时，该区块位于文件末尾。
8. `<project-dir>\CLAUDE.md` 存在，内容只包含 `AGENTS.md`。
