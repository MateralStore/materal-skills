# 控制器模板参考

按需复制并修改，保持与模块既有命名规范一致。

占位符约定：

1. `{ProjectName}`：项目名，例如 `Demo`
2. `{ModuleName}`：模块名，例如 `Order`
3. `{ModuleName}Controller`：模块控制器基类，例如 `OrderController`

## 1. 服务接口上标记 MapperController（无特殊处理路径）

`MapperControllerAttribute` 仅支持方法级，且必须传 `MapperType`。

```csharp
namespace {ProjectName}.{ModuleName}.Abstractions.Services;

public partial interface I{Entity}Service
{
    [MapperController(MapperType.Post)]
    Task {ActionName}Async({ServiceModelType} model);

    [MapperController(MapperType.Get, IsAllowAnonymous = true)]
    Task<{ResultDtoType}> {QueryActionName}Async(Guid id);

    [MapperController(MapperType.Get, Policy = "AdminOnly")]
    Task<{ResultDtoType}> {AdminActionName}Async();
}
```

## 2. MapperController 自动生成结果（MGC）

运行生成器后会生成：

1. `*.Abstractions/MGC/Controllers/I{Entity}Controller.Mapper.cs`
2. `*.Application/MGC/Controllers/{Entity}Controller.Mapper.cs`

生成代码特征：

1. 自动生成 `[HttpGet/Post/Put/Delete/Patch]`。
2. `IsAllowAnonymous = true` 时生成 `[AllowAnonymous]`。
3. `Policy` 非空且非匿名时生成 `[Authorize(Policy = "...")]`。
4. 需要映射参数会生成 `Mapper.Map`。
5. 对“需要映射参数”在映射后自动调用 `BindLoginUserID(...)`。
6. 返回类型自动包装为 `ResultModel` / `ResultModel<T>` / `CollectionResultModel<T>`。

## 3. IController 接口（需要特殊处理路径）

```csharp
using {ProjectName}.{ModuleName}.Abstractions.RequestModel.{Entity};

namespace {ProjectName}.{ModuleName}.Abstractions.Controllers;

public partial interface I{Entity}Controller
{
    [HttpPost]
    Task<ResultModel<{ResultDtoType}>> {ActionName}Async({RequestModelType} requestModel);
}
```

## 4. Controller 实现（需要特殊处理路径）

```csharp
using {ProjectName}.{ModuleName}.Abstractions.Controllers;
using {ProjectName}.{ModuleName}.Abstractions.RequestModel.{Entity};
using {ProjectName}.{ModuleName}.Abstractions.Services;
using {ProjectName}.{ModuleName}.Abstractions.Services.Models.{Entity};

namespace {ProjectName}.{ModuleName}.Application.Controllers;

public partial class {Entity}Controller : {ModuleName}Controller<I{Entity}Service>, I{Entity}Controller
{
    [HttpPost]
    public async Task<ResultModel<{ResultDtoType}>> {ActionName}Async({RequestModelType} requestModel)
    {
        {ServiceModelType} model = Mapper.Map<{ServiceModelType}>(requestModel)
            ?? throw new {ProjectName}Exception("映射失败");

        {ResultDtoType} result = await DefaultService.{ActionName}Async(model);
        return ResultModel<{ResultDtoType}>.Success(result, "执行成功");
    }
}
```

## 5. 请求模型模板

```csharp
namespace {ProjectName}.{ModuleName}.Abstractions.RequestModel.{Entity};

public class {RequestModelType}
{
    public Guid Id { get; set; }
    public string Keyword { get; set; } = string.Empty;
}
```

## 6. 最小检查项

1. `IController` 与 Controller 方法签名一致。
2. 路由和 HTTP 动词与需求一致。
3. `Mapper.Map` 源/目标类型正确。
4. `ResultModel` 泛型与返回值一致。
5. 自定义文件均位于非 `MGC` 路径。
