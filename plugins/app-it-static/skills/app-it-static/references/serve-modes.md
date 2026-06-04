# Serve Modes

`server` is the default because it gives the build a real `http://127.0.0.1`
origin and handles framework paths. `file` is an optimization only when the
build proves it can run from `file://`.

## Decision Tree

```text
Build needs an http origin?
  absolute asset paths, client routing, fetch(), or service worker
    yes -> server
    no  -> file candidate
```

## Server Mode

Use `run-template-static-server.sh` plus `static-server.py`.

Strengths:

- Handles absolute asset paths such as `/assets/...`.
- Handles SPA fallback to `index.html`.
- Gives local `fetch()` calls a real origin.
- Supports service-worker-capable builds.

Cost: a tiny Python process while the app is warm, usually around 15 MB.

## File Mode

Use `run-template-static-file.sh` only when all four are true:

- Asset paths are relative, not `/assets/...`.
- No client-side routing requires deep-link fallback.
- No `fetch()` of local files.
- No service worker.

Do not edit app source just to force file mode. If a build wants an origin, give
it the tiny server and document the memory trade-off.
