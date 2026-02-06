# JWT 认证中间件

## 概述

Materal.MergeBlock 框架提供的 JWT（JSON Web Token）认证中间件，支持用户授权和服务间授权两种模式。该中间件自动为所有 API 添加认证要求，并将登录用户信息注入到服务层。

## 安装

```bash
# 启动项目（Web.Host/Web.API 等）
dotnet add package Materal.MergeBlock.Authorization

# 需要使用 TokenService 的业务模块
dotnet add package Materal.MergeBlock.Authorization.Abstractions
```

### 包说明

| 包名 | 安装位置 | 说明 |
|------|----------|------|
| `Materal.MergeBlock.Authorization` | 启动项目 | 包含中间件实现、模块注册 |
| `Materal.MergeBlock.Authorization.Abstractions` | 业务模块 | 包含接口、扩展方法，供应用层引用 |

**注意**：`AuthorizationModule` 已在 `Materal.MergeBlock.Authorization` 中注册，**只需在启动项目安装主包即可**。业务模块只需安装 `Abstractions` 包以使用 `ITokenService` 等接口。

## 模块依赖

`AuthorizationModule` 依赖于 `WebModule`。

## 配置

在 `appsettings.json` 中添加 JWT 认证配置：

```json
{
    "Authorization": {
        "Key": "你的密钥字符串，建议不少于16位",
        "ExpiredTime": 7200,
        "Issuer": "发行者名称",
        "Audience": "接收者名称"
    }
}
```

### 配置项说明

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `Key` | string | `CMXMateral` | JWT 签名密钥，会通过 MD5 转换为 32 字节 |
| `ExpiredTime` | uint | `7200` | Token 有效期（秒），默认 2 小时 |
| `Issuer` | string | `MateralCore.Server` | Token 发行者 |
| `Audience` | string | `MateralCore.WebAPI` | Token 接收者 |

### 配置类

```csharp
public class AuthorizationOptions : IOptions
{
    public static string ConfigKey { get; } = "Authorization";
    public string Key { get; set; } = "CMXMateral";
    public uint ExpiredTime { get; set; } = 7200;
    public string Issuer { get; set; } = "MateralCore.Server";
    public string Audience { get; set; } = "MateralCore.WebAPI";
    public byte[] KeyBytes => Encoding.UTF8.GetBytes(MD5Crypto.Hash32(Key, true));
}
```

## 核心组件

### ITokenService

Token 服务接口，用于生成 JWT Token。

```csharp
public interface ITokenService
{
    /// <summary>
    /// 用户唯一标识键
    /// </summary>
    string UserIDKey { get; }

    /// <summary>
    /// 服务名称键
    /// </summary>
    string ServerNameKey { get; }

    /// <summary>
    /// 获得Token
    /// </summary>
    string GetToken(params Claim[] claims);

    /// <summary>
    /// 获得Token（用户模式）
    /// </summary>
    string GetToken(Guid userID);

    /// <summary>
    /// 获得Token（服务模式）
    /// </summary>
    string GetToken(string serverName);
}
```

### TokenServiceBase

Token 服务抽象基类，提供 JWT Token 生成的核心实现：

```csharp
public abstract class TokenServiceBase(IOptionsMonitor<AuthorizationOptions> authorizationConfig) : ITokenService
{
    public string UserIDKey { get; } = "UserID";
    public string ServerNameKey { get; } = "ServerName";

    public string GetToken(params Claim[] claims)
    {
        JwtSecurityTokenHandler tokenHandler = new();
        DateTime authTime = DateTime.UtcNow;
        DateTime expiresAt = authTime.AddSeconds(authorizationConfig.CurrentValue.ExpiredTime);
        SymmetricSecurityKey securityKey = new(authorizationConfig.CurrentValue.KeyBytes);
        List<Claim> allClaims =
        [
            new Claim(JwtRegisteredClaimNames.Iss, authorizationConfig.CurrentValue.Issuer),
            .. claims,
        ];
        SecurityTokenDescriptor tokenDescriptor = new()
        {
            Subject = new ClaimsIdentity(allClaims),
            Audience = authorizationConfig.CurrentValue.Audience,
            Issuer = authorizationConfig.CurrentValue.Issuer,
            Expires = expiresAt,
            SigningCredentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256)
        };
        SecurityToken token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}
```

## 使用方法

### 1. 服务层使用 TokenService

```csharp
public class YourServiceImpl : YourService
{
    private readonly ITokenService _tokenService;

    public YourServiceImpl(ITokenService tokenService)
    {
        _tokenService = tokenService;
    }

    public string GenerateUserToken(Guid userID)
    {
        return _tokenService.GetToken(userID);
    }

    public string GenerateServiceToken(string serviceName)
    {
        return _tokenService.GetToken(serviceName);
    }
}
```

