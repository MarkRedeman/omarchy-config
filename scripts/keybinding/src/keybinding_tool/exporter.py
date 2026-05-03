"""Export Hyprland keybindings to JSON for visualization."""

from __future__ import annotations

import json
import re
import subprocess
from datetime import UTC, datetime
from pathlib import Path


def get_runtime_bindings() -> list[dict] | None:
    """Try to get bindings from `hyprctl binds -j`."""
    modmask_map = {
        1: "SHIFT",
        4: "CTRL",
        8: "ALT",
        64: "SUPER",
    }

    def mods_from_modmask(modmask: object) -> list[str]:
        mods: list[str] = []
        try:
            mask = int(modmask)
        except (TypeError, ValueError):
            return mods

        for bit, name in modmask_map.items():
            if mask & bit:
                mods.append(name)
        return mods

    try:
        result = subprocess.run(
            ["hyprctl", "binds", "-j"], capture_output=True, text=True, check=True
        )
        data = json.loads(result.stdout)

        bindings: list[dict] = []
        for i, binding in enumerate(data):
            mods: list[str] = []
            mod_str = binding.get("modifier", "")
            if mod_str:
                mods = [part for part in mod_str.split("+") if part]
            elif "modmask" in binding:
                mods = mods_from_modmask(binding.get("modmask", 0))

            key = binding.get("key", "")
            if not key and binding.get("keycode"):
                key = f"code:{binding.get('keycode')}"

            dispatcher = binding.get("dispatcher", "")
            description = binding.get("description", "")

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
                    "args": [],
                    "commandName": dispatcher,
                    "source": "runtime (hyprctl binds -j)",
                    "bindType": "runtime",
                }
            )
        return bindings
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        return None


def parse_binding_line(line: str) -> dict | None:
    """Parse a line like `bindd = SUPER, H, Description, dispatcher, arg`."""
    line = line.split("#")[0].strip()
    if not line:
        return None

    match = re.match(r"^(bind\d*)\s*=\s*(.+)$", line)
    if not match:
        return None

    bind_type, rest = match.groups()
    parts = [part.strip() for part in rest.split(",")]
    if len(parts) < 4:
        return None

    mods_str = parts[0]
    mods = [m for m in re.split(r"[+\s]+", mods_str) if m] if mods_str else []
    key = parts[1]
    description = parts[2]
    dispatcher = parts[3]
    args = parts[4:] if len(parts) > 4 else []

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
        "source": line,
    }


def parse_bindings_file(filepath: Path) -> list[dict]:
    """Parse bindings from a hypr bindings file."""
    bindings: list[dict] = []
    with filepath.open("r", encoding="utf-8") as handle:
        for i, line in enumerate(handle, start=1):
            parsed = parse_binding_line(line)
            if parsed:
                parsed["id"] = f"{i}::{parsed['dispatcher']}"
                parsed["source"] = f"{filepath}:{i}"
                bindings.append(parsed)
    return bindings


def export_keybindings() -> tuple[Path, int, str]:
    """Export bindings JSON, returns `(out_file, total, source_mode)`."""
    repo_dir = Path(__file__).resolve().parents[4]
    bindings_file = (
        repo_dir / "dotfiles" / "hypr" / ".config" / "hypr" / "bindings.conf"
    )

    if not bindings_file.is_file():
        raise FileNotFoundError(f"Bindings file not found at {bindings_file}")

    runtime_bindings = get_runtime_bindings()
    if runtime_bindings is not None:
        bindings = runtime_bindings
        source_mode = "runtime"
    else:
        bindings = parse_bindings_file(bindings_file)
        source_mode = "file"

    output = {
        "generatedAt": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
        "sourceMode": source_mode,
        "totalBindings": len(bindings),
        "bindings": bindings,
    }

    out_dir = repo_dir / "scripts" / "keybinding"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / "keybindings.json"

    with out_file.open("w", encoding="utf-8") as handle:
        json.dump(output, handle, indent=2, ensure_ascii=False)

    return out_file, len(bindings), source_mode
