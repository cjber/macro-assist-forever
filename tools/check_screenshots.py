#!/usr/bin/env python3
"""Check that each README screenshot still matches the scene inputs it was rendered from."""

import re
from pathlib import Path

from forever_tools.screens import files, main

ROOT = Path(__file__).resolve().parents[1]
TOC = "MacroAssistForever.toc"
# tools/screenshots.py reads exactly this metadata field, for every portrait frame, and no other.
TOC_ICON = re.compile(r"^##\s*X-Forever-Icon:\s*(.*?)\s*$", re.MULTILINE)


def toc_dump(root):
    """The TOC's part of a scene's dump: the files it loads, in order, and the one field a scene draws.

    `## X-Forever-Core`, `## Version` and the other metadata never reach the renderer, so changing them must not
    mark every screenshot stale; only the file list, its load order and X-Forever-Icon can move a pixel."""
    text = (root / TOC).read_text(encoding="utf-8-sig")
    loaded = [line.strip() for line in text.splitlines()]
    loaded = [line for line in loaded if line and not line.startswith("#")]
    icon = TOC_ICON.search(text)
    if icon is None:
        raise ValueError(f"{TOC}: no X-Forever-Icon")
    return "\n".join([*loaded, f"X-Forever-Icon: {icon[1]}"]).encode()


def scene():
    """What every screenshot is drawn from: the source the renderer reads, then the TOC it loads."""
    return (
        files(
            ROOT,
            [
                "tools/screenshots.py",
                "UI/MacroWindow.lua",
                "UI/MacroWindow.xml",
                "UI/IconSelector.lua",
                "UI/Editor.lua",
                "UI/History.lua",
                "UI/Import.lua",
                "UI/Shorten.lua",
                "UI/Context.lua",
                "Core/Explain.lua",
                "Core/Highlight.lua",
                "Core/Check.lua",
                "Core/Complete.lua",
                "Core/Bars.lua",
                "Core/Import.lua",
                "Core/Shorten.lua",
                "Core/Lexer.lua",
                "Core/Parser.lua",
                "Core/Length.lua",
                "Data/Commands.lua",
                "Data/Conditions.lua",
                "Data/Recipes.lua",
                "Locales/enUS.lua",
                "media/fonts/JetBrainsMono-Regular.ttf",
                "media/squiggle.tga",
            ],
        )
        + b"\n"
        + toc_dump(ROOT)
    )


SCENES = {
    name: scene
    for name in (
        "window.png",
        "completion.png",
        "recipes.png",
        "history.png",
        "import.png",
        "shorten.png",
        "picker.png",
    )
}

if __name__ == "__main__":
    raise SystemExit(main(ROOT / "docs" / "screenshots", SCENES))
