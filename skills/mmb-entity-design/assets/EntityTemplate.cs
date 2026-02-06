namespace {ProjectName}.{ModuleName}.Abstractions.Domain;

/// <summary>
/// {实体描述}
/// </summary>
[QueryView(nameof({ViewName}))]
public class {EntityName} : BaseDomain, IDomain
{
    /// <summary>
    /// 名称
    /// </summary>
    [Required(ErrorMessage = "名称为空"), StringLength(50)]
    [Contains]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// 关联实体唯一标识
    /// </summary>
    [Required(ErrorMessage = "关联实体唯一标识为空")]
    [Equal]
    public Guid RelatedEntityID { get; set; }

    /// <summary>
    /// 状态
    /// </summary>
    [NotAdd, NotEdit]
    [Required(ErrorMessage = "状态为空")]
    [DTOText]
    public StatusType Status { get; set; }

    /// <summary>
    /// 有效标识
    /// </summary>
    [NotAdd, NotEdit]
    [Required(ErrorMessage = "有效标识为空")]
    [Equal]
    public bool IsValid { get; set; } = true;
}
