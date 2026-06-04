#!/bin/bash
# Builds desktop/<AppName>.app bundle(s) that serve a FINISHED static build,
# from scripts/app-it.config.json (app-it-static schema). No dev server is ever
# launched: each app either runs the tiny bundled static-server.py (~15 MB) or,
# when the build is file://-safe, loads straight from disk with no server at all.
#
# This is the static sibling of app-it's desktop-build.sh. It does NOT run your
# project's build — that's an explicit, expensive step (desktop:rebuild, or the
# agent's one-time build during /app-it-static). This script only assembles the
# .app around whatever already lives in static_dir.
#
# Worktree-aware: ROOT honors APP_IT_PROJECT_ROOT.
#
# app-it.config.json shape (static):
# { "apps": [ {
#     "name": "My App", "slug": "my-app",
#     "serve_mode": "server",            // "server" | "file"
#     "static_dir": "dist",              // relative to PROJECT_ROOT, holds index.html
#     "port": 4100,                      // server mode only
#     "bundle_id": "com.user.my-app", "version": "0.1.0",
#     "build_command": "npm run build"   // used by desktop-rebuild.sh, not here
# } ] }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${APP_IT_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
export APP_IT_PROJECT_ROOT="$ROOT"
CONFIG_FILE="$SCRIPT_DIR/app-it.config.json"

# --- Load apps ---------------------------------------------------------
# Record: name|slug|serve_mode|static_dir|port|bundle_id|version
APPS=()
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] && APPS+=("$line")
    done < <(/usr/bin/python3 - "$CONFIG_FILE" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
for a in cfg.get("apps", []):
    fields = [
        a.get("name", ""),
        a.get("slug", ""),
        a.get("serve_mode", "server"),
        a.get("static_dir", "dist"),
        str(a.get("port", "") or ""),
        a.get("bundle_id", ""),
        a.get("version", "0.1.0"),
    ]
    if any("|" in f for f in fields):
        print("ERROR: pipe character in field — refusing to build", file=sys.stderr)
        sys.exit(1)
    print("|".join(fields))
PY
)
else
    echo "ERROR: scripts/app-it.config.json not found." >&2
    echo "       Copy templates/app-it.config.example.json to scripts/ and customize." >&2
    exit 1
fi

if [ "${#APPS[@]}" -eq 0 ]; then
    echo "ERROR: no apps configured in scripts/app-it.config.json." >&2
    exit 1
fi

# --- Bundle-ID validation (same rule as app-it) ------------------------
USER_PREFIX="com.$(id -un | tr 'A-Z' 'a-z')."
for entry in "${APPS[@]}"; do
    IFS='|' read -r _ _ _ _ _ BID _ <<<"$entry"
    BID_LOWER="$(echo "$BID" | tr 'A-Z' 'a-z')"
    case "$BID_LOWER" in
        "$USER_PREFIX"*)
            echo "WARN: bundle_id '$BID' starts with com.\$(id -un). LaunchServices may reject it (error -600). Prefer com.user.<slug>." >&2
            ;;
    esac
done

# --- swiftc required (native shell owns the Dock icon) -----------------
if ! command -v swiftc >/dev/null 2>&1; then
    echo "ERROR: swiftc not found. app-it-static builds a native WebKit shell so the .app keeps its own Dock icon." >&2
    echo "       Install the Xcode Command Line Tools: xcode-select --install" >&2
    exit 1
fi

PLIST_TEMPLATE="$SCRIPT_DIR/info-plist-template.xml"
WRAPPER_SRC="$SCRIPT_DIR/wrapper.swift"
WRAPPER_BUILD="$ROOT/assets/icons/build/wrapper"
RUN_STUB_SRC="$SCRIPT_DIR/native-run-stub.c"
RUN_STUB_BUILD="$ROOT/assets/icons/build/run-stub"
STATIC_SERVER_SRC="$SCRIPT_DIR/static-server.py"
RUN_TEMPLATE_SERVER="$SCRIPT_DIR/run-template-static-server.sh"
RUN_TEMPLATE_FILE="$SCRIPT_DIR/run-template-static-file.sh"

for f in "$PLIST_TEMPLATE" "$WRAPPER_SRC" "$RUN_TEMPLATE_SERVER" "$RUN_TEMPLATE_FILE" "$STATIC_SERVER_SRC" "$RUN_STUB_SRC"; do
    [ -f "$f" ] || { echo "Missing template next to this script: $f" >&2; exit 1; }
