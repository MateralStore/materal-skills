# BaseServiceImpl 源码参考

本文档包含 BaseServiceImpl 的源码，用于查阅所有可重写的方法签名和默认实现。

## 查找可重写的方法

搜索 `virtual` 关键字即可找到所有可重写的方法。

## 标准版本 BaseServiceImpl

```csharp
/// <summary>
/// 基础服务实现
/// </summary>
/// <typeparam name="TAddModel">添加模型</typeparam>
/// <typeparam name="TEditModel">修改模型</typeparam>
/// <typeparam name="TQueryModel">查询模型</typeparam>
/// <typeparam name="TDTO">详情DTO</typeparam>
/// <typeparam name="TListDTO">列表DTO</typeparam>
/// <typeparam name="TRepository">仓储</typeparam>
/// <typeparam name="TDomain">实体</typeparam>
/// <typeparam name="TUnitOfWork">工作单元</typeparam>
public abstract class BaseServiceImpl<TAddModel, TEditModel, TQueryModel, TDTO, TListDTO, TRepository, TDomain, TUnitOfWork>
    where TAddModel : class, IAddServiceModel, new()
    where TEditModel : class, IEditServiceModel, new()
    where TQueryModel : PageRequestModel, IQueryServiceModel, new()
    where TDTO : class, IDTO
    where TListDTO : class, IListDTO
    where TRepository : class, IEFRepository<TDomain, Guid>, IRepository
    where TDomain : class, IDomain, new()
    where TUnitOfWork : IMergeBlockUnitOfWork
{
    // ==================== 添加操作 ====================

    /// <summary>
    /// 添加 - 接收模型，映射为实体后调用重载方法
    /// </summary>
    public virtual async Task<Guid> AddAsync(TAddModel model)
    {
        TDomain domain = Mapper.Map<TDomain>(model) ?? throw new MergeBlockException("映射失败");
        return await AddAsync(domain, model);
    }

    /// <summary>
    /// 添加 - 处理位序、注册添加、提交工作单元
    /// 重写此方法可完全控制添加流程
    /// </summary>
    protected virtual async Task<Guid> AddAsync(TDomain domain, TAddModel model)
    {
        // 处理 IIndexDomain 位序
        if (domain is IIndexDomain indexDomain)
        {
            // 获取最大位序并设置
        }
        UnitOfWork.RegisterAdd(domain);
        await UnitOfWork.CommitAsync();
        await ClearCacheAsync();
        return domain.ID;
    }

    // ==================== 删除操作 ====================

    /// <summary>
    /// 删除 - 根据ID获取实体后删除
    /// </summary>
    public virtual async Task DeleteAsync(Guid id)
    {
        TDomain domainFromDB = await DefaultRepository.FirstOrDefaultAsync(id)
            ?? throw new MergeBlockModuleException("数据不存在");
        await DeleteAsync(domainFromDB);
    }

    /// <summary>
    /// 删除 - 注册删除、提交工作单元
    /// 重写此方法可实现软删除
    /// </summary>
    protected virtual async Task DeleteAsync(TDomain domain)
    {
        UnitOfWork.RegisterDelete(domain);
        await UnitOfWork.CommitAsync();
        await ClearCacheAsync();
    }

    // ==================== 修改操作 ====================

    /// <summary>
    /// 修改 - 根据ID获取实体、映射修改、提交
    /// </summary>
    public virtual async Task EditAsync(TEditModel model)
    {
        TDomain domainFromDB = await DefaultRepository.FirstOrDefaultAsync(model.ID)
            ?? throw new MergeBlockModuleException("数据不存在");
        Mapper.Map(model, domainFromDB);
        await EditAsync(domainFromDB, model);
    }

    /// <summary>
    /// 修改 - 注册修改、提交工作单元
    /// 重写此方法可添加修改前的验证或处理
    /// </summary>
    protected virtual async Task EditAsync(TDomain domainFromDB, TEditModel model)
    {
        UnitOfWork.RegisterEdit(domainFromDB);
        await UnitOfWork.CommitAsync();
        await ClearCacheAsync();
    }

    // ==================== 获取详情 ====================

    /// <summary>
    /// 获取信息 - 根据ID获取实体
    /// </summary>
    public virtual async Task<TDTO> GetInfoAsync(Guid id)
    {
        TDomain domainFromDB = await DefaultRepository.FirstOrDefaultAsync(id)
            ?? throw new MergeBlockModuleException("数据不存在");
        return await GetInfoAsync(domainFromDB);
    }

    /// <summary>
    /// 获取信息 - 将实体映射为DTO
    /// </summary>
    protected virtual async Task<TDTO> GetInfoAsync(TDomain domain)
    {
        TDTO result = Mapper.Map<TDTO>(domain) ?? throw new MergeBlockException("映射失败");
        return await GetInfoAsync(result);
    }

    /// <summary>
    /// 获取信息 - DTO后处理（默认直接返回）
    /// 重写此方法可在DTO返回前进行格式化或过滤
    /// </summary>
    protected virtual Task<TDTO> GetInfoAsync(TDTO dto) => Task.FromResult(dto);

    // ==================== 获取列表 ====================

    /// <summary>
    /// 获取列表 - 根据查询模型获取
    /// </summary>
    public virtual async Task<(List<TListDTO> data, RangeModel rangeInfo)> GetListAsync(TQueryModel model)
    {
        Expression<Func<TDomain, bool>> expression = model.GetSearchExpression<TDomain>();
        expression = ServiceImplHelper.GetSearchTreeDomainExpression(expression, model);
        return await GetListAsync(expression, model);
    }

    /// <summary>
    /// 获取列表 - 执行查询、映射DTO
    /// </summary>
    protected virtual async Task<(List<TListDTO> data, RangeModel rangeInfo)> GetListAsync(
        Expression<Func<TDomain, bool>> expression, TQueryModel model,
        Expression<Func<TDomain, object>>? orderExpression = null,
        SortOrder sortOrder = SortOrder.Descending)
    {
        if (orderExpression == null)
        {
            (orderExpression, sortOrder) = GetDefaultOrderInfo<TDomain>(model);
        }
        (List<TDomain> data, RangeModel pageModel) = await DefaultRepository.RangeAsync(expression, orderExpression, sortOrder, model);
        List<TListDTO> result = Mapper.Map<List<TListDTO>>(data) ?? throw new MergeBlockException("映射失败");
        return await GetListAsync(result, pageModel, model);
    }

    /// <summary>
    /// 获取列表 - DTO后处理（默认直接返回）
    /// 重写此方法可对DTO列表进行批量处理
    /// </summary>
    protected virtual Task<(List<TListDTO> data, RangeModel rangeInfo)> GetListAsync(
        List<TListDTO> listDto, RangeModel rangeInfo, TQueryModel model)
    {
        return Task.FromResult((listDto, rangeInfo));
    }

    // ==================== 缓存管理 ====================

    /// <summary>
    /// 清空缓存 - 指定仓储
    /// </summary>
    protected virtual async Task ClearCacheAsync(object targetRepository)
    {
        if (targetRepository is not ICacheRepository<TDomain> cacheRepository) return;
        await cacheRepository.ClearAllCacheAsync();
    }

    /// <summary>
    /// 清空缓存 - 默认仓储
    /// </summary>
    protected virtual async Task ClearCacheAsync()
    {
        await ClearCacheAsync(DefaultRepository);
    }
}
```

