---
name: mmb-jwt-auth
description: Materal.MergeBlock 框架 JWT 认证插件使用指南。当需要在 MMB 项目中添加 JWT 认证、使用 ITokenService 生成 Token、自定义 TokenService 或扩展 Token 携带信息时使用此技能。适用于：(1) 添加/配置 JWT 认证插件，(2) 在服务层生成用户或服务 Token (3) 在控制器获取登录用户信息 (4) 自定义 Token 生成逻辑 (5) 扩展 Token Claim 信息
---
# MMB JWT 认证插件

## 概述

本技能指导在 Materal.MergeBlock 框架中配置 JWT 认证插件，支持用户授权和服务间授权两种模式。

## 快速开始

### 1. 安装

```bash
# 宿主项目（Web.Host/Web.API）
dotnet add package Materal.MergeBlock.Authorization

# 业务模块（需使用 ITokenService）
dotnet add package Materal.MergeBlock.Authorization.Abstractions
```

### 2. 配置 appsettings.json

```json
{
    "Authorization": {
        "Key": "你的密钥字符串（不少于16位）",
        "ExpiredTime": 7200,
        "Issuer": "发行方",
        "Audience": "接收方"
    }
}
```

### 3. 注册模块

`AuthorizationModule` 已在包中自动注册，只需在启动项目中安装主包即可。

## 核心任务

### 生成 Token

在服务层注入 `ITokenService`：

```csharp
public class YourServiceImpl(ITokenService tokenService)
{
    // 用户模式
    public string GenerateUserToken(Guid userID) => tokenService.GetToken(userID);

    // 服务模式
    public string GenerateServiceToken(string serviceName) => tokenService.GetToken(serviceName);

    // 自定义Claims
    public string GenerateCustomToken(params Claim[] claims) => tokenService.GetToken(claims);
}
```

### 获取登录用户信息

**控制器中：**

```csharp
[HttpGet]
public async Task<ResultModel<UserDTO>> GetLoginUserInfoAsync()
{
    Guid userID = this.GetLoginUserID();

    UserDTO user = await DefaultService.GetInfoAsync(userID);

    return ResultModel<UserDTO>.Success(user, "获取当前登录用户信息成功");
}
```

**服务层（实现 IBaseService）：**

```csharp
public class YourServiceImpl : BaseServiceImpl<YourEntity>, IBaseService
{
    // 由框架自动注入
    public Guid LoginUserID { get; set; }

    public async Task<UserDTO> GetLoginUserInfoAsync()
    {
        User user = await DefaultRepository.FirstOrDefaultAsync(LoginUserID);
        UserDTO result = Mapper.Map<UserDTO>(user);
        return result;
    }
}
```

### 跳过认证

使用 `[AllowAnonymous]` 特性：

```csharp
[AllowAnonymous]
[HttpGet]
public ResultModel GetPublicInfo()
{
    return ResultModel.Success("公开信息");
}
```

### 自定义 TokenService

继承 `TokenServiceBase`：

```csharp
public class CustomTokenService(IOptionsMonitor<AuthorizationOptions> config) : TokenServiceBase(config)
{
    public override string GetToken(params Claim[] claims)
    {
        // 自定义逻辑
        return base.GetToken(claims);
    }
}
```

在模块中替换默认实现：

```csharp
public override void OnConfigureServices(ServiceConfigurationContext context)
{
    context.Services.TryReplaceSingleton<ITokenService, CustomTokenService>();
}
```

### 扩展 Token Claim

```csharp
Claim[] claims = new[]
{
    new Claim("UserID", "123e4567-e89b-12d3-a456-426614174000"),
    new Claim("CustomKey", "CustomValue"),
    new Claim(ClaimTypes.Name, "UserName"),
    new Claim(ClaimTypes.Role, "Admin")
};
string token = _tokenService.GetToken(claims);
```

## 服务间调用

发起方自动附加 Token：

```csharp
// hasToken: true 时自动附加 Authorization 头
Dictionary<string, string> headers = _httpHelper.GetHeaders(hasToken: true);
```

## 参考文献

完整 API、配置项说明和高级用法，请参阅 [authorization.md](references/authorization.md)

## 关键说明

| 组件 | 说明 |
|------|------|
| `ITokenService` | Token 生成服务接口 |
| `TokenServiceBase` | 抽象基类，继承以自定义 |
| `UserIDKey` | 默认值为 `"UserID"` |
| `ServerNameKey` | 默认值为 `"ServerName"` |
| `IBaseService` | 实现后自动注入 `LoginUserID` |