done

# --- Compile the native WebKit wrapper (universal, cached) -------------
# Identical strategy to app-it: build arm64 + x86_64 and lipo into a universal
# binary. APP_IT_SWIFT_ARCHS overrides.
mkdir -p "$(dirname "$WRAPPER_BUILD")"
SWIFT_ARCHS="${APP_IT_SWIFT_ARCHS:-arm64,x86_64}"
if [ ! -x "$WRAPPER_BUILD" ] || [ "$WRAPPER_SRC" -nt "$WRAPPER_BUILD" ]; then
    echo "Compiling native wrapper: $WRAPPER_BUILD ($SWIFT_ARCHS)"
    IFS=',' read -r -a ARCH_LIST <<<"$SWIFT_ARCHS"
    ARCH_BINS=()
    for arch in "${ARCH_LIST[@]}"; do
        arch_clean="$(echo "$arch" | tr -d ' ')"
        BIN="$WRAPPER_BUILD.$arch_clean"
        if swiftc "$WRAPPER_SRC" -o "$BIN" \
            -framework Cocoa -framework WebKit \
            -target "$arch_clean-apple-macosx11" 2>/dev/null; then
            ARCH_BINS+=("$BIN")
        else
            echo "WARN: swiftc target $arch_clean failed — skipping." >&2
        fi
    done
    if [ "${#ARCH_BINS[@]}" -eq 0 ]; then
        echo "All targeted archs failed — building for host arch only." >&2
        swiftc "$WRAPPER_SRC" -o "$WRAPPER_BUILD" -framework Cocoa -framework WebKit
    elif [ "${#ARCH_BINS[@]}" -eq 1 ]; then
        mv "${ARCH_BINS[0]}" "$WRAPPER_BUILD"
    else
        lipo -create "${ARCH_BINS[@]}" -output "$WRAPPER_BUILD"
        rm -f "${ARCH_BINS[@]}"
    fi
fi

# --- Compile the native run stub --------------------------------------
# Contents/MacOS/run should be a Mach-O binary for Launch Services solidity.
# The substituted shell launcher lives at run.sh and this stub only execs it.
RUN_STUB_AVAILABLE=0
RUN_STUB_CC="${APP_IT_CC:-$(command -v cc 2>/dev/null || command -v clang 2>/dev/null || true)}"
if [ -n "$RUN_STUB_CC" ]; then
    if [ ! -x "$RUN_STUB_BUILD" ] || [ "$RUN_STUB_SRC" -nt "$RUN_STUB_BUILD" ]; then
        echo "Compiling native run stub: $RUN_STUB_BUILD"
        mkdir -p "$(dirname "$RUN_STUB_BUILD")"
        STUB_ARCHS="${APP_IT_STUB_ARCHS:-${APP_IT_SWIFT_ARCHS:-arm64,x86_64}}"
        IFS=',' read -r -a STUB_ARCH_LIST <<<"$STUB_ARCHS"
        STUB_ARCH_BINS=()
        for arch in "${STUB_ARCH_LIST[@]}"; do
            arch_clean="$(echo "$arch" | tr -d ' ')"
            BIN="$RUN_STUB_BUILD.$arch_clean"
            if "$RUN_STUB_CC" -arch "$arch_clean" -mmacosx-version-min=11.0 "$RUN_STUB_SRC" -o "$BIN" 2>/dev/null; then
                STUB_ARCH_BINS+=("$BIN")
            else
                rm -f "$BIN"
            fi
        done
        if [ "${#STUB_ARCH_BINS[@]}" -eq 0 ]; then
            "$RUN_STUB_CC" "$RUN_STUB_SRC" -o "$RUN_STUB_BUILD"
        elif [ "${#STUB_ARCH_BINS[@]}" -eq 1 ]; then
            mv "${STUB_ARCH_BINS[0]}" "$RUN_STUB_BUILD"
        else
            lipo -create "${STUB_ARCH_BINS[@]}" -output "$RUN_STUB_BUILD"
            rm -f "${STUB_ARCH_BINS[@]}"
        fi
    fi
    RUN_STUB_AVAILABLE=1
else
    echo "ERROR: no C compiler found. app-it-static requires a native run stub for Launch Services." >&2
    exit 1
