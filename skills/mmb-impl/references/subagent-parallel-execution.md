# SubAgent 并行执行指南

## 概述

本指南详细说明如何在 `mmb-impl` 技能中并行启动多个 SubAgent 执行业务实现。

## 重要：控制器实现的条件执行

⚠️ **关键概念**：控制器实现（`/mmb-controller-impl`）**仅在控制器无法通过 `[MapperController]` 自动生成时**才需要执行。

### 控制器生成的两种方式

| 方式 | 使用场景 | 是否需要手动实现 |
|------|---------|-----------------|
| `[MapperController]` + `/mmb-generator` | 参数简单、返回类型标准、无特殊逻辑 | ❌ 否 |
| 手动设计 + `/mmb-controller-impl` | 需要特殊验证、文件处理、复杂参数等 | ✅ 是 |

### 判断逻辑

```mermaid
flowchart TD
    A[控制器设计<br/>mmb-controller-design] --> B{方法是否可通过<br/>[MapperController] 自动生成?}
    B -->|是| C[添加 [MapperController] 特性]
    B -->|否| D[手动设计控制器接口]
    C --> E[跳过实现阶段]
    D --> F[调用 /mmb-controller-impl]
    E --> G[等待 /mmb-generator<br/>自动生成]
    F --> H[手动实现控制器逻辑]

    style C fill:#90EE90
    style E fill:#87CEEB
    style D fill:#FFB6C1
    style F fill:#DDA0DD
    style G fill:#F0E68C
    style H fill:#FFA07A
```

## 启动 SubAgent 的方式

使用 Task 工具的 `run_in_background` 参数启动后台 SubAgent：

```csharp
Task(
    subagent_type: "general-purpose",
    description: "实现任务 T-Admin-01",
    prompt: "请为以下任务完成业务实现：...",
    run_in_background: true
)
```

## 并行执行模式

### 模式 1：完全并行（推荐）

适用于**任务之间无依赖关系**的场景。

```csharp
// 同时启动多个 SubAgent
Task("实现任务1", "...", subagent_type: "general-purpose", run_in_background: true);
Task("实现任务2", "...", subagent_type: "general-purpose", run_in_background: true);
Task("实现任务3", "...", subagent_type: "general-purpose", run_in_background: true);
```

### 模式 2：分层并行

适用于**任务之间有依赖关系**的场景。

```csharp
// 第一层：并行启动无依赖的任务
var task1 = Task("实现任务1", "...", subagent_type: "general-purpose", run_in_background: true);
var task2 = Task("实现任务2", "...", subagent_type: "general-purpose", run_in_background: true);

// 等待第一层完成
TaskOutput(task_id: task1.Result);
TaskOutput(task_id: task2.Result);

// 第二层：启动依赖任务
var task3 = Task("实现任务3（依赖任务1）", "...", subagent_type: "general-purpose", run_in_background: true);
```

## SubAgent Prompt 模板

### 基础模板

```markdown
请为以下任务完成业务实现：

**任务编号**：{TaskID}
**功能编号**：{FeatureID}
**任务描述**：{TaskDescription}
**所属模块**：{ModuleName}
**实体名称**：{EntityName}

**前置条件**：
- 需求分析文档：{ModuleName}/docs/RequirementsAnalysis/{DocName}.md
- 功能设计文档：{ModuleName}/docs/FeatureDesign/{DocName}.md
- 实体定义：{ModuleName}.{ModuleAbbr}.Abstractions/Domain/{EntityName}.cs
- 任务拆解文档：{ModuleName}/docs/Tasks/{TaskDocName}.md

**验收标准**：
{AcceptanceCriteria}

请按以下流程执行：
1. 读取功能设计文档中功能编号 {FeatureID} 的详细设计
2. 调用 `/mmb-service-design` 技能判断是否需要自定义服务接口，如需要则设计服务接口、服务模型、DTO 等
3. 调用 `/mmb-service-impl` 技能实现服务接口的业务逻辑
4. 调用 `/mmb-controller-design` 技能设计控制器接口
5. **条件执行**：检查控制器设计结果，如果显示需要手动实现控制器接口，则调用 `/mmb-controller-impl` 技能进行控制器实现；如果控制器可通过 `[MapperController]` 自动生成，则跳过此步骤

完成后请返回实现结果摘要，包括：
- 服务设计结果（服务接口、自定义方法）
- 服务实现结果（实现类、实现方法）
- 控制器设计结果（自动生成/手动设计、API 端点）
- 控制器实现结果（如需要手动实现）
```

### 高级模板（包含依赖信息）

