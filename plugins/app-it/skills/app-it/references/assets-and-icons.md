# Assets And Icons

Pick one app icon source per app. The user should have one obvious file to
replace later.

## Discovery Order

1. `manifest.json`, `app/manifest.*`, or `static/manifest.json`; prefer the
   largest declared icon with `any` or `maskable` purpose.
2. Dedicated app icons near the app: `app-icon.*`, `app_icon.*`, `appicon.*`,
   `icon.png`, `icon.svg`, `icon@*.png`, `.icns`, `.ico`.
3. High-resolution square logos: `logo.*`, `brand.*`, `mark.*`,
   `logo-square.*`, `logo-mark.*`.
4. SVG logos that rasterize cleanly to a square.
5. Larger favicons: `favicon.svg`, `favicon-512.png`, `apple-touch-icon.png`,
   `android-chrome-*`.
6. Brand-token placeholder from `placeholder-icon-gen.sh`.
7. Last-resort initial-letter placeholder.

Prefer SVG over PNG over JPG/WebP over ICO when quality is equal.

## Rejection Rules

- Reject zero-byte or tiny placeholder files.
- Reject sources below 256 px unless nothing better exists.
- Prefer 1024 x 1024; 512 x 512 is acceptable.
- Require a square final canvas; pad non-square marks, do not crop.
- Prefer marks over wordmarks, because wordmarks smear in the Dock.
- Reject per-feature content icons when filenames map to `src/features/<name>/`.

## Preview

Run `desktop-icons-preview.sh` before committing to a source. It writes
`assets/icons/<slug>/preview.html` and `preview.png`, shows the icon at real
Dock/Finder sizes on light and dark backgrounds, and prints local warnings for
padding, contrast, size, and distortion.

You can preview a candidate before wiring it:

```bash
./scripts/desktop-icons-preview.sh path/to/candidate.png
```

If every real source previews poorly, generate a brand-token placeholder and
preview that.

## Later Replacement

Tell the user to replace `assets/<slug>-icon.png` or SVG, optionally run the
preview script, then run icons, build, and install. The install script refreshes
Dock and Finder icon caches.
