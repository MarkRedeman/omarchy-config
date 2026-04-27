#!/usr/bin/env python3
"""
Export Hyprland keybindings to JSON for debugging/visualization.

Tries to get runtime bindings via `hyprctl binds -j` first.
If that fails (e.g., not running Hyprland), falls back to parsing
the local bindings file.

Output: scripts/keybinding/keybindings.json
"""

import json
import subprocess
import sys
import os
import re
from datetime import datetime
from pathlib import Path


def get_runtime_bindings():
    """Try to get bindings from hyprctl."""
    try:
        result = subprocess.run(
            ["hyprctl", "binds", "-j"], capture_output=True, text=True, check=True
        )
        data = json.loads(result.stdout)
        # hyprctl binds -j returns a list of objects with:
        # { "modifier": "", "key": "", "dispatcher": "", "description": "" }
        # We'll normalize to our format.
        bindings = []
        for i, b in enumerate(data):
            mods = []
            mod_str = b.get("modifier", "")
            # modifier string like "SUPER+SHIFT" or empty
            if mod_str:
                for part in mod_str.split("+"):
                    if part:
                        mods.append(part)
            key = b.get("key", "")
            dispatcher = b.get("dispatcher", "")
            description = b.get("description", "")
            # Build combo string
            combo_parts = mods + ([key] if key else [])
            combo = "+".join(combo_parts) if combo_parts else ""
            bindings.append(
                {
                    "id": f"{i}::{dispatcher}",
                    "mods": mods,
                    "key": key,
                    "combo": combo,
                    "description": description,
                    "dispatcher": dispatcher,
                    "args": [],  # runtime data doesn't have args
                    "commandName": dispatcher,
                    "source": f"runtime (hyprctl binds -j)",
                    "bindType": "runtime",
                }
            )
        return bindings
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        return None


def parse_binding_line(line):
    """Parse a single line like `bindd = SUPER, H, Description, dispatcher, arg`."""
    # Strip comments
    line = line.split("#")[0].strip()
    if not line:
        return None
    # Match bind, bindd, bindm, bindl, bindmd
    match = re.match(r"^(bind\d*)\s*=\s*(.+)$", line)
    if not match:
        return None
    bind_type, rest = match.groups()
    # Split by commas, but careful about commas inside quotes? Not needed.
    parts = [p.strip() for p in rest.split(",")]
    if len(parts) < 3:
        return None
    # First part: modifiers (could be empty string)
    mods_str = parts[0]
    mods = [m for m in mods_str.split("+") if m] if mods_str else []
    # Second part: key
    key = parts[1]
    # Third part: description (may have commas? we assume not, as description is before dispatcher)
    # Actually description can have spaces but not commas typically.
    # We'll take everything until we see a dispatcher-like token? Simpler: assume description is single part.
    # But some descriptions have commas? We'll just take the third part as description.
    # Then the fourth part is dispatcher, fifth+ are args.
    if len(parts) < 4:
        return None
    description = parts[2]
    dispatcher = parts[3]
    args = parts[4:] if len(parts) > 4 else []
    # Build combo
    combo_parts = mods + ([key] if key else [])
    combo = "+".join(combo_parts) if combo_parts else ""
    return {
        "bindType": bind_type,
        "mods": mods,
        "key": key,
        "combo": combo,
        "description": description,
        "dispatcher": dispatcher,
        "args": args,
        "commandName": dispatcher,
        "source": line,  # store original line for debugging
    }


def parse_bindings_file(filepath):
    """Parse bindings from a file."""
    bindings = []
    with open(filepath, "r") as f:
        for i, line in enumerate(f, start=1):
            parsed = parse_binding_line(line)
            if parsed:
                parsed["id"] = f"{i}::{parsed['dispatcher']}"
                parsed["source"] = f"{filepath}:{i}"
                bindings.append(parsed)
    return bindings


def main():
    repo_dir = Path(__file__).resolve().parents[2]
    bindings_file = (
        repo_dir / "dotfiles" / "hypr" / ".config" / "hypr" / "bindings.conf"
    )
    if not bindings_file.is_file():
        print(f"Error: Bindings file not found at {bindings_file}", file=sys.stderr)
        sys.exit(1)

    # Try runtime first
    runtime_bindings = get_runtime_bindings()
    if runtime_bindings is not None:
        bindings = runtime_bindings
        source_mode = "runtime"
    else:
        bindings = parse_bindings_file(bindings_file)
        source_mode = "file"

    # Build output structure
    output = {
        "generatedAt": datetime.utcnow().isoformat() + "Z",
        "sourceMode": source_mode,
        "totalBindings": len(bindings),
        "bindings": bindings,
    }

    out_dir = repo_dir / "scripts" / "keybinding"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / "keybindings.json"
    with open(out_file, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"Exported {len(bindings)} keybindings to {out_file} (source: {source_mode})")


if __name__ == "__main__":
    main()
