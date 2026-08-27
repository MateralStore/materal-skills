---
name: browser-debugging-and-control
description: Diagnose and recover browser-control access on Windows. For local Web debugging, prefer a dedicated Chrome DevTools (CDP) endpoint and isolated profile; use the Chrome plugin only when the task needs the user's real Chrome context.
---

# 浏览器调试链路诊断

## 边界

本技能负责选择并诊断浏览器控制链路，不定义 Codex Browser/Chrome 连接器的内部 API。当前会话提供 Browser 或 Chrome 插件时，仍须读取并遵循其技能说明；本技能不能覆盖更高优先级的连接器规则。

- 本地 Web 项目的调试、问题复现、控制台/网络/DOM 检查和自动化验证，优先使用独立 Profile 的 Chrome DevTools endpoint（默认端口 `9222`）。
- 只有任务明确依赖用户现有 Chrome Profile、登录态、企业 SSO、客户端证书或既有扩展时，才优先使用 Chrome 插件；它用于真实用户环境验证，不是常规调试默认项。
- 内置浏览器用于公开网页、轻量查看和低风险只读检查，不替代复杂本地应用调试或真实登录环境验证。
- 若当前会话没有实际可调用的 CDP/MCP 客户端，`/json/version` 可访问只表示端点存在。必须说明无法附加控制的原因，再按任务需要降级到 Chrome 插件或内置浏览器。
- `http://127.0.0.1:<port>/json/version` 可访问，只证明 CDP 端点存在，不证明当前会话已经拥有可调用的 CDP/MCP 客户端。
- 没有可调用的 CDP/MCP 客户端时，只报告端点状态，不宣称可以读取控制台、检查 DOM 或点击页面。

## 选择路径

1. 先判断任务类型：本地调试/自动化验证、真实用户环境验证，还是公开页面的轻量检查。
2. 对本地调试/自动化验证，检查 `http://127.0.0.1:9222/json/version`；端点不可用时启动独立调试 Chrome，再确认当前会话是否实际提供 CDP/MCP 客户端。
3. 对真实用户环境验证，检查当前会话是否提供 Chrome 插件，并按其当前技能说明完成浏览器选择、标签页获取和页面操作；不要复制或猜测其内部 API。
4. 对公开页面的轻量检查，使用内置浏览器；若用户明确指定 Chrome、Edge、内置浏览器或其他浏览器，遵守该选择，不静默切换。
5. 当前首选路径不可用时，说明阻塞点和降级原因，再选择满足任务边界的下一条路径。
6. 涉及提交、删除、付款、发布或真实数据变更时，在最终动作前获得用户确认。

## CDP 调试路径

1. 验证端点：

```powershell
(Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:9222/json/version').Content
```

2. 端点不可用时，启动独立调试 Chrome：

```powershell
& ".\scripts\start-chrome-devtools-endpoint.ps1"
```

脚本支持自定义 Chrome、端口和专用配置目录：

```powershell
& ".\scripts\start-chrome-devtools-endpoint.ps1" `
  -ChromePath "<chrome.exe>" `
  -DebugPort 9223 `
  -ProfilePath "$env:LOCALAPPDATA\chrome-devtools-profile-9223"
```

3. 在独立调试 Chrome 中打开目标页面，再确认页面目标存在：

```powershell
(Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:9222/json/list').Content
```

4. 只有当前会话实际提供 CDP/MCP 客户端时，才能连接目标页的 `webSocketDebuggerUrl`。按 URL 和标题核对页面，忽略无关的扩展页、worker 与 service worker；否则报告端点已就绪但当前会话无法附加，并按选择路径降级。
5. 附加客户端后再复现控制台问题；历史 `console` 输出可能无法补取。
6. 操作页面时，先核对 URL、可见文字和目标元素语义。临时样式或脚本注入必须在汇报中说明是否仍然保留。

## 安全规则

- 调试端点只绑定 `127.0.0.1`，不要暴露到局域网或公网。
- 使用独立 Chrome 配置目录，避免把日常浏览器资料带入调试实例。
- 不读取与任务无关的 Cookie、密码、令牌、本地存储或浏览历史。
- 不把“端点存在”“发现标签页”和“页面可控”混为同一个状态。

## 成功标准

Chrome 插件路径以当前 Browser/Chrome 插件技能定义的验证结果为准。

CDP 调试路径必须分别确认：

1. `/json/version` 可访问。
2. `/json/list` 包含目标页面。
3. 当前会话存在实际可调用的 CDP/MCP 客户端。
4. 客户端已连接正确的页面目标，并成功执行所需的只读检查或经确认的交互。
