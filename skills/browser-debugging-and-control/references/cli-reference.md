# CLI 工作流与命令

仅在 Chrome DevTools MCP 不可用、需要受管 Chrome、多实例隔离、精确 DOM 或原始 CDP 时阅读。

## 入口与依赖

当前自动发现 Chrome 的实现面向 Windows/PowerShell，需要 Node.js 22+。macOS/Linux 必须显式提供 `--chrome`，或先补充平台发现逻辑。

```powershell
$skillRoot = "<path-to>\skills\browser-debugging-and-control"
& (Join-Path $skillRoot "scripts\cdp.ps1") doctor
& (Join-Path $skillRoot "scripts\cdp.ps1") <command> [options]
```

默认 endpoint 为 `127.0.0.1:9222`，状态目录为 `%LOCALAPPDATA%\codex-cdp\`。可使用 `CODEX_CDP_HOME`、`CODEX_CDP_PORT`、`CODEX_CDP_CHROME` 或对应参数覆盖。

`doctor` 只诊断 Node、npx、Chrome、端点、路径、会话来源和 MCP 配置线索；它不安装、不启动 Chrome、不访问网络，也不能证明 MCP 包成功启动或工具已注入当前任务。

## 最短工作流

```powershell
& (Join-Path $skillRoot "scripts\cdp.ps1") ensure `
  --session $env:CODEX_SESSION_ID `
  --url "http://127.0.0.1:5173"

& (Join-Path $skillRoot "scripts\cdp.ps1") status --session $env:CODEX_SESSION_ID
& (Join-Path $skillRoot "scripts\cdp.ps1") list --session $env:CODEX_SESSION_ID
```

`list` 只发现页面，不自动选择或认领页面。调试已有页面时，第一次操作显式传入唯一的 `--target-id`、`--target-url` 或 `--target-title`；成功连接后该页面成为当前目标，但仍不属于当前会话，`stop` 不会关闭它。

## 高频命令

```powershell
# DOM
& (Join-Path $skillRoot "scripts\cdp.ps1") dom --selector "#app" --format summary
& (Join-Path $skillRoot "scripts\cdp.ps1") dom --selector ".error" --format text --max-chars 5000

# 脚本和 CSS
& (Join-Path $skillRoot "scripts\cdp.ps1") script "document.title"
& (Join-Path $skillRoot "scripts\cdp.ps1") script --file .\probe.js
Get-Content .\probe.js -Raw | & (Join-Path $skillRoot "scripts\cdp.ps1") script --stdin

# 导航、等待、点击
& (Join-Path $skillRoot "scripts\cdp.ps1") navigate "http://127.0.0.1:5173"
& (Join-Path $skillRoot "scripts\cdp.ps1") reload
& (Join-Path $skillRoot "scripts\cdp.ps1") wait --selector "#result" --state visible --timeout-ms 10000
& (Join-Path $skillRoot "scripts\cdp.ps1") click --selector "button.submit" --wait-navigation

# 截图
& (Join-Path $skillRoot "scripts\cdp.ps1") screenshot --output .\page.png
& (Join-Path $skillRoot "scripts\cdp.ps1") screenshot --selector "#app" --output .\app.png
& (Join-Path $skillRoot "scripts\cdp.ps1") screenshot --full-page --output .\full.png

# Console
& (Join-Path $skillRoot "scripts\cdp.ps1") console --duration-ms 5000 --reload
& (Join-Path $skillRoot "scripts\cdp.ps1") console --duration-ms 5000 --live-only --raw
```

`console --live-only` 丢弃启用 Runtime/Log 时回放的历史事件，只保留监听开始后的事件。`console --raw` 保留完整 CDP 结构。

## 原始 CDP

```powershell
& (Join-Path $skillRoot "scripts\cdp.ps1") call Page.reload --params "{}"
Get-Content .\params.json -Raw | & (Join-Path $skillRoot "scripts\cdp.ps1") call Runtime.evaluate --params-stdin
& (Join-Path $skillRoot "scripts\cdp.ps1") browser-call Target.getTargets
```

`call` 连接当前页面目标，`browser-call` 连接浏览器级 WebSocket。两者支持 `--params`、`--params-file` 和 `--params-stdin`。不要用 `browser-call Browser.close` 绕过生命周期检查。

## 多实例和结束会话

每个 Chrome 实例使用不同的 `--home` 和 `--port`。共享同一实例的 Codex 任务使用不同的 `--session`。

```powershell
& (Join-Path $skillRoot "scripts\cdp.ps1") stop --session $env:CODEX_SESSION_ID
```

`stop` 只关闭当前会话通过 `ensure --url` 或 `open` 创建的页面。返回 `partial-close` 时，失败页面仍保留在会话状态中，可检查后重试。

仅在所有会话与未登记页面均可关闭时使用：

```powershell
& (Join-Path $skillRoot "scripts\cdp.ps1") shutdown-browser
```

存在其他会话或未登记页面时默认失败；`--force` 会关闭整个受管 Chrome，应视为显式破坏性操作。
