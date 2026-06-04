# Report Template

Write this inline and to `docs/desktop-launcher.app-it-static-report.md`.

```markdown
## App-it-static report

**1. Project type detected:**
<framework, package manager, build output, swiftc/python3 status>

**2. Static-servable?** <yes/no; if no, use app-it instead>

**3. Apps detected:** <N>
- **<AppName>** - serves `<static_dir>/`, serve_mode <server|file>, build `<build_command>`

**4. Serve mode per app + why:**
- <AppName>: <server|file> - <one-line reason>

**5. Build:**
- Command run: `<build_command>` <or skipped with reason>
- Output confirmed: `<static_dir>/index.html`

**6. Files added/changed:** <scripts, assets, desktop output, docs, package scripts, gitignore>

**7. Icon source:** <path, resolution, why it won>

**8. Commands:**
- Build: `<pm> desktop:build`
- Install: `<pm> desktop:install` -> `~/Applications/App It/`
- Refresh snapshot: `<pm> desktop:rebuild`
- Stop server: `<pm> desktop:quit`

**9. Verification (per app):**
- [x] Build output exists; app built; native run stub + wrapper are Mach-O; `run.sh` is executable; `.icns` multi-resolution
- [x] Bundle metadata correct
- [x] Server responds on runtime port; Cmd+Q frees it
- [x] Install-path open exits 0
- [ ] needs human: window renders the app, Dock icon identity

**10. Known limitations:**
- Snapshot, not live. Re-run `desktop:rebuild` after source changes.
- Unsigned local bundle. Gatekeeper may require right-click -> Open once.
- Baked `PROJECT_ROOT`. Rebuild if the repo moves.
- WebKit, not Chromium.
- <serve-mode-specific limitation>

## Decision history
- <YYYY-MM-DD>: Initial build (serve_mode <X>, static_dir <Y>, build `<cmd>`, port <P>, icon <source>).
```
