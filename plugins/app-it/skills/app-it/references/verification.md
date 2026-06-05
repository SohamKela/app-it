# Verification

Never call a launcher done until the installed app path has been checked. Use
three buckets: programmatic checks, human checks, and deferred checks when the
environment is hostile.

## Pre-Flight Smoke

Before clicking the app, separate project-broken from launcher-broken:

```bash
( cd "$PROJECT_ROOT_BAKED" && PORT=$SMOKE_PORT timeout 30 bash -c "$START_COMMAND" ) &
SMOKE_PID=$!
# poll HTTP, then kill the smoke process tree
```

If this fails, report "launcher built, project command failed" with the log
tail.

## Programmatic Checks

Prefer `./scripts/desktop-verify.sh --json <slug>` for the headless lane. It
checks the built/installed bundle status, runs the real bundle through
`APP_IT_SMOKE=1`, confirms the recorded runtime port and HTTP response, and
summarizes `desktop-doctor --json`. It labels GUI-only checks as manual instead
of pretending they passed.

For fixed-port apps, verify that `ports.mode` is `fixed` and the recorded
runtime port equals the configured preferred port. A busy preferred port should
fail launch with an explanation; fallback is deliberately disabled.

For Strategy E URL-only apps, rows 3-9 are `n/a - no local server`.
Programmatic verification is: `APP_IT_SMOKE=1 desktop/<App>.app/Contents/MacOS/run`
prints the configured URL, no `server.port` is written, `run.sh` contains the
URL and `allow-external-hosts` in Swift mode, and rows 1-2 still pass. GUI
verification is opening the installed app, signing into Claude if needed, and
confirming the hosted artifact runs in-window. Do not `curl` private Artifact
URLs as proof; auth-protected Artifacts may correctly redirect.

| # | Check | Idiom |
| ---: | --- | --- |
| 1 | Build succeeded | `.app` exists; `file Contents/MacOS/run` reports Mach-O; `run.sh` executable; wrapper Mach-O; icon file valid |
| 2 | Bundle metadata | `PlistBuddy` prints bundle id/name; no unresolved template-placeholder leakage |
| 3 | Runtime port | read `~/Library/Application Support/app-it/<slug>/server.port` first |
| 4 | Server responding | `curl` runtime port; any non-`000` response means the launcher reached the project |
| 5 | Process identity | prefer `desktop:doctor`; hand `pgrep` is diagnostic only |
| 6 | LaunchServices identity | `lsappinfo` bundle id matches config |
| 7 | Cmd+Q cleanup | `osascript -e 'tell application id "<bundle-id>" to quit'`, then runtime port is free |
| 8 | Red-X warm state | close windows via Apple Event; runtime port remains listening |
| 9 | Warm relaunch | reopen installed app; HTTP responds quickly on recorded runtime port |
| 10 | Installed path opens | `open "$HOME/Applications/App It/<App>.app"` exits `0` |
| 11 | Single LS registration | `lsregister -dump` shows one active installed entry |
| 12 | Shortcut binary marker | `grep -qboa "reloadPageIgnoringCache" .../wrapper` when checking menu shortcut support |

For A3 multi-server apps, Cmd+Q must also free the backend runtime port read
from `backend.port`.

## Human Checks

Mark as needs human unless the environment has a usable display:

- Window shows the app content, not an error page.
- Dock icon is the app icon, not Chrome/Safari.
- Autoplay works when the app needs media autoplay.
- FSA reconnect works when a polyfill is installed.
- Standard shortcuts respond in the actual app window.

## Deferred Checks

If verification would damage the user's current environment, do not spawn a
competing process. Examples: a same-project dev server already owns caches, or a
fixed different-project listener blocks an unmovable proxy port. Mark
`deferred - env hostile` and write the exact one-line user action to retry.

## Cmd+Q Semantics

Do not test Cmd+Q by sending `kill -TERM` to the wrapper. Signals bypass
AppKit's `applicationShouldTerminate`. Use an Apple Event through `osascript`.

## Cleanup

Before ending the session, stop every process this run started. For generated
apps, prefer `desktop:quit`; otherwise terminate recorded PID trees and sweep
runtime ports. Do not kill unrelated listeners.
