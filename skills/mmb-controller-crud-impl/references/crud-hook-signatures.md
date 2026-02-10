# CRUD Hook Signatures

来源：MMB 框架 `Materal.MergeBlock.Web.Abstractions.Controllers.MergeBlockController` 源码（`MergeBlockController.cs`）。

## 基类与能力

- `MergeBlockController`:
  - `protected IMapper Mapper`
  - `protected string GetClientIP()`
  - `protected void BindLoginUserID(object model)`
- `MergeBlockController<TService>`:
  - `protected TService DefaultService`
- `MergeBlockController<TAddRequestModel, TEditRequestModel, TQueryRequestModel, TAddModel, TEditModel, TQueryModel, TDTO, TListDTO, TService>`:
  - 标准 CRUD 默认实现与可重写点

## Add

```csharp
[HttpPost]
public virtual async Task<ResultModel<Guid>> AddAsync(TAddRequestModel requestModel)

protected virtual async Task<ResultModel<Guid>> AddAsync(TAddModel model, TAddRequestModel requestModel)
```

默认行为：`Mapper.Map` -> `BindLoginUserID` -> `DefaultService.AddAsync` -> `ResultModel<Guid>.Success`。

## Edit

```csharp
[HttpPut]
public virtual async Task<ResultModel> EditAsync(TEditRequestModel requestModel)

protected virtual async Task<ResultModel> EditAsync(TEditModel model, TEditRequestModel requestModel)
```

默认行为：`Mapper.Map` -> `BindLoginUserID` -> `DefaultService.EditAsync` -> `ResultModel.Success`。

## Delete

```csharp
[HttpDelete]
public virtual async Task<ResultModel> DeleteAsync([Required(ErrorMessage = "唯一标识为空")] Guid id)
```

默认行为：`DefaultService.DeleteAsync` -> `ResultModel.Success`。

## GetInfo

```csharp
[HttpGet]
public virtual async Task<ResultModel<TDTO>> GetInfoAsync([Required(ErrorMessage = "唯一标识为空")] Guid id)
```

默认行为：`DefaultService.GetInfoAsync` -> `ResultModel<TDTO>.Success`。

## GetList

```csharp
[HttpPost]
public virtual async Task<CollectionResultModel<TListDTO>> GetListAsync(TQueryRequestModel requestModel)

protected virtual async Task<CollectionResultModel<TListDTO>> GetListAsync(TQueryModel model, TQueryRequestModel requestModel)
```

默认行为：`Mapper.Map` -> `DefaultService.GetListAsync` -> `CollectionResultModel<TListDTO>.Success`。

## 重写建议

- 仅改业务处理（不改路由/鉴权）：优先重写 `protected`（Add/Edit/GetList）。
- 需要加 `[Authorize]`、`[AllowAnonymous]`、参数特性或改动作入口：重写 `public`。
- Delete/GetInfo 只能重写 `public`。
