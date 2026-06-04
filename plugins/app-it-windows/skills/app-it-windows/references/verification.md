# Verification

Separate buildable evidence from Windows-runtime evidence.

## Buildable From Mac Or CI

| Check | Evidence |
| --- | --- |
| Wrapper builds | `dotnet publish -c Release -r win-x64 --self-contained` |
| PowerShell scripts lint | `Invoke-ScriptAnalyzer` in Windows CI |
| Manifests/config parse | JSON parse checks |
| Placeholder icon | `.ico` round-trip in `windows-latest` CI |

If a local Mac cannot run a Windows check, say so and rely on CI only when the
CI job actually covers that check.

## Needs Windows Maintainer

Report these as deferred unless a real Windows desktop proves them:

- Window renders the URL.
- Taskbar entry is the app and shows the `.ico`.
- X/minimize keeps the server warm.
- Tray Quit frees the port.
- Warm relaunch re-shows the resident host.
- Job Object reaps the whole dev-server tree.
- SmartScreen first-run flow behaves as documented.
- Start Menu `.lnk` lands with the icon.
- DPI and icon crispness are acceptable.

Use: `this needs a Windows maintainer - see docs/WINDOWS.md`.
