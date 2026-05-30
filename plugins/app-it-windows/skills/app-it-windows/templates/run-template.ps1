# macOS sibling: run-template.sh — the native-shell launcher. (macOS: ensures
#   the dev server is up, then execs the Swift WebKit wrapper. Windows: the thin
#   bootstrap that hands off to the WPF + WebView2 host.)
#
# Windows beta · scaffolded · untested on real hardware · maintainer wanted.
#
# THIN BOOTSTRAP, BY CONTRACT (ADR 0005). macOS spawns the dev server in this
# script and `exec`s the wrapper into the same process. Windows can't: a Job
# Object dies when the process that *created* it exits, so a short-lived
# PowerShell launcher must NOT own the job, or the server would die the instant
# this script returns. Therefore:
#
#   * The WPF host (wrapper-windows, step 2.2) creates and OWNS the Job Object,
#     spawns the dev server into it, runs the readiness probe, owns
#     single-instance (named Mutex + named pipe) and the soft-close-vs-quit
#     lifecycle. The host stays resident (tray-hidden) across soft-closes.
#   * THIS script only: augments PATH, pre-flights the binary + node_modules,
#     scans for a free port, then launches the host with the resolved
#     START_COMMAND + PORT and exits. It does NOT create a Job Object, does NOT
#     probe readiness, does NOT reattach — the resident host handles relaunch.
#
# Steps 2.2 and 2.3 must not both own the job. The Edge fallback
# (run-template-edge.ps1) is the one exception: no host there, so that script
# owns the job itself.
#
# Host CLI handoff (the seam with step 2.2 — these flag names match
# wrapper-windows' HostConfig.Resolve exactly):
#   <App Name>.exe --url <url> --title <name> --slug <slug> --port <port>
#                  --start-command <cmd> --working-dir <path> [--icon <ico>]
#
# 127.0.0.1 vs 0.0.0.0 (OPEN QUESTION, same shape as macOS): we probe the
# loopback interface only and export HOST=127.0.0.1. A non-loopback listener
# trips the Windows Defender Firewall prompt on first run (the Windows analog of
# the macOS firewall prompt); loopback never does. A local launcher is never
# meant to be reachable off-box, so loopback-only is correct.
#
### TEMPLATE-DOCS-START
# Substituted by desktop-build.ps1 (this block is stripped from the generated
# run.ps1 by Expand-Template, so the real values never leak into its comments):
#   __APP_NAME__       human display name (e.g. "Momo Studio")
#   __APP_SLUG__       file-safe slug (e.g. "momo-studio")
#   __PROJECT_ROOT__   absolute path to the repo (baked at build time)
#   __PORT__           PREFERRED port; if taken, scan upward [PORT..PORT+50]
#   __START_COMMAND__  command to start the dev server from PROJECT_ROOT; must
#                      honor the PORT env var (Vite needs it via CLI:
#                      `npm run dev -- --port $env:PORT`).
### TEMPLATE-DOCS-END

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$AppName       = '__APP_NAME__'
$AppSlug       = '__APP_SLUG__'
$ProjectRoot   = '__PROJECT_ROOT__'
$PreferredPort = [int]'__PORT__'
$StartCommand  = '__START_COMMAND__'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HostExe   = Join-Path $ScriptDir "$AppName.exe"

Add-Type -AssemblyName System.Windows.Forms

# --- PATH augmentation -------------------------------------------------------
# A Start-Menu / double-click launch starts with a bare PATH. Cover the version
# managers Windows devs actually use (ADR 0005, lifecycle row 1 - a maintainer
# confirms the real-world set): nvm-windows, fnm, Volta, Scoop shims, pnpm.
$pathParts = @(
    (Join-Path $env:APPDATA 'nvm'),
    (Join-Path $env:LOCALAPPDATA 'fnm_multishells'),
    (Join-Path $env:LOCALAPPDATA 'Volta\bin'),
    (Join-Path $env:USERPROFILE 'scoop\shims'),
    (Join-Path $env:LOCALAPPDATA 'pnpm'),
    "$env:ProgramFiles\nodejs"
) | Where-Object { Test-Path $_ }
if ($pathParts) { $env:Path = ($pathParts -join ';') + ';' + $env:Path }

