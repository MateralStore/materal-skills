---
name: mmb-controller-return
description: Materal.MergeBlock(MMB) 框架控制器返回值设计规范。指导 LLM 在设计 MMB 框架控制器接口时选择正确的返回类型。使用场景：(1) 设计控制器接口返回类型时，(2) 判断 Service 层返回类型到 Controller 层的转换规则时，(3) 处理特殊返回类型（文件流、图片 Base64 等）时。适用于所有使用 Materal.MergeBlock 框架的项目。
---

# MMB 控制器返回值设计规范

## 核心原则

**控制器接口层必须包装返回值为标准 ResultModel 类型**，特殊场景除外。

## 标准返回类型

| 返回类型 | 使用场景 | 示例 |
|---------|---------|------|
| `Task<ResultModel>` | 无返回数据的操作 | 启用/禁用、修改密码、删除操作 |
| `Task<ResultModel<T>>` | 返回单个对象或值 | 获取详情、获取配置值、查询单个结果，也可以是不分页的列表 |
| `Task<CollectionResultModel<T>>` | 返回分页列表 | 标准列表查询、带分页的数据 |

### ResultModel

用于无返回数据的操作：

```csharp
/// <summary>
/// 启用用户
/// </summary>
[HttpPut]
Task<ResultModel> EnableAsync([Required] Guid id);

/// <summary>
/// 修改密码
/// </summary>
[HttpPut]
Task<ResultModel> ChangePasswordAsync(ChangePasswordRequestModel model);
```

### ResultModel<T>

返回单个对象或基本类型值：

```csharp
/// <summary>
/// 获取用户详情
/// </summary>
[HttpGet]
Task<ResultModel<UserDTO>> GetInfoAsync([Required] Guid id);

/// <summary>
/// 获取邀请码
/// </summary>
[HttpGet]
Task<ResultModel<string>> GetInviteCodeAsync();

/// <summary>
/// 获取邀请奖励
/// </summary>
[HttpGet]
Task<ResultModel<int>> GetInviteRewardAsync();

/// <summary>
/// 获取所有角色
/// </summary>
[HttpGet]
Task<ResultModel<List<RoleListDTO>>> GetAllRoleAsync();
```

### CollectionResultModel<T>

返回分页集合列表：

```csharp
/// <summary>
/// 获取用户列表
/// </summary>
[HttpPost]
Task<CollectionResultModel<UserListDTO>> GetListAsync(QueryUserRequestModel requestModel);
```

## Service 层到 Controller 层的自动转换

当Iservice的方法使用 `[MapperController]` 特性时，代码生成器会自动生成转换后的类型：

| Service 层返回 | Controller 接口返回 |
|----------------|---------------------|
| `Task` | `Task<ResultModel>` |
| `Task<T>` | `Task<ResultModel<T>>` |
| `Task<(List<T> data, RangeModel rangeInfo)>` | `Task<CollectionResultModel<T>>` |

```csharp
// Service 层 - 返回原始类型
public partial interface IUserService
{
    [MapperController(MapperType.Get)]
    Task<int> GetInviteRewardAsync();

    [MapperController(MapperType.Get)]
    Task<string> GetInviteCodeAsync();

    [MapperController(MapperType.Post)]
    Task<UserInfoDTO> GetUserInfoAsync();

    [MapperController(MapperType.Post)]
    Task<(List<UserListDTO> data, RangeModel rangeInfo)> GetListAsync(QueryUserRequestModel requestModel);
}

// Controller 接口层 - 自动包装为 ResultModel
public partial interface IUserController : IMergeBlockController
{
    [HttpGet]
    Task<ResultModel<int>> GetInviteRewardAsync();

    [HttpGet]
    Task<ResultModel<string>> GetInviteCodeAsync();

    [HttpPost]
    Task<ResultModel<UserInfoDTO>> GetUserInfoAsync();

    [HttpPost]
    Task<CollectionResultModel<UserListDTO>> GetListAsync(QueryUserRequestModel requestModel);
}
```

## 特殊返回类型

以下场景可以**直接返回**，不使用 ResultModel 包装：

| 场景 | 返回类型 | 说明 |
|------|---------|------|
| 图片 Base64 | `Task<string>` | 直接返回 base64 编码字符串 |
| 文件下载 | `Task<FileResult>` / `Task<IActionResult>` | 返回文件流 |
| SSE 流式响应 | `Task` | 服务方法返回 IAsyncEnumerable，由框架处理 |
| WebSocket | `Task` | 实时通信，不使用标准返回 |

### 图片 Base64 示例

```csharp
/// <summary>
/// 获取验证码图片（Base64）
/// </summary>
[HttpGet, AllowAnonymous]
Task<string> GetCaptchaImageAsync();
```

### 文件下载示例

```csharp
/// <summary>
/// 导出数据
/// </summary>
[HttpPost]
Task<IActionResult> ExportAsync(QueryRequestModel requestModel);
```

### SSE 流式响应示例

```csharp
// Service 层返回 IAsyncEnumerable
[MapperController(MapperType.Post)]
IAsyncEnumerable<ChatMessageDTO> StreamChatAsync(ChatRequestModel requestModel);

// Controller 接口 - 保持一致
[HttpPost]
IAsyncEnumerable<ChatMessageDTO> StreamChatAsync(ChatRequestModel requestModel);
```

## 决策流程

选择返回类型时按以下流程判断：

```
是否为特殊场景？（图片/文件/SSE/WebSocket）
├── 是 → 直接返回对应类型（string/FileResult/IAsyncEnumerable 等）
└── 否 → 继续判断

是否为分页列表查询？
├── 是 → CollectionResultModel<TListDTO>
└── 否 → 继续判断

是否有返回值？
├── 有 → ResultModel<T>
└── 无 → ResultModel
```

## 注意事项

1. **MapperController 自动处理**：使用 `[MapperController]` 特性时，自动转换 Service 返回类型为 Controller 接口返回类型
2. **手动创建接口**：手动创建控制器接口时，必须显式使用 ResultModel 包装
3. **特殊场景例外**：图片 Base64、文件下载、流式响应等场景可以直接返回原始类型
