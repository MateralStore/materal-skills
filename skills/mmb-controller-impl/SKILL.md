---
name: mmb-controller-impl
description: MMB 框架控制器实现技能。指导 LLM 根据控制器接口实现控制器逻辑。使用场景：(1) 控制器接口设计完成后需要实现控制器时；(2) 需要手动实现无法通过 MapperController 自动生成的控制器方法时；(3) MMB 项目开发流程中控制器设计完成后。输入控制器接口定义，输出控制器实现代码。适用于所有使用 Materal.MergeBlock 框架的项目。
---

# MMB 控制器实现技能

## 概述

本技能用于根据控制器接口实现符合 MMB 框架规范的控制器类。

## 工作流程

```mermaid
flowchart TD
    A[输入控制器接口定义] --> B{检查 MGC 文件夹<br/>是否存在部分类?}
    B -->|不存在| C[创建完整类<br/>继承 {ModuleName}Controller]
    B -->|存在| D{MGC 中的类<br/>是否继承基类?}
    D -->|已继承| E[创建同名部分类<br/>不添加基类]
    D -->|未继承| F[创建同名部分类<br/>继承 {ModuleName}Controller]
    C --> G[实现接口方法]
    E --> G
    F --> G
    G --> H[调用服务方法]
    H --> I[输出实现代码]
```

## 执行步骤

### 第一步：读取控制器接口定义

**控制器接口来源**：
```
{ProjectName}.{ModuleName}.Abstractions/Controllers/I{Entity}Controller.cs
```

```bash
Read {ProjectName}.{ModuleName}.Abstractions/Controllers/I{Entity}Controller.cs
```

### 第二步：检查 MGC 文件夹中是否存在自动生成的部分类

**检查路径**：
```
{ProjectName}.{ModuleName}.Application/MGC/Controllers/{Entity}Controller.cs
```

**判断规则**：
- 如果 MGC 文件夹中存在 `{Entity}Controller.cs` → 进入第三步判断是否继承基类
- 如果 MGC 文件夹中不存在 → 创建 **完整类**，继承 `{ModuleName}Controller`

### 第三步：确定基类类型

#### 场景1：MGC 中存在自动生成的部分类

**需要进一步检查 MGC 中的类是否已继承基类**：

如果 MGC 中的类**已继承基类**（如 `class AdminController : MainController<...>`）：
```csharp
namespace {ProjectName}.{ModuleName}.Application.Controllers;

/// <summary>
/// {实体描述}控制器
/// </summary>
public partial class {Entity}Controller
{
    // 方法实现...（无需添加基类）
}
```

如果 MGC 中的类**未继承基类**（如 `public partial class AdminController`）：
```csharp
using {ProjectName}.{ModuleName}.Abstractions.Services;

namespace {ProjectName}.{ModuleName}.Application.Controllers;

/// <summary>
/// {实体描述}控制器
/// </summary>
[Route("{ModuleAPI}/[controller]/[action]")]
public partial class {Entity}Controller : {ModuleName}Controller<I{Entity}Service>
{
    // 方法实现...（需要添加基类）
}
```

#### 场景2：MGC 中不存在自动生成的类

继承 `{ModuleName}Controller` 或 `{ModuleName}Controller<TService>`：

```csharp
using {ProjectName}.{ModuleName}.Abstractions.Services;

namespace {ProjectName}.{ModuleName}.Application.Controllers;

/// <summary>
/// {实体描述}控制器
/// </summary>
[Route("{ModuleAPI}/[controller]/[action]")]
public class {Entity}Controller : {ModuleName}Controller<I{Entity}Service>, I{Entity}Controller
{
    // 方法实现...
}
```

### 第四步：实现控制器方法

#### 方法实现模板

```csharp
/// <summary>
/// {方法描述}
/// </summary>
/// <param name="{ParameterName}">{参数描述}</param>
/// <returns></returns>
[Http{Method}]
public async Task<ResultModel<{ReturnType}>> {MethodName}Async({RequestModel} {ParameterName})
{
    // 1. 参数映射（RequestModel → ServiceModel）
    {ServiceModel} model = Mapper.Map<{ServiceModel}>({ParameterName})
        ?? throw new ZhiTuException("映射失败");

    // 2. 绑定登录用户 ID（如需要）
    BindLoginUserID(model);

    // 3. 调用服务方法
    {ReturnType} result = await DefaultService.{MethodName}Async(model);

    // 4. 返回结果
    return ResultModel<{ReturnType}>.Success(result, "{操作描述}成功");
}
```

#### 特殊场景处理

##### 1. 无参数方法

```csharp
[HttpGet]
public async Task<ResultModel<string>> GetCaptchaImageAsync()
{
    string result = await DefaultService.GetCaptchaImageAsync();
    return ResultModel<string>.Success(result, "获取验证码成功");
}
```

##### 2. 简单类型参数（无需映射）

```csharp
[HttpGet]
public async Task<ResultModel<UserDTO>> GetInfoAsync([Required] Guid id)
{
    UserDTO result = await DefaultService.GetInfoAsync(id);
    return ResultModel<UserDTO>.Success(result, "获取信息成功");
}
```

