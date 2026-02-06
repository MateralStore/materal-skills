---
name: mmb-exception-handling
description: Materal.MergeBlock(MMB) 框架异常处理规范指导。在以下场景使用：(1) 服务层或控制器中需要抛出异常时，(2) 进行参数验证时，(3) 处理流式响应异常时，(4) 编写后台服务时，(5) 任何涉及异常处理和错误返回的场景。
---
# MMB 异常处理规范

> **项目说明**：本文档以知图项目为例，使用 `ZhiTuException`。
> 其他 MMB 项目请替换为对应的 `{ProjectName}Exception`（如 `MyAppException`）。

## 概述

Materal.MergeBlock 框架提供统一的全局异常处理机制。每个 MMB 项目都有自己的根异常类（如 `ZhiTuException`），所有业务相关错误都应使用此异常类。

## 异常类型

| 异常类型 | 使用场景 | HTTP状态码 | 示例 |
|---------|---------|-----------|------|
| `ZhiTuException` | 所有业务相关错误（参数验证、业务规则） | 200 | `throw new ZhiTuException("用户名已存在");` |
| 系统异常（Exception） | 未预期的系统错误 | 500 | 让框架自动处理，不要捕获吞掉 |

## 使用规范

### ZhiTuException（业务异常）

**统一用于**：参数验证失败、业务规则不满足等所有需要向用户返回错误信息的场景

```csharp
// 1. 参数验证
if (string.IsNullOrWhiteSpace(model.UserName)) throw new ZhiTuException("用户名不能为空");

if (model.Password.Length < 6) throw new ZhiTuException("密码长度不能少于6位");

if (model.Age < 0 || model.Age > 150) throw new ZhiTuException("年龄必须在0-150之间");

// 2. 业务规则检查
if (await DefaultRepository.ExistsAsync(model.UserName)) throw new ZhiTuException("用户名已存在");

User user = await DefaultRepository.FirstOrDefaultAsync(id) ?? throw new ZhiTuException($"用户不存在：{id}");

if (order.Status != OrderStatus.Pending) throw new ZhiTuException("只有待支付订单才能取消");

if (!currentUser.HasPermission(Permission.Admin)) throw new ZhiTuException("没有操作权限");
```

### 系统异常（不处理）

**重要**：不要手动捕获并吞掉系统异常，让框架统一处理

```csharp
// ❌ 错误：捕获后只返回null
try
{
    await UnitOfWork.CommitAsync();
}
catch (Exception ex)
{
    _logger.LogError(ex, "保存失败");
    return null; // 错误！异常被吞掉
}

// ✅ 正确：让异常向上传播，框架会记录日志并返回500
await UnitOfWork.CommitAsync();
```

## 流式响应异常

使用 `IAsyncEnumerable` 流式响应时，异常会被框架自动处理：

```csharp
[HttpGet("stream")]
public async IAsyncEnumerable<int> StreamData([FromQuery] int count)
{
    for (int i = 0; i < count; i++)
    {
        await Task.Delay(100);
        // 异常会被包装为特殊格式：[!!STREAM_ERROR_START!!]{json}[!!STREAM_ERROR_END!!]
        if (i == 5) throw new Exception("模拟流式异常");
        yield return i;
    }
}
```

**错误格式**：`[!!STREAM_ERROR_START!!]{"Code":500,"Message":"错误消息"}[!!STREAM_ERROR_END!!]`

## 最佳实践

### ✅ DO（推荐做法）

```csharp
// 1. 服务层返回 DTO，失败时抛出业务异常
public async Task<UserDTO> GetInfoAsync(Guid id)
{
    User user = await DefaultRepository.FirstOrDefaultAsync(id) ?? throw new ZhiTuException($"用户不存在：{id}");
    return Mapper.Map<UserDTO>(user);
}

// 2. 参数验证使用项目根异常
if (string.IsNullOrWhiteSpace(model.UserName)) throw new ZhiTuException("用户名不能为空");

// 3. 自定义业务异常继承项目根异常
public class OrderException : ZhiTuException
{
    public OrderException(string message) : base(message) { }
}
```

### ❌ DON'T（禁止做法）

```csharp
// 1. ❌ 不要用通用 Exception 处理业务逻辑
throw new Exception("用户名已存在"); // 错误！

// 2. ❌ 不要在服务层返回 ResultModel
public async Task<ResultModel> CreateUserAsync(...)
{
    if (exists) return ResultModel.Fail("用户已存在"); // 不推荐
}

// 3. ❌ 不要捕获所有异常后只记录日志
try { ... } catch (Exception ex) { _logger.LogError(ex); return null; }

// 4. ❌ 不要手动构造带堆栈的异常
throw new ZhiTuException($"错误: {ex.Message}"); // 不需要包含原始异常
```

## 配置

开发环境和生产环境的异常配置：

```json
{
    "Exception": {
        "ShowException": false,  // 生产环境必须为 false
        "ErrorMessage": "服务出错了！请联系管理员。"
    }
}
```

- **开发环境**：`ShowException: true` 显示详细错误
- **生产环境**：`ShowException: false` 隐藏敏感信息

## 完整示例

```csharp
public class UserServiceImpl(IUserRepository DefaultRepository, IUnitOfWork UnitOfWork) : IUserService
{
    public async Task<Guid> AddAsync(AddUserModel model)
    {
        // 1. 参数验证（使用项目根异常）
        if (string.IsNullOrWhiteSpace(model.UserName)) throw new ZhiTuException("用户名不能为空");

        if (model.Password.Length < 6) throw new ZhiTuException("密码长度不能少于6位");

        // 2. 业务规则检查（使用项目根异常）
        if (await DefaultRepository.ExistsAsync(model.UserName)) throw new ZhiTuException("用户名已存在");

        // 3. 创建用户（系统异常不捕获，让框架处理）
        User user = Mapper.Map<User>(model);
        user.Password = PasswordHelper.HashPassword(model.Password);
        await UnitOfWork.RegisterAdd(user);
        await UnitOfWork.CommitAsync();

        return user.ID;
    }

    public async Task<UserDTO> GetInfoAsync(Guid id)
    {
        // 数据不存在（使用项目根异常）
        User user = await DefaultRepository.FirstOrDefaultAsync(id) ?? throw new ZhiTuException($"用户不存在：{id}");            

        return Mapper.Map<UserDTO>(user);
    }

    public async Task DeleteAsync(Guid id)
    {
        User user = await DefaultRepository.FirstOrDefaultAsync(id) ?? throw new ZhiTuException($"用户不存在：{id}");

        // 权限检查（使用项目根异常）
        if (user.ID == LoginUserID) throw new ZhiTuException("不能删除自己的账号");

        await UnitOfWork.RegisterDelete(user);
        await UnitOfWork.CommitAsync();
    }
}
```
