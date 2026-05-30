#!/usr/bin/env pwsh
# Last-resort placeholder icon generator. Produces assets/<slug>-icon.svg
# (or .png when ImageMagick is absent) when no usable square brand mark exists.
# Mirrors placeholder-icon-gen.sh exactly: same three motifs, same brand-token
# detection, same output contract.
#
# Strategy menu (in priority order):
#   1. Brand-token-derived SVG + ImageMagick: parse globals.css / tailwind.config
#      for --color-* custom properties, pick accent + background, write a
#      30-line geometric mark. Brand-aligned by construction. ImageMagick renders
#      the SVG for desktop-icons.ps1.
#   2. Brand-token-derived PNG (System.Drawing): same color detection, same
#      motif, drawn programmatically when ImageMagick is absent. Produces a
#      PNG source that the System.Drawing path in desktop-icons.ps1 can consume.
#
# In both cases, desktop-icons.ps1 is called automatically at the end so
# the .ico is immediately ready — the build never fails on a missing icon.
#
# Usage:
#   $env:APP_NAME = "My App"; $env:APP_SLUG = "my-app"; .\placeholder-icon-gen.ps1
#   $env:APP_NAME = "My App"; $env:APP_SLUG = "my-app"; $env:MOTIF = "rings"; .\placeholder-icon-gen.ps1
#   $env:APP_NAME = "My App"; $env:APP_SLUG = "my-app"; $env:ACCENT = "#c8a44e"; $env:VOID = "#08080a"; .\placeholder-icon-gen.ps1
#
# Optional env:
#   MOTIF  = "rings" | "monogram" | "grid"   (default: rings)
#   ACCENT = override accent color (e.g. "#c8a44e")
#   VOID   = override background color (e.g. "#08080a")
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
$Motif = if ($env:MOTIF) { $env:MOTIF } else { 'rings' }

# --- Sniff brand tokens from common locations ---------------------------------
# Mirrors the detect_color() shell function in placeholder-icon-gen.sh.
function Get-BrandColor {
    param([string]$Pattern)
    $searchDirs = @('src','app','public','styles') |
        ForEach-Object { Join-Path $Root $_ } |
        Where-Object { Test-Path $_ }
    if (-not $searchDirs) { return $null }
    $hit = Get-ChildItem -Path $searchDirs -Recurse -File -ErrorAction SilentlyContinue |
        Select-String -Pattern $Pattern -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $hit) { return $null }
    if ($hit.Line -match '(#[0-9a-fA-F]{3,8})') { return $Matches[1] }
    return $null
}

$Accent = if ($env:ACCENT) { $env:ACCENT } else {
    $c = Get-BrandColor '--color-(accent|primary|brand|action)'
    if (-not $c) { $c = Get-BrandColor 'accent.*#' }
    if (-not $c) { $c = '#c8a44e' }
    $c
}
$Void = if ($env:VOID) { $env:VOID } else {
    $c = Get-BrandColor '--color-(bg|background|void|surface|base)'
    if (-not $c) { $c = '#08080a' }
    $c
}

$FirstLetter = ($AppName[0]).ToString().ToUpper()

New-Item -ItemType Directory -Force -Path (Join-Path $Root 'assets') | Out-Null

