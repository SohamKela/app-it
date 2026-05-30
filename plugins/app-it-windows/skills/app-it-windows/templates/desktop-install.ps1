# macOS sibling: desktop-install.sh — installs every built launcher into the
#   user's app folder. (macOS: copies desktop\*.app into ~/Applications/App It/,
#   a Dock Stack. Windows: creates a Start Menu .lnk per app under an "app-it"
#   Programs folder — the Windows equivalent of that one-folder Dock Stack.)
#
# Windows beta · scaffolded · untested on real hardware · maintainer wanted.
#
# Per ADR 0005 the shortcut lands at:
#   %APPDATA%\Microsoft\Windows\Start Menu\Programs\app-it\<App Name>.lnk
# created with the WScript.Shell COM object. The folder ("app-it") is the
# Windows reading of ~/Applications/App It/.
#
# Honors APP_IT_INSTALL_DIR — same override the macOS install script honors —
# to redirect the install target (e.g. a Desktop folder or a custom Start Menu
# subfolder).
#
# The .lnk targets PowerShell running the per-app run.ps1 (the thin bootstrap),
# NOT the host .exe directly: run.ps1 augments PATH, pre-flights, and scans for
# a free port before handing off to the host (ADR 0005). -WindowStyle Hidden
# keeps the console from showing; a brief flash on slow machines is a documented
# beta wart a maintainer may resolve (e.g. a .vbs shim or conhost tweak).
#
# MAINTAINER (ADR 0005 deferred list): confirm the .lnk lands in the Start Menu,
# its icon renders in taskbar + Start (Windows icon-cache quirks), and SmartScreen
# "Run anyway" sticks on first launch.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root      = if ($env:APP_IT_PROJECT_ROOT) { $env:APP_IT_PROJECT_ROOT } else { (Resolve-Path (Join-Path $ScriptDir '..')).Path }

$defaultTarget = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\app-it'
$target = if ($env:APP_IT_INSTALL_DIR) { $env:APP_IT_INSTALL_DIR } else { $defaultTarget }

if (-not (Test-Path $target)) {
    if ($target -eq $defaultTarget) {
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Write-Host "Created $target."
        Write-Host 'Your apps now appear under "app-it" in the Start Menu. Right-click any one to pin it to Start or the taskbar.'
    } else {
        Write-Error "Install target $target does not exist."
        exit 1
    }
}

# Prefer PowerShell 7 (pwsh) if present, else Windows PowerShell.
$pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshExe) { $pwshExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe' }

$desktop = Join-Path $Root 'desktop'
if (-not (Test-Path $desktop)) {
    Write-Error "No desktop\ folder under $Root. Run desktop-build.ps1 first."
    exit 1
}

$wsh = New-Object -ComObject WScript.Shell
$count = 0
foreach ($appDir in Get-ChildItem -Path $desktop -Directory -ErrorAction SilentlyContinue) {
    $runScript = Join-Path $appDir.FullName 'run.ps1'
    if (-not (Test-Path $runScript)) {
        Write-Warning "  skipping $($appDir.Name): no run.ps1 (re-run desktop-build.ps1)."
        continue
    }

    $lnkPath = Join-Path $target "$($appDir.Name).lnk"
    $sc = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath       = $pwshExe
    $sc.Arguments        = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$runScript`""
    $sc.WorkingDirectory = $appDir.FullName
    $sc.Description      = "$($appDir.Name) (app-it)"

    # Icon: the per-app .ico if the icon step produced one; else the host .exe
    # (its embedded icon); else leave PowerShell's default.
    $ico = Join-Path $appDir.FullName "$($appDir.Name).ico"
    $exe = Join-Path $appDir.FullName "$($appDir.Name).exe"
    if (Test-Path $ico)      { $sc.IconLocation = "$ico,0" }
    elseif (Test-Path $exe)  { $sc.IconLocation = "$exe,0" }

    $sc.Save()
    Write-Host "Installed: $lnkPath"
    $count++
}
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh) | Out-Null

if ($count -eq 0) {
    Write-Error "No app folders found under $desktop. Run desktop-build.ps1 first."
    exit 1
}

Write-Host ''
Write-Host "Installed $count shortcut(s) under $target"
