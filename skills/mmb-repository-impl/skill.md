---
name: mmb-repository-impl
description: MMB 框架仓储特殊方法实现技能。指导 LLM 为仓储实现特殊方法以优化性能或处理复杂查询。使用场景：(1) 服务实现时发现需要仓储提供特殊方法时（复杂多表联合查询、批量操作、复杂聚合等），(2) 需要优化数据库查询性能时，(3) MMB 项目开发流程中需要定义仓储时。输入实体定义、需要的特殊方法描述，设计并实现仓储接口和仓储实现类中的特殊方法。
---

# MMB 仓储特殊方法实现技能

## 概述

本技能用于为仓储层实现特殊方法，主要解决性能优化问题（如复杂多表联合查询）和复杂查询需求。

## 输入

- 实体定义路径
- 需要实现的特殊方法描述

## 使用场景

### 1. 复杂的多表联合查询

**问题**：需要关联多个表（3个以上）的数据进行查询，或进行复杂的联合查询操作

```csharp
// 场景：需要查询订单详情，包含用户、产品、物流等多表信息
// 简单的两表联合（如订单-用户）可在服务层处理
// 复杂的多表联合查询应在仓储层实现以提高性能
```

**解决方案**：仓储提供复杂多表联合查询方法，返回组合的 DTO

### 2. 批量操作优化

**问题**：逐个操作导致大量 SQL 语句

```csharp
// 效率低下的批量更新
foreach (var userID in userIDs)
{
    User user = await _userRepository.FirstOrDefaultAsync(userID);
    user.Status = newStatus;
    await _unitOfWork.RegisterEdit(user);
}
await _unitOfWork.CommitAsync(); // 生成 N 条 UPDATE 语句
```

**解决方案**：仓储提供批量操作方法

### 3. 复杂聚合查询

**问题**：需要分组、统计等 EF Core 难以高效生成的查询

**解决方案**：仓储提供专门的聚合方法

### 4. 原生 SQL 查询

**问题**：EF Core 生成的 SQL 性能不佳，或需要执行复杂的原生 SQL 查询

**解决方案**：仓储提供使用 `ExecuteQuerySql` 或 `ExecuteNonQuery` 执行原生SQL的方法

**注意**：MMB 框架禁止使用自定义存储过程，数据库自带的存储过程（如系统存储过程）允许使用

## 执行步骤

### 第一步：读取实体定义

```bash
Read {ProjectName}.{ModuleName}.Abstractions/Domain/{EntityName}.cs
```

### 第二步：检查 MGC 生成的仓储基类

**说明**：MGC 代码生成器通常会自动生成仓储的基础代码并选择正确的基类。

不同模块使用不同的仓储基类：

| 模块 | 仓储接口基类 | 仓储实现基类 |
|------|-------------|-------------|
| ZhiTu.Main | `IMainRepository<T>` | `MainRepositoryImpl<T>` |
| 其他模块 | `I{Module}Repository<T>` | `{Module}RepositoryImpl<T>` |

**重要**：
- 如果 MGC 中已经生成了对应仓储，直接在 `Repositories/` 目录下创建 partial 扩展即可
- 只有当 MGC 中没有对应仓储或没有继承时，才需要手动指定基类

### 第三步：分析需要实现的方法

根据输入的描述，确定需要实现的仓储方法：

| 场景 | 方法命名模式 | 返回类型 |
|------|-------------|---------|
| 复杂多表联合查询 | `Get{Entity}With{Related}InfoAsync` | `Task<List<{ResultDTO}>>` |
| 批量更新 | `BatchUpdate{Property}Async` | `Task` |
| 批量删除 | `BatchDeleteAsync` | `Task` |
| 聚合统计 | `Get{Statistics}Async` | `Task<List<{StatisticsDTO}>>` |
| 原生 SQL 查询 | `Search{Entity}Async` | `Task<List<{ResultDTO}>>` |