# --- SVG templates (identical markup to placeholder-icon-gen.sh) --------------
$svgs = @{
    rings    = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" rx="180" fill="$Void"/>
  <circle cx="512" cy="512" r="380" fill="none" stroke="$Accent" stroke-width="10" opacity="0.35"/>
  <circle cx="512" cy="512" r="290" fill="none" stroke="$Accent" stroke-width="14" opacity="0.55"/>
  <circle cx="512" cy="512" r="200" fill="none" stroke="$Accent" stroke-width="18" opacity="0.75"/>
  <circle cx="512" cy="512" r="110" fill="$Accent"/>
</svg>
"@
    monogram = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" rx="180" fill="$Accent"/>
  <text x="512" y="700" font-family="ui-sans-serif, system-ui, -apple-system, sans-serif"
        font-size="640" font-weight="700" fill="$Void" text-anchor="middle">$FirstLetter</text>
</svg>
"@
    grid     = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" rx="180" fill="$Void"/>
  <g fill="$Accent">
    <rect x="220" y="220" width="180" height="180" rx="32" opacity="0.4"/>
    <rect x="420" y="220" width="180" height="180" rx="32" opacity="0.6"/>
    <rect x="620" y="220" width="180" height="180" rx="32" opacity="0.8"/>
    <rect x="220" y="420" width="180" height="180" rx="32" opacity="0.6"/>
    <rect x="420" y="420" width="180" height="180" rx="32" opacity="1.0"/>
    <rect x="620" y="420" width="180" height="180" rx="32" opacity="0.6"/>
    <rect x="220" y="620" width="180" height="180" rx="32" opacity="0.8"/>
    <rect x="420" y="620" width="180" height="180" rx="32" opacity="0.6"/>
    <rect x="620" y="620" width="180" height="180" rx="32" opacity="0.4"/>
  </g>
</svg>
"@
}

if (-not $svgs.ContainsKey($Motif)) {
    Write-Error "Unknown MOTIF '$Motif'. Pick: rings | monogram | grid."
    exit 1
}

$hasMagick = [bool](Get-Command magick -ErrorAction SilentlyContinue)

