# MMB 框架核心接口参考

## IUnitOfWork - 工作单元接口

```csharp
public interface IUnitOfWork
{
    IServiceProvider ServiceProvider { get; }

    // 提交操作
    Task CommitAsync(bool setDetached = true);
    void Commit(bool setDetached = true);

    // 注册操作
    void RegisterAdd<TEntity, TPrimaryKeyType>(TEntity obj);
    void RegisterEdit<TEntity, TPrimaryKeyType>(TEntity obj);
    void RegisterDelete<TEntity, TPrimaryKeyType>(TEntity obj);

    // 获取仓储
    TRepository GetRepository<TRepository>() where TRepository : IRepository;
}
```

## IRepository - 仓储接口

```csharp
public interface IRepository<TEntity, TPrimaryKeyType> : IRepository
    where TEntity : class, IEntity<TPrimaryKeyType>
    where TPrimaryKeyType : struct
{
    // ========== 根据ID获取 ==========
    TEntity First(TPrimaryKeyType id);
    Task<TEntity> FirstAsync(TPrimaryKeyType id);
    TEntity? FirstOrDefault(TPrimaryKeyType id);
    Task<TEntity?> FirstOrDefaultAsync(TPrimaryKeyType id);

    // ========== 检查存在 ==========
    bool Existed(TPrimaryKeyType id);
    Task<bool> ExistedAsync(TPrimaryKeyType id);

    // ========== 条件查询 ==========
    TEntity? FirstOrDefault(Expression<Func<TEntity, bool>> expression);
    Task<TEntity?> FirstOrDefaultAsync(Expression<Func<TEntity, bool>> expression);
    TEntity First(Expression<Func<TEntity, bool>> expression);
    Task<TEntity> FirstAsync(Expression<Func<TEntity, bool>> expression);

    bool Existed(Expression<Func<TEntity, bool>> expression);
    Task<bool> ExistedAsync(Expression<Func<TEntity, bool>> expression);

    int Count(Expression<Func<TEntity, bool>> expression);
    Task<int> CountAsync(Expression<Func<TEntity, bool>> expression);

    // ========== 查询列表 ==========
    List<TEntity> Find(Expression<Func<TEntity, bool>> expression);
    Task<List<TEntity>> FindAsync(Expression<Func<TEntity, bool>> expression);

    List<TEntity> Find(Expression<Func<TEntity, bool>> expression,
        Expression<Func<TEntity, object>> orderExpression);
    Task<List<TEntity>> FindAsync(Expression<Func<TEntity, bool>> expression,
        Expression<Func<TEntity, object>> orderExpression);

    List<TEntity> Find(Expression<Func<TEntity, bool>> expression,
        Expression<Func<TEntity, object>> orderExpression, SortOrder sortOrder);
    Task<List<TEntity>> FindAsync(Expression<Func<TEntity, bool>> expression,
        Expression<Func<TEntity, object>> orderExpression, SortOrder sortOrder);

    // ========== 分页查询 ==========
    Task<(List<TEntity> data, PageModel pageInfo)> PagingAsync(PageRequestModel pageRequestModel);
    Task<(List<TEntity> data, PageModel pageInfo)> PagingAsync(
        PageRequestModel pageRequestModel, Expression<Func<TEntity, object>> orderExpression);
    Task<(List<TEntity> data, PageModel pageInfo)> PagingAsync(
        PageRequestModel pageRequestModel, Expression<Func<TEntity, object>> orderExpression, SortOrder sortOrder);

    Task<(List<TEntity> data, PageModel pageInfo)> PagingAsync(
        Expression<Func<TEntity, bool>> filterExpression, PageRequestModel pageRequestModel);
    Task<(List<TEntity> data, PageModel pageInfo)> PagingAsync(
        Expression<Func<TEntity, bool>> filterExpression, long pageIndex, long pageSize);

    // ========== 范围查询 ==========
    Task<(List<TEntity> data, RangeModel rangeInfo)> RangeAsync(RangeRequestModel rangeRequestModel);
    Task<(List<TEntity> data, RangeModel rangeInfo)> RangeAsync(
        RangeRequestModel rangeRequestModel, Expression<Func<TEntity, object>> orderExpression);
    Task<(List<TEntity> data, RangeModel rangeInfo)> RangeAsync(
        RangeRequestModel rangeRequestModel, Expression<Func<TEntity, object>> orderExpression, SortOrder sortOrder);

    Task<(List<TEntity> data, RangeModel rangeInfo)> RangeAsync(
        Expression<Func<TEntity, bool>> filterExpression, RangeRequestModel rangeRequestModel);
    Task<(List<TEntity> data, RangeModel rangeInfo)> RangeAsync(
        Expression<Func<TEntity, bool>> filterExpression, long skip, long take);
}
```

## BaseServiceImpl - 服务基类

```csharp
public abstract class BaseServiceImpl<TRepository, TDomain, TUnitOfWork>
{
    // 工作单元
    protected TUnitOfWork UnitOfWork { get; }

    // 默认仓储
    protected TRepository DefaultRepository { get; }

    // 登录用户ID
    public Guid LoginUserID { get; set; }

    // 映射器
    protected IMapper Mapper { get; }
}
```

## 仓储与工作单元的关系

1. **仓储**：负责查询操作（Read）
2. **工作单元**：负责写操作（Write）
3. **配合使用**：
   - 读取：使用 `DefaultRepository.FirstOrDefaultAsync()`
   - 写入：使用 `UnitOfWork.RegisterEdit()` + `CommitAsync()`
