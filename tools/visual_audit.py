#!/usr/bin/env python3
"""Check the screenshot scenes' recorded widgets, and the text they render, against their bounds and one another."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIN_GAP = 8
# A FontString's measured extent may differ from its box by a rounding unit and still fit.
CONTENT_SLACK = 1
# A box that declares the frame inset it is anchored to may be a rounding unit off and still be at that inset.
INSET_SLACK = 1
# The approved split layout puts the footer buttons 6 units apart, so these two pairs use their own gap.
INTENTIONAL_GAPS = {
    frozenset(("new", "delete")): 6,
    frozenset(("delete", "history")): 6,
    frozenset(("history", "import")): 6,
    frozenset(("import", "recipes")): 6,
    frozenset(("cancel", "save")): 6,
    frozenset(("import-cancel", "import-button")): 6,
    frozenset(("shorten-cancel", "shorten-apply")): 6,
}


def check_scene(scene):
    frame = scene["frame"]
    widgets = scene["widgets"]
    errors = []
    for widget in widgets:
        x, y = widget["x"], widget["y"]
        right, bottom = x + widget["w"], y + widget["h"]
        edge = widget.get("edge")
        if edge == "outside-right":
            # Blizzard's side tabs hang off the frame's right edge (the spellbook, Professions and Housing
            # windows all do this), so the widget starts at that edge and must only keep the frame's vertical
            # bounds. Every other widget stays inside the frame.
            inside = x >= frame["x"] + frame["w"] - 2 and y >= frame["y"] and bottom <= frame["y"] + frame["h"]
        else:
            inside = x >= frame["x"] and y >= frame["y"] and bottom <= frame["y"] + frame["h"]
            # A side rail belongs on the frame's own edge (docs/ui-composition.md): it starts inside the frame
            # and runs past it, so only its vertical bounds must stay within the frame.
            if edge == "right":
                inside = inside and x < frame["x"] + frame["w"]
            elif edge == "left":
                inside = inside and right > frame["x"]
            else:
                inside = inside and right <= frame["x"] + frame["w"]
        if not inside:
            errors.append(f"{widget['name']} lies outside the frame")
        # A box anchored to the frame's own edge must sit at the inset it declares. One that stops short leaves an
        # unused strip between its edge and the frame's inset, which is how a text box can make a fitting line wrap.
        distances = {
            "left": x - frame["x"],
            "right": frame["x"] + frame["w"] - right,
            "top": y - frame["y"],
            "bottom": frame["y"] + frame["h"] - bottom,
        }
        for side, inset in (widget.get("insets") or {}).items():
            if abs(distances[side] - inset) > INSET_SLACK:
                errors.append(
                    f"{widget['name']} sits {distances[side]:.0f} from the frame's {side} edge, not its {inset} inset"
                )
        content = widget.get("content")
        if content:
            # A FontString draws its measured extent inside its own box. The text may run wider than the box even
            # when the widget itself sits inside the frame, so check the rendered width, and the height unless the
            # box scrolls the text instead of clipping it.
            if content["w"] > widget["w"] + CONTENT_SLACK:
                errors.append(f"{widget['name']} text is {content['w']:.1f} wide in a {widget['w']} box")
            if content["h"] > widget["h"] + CONTENT_SLACK and not widget.get("scroll"):
                errors.append(f"{widget['name']} text is {content['h']:.1f} tall in a {widget['h']} box")
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
    return errors


def main():
    manifest = ROOT / "docs" / "screenshots" / "layout.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    scenes = data.get("scenes", [data])
    widgets = 0
    findings = 0
    for index, scene in enumerate(scenes):
        widgets += len(scene["widgets"])
        for error in check_scene(scene):
            print(f"visual_audit: scene {index + 1}: {error}")
            findings += 1
    print(f"visual_audit: {widgets} widgets, {findings} findings")
    return bool(findings)


if __name__ == "__main__":
    raise SystemExit(main())
