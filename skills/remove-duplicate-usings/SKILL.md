---
name: remove-duplicate-usings
description: 移除 C# 文件中与 GlobalUsings.cs 重复的 using 语句。接收一个或多个 .cs 文件路径作为输入，自动查找同一项目目录下的 GlobalUsings.cs 文件，比较并移除文件中已经在全局 using 声明的命名空间导入。适用于：(1) 清理项目中的冗余 using 语句，(2) 代码重构后的 using 整理，(3) 确保代码风格一致性。
---

# 移除重复 Using 语句

## 工作流程

1. **定位 GlobalUsings.cs 文件**
   - 从输入文件路径向上查找，找到所在的项目根目录（包含 `.csproj` 文件的目录）
   - 在该目录中查找 `GlobalUsings.cs` 文件
   - 支持多个项目模块（如 {Project}.{Module}.Abstractions、{Project}.Core.Abstractions 等）

2. **解析 GlobalUsings 内容**
   - 读取 GlobalUsings.cs 文件
   - 提取所有 `global using` 后的命名空间
   - 忽略空行和注释

3. **处理目标文件**
   - 读取目标 .cs 文件
   - 识别文件顶部的 `using` 语句
   - 与 GlobalUsings 中的命名空间进行比较
   - 移除重复的 using 语句

4. **更新文件**
   - 保持文件其他内容不变
   - 保留文件编码和 BOM
   - 确保 using 语句区域格式正确

## 使用方法

### 单文件处理
```
处理文件 {Project}.{Module}/{Project}.{Module}.Abstractions/Do{Module}/Flowchart.cs
```

### 多文件处理
```
处理以下文件中的重复 using：
- {Project}.{Module}/{Project}.{Module}.Abstractions/Do{Module}/Flowchart.cs
- {Project}.{Module}/{Project}.{Module}.Abstractions/Do{Module}/NodeKnowledge.cs
- {Project}.Core/{Project}.Core.Abstractions/Services/ISampleService.cs
```

## 命名空间比较规则

- **完全匹配**：`using System.ComponentModel.DataAnnotations;` 与 `global using System.ComponentModel.DataAnnotations;` 匹配
- **大小写敏感**：C# 命名空间区分大小写
- **忽略尾部分号**：比较时自动处理分号差异

## 注意事项

- 不会移除 `static using` 或 `alias using`（如 `using static Math`、`using Alias = Namespace.Class`）
- 保留所有非重复的 using 语句
- 如果文件没有 using 语句，不进行任何修改
- 自动保留文件中的注释和空行（除非与被移除的 using 位于同一行）

## 示例

**输入文件 Flowchart.cs：**
```csharp
using System.ComponentModel.DataAnnotations;
using Microsoft.Extensions.Logging;

namespace {Project}.{Module}.Abstractions.Do{Module};

public class Flowchart { }
```

**GlobalUsings.cs 包含：**
```csharp
global using System.ComponentModel.DataAnnotations;
global using Materal.MergeBlock.Abstractions;
```

**处理后的 Flowchart.cs：**
```csharp
using Microsoft.Extensions.Logging;

namespace {Project}.{Module}.Abstractions.Do{Module};

public class Flowchart { }
```
