#!/usr/bin/env pwsh
# Generates <App Name>.ico from assets/<slug>-icon.{png,svg} for one app.
#
# v2 parity with desktop-icons.sh (macOS sibling):
#   1. Mtime-aware: skip regen when the .ico is newer than the source file.
#      When the source is newer, clears the intermediate cache so the rebuild
#      actually runs.
#   2. Honors APP_IT_PROJECT_ROOT (worktree workflow); helper script lives
#      next to desktop-build.ps1, project artifacts go to APP_IT_PROJECT_ROOT.
#   3. Two code paths — same output, different tooling:
#        ImageMagick (magick)   — fast, handles both PNG and SVG sources.
#        System.Drawing fallback — stock Windows, PNG sources only.
#          Uses PNG-in-ICO containers (supported since Windows Vista).
#
# Sizes baked into the .ico container (ADR 0005):
#   16, 32, 48  — taskbar and legacy DPI contexts
#   64, 128     — mid-DPI taskbar / Start Menu (cheap to include, noticeably
#                 better than upscaling 48 or 256; included by default)
#   256         — high-DPI / "open with" dialogs, explorer thumbnails
#
# Required env: APP_NAME, APP_SLUG. APP_NAME may include non-ASCII.
# Honors APP_IT_PROJECT_ROOT (worktree workflow).
#
# Windows beta · scaffolded · untested on real hardware · maintainer wanted.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root      = if ($env:APP_IT_PROJECT_ROOT) {
    $env:APP_IT_PROJECT_ROOT
} else {
    (Resolve-Path (Join-Path $ScriptDir '..')).Path
}

$AppName = if ($env:APP_NAME) { $env:APP_NAME } else {
    throw 'must set APP_NAME (e.g. "My App")'
}
$AppSlug = if ($env:APP_SLUG) { $env:APP_SLUG } else {
    throw 'must set APP_SLUG (e.g. "my-app")'
}

# --- Locate source icon (same fallback chain as macOS desktop-icons.sh) -------
$SrcPng = $null
foreach ($candidate in @(
    (Join-Path $Root "assets\$AppSlug-icon.png"),
    (Join-Path $Root 'assets\app-icon.png')
)) {
    if (Test-Path $candidate) { $SrcPng = $candidate; break }
}
$SrcSvg = $null
foreach ($candidate in @(
    (Join-Path $Root "assets\$AppSlug-icon.svg"),
    (Join-Path $Root 'assets\app-icon.svg')
)) {
    if (Test-Path $candidate) { $SrcSvg = $candidate; break }
}

if (-not $SrcPng -and -not $SrcSvg) {
    Write-Error (
        "No source icon for $AppSlug.`n" +
        "  Looked at: assets\$AppSlug-icon.{png,svg}, assets\app-icon.{png,svg}`n" +
        "  Run scripts\placeholder-icon-gen.ps1 to create one, or drop a`n" +
        "  1024x1024 PNG/SVG at one of those paths."
    )
    exit 1
}

$OutDir    = Join-Path $Root "assets\icons\$AppSlug"
$AppOutDir = Join-Path $Root "desktop\$AppName"
$Ico       = Join-Path $AppOutDir "$AppName.ico"

# Canonical source for mtime comparison: prefer PNG over SVG.
$SourceRef = if ($SrcPng) { $SrcPng } else { $SrcSvg }

# --- Mtime-aware short-circuit ------------------------------------------------
if ((Test-Path $Ico) -and
    (Get-Item $Ico).LastWriteTimeUtc -gt (Get-Item $SourceRef).LastWriteTimeUtc) {
    Write-Host "Icon up-to-date: $Ico"
    exit 0
}

# Source changed — clear the intermediate cache so the rebuild actually runs
# (cached size PNGs would short-circuit the resize loop).
if (Test-Path $OutDir) { Remove-Item -Recurse -Force $OutDir }
New-Item -ItemType Directory -Force -Path $OutDir   | Out-Null
New-Item -ItemType Directory -Force -Path $AppOutDir | Out-Null

# ICO sizes (see header comment for rationale).
[int[]]$Sizes = @(16, 32, 48, 64, 128, 256)

