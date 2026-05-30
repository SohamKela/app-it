# macOS sibling: desktop-build.sh — builds the per-app desktop launchers for
#   every entry in scripts/app-it.config.json. Idempotent.
#
# Windows beta · scaffolded · untested on real hardware · maintainer wanted.
#
# Windows reading of the macOS build: instead of a .app bundle per app, produce
#   desktop\<App Name>\
#     <App Name>.exe   — the published WPF + WebView2 host (renamed so the
#                        taskbar/Process name is the app, not "wrapper-windows")
#     <App Name>.ico   — the multi-resolution icon (from the icon step, 2.4)
#     run.ps1          — substituted run-template.ps1: the thin bootstrap the
#                        Start Menu .lnk launches (desktop-install.ps1)
#
# Launcher modes (mirrors macOS swift|chrome):
#   webview2 (default) — build the WPF host with `dotnet publish`; run.ps1 is
#                        the thin bootstrap that launches the host, which owns
#                        the Job Object and spawns the dev server (ADR 0005).
#   edge               — no host; run.ps1 is run-template-edge.ps1, which owns
#                        the Job Object itself. Auto-selected when the .NET SDK
#                        is unavailable (the Windows analog of swiftc-missing ->
#                        Chrome fallback). Force with APP_IT_LAUNCHER_MODE=edge.
#
# Single source of truth — desktop-quit.ps1 reads the same app-it.config.json.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root      = if ($env:APP_IT_PROJECT_ROOT) { $env:APP_IT_PROJECT_ROOT } else { (Resolve-Path (Join-Path $ScriptDir '..')).Path }
$env:APP_IT_PROJECT_ROOT = $Root
$ConfigFile = Join-Path $ScriptDir 'app-it.config.json'

# --- Load apps from JSON (preferred) or a placeholder record (template) -------
$apps = @()
if (Test-Path $ConfigFile) {
    $cfg = Get-Content -Raw $ConfigFile | ConvertFrom-Json
    foreach ($a in $cfg.apps) {
        $name = [string]$a.name
        $slug = if ($a.slug) { $a.slug } else { ($name.ToLower() -replace '[^a-z0-9]+','-').Trim('-') }
        $edgeFallback = $false
        if ($a.PSObject.Properties.Name -contains 'platform' -and $a.platform -and
            $a.platform.PSObject.Properties.Name -contains 'windows' -and $a.platform.windows -and
            $a.platform.windows.PSObject.Properties.Name -contains 'edge_fallback') {
            $edgeFallback = [bool]$a.platform.windows.edge_fallback
        }
        $apps += [pscustomobject]@{
            name          = $name
            slug          = $slug
            port          = [string]$a.port
            start_command = [string]$a.start_command
            version       = if ($a.version) { [string]$a.version } else { '0.1.0' }
            edge_fallback = $edgeFallback
        }
    }
} else {
    Write-Warning 'scripts\app-it.config.json not found - using placeholder record. Copy app-it.config.example.json to scripts\.'
    $apps += [pscustomobject]@{
        name='__APP_NAME__'; slug='__APP_SLUG__'; port='__PORT__';
        start_command='__START_COMMAND__'; version='__VERSION__'; edge_fallback=$false
    }
}
if ($apps.Count -eq 0) { Write-Error 'ERROR: no apps configured. Edit scripts\app-it.config.json.'; exit 1 }

# --- Launcher mode -----------------------------------------------------------
# Default webview2; fall back to edge if the .NET SDK can't build the host.
$globalMode = if ($env:APP_IT_LAUNCHER_MODE) { $env:APP_IT_LAUNCHER_MODE } else { 'webview2' }
$hasDotnetSdk = $false
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    $hasDotnetSdk = [bool](& dotnet --list-sdks 2>$null)
}
if ($globalMode -eq 'webview2' -and -not $hasDotnetSdk) {
    Write-Warning '.NET SDK not found - falling back to the Edge --app launcher for all apps.'
    Write-Warning 'Install the .NET 8 SDK to build the native WebView2 host (https://dotnet.microsoft.com/download).'
    $globalMode = 'edge'
}

$runTemplateWebView2 = Join-Path $ScriptDir 'run-template.ps1'
$runTemplateEdge     = Join-Path $ScriptDir 'run-template-edge.ps1'

