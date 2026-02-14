---
name: mmb-tree-and-index-domain-hooks
description: MMB (Materal.MergeBlock) 框架树形+位序实体扩展实现技能。用于实体同时具备 ITreeDomain 与 IIndexDomain 能力时，基于代码生成的 GetTreeListAsync、MoveTreeNodeAsync 以及 OnConvertTreeDTOInit/OnConvertTreeDTOBefore/OnConvertTreeDTO/OnConvertTreeDTOAfter、OnMoveTreeAndIndexBefore/OnMoveTreeAndIndexAfter 钩子，在不修改 MGC 文件的前提下实现树列表转换与树节点移动+位序重排扩展。使用场景：(1) 需要在树DTO转换前后注入上下文或加工字段，(2) 需要在移动节点和重排位序前后做校验与业务补偿，(3) 需要处理 partial void 同步限制并设计异步包装方法。
---

# MMB TreeAndIndex 结构扩展指南

## 概述

当实体同时具备 `ITreeDomain` 与 `IIndexDomain` 能力时，MMB 生成器会生成 `TreeAndIndex` 服务与控制器能力。扩展逻辑必须基于生成扩展点实现，禁止修改 `MGC` 目录。

## 适用范围

- 适用：`TreeAndIndexGeneratorCodePlug` 生成的 `*.TreeAndIndex.cs`。
- 典型前置：实体同时开启树能力与位序能力，且未关闭 Tree/Index 的 Service 与 Controller 生成。
- 不适用：仅树或仅位序实体；这两类分别使用 `/mmb-tree-domain-hooks`、`/mmb-index-domain-hooks`。

## 先检索再实现

每次实现前先检索模块中的真实生成签名：

```bash
rg --files -g "*.TreeAndIndex.cs" -g "*.Tree.cs" -g "*.Index.cs"
rg -n "GetTreeListAsync\(Guid\? parentID\)|MoveTreeNodeAsync\(MoveTreeNodeAndIndexModel model\)|OnConvertTreeDTOInit|OnConvertTreeDTOBefore|OnConvertTreeDTO\(|OnConvertTreeDTOAfter|OnMoveTreeAndIndexBefore|OnMoveTreeAndIndexAfter|GetAllRecursiveChildren|GetMaxIndexAsync" <模块路径>
```

重点确认以下文件（路径模式）：
- `{Project}.{Module}.Application/MGC/Services/{Entity}ServiceImpl.TreeAndIndex.cs`
- `{Project}.{Module}.Abstractions/MGC/Services/I{Entity}Service.TreeAndIndex.cs`
- `{Project}.{Module}.Application/MGC/Controllers/{Entity}Controller.TreeAndIndex.cs`
- `{Project}.{Module}.Repository/MGC/Repositories/{Entity}RepositoryImpl.Tree.cs`
- `{Project}.{Module}.Repository/MGC/Repositories/{Entity}RepositoryImpl.Index.cs`

## 执行步骤

1. 若刚改过实体或特性，先运行 `/mmb-generator`。
2. 打开 `MGC/Services/{Entity}ServiceImpl.TreeAndIndex.cs`，确认 `GetTreeListAsync`、`MoveTreeNodeAsync` 与全部 `partial void` 钩子签名。
3. 在非 MGC 文件实现 `partial` 钩子，默认放在 `{Project}.{Module}.Application/Services/{Entity}ServiceImpl.cs`。
4. 钩子内只放同步、轻量、可快速失败的逻辑。
5. 构建并验证“树列表 + 跨父级/同父级移动 + 位序重排”链路。

## 标准实现模板

```csharp
using Materal.MergeBlock.Abstractions.Models;
using ZhiTu.Main.Abstractions.Domain;
using ZhiTu.Main.Abstractions.DTO.Category;

namespace ZhiTu.Main.Application.Services;

public partial class CategoryServiceImpl
{
    partial void OnConvertTreeDTOInit(Dictionary<string, object> contextData)
    {
        contextData["start"] = DateTime.Now;
    }

    partial void OnConvertTreeDTOBefore(List<Category> domains, Dictionary<string, object> contextData)
    {
        contextData["count"] = domains.Count;
    }

    partial void OnConvertTreeDTO(CategoryTreeListDTO dto, Category domain, Dictionary<string, object> contextData)
    {
        // 示例：按业务补充 dto 字段
    }

    partial void OnConvertTreeDTOAfter(List<CategoryTreeListDTO> dtos, List<Category> domains, Dictionary<string, object> contextData)
    {
        // 示例：树转换完成后的同步处理
    }

    partial void OnMoveTreeAndIndexBefore(MoveTreeNodeAndIndexModel model, Dictionary<string, object> contextData)
    {
        if (model.SourceID == model.TargetID)
        {
            throw new ZhiTuException("不能以自己为排序对象");
        }
    }

    partial void OnMoveTreeAndIndexAfter(MoveTreeNodeAndIndexModel model, Dictionary<string, object> contextData, List<Category> domains)
    {
        // 示例：记录日志、刷新轻量缓存
    }
}
```

