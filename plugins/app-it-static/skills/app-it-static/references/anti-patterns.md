# Anti-patterns

- Do not run `npm run dev`. That is `app-it`, not `app-it-static`.
- Do not claim live reload. This serves a snapshot.
- Do not default to file mode for framework builds.
- Do not statically serve a server-rendered Next app without
  `output: 'export'`.
- Do not add runtime dependencies. `static-server.py` uses Python stdlib.
- Do not edit app source to force static serving.
- Do not bind the static server to `0.0.0.0`; use `127.0.0.1`.
- Do not run the project build inside `desktop-build.sh`.
- Do not use `com.$(id -un).*` bundle IDs.
- Do not derive `PROJECT_ROOT` from `$0`; installed apps move away from the repo.
