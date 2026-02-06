# MMB 框架仓储方法参考

> MMB 框架仓储基类提供了丰富的默认方法，大多数场景下无需自定义仓储方法。

**注意**：MMB 框架中方法命名可能与示例略有不同，请以实际框架定义为准。

---

## 目录

- [存在性检查](#存在性检查)
- [数量统计](#数量统计)
- [查询单条记录](#查询单条记录)
- [查询列表](#查询列表)
- [分页查询](#分页查询)
- [范围查询](#范围查询)
- [缓存相关方法](#缓存相关方法)
- [使用示例](#使用示例)

---

## 存在性检查

| 方法 | 说明 | 同步/异步 | 示例 |
|------|------|-----------|------|
| `Existed(id)` | 按 ID 检查是否存在 | 同步 | `DefaultRepository.Existed(id)` |
| `ExistedAsync(id)` | 按 ID 检查是否存在 | 异步 | `await DefaultRepository.ExistedAsync(id)` |
| `Existed(expression)` | 按表达式检查是否存在 | 同步 | `DefaultRepository.Existed(u => u.UserName == name)` |
| `ExistedAsync(expression)` | 按表达式检查是否存在 | 异步 | `await DefaultRepository.ExistedAsync(u => u.UserName == name)` |
| `Existed(filterModel)` | 按 FilterModel 检查是否存在 | 同步 | `DefaultRepository.Existed(filterModel)` |
| `ExistedAsync(filterModel)` | 按 FilterModel 检查是否存在 | 异步 | `await DefaultRepository.ExistedAsync(filterModel)` |

---

## 数量统计

| 方法 | 说明 | 同步/异步 | 示例 |
|------|------|-----------|------|
| `Count(expression)` | 按表达式统计数量 | 同步 | `DefaultRepository.Count(u => u.IsEnabled)` |
| `CountAsync(expression)` | 按表达式统计数量 | 异步 | `await DefaultRepository.CountAsync(u => u.IsEnabled)` |
| `Count(filterModel)` | 按 FilterModel 统计数量 | 同步 | `DefaultRepository.Count(filterModel)` |
| `CountAsync(filterModel)` | 按 FilterModel 统计数量 | 异步 | `await DefaultRepository.CountAsync(filterModel)` |

---

## 查询单条记录

| 方法 | 说明 | 同步/异步 | 返回值 | 示例 |
|------|------|-----------|--------|------|
| `FirstOrDefault(id)` | 按 ID 查询 | 同步 | 可空 | `DefaultRepository.FirstOrDefault(id)` |
| `FirstOrDefaultAsync(id)` | 按 ID 查询 | 异步 | 可空 | `await DefaultRepository.FirstOrDefaultAsync(id)` |
| `FirstOrDefault(expression)` | 按表达式查询第一条 | 同步 | 可空 | `DefaultRepository.FirstOrDefault(u => u.UserName == name)` |
| `FirstOrDefaultAsync(expression)` | 按表达式查询第一条 | 异步 | 可空 | `await DefaultRepository.FirstOrDefaultAsync(u => u.UserName == name)` |
| `FirstOrDefault(filterModel)` | 按 FilterModel 查询第一条 | 同步 | 可空 | `DefaultRepository.FirstOrDefault(filterModel)` |
| `FirstOrDefaultAsync(filterModel)` | 按 FilterModel 查询第一条 | 异步 | 可空 | `await DefaultRepository.FirstOrDefaultAsync(filterModel)` |
| `First(id)` | 按 ID 查询 | 同步 | 必须存在 | `DefaultRepository.First(id)` |
| `FirstAsync(id)` | 按 ID 查询 | 异步 | 必须存在 | `await DefaultRepository.FirstAsync(id)` |
| `First(expression)` | 按表达式查询第一条 | 同步 | 必须存在 | `DefaultRepository.First(u => u.UserName == name)` |
| `FirstAsync(expression)` | 按表达式查询第一条 | 异步 | 必须存在 | `await DefaultRepository.FirstAsync(u => u.UserName == name)` |

---

## 查询列表

| 方法 | 说明 | 同步/异步 | 示例 |
|------|------|-----------|------|
| `Find(expression)` | 按表达式查询列表 | 同步 | `DefaultRepository.Find(u => u.Status == UserStatus.Enabled)` |
| `FindAsync(expression)` | 按表达式查询列表 | 异步 | `await DefaultRepository.FindAsync(u => u.Status == UserStatus.Enabled)` |
| `Find(expression, orderExpression)` | 带排序查询 | 同步 | `DefaultRepository.Find(u => u.IsEnabled, u => u.CreateTime)` |
| `FindAsync(expression, orderExpression)` | 带排序查询 | 异步 | `await DefaultRepository.FindAsync(u => u.IsEnabled, u => u.CreateTime)` |
| `Find(expression, orderExpression, sortOrder)` | 带排序和排序方式查询 | 同步 | `DefaultRepository.Find(u => u.IsEnabled, u => u.CreateTime, SortOrder.Descending)` |
| `FindAsync(expression, orderExpression, sortOrder)` | 带排序和排序方式查询 | 异步 | `await DefaultRepository.FindAsync(u => u.IsEnabled, u => u.CreateTime, SortOrder.Descending)` |
| `Find(filterModel)` | 按 FilterModel 查询 | 同步 | `DefaultRepository.Find(filterModel)` |
| `FindAsync(filterModel)` | 按 FilterModel 查询 | 异步 | `await DefaultRepository.FindAsync(filterModel)` |

---

## 分页查询

| 方法 | 说明 | 同步/异步 | 示例 |
|------|------|-----------|------|
| `Paging(pageRequestModel)` | 基础分页 | 同步 | `DefaultRepository.Paging(pageModel)` |
| `PagingAsync(pageRequestModel)` | 基础分页 | 异步 | `await DefaultRepository.PagingAsync(pageModel)` |
| `Paging(expression, pageRequestModel)` | 带过滤分页 | 同步 | `DefaultRepository.Paging(u => u.IsEnabled, pageModel)` |
| `PagingAsync(expression, pageRequestModel)` | 带过滤分页 | 异步 | `await DefaultRepository.PagingAsync(u => u.IsEnabled, pageModel)` |
| `Paging(expression, orderExpression, sortOrder, pageIndex, pageSize)` | 完整参数分页 | 同步 | `DefaultRepository.Paging(u => u.IsEnabled, u => u.CreateTime, SortOrder.Descending, 1, 20)` |
| `PagingAsync(expression, orderExpression, sortOrder, pageIndex, pageSize)` | 完整参数分页 | 异步 | `await DefaultRepository.PagingAsync(u => u.IsEnabled, u => u.CreateTime, SortOrder.Descending, 1, 20)` |

**返回值**：`(List<TEntity> data, PageModel pageInfo)` 或 `(long count, List<TEntity> data)`

---

## 范围查询（Range）

| 方法 | 说明 | 同步/异步 | 示例 |
|------|------|-----------|------|
| `Range(rangeRequestModel)` | 基础范围查询 | 同步 | `DefaultRepository.Range(rangeModel)` |
| `RangeAsync(rangeRequestModel)` | 基础范围查询 | 异步 | `await DefaultRepository.RangeAsync(rangeModel)` |
| `Range(expression, skip, take)` | 带过滤范围查询 | 同步 | `DefaultRepository.Range(u => u.IsEnabled, 0, 20)` |
| `RangeAsync(expression, skip, take)` | 带过滤范围查询 | 异步 | `await DefaultRepository.RangeAsync(u => u.IsEnabled, 0, 20)` |
| `Range(expression, orderExpression, sortOrder, skip, take)` | 完整参数范围查询 | 同步 | `DefaultRepository.Range(u => u.IsEnabled, u => u.CreateTime, SortOrder.Descending, 0, 20)` |
| `RangeAsync(expression, orderExpression, sortOrder, skip, take)` | 完整参数范围查询 | 异步 | `await DefaultRepository.RangeAsync(u => u.IsEnabled, u => u.CreateTime, SortOrder.Descending, 0, 20)` |

**返回值**：`(List<TEntity> data, RangeModel rangeInfo)`

---

## 缓存相关方法（ICacheRepository）

> 如果仓储实现了 `ICacheRepository<T>` 接口，还可使用以下缓存方法：

| 方法 | 说明 | 同步/异步 | 示例 |
|------|------|-----------|------|
| `GetAllInfoFromCache()` | 从缓存获取所有数据 | 同步 | `DefaultRepository.GetAllInfoFromCache()` |
| `GetAllInfoFromCacheAsync()` | 从缓存获取所有数据 | 异步 | `await DefaultRepository.GetAllInfoFromCacheAsync()` |
| `GetInfoFromCache(key)` | 从缓存获取指定数据 | 同步 | `DefaultRepository.GetInfoFromCache("cacheKey")` |
| `GetInfoFromCacheAsync(key)` | 从缓存获取指定数据 | 异步 | `await DefaultRepository.GetInfoFromCacheAsync("cacheKey")` |
| `ClearAllCache()` | 清空所有缓存 | 同步 | `DefaultRepository.ClearAllCache()` |
| `ClearAllCacheAsync()` | 清空所有缓存 | 异步 | `await DefaultRepository.ClearAllCacheAsync()` |
| `ClearCache(key)` | 清空指定缓存 | 同步 | `DefaultRepository.ClearCache("cacheKey")` |
| `ClearCacheAsync(key)` | 清空指定缓存 | 异步 | `await DefaultRepository.ClearCacheAsync("cacheKey")` |

---

## 使用示例

```csharp
// 示例1：检查用户名是否存在
if (await DefaultRepository.ExistedAsync(u => u.UserName == model.UserName))
{
    throw new ZhiTuException("用户名已存在");
}

// 示例2：按 ID 查询用户
User user = await DefaultRepository.FirstOrDefaultAsync(id)
    ?? throw new ZhiTuException($"用户不存在：{id}");

// 示例3：查询启用的用户列表
List<User> users = await DefaultRepository.FindAsync(u => u.IsEnabled);

// 示例4：查询启用的用户并按创建时间降序排序
List<User> users = await DefaultRepository.FindAsync(
    u => u.IsEnabled,
    u => u.CreateTime,
    SortOrder.Descending);

// 示例5：分页查询
PagingModel<User> pageModel = _mapper.Map<PagingModel<User>>(model);
(List<User> data, PageModel pageInfo) = await DefaultRepository.PagingAsync(pageModel);

// 示例6：使用范围查询（Range）
(List<User> data, RangeModel rangeInfo) = await DefaultRepository.RangeAsync(
    u => u.IsEnabled,
    u => u.CreateTime,
    SortOrder.Descending,
    0,
    20);

// 示例7：使用缓存仓储（如果实现了 ICacheRepository）
List<User> allUsers = await DefaultRepository.GetAllInfoFromCacheAsync();
await DefaultRepository.ClearAllCacheAsync();

// 示例8：统计启用的用户数量
long enabledCount = await DefaultRepository.CountAsync(u => u.IsEnabled);

// 示例9：检查数据是否存在
bool exists = await DefaultRepository.ExistedAsync(someId);
```

---

## 快速查找指南

| 需求 | 推荐方法 | 页内链接 |
|------|----------|----------|
| 检查数据是否存在 | `ExistedAsync(id)` 或 `ExistedAsync(expression)` | [存在性检查](#存在性检查) |
| 统计数量 | `CountAsync(expression)` | [数量统计](#数量统计) |
| 查询单条数据 | `FirstOrDefaultAsync(id)` 或 `FirstOrDefaultAsync(expression)` | [查询单条记录](#查询单条记录) |
| 查询列表 | `FindAsync(expression)` | [查询列表](#查询列表) |
| 分页查询 | `PagingAsync(pageRequestModel)` | [分页查询](#分页查询) |
| 范围查询 | `RangeAsync(...)` | [范围查询](#范围查询) |
| 缓存操作 | `GetAllInfoFromCacheAsync()` 等 | [缓存相关方法](#缓存相关方法) |
