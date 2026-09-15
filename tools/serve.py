#!/usr/bin/env python3
import http.server
import socketserver
import os
from pathlib import Path

import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8088
DIST_DIR = Path(__file__).resolve().parents[1] / "web" / "dist"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIST_DIR), **kwargs)

    def end_headers(self):
        # Cross-origin isolation headers for SharedArrayBuffer / high performance WASM if needed
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def guess_type(self, path):
        if str(path).endswith(".wasm"):
            return "application/wasm"
        if str(path).endswith(".data"):
            return "application/octet-stream"
        if str(path).endswith(".js"):
            return "application/javascript"
        return super().guess_type(path)

if __name__ == "__main__":
    os.chdir(str(DIST_DIR))
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"Serving {DIST_DIR} at http://localhost:{PORT}/")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
