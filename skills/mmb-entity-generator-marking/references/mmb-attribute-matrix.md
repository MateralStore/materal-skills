# MMB 特性对照表

本文件给出本技能依赖的最小特性语义。

## 类级特性

| 特性 | 作用 | 典型场景 |
|------|------|---------|
| `EmptyController` | 生成空白控制器，不生成标准 CRUD 方法 | 实体需要自定义接口，不走标准 CRUD |
| `EmptyService` | 生成空白服务，不生成标准 CRUD 方法 | 服务只保留基础结构，方法手写 |
| `NotController` | 完全不生成控制器 | 关系实体/内部实体不暴露 API |
| `NotService` | 完全不生成服务 | 关系实体/内部实体不需要独立服务 |
| `NotAdd` | 整个实体不生成添加模型 | 不需要生成标准的添加模型时 |
| `NotEdit` | 整个实体不生成修改模型 | 不需要生成标准的修改模型时 |
| `NotQuery` | 整个实体不生成查询模型 | 不需要生成标准的查询模型时 |
| `NotTreeController` | 不生成 Tree 控制器代码 | Tree 接口需手写控制器统一策略 |
| `NotTreeService` | 不生成 Tree 服务代码 | Tree 服务需完全手写或禁用 |
| `NotTreeDTO` | 不生成 Tree DTO 代码 | 不需要 Tree DTO 结构 |
| `NotTreeRepository` | 不生成 Tree 仓储代码 | 不需要 Tree 仓储扩展 |
| `NotIndexController` | 不生成 Index 控制器代码 | Index 接口需手写控制器统一策略 |
| `NotIndexService` | 不生成 Index 服务代码 | Index 服务需完全手写或禁用 |
| `NotIndexRepository` | 不生成 Index 仓储代码 | 不需要 Index 仓储扩展 |

## 属性级特性

| 特性 | 作用 |
|------|------|
| `NotAdd` | 该属性不进入添加模型 |
| `NotEdit` | 该属性不进入修改模型 |
| `NotQuery` | 该属性不进入查询模型 |

## 关键规则

- `Empty*` 与 `Not*` 在同一语义层面互斥，按实体类型择一使用。
- 当实体整体不需要 Add/Edit/Query 模型时，优先使用类级 `NotAdd`/`NotEdit`/`NotQuery`。
- 需要手写 Tree/Index 控制器统一鉴权时，优先使用 `NotTreeController`/`NotIndexController` 抑制生成，而不是在生成控制器外层叠加过滤器补丁。
- 仅替换控制器时不要误加 `NotTreeService`/`NotIndexService`，避免连服务能力一起被抑制。

## 本地检索来源

可在本地 NuGet XML 文档中检索以下成员确认语义：

- `T:Materal.MergeBlock.GeneratorCode.Attributers.EmptyControllerAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.EmptyServiceAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotControllerAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotServiceAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotAddAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotEditAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotQueryAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotTreeControllerAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotTreeServiceAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotTreeDTOAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotTreeRepositoryAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotIndexControllerAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotIndexServiceAttribute`
- `T:Materal.MergeBlock.GeneratorCode.Attributers.NotIndexRepositoryAttribute`