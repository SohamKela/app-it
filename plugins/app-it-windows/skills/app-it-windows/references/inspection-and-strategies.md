# Inspection And Strategies

Run `templates/inspect.ps1` first. It inventories worktree status, scripts,
hardcoded ports, framework signals, sibling apps, WebView2/.NET availability,
and runtime-binary candidates.

## Inspection Decisions

- Worktree strategy: write to the main checkout when launcher files are
  dev-tooling, use `APP_IT_PROJECT_ROOT` when the worktree diff should carry the
  scripts, or bake the worktree only after explicit opt-in.
- Project type: verify from `package.json`, config files, Python/Rust/etc
  signals, and existing desktop configs.
- Runtime shape: static, single-server, multi-server, one-shot, or already a
  desktop target.
- Ports: hardcoded `-p`/`--port` flags must become env-driven for the launcher.
- Existing Electron/Tauri/NW.js: use its Windows target instead of stacking a
  second wrapper.
- Toolchain: .NET 8 SDK builds the host; WebView2 Evergreen runtime is needed to
  run it and cannot be proven from macOS.
- Browser APIs: WebView2 is Chromium; no File System Access polyfill is needed.
- Naming/icon: use app-level user vocabulary and a multi-resolution `.ico`.

## Strategy Tree

```text
Existing Electron/Tauri/NW.js config for this app?
  yes -> Strategy B
  no  -> hard requirement for tray/file associations/signed installer?
           yes -> Strategy D
           no  -> .NET 8 SDK buildable and WebView2 expected?
                    no  -> W-Edge
                    yes -> static built bundle, no server?
                             yes -> W-Static
                             no  -> cohabiting frontend + backend?
                                      yes -> W-Multi
                                      no  -> W-Native
```

## Strategy Notes

- W-Native: default WPF + WebView2 host. Owns the Taskbar icon, title bar,
  single-instance behavior, and Job Object.
- W-Edge: fallback when .NET/WebView2 prerequisites are unavailable. Document
  weak Taskbar identity and shutdown behavior loudly.
- W-Static: file URL through the host, empty port, no dev server.
- W-Multi: frontend and backend both run under the host-owned Job Object with
  distinct ports.
- Strategy B: use the existing Electron/Tauri/NW.js Windows target.
- Strategy D: Tauri only when native desktop requirements force it; signing/MSIX
  remain out of scope.
