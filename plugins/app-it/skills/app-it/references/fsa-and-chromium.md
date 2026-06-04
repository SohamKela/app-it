# FSA And Chromium-Only APIs

WebKit does not implement File System Access. Decide whether the app only needs
a remembered folder handle or true browser-side file I/O.

## Two-Stage Search

Stage 1: any FSA usage:

```bash
rg -n "showDirectoryPicker|FileSystemDirectoryHandle|FileSystemFileHandle" src services app
```

Stage 2: real I/O that the polyfill cannot satisfy:

```bash
rg -n "\\.createWritable\\(|\\.getFile\\(\\)|writable\\.write\\(" src services app
```

Stage 1 only can be A1 native plus polyfill. Stage 2 routes to A1 Chrome
fallback or a native wrapper only when a broader OS requirement justifies it.

## Polyfill Use

Use `fsa-polyfill-template.js` only when:

- The app checks for `showDirectoryPicker()`.
- It stores a directory handle in IndexedDB.
- Real reads/writes happen through server APIs, not the JS handle itself.

Steps:

1. Confirm Stage 2 has no real-I/O hits.
2. Find IndexedDB database, store, and key names.
3. Copy the template to `assets/<slug>-polyfill.js`.
4. Substitute workspace path/name and DB/store/key placeholders.
5. Set `polyfill_path` in `scripts/app-it.config.json`.
6. Build, install, and verify reconnect behavior when a display is available.

If app code expects `getDirectoryHandle(..., { create: true })` to produce real
files, pre-create those directories from the build or launcher instead.

## Chromium-Only APIs

Use A1 Chrome fallback for Web USB, Web Bluetooth, Web HID, Web MIDI, File
System Access real I/O, or other Chromium-only runtime dependencies. Document
Chrome-specific limitations in the report.
