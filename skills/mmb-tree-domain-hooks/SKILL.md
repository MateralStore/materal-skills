---
name: mmb-tree-domain-hooks
description: MMB (Materal.MergeBlock) 框架树形实体扩展实现技能。用于实体具备树结构能力后，基于代码生成的 ExchangeParentAsync、GetTreeListAsync 及 OnExchangeParentBefore/OnExchangeParentAfter/OnToTreeBefore/OnConvertToTreeDTO/OnToTreeAfter 钩子，在不修改 MGC 文件的前提下实现父级变更和树列表转换扩展。使用场景：(1) 需要在更改父级前后做校验与业务补偿，(2) 需要在树DTO转换前后注入上下文或加工字段，(3) 需要处理 partial void 同步限制并设计异步包装方法。
---

# MMB Tree 结构扩展指南

## 概述

当实体具备树结构能力时，MMB 生成器会生成父级变更和树查询能力。扩展逻辑必须基于生成扩展点实现，禁止修改 `MGC` 目录。

## 先检索再实现

每次实现前先检索模块中的真实生成签名：

```bash
rg --files -g "*.Tree.cs"
rg -n "ExchangeParentAsync|GetTreeListAsync|OnExchangeParentBefore|OnExchangeParentAfter|OnToTreeBefore|OnConvertToTreeDTO|OnToTreeAfter" <模块路径>
```

重点确认以下文件（路径模式）：
- `{Project}.{Module}.Application/MGC/Services/{Entity}ServiceImpl.Tree.cs`
- `{Project}.{Module}.Abstractions/MGC/Services/I{Entity}Service.Tree.cs`
- `{Project}.{Module}.Application/MGC/Controllers/{Entity}Controller.Tree.cs`

## 执行步骤

1. 若刚改过实体或特性，先运行 `/mmb-generator`。
2. 打开 `MGC/Services/{Entity}ServiceImpl.Tree.cs`，确认钩子签名。
3. 在非 MGC 文件实现 `partial` 钩子，默认放在 `{Project}.{Module}.Application/Services/{Entity}ServiceImpl.cs`。
4. 钩子内只放同步、轻量、可快速失败的逻辑。
5. 构建并验证“更改父级 + 树查询”链路。

## 标准实现模板

```csharp
using ZhiTu.Main.Abstractions.DTO.Category;
using ZhiTu.Main.Abstractions.Services.Models.Category;

namespace ZhiTu.Main.Application.Services;

public partial class CategoryServiceImpl
{
    partial void OnExchangeParentBefore(ExchangeParentModel model)
    {
        if (model.SourceID == model.TargetID)
        {
            throw new ZhiTuException("不能以自己为父级");
        }
    }

    partial void OnExchangeParentAfter(ExchangeParentModel model)
    {
        // 示例：记录日志、刷新轻量缓存
    }

    partial void OnToTreeBefore(List<Category> allInfo, QueryCategoryTreeListModel queryModel, Dictionary<string, object> contextData)
    {
        contextData["total"] = allInfo.Count;
    }

    partial void OnConvertToTreeDTO(CategoryTreeListDTO dto, Category domain, QueryCategoryTreeListModel queryModel, Dictionary<string, object> contextData)
    {
        // 示例：按业务补充 dto 字段
    }

    partial void OnToTreeAfter(List<CategoryTreeListDTO> dtos, QueryCategoryTreeListModel queryModel, Dictionary<string, object> contextData)
    {
        // 示例：树转换完成后的同步处理
    }
}
```

## ExchangeParentModel 关键字段

按当前 MMB 官方源码，`ExchangeParentModel` 包含：
- `SourceID`：源实体 ID（必填）。
- `TargetID`：目标父级 ID（可空；空表示移到根级）。

参考：
- `https://github.com/MateralStore/Materal.MergeBlock/blob/main/Materal.MergeBlock.Abstractions/Models/ExchangeParentModel.cs`

## ServiceImplHelper 树形逻辑契约

底层行为以官方源码为准：
- `https://github.com/MateralStore/Materal.MergeBlock/blob/main/Materal.MergeBlock.Application.Abstractions/Services/ServiceImplHelper.cs`

在实现扩展时，按以下契约推理：
- 入口：`ExchangeParentByGroupPropertiesAsync(...)` 是标准更改父级入口。
- 前置校验：`SourceID == TargetID` 直接失败。
- 空目标：`TargetID` 为空或空 Guid 时，源节点提升到根级（`ParentID = null`）。
- 分组约束：提供 `groupProperties` 时，源/目标分组属性值必须一致。
- 循环检测：若目标父级形成环（例如目标是源的子链回指），操作失败。
- 持久化：注册变更后 `CommitAsync()`。

## GetTreeListAsync 生成逻辑契约

以生成的 `ServiceImpl.Tree.cs` 为准：
- 排序优先级：
  - 请求显式排序字段合法时，按请求排序。
  - 否则若实体实现 `IIndexDomain`，默认按 `Index` 升序。
  - 否则按 `CreateTime` 降序。
- 数据来源：
  - 仓储支持缓存时，先取全量缓存后用 `queryModel` 委托筛选和排序。
  - 否则走仓储查询。
- 树转换流程：
  - `OnToTreeBefore(...)` -> `ToTree(...)`（节点映射时触发 `OnConvertToTreeDTO(...)`）-> `OnToTreeAfter(...)`。

## 钩子能力边界

`OnExchangeParentBefore/After`、`OnToTreeBefore/After`、`OnConvertToTreeDTO` 都是 `partial void`：
- 可以：同步校验、同步加工、轻量上下文注入。
- 不适合：`await` 异步 I/O、长耗时逻辑、复杂事务编排。

需要异步扩展时，新增包装方法：

```csharp
public async Task<List<CategoryTreeListDTO>> GetTreeListWithBizAsync(QueryCategoryTreeListModel model)
{
    await ValidateTreeQueryAsync(model);
    List<CategoryTreeListDTO> result = await GetTreeListAsync(model);
    await EnrichTreeAsync(result);
    return result;
}
```

## 强制规则

- 禁止修改任何 `MGC` 文件。
- 非 MGC 实现必须与生成签名完全一致。
- 异常处理遵循 `/mmb-exception-handling`。
- 文件组织遵循单文件优先：默认集中在 `{Entity}ServiceImpl.cs`。

## 自检清单

- 已检索并核对 `.Tree.cs` 真实签名。
- 扩展代码不在 `MGC` 目录。
- 所有 `partial void` 签名完全匹配。
- 更改父级、查询树列表两个链路都已验证通过。
