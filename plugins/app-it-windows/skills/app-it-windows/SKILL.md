---
name: app-it-windows
description: >-
  Turn a project into one or more real Windows desktop launchers — a
  self-contained `.exe` with its own Taskbar identity and a Start Menu
  shortcut. **Windows beta · maintainer wanted · scaffolded but not
  battle-tested on real hardware.** Use when the user asks to make a local web
  project clickable on Windows, give it an icon, package it as a Windows app,
  or put a launcher in the Start Menu. Mirrors the macOS app-it contract
  (native shell that owns its icon, warm dev-server reuse, soft-close vs quit,
  multi-resolution icon, one-folder install) using Windows primitives: a C#
  WPF + WebView2 host, PowerShell lifecycle scripts, a multi-resolution `.ico`,
  and a Start Menu `.lnk`. Because the author runs only macOS, every decision
  that needs real Windows hardware to confirm fails loudly with a pointer to
  `docs/WINDOWS.md` instead of guessing. Do not present this skill as a
  finished feature.
---

# app-it-windows — Make any project launchable on Windows (beta)

> **Read this first.** This is the Windows sibling of the macOS `app-it` skill.
> The macOS lane is proven by daily use; **this Windows lane is a scaffold the
> author has never run on Windows hardware.** The contract below is correct *on
> paper* (ADR [0005](../../../../docs/decisions/0005-windows-beta-scope.md)), but
> the seams a Mac cannot test are called out explicitly and must be handed to a
> Windows maintainer — see **[The maintainer contract](#the-maintainer-contract)**.
> Never tell the user "your Windows launcher works." Tell them "the scaffold is
> built; here is what a Windows maintainer still needs to verify."

## Core principles

1. **Minimum work for the user. Maximum repeatability. No over-engineering.** Same bar as macOS.
2. **Decide. Don't ask — *unless only a Windows machine could decide.*** When this skill prescribes a default, use it; building the scaffold is reversible. The one new rule on Windows: when a choice genuinely cannot be made or verified without real Windows hardware (see the [deferred-to-maintainer list](#deferred-to-a-windows-maintainer)), **do not guess** — emit the work you *can* do, then fail that sub-step loudly with `this needs a Windows maintainer — see docs/WINDOWS.md` and record it in the report.
3. **Click → it works (the intent).** Double-click the Start Menu shortcut → a window appears showing the app → the **X button / minimize leaves the dev server warm** for a fast relaunch → an explicit **Quit** (tray menu) kills everything and frees the port. This is the Windows reading of macOS's red-X-vs-Cmd+Q; on Windows it is a *manufactured* contract, not an OS gift (see [Lifecycle](#lifecycle-the-soft-close-vs-quit-triple)).
4. **One folder, one Start Menu group.** Install destination is the `app-it\` folder under the user's Start Menu Programs by default: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\app-it\`. This is the Windows equivalent of macOS's `~/Applications/App It/` Dock Stack. Honors `APP_IT_INSTALL_DIR`.
5. **One project may produce multiple apps.** Detect this; create one launcher per user-facing app; do not bundle them.
6. **The launcher keeps its own Taskbar icon.** The foreground process must be ours (the WPF host), not Edge's. Default launcher is the C# WPF + WebView2 shell this skill ships. Edge `--app=` is a documented fallback only — it surrenders Taskbar identity, exactly as Chrome `--app=` does on macOS.
7. **Trust disk over docs.** `CLAUDE.md`, `AGENTS.md`, `README.md` may be stale. Verify project type from `package.json` + config files. If docs and disk disagree, trust disk and note it.
8. **Runtime truth beats build-time guess.** The launcher's port may not be the configured port. The verification target is the runtime artifact, not the build-time intent. The templates encode this; respect it during verification.

The user almost never wants:
- A full Electron migration of their app.
- A new bundler in their dependency tree.
- Hand-edited absolute paths.
- A launcher that opens a stray PowerShell / Command Prompt window on every click.
- To be asked a question that has a defensible default — *or* to be told a Windows-only behaviour "works" when it was never run on Windows.

## The maintainer contract

The author is a macOS user and will not dogfood this. That shapes how this skill behaves:

- **Everything a Mac *can* produce, produce it.** `dotnet build` / `dotnet publish --runtime win-x64` cross-compile from macOS; PowerShell scripts, manifests, the `.csproj`, and the config are all authorable and lint-checkable from a Mac. CI on `windows-latest` (step 3.1) is what exercises the build.
- **Everything that needs real Windows hardware to *confirm*, hand off — don't fake.** When you reach a step whose correctness depends on the live Windows TCP stack, SmartScreen, the WebView2 Evergreen runtime, Job-Object tree-reaping, Start Menu icon-cache behaviour, or per-monitor DPI, you **stop and mark it deferred** with the exact phrase `this needs a Windows maintainer — see docs/WINDOWS.md`. The [deferred list](#deferred-to-a-windows-maintainer) is the canonical set of these seams.
- **Every user-facing string says beta.** Reports, docs, and summaries must read **beta · scaffolded · untested on real hardware · maintainer wanted.** Nothing claims Windows works until a maintainer has dogfooded it.

## When to use this skill

Trigger on any of: "launch from the Start Menu", "make this a Windows app", "give this a Windows launcher / icon", "package as a `.exe`", "Windows desktop shortcut for this project", "appify on Windows", "app-it for Windows".

Use the **macOS `app-it` skill instead** when the user is on a Mac or wants a `.app` / Dock launcher.

Do **not** use this skill for:
- Distributing to other users (MSIX, code signing, Microsoft Store, auto-update). Out of scope — mention as a known limitation.
- Native rewrites or feature additions.
- Generic "build" / "deploy" requests unrelated to a desktop launcher.

---

## Templates folder

This skill ships Windows templates next to `SKILL.md`. As with macOS, the job is to **copy them into the project and customize via `app-it.config.json`** — not rewrite them from scratch.

```
templates/
  wrapper-windows/                 # C# WPF + WebView2 host (the .exe) — step 2.2
    wrapper.csproj                 #   net8.0-windows, WPF, single-file self-contained publish
    App.xaml / App.xaml.cs         #   bootstrap + argument parsing; ShutdownMode=OnExplicitShutdown
    MainWindow.xaml / .xaml.cs     #   WebView2 fills the window; Closing → hide; tray Quit → dispose job
    README.md                      #   "this is the wrapper; dotnet publish builds it; see docs/WINDOWS.md"
  desktop-build.ps1                # dotnet publish → desktop\<App Name>\ (mirrors desktop-build.sh)
  desktop-install.ps1              # Start Menu .lnk via WScript.Shell COM (mirrors desktop-install.sh)
  desktop-quit.ps1                 # port-owner sweep, Stop-Process (mirrors desktop-quit.sh)
  inspect.ps1                      # Phase-1 Windows probe (mirrors inspect.sh)
  run-template.ps1                 # thin bootstrap → launches the WPF host (mirrors run-template.sh)
  run-template-edge.ps1            # Edge --app= fallback (mirrors run-template-chrome.sh)
  desktop-icons.ps1                # PNG/SVG → multi-res .ico (mirrors desktop-icons.sh)
  placeholder-icon-gen.ps1         # last-resort .ico so the build never fails (mirrors placeholder-icon-gen.sh)
  app-it.config.example.json       # same schema as macOS + optional platform.windows block
```

> **Build order note.** These templates are filled in across campaign steps 2.2–2.4.
> If a template you need is still a stub, build only what is present and record
> the gap in the report — do not invent a substitute for a not-yet-shipped template.

**Do not re-derive the patterns.** The comments inside each template document Windows traps (PATH augmentation for nvm-windows/fnm/Volta/Scoop, free-port probing via `TcpListener`, Job-Object ownership) that mirror the hard-won macOS lessons.

---

## Workflow

Phases run in order. Don't skip ahead. The shape is identical to macOS — **inspect → decide → build → verify → report** — with Windows primitives substituted at each step.

### Phase 1 — Inspect (read-only)

**Run `templates/inspect.ps1` first** (PowerShell). It is the Windows sibling of `inspect.sh`: worktree status, project type, dev scripts with hardcoded `-p`/`--port` literals, framework port literals, sibling-app port collisions, runtime-binary availability — **plus two Windows-only probes**: is the **WebView2 Evergreen runtime** present, and is the **.NET 8 SDK** present. Read its output before answering anything below.

Then answer all of these. Do not modify files.

1. **Worktree?** Same three strategies as macOS: (a) write to main checkout (preferred for dev-tooling), (b) `APP_IT_PROJECT_ROOT` env override (reviewable diff on a feature branch), (c) bake worktree + document rebuild (explicit opt-in only).
2. **Project type** (verify from disk). `package.json`, `next.config.*`, `vite.config.*`, `pyproject.toml`/`requirements.txt`, `index.html` at root, etc. Same inventory as macOS.
3. **Runtime shape per app.** Static / single-server / multi-server cohabiting / one-shot script.
4. **Dev-script choice.** Inventory `dev:*` / `start:*`. Default to `dev`; prefer a `dev:bypass` / `dev:no-db` variant when canonical `dev` needs external services unreachable from a click.
5. **Hardcoded port literals.** A `-p 3002` / `--port 5173` in the dev script makes the framework ignore the launcher's `PORT` env. Swap for a clean direct-binary call (`pnpm exec next dev`) or add a `dev:app-it` script. (Same trap, same fix as macOS.)
6. **Existing desktop config.** If `electron`/`tauri`/`nw.js` is already present, that is a strong signal — note it (Strategy B applies on Windows too, via the toolchain's own Windows target).
7. **Multi-app detection.** Same signals as macOS (monorepo workspaces, multiple distinct dev servers, README naming distinct apps). Per-feature icon directories are content, not apps.
8. **Cohabiting frontend + backend?** Same strong signals: `concurrently`/`npm-run-all`/`turbo run dev`/`pnpm -r dev`; a proxy block targeting a different `localhost:` port; a separate `server/` with its own start script.
9. **Toolchain availability — the Windows fork in the road.** Two probes drive strategy:
   - **.NET 8 SDK present?** (`dotnet --version`). Required to *build* the WPF host. CI builds it on `windows-latest`; locally on a Mac you can still `dotnet publish --runtime win-x64`. If absent and unfixable, route to the **Edge `--app=` fallback** and document the warts.
   - **WebView2 Evergreen runtime present?** Required to *run* the WPF host on the target machine. Ships with Win11 and recent Win10 but is **not guaranteed**. → **Whether it is actually present on a clean target is [deferred to a maintainer](#deferred-to-a-windows-maintainer); from a Mac you cannot confirm it.**
10. **Browser-API gotchas.** WebView2 is Chromium, so it natively supports File System Access, Web USB/Bluetooth/HID/MIDI — **no FSA polyfill is needed** (this is a real divergence from macOS WebKit, which lacks FSA). Note any such usage; it is a *point in favour* of the WebView2 host, not against it.
11. **Asset inventory per app.** Same discovery order as macOS (manifest icons → dedicated app icons → square logos → SVG → favicons → brand-token SVG → last-resort letter). The output target is a multi-resolution `.ico`, not `.icns`.
12. **Project-name resolution.** Identical scoring to macOS (recent commit subjects → displayName → human `metadata.json` name → folder humanized → `package.json` name last). Reject scaffold names (`vite-project`, `next-app`).
13. **Per-app stable key (`bundle_id`).** Retained from the shared schema even though Windows has no LaunchServices — it namespaces state/log paths under `%LOCALAPPDATA%\app-it\<slug>\`. Default `com.user.<slug>`.
14. **Install destination.** `%APPDATA%\Microsoft\Windows\Start Menu\Programs\app-it\` unless `APP_IT_INSTALL_DIR` overrides. Optional `APP_IT_DESKTOP_SHORTCUT=1` may also drop a Desktop `.lnk`.
15. **Project root path.** Resolve to a *persistent* absolute path (post-worktree-strategy). The build script bakes it; it cannot be re-derived after the shortcut is installed.

### Phase 2 — Decide

For **each app** detected, pick **one** strategy. The Windows tree is simpler than macOS because WebView2 is Chromium (no FSA-forces-Chrome branch):

```
Existing Electron/Tauri/NW.js config for this app?
├── YES → Strategy B (use its Windows target — don't stack on top)
└── NO →
    Hard requirement for tray UI / file associations / shipping signed installers?
    ├── YES → Strategy D (Tauri wrapper) — and flag signing/MSIX as out of scope
    └── NO →
        .NET 8 SDK buildable AND WebView2 runtime expected on target?
        ├── NO  → W-Edge fallback (Edge --app=) — document warts loudly
        └── YES →
            Static built bundle, no server?
            ├── YES → W-Static (file:// URL, no dev server)
            └── NO →
                Cohabiting frontend + backend?
                ├── YES → W-Multi (one launcher boots both, both in the Job Object)
                └── NO  → W-Native: WPF + WebView2 host (DEFAULT)
```

Strategies, named so the report and CI can refer to them:
- **W-Native — WPF + WebView2 host** (DEFAULT). The host window owns the title bar and `.ico`, so the Taskbar entry is the app, not Edge. Built via `dotnet publish` to a self-contained single-file `.exe`. Requires .NET 8 SDK to build; WebView2 runtime to run.
- **W-Edge — Edge `--app=` fallback.** Used when WebView2 / .NET SDK is unavailable. Same warts as macOS Chrome `--app=`: no distinct Taskbar identity, weaker single-instance, no clean close-vs-quit. `desktop-quit.ps1` becomes the primary shutdown. A fallback, never the default.
- **W-Static** — built site with `index.html`, no server. Point the host at a `file://` URL; pass an empty port.
- **W-Multi** — one user-facing app with cohabiting backend + frontend; both children live in the host's Job Object.
- **Strategy B** — existing Electron/Tauri/NW.js: build its Windows target, don't add a second wrapper.
- **Strategy D** — Tauri, only when a tray/file-association/signed-installer requirement truly forces it.

### Phase 3 — Build

Touch as few project files as possible. Allowed additions mirror macOS, Windows-flavoured:

- `assets\<slug>-icon.{png,svg}` per app (or `assets\app-icon.{png,svg}` if single-app).
- `assets\icons\` — generated `.ico` artifacts (gitignore the contents).
- `scripts\wrapper-windows\` — the C# host, copied verbatim from `templates/wrapper-windows/`.
- `scripts\*.ps1` — `run-template.ps1`, `desktop-build.ps1`, `desktop-install.ps1`, `desktop-quit.ps1`, `inspect.ps1`, `desktop-icons.ps1`, `placeholder-icon-gen.ps1`, `run-template-edge.ps1` (only those the chosen strategy needs).
- `scripts\app-it.config.json` — single source of truth for the APPS list (same schema as macOS + optional `platform.windows` block).
- `desktop\<App Name>\` per app — the published `.exe` + `.ico` (gitignore — regenerated by build).
- `docs\desktop-launcher.md` and `docs\desktop-launcher.app-it-report.md`.
- `package.json` `scripts`: `desktop:build`, `desktop:icons`, `desktop:install`, `desktop:quit` — each invoking the matching `.ps1` via `pwsh -File`.

**Single source of truth: `scripts\app-it.config.json`** — the same schema the macOS skill uses, so a config authored for one platform is legible on the other. The optional `platform.windows` block carries Windows-only fields (every field defaulted):

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

**Config-file edits to make ports env-driven are expected and necessary** (not a violation of "don't touch app source"), exactly as on macOS: a frontend dev-server config may need to read `process.env.PORT`, a multi-server backend may need `API_PORT` before `PORT`, and Vite needs `strictPort: true`. Edits stay minimal and additive so `npm run dev` from a terminal keeps working.

Never:
- Modify app business-logic source code.
- Add runtime dependencies for the W-Native / W-Static / W-Multi strategies.
- Hardcode user paths anywhere except as defaults with an override.
- Spawn a PowerShell/Command-Prompt window the user must keep open.
- Write a launcher that requires the dev server to already be running.
- Leave server processes alive after an explicit Quit.
- **Claim a Windows-runtime behaviour works when it was only built, never run.** Build-time success ≠ runtime success on Windows.

### Phase 4 — Verify (mandatory, three buckets)

The Windows verification matrix has a **third bucket that does not exist on macOS**: checks a Mac literally cannot run because there is no Windows host in the loop. Never claim success in a bucket you can't actually exercise.

| # | Check | From a Mac? | Idiom / who verifies |
|---|---|---|---|
| 1 | Wrapper builds | `[x]` build | `dotnet publish -c Release -r win-x64 --self-contained` succeeds; single-file `.exe` emitted. **CI runs this on `windows-latest`.** |
| 2 | PowerShell scripts lint clean | `[x]` build | `Invoke-ScriptAnalyzer` returns no findings at Error + Warning under `PSScriptAnalyzerSettings.psd1` (CI). |
| 3 | Manifests parse | `[x]` build | both `plugin.json` manifests are valid JSON; `app-it.config.json` parses. |
| 4 | Placeholder icon round-trips | `[x]` build | `placeholder-icon-gen.ps1` emits a readable multi-res `.ico` (CI, on `windows-latest`). |
| 5 | `.exe` launches a window and renders the URL | `[ ] needs a Windows maintainer` | requires a Windows desktop session. |
| 6 | Taskbar entry is the app (not Edge), with our `.ico` | `[ ] needs a Windows maintainer` | Windows icon-cache + DPI behaviour. |
| 7 | X / minimize leaves the dev server warm | `[ ] needs a Windows maintainer` | `Window.Closing` cancel-and-hide on real hardware. |
| 8 | Tray **Quit** disposes the Job Object → port freed | `[ ] needs a Windows maintainer` | confirm `Get-NetTCPConnection -LocalPort <port> -State Listen` is empty after Quit. |
| 9 | Warm relaunch re-shows the resident host instantly | `[ ] needs a Windows maintainer` | named-Mutex + named-pipe single-instance; focus + multi-monitor placement. |
| 10 | Job Object reaps the whole tree (vite → esbuild workers), no leak | `[ ] needs a Windows maintainer` | the load-bearing lifecycle claim. |
| 11 | SmartScreen "More info → Run anyway" appears once and sticks | `[ ] needs a Windows maintainer` | unsigned-binary first-run flow. |
| 12 | Start Menu `.lnk` lands and its icon shows in taskbar + Start | `[ ] needs a Windows maintainer` | shell + icon-cache quirks. |

**The discipline:** rows 1–4 are the *only* rows a Mac (or macOS CI) can turn green. Rows 5–12 are the [deferred-to-maintainer list](#deferred-to-a-windows-maintainer) in checklist form — mark every one `[ ] needs a Windows maintainer — see docs/WINDOWS.md` and never overstate. If asked "does it work on Windows?", the honest answer is "it builds and lints; nobody has run it on Windows yet."

### Phase 5 — Report

Two outputs, same as macOS:
1. **Inline chat report** — the [Final report format](#final-report-format) below.
2. **`docs/desktop-launcher.app-it-report.md` written to disk** — same content plus a `## Decision history` section future sessions append to.

Stage new files with `git add`; do not commit unless the user asks.

---

## Strategy W-Native — WPF + WebView2 host (DEFAULT)

Why this is the default and not Edge `--app=` — the same reasoning as macOS Swift-vs-Chrome:

| Issue | Edge `--app=` | WPF + WebView2 host |
|---|---|---|
| Taskbar icon while window open | Edge's, not ours | Ours |
| Re-click while running | May open a duplicate window | Re-shows the existing window (named Mutex) |
| Window-startup latency | Edge profile init | Fast (WebView2 reuses the runtime) |
| Quit vs close | Indistinguishable | Distinguishable (manufactured — see below) |
| Single-instance | Manual / weak | Native via named Mutex + named pipe |

**Bundle layout (per app):**

```
desktop\<App Name>\
  <App Name>.exe                  # self-contained single-file WPF + WebView2 host
  <App Name>.ico                  # multi-resolution icon
```

…plus a `.lnk` in `%APPDATA%\Microsoft\Windows\Start Menu\Programs\app-it\<App Name>.lnk`.

**`PROJECT_ROOT` is baked at build time** (honors `APP_IT_PROJECT_ROOT`). Never derive it from the `.exe` path — the published folder is independent of the repo.

### Lifecycle — the soft-close-vs-quit triple

Windows does **not** hand you the close-vs-quit distinction the way AppKit does on macOS. We *manufacture* it with three wired pieces (ADR 0005); the host (step 2.2) must implement exactly this triple:

1. `Application.ShutdownMode = OnExplicitShutdown` — so closing the window does **not** terminate the app.
2. `Window.Closing` with `e.Cancel = true` → **hide to tray** (soft-close keeps the dev server warm).
3. A tray-menu **Quit** → **dispose the Job Object** → the dev-server tree dies and the port is freed.

This is the Windows reading of ADR 0004 (macOS daemon-mode). **Whether silent X-to-tray surprises Windows users, and whether tray-only Quit is discoverable, is [deferred to a maintainer](#deferred-to-a-windows-maintainer)** — the beta picks X/minimize = soft-close, Quit from the tray.

### Who owns the Job Object (the 2.2 / 2.3 seam)

A Job Object dies when the process that *created* it exits. So: **the WPF host owns and creates the Job Object and spawns the dev server into it** (step 2.2). `run-template.ps1` (step 2.3) is the **thin bootstrap** — augment PATH, pre-flight, scan for a free port on `127.0.0.1`, then launch the host with the resolved `START_COMMAND` + `PORT`; the host does the job-wrapped spawn. A Job Object created by the short-lived PowerShell launcher would close — and kill the server — the instant the script returned. The one exception is the **W-Edge fallback**, where there is no host: `run-template-edge.ps1` owns the job itself and accepts the warts. **The two must never both try to own the job.**

### Hold the port — the load-bearing divergence from macOS

macOS uses `setsid` to detach the dev server so it survives a full wrapper exit (true daemon, warm across quits). The Windows beta instead binds the dev server's lifetime to the **resident host's Job Object**: the server stays warm across soft-closes (the host stays resident, tray-hidden) but **dies when the host dies**. This trades macOS's warm-across-full-quit for orphan-safety (no leaked server after a crash). **Whether this trade is acceptable, or a maintainer wants a truly-detached daemon (named-pipe broker) for exact macOS parity, is deferred.**

## Strategy W-Edge — Edge `--app=` fallback

Use when .NET 8 SDK is unavailable to build *or* the WebView2 runtime can't be assumed on the target. The Edge template ships with the same runtime defenses it can (free-port scan, `server.port` recording, PATH augmentation), but the warts that remain are documented loudly:
- Taskbar may show Edge's icon, not ours.
- Re-launch may open a duplicate window.
- Quit vs close are not distinguished → closing the window leaves the dev server running until `desktop-quit.ps1`. Mark "Quit kills server" as `[ ] needs desktop:quit`, and document `desktop:quit` as the **primary** shutdown in `docs/desktop-launcher.md`.

## W-Static / W-Multi

- **W-Static** — adapt `run-template.ps1`: drop the dev-server block, point the host at `file://<PROJECT_ROOT>\<dist>\index.html`, pass an empty port.
- **W-Multi** — one launcher boots both FE and BE into the host's Job Object with distinct `PORT` / `API_PORT` env vars, records both ports under `%LOCALAPPDATA%\app-it\<slug>\`. Disposing the Job Object on Quit reaps both. Required edits to make ports env-driven are the same carve-out as macOS.

---

## Icons — multi-resolution `.ico`

`desktop-icons.ps1` produces a multi-resolution `.ico` (the Windows `.icns`) from a source PNG or SVG, containing at minimum **16 / 32 / 48 / 256** px. **64 and 128 are nearly free in the `.ico` container and improve mid-DPI taskbar / Start Menu rendering — include them** (`ico_sizes: [16, 32, 48, 64, 128, 256]`). **ImageMagick** is used when present (fast, clean SVG rasterization); a **`System.Drawing`** PowerShell fallback keeps it working on stock Windows with nothing installed. `placeholder-icon-gen.ps1` generates a placeholder `.ico` so the build never fails on a missing icon.

> `System.Drawing.Common` is Windows-only on .NET 8. That is fine here — the fallback only ever runs on Windows hosts / `windows-latest` CI. It must never be invoked from the macOS side. **Whether the fallback's quality is acceptable next to the ImageMagick path is deferred to a maintainer.**

## Signing — unsigned, SmartScreen click-through documented

Unsigned, like the macOS plugin's ad-hoc local signing. On first run, Windows SmartScreen shows "Windows protected your PC"; the user clicks **More info → Run anyway** once. This one-time click-through is **documented in `docs/WINDOWS.md`** (the Windows analog of the macOS Gatekeeper note). Self-signed certs are more friction than benefit. Real code signing / MSIX / Store distribution is out of scope. **Whether the SmartScreen flow appears and sticks as documented is deferred to a maintainer.**

---

## Anti-patterns (Windows-specific)

These mirror the macOS anti-patterns where they transfer, and add the Windows-only traps from ADR 0005:

- **Don't use Edge `--app=` as the default.** It steals the Taskbar icon, weakens single-instance, can't cleanly distinguish close from quit. Use the WPF host. Edge is a fallback only.
- **Don't let both the PowerShell launcher and the WPF host own the Job Object.** The host owns it (it must outlive the launcher). The launcher is a thin bootstrap. The W-Edge fallback is the only place the script owns the job.
- **Don't use `OnLastWindowClose` shutdown mode.** Closing the window would terminate everything and break the warm-server contract. Use `OnExplicitShutdown` + `Window.Closing` cancel-and-hide + tray Quit.
- **Don't bind the dev server to `0.0.0.0`.** Bind `127.0.0.1` only — a non-loopback listener trips the Windows Defender Firewall prompt, exactly as it does the macOS firewall.
- **Don't trust `Get-NetTCPConnection` to *find a free* port.** It lists *existing* connections, not free ones. Probe with a `System.Net.Sockets.TcpListener` bind on `127.0.0.1:<port>` and catch the failure. (`Get-NetTCPConnection` is the right tool for *cleanup* — mapping a busy port to its `OwningProcess` — not for allocation.)
- **Don't omit PATH augmentation.** A Start Menu / Explorer launch starts with a bare PATH. The template must cover the Windows version managers devs actually use: **nvm-windows, fnm, Volta, Scoop shims, pnpm, Bun, Deno**.
- **Don't derive `PROJECT_ROOT` from the `.exe` location.** Bake the absolute repo path at build time; honor `APP_IT_PROJECT_ROOT`.
- **Don't add a FSA polyfill.** WebView2 is Chromium and supports File System Access natively — the polyfill is a macOS-WebKit workaround that has no place here.
- **Don't claim a deferred row is green.** Build/lint success is not runtime success. Any row in the [deferred list](#deferred-to-a-windows-maintainer) stays `[ ] needs a Windows maintainer` until a human on real hardware confirms it.

---

## Deferred to a Windows maintainer

These are the decisions and verifications a Mac user **cannot honestly make from a Mac** (ADR 0005). When the workflow reaches any of them, do the buildable part, then mark it deferred with `this needs a Windows maintainer — see docs/WINDOWS.md`. `docs/WINDOWS.md` (step 3.2) turns this into the contributor's checklist.

1. **X-closes-to-tray vs X-quits** — does silent minimize-to-tray match Windows users' expectations? (Lifecycle.)
2. **Job Object reaps the full tree** — vite/esbuild grandchildren, no breakaway, no leaked port on quit.
3. **Warm-keep model is acceptable** — job-bound server (dies with the resident host) vs a truly-detached daemon matching macOS.
4. **Single-instance re-show feels instant** — focus-stealing, multi-monitor placement.
5. **SmartScreen first-run flow** appears as documented and "Run anyway" sticks.
6. **WebView2 Evergreen runtime present** on a clean install — and the fallback bootstrapper behaves.
7. **Self-contained single-file `.exe` runs on a machine with no .NET.**
8. **`.lnk` lands in the Start Menu** and its icon renders in taskbar and Start.
9. **`.ico` renders crisply at each DPI**, and the `System.Drawing` fallback's quality is acceptable.
10. **Per-monitor-v2 / high-DPI scaling** of the WebView2 host looks right.
11. **Antivirus / Defender false-positives** on an unsigned single-file `.exe`.
12. **Edge `--app=` fallback** taskbar identity and close behaviour.
13. **PATH augmentation** covers the Windows version managers in real use.

---

## Final report format

End every app-it-windows session with **exactly** this report. No section omitted; "n/a" if truly inapplicable. Inline in chat **and** written to `docs/desktop-launcher.app-it-report.md`.

```markdown
## App-it (Windows beta) report

> **Beta · scaffolded · untested on real hardware · maintainer wanted.** This
> session built and lint-checked the scaffold; nothing below was run on Windows.

**1. Project type detected:**
<e.g. pnpm monorepo, Vite + React on :5173, no existing desktop config, .NET 8 SDK present, WebView2 runtime unknown (Mac), worktree at ...>

**1.5. Name resolution** *(if naming sources disagreed)*
Picked: "<chosen>". Sources surveyed: <...>. Reason: <one line>. To override: edit `scripts\app-it.config.json`, then desktop:build && desktop:install.

**2. Apps detected:** <N>
- **<AppName 1>** — <runtime shape, port, start command>

**3. Strategy chosen per app:**
- <AppName 1>: <W-Native | W-Edge | W-Static | W-Multi | B | D> — <one-line reason>

**4. Why these are the lowest-effort robust approaches:**
<2–4 sentences. What was ruled out and why. If W-Edge was chosen, name the missing prerequisite (.NET SDK / WebView2).>

**5. Files added/changed:**
- `assets\<slug>-icon.png` per app
- `scripts\wrapper-windows\...` (the C# host)
- `scripts\*.ps1` (only those the strategy needs)
- `scripts\app-it.config.json`
- *(if W-Multi)* `vite.config.ts` / `server` edits — env-driven ports
- `package.json` — added desktop:* scripts
- `docs\desktop-launcher.md`, `docs\desktop-launcher.app-it-report.md`
- `.gitignore` — added: `desktop/`, `assets/icons/`

**6. Icon source per app:**
- <AppName 1>: `<path>` — <resolution>, <why this beat alternatives>. Considered: <list>.

**7. To change an app icon later:**
Replace `assets\<slug>-icon.png`, then `pnpm desktop:icons && pnpm desktop:build && pnpm desktop:install`.

**8. Build / install / quit commands:**
- Build: `pnpm desktop:build` (runs `dotnet publish`)
- Install: `pnpm desktop:install` (→ Start Menu `app-it\` folder)
- Quit: `pnpm desktop:quit` (frees the port)

**9. Generated launcher locations:**
- Repo: `desktop\<App Name>\<App Name>.exe`
- Installed shortcut: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\app-it\<App Name>.lnk`
- Runtime port (after first click): `%LOCALAPPDATA%\app-it\<slug>\server.port`

**10. Verification (per app) — three buckets:**
- [x] Wrapper builds (`dotnet publish -r win-x64 --self-contained`)
- [x] PowerShell scripts lint clean (`Invoke-ScriptAnalyzer`)
- [x] Manifests + config parse
- [x] Placeholder icon round-trips (CI, windows-latest)
- [ ] needs a Windows maintainer — see docs/WINDOWS.md: window renders, Taskbar identity, X-to-warm, tray-Quit-frees-port, Job-Object tree reap, warm relaunch, SmartScreen, `.lnk` + icon-cache, DPI
- [ ] deferred — Windows runtime not in the loop (this is a Mac-authored beta)

**11. Start Menu group:**
- [x] `app-it\` Start Menu folder targeted (created on install)
- [ ] needs a Windows maintainer: confirm the shortcut + icon actually appear

**12. Known limitations:**
- Untested on real Windows hardware — beta, maintainer wanted (docs/WINDOWS.md)
- Unsigned `.exe` — SmartScreen warns on first launch (More info → Run anyway)
- WebView2 runtime assumed present (ships with Win11 / recent Win10; not guaranteed)
- baked PROJECT_ROOT — re-run desktop:build if the repo moves
- <e.g. W-Edge fallback used — Taskbar identity is Edge's, Quit needs desktop:quit>

## Decision history
- <YYYY-MM-DD>: Initial scaffold (Strategy <X>, bundle-id <Y>, port <P>, icon: <source>). Mac-authored; runtime checks deferred to a Windows maintainer.
- <next session appends here>
```

---

## Cross-reference

- **Lifecycle contract & every deferred decision:** [ADR 0005](../../../../docs/decisions/0005-windows-beta-scope.md).
- **The macOS sibling skill** (proven, daily-use): `plugins/app-it/skills/app-it/SKILL.md`.
- **Contributor doorway** (what a first PR looks like, how to claim a check): `docs/WINDOWS.md` (shipped in step 3.2).