fi

# --- Substitution helper (strips TEMPLATE-DOCS blocks) -----------------
substitute() {
    /usr/bin/python3 - "$@" <<'PY'
import sys, pathlib, re
src = pathlib.Path(sys.argv[1]).read_text()
src = re.sub(r"### TEMPLATE-DOCS-START.*?### TEMPLATE-DOCS-END\n?", "", src, flags=re.DOTALL)
for arg in sys.argv[2:]:
    key, _, value = arg.partition("=")
    src = src.replace(key, value)
sys.stdout.write(src)
PY
}

# --- Build each app ----------------------------------------------------
for entry in "${APPS[@]}"; do
    IFS='|' read -r APP_NAME APP_SLUG SERVE_MODE STATIC_DIR PORT BUNDLE_ID VERSION <<<"$entry"
    [ -z "$STATIC_DIR" ] && STATIC_DIR="dist"
    [ -z "$SERVE_MODE" ] && SERVE_MODE="server"

    STATIC_PATH="$ROOT/$STATIC_DIR"
    if [ ! -d "$STATIC_PATH" ]; then
        echo "WARN: static_dir not found for $APP_NAME: $STATIC_PATH" >&2
        echo "      The .app will be assembled but won't launch until the build exists (run desktop:rebuild)." >&2
    elif [ ! -f "$STATIC_PATH/index.html" ]; then
        echo "WARN: no index.html in $STATIC_PATH — is this really a built site?" >&2
    fi

    APP_DIR="$ROOT/desktop/${APP_NAME}.app"
    CONTENTS="$APP_DIR/Contents"
    MACOS="$CONTENTS/MacOS"
    RESOURCES="$CONTENTS/Resources"
    echo "Building: $APP_DIR  (serve_mode: $SERVE_MODE, static_dir: $STATIC_DIR)"
    mkdir -p "$MACOS" "$RESOURCES"

    substitute "$PLIST_TEMPLATE" \
        "__APP_NAME__=$APP_NAME" \
        "__BUNDLE_ID__=$BUNDLE_ID" \
        "__VERSION__=$VERSION" \
        > "$CONTENTS/Info.plist"

    RUN_SCRIPT="$MACOS/run.sh"
    if [ "$SERVE_MODE" = "file" ]; then
        substitute "$RUN_TEMPLATE_FILE" \
            "__APP_NAME__=$APP_NAME" \
            "__PROJECT_ROOT__=$ROOT" \
            "__STATIC_DIR__=$STATIC_DIR" \
            > "$RUN_SCRIPT"
    else
        [ -z "$PORT" ] && PORT=4100
        substitute "$RUN_TEMPLATE_SERVER" \
            "__APP_NAME__=$APP_NAME" \
            "__APP_SLUG__=$APP_SLUG" \
            "__PROJECT_ROOT__=$ROOT" \
            "__PORT__=$PORT" \
            "__STATIC_DIR__=$STATIC_DIR" \
            > "$RUN_SCRIPT"
        cp "$STATIC_SERVER_SRC" "$MACOS/static-server.py"
        chmod +x "$MACOS/static-server.py"
    fi
    chmod +x "$RUN_SCRIPT"
    cp "$RUN_STUB_BUILD" "$MACOS/run"
    chmod +x "$MACOS/run"

    cp "$WRAPPER_BUILD" "$MACOS/wrapper"
    chmod +x "$MACOS/wrapper"

    # desktop-icons.sh is mtime-aware and short-circuits when nothing changed.
    APP_NAME="$APP_NAME" APP_SLUG="$APP_SLUG" "$SCRIPT_DIR/desktop-icons.sh"
    touch "$APP_DIR"

    # Ad-hoc code signature (macOS 15+ Gatekeeper). Strip xattrs first.
    /usr/bin/xattr -cr "$APP_DIR" 2>/dev/null || true
    if ! /usr/bin/codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1; then
        echo "  WARN: codesign --sign - failed for $APP_DIR (app may be blocked by Gatekeeper)" >&2
    fi
done

echo
echo "Built ${#APPS[@]} app(s) under $ROOT/desktop/"
echo "  Install:  ./scripts/desktop-install.sh   # copies to ~/Applications/App It/, refreshes Dock"
echo "  Refresh:  ./scripts/desktop-rebuild.sh   # re-runs your build, then build + install"
