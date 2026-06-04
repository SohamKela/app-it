# 0008 - Existing-bundle adoption stays out of scope

**Status:** Accepted

## Context

App It already has Strategy B for projects that own an Electron, Tauri, or NW.js
desktop path. In that case, the desktop wrapper is part of the source project:
the agent can inspect the repo, use the existing scripts/config, and keep the
project's runtime and storage model under the project's control.

A different request is to point App It at an already-built local `.app`, copy it,
rename it, harden it, or migrate it into App It's launcher model. That is
attractive because it sounds like a shortcut for "make this existing thing feel
like my daily-use app," but the observable bundle is not enough evidence to
know how the app owns data, cookies, profiles, permissions, update channels,
signing expectations, helper tools, or embedded services.

## Decision

Do not add public generic existing-bundle adoption to App It.

App It should build launchers from project source, static build output, or a
project-owned desktop configuration. It should not copy, mutate, wrap, or
"harden" arbitrary installed `.app` bundles as a public workflow.

The only supported existing-desktop path remains Strategy B: if the target
project itself contains Electron, Tauri, NW.js, or equivalent desktop config,
use that project-owned path deliberately. If the only input is an installed
bundle, App It should treat it as out of scope and explain that the source
project or a normal rebuild path is required.

## Observable Classification

Inspection may use narrow labels for diagnostics only:

- **App It-generated:** bundle/state/config markers created by this repo's
  templates are present and consistent.
- **Project-owned desktop path:** the source repo contains inspectable
  Electron, Tauri, NW.js, or equivalent config and scripts.
- **Unknown bundle:** an installed `.app` exists, but App It cannot prove its
  ownership model from bundle contents alone.

Those labels must not imply that App It can safely adopt the bundle, preserve
profiles, migrate cookies, repair signing, or manage updates.

## Alternatives Considered

- **Generic copy-and-harden command.** Rejected: it would make App It responsible
  for storage migration, signing shape, embedded helper behavior, update
  channels, and app-specific assumptions it cannot verify from the bundle.
- **Best-effort Electron/Tauri/Nativefier detection from bundle files.**
  Rejected as a public workflow: bundle internals can hint at a framework, but
  they do not prove the original project contract or the user's intended data
  boundary.
- **Private migration recipe.** Rejected for the public plugin. A one-off local
  rescue can be done manually by a maintainer, but it should not become product
  surface or appear in the skill as a general promise.

## Consequences

- This decision is a deliberate no-op: record it and add no adoption tooling.
- App It keeps its simple contract: additive, reversible launchers generated
  from a project the agent can inspect.
- Documentation can still tell users with existing Electron/Tauri/NW.js project
  configs to use Strategy B.
- Diagnostics may say "unknown bundle" or "project-owned desktop path," but they
  must not offer storage/cookie migration or arbitrary `.app` adoption.
