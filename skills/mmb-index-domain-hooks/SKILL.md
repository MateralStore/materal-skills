---
name: mmb-index-domain-hooks
description: MMB (Materal.MergeBlock) 框架 IIndexDomain 位序实体扩展实现技能。用于实体实现 IIndexDomain 后，基于代码生成的 ExchangeIndexAsync 与 OnExchangeIndexBefore/OnExchangeIndexAfter 钩子，在不修改 MGC 文件的前提下实现位序交换前后业务逻辑。使用场景：(1) 需要在交换位序前做参数校验或上下文准备，(2) 需要在交换位序后做缓存刷新、日志记录、事件触发，(3) 需要处理 partial void 钩子的同步限制并设计异步包装方法。
---

# MMB IIndexDomain 位序扩展指南

## 概述

当实体实现 `IIndexDomain` 时，MMB 生成器会生成位序交换能力。扩展逻辑必须基于生成的扩展点实现，不得修改 `MGC` 目录。

## 先检索再实现

每次实现前先在模块中检索并确认实际生成签名，避免按记忆编码：

```bash
rg --files -g "*.Index.cs"
rg -n "ExchangeIndexAsync|OnExchangeIndexBefore|OnExchangeIndexAfter" <模块路径>
```

同时确认 `ExchangeIndexModel` 字段定义。若模块内没有该模型文件，直接查看官方源码：
- `https://github.com/MateralStore/Materal.MergeBlock/blob/main/Materal.MergeBlock.Abstractions/Models/ExchangeIndexModel.cs`

重点确认以下文件（路径模式）：
- `{Project}.{Module}.Application/MGC/Services/{Entity}ServiceImpl.Index.cs`
- `{Project}.{Module}.Abstractions/MGC/Services/I{Entity}Service.Index.cs`
- `{Project}.{Module}.Application/MGC/Controllers/{Entity}Controller.Index.cs`

## 执行步骤

1. 确认实体实现了 `IIndexDomain`。
2. 若刚改过实体，先运行 `/mmb-generator` 生成位序代码。
3. 打开 `MGC/Services/{Entity}ServiceImpl.Index.cs`，确认钩子方法签名。
4. 在非 MGC 文件实现 `partial` 钩子，默认放在 `{Project}.{Module}.Application/Services/{Entity}ServiceImpl.cs`。
5. 在钩子中仅放同步且快速的逻辑。
6. 运行构建并验证位序交换链路。

## 标准实现模板

```csharp
using ZhiTu.Main.Abstractions.DTO.Category;
using ZhiTu.Main.Abstractions.Services.Models.Category;

namespace ZhiTu.Main.Application.Services;

public partial class CategoryServiceImpl
{
    partial void OnExchangeIndexBefore(ExchangeIndexModel model)
    {
        if (model.SourceID == model.TargetID)
        {
            throw new ZhiTuException("不能与自身交换位序");
        }
    }

    partial void OnExchangeIndexAfter(ExchangeIndexModel model)
    {
        // 示例：记录日志、刷新内存状态、触发轻量同步事件
    }
}
```

## ExchangeIndexModel 关键字段

按当前 MMB 框架源码，`ExchangeIndexModel` 包含：
- `SourceID`：源实体 ID（必填）。
- `TargetID`：目标实体 ID（必填）。
- `Before`：是否插入到目标之前（默认 `false`）。

## ServiceImplHelper 位序逻辑契约

位序交换的底层行为以官方源码为准：
- `https://github.com/MateralStore/Materal.MergeBlock/blob/main/Materal.MergeBlock.Application.Abstractions/Services/ServiceImplHelper.cs`

在实现钩子或包装方法时，按以下契约推理：
- 入口：`ExchangeIndexByGroupPropertiesAsync(...)` 是标准位序交换入口。
- 前置校验：`SourceID == TargetID` 时直接失败；源和目标实体必须都存在。
- 同组约束：`groupProperties` 指定的每个分组属性必须一致，否则不允许交换位序。
- 交换范围：按 `minIndex~maxIndex` 与分组条件查询候选集，再执行 `domains.ExchangeIndex(model.SourceID, model.Before)`。
- 持久化：对候选集逐条 `RegisterEdit`，最后 `CommitAsync`。

## 钩子能力边界

`OnExchangeIndexBefore/After` 是 `partial void`：
- 可以：参数校验、轻量同步加工、同步日志。
- 不适合：`await` 异步 I/O、长耗时逻辑、复杂事务编排。

需要异步扩展时，新增包装方法并在其中编排：

```csharp
public async Task ExchangeIndexWithBizAsync(ExchangeIndexModel model)
{
    await ValidateBeforeExchangeAsync(model);
    await ExchangeIndexAsync(model);
    await RefreshCacheAfterExchangeAsync(model);
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
- 扩展代码不在 `MGC` 目录。
- `partial void` 签名完全匹配。
- 位序交换接口调用成功且前后逻辑按预期执行。