```markdown
请为以下任务完成业务实现：

**任务编号**：{TaskID}
**功能编号**：{FeatureID}
**任务描述**：{TaskDescription}
**所属模块**：{ModuleName}
**实体名称**：{EntityName}

**任务依赖**：
- 依赖任务：{DependentTaskID}
- 依赖原因：{DependencyReason}

**前置条件**：
- 需求分析文档：{ModuleName}/docs/RequirementsAnalysis/{DocName}.md
- 功能设计文档：{ModuleName}/docs/FeatureDesign/{DocName}.md
- 实体定义：{ModuleName}.{ModuleAbbr}.Abstractions/Domain/{EntityName}.cs
- 任务拆解文档：{ModuleName}/docs/Tasks/{TaskDocName}.md

**特殊说明**：
{SpecialNotes}

**验收标准**：
{AcceptanceCriteria}

请按以下流程执行：
1. 读取功能设计文档中功能编号 {FeatureID} 的详细设计
2. 调用 `/mmb-service-design` 技能判断是否需要自定义服务接口，如需要则设计服务接口、服务模型、DTO 等
3. 调用 `/mmb-service-impl` 技能实现服务接口的业务逻辑
4. 调用 `/mmb-controller-design` 技能设计控制器接口
5. **条件执行**：检查控制器设计结果，如果显示需要手动实现控制器接口，则调用 `/mmb-controller-impl` 技能进行控制器实现；如果控制器可通过 `[MapperController]` 自动生成，则跳过此步骤

完成后请返回实现结果摘要，包括：
- 服务设计结果（服务接口、自定义方法）
- 服务实现结果（实现类、实现方法）
- 控制器设计结果（自动生成/手动设计、API 端点、是否需要手动实现）
- 控制器实现结果（如需要手动实现）
```

## 等待 SubAgent 完成

### 轮询检查

```csharp
while (true)
{
    var allCompleted = true;
    foreach (var taskId in taskIds)
    {
        var output = TaskOutput(task_id: taskId, block: false, timeout: 1000);
        if (output.Status != "completed")
        {
            allCompleted = false;
            break;
        }
    }
    if (allCompleted) break;
}
```

### 使用 TaskOutput 获取结果

```csharp
var output = TaskOutput(task_id: taskId, block: true, timeout: 300000);
// output.Result 包含 SubAgent 的输出结果
```

## 错误处理

### 单个 SubAgent 失败

```csharp
try
{
    var output = TaskOutput(task_id: taskId, block: true, timeout: 300000);
    if (output.Status == "failed")
    {
        // 记录错误，继续执行其他任务
        errors.Add(taskId, output.Error);
    }
}
catch (Exception ex)
{
    // 记录异常
    errors.Add(taskId, ex.Message);
}
```

### 失败重试

```csharp
int maxRetries = 2;
for (int i = 0; i < maxRetries; i++)
{
    var output = TaskOutput(task_id: taskId, block: true, timeout: 300000);
    if (output.Status == "completed")
    {
        break;
    }
    if (i < maxRetries - 1)
    {
        // 重新启动 SubAgent
        Task("重试任务", "...", subagent_type: "general-purpose", run_in_background: true);
    }
}
```

## 性能优化

### 并行数量控制

建议同时运行的 SubAgent 数量不超过 5 个，避免资源耗尽。

```csharp
int maxParallel = 5;
for (int i = 0; i < tasks.Count; i += maxParallel)
{
    var batch = tasks.Skip(i).Take(maxParallel);
    foreach (var task in batch)
    {
        Task(task.Description, task.Prompt, subagent_type: "general-purpose", run_in_background: true);
    }
    // 等待批次完成
    WaitForBatchCompletion();
}
```

## 示例

### 完整示例：管理员账号管理实现

```csharp
// 任务列表
var tasks = new[]
{
    new { TaskID = "T-Admin-01", FeatureID = "F-Admin-01", Description = "管理员登录" },
    new { TaskID = "T-Admin-02", FeatureID = "F-Admin-02", Description = "管理员列表查询" },
    new { TaskID = "T-Admin-03", FeatureID = "F-Admin-03", Description = "获取管理员详情" }
};

// 并行启动 SubAgent
var taskIds = new List<string>();
foreach (var task in tasks)
{
    var prompt = $@"
请为以下任务完成业务实现：

**任务编号**：{task.TaskID}
**功能编号**：{task.FeatureID}
**任务描述**：{task.Description}

请按流程执行服务设计、服务实现、控制器设计。
";
    var result = Task(
        subagent_type: "general-purpose",
        description: task.Description,
        prompt: prompt,
        run_in_background: true
    );
    taskIds.Add(result.Result);
}

// 等待所有 SubAgent 完成
var results = new List<string>();
foreach (var taskId in taskIds)
{
    var output = TaskOutput(task_id: taskId, block: true, timeout: 300000);
    results.Add(output.Result);
}

// 输出汇总
Console.WriteLine("所有任务已完成：" + string.Join(", ", tasks.Select(t => t.TaskID)));
Console.WriteLine("控制器实现情况：");
Console.WriteLine("- 自动生成（MapperController）：{count} 个");
Console.WriteLine("- 需要手动实现：{count} 个");
```
