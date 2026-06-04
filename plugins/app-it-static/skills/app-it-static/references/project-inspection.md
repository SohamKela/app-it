# Project Inspection

Run `templates/inspect-static.sh` first from the target project root. It reports
package manager, framework signals, build commands, output directories, existing
built output, serve-mode hints, and toolchain availability.

## Static-servable Test

Use this skill only when the project can produce files with an `index.html`:

- Framework build output such as `dist/`, `build/`, `out/`, or
  `.output/public/`.
- A hand-written static site with `index.html` at the project root.
- Existing built output the user explicitly wants served as-is.

Route to `app-it` when the app needs a live dev server: standard server-rendered
Next, SvelteKit without `adapter-static`, Astro server/hybrid output, Nuxt
server output, middleware-only local files, external local DB wiring, or a
project whose only working command is `npm run dev`.

## Build-output Detection

Trust config files over README prose.

| Signal | Build command | Output dir | Default |
| --- | --- | --- | --- |
| `vite.config.*` | `<pm> build` | `dist/` | server |
| `astro.config.*` static/default | `<pm> build` | `dist/` | server |
| Astro `server`/`hybrid` | route to app-it | n/a | n/a |
| `react-scripts` | `<pm> build` | `build/` | server |
| SvelteKit + `adapter-static` | `<pm> build` | `build/` | server |
| SvelteKit without `adapter-static` | route to app-it | n/a | n/a |
| Next with `output: 'export'` | `<pm> build` | `out/` | server |
| Next without export | route to app-it | n/a | n/a |
| `vue.config.js` | `<pm> build` | `dist/` | server |
| `angular.json` | `<pm> build` | `dist/<project>/browser/` | server |
| Nuxt via `nuxi generate` | `<pm> generate` | `.output/public/` | server |
| Nuxt plain build | route to app-it | n/a | n/a |
| root `index.html`, no build tool | none | `.` | file candidate |
| existing `dist/`/`build/`/`out/` | optional | that dir | inspect |

Package manager from lockfile: `pnpm-lock.yaml` -> `pnpm build`, `yarn.lock` ->
`yarn build`, `bun.lockb` -> `bun run build`, otherwise `npm run build`.

## Decisions To Make

- Already built? Skip the project build only when the existing output is fresh
  enough for the user's request and contains `index.html`.
- Multi-app? Build one `.app` per user-facing app. Do not bundle unrelated apps.
- Name and bundle ID: use the user's vocabulary; default bundle ID
  `com.user.<slug>`. Never use `com.$(id -un).*`.
- Icon: use the best square app-level source; generated placeholders are last
  resort.
- Toolchain: `swiftc` and `python3` come from Xcode Command Line Tools. If
  either is missing, stop with `xcode-select --install`.
