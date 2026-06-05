# Project Inspection

Run `templates/inspect.sh` from the target project root before editing. It is
read-only and prints the signals that decide the packaging route.

## What To Read From The Inspector

- Repo path and worktree status.
- Disk project type: `package.json`, framework configs, desktop configs,
  Python/Ruby/Rust markers, static `index.html`, manifest/service worker.
- `dev` and `start` script inventory, especially scripts with hardcoded
  `-p`/`--port` values or multi-process orchestrators.
- Framework port literals in config files.
- Claude Artifact URLs and hosted Artifact runtime API usage.
- Two-stage File System Access usage.
- Existing App It sibling apps and current port listeners.
- Toolchain availability, especially `swiftc`.
- Runtime data paths, `.env`/database/cache gitignore entries, and asset
  candidates.
- Recent commit subjects, because they often reveal the user's real app name.

## Worktree Detection

If the inspector reports a worktree, choose the strategy in
`ports-and-worktrees.md` before baking paths. The baked `PROJECT_ROOT` must be a
persistent absolute path.

## Project Type Signals

- Next.js: `next.config.*`, `next` dependency or `next dev`.
- Vite/React: `vite.config.*`, `vite`, `react`, `react-dom`, plugin-react.
- SvelteKit: `svelte.config.*`, `@sveltejs/kit`, Svelte, Vite.
- Astro: `astro.config.*` and `astro`.
- Static: root or build-output `index.html`, no server needed.
- Python web app: `pyproject.toml`, `requirements.txt`, Flask/FastAPI imports.
- Existing desktop: `electron`, `electron-builder`, `src-tauri/`, `nw.js`.
- PWA: `manifest.json` and service worker. Still build a Strategy A `.app` and
  mention PWA install as optional.
- Published/shared Claude Artifact URL: choose Strategy E URL-only.
- Raw Claude Artifact source using `window.claude`, `window.storage`, MCP
  prompts, or Claude-provided auth: block local credential shims and ask for a
  published/shared Artifact URL.

Ignore stale docs when they disagree with the files that actually run.

## Multi-App Detection

Treat as multi-app when there are distinct user-facing apps:

- `apps/*/package.json` or workspace config listing multiple apps.
- Multiple `dev:*` or `start:*` scripts running different UIs on different
  ports.
- Sanity Studio alongside a main app.
- README or recent commits name separate end-user apps.

Treat as single-app when signals are only routes, Storybook/docs/e2e tooling,
server-only `apps/api`, or per-feature icon directories. Per-feature icons often
map to `src/features/<name>/`; those are content marks, not separate apps.

## Cohabiting Frontend And Backend

Route to A3 when a single user-facing app needs a frontend and backend together.
Strong signals:

- `concurrently`, `npm-run-all`, `turbo run dev`, `pnpm -r dev`, or custom
  `scripts/dev.sh`.
- Vite/Next proxy targets pointing at another `localhost:<port>`.
- `server/`, `api/`, or `apps/api` consumed by the frontend.

Reuse an existing orchestrator when it behaves on signals. Use the multi-server
template only when the project lacks a reliable orchestrator or needs separate
frontend/backend ports managed by the launcher.

## Naming

Resolve names in this order:

1. Recent commit subjects and project vocabulary.
2. `package.json` `displayName`.
3. Human-looking `metadata.json` name.
4. Folder name, humanized.
5. `package.json` `name` only when it is not scaffold-shaped.

Reject names containing scaffold patterns like `vite-project`, `next-app`, or
triple-dash slugs. Surface naming conflicts in the report and tell the user
they can edit `scripts/app-it.config.json` then rebuild.

## Bundle IDs

Default to `com.user.<slug>` unless the project has a real domain. Country-code
reverse DNS such as `dk.example.app` is fine. Reject `com.$(id -un).*` because
LaunchServices may reject unsigned bundles claiming that personal-team prefix.

## Framework Recipes

Translate examples to the package manager actually present. Package-script
flags are fine when the script is a thin, boring `dev` target. Prefer the
direct framework binary when the script already names the framework binary with
its own flags, wraps an orchestrator, opens prompts, or hardcodes a port.

| Framework | Preferred port | Start command |
| --- | ---: | --- |
| Next.js | 3000 | `pnpm exec next dev --hostname 127.0.0.1 --port "$PORT"` when scripts hardcode flags or wrap `next dev`; otherwise a plain `dev` script that honors `PORT` is OK |
| Vite + React | 5173 | `npm run dev -- --host 127.0.0.1 --port "$PORT" --strictPort` |
| SvelteKit | 5173 | `npm run dev -- --host 127.0.0.1 --port "$PORT" --strictPort` |
| Astro | 4321 | `npm run dev -- --host 127.0.0.1 --port "$PORT"` |
| Express | app default | reads `PORT`; for A3, prefer `API_PORT` before `PORT` |
| Flask/FastAPI | app default | read `PORT` or framework-specific port env |

If a script opens a TTY prompt, mascot launcher, or interactive setup, bypass it
with the underlying dev-server binary or choose a noninteractive script.

Package-manager command shapes:

- pnpm direct binary: `pnpm exec next dev --hostname 127.0.0.1 --port "$PORT"`.
- npm direct binary: `npm exec -- next dev --hostname 127.0.0.1 --port "$PORT"`.
- yarn direct binary: `yarn exec next dev --hostname 127.0.0.1 --port "$PORT"`.
- bun direct binary: `bunx next dev --hostname 127.0.0.1 --port "$PORT"`.
- npm/pnpm script flags: `<pm> run dev -- --host 127.0.0.1 --port "$PORT"`.

Do not stack App It flags onto a script that already contains `-p`, `--port`,
`--hostname`, `concurrently`, `turbo`, `npm-run-all`, or `pnpm -r` unless you
have verified where that package manager forwards the flags. Add a clean
`dev:app-it` script or use the direct binary instead.