### 第四步：设计仓储接口

#### 3.1 确定仓储接口文件路径

```
{ProjectName}.{ModuleName}.Abstractions/Repositories/I{Entity}Repository.cs
```

**重要说明**：
- 仓储接口放在 `Abstractions` 层（而非 `Repository` 层）
- 这是 MMB 框架的设计约定
- MGC 自动生成的仓储接口在 `MGC/Repositories/` 下，自定义的放在 `Repositories/` 下

**注意**：如果仓储接口已存在，则读取现有文件并在其中添加新方法

#### 3.2 添加仓储方法签名

```csharp
namespace {ProjectName}.{ModuleName}.Abstractions.Repositories;

using {ProjectName}.{ModuleName}.Abstractions.Domain;
using Materal.MergeBlock.Repository.Abstractions;
using System.Linq.Expressions;

/// <summary>
/// {实体描述}仓储接口
/// </summary>
public partial interface I{Entity}Repository : I{Module}Repository<{Entity}>
{
    /// <summary>
    /// 获取带{关联实体}信息的{实体}列表
    /// </summary>
    Task<List<{Entity}With{Related}DTO>> Get{Entity}With{Related}InfoAsync(
        Expression<Func<{Entity}, bool>> where);

    /// <summary>
    /// 批量更新{属性}
    /// </summary>
    Task BatchUpdate{Property}Async(
        List<{KeyType}> ids,
        {PropertyType} newValue);
}
```

### 第五步：实现仓储方法

#### 4.1 确定仓储实现文件路径

```
{ProjectName}.{ModuleName}.Repository/Repositories/{Entity}RepositoryImpl.cs
```

#### 4.2 实现仓储方法

```csharp
namespace {ProjectName}.{ModuleName}.Repository.Repositories;

using {ProjectName}.{ModuleName}.Abstractions.Domain;
using {ProjectName}.{ModuleName}.Abstractions.Repositories;
using Microsoft.EntityFrameworkCore;

/// <summary>
/// {实体描述}仓储实现
/// </summary>
public partial class {Entity}RepositoryImpl : {Module}RepositoryImpl<{Entity}>, I{Entity}Repository
{
    // 构造函数由父类提供，无需手动定义

    public async Task<List<{Entity}With{Related}DTO>> Get{Entity}With{Related}InfoAsync(
        Expression<Func<{Entity}, bool>> where)
    {
        // 多表联合查询示例（MMB 未启用导航属性，使用 Join 进行关联）
        return await (from e in DBSet
                      join r in DbContext.Set<{RelatedEntity}>() on e.{RelatedID} equals r.ID
                      where where.Compile()(e)
                      select new {Entity}With{Related}DTO
                      {
                          ID = e.ID,
                          // 映射实体属性
                          ... = e....,
                          // 映射关联实体属性
                          {Related}Name = r.Name
                      })
                      .ToListAsync();
    }

    public async Task BatchUpdate{Property}Async(
        List<{KeyType}> ids,
        {PropertyType} newValue)
    {
        await DBSet
            .Where(e => ids.Contains(e.ID))
            .ExecuteUpdateAsync(setters => setters.SetProperty(e => e.{Property}, newValue));
    }
}
```

#### 4.3 DTO 文件夹位置规则

**重要**：DTO 应按实体进行文件夹分类存放，而非直接放在 DTO 根目录下。

| DTO 类型 | 正确路径 | 错误路径 |
|---------|---------|---------|
| 实体相关 DTO | `DTO/{EntityName}/{DtoName}.cs` | `DTO/{DtoName}.cs` |

**示例**：
- `DTO/Admin/LoginResultDTO.cs` ✅
- `DTO/AdminStatisticsDTO.cs` ❌ → 应为 `DTO/Admin/AdminStatisticsDTO.cs`

**原因**：按实体分类组织 DTO 可以提高代码可维护性，避免 DTO 根目录过于混乱。

