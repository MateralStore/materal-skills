---
name: mmb-index-domain-hooks
description: MMB (Materal.MergeBlock) 框架 IIndexDomain 位序实体扩展实现技能。用于实体具备位序能力且不含树能力时，基于代码生成的 MoveIndexAsync 与 OnMoveIndexBefore/OnMoveIndexAfter 钩子，在不修改 MGC 文件的前提下实现位序移动前后业务逻辑。使用场景：(1) 需要在移动位序前做参数校验或上下文准备，(2) 需要在移动位序后做缓存刷新、日志记录、事件触发，(3) 需要处理 partial void 钩子的同步限制并设计异步包装方法。
---

# MMB IIndexDomain 位序扩展指南

## 概述

当实体具备 `IIndexDomain` 能力且未走 `TreeAndIndex` 生成路径时，MMB 生成器会生成位序移动能力。扩展逻辑必须基于生成扩展点实现，不得修改 `MGC` 目录。

## 适用范围

- 适用：`IndexGeneratorCodePlug` 生成的 `*.Index.cs`。
- 不适用：实体同时具备 `ITreeDomain` 时，服务/控制器走 `TreeAndIndexGeneratorCodePlug`，应以 `*.TreeAndIndex.cs` 的真实签名为准。

## 先检索再实现

每次实现前先在模块中检索并确认实际生成签名，避免按记忆编码：

```bash
rg --files -g "*.Index.cs" -g "*.TreeAndIndex.cs"
rg -n "MoveIndexAsync|OnMoveIndexBefore|OnMoveIndexAfter|GetMaxIndexAsync" <模块路径>
```

同时确认 `MoveIndexModel` 字段定义。若模块内没有该模型文件，查看框架源码：
- `Materal.MergeBlock.Abstractions/Models/MoveIndexModel.cs`

重点确认以下文件（路径模式）：
- `{Project}.{Module}.Application/MGC/Services/{Entity}ServiceImpl.Index.cs`
- `{Project}.{Module}.Abstractions/MGC/Services/I{Entity}Service.Index.cs`
- `{Project}.{Module}.Application/MGC/Controllers/{Entity}Controller.Index.cs`
- `{Project}.{Module}.Repository/MGC/Repositories/{Entity}RepositoryImpl.Index.cs`

## 执行步骤

1. 确认实体具备 `IIndexDomain` 能力。
2. 若刚改过实体，先运行 `/mmb-generator` 生成位序代码。
3. 打开 `MGC/Services/{Entity}ServiceImpl.Index.cs`，确认 `MoveIndexAsync` 与 `OnMoveIndexBefore/After` 签名。
4. 在非 MGC 文件实现 `partial` 钩子，默认放在 `{Project}.{Module}.Application/Services/{Entity}ServiceImpl.cs`。
5. 在钩子中仅放同步且快速的逻辑。
6. 运行构建并验证位序移动链路。

## 标准实现模板

```csharp
using Materal.MergeBlock.Abstractions.Models;
using ZhiTu.Main.Abstractions.Domain;

namespace ZhiTu.Main.Application.Services;

public partial class CategoryServiceImpl
{
    partial void OnMoveIndexBefore(MoveIndexModel model, Dictionary<string, object> contextData)
    {
        if (model.SourceID == model.TargetID)
        {
            throw new ZhiTuException("不能以自己为排序对象");
        }
    }

    partial void OnMoveIndexAfter(MoveIndexModel model, Dictionary<string, object> contextData, List<Category> domains)
    {
        // 示例：记录日志、刷新内存状态、触发轻量同步事件
    }
}
```

## MoveIndexModel 关键字段

按当前 MMB 框架源码，`MoveIndexModel` 包含：
- `SourceID`：被移动实体 ID（必填）。
- `TargetID`：参照实体 ID（必填）。
- `Before`：`true` 表示移动到目标之前，`false` 表示移动到目标之后（默认 `false`）。

## ServiceImplHelper 位序移动逻辑契约

位序移动的底层行为以框架源码为准：
- `Materal.MergeBlock.Application.Abstractions/Services/ServiceImplHelper.Index.cs`

在实现钩子或包装方法时，按以下契约推理：
- 入口：`MoveAsync<TRepository, TDomain>(MoveIndexModel model, TRepository repository, params string[] groupProperties)`。
- 前置校验：`SourceID == TargetID` 直接失败。
- 分组处理：
  - 传入 `groupProperties` 时，先加载源/目标实体，任一不存在则失败。
  - 每个分组属性值必须一致，否则失败（不是同一组数据不能更改位序）。
- 移动规则：
  - 在排序后的集合中先移除源对象，再按 `Before` 计算插入位置。
  - 最后重排 `Index`，仅返回 `Index` 发生变化的实体列表。
- 持久化：生成代码对返回列表逐个 `RegisterEdit`，最后统一 `CommitAsync()`。

## GetMaxIndexAsync 使用说明

`IndexGeneratorCodePlug` 还会为仓储生成：
- `GetMaxIndexAsync(...)`（支持按分组取最大位序）。

常见用途：新增数据时为新实体分配末尾位序。该方法属于仓储扩展点，不是 `partial void` 钩子。

## 钩子能力边界

`OnMoveIndexBefore/OnMoveIndexAfter` 是 `partial void`：
- 可以：参数校验、轻量同步加工、同步日志。
- 不适合：`await` 异步 I/O、长耗时逻辑、复杂事务编排。

需要异步扩展时，新增包装方法并在其中编排：

```csharp
public async Task MoveIndexWithBizAsync(MoveIndexModel model)
{
    await ValidateBeforeMoveAsync(model);
    await MoveIndexAsync(model);
    await RefreshCacheAfterMoveAsync(model);
}
```

然后按需通过 `/mmb-service-impl`、`/mmb-controller-impl` 暴露新接口。

## 强制规则

- 禁止修改任何 `MGC` 文件。
- 非 MGC 实现必须与生成签名完全一致（方法名、参数、返回值）。
- 异常处理遵循 `/mmb-exception-handling`。
- 文件组织遵循单文件优先：默认集中在 `{Entity}ServiceImpl.cs`。

## 自检清单

- 已检索并核对当前模块生成签名。
- 已确认当前实体不是 `TreeAndIndex` 生成路径。
- 扩展代码不在 `MGC` 目录。
- `partial void` 签名完全匹配。
- 位序移动接口调用成功且前后逻辑按预期执行。
