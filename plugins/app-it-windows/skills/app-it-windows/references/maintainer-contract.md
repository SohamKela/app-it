# Maintainer Contract

The author runs macOS and will not dogfood this plugin. The Windows lane must
therefore be honest about what was built and what was actually run.

## Produce From Mac Or CI

- C# WPF + WebView2 host sources.
- PowerShell lifecycle scripts.
- Config and manifest files.
- `dotnet publish --runtime win-x64` when the SDK is available.
- CI checks on `windows-latest`: build, script lint, manifest/config parse, and
  placeholder icon round-trip.

## Defer To A Windows Maintainer

Use this exact phrase in reports and blockers:

```text
this needs a Windows maintainer - see docs/WINDOWS.md
```

Defer anything that requires a real Windows desktop or target machine:

- Window opens and renders the URL.
- Taskbar identity is the app, not Edge.
- X/minimize keeps the server warm and feels acceptable.
- Tray Quit disposes the Job Object and frees the port.
- Job Object reaps full dev-server trees.
- Single-instance re-show focuses the resident window.
- SmartScreen first-run flow appears and sticks.
- WebView2 Evergreen runtime exists on a clean target.
- Self-contained `.exe` runs without .NET installed.
- Start Menu `.lnk` lands and icon cache displays the `.ico`.
- DPI behavior and `.ico` crispness are acceptable.
- Defender/antivirus does not false-positive.
- Edge fallback behavior is acceptable.
- PATH augmentation covers real Windows version managers.

Every user-facing string should say beta, scaffolded, untested on real hardware,
and maintainer wanted.
