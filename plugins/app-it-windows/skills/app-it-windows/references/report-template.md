# Report Template

Write this inline and to `docs\desktop-launcher.app-it-report.md`.

```markdown
## App-it (Windows beta) report

> Beta: scaffolded, untested on real hardware, maintainer wanted. This session
> built and lint-checked what the environment can prove; runtime checks need a
> Windows maintainer.

**1. Project type detected:**
<framework, package manager, runtime shape, .NET/WebView2 status, worktree>

**1.5. Name resolution** *(if naming sources disagreed)*
Picked: "<chosen>". Sources surveyed: <...>. Reason: <one line>.

**2. Apps detected:** <N>
- **<AppName>** - <runtime shape, port, start command>

**3. Strategy chosen per app:**
- <AppName>: <W-Native | W-Edge | W-Static | W-Multi | B | D> - <reason>

**4. Why this is the lowest-effort robust approach:**
<2-4 sentences; name ruled-out choices and missing prerequisites.>

**5. Files added/changed:**
<scripts, wrapper, config, package scripts, docs, assets, gitignore>

**6. Icon source per app:**
- <AppName>: `<path>` - <resolution, why it won>

**7. To change an icon later:**
Replace `assets\<slug>-icon.png`, then run desktop icon/build/install commands.

**8. Build / install / quit commands:**
- Build: `<pm> desktop:build`
- Install: `<pm> desktop:install`
- Quit: `<pm> desktop:quit`

**9. Generated launcher locations:**
- Repo: `desktop\<App Name>\<App Name>.exe`
- Installed shortcut: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\app-it\<App Name>.lnk`
- Runtime port: `%LOCALAPPDATA%\app-it\<slug>\server.port`

**10. Verification (per app):**
- [x] Wrapper builds
- [x] PowerShell scripts lint clean
- [x] Manifests + config parse
- [x] Placeholder icon round-trips
- [ ] this needs a Windows maintainer - see docs/WINDOWS.md: window render, Taskbar identity, X-to-warm, tray Quit, Job Object reap, warm relaunch, SmartScreen, `.lnk`, icon cache, DPI

**11. Start Menu group:**
- [x] `app-it\` Start Menu folder targeted
- [ ] this needs a Windows maintainer - see docs/WINDOWS.md: shortcut and icon appear

**12. Known limitations:**
- Untested on real Windows hardware.
- Unsigned `.exe`; SmartScreen first-run click-through expected.
- WebView2 runtime assumed, not guaranteed.
- Baked `PROJECT_ROOT`; rebuild if the repo moves.
- <strategy-specific limitation>

## Decision history
- <YYYY-MM-DD>: Initial scaffold (Strategy <X>, bundle-id <Y>, port <P>, icon <source>). Runtime checks deferred to a Windows maintainer.
```
