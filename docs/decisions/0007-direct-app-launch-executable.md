# 0007 - Direct app launch executable shape

**Status:** Accepted

## Context

The campaign started with a product-risk finding: a generated `Vite Basic.app`
could verify with `codesign --verify --deep --strict`, but direct execution of
`Contents/MacOS/run` returned `137` with no output. The same generated launcher
worked when invoked as `bash Contents/MacOS/run`, and a copied-out copy of that
script also worked. A small shell script inside a signed `.app` worked too.

That prior reproduction rules out a blanket "shell scripts cannot be inside
signed app bundles" explanation. It points at the generated launcher as a
shell-script `CFBundleExecutable` being the fragile surface: the script content,
bundle execution context, or macOS policy around that combination can fail
before the launcher writes useful logs.

## Reproduction Notes

A reproduction attempt from a clean `HEAD` archive of the repo could not
reproduce the `137` on the same host:

```text
codesign --verify --deep --strict "Vite Basic.app" -> 0
file "Vite Basic.app/Contents/MacOS/run" -> Bourne-Again shell script text executable, with very long lines
APP_IT_SMOKE=1 "Vite Basic.app/Contents/MacOS/run" -> 0
APP_IT_SMOKE=1 bash "Vite Basic.app/Contents/MacOS/run" -> 0
APP_IT_SMOKE=1 "./copied-run" -> 0
lsof -ti tcp:41000-41080 -> none
```

The native-stub shape also passed the same headless smoke:

```text
file "Vite Basic.app/Contents/MacOS/run" -> Mach-O 64-bit executable arm64
file "Vite Basic.app/Contents/MacOS/run.sh" -> Bourne-Again shell script text executable, with very long lines
codesign --verify --deep --strict "Vite Basic.app" -> 0
APP_IT_SMOKE=1 "Vite Basic.app/Contents/MacOS/run" -> 0
APP_IT_SMOKE=1 bash "Vite Basic.app/Contents/MacOS/run.sh" -> 0
lsof -ti tcp:41000-41080 -> none
```

So the exact `137` trigger is not stable enough to reduce to one macOS subsystem.
The product risk is still clear: the generated app should not make
the shell script itself the bundle executable when a tiny native bootstrap can
remove that Launch Services edge without changing server lifecycle behavior.

## Decision

Keep `CFBundleExecutable` as `run`, but make `Contents/MacOS/run` a tiny Mach-O
bootstrap whenever a local C compiler is available. Move the real launcher script
to `Contents/MacOS/run.sh`; the native `run` locates `run.sh` next to itself and
`execv`s it with the original argv and environment.

This keeps the existing bash launcher as the source of lifecycle truth while
giving Finder, Dock, Launch Services, and direct execution a normal native app
entrypoint.

If the C compiler is unavailable, fall back to the older shell-as-`run` shape
with a visible warning. That preserves App It's "works with system tools" promise
on constrained machines, while the fixture suite should make the preferred
native shape visible on normal macOS developer machines.

## Regression Shape

The smallest durable automated check is:

```text
build the vite-basic fixture
assert Info.plist CFBundleExecutable == run
assert Contents/MacOS/run exists and `file` reports Mach-O
assert Contents/MacOS/run.sh exists and contains the substituted launcher
run APP_IT_SMOKE=1 "Contents/MacOS/run" and expect rc 0
verify server.port, server.pid, ownership, HTTP response, warm reattach, and desktop:quit cleanup
```

That check protects click-to-open better than only linting the shell script,
because it exercises the generated bundle path users actually click.

## Launch Services Probe

This investigation did not open the bundle through Finder or `open`, because a
normal launch can create a GUI window. The release/manual smoke probe should use
a non-GUI environment, then immediately unset it:

```bash
launchctl setenv APP_IT_SMOKE 1
open -W -n "desktop/Vite Basic.app"
launchctl unsetenv APP_IT_SMOKE
```

If that returns non-zero while direct `Contents/MacOS/run` succeeds, the remaining
bug is Launch Services-specific. If both succeed, the native bootstrap has closed
the practical click-to-open risk.

## Consequences

- `desktop-build.sh` owns one more generated product surface: the native run
  bootstrap.
- `desktop:doctor` and fixture output should describe `run` as the native entry
  point and `run.sh` as the launcher script.
- `app-it-static` should use the same executable shape so the sibling plugin does
  not keep the weaker shell bundle entrypoint.
- The launcher scripts remain bash and keep the existing port truth, warm
  relaunch, Chrome fallback, worktree override, and cleanup contracts.
