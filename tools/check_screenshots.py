#!/usr/bin/env python3
"""Check that each README screenshot still matches the scene inputs it was rendered from."""

from pathlib import Path

from forever_tools.screens import files, main

ROOT = Path(__file__).resolve().parents[1]
SCENES = {
    name: lambda: files(
        ROOT,
        [
            "tools/screenshots.py",
            "MacroAssistForever.toc",
            "UI/MacroWindow.lua",
            "UI/MacroWindow.xml",
            "UI/IconSelector.lua",
            "UI/Editor.lua",
            "UI/History.lua",
            "UI/Import.lua",
            "UI/Context.lua",
            "Core/Explain.lua",
            "Core/Highlight.lua",
            "Core/Check.lua",
            "Core/Complete.lua",
            "Core/Bars.lua",
            "Core/Import.lua",
            "Core/Lexer.lua",
            "Core/Parser.lua",
            "Core/Length.lua",
            "Data/Commands.lua",
            "Data/Conditions.lua",
            "Locales/enUS.lua",
            "media/fonts/JetBrainsMono-Regular.ttf",
            "media/squiggle.tga",
        ],
    )
    for name in ("window.png", "completion.png", "history.png", "import.png", "picker.png")
}

if __name__ == "__main__":
    raise SystemExit(main(ROOT / "docs" / "screenshots", SCENES))
