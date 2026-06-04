# Ports And Worktrees

Runtime truth beats build-time intent. The launcher may choose a fallback port,
and the recorded supervisor PID may not be the actual listener.

## Worktree Strategy

When inspection reports a worktree, choose one:

- Bypass worktree and write to the main checkout. Preferred when App It tooling
  is unrelated to the worktree branch.
- Use `APP_IT_PROJECT_ROOT` to build scripts from the worktree while baking the
  persistent main checkout path.
- Bake the worktree only when the user explicitly chose that tradeoff; document
  that the app must be rebuilt after the worktree is pruned.

Never derive `PROJECT_ROOT` from the installed app path. The `.app` is copied to
`~/Applications/App It/`; bake a persistent absolute path at build time.

## Runtime Port Truth

The launcher starts with a preferred port. By default,
`port_mode: "fallback"` scans upward for a free port and records the actual
runtime port to:

```text
~/Library/Application Support/app-it/<slug>/server.port
```

Read that file before curling or checking ownership. Do not hardcode the
preferred port in verification.

Use `port_mode: "fixed"` only when the app must keep exactly one localhost
origin, for example browser storage, OAuth callbacks, or unmovable project
config. In fixed mode, a busy preferred port is an intentional launch failure.
The launcher does not fall back because `http://localhost:3000` and
`http://localhost:3001` are different browser-storage origins.

## Hardcoded Port Literals

If a dev script contains `-p 3002` or `--port 5173`, the framework may ignore
the launcher `PORT` env. Prefer one of:

- Bypass the script with a direct binary call such as
  `pnpm exec next dev --hostname 127.0.0.1 --port "$PORT"`.
- Add a `dev:app-it` script without the literal.
- For Vite single-server apps, pass CLI flags:
  `npm run dev -- --host 127.0.0.1 --port "$PORT" --strictPort`.

If a proxy target or backend port is hardcoded, route to A3 and make ports
env-driven with minimal config edits.

## Framework Port Cheat Sheet

| Framework | Behavior | App It command shape |
| --- | --- | --- |
| Next.js | reads `PORT`; exits if busy | direct binary for flaggy scripts: `pnpm exec next dev --hostname 127.0.0.1 --port "$PORT"` |
| Vite | config literals can override env | pass `--host 127.0.0.1 --port "$PORT" --strictPort` |
| SvelteKit | Vite-backed | same Vite flags |
| Astro | accepts `--port` | pass `--host 127.0.0.1 --port "$PORT"` |
| CRA | reads `PORT` | normal script is usually fine |
| Express | usually reads `PORT` | for A3 backend, read `API_PORT` first |
| Flask | reads `PORT`/`FLASK_RUN_PORT` | normal module command is usually fine |

Recommended package-manager invocations:

- pnpm direct binary: `pnpm exec <bin> <args>`
- npm direct binary: `npm exec -- <bin> <args>`
- yarn direct binary: `yarn exec <bin> <args>`
- bun direct binary: `bunx <bin> <args>`
- npm/pnpm script flags: `<pm> run dev -- <framework flags>`
- python: `python -m <module>`

For Next.js, prefer the direct binary when the `dev` script already contains
`next dev`, `-p`, `--port`, `--hostname`, a shell chain, or an orchestrator.
`pnpm dev -- --port "$PORT"` can work for a plain script, but it is easier to
misread and easier for wrappers to swallow. Direct binary keeps App It's flags
attached to Next itself.

## Env-Driven Cohabiting Servers

For A3.2:

- Frontend port reads `PORT`.
- Backend port reads `API_PORT`.
- Frontend proxy target reads `API_PORT`.
- Vite gets `strictPort: true`.
- Backend entrypoint reads `API_PORT` before `PORT` so `.env` files cannot
  accidentally override the launcher.

These edits are allowed because they make the existing project runnable from
the Dock while preserving terminal defaults.

## Collision Policy

Do not passively attach to a server that merely responds on the preferred port.
If the listener is not owned by App It's recorded supervisor tree, scan upward
and start App It's own process. The cost of attaching to the wrong project is
showing unrelated UI inside the user's app window.

If fixed proxy/port literals are intentionally unmovable, refuse to start on
collision and write a clear report note.
