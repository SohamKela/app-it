#!/bin/bash
# Stop the tiny static servers spawned by app-it-static launchers, plus any open
# wrapper windows. file:// apps have no server — only a window to close.
#
# Reads scripts/app-it.config.json (app-it-static schema). The static server is
# a single Python process (no re-parenting children), so cleanup is simpler than
# app-it's dev-server case. Same ownership discipline as app-it's quit, though:
# stop the recorded PID tree only when we can PROVE we own it — the recorded
# start-time still matches (new state), or the recorded tree genuinely owns the
# recorded listener (legacy state). A reused or foreign PID is left alone and the
# recorded files are treated as stale.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${APP_IT_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_FILE="$SCRIPT_DIR/app-it.config.json"

# Record per app: name|slug|serve_mode|preferred_port
APPS=()
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] && APPS+=("$line")
    done < <(/usr/bin/python3 - "$CONFIG_FILE" <<'PY'
import json, re, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
for a in cfg.get("apps", []):
    name = a.get("name", "")
    slug = a.get("slug") or re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    print(f'{name}|{slug}|{a.get("serve_mode","server")}|{a.get("port","") or ""}')
PY
)
else
    echo "ERROR: scripts/app-it.config.json not found." >&2
    exit 1
fi

if [ "${#APPS[@]}" -eq 0 ]; then
    echo "ERROR: no apps configured." >&2
    exit 1
fi

is_live_pid() {
    local pid="${1:-}"
    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    kill -0 "$pid" 2>/dev/null
}

read_first_line() {
    local file="$1"
    [ -f "$file" ] || return 0
    sed -n '1p' "$file" 2>/dev/null || true
}

# Start-time identity — proves a recorded PID is still OUR server and not a
# recycled PID the OS handed to something unrelated. Mirrors app-it's quit gate.
pid_identity() {
    local pid="${1:-}"
    case "$pid" in
        ''|*[!0-9]*) return 1 ;;
    esac
    ps -o lstart= -p "$pid" 2>/dev/null | awk '{$1=$1; print}'
}

pid_identity_matches() {
    local pid="$1"
    local file="$2"
    local recorded current
    [ -f "$file" ] || return 1
    recorded="$(read_first_line "$file")"
    current="$(pid_identity "$pid" || true)"
    [ -n "$recorded" ] && [ "$recorded" = "$current" ]
}

descendant_tree() {
    local supervisor="${1:-}"
    is_live_pid "$supervisor" || return 0

    local descendants="$supervisor"
    local current="$supervisor"
    local next_gen _pid
    for _ in 1 2 3 4; do
        next_gen=""
        for _pid in $current; do
            next_gen="$next_gen $(pgrep -P "$_pid" 2>/dev/null | tr '\n' ' ')"
        done
        [ -z "${next_gen// /}" ] && break
        descendants="$descendants $next_gen"
        current="$next_gen"
    done
    printf '%s\n' "$descendants"
}

pid_in_list() {
    local needle="$1"
    local haystack="$2"
    case " $haystack " in
        *" $needle "*) return 0 ;;
        *) return 1 ;;
    esac
}

listeners_owned_by_tree() {
    local tree="$1"
    local port="${2:-}"
    [ -n "$tree" ] || return 0
    [ -n "$port" ] || return 0

    local listeners pid owned=""
    listeners="$(lsof -ti tcp:"$port" 2>/dev/null || true)"
    for pid in $listeners; do
        if pid_in_list "$pid" "$tree"; then
            owned="$owned $pid"
        fi
    done
    printf '%s\n' "$owned"
}

term_pids() {
    local pid
    for pid in "$@"; do
        [ -n "$pid" ] || continue
        [ "$pid" = "$$" ] && continue
        kill -TERM "$pid" 2>/dev/null || true
    done
}

kill_pids() {
    local pid
    for pid in "$@"; do
        [ -n "$pid" ] || continue
        [ "$pid" = "$$" ] && continue
        kill -KILL "$pid" 2>/dev/null || true
    done
}

still_live_pids() {
    local pid still=""
    for pid in "$@"; do
        is_live_pid "$pid" && still="$still $pid"
    done
    printf '%s\n' "$still"
}

