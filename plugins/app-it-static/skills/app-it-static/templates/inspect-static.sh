#!/bin/bash
# Phase 1 inspection for /app-it-static. Read-only.
#
# Detects whether a project is a FINISHED / buildable static app, what command
# builds it, where the output lands, and whether the build can be loaded over
# file:// (zero server) or needs the tiny static server — so the agent can serve
# the build without ever starting a dev server.
#
# Usage:
#   ./scripts/inspect-static.sh
#   /path/to/templates/inspect-static.sh
#   APP_IT_PROJECT_ROOT=/path/to/repo ./scripts/inspect-static.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "${APP_IT_PROJECT_ROOT:-}" ]; then
    ROOT="$APP_IT_PROJECT_ROOT"
elif [ "$(basename "$SCRIPT_DIR")" = "templates" ] && [ -f "$SCRIPT_DIR/../SKILL.md" ]; then
    ROOT="$(pwd)"
else
    ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
cd "$ROOT"

sec() { echo; echo "=== $1 ==="; }

sec "Repo location"
echo "ROOT: $ROOT"

sec "Package manager"
PM="npm"
if [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
elif [ -f "yarn.lock" ]; then PM="yarn"
elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then PM="bun"
fi
echo "  detected: $PM  (from lockfile)"

sec "Framework / build-output detection"
/usr/bin/python3 - "$PM" <<'PY'
import json, os, sys, re

pm = sys.argv[1]

def build(script):
    # yarn omits "run"; everyone else keeps it.
    return f"{pm} {script}" if pm == "yarn" else f"{pm} run {script}"

pkg = {}
if os.path.exists("package.json"):
    try:
        pkg = json.load(open("package.json"))
    except Exception:
        pkg = {}
deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
scripts = pkg.get("scripts", {})
def has(*names):
    return any(n in deps for n in names)

rows = []  # (framework, build_command, output_dir, note)

if has("vite") or any(os.path.exists(f) for f in ("vite.config.ts", "vite.config.js", "vite.config.mjs")):
    rows.append(("Vite", build("build"), "dist",
                 "Vite defaults to ABSOLUTE asset paths (/assets/...). Set base:'./' in vite.config for file:// mode; otherwise use serve_mode 'server'."))
if has("react-scripts"):
    rows.append(("Create React App", build("build"), "build",
                 "CRA uses absolute /static/ paths. Add \"homepage\": \".\" to package.json for file:// mode; otherwise 'server'."))
if has("next") or any(os.path.exists(f) for f in ("next.config.js", "next.config.ts", "next.config.mjs")):
    export = False
    for cfg in ("next.config.js", "next.config.ts", "next.config.mjs"):
        if os.path.exists(cfg):
            txt = open(cfg, encoding="utf-8", errors="ignore").read()
            if re.search(r"output\s*:\s*['\"]export['\"]", txt):
                export = True
    if export:
        rows.append(("Next.js (static export)", build("build"), "out",
                     "output:'export' detected — servable as static. Client routing needs serve_mode 'server'."))
    else:
        rows.append(("Next.js (NO static export)", "n/a", "n/a",
                     "No output:'export'. Next needs a Node runtime for SSR/ISR — this is NOT a static app. Use /app-it (dev server), or add output:'export' and re-run."))
if has("astro"):
    astro_ssr = False
    for cfg in ("astro.config.mjs", "astro.config.js", "astro.config.ts"):
        if os.path.exists(cfg):
            txt = open(cfg, encoding="utf-8", errors="ignore").read()
            if re.search(r"output\s*:\s*['\"](server|hybrid)['\"]", txt):
                astro_ssr = True
    if astro_ssr:
        rows.append(("Astro (SSR: output server/hybrid)", "n/a", "n/a",
                     "output:'server'/'hybrid' needs a Node runtime — NOT static. Use /app-it, or set output:'static' and re-run."))
    else:
        rows.append(("Astro", build("build"), "dist",
                     "Static by default (output:'static'). Client routing needs serve_mode 'server'."))
if has("@sveltejs/adapter-static"):
    rows.append(("SvelteKit (adapter-static)", build("build"), "build",
                 "adapter-static → fully static output."))
elif has("@sveltejs/kit"):
    rows.append(("SvelteKit (no static adapter?)", build("build"), "build",
                 "No adapter-static found — may need a Node server. Confirm the adapter before serving statically."))
if has("@vue/cli-service"):
    rows.append(("Vue CLI", build("build"), "dist",
                 "publicPath defaults to '/' — set to './' for file:// mode."))
if has("@angular/cli", "@angular-devkit/build-angular"):
    rows.append(("Angular", build("build"), "dist/<project>",
                 "Output is dist/<project-name>/browser on Angular 17+. Point static_dir at the folder holding index.html."))
if has("nuxt"):
    rows.append(("Nuxt", build("generate"), ".output/public",
                 "STATIC only via 'nuxi generate' (the 'generate' script) → .output/public. Plain 'nuxt build' is SSR (Nitro) — use /app-it for that."))

if not rows and os.path.exists("index.html"):
    rows.append(("Plain static site", "(no build)", ".",
                 "Root index.html, no build step. Strong file:// candidate."))
if not rows:
    rows.append(("Unknown", "(unknown)", "(unknown)",
                 "No known static build tool detected. If a built folder already exists, point static_dir at it; otherwise this may not be a static app — consider /app-it."))

for fw, cmd, out, note in rows:
    print(f"  - {fw}")
    print(f"      build_command: {cmd}")
    print(f"      static_dir:    {out}")
    print(f"      note:          {note}")
PY

sec "Existing build output already on disk?"
FOUND_BUILD=0
# NOTE: no bare public/ here — for every framework above it's the SOURCE
# static-input folder (serving public/index.html ships an unbuilt template).
# .output/public (Nuxt) and dist/spa (Quasar) ARE real build outputs.
for d in dist build out ".output/public" "dist/spa"; do
    if [ -d "$ROOT/$d" ] && [ -f "$ROOT/$d/index.html" ]; then
        echo "  ✓ $d/  (has index.html — can be served as-is; consider skipping the build)"
        FOUND_BUILD=1
    fi
done
[ "$FOUND_BUILD" = "0" ] && echo "  (none with a top-level index.html — a build step is likely needed first)"

sec "file:// safety probe (only meaningful when a build already exists)"
PROBED=0
for d in dist build out ".output/public" "dist/spa"; do
    IDX="$ROOT/$d/index.html"
    [ -f "$IDX" ] || continue
    PROBED=1
    ABS="$(grep -oE '(src|href)="/[^"]*"' "$IDX" 2>/dev/null | head -3 || true)"
    # Look for a service worker / web-app manifest anywhere in the build dir, not
    # just index.html — modern PWAs (vite-plugin-pwa, Workbox) register the SW
    # from a hashed bundle, so an index.html-only grep misses them.
    SW="$(grep -oE 'serviceWorker|navigator\.serviceWorker' "$IDX" 2>/dev/null | head -1 || true)"
    [ -z "$SW" ] && SW="$(find "$ROOT/$d" -maxdepth 2 \( -name 'sw.js' -o -name 'service-worker.js' -o -name 'workbox-*.js' -o -name '*.webmanifest' \) -type f 2>/dev/null | head -1)"
    if [ -n "$ABS" ]; then
        echo "  $d/index.html uses ABSOLUTE asset paths → serve_mode \"server\":"
        echo "$ABS" | sed 's/^/        /'
    else
        echo "  $d/index.html has no absolute asset paths → file:// candidate (still verify routing + fetch + service workers)."
    fi
    [ -n "$SW" ] && echo "        ⚠ service worker referenced — service workers do NOT register on file://; use \"server\"."
done
[ "$PROBED" = "0" ] && echo "  (no build on disk yet — default to serve_mode \"server\"; re-probe after the first build)"

sec "Toolchain"
for c in swiftc python3 node "$PM"; do
    command -v "$c" >/dev/null 2>&1 && echo "  $c → $(command -v "$c")"
done
command -v swiftc >/dev/null 2>&1 || echo "  ⚠ swiftc missing — needed for the native shell. Install: xcode-select --install"

sec "Recent commit subjects (project-name vocabulary)"
git -C "$ROOT" log --pretty=%s -8 2>/dev/null | sed 's/^/  /' || echo "  (no git history)"

echo
echo "=== End of inspection ==="
echo "Default to serve_mode \"server\" (tiny static-server.py, ~15 MB, SPA-aware)."
echo "Use \"file\" (zero server) only when the build is confirmed file://-safe."
