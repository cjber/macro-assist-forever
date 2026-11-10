#!/usr/bin/env python3
"""Check the screenshot scene's recorded widgets against their window bounds and one another."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIN_GAP = 8
# The approved split layout puts the footer buttons 6 units apart, so these two pairs use their own gap.
INTENTIONAL_GAPS = {
    frozenset(("new", "delete")): 6,
    frozenset(("cancel", "save")): 6,
}


def main():
    manifest = ROOT / "docs" / "screenshots" / "layout.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    frame = data["frame"]
    widgets = data["widgets"]
    errors = []
    for widget in widgets:
        x, y = widget["x"], widget["y"]
        right, bottom = x + widget["w"], y + widget["h"]
        inside = x >= frame["x"] and y >= frame["y"] and bottom <= frame["y"] + frame["h"]
        # A side rail belongs on the frame's outer right edge (docs/ui-composition.md): it starts inside the
        # frame and runs past it, so only its vertical bounds must stay within the frame.
        if widget.get("edge") == "right":
            inside = inside and x < frame["x"] + frame["w"]
        else:
            inside = inside and right <= frame["x"] + frame["w"]
        if not inside:
            errors.append(f"{widget['name']} lies outside the frame")
    interactive = [widget for widget in widgets if widget["role"] in {"button", "tabs", "input"}]
    for index, first in enumerate(interactive):
        for second in interactive[index + 1 :]:
            dx = max(second["x"] - (first["x"] + first["w"]), first["x"] - (second["x"] + second["w"]), 0)
            dy = max(second["y"] - (first["y"] + first["h"]), first["y"] - (second["y"] + second["h"]), 0)
            gap = INTENTIONAL_GAPS.get(frozenset((first["name"], second["name"])), MIN_GAP)
            if dx == 0 and dy == 0:
                errors.append(f"{first['name']} overlaps {second['name']}")
            elif dx < gap and dy < gap:
                errors.append(f"{first['name']} and {second['name']} are less than {gap} units apart")
    for error in errors:
        print(f"visual_audit: {error}")
    print(f"visual_audit: {len(widgets)} widgets, {len(errors)} findings")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
