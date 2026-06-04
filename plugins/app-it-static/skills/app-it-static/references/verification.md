# Verification

Run the checks that match the chosen serve mode. Clean up any smoke servers or
opened app processes before ending the session.

## Pre-flight Smoke

For server mode, prove the built output works before blaming launcher code:

```bash
STATIC_DIR="$PROJECT_ROOT/<static_dir>" PORT="$PORT" python3 scripts/static-server.py
curl -sS -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT"
```

Kill that smoke process. For file mode, confirm `index.html` exists and asset
paths are relative.

## Mandatory Checks

| Check | Programmatic idiom |
| --- | --- |
| Build output exists | `test -f "$PROJECT_ROOT/<static_dir>/index.html"` |
| App bundle exists | `test -d "desktop/<App>.app"` |
| Native entrypoint | `file Contents/MacOS/run` reports Mach-O executable |
| Script handoff | `Contents/MacOS/run.sh` is executable |
| Wrapper | `file <wrapper>` reports Mach-O executable |
| Icon | `.icns` is a Mac OS X icon |
| Metadata | `PlistBuddy` prints bundle ID; no `__PLACEHOLDER__` |
| Install open | `open "$HOME/Applications/App It/<App>.app"` exits `0` |
| Server response | runtime `server.port` exists and `curl` is non-`000` |
| Quit cleanup | Apple Event quit frees the runtime port within 2s |

GUI-only checks need a display:

- Window renders the built app rather than a blank page or 404.
- Dock icon is the app icon.

If the environment cannot verify GUI checks, put them in the human bucket.
