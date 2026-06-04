# Decision records

Why app-it is shaped the way it is — and which tempting alternatives were tried and turned down. Short by design: each file records one decision, its context, the alternatives, and what it costs.

- [0001](0001-native-webkit-shell.md) — Native WebKit shell as the default launcher
- [0002](0002-macos-only-scope.md) — macOS only, on purpose
- [0003](0003-bundle-id-prefix.md) — `com.user.<slug>` bundle-id prefix
- [0004](0004-daemon-mode-lifecycle.md) — Daemon-mode dev server: warm on close, killed on quit
- [0005](0005-windows-beta-scope.md) — Windows beta: scope and lifecycle contract (supersedes 0002 for the Windows lane only)
- [0006](0006-static-companion-snapshot-model.md) — `app-it-static`: a companion that serves the build, not a dev server
- [0007](0007-direct-app-launch-executable.md) — Direct app launch executable shape
- [0008](0008-existing-bundle-adoption.md) — Existing-bundle adoption stays out of scope

`REJECTED/` holds proposals considered seriously and declined, so they don't get re-litigated six months from now:

- [Electron or Tauri by default](REJECTED/electron-or-tauri-by-default.md)
- [Auto-attaching to an already-running dev server](REJECTED/auto-attach-to-a-running-server.md)
