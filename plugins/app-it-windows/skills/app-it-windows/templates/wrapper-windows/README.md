# `wrapper-windows` — the Windows host

This is the WebView2 + WPF host (the `.exe`), the Windows sibling of `wrapper.swift`: it owns the window, the taskbar identity, and the `.ico`, and creates the Job Object the dev server runs inside. `dotnet publish -c Release -r win-x64 --self-contained` (driven by `desktop-build.ps1`) compiles it to one self-contained single-file `.exe`. None of its runtime behaviour — tray soft-close, Job-Object reap, single-instance re-show, WebView2-runtime presence, DPI scaling — has been verified on real Windows hardware; see [`docs/WINDOWS.md`](../../../../../../docs/WINDOWS.md) for the maintainer checklist.

## Maintainer notes

- **WebView2 user-data folder:** `%LOCALAPPDATA%\app-it\<slug>\WebView2` (set in `HostConfig.WebView2UserDataDir`). `server.pid` / `server.port` sit beside it under `%LOCALAPPDATA%\app-it\<slug>\`.
- **Warm relaunch** is a named **Mutex + named pipe** (`SingleInstanceGate`), not a hidden daemon: the host stays resident and tray-hidden across soft-closes, so the server never leaves its job. A truly-detached daemon for exact macOS warm-across-full-quit parity is the deferred alternative (ADR 0005, lifecycle row 2).
- **Args:** `--url`, `--title`, `--icon`, `--slug`, `--port`, `--start-command`, `--working-dir` (each also readable from the matching `APP_IT_*` env var). `run-template.ps1` supplies them; nothing is baked into the `.exe`.