#### 4.4 完整示例（ZhiTu.Main 模块的 Admin 实体）

**DTO**（`ZhiTu.Main.Abstractions/DTO/Admin/AdminStatisticsDTO.cs`）：
```csharp
namespace ZhiTu.Main.Abstractions.DTO.Admin;

/// <summary>
/// 管理员统计DTO
/// </summary>
public class AdminStatisticsDTO
{
    /// <summary>
    /// 是否启用
    /// </summary>
    public bool IsEnabled { get; set; }

    /// <summary>
    /// 数量
    /// </summary>
    public int Count { get; set; }
}
```

**仓储接口**（`ZhiTu.Main.Abstractions/Repositories/IAdminRepository.cs`）：
```csharp
namespace ZhiTu.Main.Abstractions.Repositories;

using ZhiTu.Main.Abstractions.Domain;
using ZhiTu.Main.Abstractions;
using Materal.MergeBlock.Repository.Abstractions;
using System.Linq.Expressions;

/// <summary>
/// 管理员仓储接口
/// </summary>
public partial interface IAdminRepository : IMainRepository<Admin>
{
    /// <summary>
    /// 批量更新管理员启用状态
    /// </summary>
    Task BatchUpdateIsEnabledAsync(List<Guid> ids, bool isEnabled);
}
```

**仓储实现**（`ZhiTu.Main.Repository/Repositories/AdminRepositoryImpl.cs`）：
```csharp
namespace ZhiTu.Main.Repository.Repositories;

using ZhiTu.Main.Abstractions.Domain;
using ZhiTu.Main.Abstractions.Repositories;
using Microsoft.EntityFrameworkCore;

/// <summary>
/// 管理员仓储实现
/// </summary>
public partial class AdminRepositoryImpl : MainRepositoryImpl<Admin>, IAdminRepository
{
    public async Task BatchUpdateIsEnabledAsync(List<Guid> ids, bool isEnabled)
    {
        await DBSet
            .Where(a => ids.Contains(a.ID))
            .ExecuteUpdateAsync(setters => setters.SetProperty(a => a.IsEnabled, isEnabled));
    }
}
```

#### 4.5 常见实现模式

**说明**：简单的两表联合查询（如订单-用户）可在服务层分别查询后组合，无需仓储自定义方法。以下为真正需要仓储参与的复杂场景：

**复杂多表联合查询（3表以上）**：
```csharp
// 查询订单详情，包含用户、订单项、产品等多表信息
public async Task<List<OrderDetailDTO>> GetOrderDetailsAsync(Expression<Func<Order, bool>> where)
{
    return await (from o in DBSet
                  join u in DbContext.Set<User>() on o.UserID equals u.ID
                  join i in DbContext.Set<OrderItem>() on o.ID equals i.OrderID
                  join p in DbContext.Set<Product>() on i.ProductID equals p.ID
                  where where.Compile()(o)
                  select new OrderDetailDTO
                  {
                      OrderID = o.ID,
                      OrderName = o.Name,
                      UserName = u.Name,
                      ProductName = p.Name,
                      Quantity = i.Quantity,
                      Price = i.Price
                  })
                  .ToListAsync();
}
```

**批量更新（EF Core 7+）**：
```csharp
public async Task BatchUpdateStatusAsync(List<Guid> ids, UserStatus status)
{
    await DBSet
        .Where(u => ids.Contains(u.ID))
        .ExecuteUpdateAsync(setters => setters.SetProperty(u => u.Status, status));
}
```

**批量删除**：
```csharp
public async Task BatchDeleteAsync(List<Guid> ids)
{
    await DBSet
        .Where(u => ids.Contains(u.ID))
        .ExecuteDeleteAsync();
}
```

