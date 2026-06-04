# Generated Files

Copy templates into the target project and customize through
`scripts/app-it.config.json`. Do not rewrite launcher internals.

## Template Roster

```text
templates/
  wrapper.swift
  info-plist-template.xml
  native-run-stub.c
  desktop-icons.sh
  desktop-icons-preview.sh
  desktop-install.sh
  placeholder-icon-gen.sh
  static-server.py
  run-template-static-server.sh
  run-template-static-file.sh
  desktop-build.sh
  desktop-quit.sh
  desktop-rebuild.sh
  inspect-static.sh
  app-it.config.example.json
  desktop-launcher.md.template
```

The shared macOS launcher templates must stay byte-identical to `app-it`.
Validation fails on drift.

## Allowed Additions

- `scripts/wrapper.swift`, `scripts/info-plist-template.xml`,
  `scripts/native-run-stub.c`, `scripts/static-server.py`,
  `scripts/run-template-static-*.sh`, `scripts/desktop-*.sh`,
  `scripts/inspect-static.sh`, `scripts/placeholder-icon-gen.sh`.
- `scripts/app-it.config.json`.
- `assets/<slug>-icon.{png,svg}` and generated `assets/icons/`.
- `desktop/<AppName>.app/` (regenerated output; gitignored).
- `docs/desktop-launcher.md` and
  `docs/desktop-launcher.app-it-static-report.md`.
- Package scripts: `desktop:build`, `desktop:icons`,
  `desktop:icons:preview`, `desktop:install`, `desktop:quit`,
  `desktop:rebuild`.

For hand-written static sites without `package.json`, expose equivalent commands
through a `Makefile` or top-level shell script.

## Config Shape

```json
{
  "apps": [
    {
      "name": "Fjord",
      "slug": "fjord",
      "serve_mode": "server",
      "static_dir": "dist",
      "port": 4100,
      "bundle_id": "com.user.fjord",
      "version": "0.1.0",
      "build_command": "npm run build"
    }
  ]
}
```

`desktop-build.sh`, `desktop-quit.sh`, and `desktop-rebuild.sh` read this file.
`build_command` is used by `desktop:rebuild`, not by routine bundle assembly.
