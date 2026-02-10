---
name: mmb-controller-impl
description: MMB (Materal.MergeBlock) 框架非标准 CRUD 控制器实现技能。用于在标准 CRUD 之外实现控制器层能力，并在两种路径间做决策：(1) 无需控制器特殊处理时，在服务接口方法上添加 [MapperController(MapperType.Xxx)] 并通过代码生成得到控制器；(2) 需要数据加工、聚合编排、文件流、特殊路由/鉴权等处理时，手写 IController 与 Controller 实现。适用于“新增非标准接口”“扩展现有控制器动作”“判断是否可走映射控制器生成”的场景。
---

# MMB 非标准 CRUD 控制器实现技能

按以下固定流程实现，优先基于仓库检索结果决策，不依赖猜测。

> **重要说明**：本技能仅处理**非标准 CRUD 控制器能力**，不处理标准 CRUD。

## 强制约束

1. 仅实现非标准 CRUD 控制器功能；标准 CRUD 控制器介入使用 `mmb-controller-crud-impl`（服务层标准 CRUD 使用 `mmb-service-crud-impl`）。
2. 禁止修改任何 `MGC` 目录下文件。
3. 修改前先检索项目内现有命名、路由、返回模型风格，保持一致。
4. 涉及异常处理时遵循 `mmb-exception-handling`。
5. `MapperControllerAttribute` 仅允许标记在服务接口方法上（`AttributeTargets.Method`），且必须传入 `MapperType`。
6. 若项目已启用全局默认鉴权，默认不要添加裸 `[Authorize]`；仅在“公开”或“策略升级”场景显式加特性。
7. Tree/Index 接口需要统一策略且生成代码不满足时，优先在实体上标记 `NotTreeController` / `NotIndexController` 后手写控制器，不用后置 Filter 打补丁。

## 使用边界

### 本技能处理

1. 标准 CRUD 之外的控制器动作新增或扩展（如重置密码、状态切换、个人中心、统计、文件流）。
2. 非标准接口的 `MapperController` 生成路径或手写控制器路径决策。
3. 非标准接口的控制器层特殊处理（聚合编排、流式响应、复杂参数绑定、特殊路由/鉴权）。

### 本技能不处理

1. 标准 CRUD 五类动作：获取列表、获取详情、添加、修改、删除。
2. 标准 CRUD 控制器方法重写与介入（转 `mmb-controller-crud-impl`）。
3. 标准 CRUD 服务实现（转 `mmb-service-crud-impl`）。

判定规则：优先按**操作语义**判断是否为标准 CRUD，任务编号仅作辅助，不作为硬约束。

## 命名约定

1. 使用 `{ProjectName}.{ModuleName}` 作为模块命名空间前缀。
2. 控制器基类命名使用 `{ModuleName}Controller`，例如模块 `Order` 对应 `OrderController`。

## 流程总览

```mermaid
flowchart TD
    A[读取功能需求] --> B[读取 IService 文件]
    B --> C{判断功能是否需要控制器层特殊处理\n数据加工/聚合/流式/特殊路由等}
    C -->|不需要特殊处理| D[在服务接口方法上添加 MapperController(MapperType.Xxx)]
    D --> M[编写请求模型]
    M --> F[生成代码]
    F --> I[结束流程]
    C -->|需要特殊处理| E[编写 IController 接口定义]
    E --> J[编写请求模型]
    J --> K[编写 Controller 实现]
    K --> I[结束流程]
```

## Step A-B：读取需求与服务接口

1. 读取功能需求，提取以下信息：
- 接口语义、输入字段、输出字段
- HTTP 动词和路由约束
- 是否存在跨服务编排、文件流、权限上下文依赖
2. 读取对应服务接口文件（通常在 `*.Abstractions/Services/`），确认目标服务方法是否已存在。
3. 若服务方法不存在，先配合 `mmb-service-impl` 完成服务接口与服务实现。

## Step C：是否需要控制器层特殊处理

满足任一条件，即判定为“需要特殊处理”：

1. 控制器需要做数据加工或聚合编排（不仅是一对一映射）。
2. 需要处理文件上传下载、流式响应、分块/长连接。
3. 需要自定义路由模板或复杂参数绑定（生成器默认只生成 `[HttpGet/Post/Put/Delete/Patch]`）。
4. 需要基于 Header/Cookie/Claim 做额外处理。
5. 需要返回与默认生成模式不一致的响应结构。
6. Tree/Index 生成控制器的鉴权粒度不满足需求，且需要统一策略声明。