# --- ImageMagick path: emit SVG, let desktop-icons.ps1 render it --------------
if ($hasMagick) {
    $outSvg = Join-Path $Root "assets\$AppSlug-icon.svg"
    Set-Content -Path $outSvg -Value $svgs[$Motif] -Encoding UTF8
    Write-Host "Generated: $outSvg  (motif: $Motif, accent: $Accent, void: $Void)"
    Write-Host "Replace assets\$AppSlug-icon.svg with a real brand mark when one is available."
} else {
    # --- System.Drawing fallback: draw the motif programmatically into a PNG ---
    # System.Drawing cannot render SVG, so we reproduce the motif in GDI+ code.
    # The SVG is still written (for reference / future use with ImageMagick),
    # but the PNG is what desktop-icons.ps1 will consume via its own fallback path.
    Write-Host 'ImageMagick not found - drawing placeholder PNG with System.Drawing.'

    $outSvg = Join-Path $Root "assets\$AppSlug-icon.svg"
    Set-Content -Path $outSvg -Value $svgs[$Motif] -Encoding UTF8

    Add-Type -AssemblyName System.Drawing

    $sz  = 1024
    $bmp = [System.Drawing.Bitmap]::new($sz, $sz)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    $bgColor     = [System.Drawing.ColorTranslator]::FromHtml($Void)
    $accentColor = [System.Drawing.ColorTranslator]::FromHtml($Accent)

    # Background fill
    $bgBrush = [System.Drawing.SolidBrush]::new($bgColor)
    $g.FillRectangle($bgBrush, 0, 0, $sz, $sz)
    $bgBrush.Dispose()

    $cx = $sz / 2  # center x/y

    switch ($Motif) {
        'rings' {
            # Concentric rings: radii 380, 290, 200, center dot 110 (matches SVG)
            foreach ($ring in @(
                [pscustomobject]@{ r=380; w=10;  op=[int](0.35*255) },
                [pscustomobject]@{ r=290; w=14;  op=[int](0.55*255) },
                [pscustomobject]@{ r=200; w=18;  op=[int](0.75*255) }
            )) {
                $col = [System.Drawing.Color]::FromArgb($ring.op, $accentColor)
                $pen = [System.Drawing.Pen]::new($col, $ring.w)
                $g.DrawEllipse($pen, $cx - $ring.r, $cx - $ring.r, $ring.r * 2, $ring.r * 2)
                $pen.Dispose()
            }
            # Center dot
            $dotBrush = [System.Drawing.SolidBrush]::new($accentColor)
            $g.FillEllipse($dotBrush, $cx - 110, $cx - 110, 220, 220)
            $dotBrush.Dispose()
        }
        'monogram' {
            # Accent background, dark letter
            $acBrush = [System.Drawing.SolidBrush]::new($accentColor)
            $g.FillRectangle($acBrush, 0, 0, $sz, $sz)
            $acBrush.Dispose()
            $font    = [System.Drawing.Font]::new('Arial', 640, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $txtBrush = [System.Drawing.SolidBrush]::new($bgColor)
            $sf = [System.Drawing.StringFormat]::new()
            $sf.Alignment     = [System.Drawing.StringAlignment]::Center
            $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
            $g.DrawString($FirstLetter, $font, $txtBrush, [System.Drawing.RectangleF]::new(0, 0, $sz, $sz), $sf)
            $font.Dispose()
            $txtBrush.Dispose()
            $sf.Dispose()
        }
        'grid' {
            # 3x3 grid of rounded rects with varying opacity (matches SVG)
            $cells = @(
                [pscustomobject]@{ x=220; y=220; op=[int](0.4*255) },
                [pscustomobject]@{ x=420; y=220; op=[int](0.6*255) },
                [pscustomobject]@{ x=620; y=220; op=[int](0.8*255) },
                [pscustomobject]@{ x=220; y=420; op=[int](0.6*255) },
                [pscustomobject]@{ x=420; y=420; op=[int](1.0*255) },
                [pscustomobject]@{ x=620; y=420; op=[int](0.6*255) },
                [pscustomobject]@{ x=220; y=620; op=[int](0.8*255) },
                [pscustomobject]@{ x=420; y=620; op=[int](0.6*255) },
                [pscustomobject]@{ x=620; y=620; op=[int](0.4*255) }
            )
            foreach ($cell in $cells) {
                $col   = [System.Drawing.Color]::FromArgb($cell.op, $accentColor)
                $brush = [System.Drawing.SolidBrush]::new($col)
                # GraphicsPath for a rounded rect (rx=32 in the SVG)
                $path  = [System.Drawing.Drawing2D.GraphicsPath]::new()
                $rx = 32; $cw = 180; $ch = 180
                $path.AddArc($cell.x,          $cell.y,          $rx*2, $rx*2, 180, 90)
                $path.AddArc($cell.x+$cw-$rx*2,$cell.y,          $rx*2, $rx*2, 270, 90)
                $path.AddArc($cell.x+$cw-$rx*2,$cell.y+$ch-$rx*2,$rx*2, $rx*2,   0, 90)
                $path.AddArc($cell.x,          $cell.y+$ch-$rx*2,$rx*2, $rx*2,  90, 90)
                $path.CloseFigure()
                $g.FillPath($brush, $path)
                $brush.Dispose()
                $path.Dispose()
            }
        }
    }

    $g.Dispose()

    $outPng = Join-Path $Root "assets\$AppSlug-icon.png"
    $bmp.Save($outPng, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    Write-Host "Generated: $outPng  (motif: $Motif, accent: $Accent, void: $Void)"
    Write-Host "SVG reference also written: $outSvg"
    Write-Host 'Install ImageMagick for SVG support and cleaner rasterization: https://imagemagick.org/script/download.php'
    Write-Host "Replace assets\$AppSlug-icon.png with a real brand mark when one is available."
}

# --- Run the icon pipeline immediately so the .ico is ready for the build -----
$iconScript = Join-Path $ScriptDir 'desktop-icons.ps1'
if (Test-Path $iconScript) {
    Write-Host ''
    Write-Host "Running desktop-icons.ps1 to produce the .ico..."
    & $iconScript
} else {
    Write-Host ''
    Write-Host "Run scripts\desktop-icons.ps1 to convert the source to .ico, then run desktop-build.ps1."
}
