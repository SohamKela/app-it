#!/usr/bin/env python3
# Tiny zero-dependency static server for finished builds.
# Keeps app-it-static lightweight by serving dist/build/out from
# http://127.0.0.1:PORT with SPA fallback and strict browser MIME types.
# Do not replace with `python3 -m http.server`: it breaks deep links and can
# serve .mjs/.wasm with stale content types on older systems.
#
# Usage:
#   STATIC_DIR=/abs/path/to/dist PORT=4100 ./static-server.py
#   ./static-server.py /abs/path/to/dist 4100
#
# Binds 127.0.0.1 ONLY — never 0.0.0.0. This is a local launcher, not a host.

import os
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

# Pin strict browser types; everything else uses the stdlib guesser.
EXTRA_TYPES = {
    ".js":          "text/javascript",
    ".mjs":         "text/javascript",
    ".wasm":        "application/wasm",
    ".json":        "application/json",
    ".map":         "application/json",
    ".webmanifest": "application/manifest+json",
}


class StaticHandler(SimpleHTTPRequestHandler):
    """SPA-aware static handler rooted at a fixed directory (set via partial)."""

    def guess_type(self, path):
        _, ext = os.path.splitext(path)
        return EXTRA_TYPES.get(ext.lower()) or super().guess_type(path)

    def send_head(self):
        # SPA fallback only for page navigations; missing assets must still 404.
        # `Accept: text/html` also handles dotted routes like /report/2024.q1.
        path = self.translate_path(self.path)
        if not os.path.exists(path) and "text/html" in self.headers.get("Accept", ""):
            self.path = "/index.html"
        return super().send_head()

    def end_headers(self):
        # Local snapshot: discourage caching so a desktop:rebuild shows up on the
        # next reload instead of serving a stale chunk from the WebKit cache.
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt, *args):
        # One terse line per request to the launcher's server.log (stderr).
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    directory = os.environ.get("STATIC_DIR") or (sys.argv[1] if len(sys.argv) > 1 else ".")
    port_str = os.environ.get("PORT") or (sys.argv[2] if len(sys.argv) > 2 else "4100")
    directory = os.path.abspath(directory)

    if not os.path.isdir(directory):
        sys.stderr.write("static-server: directory not found: %s\n" % directory)
        sys.exit(1)
    try:
        port = int(port_str)
    except ValueError:
        sys.stderr.write("static-server: invalid PORT: %s\n" % port_str)
        sys.exit(1)

    handler = partial(StaticHandler, directory=directory)
    httpd = ThreadingHTTPServer(("127.0.0.1", port), handler)
    sys.stderr.write("static-server: serving %s at http://127.0.0.1:%d\n" % (directory, port))
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
