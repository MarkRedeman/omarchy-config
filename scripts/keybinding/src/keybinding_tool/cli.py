"""CLI entrypoint for keybinding tooling."""

from __future__ import annotations

import argparse
import sys

from .exporter import export_keybindings
from .server import serve_ui


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="keybinding",
        description="Export Hyprland keybindings and serve the visualizer UI.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("export", help="Generate keybindings.json")

    serve_parser = subparsers.add_parser("serve", help="Serve the visualizer UI")
    serve_parser.add_argument("--port", type=int, default=8000, help="Port to bind")

    dev_parser = subparsers.add_parser(
        "dev", help="Generate keybindings then serve the visualizer"
    )
    dev_parser.add_argument("--port", type=int, default=8000, help="Port to bind")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "export":
        try:
            out_file, total, source_mode = export_keybindings()
        except FileNotFoundError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1

        print(f"Exported {total} keybindings to {out_file} (source: {source_mode})")
        return 0

    if args.command == "serve":
        try:
            out_file, total, source_mode = export_keybindings()
        except FileNotFoundError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1

        print(f"Exported {total} keybindings to {out_file} (source: {source_mode})")
        serve_ui(port=args.port)
        return 0

    if args.command == "dev":
        try:
            out_file, total, source_mode = export_keybindings()
        except FileNotFoundError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1

        print(f"Exported {total} keybindings to {out_file} (source: {source_mode})")
        serve_ui(port=args.port)
        return 0

    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
