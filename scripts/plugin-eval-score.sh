#!/usr/bin/env bash
# Local release gate for plugin-eval source scores.
#
# Runs the deterministic coverage generator first so plugin-eval sees fresh
# coverage artifacts under the plugin roots. This stays out of normal PR CI
# because plugin-eval is a local Codex plugin tool, not a repo dependency.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$ROOT/reports/plugin-eval/latest}"
PLUGIN_EVAL="${PLUGIN_EVAL:-}"

cd "$ROOT"

"$ROOT/scripts/coverage.sh"

if [ -z "$PLUGIN_EVAL" ]; then
  for candidate in "$HOME"/.codex/plugins/cache/openai-curated/plugin-eval/*/scripts/plugin-eval.js; do
    if [ -f "$candidate" ]; then
      PLUGIN_EVAL="$candidate"
      break
    fi
  done
fi

if [ -z "$PLUGIN_EVAL" ] || [ ! -f "$PLUGIN_EVAL" ]; then
  echo "error: plugin-eval.js not found; install/enable the Plugin Eval plugin or set PLUGIN_EVAL=/path/to/plugin-eval.js" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

for plugin in app-it app-it-static app-it-windows; do
  out="$OUT_DIR/$plugin.json"
  node "$PLUGIN_EVAL" analyze "$ROOT/plugins/$plugin" --format json > "$out"
  node - "$out" "$plugin" <<'NODE'
const fs = require("fs");
const report = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const plugin = process.argv[3];
const summary = report.summary || {};
const deductions = (summary.deductions || [])
  .map((item) => item.id)
  .join(", ");
console.log(`${plugin}: ${summary.score}/100 ${summary.grade || ""}${deductions ? ` (${deductions})` : ""}`);
NODE
done

echo "plugin-eval reports: $OUT_DIR"