stop_owned_runtime() {
    local pid_file="$1"
    local port_file="$2"
    local preferred_port="${3:-}"
    local identity_file="${4:-}"

    local recorded_pid recorded_port tree owned_listeners ports port pids_to_stop still ownership_ok
    recorded_pid="$(read_first_line "$pid_file")"
    recorded_port="$(read_first_line "$port_file")"

    if is_live_pid "$recorded_pid"; then
        tree="$(descendant_tree "$recorded_pid")"
        pids_to_stop="$tree"
        ownership_ok=0

        ports="$recorded_port"
        if [ -n "$preferred_port" ] && [ "$preferred_port" != "$recorded_port" ]; then
            ports="$ports $preferred_port"
        fi
        for port in $ports; do
            owned_listeners="$(listeners_owned_by_tree "$tree" "$port")"
            pids_to_stop="$pids_to_stop $owned_listeners"
            # Legacy state (no identity file): the only proof we have is that the
            # recorded PID tree genuinely owns the recorded listener.
            [ -n "${owned_listeners// /}" ] && [ ! -f "$identity_file" ] && ownership_ok=1
        done

        # New state: the recorded PID's start-time still matches — it is our
        # server, not a recycled PID. This is the proof that defeats PID reuse.
        if pid_identity_matches "$recorded_pid" "$identity_file"; then
            ownership_ok=1
        fi

        if [ "$ownership_ok" = "1" ]; then
            term_pids $pids_to_stop
            for _ in 1 2 3; do
                still="$(still_live_pids $pids_to_stop)"
                [ -z "${still// /}" ] && break
                sleep 0.5
            done
            still="$(still_live_pids $pids_to_stop)"
            [ -n "${still// /}" ] && kill_pids $still
            CLOSED_ANY=1
        else
            # Live PID we cannot prove we own (reused/foreign): leave it alone,
            # treat the recorded files as stale.
            STALE_ANY=1
        fi
    elif [ -f "$pid_file" ] || [ -f "$port_file" ]; then
        STALE_ANY=1
    fi

    rm -f "$pid_file" "$port_file"
    [ -n "$identity_file" ] && rm -f "$identity_file"
}

CLOSED_ANY=0
STALE_ANY=0
for entry in "${APPS[@]}"; do
    IFS='|' read -r APP_NAME APP_SLUG SERVE_MODE PREFERRED_PORT <<<"$entry"
    [ "$SERVE_MODE" = "file" ] && continue   # no server to stop
    STATE_DIR="$HOME/Library/Application Support/app-it/$APP_SLUG"
    PID_FILE="$STATE_DIR/server.pid"
    PORT_FILE="$STATE_DIR/server.port"
    PID_ID_FILE="$STATE_DIR/server.identity"
    stop_owned_runtime "$PID_FILE" "$PORT_FILE" "$PREFERRED_PORT" "$PID_ID_FILE"
done

# Native WebKit wrapper windows. Server-mode wrappers carry the generated
# pid-file argument; file:// wrappers have no pid-file, so fall back to the
# bundle executable path for that zero-server case.
for entry in "${APPS[@]}"; do
    IFS='|' read -r APP_NAME APP_SLUG SERVE_MODE _ <<<"$entry"
    STATE_DIR="$HOME/Library/Application Support/app-it/$APP_SLUG"
    PID_FILE="$STATE_DIR/server.pid"
    for p in $(pgrep -f "MacOS/wrapper " 2>/dev/null); do
        cmdline="$(ps -o command= -p "$p" 2>/dev/null || true)"
        if [ "$SERVE_MODE" = "file" ]; then
            # Anchor on the bundle dir ("<AppName>.app/Contents/MacOS/wrapper")
            # so an app named "Fjord" can't also match "Fjord Studio".
            match="$APP_NAME.app/Contents/MacOS/wrapper"
        else
            match="$PID_FILE"
        fi
        if echo "$cmdline" | grep -qF "$match"; then
            kill -TERM "$p" 2>/dev/null || true
            CLOSED_ANY=1
        fi
    done
done

if [ "$CLOSED_ANY" = "1" ] && [ "$STALE_ANY" = "1" ]; then
    echo "Stopped owned App It static servers/windows and cleaned stale state."
elif [ "$CLOSED_ANY" = "1" ]; then
    echo "Stopped owned App It static servers/windows."
elif [ "$STALE_ANY" = "1" ]; then
    echo "Cleaned stale App It static state; no owned server was running."
else
    echo "Already clean — no App It static servers or windows were running."
fi
