# 0005 — Windows beta: scope and lifecycle contract

**Status:** Accepted (beta · scaffolded · untested on real hardware · maintainer wanted)
**Supersedes:** [0002 — macOS only, on purpose](0002-macos-only-scope.md), **for the Windows lane only.**

> This record does not delete or rewrite 0002. 0002 still governs the macOS
> plugin (`plugins/app-it/`) and its honest "macOS-only" promise. What 0002 got
> right — that Windows is a *separate plugin*, not a flag on the macOS one —
> stays true. This ADR opens that separate plugin (`plugins/app-it-windows/`) as
> an explicit beta and writes the contract it must honor. Everywhere the two
> overlap, 0002's "different project, different failure modes" reasoning is the
> reason this is a sibling and not a cross-platform abstraction.

## Context

app-it turns a local web project into a real desktop launcher. On macOS that
means a Swift `WKWebView` shell that owns its Dock icon, a daemon-mode dev
server that stays warm on window-close and dies on quit, multi-resolution
`.icns` icons, and `~/Applications/App It/` install. The macOS contract is
proven by daily use (ADRs [0001](0001-native-webkit-shell.md),
[0003](0003-bundle-id-prefix.md), [0004](0004-daemon-mode-lifecycle.md)).

Christian — the author — runs only macOS and will not dogfood a Windows build.
The honest move is not to keep saying "no" (0002), nor to quietly ship an
untested Windows launcher dressed as "working." It is to ship a **credible beta
scaffold plus a clear contributor doorway**, label it beta everywhere a user can
see it, guard it with CI so it can't bit-rot, and name — out loud — every
decision only a real Windows user can validate.

This ADR is the spec the rest of the campaign builds against. It maps each macOS
primitive to its Windows counterpart and marks the seams a Mac cannot test.

## Decision

### Native shell — WPF + WebView2

The Windows equivalent of the Swift `WKWebView` shell is a **C# WPF host
embedding WebView2** (`Microsoft.Web.WebView2`, the Evergreen Chromium runtime).
The host window owns the title bar and `.ico`, so the **taskbar entry is the
app, not Edge** — the same reason macOS uses a native shell over Chrome `--app=`
(0001). WPF gives us first-class window-lifecycle hooks (`Window.Closing`, custom
`ShutdownMode`), a tray icon, and `Win32` interop for Job Objects — everything the
soft-close-vs-quit contract needs.

Built via **`dotnet publish` to a self-contained, single-file `.exe`**
(`win-x64`, `PublishSingleFile=true`, `SelfContained=true`). One file, no .NET
runtime install, double-click runs — the Windows reading of app-it's "click → it
works" principle.

**Edge `--app=<url>` is the documented fallback**, exactly as Chrome `--app=` is
on macOS (0001): used when WebView2 / the .NET SDK is unavailable, with the same
warts (no distinct taskbar identity, weaker single-instance, no clean
close-vs-quit distinction). It is a fallback, never the default.

| Open question (beta default in **bold**) | Why |
| --- | --- |
| WPF **vs** WinUI 3 | WPF: mature WebView2 integration, no Windows App SDK runtime dependency, stable since forever. WinUI 3 is the "modern" path but adds runtime/packaging friction a beta doesn't need. **WPF.** A maintainer who wants Fluent styling can revisit. |
| Self-contained ~80 MB **vs** framework-dependent ~1 MB + runtime install | Self-contained honors "no first-run setup." 80 MB is nothing for a local launcher. **Self-contained, no runtime install required.** |

### Packaging — folder + `.exe` + `.ico` + Start Menu `.lnk`

Per app, a folder containing the published `.exe` and its `.ico`, plus a `.lnk`
shortcut placed in:

```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\app-it\<App Name>.lnk
```