## MoveTreeNodeAndIndexModel 关键字段

按当前 MMB 框架源码，`MoveTreeNodeAndIndexModel` 包含：
- `SourceID`：被移动实体 ID（必填）。
- `ParentID`：目标父级 ID（可空；空表示“不强制更改父级”，由算法决定）。
- `TargetID`：参照实体 ID（可空）。
- `Before`：`true` 表示移动到目标之前，`false` 表示移动到目标之后（默认 `false`）。

## ServiceImplHelper 树+位序逻辑契约

底层行为以框架源码为准：
- `Materal.MergeBlock.Application.Abstractions/Services/ServiceImplHelper.TreeAndIndex.cs`

在实现扩展时，按以下契约推理：
- 入口：`MoveAsync<TRepository, TDomain>(MoveTreeNodeAndIndexModel model, TRepository repository, params string[] groupProperties)`。
- 前置校验：`SourceID == TargetID` 直接失败。
- 父级决策优先级：
  - `TargetID` 存在时：优先取 `TargetID` 对应节点的 `ParentID`，取不到再退回 `model.ParentID`，再退回源节点原父级。
  - `TargetID` 为空时：`model.ParentID ?? 源节点原父级`。
- 跨父级时校验：
  - 新父级为源子节点时失败（防循环）。
  - 传入 `groupProperties` 时，源节点与目标父节点分组属性必须一致，否则失败。
- 执行移动：
  - 同父级移动：在同级节点列表内按 `Before` 重排位序。
  - 跨父级移动：先更新源节点父级，再重排原父级子节点位序，再插入并重排新父级子节点位序。
- 返回值：返回所有发生变更的实体列表（父级变化或 `Index` 变化）。
- 持久化：生成代码在 `OnMoveTreeAndIndexAfter` 后对变更列表逐条 `RegisterEdit`，最后 `CommitAsync()`。

## GetTreeListAsync 生成逻辑契约

以生成的 `ServiceImpl.TreeAndIndex.cs` 为准：
- 上下文流程：`OnConvertTreeDTOInit` -> 获取数据 -> `OnConvertTreeDTOBefore` -> `ToTree(..., OnConvertTreeDTO, true)` -> `OnConvertTreeDTOAfter`。
- 数据来源与排序：
  - `parentID == null`：`DefaultRepository.FindAsync(m => true, m => m.Index, SortOrder.Ascending)`。
  - `parentID != null`：`DefaultRepository.GetAllRecursiveChildren(parentID.Value)` 后再按 `Index` 升序排序。

## 分组位序配置说明

`TreeAndIndexGeneratorCodePlug` 会把实体配置的 `IndexGroupProperties` 作为 `groupProperties` 传入 `ServiceImplHelper.MoveAsync(...)`：
- 有分组配置：传入 `nameof(Entity.Property)` 数组。
- 无分组配置：传入空数组 `[]`。

## 钩子能力边界

`OnConvertTreeDTOInit/Before/OnConvertTreeDTO/After`、`OnMoveTreeAndIndexBefore/After` 都是 `partial void`：
- 可以：同步校验、同步加工、轻量上下文注入。
- 不适合：`await` 异步 I/O、长耗时逻辑、复杂事务编排。

需要异步扩展时，新增包装方法：

```csharp
public async Task MoveTreeNodeWithBizAsync(MoveTreeNodeAndIndexModel model)
{
    await ValidateBeforeMoveAsync(model);
    await MoveTreeNodeAsync(model);
    await RefreshCacheAfterMoveAsync(model);
}
```

## 强制规则

- 禁止修改任何 `MGC` 文件。
- 非 MGC 实现必须与生成签名完全一致（方法名、参数、返回值）。
- 异常处理遵循 `/mmb-exception-handling`。
- 文件组织遵循单文件优先：默认集中在 `{Entity}ServiceImpl.cs`。

## 自检清单

- 已检索并核对 `.TreeAndIndex.cs` 真实签名。
- 已确认当前实体确实同时具备树能力与位序能力。
- 扩展代码不在 `MGC` 目录。
- 所有 `partial void` 签名完全匹配。
- 树列表、同父级位序移动、跨父级移动三个链路都已验证通过。
