# Chrome DevTools MCP 安装与配置

仅在当前任务没有可调用的 Chrome DevTools MCP 工具，或需要把 MCP 绑定到指定 CLI Chrome 时阅读本说明。优先以仓库发布的 README 和当前 `chrome-devtools-mcp` 版本为准。

## 安装

Codex 中添加官方 MCP server：

```powershell
codex mcp add chrome-devtools -- npx chrome-devtools-mcp@latest
```

Windows 11 也可以在 `%USERPROFILE%\.codex\config.toml` 中显式配置：

```toml
[mcp_servers.chrome-devtools]
command = "cmd"
args = ["/c", "npx", "-y", "chrome-devtools-mcp@1.8.0"]
env = { SystemRoot="C:\\Windows", PROGRAMFILES="C:\\Program Files" }
startup_timeout_ms = 20000
```

`1.8.0` 是本技能当前验证基线；若改用 `@latest`，安装后重新检查工具名称和参数。不要把这段配置写入技能目录来代替用户的 Codex 配置。

如果需要同时连接多个独立 CLI Chrome，可在用户配置中使用多个具名 server；每个 server 绑定不同端口：

```toml
[mcp_servers.chrome-devtools-account-a]
command = "cmd"
args = ["/c", "npx", "-y", "chrome-devtools-mcp@1.8.0", "--browser-url=http://127.0.0.1:9231"]

[mcp_servers.chrome-devtools-account-b]
command = "cmd"
args = ["/c", "npx", "-y", "chrome-devtools-mcp@1.8.0", "--browser-url=http://127.0.0.1:9232"]
```

`doctor` 会按 section 识别这些具名 server，只统计 section 自身的 `chrome-devtools-mcp`、`--browser-url` 和 `--isolated` 配置，不会把无关 MCP 或注释中的文字算进去。

安装或修改配置后，重新加载/重启 Codex 任务。先在工具列表确认 `mcp__chrome_devtools__list_pages`、`take_snapshot`、`evaluate_script` 等实际存在，再开始调试。

## 浏览器归属

选择一种模式，并在整个任务中保持一致：

- MCP 自管：让 MCP 启动自己的 Chrome；需要隔离时使用 MCP 支持的 `--isolated`。
- CLI 管理：先运行 `cdp.ps1 ensure --port 9231`，再把 MCP server 参数配置为 `--browser-url=http://127.0.0.1:9231`。MCP server 启动后不能在当前任务中临时改参数。

CLI 的 `--home`、`--profile` 和 `--port` 必须对每个 Chrome 实例唯一。共享一个 CLI Chrome 端点时，每个 Codex 任务还应使用唯一 `--session`；`stop` 只关闭当前会话登记的页面，不能退出整个浏览器。多个端点应配置多个具名 MCP server，各自绑定独立端口；不要依赖未公开的 daemon/session 内部字段。

## 隐私与网络

按需设置以下选项（具体名称以安装版本 README 为准）：

- `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1`：关闭使用统计。
- `CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS=1`：关闭更新检查。
- `--no-performance-crux`：不调用性能 trace 的 CrUX 查询。
- `--redact-network-headers`：尽量脱敏网络请求头。

Console、DOM、截图、trace、请求头和页面 URL 可能包含敏感业务数据；不要把这些输出写入公开目录或提交到仓库。

## 安装故障

- `npx` 不存在：安装 Node.js LTS，并确认 `node --version`、`npx --version` 可用。
- server 未出现在工具列表：确认 `config.toml` 语法、命令路径和启动超时，然后重启 Codex 任务。
- MCP 能启动但没有页面：先用 MCP 的 `list_pages`；若使用 CLI 管理模式，再确认 `status` 的端点和 `--browser-url` 端口一致。
- MCP 与 CLI 看到不同页面：说明它们连接了不同 Chrome/端点；不要混用旧的 `pageId`，重新选择浏览器归属并调用 `list_pages`/`list`。
- MCP 不可用但 CLI 自检通过：按 CLI 回退路径完成任务，并在结果中说明未使用 MCP。

## 生命周期边界

`stop` 只关闭当前会话登记的页面；它不会退出 Chrome。只有明确确认所有会话和未登记页面都允许关闭时，才使用 `shutdown-browser`，并在必要时显式传入 `--force`。