##### 3. 返回无返回值方法

```csharp
[HttpPost]
public async Task<ResultModel> SetEnabledAsync(SetEnabledRequestModel requestModel)
{
    SetEnabledModel model = Mapper.Map<SetEnabledModel>(requestModel)
        ?? throw new ZhiTuException("映射失败");
    await DefaultService.SetEnabledAsync(model);
    return ResultModel.Success("设置状态成功");
}
```

##### 4. 匿名访问方法

```csharp
[HttpPost, AllowAnonymous]
public async Task<ResultModel<LoginResultDTO>> LoginAsync(LoginRequestModel requestModel)
{
    LoginModel model = Mapper.Map<LoginModel>(requestModel)
        ?? throw new ZhiTuException("映射失败");
    LoginResultDTO result = await DefaultService.LoginAsync(model);
    return ResultModel<LoginResultDTO>.Success(result, "登录成功");
}
```

##### 5. 文件上传

```csharp
[HttpPost]
public async Task<ResultModel<string>> UploadAvatarAsync([Required] Guid userId, IFormFile file)
{
    if (file == null || file.Length == 0)
    {
        throw new ZhiTuException("请选择要上传的文件");
    }
    string result = await DefaultService.UploadAvatarAsync(userId, file);
    return ResultModel<string>.Success(result, "上传成功");
}
```

##### 6. 文件下载

```csharp
[HttpGet]
public async Task<IActionResult> DownloadAsync([Required] Guid id)
{
    (byte[] fileBytes, string fileName, string contentType) = await DefaultService.GetFileAsync(id);
    return File(fileBytes, contentType, fileName);
}
```

### 第五步：MergeBlockController 基类可用成员

| 成员名 | 类型 | 说明 |
|--------|------|------|
| `Mapper` | `IMapper` | 对象映射器 |
| `DefaultService` | `TService` | 默认服务（继承自 `MergeBlockController<TService>`） |
| `GetClientIP()` | `string` | 获取客户端 IP |
| `BindLoginUserID(object)` | `void` | 绑定登录用户 ID 到带有 `[LoginUserID]` 特性的属性 |

### 第六步：输出实现代码

将实现代码写入：
```
{ProjectName}.{ModuleName}.Application/Controllers/{Entity}Controller.cs
```

## 完整示例

### 示例1：MGC 存在部分类（推荐）

**自动生成**（MGC/AdminController.cs）：
```csharp
public partial class AdminController : MainController<...>, IAdminController
{
}
```

**手动实现**（Controllers/AdminController.cs）：
```csharp
namespace ZhiTu.Main.Application.Controllers;

public partial class AdminController
{
    /// <summary>
    /// 管理员登录
    /// </summary>
    [HttpPost, AllowAnonymous]
    public async Task<ResultModel<LoginResultDTO>> LoginAsync(LoginRequestModel requestModel)
    {
        LoginModel model = Mapper.Map<LoginModel>(requestModel)
            ?? throw new ZhiTuException("映射失败");
        LoginResultDTO result = await DefaultService.LoginAsync(model);
        return ResultModel<LoginResultDTO>.Success(result, "登录成功");
    }
}
```

### 示例2：MGC 不存在（手动创建完整类）

```csharp
using Microsoft.AspNetCore.Mvc;
using ZhiTu.Main.Abstractions.Controllers;
using ZhiTu.Main.Abstractions.Services;

namespace ZhiTu.Main.Application.Controllers;

/// <summary>
/// 文件管理控制器
/// </summary>
[Route("MainAPI/[controller]/[action]")]
public class FileController : MainController<IFileService>, IFileController
{
    /// <summary>
    /// 上传文件
    /// </summary>
    [HttpPost]
    public async Task<ResultModel<string>> UploadAsync(IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            throw new ZhiTuException("请选择要上传的文件");
        }
        string result = await DefaultService.UploadAsync(file);
        return ResultModel<string>.Success(result, "上传成功");
    }
}
```

## 注意事项

1. **必须使用 partial class**：当 MGC 中存在自动生成的类时，手动创建的类必须是 partial class
2. **不重复定义基类**：部分类不需要再次指定基类，基类已在 MGC 文件中定义
3. **异常处理**：使用 `{ProjectName}Exception` 抛出业务异常
4. **参数映射**：使用 `Mapper.Map` 进行 RequestModel → ServiceModel 映射
5. **登录用户绑定**：需要获取登录用户 ID 时，在 ServiceModel 属性上添加 `[LoginUserID]` 特性，然后调用 `BindLoginUserID(model)`
6. **匿名访问**：添加 `[AllowAnonymous]` 特性
7. **禁止修改 MGC**：MGC 文件夹中的代码是自动生成的，禁止手动修改

## 相关技能

- **`/mmb-controller-design`**：控制器设计技能
- **`/mmb-controller-return`**：控制器返回值设计规范
- **`/mmb-service-design`**：服务接口设计技能
