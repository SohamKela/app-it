#!/usr/bin/env python3
"""Unit tests for the tiny app-it-static HTTP server."""

from __future__ import annotations

import importlib.util
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "templates" / "static-server.py"
SPEC = importlib.util.spec_from_file_location("app_it_static_server", MODULE_PATH)
assert SPEC and SPEC.loader
static_server = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(static_server)


class StaticServerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "index.html").write_text("<!doctype html><title>App It</title>", encoding="utf-8")
        (self.root / "app.mjs").write_text("export const ok = true;", encoding="utf-8")
        (self.root / "assets").mkdir()

        handler = partial(static_server.StaticHandler, directory=str(self.root))
        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        self.thread = threading.Thread(target=self.httpd.serve_forever)
        self.thread.start()
        self.base_url = f"http://127.0.0.1:{self.httpd.server_port}"

    def tearDown(self) -> None:
        self.httpd.shutdown()
        self.thread.join(timeout=5)
        self.httpd.server_close()
        self.tmp.cleanup()

    def fetch(self, path: str, accept: str = "text/html") -> urllib.response.addinfourl:
        request = urllib.request.Request(f"{self.base_url}{path}", headers={"Accept": accept})
        return urllib.request.urlopen(request, timeout=5)

    def test_spa_navigation_falls_back_to_index(self) -> None:
        with self.fetch("/reports/2026.q2") as response:
            body = response.read().decode("utf-8")
        self.assertEqual(response.status, 200)
        self.assertIn("App It", body)

    def test_missing_asset_stays_404(self) -> None:
        with self.assertRaises(urllib.error.HTTPError) as raised:
            self.fetch("/assets/missing.js", accept="application/javascript")
        self.assertEqual(raised.exception.code, 404)

    def test_strict_module_mime_type_and_cache_header(self) -> None:
        with self.fetch("/app.mjs", accept="text/javascript") as response:
            body = response.read().decode("utf-8")
        self.assertEqual(response.status, 200)
        self.assertTrue(response.headers["Content-Type"].startswith("text/javascript"))
        self.assertEqual(response.headers["Cache-Control"], "no-cache")
        self.assertIn("ok", body)


if __name__ == "__main__":
    unittest.main()
