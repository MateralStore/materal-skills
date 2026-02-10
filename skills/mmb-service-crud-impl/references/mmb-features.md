# MMB 框架特性详解

## 数据操作特性

### NotAdd - 添加时排除

用于指定字段在添加操作时不由前端传入，由后端自动设置。

**判断标准：前端是否需要传入这个值？**
- **不需要** → 使用 `[NotAdd]`，在服务实现中设置默认值
- **需要** → 不使用 `[NotAdd]`，即使需要后端处理（如加密）

**适用场景：**
- `Status` - 新用户默认为启用（前端不传，后端设置默认值）
- `LastLoginTime` - 新用户未登录过（前端不传，后端自动设置）
- `CreateTime`/`UpdateTime` - 系统自动管理（前端不传）

**常见错误：**
- ❌ `Password` 使用 `[NotAdd]` - 虽然需要加密，但前端必须传入初始密码
- ✅ `Password` 不使用 `[NotAdd]` - 在服务实现的 `AddAsync` 方法中加密处理

### NotEdit - 修改时排除

用于指定字段在修改操作时不允许修改。

**判断标准：这个字段是否可以通过标准修改接口修改？**
- **不可以** → 使用 `[NotEdit]`，需要通过专门接口修改
- **可以** → 不使用 `[NotEdit]`

**适用场景：**
- `Account` - 账号唯一标识，创建后不应修改
- `Password` - 密码通过专门的修改密码接口修改，不在标准修改接口中处理
- `Role` - 角色变更需要专门的审批或授权流程
- `Status` - 状态通过专门的启用/停用接口修改
- `LastLoginTime` - 由系统自动更新，不应手动修改

### NotDTO / NotListDTO - DTO 排除

用于指定字段不在返回的 DTO 中暴露。

**适用场景：**
- `Password` - 敏感信息，不返回给前端

## 查询特性

### 精准匹配类

| 特性 | 数据类型要求 | 示例 |
|------|-------------|------|
| `[Equal]` | 任意 | 按账号、手机号、角色、状态筛选 |
| `[NotEqual]` | 任意 | 排除特定状态的数据 |

### 范围比较类

| 特性 | 数据类型要求 | 示例 |
|------|-------------|------|
| `[GreaterThan]` | 可比较类型 | 创建时间大于某日期 |
| `[LessThan]` | 可比较类型 | 创建时间小于某日期 |
| `[GreaterThanOrEqual]` | 可比较类型 | 创建时间大于等于某日期 |
| `[LessThanOrEqual]` | 可比较类型 | 创建时间小于等于某日期 |
| `[Between]` | 可比较类型 | 日期范围查询 |

### 字符串匹配类

| 特性 | 说明 | 示例 |
|------|------|------|
| `[Contains]` | 包含指定字符串 | 按姓名模糊搜索 |
| `[StartContains]` | 以指定字符串开始 | 按前缀筛选 |
| `[EndContains]` | 以指定字符串结束 | 按后缀筛选（如文件扩展名） |

## 特性组合示例

```csharp
public partial class User : BaseDomain
{
    // 账号：不可修改、精准查询
    [Required]
    [MaxLength(50)]
    [NotEdit]
    [Equal]
    public string Account { get; set; } = string.Empty;

    // 密码：前端传入、需要加密、不可修改、不暴露在 DTO
    // 注意：不使用 [NotAdd]，因为添加时前端需要传入初始密码
    // 在服务实现的 AddAsync 方法中处理加密
    [Required]
    [MaxLength(100)]
    [NotEdit]
    [NotDTO]
    [NotListDTO]
    public string Password { get; set; } = string.Empty;

    // 姓名：可修改、模糊查询
    [Required]
    [MaxLength(50)]
    [Contains]
    public string Name { get; set; } = string.Empty;

    // 状态：添加时自动设置、不可修改、精准查询
    [Required]
    [NotAdd]      // 前端不传，后端设置默认值为 Enabled
    [NotEdit]     // 通过专门的启用/停用接口修改
    [Equal]
    public UserStatus Status { get; set; }

    // 最后登录时间：添加时自动设置、不可修改
    [NotAdd]      // 新用户未登录过，设为 null
    [NotEdit]     // 由系统在登录时自动更新
    public DateTime? LastLoginTime { get; set; }
}
```
