#!/usr/bin/env python3
"""Check the screenshot scene's recorded widgets against their window bounds and one another."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIN_GAP = 8


def main():
    manifest = ROOT / "docs" / "screenshots" / "layout.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    frame = data["frame"]
    widgets = data["widgets"]
    errors = []
    for widget in widgets:
        x, y = widget["x"], widget["y"]
        right, bottom = x + widget["w"], y + widget["h"]
        if x < frame["x"] or y < frame["y"] or right > frame["x"] + frame["w"] or bottom > frame["y"] + frame["h"]:
            errors.append(f"{widget['name']} lies outside the frame")
    interactive = [widget for widget in widgets if widget["role"] in {"button", "tabs", "input"}]
    for index, first in enumerate(interactive):
        for second in interactive[index + 1 :]:
            dx = max(second["x"] - (first["x"] + first["w"]), first["x"] - (second["x"] + second["w"]), 0)
            dy = max(second["y"] - (first["y"] + first["h"]), first["y"] - (second["y"] + second["h"]), 0)
            if dx == 0 and dy == 0:
                errors.append(f"{first['name']} overlaps {second['name']}")
            elif dx < MIN_GAP and dy < MIN_GAP:
                errors.append(f"{first['name']} and {second['name']} are less than {MIN_GAP} units apart")
    for error in errors:
        print(f"visual_audit: {error}")
    print(f"visual_audit: {len(widgets)} widgets, {len(errors)} findings")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
