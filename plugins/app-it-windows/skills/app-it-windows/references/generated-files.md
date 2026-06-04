# Generated Files

Copy templates into the target project and customize via
`scripts\app-it.config.json`.

## Allowed Additions

- `assets\<slug>-icon.{png,svg}`.
- `assets\icons\` for generated `.ico` artifacts.
- `scripts\wrapper-windows\` for the C# host.
- Selected `scripts\*.ps1`: run template, Edge fallback, build, install, quit,
  inspect, icon generation, and placeholder icon generation.
- `scripts\app-it.config.json`.
- `desktop\<App Name>\` for generated `.exe` and `.ico` output.
- `docs\desktop-launcher.md` and `docs\desktop-launcher.app-it-report.md`.
- Package scripts: `desktop:build`, `desktop:icons`, `desktop:install`,
  `desktop:quit`.
- `.gitignore` entries for regenerated desktop/icon outputs.

## Config Shape

```json
{
  "apps": [
    {
      "name": "My App",
      "slug": "my-app",
      "port": 3000,
      "start_command": "pnpm exec next dev",
      "bundle_id": "com.user.my-app",
      "version": "0.1.0",
      "platform": {
        "windows": {
          "webview2_user_data_dir": "%LOCALAPPDATA%\\app-it\\my-app\\WebView2",
          "ico_sizes": [16, 32, 48, 64, 128, 256],
          "start_menu_folder": "app-it",
          "edge_fallback": false
        }
      }
    }
  ]
}
```

The Windows plugin reads the same top-level schema as macOS. Windows-only
fields live under `platform.windows`.

## Rules

- Do not modify business-logic source.
- Env-driven port edits are allowed when launcher correctness requires them.
- Do not add runtime dependencies for W-Native, W-Static, or W-Multi.
- Do not hardcode user paths except as overridable defaults.
- Do not leave a PowerShell or Command Prompt window open on click.
- Do not require the dev server to be running before launch.
