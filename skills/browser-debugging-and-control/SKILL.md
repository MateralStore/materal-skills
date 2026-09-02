---
name: browser-debugging-and-control
description: 作为网页调试与测试的默认入口，使用 Chrome DevTools MCP 和受管本地 Chrome/CDP CLI 打开、导航和控制网页。适用于 Console、DOM、脚本与 CSS 注入、页面交互、导航、截图、多账号/多会话和原始 CDP；除非用户明确指定 @Chrome、@Edge 或 @浏览器，或本技能/MCP 不可用，否则不要优先使用这些通用浏览器连接器。
---

# 浏览器调试与控制

当用户要求打开网页、控制浏览器、调试网页或测试网页时，默认加载并使用本技能。普通网页调试先检查当前任务是否暴露 Chrome DevTools MCP，再按下表在 MCP 与配套 CLI 之间路由；不要把通用浏览器连接器当成默认入口。

## 选择入口

先检查当前任务是否实际暴露 Chrome DevTools MCP 工具，例如 `mcp__chrome_devtools__list_pages`、`take_snapshot` 或 `evaluate_script`。配置文件、npm 包或 CDP 端口存在都不能证明 MCP 在当前任务可用。

| 需求 | 首选入口 |
| --- | --- |
| Console、Snapshot/DOM、脚本、CSS、导航、点击、填写、键盘、等待、截图 | Chrome DevTools MCP |
| 启动/复用受管 Chrome、端点校验、多 Chrome 实例 | CLI |
| 精确 HTML/属性/布局、任意页面级或浏览器级 CDP、原始 Console 事件 | CLI |
| MCP 不可用 | CLI 回退 |

发布基线曾用 Chrome DevTools MCP 1.8.0 验证主要调试动作，但每台机器和每个新任务仍须重新发现工具。用户明确指定 `@Edge`、`@Chrome` 或 `@浏览器` 时，遵循对应连接器技能，不要静默改用本技能的默认路线。

MCP 缺失、启动失败或需要绑定 CLI Chrome 时，阅读 [MCP 安装与配置](references/mcp-setup.md)。进入 CLI 路径时，阅读 [CLI 工作流与命令](references/cli-reference.md)。

## MCP 工作流

1. 调用 `list_pages`，明确页面和当前 `pageId`。
2. 调用 `take_snapshot` 获取稳定 `uid`；动作后页面变化时重新获取，不复用过期标识。
3. 使用 `list_console_messages`、`evaluate_script`、`click`、`fill`、`press_key`、`hover`、`wait_for` 和 `take_screenshot`。
4. 需要精确 DOM、复杂 JSON、实验性协议或完整原始事件时切换 CLI，不要删减 `call`、`browser-call` 或 `console --raw` 能力。

MCP 与 CLI 应连接同一预期浏览器。MCP 自管模式使用 MCP 的隔离参数；CLI 管理模式先启动 CLI Chrome，再在 MCP server 启动参数中设置 `--browser-url=http://127.0.0.1:<port>`。当前任务不能临时改变已经启动的 MCP daemon 参数。

## 多账号与多会话

- 仅需 Cookie/LocalStorage 隔离时，优先为每个账号使用不同的 MCP `isolatedContext`。
- 需要不同代理、扩展、权限、缓存、Service Worker 或进程级隔离时，使用不同的 CLI `--home` 和 `--port`；`--profile` 默认由 `home` 派生。
- 多个 Codex 任务共享一个 CLI Chrome 时，每个任务必须使用唯一 `--session`。CLI 默认读取 `CODEX_SESSION_ID` 或 `CODEX_THREAD_ID`。
- “当前目标”不等于“页面所有权”。只有当前会话通过 `ensure --url` 或 `open` 创建的页面才归该会话所有；选择或调试已有页面不会使 `stop` 关闭它。

## 生命周期边界

- `stop` 只关闭当前会话明确登记的页面，不退出 Chrome。若部分页面关闭失败，保留失败页面的所有权记录并报告 `partial-close`。
- `shutdown-browser` 是显式的浏览器级操作；存在其他会话页面或未登记页面时默认拒绝。只有确认所有页面都允许关闭时才使用 `--force`。
- 保留 `browser-call` 原始能力，但不能用 `browser-call Browser.close` 绕过生命周期检查。
- 旧版只有 `state.json`、没有会话状态时，不猜测页面归属；`stop` 返回 `no-session-pages`。

## 安全边界

- CDP 只监听 `127.0.0.1`，CLI 使用独立 `--user-data-dir`，不传入日常 Chrome Profile。
- 只读取任务相关页面，不主动读取无关 Cookie、密码、令牌、浏览历史或本地存储。
- 脚本/CSS 注入、导航、刷新和其他副作用要在结果中说明。提交、删除、付款、发布或真实数据变更仍需在最终动作前获得用户确认。
- Screenshot、DOM、Console、trace 和请求头可能含业务数据，只保存到任务允许的本地目录。

## 完成标准

MCP 路径必须确认工具确实暴露、目标页面明确、使用最新 `pageId`/`uid` 完成操作，并说明是否发生 CLI 回退。

CLI 路径必须确认 endpoint 归属、通过唯一页面条件连接成功、完成用户要求的检查或交互，并报告退出码、副作用及会话页面是否关闭。端点在线、发现页面和页面可控是三个不同状态。
