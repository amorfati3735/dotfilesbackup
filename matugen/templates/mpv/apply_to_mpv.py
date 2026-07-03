#!/usr/bin/env python3
import json
import re
import os
from pathlib import Path

def apply_matugen_to_mpv(mpv_conf_path="/home/pratik/.config/mpv/mpv.conf"):
    colors_path = Path("/home/pratik/.config/matugen/palettes/last.json")
    if not colors_path.exists():
        print("No palette file found")
        return

    with open(colors_path, "r") as f:
        colors = json.load(f)

    sub_color = colors.get("on_primary", {}).get("default", {}).get("hex_stripped", "FFFFFF")
    sub_border_color = colors.get("primary", {}).get("default", {}).get("hex_stripped", "0E0E0E")
    sub_shadow_color = colors.get("primary_container", {}).get("default", {}).get("hex_stripped", "222222")

    pattern = r'^#?\s*sub-(color|border-color|shadow-color)\s*=.*$'
    new_lines = []

    with open(mpv_conf_path, "r") as f:
        lines = f.readlines()

    for line in lines:
        stripped = line.strip()
        if re.match(pattern, stripped, re.IGNORECASE):
            continue
        new_lines.append(line)

    new_lines.extend([
        f"sub-color=\"{sub_color}\"\n",
        f"sub-border-color=\"{sub_border_color}\"\n",
        f"sub-shadow-color=\"{sub_shadow_color}\"\n",
        "\n"
    ])

    with open(mpv_conf_path, "w") as f:
        f.writelines(new_lines)

    print("Applied matugen colors to mpv.conf")

if __name__ == "__main__":
    apply_matugen_to_mpv()