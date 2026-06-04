# Wrapper Host

The host in `templates/wrapper-windows/` is the WebView2 + WPF sibling of
`wrapper.swift`. `desktop-build.ps1` publishes it as a self-contained
single-file `win-x64` `.exe`, then copies that executable beside each app's
`.ico`.

## Contract

- The host owns the window, title bar, Taskbar identity, and icon.
- The host creates and owns the Job Object the dev server runs inside.
- `run-template.ps1` is a thin bootstrap: augment PATH, find a free loopback
  port, resolve the start command, then launch the host with flags.
- The `.exe` is generic. Per-app settings come from flags/env vars, not baked
  host code.

## Lifecycle

Windows does not provide macOS-style close-vs-quit semantics automatically. The
scaffold manufactures them:

1. `Application.ShutdownMode = OnExplicitShutdown`.
2. `Window.Closing` cancels close and hides to tray.
3. Tray Quit disposes the Job Object, killing the dev-server tree and freeing
   the port.

Whether this behavior is right for Windows users is deferred to a maintainer.

## Arguments

The host accepts `--url`, `--title`, `--icon`, `--slug`, `--port`,
`--start-command`, and `--working-dir`. Each also has an `APP_IT_*` env fallback.

Runtime state lives under `%LOCALAPPDATA%\app-it\<slug>\`: `server.pid`,
`server.port`, `server.identity`, and `WebView2`. `server.identity` is the dev
server's creation time as an invariant UTC FILETIME (the Windows reading of
macOS `ps -o lstart=`); `desktop-quit.ps1` re-checks it so it only stops a
recorded PID it can prove it owns, never a recycled or foreign process that
happens to hold the recorded port.

Do not let both PowerShell and the host own the Job Object. W-Edge is the only
strategy where the script owns process cleanup because there is no host.