若仅为“请求模型 -> 服务模型 -> 服务方法 -> 统一结果包装”直通调用，判定为“不需要特殊处理”。

## 分支 1：不需要特殊处理（MapperController 路径）

1. 在服务接口方法上添加 `[MapperController(MapperType.Xxx)]`：
- `MapperType.Get` -> `[HttpGet]`
- `MapperType.Post` -> `[HttpPost]`
- `MapperType.Put` -> `[HttpPut]`
- `MapperType.Delete` -> `[HttpDelete]`
- `MapperType.Patch` -> `[HttpPatch]`
2. 按需配置鉴权参数：
- 匿名：`[MapperController(MapperType.Get, IsAllowAnonymous = true)]`，生成 `[AllowAnonymous]`
- 策略：`[MapperController(MapperType.Get, Policy = "AdminOnly")]`，生成 `[Authorize(Policy = "AdminOnly")]`
- 当 `IsAllowAnonymous = true` 时，`Policy` 不生效
 - 若仅需默认登录态且项目已全局默认鉴权：不配置 `Policy`，也不在手写控制器里补裸 `[Authorize]`
3. 在 `*.Abstractions/RequestModel/{Entity}/` 编写请求模型。
4. 确保请求模型与服务方法入参映射可成立：
- 需要映射参数（`RequestName != Name`）会生成 `Mapper.Map`
- 其余参数按原类型直接透传
5. 明确返回包装规则（由生成器自动处理）：
- 服务方法 `Task` 或 `void` -> 控制器返回 `ResultModel`
- 服务方法 `Task<T>` 或 `T` -> 控制器返回 `ResultModel<T>`
- 服务方法返回分页元组 `(List<T> result, RangeModel rangeInfo)`（同步/异步）-> 控制器返回 `CollectionResultModel<T>`
6. 运行代码生成：

```bash
MMB GeneratorCode --ModulePath <模块路径>
```

7. 仅检查生成结果，不手改生成文件：
- `*.Abstractions/MGC/Controllers/I{Entity}Controller.Mapper.cs`
- `*.Application/MGC/Controllers/{Entity}Controller.Mapper.cs`

## 分支 2：需要特殊处理（手写控制器路径）

1. 在 `*.Abstractions/Controllers/` 新增或扩展 `I{Entity}Controller.cs`。
2. 在 `*.Abstractions/RequestModel/{Entity}/` 创建请求模型。
3. 在 `*.Application/Controllers/` 新增或扩展 `{Entity}Controller.cs`（`partial class`）。
4. 在控制器方法中执行：
- 请求参数校验
- 请求模型到服务模型映射（`Mapper.Map`）
- 调用 `DefaultService` 对应方法
- 返回 `ResultModel` / `ResultModel<T>` / `CollectionResultModel<T>`
5. 如映射规则无法靠约定自动完成，补充 `AutoMapperProfile`。
6. 对 Tree/Index 场景，若要手写控制器统一策略：
- 在实体上先标记 `NotTreeController` / `NotIndexController`
- 保留或抑制 Tree/Index 服务代码按业务决定（`NotTreeService` / `NotIndexService`）
- 运行生成器后，仅在非 MGC 控制器中实现对应动作与策略

控制器代码模板见：`references/controller-templates.md`

## 路径速查

1. 服务接口：`{ProjectName}.{ModuleName}\{ProjectName}.{ModuleName}.Abstractions\Services\`
2. 请求模型：`{ProjectName}.{ModuleName}\{ProjectName}.{ModuleName}.Abstractions\RequestModel\{Entity}\`
3. 控制器接口：`{ProjectName}.{ModuleName}\{ProjectName}.{ModuleName}.Abstractions\Controllers\`
4. 控制器实现：`{ProjectName}.{ModuleName}\{ProjectName}.{ModuleName}.Application\Controllers\`

需要精确路径时，使用 `mmb-path-resolver`。

## 完成检查

1. 非标准接口流程是否按分支实现完成。
2. 是否未修改任何 `MGC` 文件。
3. 是否已运行生成器（MapperController 路径必需）。
4. 是否补齐必要 `using`、命名空间、返回模型和异常处理。
5. 是否避免无必要裸 `[Authorize]`（默认鉴权项目中）。
6. Tree/Index 统一策略场景是否优先采用 `NotTreeController` / `NotIndexController` + 手写控制器。
7. 是否通过编译验证（至少模块级 `dotnet build`）。
