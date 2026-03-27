#!/usr/bin/env python3
"""Merge matugen-generated colors into VS Code settings.json"""
import json
import sys
from pathlib import Path

COLORS_FILE = Path.home() / ".local/state/matugen/vscode-colors.json"
SETTINGS_FILE = Path.home() / ".config/Code/User/settings.json"

def main():
    if not COLORS_FILE.exists():
        print(f"No colors file at {COLORS_FILE}", file=sys.stderr)
        return 1

    colors = json.loads(COLORS_FILE.read_text())
    settings = json.loads(SETTINGS_FILE.read_text()) if SETTINGS_FILE.exists() else {}

    settings["workbench.colorCustomizations"] = colors
    SETTINGS_FILE.write_text(json.dumps(settings, indent=2) + "\n")
    print(f"Applied {len(colors)} color overrides to VS Code")
    return 0

if __name__ == "__main__":
    sys.exit(main())