## 带视图仓储版本

如果有视图仓储（ViewRepository），会额外提供以下方法：

```csharp
/// <summary>
/// 从视图仓储获取信息
/// </summary>
protected virtual async Task<TDTO> GetInfoAsync(TViewDomain domain)
{
    TDTO result = Mapper.Map<TDTO>(domain) ?? throw new MergeBlockException("映射失败");
    return await GetInfoAsync(result);
}

/// <summary>
/// 从视图仓储获取列表
/// </summary>
protected virtual async Task<(List<TListDTO> data, RangeModel rangeInfo)> GetViewListAsync(
    Expression<Func<TViewDomain, bool>> expression, TQueryModel model,
    Expression<Func<TViewDomain, object>>? orderExpression = null,
    SortOrder sortOrder = SortOrder.Descending)
{
    // 类似 GetListAsync，但使用视图仓储
}
```

## 重写方法的选择指南

| 需求 | 推荐重写方法 | 原因 |
|------|-------------|------|
| 数据验证、数据处理 | `AddAsync(TAddModel)` | 在映射后、添加前介入 |
| 软删除 | `DeleteAsync(TDomain)` | 完全控制删除行为 |
| 删除前验证 | `DeleteAsync(Guid id)` | 在获取实体后、删除前验证 |
| DTO 格式化 | `GetInfoAsync(TDTO)` | 在DTO返回前处理 |
| DTO 批量处理 | `GetListAsync(List, ...)` | 对列表中每个DTO处理 |
| 自定义缓存清理 | `ClearCacheAsync()` | 添加额外的缓存清理逻辑 |
