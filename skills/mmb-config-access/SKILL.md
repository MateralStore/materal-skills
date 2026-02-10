---
name: mmb-config-access
description: MMB (Materal.MergeBlock) 框架配置获取规范指导。用于在服务实现、控制器、后台服务等场景中从配置文件获取值。包括：(1) 在 ApplicationConfig 类中定义配置属性，(2) 使用 IOptionsMonitor 注入配置，(3) 通过 CurrentValue 获取配置值，(4) 配置文件与配置类的对应关系。使用场景：需要在代码中读取配置值时。
---

# MMB 框架配置获取

## 配置类定义

在模块的 `Application` 项目中创建配置类：

```csharp
namespace ZhiTu.{ModuleName}.Application;

/// <summary>
/// 应用程序配置
/// </summary>
[Options("ConfigSectionName")]  // 配置节名称
public class ApplicationConfig : IOptions
{
    /// <summary>
    /// 配置属性1
    /// </summary>
    public string SomeProperty { get; set; } = "defaultValue";

    /// <summary>
    /// 配置属性2
    /// </summary>
    public int SomeNumber { get; set; } = 100;
}
```

**重要说明**：
- `[Options("ConfigSectionName")]` 特性指定配置节名称
- 配置类必须实现 `IOptions` 接口
- 可以设置默认值

## 配置文件定义

在同名的 `.json` 文件中添加配置值（位于 `Application` 项目根目录）：

```json
{
  "ConfigSectionName": {
    "SomeProperty": "实际值",
    "SomeNumber": 200
  }
}
```

文件命名格式：`ZhiTu.{ModuleName}.Application.json`

## 使用配置

### 服务实现类

```csharp
using Microsoft.Extensions.Options;

public partial class UserServiceImpl
{
    private readonly IOptionsMonitor<ApplicationConfig> _applicationConfig;

    public UserServiceImpl(IOptionsMonitor<ApplicationConfig> applicationConfig)
    {
        _applicationConfig = applicationConfig;
    }

    public async Task SomeMethod()
    {
        // 获取配置值
        string value = _applicationConfig.CurrentValue.SomeProperty;
    }
}
```

### 控制器

```csharp
using Microsoft.Extensions.Options;

[ApiController]
[Route("api/[controller]")]
public class SomeController : ControllerBase, ISomeController
{
    private readonly IOptionsMonitor<ApplicationConfig> _applicationConfig;

    public SomeController(IOptionsMonitor<ApplicationConfig> applicationConfig)
    {
        _applicationConfig = applicationConfig;
    }
}
```

### 后台服务

```csharp
using Microsoft.Extensions.Options;

public class SomeBackgroundService : BackgroundService
{
    private readonly IOptionsMonitor<ApplicationConfig> _applicationConfig;

    public SomeBackgroundService(IOptionsMonitor<ApplicationConfig> applicationConfig)
    {
        _applicationConfig = applicationConfig;
    }
}
```

## 为什么使用 IOptionsMonitor

| 类型 | 说明 | 推荐场景 |
|------|------|----------|
| `IOptions<T>` | 仅在启动时读取，配置更改不生效 | 配置永不更改的场景 |
| `IOptionsMonitor<T>` | 可监听配置更改，自动获取最新值 | **推荐使用**，支持热更新 |
| `IOptionsSnapshot<T>` | 每个请求获取新值 | Scoped 生命周期的服务 |

**推荐：始终使用 `IOptionsMonitor<T>` 以支持配置热更新。**

## 完整示例

参考 `UserServiceImpl.cs` 中的配置使用：

```csharp
// 获取默认密码
string defaultPassword = _applicationConfig.CurrentValue.DefaultPassword;
```
