# Report Template

End every App It session with this report inline and written to
`docs/desktop-launcher.app-it-report.md`. Keep every section; use `n/a` only
when truly inapplicable.

```markdown
## App-it report

**1. Project type detected:**
<framework/runtime/toolchain/worktree summary>

**1.5. Name resolution** *(if multiple naming sources disagreed)*
Picked: "<chosen>". Sources surveyed: <folder>, <package.json name>, <metadata.json>, <recent commits>. Reason: <one line>. To override: edit `scripts/app-it.config.json`, then desktop:build && desktop:install.

**2. Apps detected:** <N>
- **<AppName 1>** - <runtime shape, port, start command>

**3. Strategy chosen per app:**
- <AppName 1>: <A1 native | A1 chrome-fallback | A2 static | A3.1 reuse-orchestrator | A3.2 multi-server-template | A3.3 refuse-on-collision | A4 CLI | B | D> - <one-line reason>

**4. Why these are the lowest-effort robust approaches:**
<2-4 sentences. Mention what was ruled out and why.>

**5. Files added/changed:**
- `assets/<slug>-icon.png` per app
- `assets/<slug>-polyfill.js` per app *(if used)*
- `desktop/<AppName>.app/...`
- copied `scripts/` templates and `scripts/app-it.config.json`
- env-port config edits *(if used)*
- `package.json` desktop scripts
- `docs/desktop-launcher.md`
- `docs/desktop-launcher.app-it-report.md`
- `.gitignore` generated-artifact entries

**6. Icon source per app:**
- <AppName 1>: `<path>` - <resolution/format>, <why this beat alternatives>. Considered: <list>.

**7. To change an app icon later:**
Replace `assets/<slug>-icon.png`, optionally run the preview script, then run icons, build, and install. The install step refreshes Dock and Finder icon caches.

**8. Build / install / quit commands:**
- Build: `<command>`
- Install: `<command>`
- Quit: `<command>`
- Diagnose: `<command>`

**9. Generated launcher locations:**
- Repo: `desktop/<AppName>.app`
- Installed: `~/Applications/App It/<AppName>.app`
- Runtime port after first click: `~/Library/Application Support/app-it/<slug>/server.port`

**10. Verification (per app):**
- [x] Build succeeded; `.app` exists; run executable and wrapper are Mach-O; icon is valid
- [x] Bundle metadata correct; no placeholder leakage
- [x] Cold launch records runtime port; HTTP responds
- [x] Single instance / process identity confirmed
- [x] Cmd+Q via Apple Event kills server tree
- [x] Red-X leaves server warm
- [x] Warm relaunch is fast
- [x] Installed-path open exits 0
- [ ] needs human: window content, Dock icon identity, autoplay, FSA reconnect, keyboard shortcuts
- [ ] deferred - env hostile: <reason and retry one-liner>

**11. Dock Stack:**
- [x] `~/Applications/App It/` exists
- [ ] User has dragged `~/Applications/App It/` to the right side of the Dock

**12. Known limitations:**
- <unsigned bundle / WebKit vs Chromium / baked path / Chrome fallback / worktree / universal binary / n/a>

## Decision history
- <YYYY-MM-DD>: Initial build (Strategy <X>, bundle-id <Y>, port <P>, icon: <source>).
```