**复杂聚合查询**：
```csharp
public async Task<List<CategoryStatisticsDTO>> GetCategoryStatisticsAsync()
{
    return await DBSet
        .GroupBy(p => p.CategoryID)
        .Select(g => new CategoryStatisticsDTO
        {
            CategoryID = g.Key,
            ProductCount = g.Count(),
            AveragePrice = g.Average(p => p.Price)
        })
        .ToListAsync();
}
```

**原生 SQL 查询**：
```csharp
public async Task<List<UserSearchResultDTO>> SearchUsersAsync(string keyword)
{
    string sql = "SELECT ID, UserName, Email FROM Users WHERE UserName LIKE @Keyword";
    var parameters = new List<IDataParameter>
    {
        new SqlParameter("@Keyword", $"%{keyword}%")
    };
    return await ExcuteQuerySql<UserSearchResultDTO>(sql, parameters);
}
```

**复杂原生 SQL 查询（使用回调处理）**：
```csharp
public async Task<List<UserStatisticsDTO>> GetUserStatisticsAsync()
{
    string sql = @"
        SELECT
            u.ID,
            u.UserName,
            COUNT(o.ID) AS OrderCount,
            SUM(o.TotalAmount) AS TotalAmount
        FROM Users u
        LEFT JOIN Orders o ON u.ID = o.UserID
        GROUP BY u.ID, u.UserName";

    return await ExcuteQuerySql<UserStatisticsDTO>(sql, null, dr =>
    {
        return new UserStatisticsDTO
        {
            UserID = dr.GetGuid(dr.GetOrdinal("ID")),
            UserName = dr.GetString(dr.GetOrdinal("UserName")),
            OrderCount = dr.GetInt32(dr.GetOrdinal("OrderCount")),
            TotalAmount = dr.GetDecimal(dr.GetOrdinal("TotalAmount"))
        };
    });
}
```

### 第六步：写入文件

**仓储接口不存在时创建**：
```bash
Write {ProjectName}.{ModuleName}.Abstractions/Repositories/I{Entity}Repository.cs
```

**仓储接口已存在时添加方法**：
```bash
Edit {ProjectName}.{ModuleName}.Abstractions/Repositories/I{Entity}Repository.cs
```

**仓储实现不存在时创建**：
```bash
Write {ProjectName}.{ModuleName}.Repository/Repositories/{Entity}RepositoryImpl.cs
```

**仓储实现已存在时添加方法**：
```bash
Edit {ProjectName}.{ModuleName}.Repository/Repositories/{Entity}RepositoryImpl.cs
```

## 输出

仓储方法实现完成后输出摘要：

```markdown
## 仓储方法实现摘要

### 仓储
- **接口名称**：`I{Entity}Repository`
- **实现类名**：`{Entity}RepositoryImpl`
- **接口路径**：`{ProjectName}.{ModuleName}.Abstractions/Repositories/I{Entity}Repository.cs`
- **实现路径**：`{ProjectName}.{ModuleName}.Repository/Repositories/{Entity}RepositoryImpl.cs`

### 实现方法

| 方法名 | 返回类型 | 性能优化点 |
|--------|---------|-----------|
| `{MethodName}Async` | `Task<{ReturnType}>` | {优化描述} |

```

## 注意事项

1. **partial class/interface**：仓储使用 partial 定义，不要修改自动生成的部分
2. **async/await**：所有方法必须是异步的
3. **XML 注释**：仓储接口方法应包含 XML 注释
4. **参数验证**：仓储层不进行参数验证，由服务层负责
5. **性能优先**：实现的根本目的是优化性能，确保 SQL 高效
6. **禁止自定义存储过程**：MMB 框架禁止使用自定义存储过程，所有业务逻辑应在服务层实现。数据库自带的系统存储过程允许使用
7. **DTO 文件夹位置**：DTO 应按实体进行文件夹分类存放，路径为 `DTO/{EntityName}/{DtoName}.cs`，而非直接放在 DTO 根目录下
8. **异常处理**：仓储通常不进行异常处理，由服务层负责