This mirrors the macOS "one folder, one Dock Stack" idea (the `app-it\` Start
Menu folder is the Windows equivalent of `~/Applications/App It/`). The shortcut
is created with the `WScript.Shell` COM object from PowerShell.

- **No MSIX.** Too heavy for a personal local launcher; pulls in packaging
  identity, signing expectations, and Store-shaped friction we explicitly reject
  (mirrors "no installer generation" in [COMPATIBILITY.md](../COMPATIBILITY.md)).
- **Honors `APP_IT_INSTALL_DIR`** — same override the macOS install script
  honors, so a maintainer can redirect the install target.

| Open question (beta default in **bold**) | Why |
| --- | --- |
| `.lnk` in Start Menu only **vs** also Taskbar pin / Desktop shortcut | Taskbar pinning is a manual, per-user gesture on Windows that cannot be scripted cleanly without unsupported shell hacks. Desktop shortcuts clutter. **Start Menu only** for the beta; an optional `APP_IT_DESKTOP_SHORTCUT=1` may add a Desktop `.lnk`. A maintainer decides whether taskbar-pin guidance belongs in WINDOWS.md. |

### Lifecycle primitives — macOS vs Windows

The load-bearing table. Each row is a contract step that steps 2.2–2.4 must
implement and step 3.1's CI must (where a Mac can) exercise. The third column is
what only a Windows maintainer can settle.

| Concern | macOS (today, proven) | Windows (beta scaffold) | Must be validated by a Windows maintainer |
| --- | --- | --- | --- |
| **Launch the dev server** | `run-template.sh`: augment PATH, pre-flight the binary + `node_modules`, scan `[PORT..PORT+50]` for a free port, `setsid bash -c "$START_COMMAND"` with `PORT` env, record `server.pid` / `server.port` under `~/Library/Application Support/app-it/<slug>/`. | `run-template.ps1`: augment PATH (nvm-windows, fnm, Volta, Scoop shims, `pnpm`), pre-flight, scan for a free port, start the dev server as a **child inside a Win32 Job Object** with `$env:PORT`, record `server.pid` / `server.port` under `%LOCALAPPDATA%\app-it\<slug>\`. | Free-port scan is race-free under the real Windows TCP stack (`System.Net.Sockets.TcpListener` bind-probe is likely more reliable than `Get-NetTCPConnection`, which only lists *existing* connections). PATH augmentation covers the version managers Windows devs actually use. |
| **Hold the port (keep the server alive)** | `setsid` detaches the dev server from the wrapper's process group, so it **survives the wrapper exiting** — SIGHUP can't reach it. The server is a true daemon; the wrapper reattaches by port on relaunch. | The dev server lives **inside the host's Job Object**, not detached. Its lifetime is anchored to the host process (which stays resident, tray-hidden, across soft-closes). Job Objects are nested-aware on Windows 8+, so `npm → node → vite` stays inside the job and can't leak. | **The load-bearing divergence.** macOS keeps the server warm even across a full wrapper exit; the Windows job-bound server dies when the host dies. Is the orphan-safe job model the right trade, or does a maintainer want a truly-detached daemon (named-pipe broker) to match macOS warm-keep across full quits? **Beta picks job-bound** — orphan-safety over exact parity. |
| **Soft-close vs hard-quit** | `windowShouldClose` sets `quittingViaWindowClose`; `applicationShouldTerminate` reads it. Red-X / ⌘W → leave server warm. ⌘Q → kill server. AppKit's lifecycle drives it, not a guessed signal. | WPF `Window.Closing` with `e.Cancel = true` → **hide to tray** (soft-close). Explicit **Quit** (tray-menu "Quit", optionally `Ctrl+Shift+Q`) → dispose the Job Object → server dies, port freed. Requires `Application.ShutdownMode = OnExplicitShutdown` (not `OnLastWindowClose`), or closing the window would terminate everything. | Windows has **no first-class OS distinction** between "close this window" and "quit this app" — the X button is ambiguous and many Windows users expect X = quit. Does silent minimize-to-tray on X surprise them? Is a tray-only Quit discoverable enough? **Beta: X/minimize = soft-close to tray; Quit only from the tray menu.** A maintainer judges the convention. |
| **Port-clean on quit** | `killServer()` (⌘Q) and `desktop-quit.sh` stop the recorded PID tree **only when ownership is proven** — the recorded `ps -o lstart=` identity still matches, or (legacy state) the recorded tree owns the recorded listener. A reused/foreign PID is left alone; no blind `lsof \| kill` port sweep. | Disposing the Job Object with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` **atomically reaps the whole tree** — no signal cascade. `desktop-quit.ps1` is the defensive fallback and applies the **same ownership proof**: it stops the recorded PID tree only when the `server.identity` token (the dev server's `StartTime` as a UTC FILETIME) still matches, or (legacy state) the recorded tree owns the recorded listener. It no longer stops whatever happens to own the recorded port. | Job teardown reaps grandchildren (vite → esbuild workers) on real hardware with no breakaway, and the ownership proof stops an orphaned dev-server tree **while leaving an unrelated process on the same port alone**. `Get-Process().StartTime` and `Get-NetTCPConnection`'s `OwningProcess` behave as assumed on real hardware. |
| **Warm relaunch** | New `run` reattaches to the surviving daemon via pid → descendant-walk → port → HTTP gate (~250 ms vs multi-second cold start). | **Single-instance** via a named `Mutex` + named pipe: a second launch signals the resident (tray-hidden) host to re-show its window **instantly**. "Warm" = the host is still resident, so the server never left its job — no reattach-to-detached-server needed. After a reboot or full quit, it's a cold start (same as macOS once `server.pid` is dead). | Single-instance mechanism choice (**named `Mutex` + named pipe** for the beta, vs `WM_COPYDATA` or a single-instance NuGet), re-show latency, focus-stealing, and multi-monitor placement on real hardware. |

**Why the answer to "how does WPF tell close from quit" is a contract, not a
guess:** WPF doesn't get the distinction for free the way AppKit does. We
manufacture it: `ShutdownMode = OnExplicitShutdown` + `Window.Closing` cancels
and hides + a tray "Quit" disposes the job. That triple is the Windows reading of
ADR 0004, and steps 2.2/2.3 must wire exactly it.

**Who owns the Job Object (the seam between steps 2.2 and 2.3).** macOS spawns
the server in the bash `run` script and then `exec`s the wrapper into the same
process. Windows has no equivalent — and a Job Object dies when the process that
*created* it exits. So the contract is: **the WPF host (`wrapper-windows`, step
2.2) creates and owns the Job Object and spawns the dev server into it.** A
Job Object created by a short-lived PowerShell launcher would close — and kill
the server — the instant that script returned. `run-template.ps1` (step 2.3) is
therefore the **thin bootstrap**: augment PATH, pre-flight, scan for a free port,
then launch the host with the resolved `START_COMMAND` + `PORT`; the host does
the job-wrapped spawn. The one exception is the **Edge `--app=` fallback**, where
there is no WPF host — there `run-template-edge.ps1` owns the job itself and
accepts the macOS-Chrome-fallback warts (no clean close-vs-quit; `desktop-quit.ps1`
is the primary shutdown). The host and the bootstrap launcher must not both try to own the job.

### Signing — unsigned, SmartScreen click-through documented

Unsigned, like the macOS plugin's ad-hoc local signing. On first run, Windows
SmartScreen shows "Windows protected your PC"; the user clicks **More info → Run
anyway** once and Windows remembers. This one-time click-through is **documented
in `docs/WINDOWS.md`** (the Windows analog of the macOS Gatekeeper first-launch
note). Self-signed certificates are *more* friction than benefit for a personal
local launcher — they still trip SmartScreen reputation checks while adding cert
lifecycle overhead — so we skip them. Real code signing is out of scope (mirrors
"no notarized distribution" on the macOS side).

### Icons — multi-resolution `.ico` from PNG/SVG

`desktop-icons.ps1` produces a multi-resolution `.ico` (the Windows `.icns`)
from a source PNG or SVG, containing at minimum **16 / 32 / 48 / 256** px. Adding
**64 and 128** is nearly free in the `.ico` container and helps mid-DPI taskbar
and Start Menu rendering — the icon step (2.4) may include them. **ImageMagick**
is used when present (fast, clean SVG rasterization); a **`System.Drawing`**
PowerShell fallback keeps it working on stock Windows with nothing installed.
`placeholder-icon-gen.ps1` generates a placeholder `.ico` so the build never
fails on a missing icon — the same guarantee `placeholder-icon-gen.sh` gives the
`.icns` path.

> Note for the build/CI lane: `System.Drawing.Common` is Windows-only on .NET 8.
> That's fine here — this is a Windows-only project and the fallback only ever
> runs on Windows hosts / `windows-latest` CI. It must never be invoked from the
> macOS side.

### Config — same schema, optional `platform.windows` block

The Windows plugin reads the **same `app-it.config.json` schema** as macOS
(`name`, `slug`, `port`, `start_command`, `bundle_id`, `version`, …), so the
mental model and most fields are identical. An **optional `platform.windows`
block** carries Windows-only specifics without polluting the shared schema:

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

The block is optional and every field has a default; a macOS config opened on
Windows still works. `bundle_id` is retained as a stable per-app key even though
Windows has no LaunchServices — it namespaces state/log paths the same way.

### Deferred to a Windows maintainer

Every item below is a decision or verification a Mac user **cannot honestly make
from a Mac**. The scaffold encodes a defensible default; only a maintainer on
real hardware can confirm or correct it. WINDOWS.md turns this list into the
contributor's checklist.

1. **X-closes-to-tray vs X-quits.** Whether minimize-to-tray on the X button
   matches Windows users' expectations, or surprises them. (Lifecycle, row 3.)
2. **Job Object actually reaps the full tree** — vite/esbuild grandchildren, no
   breakaway, no leaked port on quit. (Lifecycle, row 4.)
3. **Warm-keep model is acceptable** — job-bound server (dies with the resident
   host) vs a truly-detached daemon matching macOS. (Lifecycle, row 2.)
4. **Single-instance re-show** actually feels instant, steals focus correctly,
   and lands on the right monitor. (Lifecycle, row 5.)
5. **SmartScreen first-run flow** appears as documented and "Run anyway" sticks.
6. **WebView2 Evergreen runtime present** on a clean Windows install (it ships
   with Win11 and recent Win10, but is not guaranteed) — and the fallback
   bootstrapper behaves.
7. **Self-contained single-file `.exe` runs on a machine with no .NET** — the
   whole point of choosing self-contained.
8. **`.lnk` lands in the Start Menu** and its icon renders in taskbar and Start
   (Windows icon-cache quirks).
9. **`.ico` renders crisply at each DPI**, and the `System.Drawing` fallback's
   quality is acceptable next to the ImageMagick path.
10. **Per-monitor-v2 / high-DPI scaling** of the WebView2 host looks right.
11. **Antivirus / Defender false-positives** on an unsigned, self-published
    single-file `.exe`.
12. **Edge `--app=` fallback** taskbar identity and close behavior.
13. **PATH augmentation** covers the Windows version managers in real use.

## Alternatives considered

- **A cross-platform plugin spanning macOS + Windows.** Rejected for the same
  reason 0002 gave: the hard parts don't transfer. `WKWebView`/`.app`/`.icns`/
  `lsof` have no shared abstraction with WebView2/`.lnk`/`.ico`/Job Objects that
  isn't a lowest-common-denominator lie. Sibling plugins keep both promises
  honest.
- **WinUI 3 host.** Deferred, not rejected — see the native-shell table. Beta
  values stability over modern styling.
- **MSIX packaging / code signing / Microsoft Store.** Out of scope; too heavy
  for a personal local launcher (consistent with the macOS side rejecting
  installers and notarization).
- **A truly-detached daemon (named-pipe broker) for exact macOS warm-keep
  parity.** Deferred to a maintainer — the orphan-safe job model is the safer
  beta default (lifecycle row 2).

## Consequences

- The Windows host has a concrete contract: WPF + WebView2 host, the
  `ShutdownMode=OnExplicitShutdown` + `Closing`-hides + tray-Quit lifecycle
  triple, Job-Object port lifetime, multi-res `.ico`, shared config + optional
  `platform.windows` block. The `windows-latest` CI lane exercises what a Mac
  can't (PowerShell lint, `dotnet build`, manifest parse, placeholder-icon
  round-trip). WINDOWS.md is seeded directly from the
  "deferred to a maintainer" list.
- Every public artifact (README callout, COMPATIBILITY row, WINDOWS.md,
  CHANGELOG, the Windows SKILL.md `description`) must read **beta · scaffolded ·
  untested on real hardware · maintainer wanted.** Nothing claims Windows works
  until a maintainer has dogfooded it.
- 0002 stays accepted and unedited; this ADR narrows its scope to "macOS-only
  *for the proven `plugins/app-it/` lane*," with the Windows lane now a labeled
  beta beside it.
