# Troubleshooting And Anti-Patterns

The templates contain behavior from real failure cases. Treat comments in them
as product guardrails, not noise.

## Gatekeeper And Signing

`desktop-build.sh` strips extended attributes and ad-hoc signs the bundle:

```bash
/usr/bin/xattr -cr "$APP_DIR"
/usr/bin/codesign --force --deep --sign - "$APP_DIR"
```

`spctl --assess` may still say "rejected" for ad-hoc bundles; the practical
Gatekeeper test is `open` on the installed app.

If older generated apps show the prohibition symbol after a macOS update,
prefer rebuilding with `desktop:build && desktop:install`. If rebuilding is
impossible, strip metadata, ad-hoc sign in place, refresh LaunchServices, and
restart Finder.

## iCloud Extended Attributes

Apps under iCloud-synced Desktop/Documents may acquire protected
`com.apple.fileprovider.fpfs#P` xattrs that codesign cannot remove. Copy without
metadata, sign the clean copy, then replace the original:

```bash
ditto --noextattr --norsrc "$app" /tmp/clean.app
/usr/bin/codesign --force --deep --sign - /tmp/clean.app
```

## Stale Wrapper Shortcuts

If a user reports missing Cmd+R, Cmd+W, zoom, or edit shortcuts, their installed
wrapper may predate the menu/keyboard monitor. Rebuild and reinstall; do not
patch the installed binary by hand.

## desktop:doctor

`desktop-doctor.sh` is read-only by default. It checks config, placeholder
leakage, bundle identity, installed/build app presence, executable shape,
icons, signature/quarantine, runtime port, stale PIDs, descendant ownership,
start-command availability, logs, and template drift.

Use `--json` when an agent or script needs stable machine-readable diagnostics:
the output includes selected app metadata, preferred/runtime ports, counts, and
per-check records. Add `--strict` when warnings or failures should make the
command exit non-zero.

`--fix-safe` is deliberately narrow. It may clean stale App It pid/port files,
refresh this bundle's LaunchServices registration, rebuild generated icon
artifacts, and clear quarantine on the generated app. It must not edit product
code, run installs, kill servers, or touch anything outside App It artifacts.

## Anti-Patterns

- Do not default to Chrome for vanilla web apps.
- Do not passively attach to an externally running server just because `curl`
  returns 200.
- Do not use AppleScript accessibility hacks to deduplicate Chrome windows.
- Do not touch private `WKPreferences` SPI for autoplay.
- Do not path-match `pgrep -f` on non-ASCII paths; prefer URL/port or doctor.
- Do not trust HTTP 200 as visual proof that the wrapper window is correct.
- Do not use `kill -TERM` against the wrapper PID to verify Cmd+Q.
- Do not derive `PROJECT_ROOT` from `$0` or the installed `.app` path.
- Do not symlink `node_modules` from a main checkout into a worktree.
- Do not use single-stage cleanup.
- Do not remove Finder/Dock `PATH` augmentation.
- Do not kill the dev server on every window close.
- Do not migrate to Electron/Tauri while packaging.
- Do not pick `npm run dev` blindly when it hides prompts or port literals.
- Do not hardcode a port literal in `START_COMMAND`.
- Do not touch business-logic source outside the env-port carve-out.
- Do not bundle multiple user-facing apps into one `.app`.
- Do not ask the user questions with defensible defaults.
- Do not rely on AppKit menu key equivalents alone for browser shortcuts.
- Do not assume signatures survive iCloud or major macOS updates.