### 2. 控制器获取登录用户信息

```csharp
[ApiController]
[Route("api/[controller]")]
public class YourController : ControllerBase
{
    [HttpGet("profile")]
    public IActionResult GetProfile()
    {
        // 获取登录用户ID
        Guid userID = this.GetLoginUserID();

        // 判断是否用户登录
        if (this.IsUserLogin())
        {
            // 用户已登录
        }

        return Ok(new { UserID = userID });
    }

    [HttpGet("server-info")]
    public IActionResult GetServerInfo()
    {
        // 获取服务名称
        string serverName = this.GetLoginServerName();

        // 判断是否服务登录
        if (this.IsServerLogin())
        {
            // 服务已登录
        }

        return Ok(new { ServerName = serverName });
    }
}
```

### 3. 跳过认证

对于不需要认证的接口，使用 `[AllowAnonymous]`：

```csharp
[ApiController]
[Route("api/[controller]")]
public class PublicController : ControllerBase
{
    [AllowAnonymous]
    [HttpGet("info")]
    public IActionResult GetPublicInfo()
    {
        return Ok(new { Message = "公开信息" });
    }
}
```

### 4. 服务层自动获取登录用户ID

中间件会自动将登录用户的 ID 注入到实现了 `IBaseService` 接口的服务中：

```csharp
public class YourServiceImpl : YourService, IBaseService
{
    /// <summary>
    /// 登录用户ID（由框架自动注入）
    /// </summary>
    public Guid? LoginUserID { get; set; }

    public async Task<UserDto> GetUserAsync(Guid id)
    {
        // 可以直接使用 LoginUserID 进行权限判断
        if (LoginUserID.HasValue)
        {
            // 用户已登录
        }
        return await _repository.GetAsync(id);
    }
}
```

## 服务间调用

### 发起方配置

服务间调用时，`AuthorizationControllerHttpHelper` 会自动附加 JWT Token：

```csharp
public class YourServiceImpl : YourService
{
    private readonly IControllerHttpHelper _httpHelper;

    public YourServiceImpl(IControllerHttpHelper httpHelper)
    {
        _httpHelper = httpHelper;
    }

    public async Task CallOtherService()
    {
        // hasToken = true 时自动附加 Authorization 头
        Dictionary<string, string> headers = _httpHelper.GetHeaders(hasToken: true);
        // 使用 headers 发起 HTTP 请求
    }
}
```

### 接收方验证

接收方服务只需正常使用认证中间件即可，框架会自动验证 Token。

## 认证流程

```
客户端请求
    ↓
[Authorization] Header: Bearer {JWT Token}
    ↓
UseAuthentication() 中间件
    ↓
JwtBearer 验证 Token
    ↓
AuthorizeFilter 全局拦截
    ↓
SetLoginUserInfoAttribute 自动注入 LoginUserID
    ↓
Controller / Service 处理请求
```

## 注意事项

1. **全局认证**：默认情况下，所有 API 都需要认证，使用 `[AllowAnonymous]` 跳过特定接口
2. **服务名称唯一性**：服务间调用时，确保服务名称唯一
3. **密钥安全**：生产环境中，请使用强密钥并妥善保管
4. **时钟偏移**：验证时允许的时钟偏移量等于 Token 有效期
5. **Token 刷新**：框架不提供 Token 刷新功能，需自行实现

## 扩展自定义

### 自定义 TokenService

继承 `TokenServiceBase` 实现自定义 Token 生成逻辑：

```csharp
public class CustomTokenService : TokenServiceBase
{
    public CustomTokenService(IOptionsMonitor<AuthorizationOptions> config) : base(config) { }

    public override string GetToken(params Claim[] claims)
    {
        // 自定义 Token 生成逻辑
        return base.GetToken(claims);
    }
}
```

### 自定义 Claim

```csharp
// 添加额外的 Claim
var claims = new[]
{
    new Claim("CustomKey", "CustomValue"),
    new Claim(ClaimTypes.Name, "UserName"),
};
string token = _tokenService.GetToken(claims);
```

### 替换默认 TokenService

自定义 TokenService 后，需要在模块中替换默认实现：

```csharp
[DependsOn(typeof(AuthorizationModule))]
public class YourModule() : MergeBlockModule("你的模块")
{
    public override void OnConfigureServices(ServiceConfigurationContext context)
    {
        context.Services.TryReplaceSingleton<ITokenService, CustomTokenService>();
    }
}
```
