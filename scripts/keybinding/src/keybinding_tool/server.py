"""Simple local HTTP server for the keybinding UI."""

from __future__ import annotations

import http.server
import socketserver
from pathlib import Path


def serve_ui(port: int = 8000) -> None:
    """Serve keybinding UI directory until interrupted."""
    web_root = Path(__file__).resolve().parents[2]
    handler = http.server.SimpleHTTPRequestHandler

    with socketserver.TCPServer(("", port), handler) as httpd:
        print(f"Serving keybinding UI at http://localhost:{port}")
        print(f"Web root: {web_root}")
        print("Press Ctrl+C to stop.")
        try:
            import os

            os.chdir(web_root)
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopping server.")
