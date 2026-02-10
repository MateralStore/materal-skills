---
name: mmb-single-file-first
description: MMB (Materal.MergeBlock) 项目单文件优先治理技能。用于修复或预防 LLM 生成 `UserController.Crud.cs`、`IUserService.Auth.cs` 这类碎片化命名文件，按“简单类写入主文件 `{Class}.cs`、复杂类再拆分”的规则整理控制器/服务/接口文件。适用于代码生成后清理、提交前自检、代码评审发现命名拆分不符合规范的场景。
---
# MMB 单文件优先技能

按以下步骤执行，优先基于仓库检索结果判断，不依赖猜测。

## 强制约束

1. 禁止修改任何 `MGC` 目录文件。
2. 默认使用单文件：简单类统一落在主文件 `{Class}.cs`。
3. 仅在类明显变大时保留拆分文件（如 `{Class}.Crud.cs`、`{Class}.Auth.cs`）。
4. 每次处理后都执行编译验证（至少模块级 `dotnet build`）。

## 判定规则

1. 先识别候选文件：非 `MGC` 且命名匹配 `{Class}.{Tag}.cs`。
2. 使用主文件优先规则：
- 若只有一个碎片文件且主文件不存在，直接改名为 `{Class}.cs`。
- 若存在主文件，且“总行数 <= 300、方法数 <= 8、拆分文件数 <= 3”，执行合并。
- 若超过阈值，保留拆分，并按职责命名（如 `Crud/Auth/Profile`）。
3. 在不确定时默认合并到主文件，除非你能给出“保持拆分更清晰”的具体理由。

详细阈值与边界见：`references/split-rules.md`。

## 执行流程

1. 扫描模块内非 `MGC` 碎片文件并分组到对应主类。
2. 按“判定规则”决定：改名、合并、或保留拆分。
3. 改名或合并后，清理重复 `using` 与空文件。
4. 输出处理结果：变更前后文件清单 + 每个类的判定依据。
5. 运行构建验证。

## 快速检查脚本

使用 `scripts/single_file_first.py` 先检查再修改：

```bash
python .agents/skills/mmb-single-file-first/scripts/single_file_first.py ZhiTu.Main
```

仅执行安全改名（不做自动合并）：

```bash
python .agents/skills/mmb-single-file-first/scripts/single_file_first.py ZhiTu.Main --apply
```

## 输出要求

1. 明确列出处理的文件路径。
2. 对每个类给出“为何合并/为何保留拆分”的一句话依据。
3. 明确说明是否触碰 `MGC`（答案必须是“否”）。

## 相关技能

1. `remove-duplicate-usings`：合并后清理冗余 using。
2. `mmb-controller-crud-impl`：在控制器标准 CRUD 介入时落地业务代码。