# --- Resolve & publish the WPF host once (cached) ----------------------------
# Locate the wrapper-windows .csproj near these templates (step 2.2). Override
# with APP_IT_WRAPPER_CSPROJ. Published self-contained single-file exe is cached
# under assets\build\ and reused unless a source file is newer.
$publishedExe = $null
if ($globalMode -eq 'webview2') {
    $csproj = $null
    if ($env:APP_IT_WRAPPER_CSPROJ -and (Test-Path $env:APP_IT_WRAPPER_CSPROJ)) {
        $csproj = $env:APP_IT_WRAPPER_CSPROJ
    } else {
        # The host project lives at templates\wrapper-windows\wrapper.csproj.
        $csproj = Get-ChildItem -Path $ScriptDir -Recurse -Filter '*.csproj' -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $csproj) {
        Write-Warning 'wrapper-windows .csproj not found - falling back to the Edge --app launcher.'
        Write-Warning 'Set APP_IT_WRAPPER_CSPROJ to the host project if it lives elsewhere.'
        $globalMode = 'edge'
    } else {
        $publishDir = Join-Path $Root 'assets\build\wrapper-windows'
        $projDir = Split-Path -Parent $csproj
        $newestSrc = Get-ChildItem -Path $projDir -Recurse -Include *.cs,*.csproj,*.xaml -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        $existing = if (Test-Path $publishDir) {
            Get-ChildItem -Path $publishDir -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        } else { $null }
        $needsBuild = (-not $existing) -or ($newestSrc -and $newestSrc.LastWriteTimeUtc -gt $existing.LastWriteTimeUtc)
        if ($needsBuild) {
            Write-Host "Publishing WebView2 host: $csproj"
            # Self-contained single-file win-x64 (ADR 0005): one .exe, no runtime install.
            & dotnet publish $csproj -c Release -r win-x64 --self-contained true `
                -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
                -o $publishDir
            if ($LASTEXITCODE -ne 0) {
                Write-Warning 'dotnet publish failed - falling back to the Edge --app launcher.'
                $globalMode = 'edge'
            }
        }
        if ($globalMode -eq 'webview2') {
            # AssemblyName is app-it-host -> app-it-host.exe; fall back to the
            # largest .exe if a maintainer renamed the assembly.
            $publishedExe = Get-ChildItem -Path $publishDir -Filter 'app-it-host.exe' -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName
            if (-not $publishedExe) {
                $publishedExe = Get-ChildItem -Path $publishDir -Filter *.exe -ErrorAction SilentlyContinue |
                    Sort-Object Length -Descending | Select-Object -First 1 -ExpandProperty FullName
            }
            if (-not $publishedExe) {
                Write-Warning 'No .exe produced by dotnet publish - falling back to the Edge --app launcher.'
                $globalMode = 'edge'
            }
        }
    }
}

# --- Substitution helper -----------------------------------------------------
# Strips a TEMPLATE-DOCS block (if present) before substitution so placeholder
# examples inside header comments don't leak substituted values into the built
# run.ps1 (parity with the macOS substitute() helper).
function Expand-Template {
    param([string]$Path, [hashtable]$Map)
    $src = Get-Content -Raw $Path
    $src = [regex]::Replace($src, '### TEMPLATE-DOCS-START.*?### TEMPLATE-DOCS-END\r?\n?', '', 'Singleline')
    foreach ($k in $Map.Keys) { $src = $src.Replace($k, $Map[$k]) }
    return $src
}

# --- Build each app ----------------------------------------------------------
$desktop = Join-Path $Root 'desktop'
foreach ($app in $apps) {
    $appMode = if ($app.edge_fallback -or $globalMode -eq 'edge') { 'edge' } else { 'webview2' }
    $appDir = Join-Path $desktop $app.name
    Write-Host "Building: $appDir  (mode: $appMode)"
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null

    # Host .exe (webview2 mode only): rename to <App Name>.exe so the taskbar
    # entry and process name are the app, not "wrapper-windows".
    if ($appMode -eq 'webview2') {
        Copy-Item -Force -Path $publishedExe -Destination (Join-Path $appDir "$($app.name).exe")
    }

    # Icon: built by the icon step (2.4). Call desktop-icons.ps1 if present
    # (mtime-aware, like the macOS desktop-icons.sh), else note its absence.
    $iconScript = Join-Path $ScriptDir 'desktop-icons.ps1'
    if (Test-Path $iconScript) {
        $env:APP_NAME = $app.name; $env:APP_SLUG = $app.slug
        & $iconScript
    } else {
        $existingIco = Join-Path $appDir "$($app.name).ico"
        if (-not (Test-Path $existingIco)) {
            Write-Warning "  no .ico yet for $($app.name) - run the icon step (desktop-icons.ps1, step 2.4)."
        }
    }

    # run.ps1 — substituted bootstrap the .lnk launches.
    $template = if ($appMode -eq 'edge') { $runTemplateEdge } else { $runTemplateWebView2 }
    $map = @{
        '__APP_NAME__'      = $app.name
        '__APP_SLUG__'      = $app.slug
        '__PROJECT_ROOT__'  = $Root
        '__PORT__'          = $app.port
        '__START_COMMAND__' = $app.start_command
    }
    Expand-Template -Path $template -Map $map | Set-Content -Path (Join-Path $appDir 'run.ps1') -Encoding UTF8
}

Write-Host ''
Write-Host "Built $($apps.Count) app(s) under $desktop  (mode: $globalMode)"
Write-Host '  Install:  pwsh .\scripts\desktop-install.ps1   # creates Start Menu shortcuts'