# --- ImageMagick path ---------------------------------------------------------
if (Get-Command magick -ErrorAction SilentlyContinue) {
    Write-Host "Building .ico for $AppSlug (ImageMagick, sizes: $($Sizes -join ', '))"

    # Rasterize SVG to a 1024-wide PNG master. PNG sources go straight to resize.
    if ($SrcSvg -and -not $SrcPng) {
        $master = Join-Path $OutDir 'source-1024.png'
        & magick -background none -density 300 $SrcSvg -resize '1024x1024' $master
        if ($LASTEXITCODE -ne 0) {
            Write-Error "magick SVG rasterization failed for $SrcSvg"; exit 1
        }
    } else {
        $master = $SrcPng
    }

    # Pre-scale to a clean 1024 master so all sizes resample from the same source.
    $master1024 = Join-Path $OutDir 'icon_1024.png'
    & magick $master -resize '1024x1024' $master1024
    if ($LASTEXITCODE -ne 0) { Write-Error "magick resize to 1024 failed"; exit 1 }

    # Generate per-size PNGs (kept in OutDir for potential debug / cache use).
    $sizePngs = [System.Collections.Generic.List[string]]::new()
    foreach ($size in $Sizes) {
        $out = Join-Path $OutDir "icon_$size.png"
        & magick $master1024 -resize "${size}x${size}" $out
        if ($LASTEXITCODE -ne 0) { Write-Error "magick resize to $size failed"; exit 1 }
        $sizePngs.Add($out)
    }

    # Assemble multi-resolution .ico in one shot.
    & magick @($sizePngs) $Ico
    if ($LASTEXITCODE -ne 0) { Write-Error "magick .ico assembly failed"; exit 1 }

    Write-Host "Generated: $Ico"
    exit 0
}

# --- System.Drawing fallback --------------------------------------------------
# Works on stock Windows. Requires PNG source; SVG rasterization needs magick.
Write-Host 'ImageMagick not found - using System.Drawing fallback (PNG only).'

if (-not $SrcPng) {
    Write-Error (
        "System.Drawing fallback requires a PNG source (found only SVG: $SrcSvg).`n" +
        "Install ImageMagick to enable SVG support: https://imagemagick.org/script/download.php`n" +
        "Or place a 1024x1024 PNG at assets\$AppSlug-icon.png and run again."
    )
    exit 1
}

Add-Type -AssemblyName System.Drawing

# Normalize source to a 1024-square PNG master (catches JPEG-in-.png mislabels
# the same way macOS's sips -s format png normalization does).
$srcBitmap  = [System.Drawing.Bitmap]::new($SrcPng)
$master1024 = [System.Drawing.Bitmap]::new(1024, 1024)
$g = [System.Drawing.Graphics]::FromImage($master1024)
$g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.DrawImage($srcBitmap, 0, 0, 1024, 1024)
$g.Dispose()
$srcBitmap.Dispose()

# Render each size to a PNG byte buffer and save the per-size file.
$pngBuffers = [System.Collections.Generic.List[byte[]]]::new()
foreach ($size in $Sizes) {
    $bmp = [System.Drawing.Bitmap]::new($size, $size)
    $gr  = [System.Drawing.Graphics]::FromImage($bmp)
    $gr.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gr.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $gr.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gr.DrawImage($master1024, 0, 0, $size, $size)
    $gr.Dispose()

    # Save intermediate PNG for debug / cache parity with the ImageMagick path.
    $bmp.Save((Join-Path $OutDir "icon_$size.png"), [System.Drawing.Imaging.ImageFormat]::Png)

    $ms = [System.IO.MemoryStream]::new()
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngBuffers.Add($ms.ToArray())
    $ms.Dispose()
    $bmp.Dispose()
}
$master1024.Dispose()

# Assemble .ico: header + directory + image data.
# Using PNG-in-ICO containers (Windows Vista+). All images are 32-bit RGBA PNG.
# ICO format: https://en.wikipedia.org/wiki/ICO_(file_format)
$count      = $Sizes.Count
$dataOffset = 6 + $count * 16  # 6-byte header + N × 16-byte directory entries

$icoStream = [System.IO.MemoryStream]::new()
$bw        = [System.IO.BinaryWriter]::new($icoStream)

# Header (6 bytes)
$bw.Write([uint16]0)      # reserved, must be 0
$bw.Write([uint16]1)      # type = 1 (ICO)
$bw.Write([uint16]$count) # number of images

# Directory entries (16 bytes each)
$offset = $dataOffset
for ($i = 0; $i -lt $count; $i++) {
    $sz  = $Sizes[$i]
    $len = $pngBuffers[$i].Length
    # Width/height: 0 encodes 256 in the ICO format.
    $bw.Write([byte]$(if ($sz -ge 256) { 0 } else { $sz }))
    $bw.Write([byte]$(if ($sz -ge 256) { 0 } else { $sz }))
    $bw.Write([byte]0)         # color palette count (0 = no palette)
    $bw.Write([byte]0)         # reserved
    $bw.Write([uint16]1)       # color planes
    $bw.Write([uint16]32)      # bits per pixel
    $bw.Write([uint32]$len)    # image data size
    $bw.Write([uint32]$offset) # image data offset from file start
    $offset += $len
}

# Image data (PNG blobs in order)
foreach ($buf in $pngBuffers) { $bw.Write($buf) }

$bw.Flush()
[System.IO.File]::WriteAllBytes($Ico, $icoStream.ToArray())
$bw.Dispose()
$icoStream.Dispose()

Write-Host "Generated: $Ico  (System.Drawing, sizes: $($Sizes -join ', '))"