# Loopback-only: see header note.
$env:HOST = '127.0.0.1'

# --- Project-root sanity -----------------------------------------------------
if (-not (Test-Path $ProjectRoot)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Project repo not found at:`n$ProjectRoot`n`nThe launcher was built against a path that no longer exists (repo moved). Re-run the build from the canonical repo location.",
        "$AppName failed to launch") | Out-Null
    exit 1
}

# --- Host present? -----------------------------------------------------------
if (-not (Test-Path $HostExe)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Native host missing at:`n$HostExe`n`nRun the build to (re)publish it, or rebuild in Edge-fallback mode.",
        "$AppName failed to launch") | Out-Null
    exit 1
}

# --- Pre-flight: required binary present? -------------------------------------
$firstBin = ($StartCommand -split '\s+')[0]
if ($firstBin -and -not (Get-Command $firstBin -ErrorAction SilentlyContinue)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Required binary not found on PATH:`n$firstBin`n`nThe launcher's PATH covers nvm-windows, fnm, Volta, Scoop, pnpm and Program Files\nodejs. Install the tool or adjust start_command.",
        "$AppName can't start") | Out-Null
    exit 1
}

# --- Pre-flight: node_modules present? ---------------------------------------
if ($StartCommand -match '^(npm|pnpm|yarn|bun|bunx|npx)\b') {
    if (-not (Test-Path (Join-Path $ProjectRoot 'node_modules'))) {
        [System.Windows.Forms.MessageBox]::Show(
            "node_modules is missing in:`n$ProjectRoot`n`nRun an install there, then click again.",
            "$AppName can't start") | Out-Null
        exit 1
    }
}

# --- Free-port scan (loopback TcpListener bind-probe) ------------------------
# ADR 0005: binding 127.0.0.1 with a TcpListener is more reliable than reading
# Get-NetTCPConnection (which only lists *existing* connections). The host's
# single-instance logic means a second launch just re-shows the resident window
# and ignores this port, so passing a fresh port is harmless if unused.
function Test-PortFree {
    param([int]$Port)
    $l = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    try { $l.Start(); return $true } catch { return $false } finally { $l.Stop() }
}
$chosenPort = $null
for ($p = $PreferredPort; $p -le ($PreferredPort + 50); $p++) {
    if (Test-PortFree -Port $p) { $chosenPort = $p; break }
}
if (-not $chosenPort) {
    [System.Windows.Forms.MessageBox]::Show(
        "Searched $PreferredPort-$($PreferredPort + 50). Quit something using one of those ports and try again.",
        "$AppName couldn't find a free port") | Out-Null
    exit 1
}

# --- Hand off to the resident host -------------------------------------------
# The host owns the Job Object, spawns the dev server into it with $env:PORT,
# probes readiness, and renders WebView2. We launch and exit; the host is now
# the app's foreground process (its own taskbar identity and .ico).
#
# Flag names are the seam with wrapper-windows' HostConfig.Resolve (step 2.2):
#   --url --title --icon --slug --port --start-command --working-dir
# The host REQUIRES --url and never derives the working dir from its own path,
# so we pass the resolved loopback URL + PROJECT_ROOT explicitly. Splatting
# (@hostArgs) keeps each element a distinct argv entry — no manual quoting.
$url = "http://127.0.0.1:$chosenPort"
$hostArgs = @(
    '--url',           $url,
    '--title',         $AppName,
    '--slug',          $AppSlug,
    '--port',          "$chosenPort",
    '--start-command', $StartCommand,
    '--working-dir',   $ProjectRoot
)
$IconPath = Join-Path $ScriptDir "$AppName.ico"
if (Test-Path $IconPath) { $hostArgs += @('--icon', $IconPath) }

& $HostExe @hostArgs
