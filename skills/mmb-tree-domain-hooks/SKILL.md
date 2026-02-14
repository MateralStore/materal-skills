---
name: mmb-tree-domain-hooks
description: MMB (Materal.MergeBlock) 框架树形实体扩展实现技能。用于实体具备树结构能力且不含位序能力时，基于代码生成的 GetTreeListAsync、MoveTreeNodeAsync 以及 OnConvertTreeDTOInit/OnConvertTreeDTOBefore/OnConvertTreeDTO/OnConvertTreeDTOAfter、OnMoveTreeBefore/OnMoveTreeAfter 钩子，在不修改 MGC 文件的前提下实现树列表转换与节点移动扩展。使用场景：(1) 需要在树DTO转换前后注入上下文或加工字段，(2) 需要在移动节点前后做校验与业务补偿，(3) 需要处理 partial void 同步限制并设计异步包装方法。
---

# MMB Tree 结构扩展指南

## 概述

当实体具备 `ITreeDomain` 能力且未走 `TreeAndIndex` 生成路径时，MMB 生成器会生成树查询与节点移动能力。扩展逻辑必须基于生成扩展点实现，禁止修改 `MGC` 目录。

## 适用范围

- 适用：`TreeGeneratorCodePlug` 生成的 `*.Tree.cs`。
- 不适用：实体同时具备 `IIndexDomain` 时，服务/控制器走 `TreeAndIndexGeneratorCodePlug`，应以 `*.TreeAndIndex.cs` 的真实签名为准。

## 先检索再实现

每次实现前先检索模块中的真实生成签名：

```bash
rg --files -g "*.Tree.cs" -g "*.TreeAndIndex.cs"
rg -n "GetTreeListAsync\(Guid\? parentID\)|MoveTreeNodeAsync|OnConvertTreeDTOInit|OnConvertTreeDTOBefore|OnConvertTreeDTO\(|OnConvertTreeDTOAfter|OnMoveTreeBefore|OnMoveTreeAfter" <模块路径>
```

重点确认以下文件（路径模式）：
- `{Project}.{Module}.Application/MGC/Services/{Entity}ServiceImpl.Tree.cs`
- `{Project}.{Module}.Abstractions/MGC/Services/I{Entity}Service.Tree.cs`
- `{Project}.{Module}.Application/MGC/Controllers/{Entity}Controller.Tree.cs`
- `{Project}.{Module}.Repository/MGC/Repositories/{Entity}RepositoryImpl.Tree.cs`

## 执行步骤

1. 若刚改过实体或特性，先运行 `/mmb-generator`。
2. 打开 `MGC/Services/{Entity}ServiceImpl.Tree.cs`，确认 `GetTreeListAsync`、`MoveTreeNodeAsync` 与全部 `partial void` 钩子签名。
3. 在非 MGC 文件实现 `partial` 钩子，默认放在 `{Project}.{Module}.Application/Services/{Entity}ServiceImpl.cs`。
4. 钩子内只放同步、轻量、可快速失败的逻辑。
5. 构建并验证“树列表 + 移动节点”链路。

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

    partial void OnMoveTreeBefore(MoveTreeNodeModel model, Dictionary<string, object> contextData)
    {
        if (model.SourceID == model.TargetID)
        {
            throw new ZhiTuException("不能将自己设置为自己的父级");
        }
    }

    partial void OnMoveTreeAfter(MoveTreeNodeModel model, Dictionary<string, object> contextData, Category domain)
    {
        // 示例：记录日志、刷新轻量缓存
    }
}
```

## MoveTreeNodeModel 关键字段

按当前 MMB 框架源码，`MoveTreeNodeModel` 包含：
- `SourceID`：被移动实体 ID（必填）。
- `TargetID`：目标父级 ID（可空；空表示移动到根级）。

## ServiceImplHelper 树移动逻辑契约

底层行为以官方源码为准：
- `Materal.MergeBlock.Application.Abstractions/Services/ServiceImplHelper.Tree.cs`

在实现扩展时，按以下契约推理：
- 入口：`MoveAsync<TRepository, TDomain>(MoveTreeNodeModel model, TRepository repository)`。
- 前置校验：`SourceID == TargetID` 直接失败。
- 源节点校验：`SourceID` 对应实体不存在时失败。
- 循环检测：`TargetID` 存在时，若目标在 `GetAllRecursiveChildrenID(SourceID)` 内，则失败。
- 父级变更：`sourceDomain.ParentID = model.TargetID`。
- 持久化：生成代码在 `OnMoveTreeAfter` 后执行 `RegisterEdit(domain)` + `CommitAsync()`。

## GetTreeListAsync 生成逻辑契约

以生成的 `ServiceImpl.Tree.cs` 为准：
- 上下文流程：`OnConvertTreeDTOInit` -> 获取数据 -> `OnConvertTreeDTOBefore` -> `ToTree(..., OnConvertTreeDTO, true)` -> `OnConvertTreeDTOAfter`。
- 数据来源：
  - `parentID == null`：`DefaultRepository.FindAsync(m => true)`。
  - `parentID != null`：`DefaultRepository.GetAllRecursiveChildren(parentID.Value)`。
- 树仓储契约：仓储需实现 `ITreeRepository<TDomain>`，提供 `GetAllRecursiveChildren` 与 `GetAllRecursiveChildrenID`。

## 钩子能力边界

`OnConvertTreeDTOInit/Before/OnConvertTreeDTO/After`、`OnMoveTreeBefore/After` 都是 `partial void`：
- 可以：同步校验、同步加工、轻量上下文注入。
- 不适合：`await` 异步 I/O、长耗时逻辑、复杂事务编排。

需要异步扩展时，新增包装方法：

```csharp
public async Task MoveTreeNodeWithBizAsync(MoveTreeNodeModel model)
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

- 已检索并核对 `.Tree.cs` 真实签名。
- 已确认当前实体不是 `TreeAndIndex` 生成路径。
- 扩展代码不在 `MGC` 目录。
- 所有 `partial void` 签名完全匹配。
- 树列表、移动节点两个链路都已验证通过。
