#!/usr/bin/env python3
"""Render the macro window from the sizes, art and editor rules in UI/ and Core/.

The list, header, editor and popup numbers come from UI/MacroWindow.lua, UI/Editor.lua and
UI/MacroWindow.xml. Summaries, colouring, diagnostics and completions are produced by the addon's
own Lua: this script only lays their output out with the client's atlases and fonts. JetBrains Mono
is read from media/fonts because it is the addon's bundled font, not a client file.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CORE = Path(os.environ.get("FOREVER_CORE", ROOT.parent / "forever-core"))
sys.path.insert(0, str(CORE / "tools" / "wowmock"))
import wowmock  # noqa: E402

SOURCE = (ROOT / "UI" / "MacroWindow.lua").read_text(encoding="utf-8")
EDITOR = (ROOT / "UI" / "Editor.lua").read_text(encoding="utf-8")
XML = (ROOT / "UI" / "MacroWindow.xml").read_text(encoding="utf-8")
FONT_FILE = ROOT / "media" / "fonts" / "JetBrainsMono-Regular.ttf"
SQUIGGLE = Image.open(ROOT / "media" / "squiggle.tga").convert("RGBA")
FONTS = wowmock.FONTS


def number(name, text=SOURCE):
    """A local constant from the addon's Lua, so a scene follows the window when its numbers move."""
    return int(re.search(rf"local {name} = (-?\d+)", text)[1])


WINDOW_WIDTH = number("WINDOW_WIDTH")
WINDOW_HEIGHT = number("WINDOW_HEIGHT")
INSET_LEFT = number("INSET_LEFT")
INSET_RIGHT = number("INSET_RIGHT")
TAB_LEFT = number("TAB_LEFT")
TAB_TOP = number("TAB_TOP")
LIST_TOP = number("LIST_TOP")
LIST_HEIGHT = number("LIST_HEIGHT")
HEADER_HEIGHT = number("HEADER_HEIGHT")
GAP = number("GAP")
BOTTOM_OFFSET = number("BOTTOM_OFFSET")
BUTTON_HEIGHT = number("BUTTON_HEIGHT")
BUTTON_WIDTH = number("BUTTON_WIDTH")
DELETE_WIDTH = number("DELETE_WIDTH")
CHANGE_WIDTH = number("CHANGE_WIDTH")
INSET_PADDING = number("INSET_PADDING")
SCROLL_RIGHT_PADDING = number("SCROLL_RIGHT_PADDING")
HEADER_ICON = number("HEADER_ICON")
HEADER_ICON_FRAME = number("HEADER_ICON_FRAME")
ROW_HEIGHT = number("ROW_HEIGHT")
ROW_NAME_WIDTH = number("ROW_NAME_WIDTH")
ROW_ICON_SIZE = 18
ROW_ICON_INSET = 5
ROW_ICON_GAP = 6
ROW_TEXT_RIGHT = 6
SCROLL_GAP = number("SCROLL_GAP")
SCROLL_WIDTH = number("SCROLL_WIDTH")
FONT_SIZE = number("FONT_SIZE", EDITOR)
GUTTER_WIDTH = number("GUTTER_WIDTH", EDITOR)
TEXT_INSET_LEFT = number("TEXT_INSET_LEFT", EDITOR)
TEXT_INSET_RIGHT = number("TEXT_INSET_RIGHT", EDITOR)
TEXT_INSET_TOP = number("TEXT_INSET_TOP", EDITOR)
SQUIGGLE_HEIGHT = number("SQUIGGLE_HEIGHT", EDITOR)
POPUP_ROWS = number("POPUP_ROWS", EDITOR)
POPUP_ROW_HEIGHT = number("POPUP_ROW_HEIGHT", EDITOR)
POPUP_PADDING = number("POPUP_PADDING", EDITOR)
MAX_ACCOUNT = 120
MAX_CHARACTER = 30

X, Y = 24, 24
MARGIN = 24
LINE_HEIGHT = FONT_SIZE
MONO = wowmock.Font(str(FONT_FILE), FONT_SIZE, wowmock.WHITE, None)
MUTED = (0.55, 0.55, 0.55)
WHITE = wowmock.WHITE
GOLD = wowmock.NORMAL
GREEN = wowmock.rgb("33ff99")
RED = wowmock.rgb("ff4040")
YELLOW = wowmock.rgb("ffd100")
DIM = wowmock.rgb("9d9d9d")


def editor_badges():
    """The kind badges the editor's completion popup draws, read from UI/Editor.lua."""
    block = re.search(r"local BADGES = \{(.*?)\n\}", EDITOR, re.S)[1]
    return dict(re.findall(r'(\w+) = "([^"]*)"', block))


BADGES = editor_badges()

# The Hunter macros the list shows. The bodies are the source of both the summaries and the editor text.
MACROS = [
    (
        "ability_impalingbolt",
        "Arcane",
        "\n".join(
            [
                "#showtooltip",
                "/cast [@mouseover,harm,nodead][] Arcane Shot",
                "/cast [mod:shift] Concussive Shot",
                "/petattack [@mouseover,harm,nodead][]",
                "/startattack",
            ]
        ),
    ),
    ("ability_hunter_mendpet", "Pet", "/cast [@pet,dead] Revive Pet; [nopet] Call Pet; Mend Pet"),
    ("ability_rogue_feigndeath", "FD", "/cast Feign Death\n/stopattack"),
    ("spell_frost_chainsofice", "Trap", "/cast Freezing Trap"),
    (
        "ability_hunter_snipershot",
        "Mark",
        "#showtooltip\n/cast [@mouseover,harm,nodead][] Hunter's Mark\n/petattack [@mouseover,harm,nodead][]",
    ),
    ("ability_meleedamage", "Melee", "/cast [mod:shift] Wing Clip; Raptor Strike"),
    ("ability_hunter_beastcall", "Call", "/cast [nopet] Call Pet; [@pet,dead] Revive Pet; Mend Pet"),
    ("inv_misc_food_19", "Feed", "/cast [@pet,nodead] Feed Pet\n/use Roasted Quail"),
    ("inv_misc_bandage_15", "Bandage", "/cast [@player] Heavy Runecloth Bandage"),
]
SELECTED = 0
CURRENT_LINE = 1

# The completion scene: a short Hunter macro with one mistyped command on a line above the caret, and a new
# `/cast [` being typed on the last line, so the popup opens below every line of text.
COMPLETION_BODY = "\n".join(
    [
        "#showtooltip",
        "/petattac [@mouseover,harm,nodead][]",
        "/cast [@mouseover,harm,nodead][] Arcane Shot",
        "/cast [mod:shift] Concussive Shot",
        "/startattack",
        "/cast [",
    ]
)
COMPLETION_LINE = 5
COMPLETION_CARET = COMPLETION_BODY.rindex("/cast [") + len("/cast [") + 1  # byte offset after `[`
LIVE = {
    "actionbar": "no",
    "bar": "no",
    "bonusbar": "no",
    "btn": "no",
    "button": "no",
    "channeling": "no",
    "combat": "no",
    "cursor": "no",
    "dead": "no",
    "equipped": "no",
    "exists": "yes",
    "form": "no",
    "group": "yes",
    "harm": "yes",
    "help": "no",
    "indoors": "no",
    "known": "no",
    "mod": "no",
    "modifier": "no",
    "mounted": "no",
    "outdoors": "yes",
    "party": "yes",
    "pet": "yes",
    "possessbar": "no",
    "raid": "yes",
    "resting": "no",
    "stance": "no",
    "stealth": "no",
    "swimming": "no",
    "worn": "no",
}
SPELLS = [
    {"name": "Arcane Shot", "ranks": [1, 3, 5, 7, 9]},
    {"name": "Serpent Sting", "ranks": [1, 3, 5, 7, 9]},
    {"name": "Concussive Shot", "ranks": [1, 3, 5, 7]},
    {"name": "Hunter's Mark", "ranks": [1, 2, 3, 4]},
    {"name": "Aspect of the Cheetah", "ranks": [1]},
    {"name": "Wing Clip", "ranks": [1, 2, 3]},
    {"name": "Raptor Strike", "ranks": [1, 3, 5, 7]},
    {"name": "Feign Death", "ranks": [1]},
    {"name": "Revive Pet", "ranks": [1]},
    {"name": "Call Pet", "ranks": [1]},
    {"name": "Feed Pet", "ranks": [1]},
    {"name": "Mend Pet", "ranks": [1, 3, 5, 7]},
    {"name": "Freezing Trap", "ranks": [1, 2, 3]},
    {"name": "Heavy Runecloth Bandage", "ranks": [1]},
]


def lua_string(value):
    return json.dumps(value, ensure_ascii=False)


def sample():
    """Ask the addon's own Lua for the summaries, colour codes, diagnostics and completion items."""
    macros = ",\n".join(lua_string(body) for _, _, body in MACROS)
    spells = ",\n".join(
        f"{{name = {lua_string(spell['name'])}, ranks = {{{', '.join(str(rank) for rank in spell['ranks'])}}}, "
        "learned = true}"
        for spell in SPELLS
    )
    live = ",\n".join(f"[{lua_string(name)}] = {lua_string(value)}" for name, value in LIVE.items())
    script = f"""
local ns = {{}}
for _, file in ipairs({{
    "Locales/enUS.lua",
    "Data/Commands.lua",
    "Data/Conditions.lua",
    "Core/Lexer.lua",
    "Core/Parser.lua",
    "Core/Length.lua",
    "Core/Highlight.lua",
    "Core/Explain.lua",
    "Core/Complete.lua",
    "Core/Check.lua",
}}) do
    assert(loadfile(file))("MacroAssistForever", ns)
end
local function clean(text)
    return (tostring(text):gsub("[\\t\\r\\n]", " "))
end
local macros = {{
{macros}
}}
for index, body in ipairs(macros) do
    print("SUMMARY\\t" .. index .. "\\t" .. clean(ns.Explain(body)))
    for lineIndex, line in ipairs(ns.Parser.Parse(body).lines) do
        print("MACRO_LINE\\t" .. index .. "\\t" .. lineIndex .. "\\t" .. clean(ns.Highlight.Line(line)))
    end
end
local completion = {lua_string(COMPLETION_BODY)}
print("COMPLETION_SUMMARY\\t" .. clean(ns.Explain(completion)))
for index, line in ipairs(ns.Parser.Parse(completion).lines) do
    print("LINE\\t" .. index .. "\\t" .. clean(ns.Highlight.Line(line)))
end
local live = {{
{live}
}}
local ctx = {{
    spells = {{
{spells}
    }},
    evaluate = function(condition)
        local name = condition.name or ""
        local value = live[name] or "no"
        if condition.no then
            return value == "yes" and "no" or "yes"
        end
        return value
    end,
}}
for index, diagnostic in ipairs(ns.Check(completion, ctx)) do
    print("DIAG\\t" .. index .. "\\t" .. diagnostic.from .. "\\t" .. diagnostic.to .. "\\t" .. diagnostic.severity
        .. "\\t" .. clean(diagnostic.message) .. "\\t" .. clean(diagnostic.fix and diagnostic.fix.insert or ""))
end
local result = ns.Complete(completion, {COMPLETION_CARET}, ctx)
print("COMPLETE\\t" .. result.from .. "\\t" .. result.to)
for index, item in ipairs(result.items) do
    print("ITEM\\t" .. index .. "\\t" .. item.kind .. "\\t" .. clean(item.label) .. "\\t" .. clean(item.detail))
end
print("LENGTH\\t" .. ns.Length(completion))
"""
    result = subprocess.run(["luajit", "-e", script], cwd=ROOT, capture_output=True, text=True, check=True)
    data = {
        "summary": {},
        "macro_lines": {},
        "completion_summary": "",
        "lines": {},
        "diagnostics": [],
        "items": [],
        "complete": None,
        "length": 0,
    }
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if parts[0] == "SUMMARY":
            data["summary"][int(parts[1])] = parts[2]
        elif parts[0] == "MACRO_LINE":
            data["macro_lines"].setdefault(int(parts[1]), {})[int(parts[2])] = parts[3]
        elif parts[0] == "COMPLETION_SUMMARY":
            data["completion_summary"] = parts[1]
        elif parts[0] == "LINE":
            data["lines"][int(parts[1])] = parts[2]
        elif parts[0] == "DIAG":
            data["diagnostics"].append(
                {
                    "from": int(parts[2]),
                    "to": int(parts[3]),
                    "severity": parts[4],
                    "message": parts[5],
                    "fix": parts[6],
                }
            )
        elif parts[0] == "COMPLETE":
            data["complete"] = (int(parts[1]), int(parts[2]))
        elif parts[0] == "ITEM":
            data["items"].append({"kind": parts[2], "label": parts[3], "detail": parts[4]})
        elif parts[0] == "LENGTH":
            data["length"] = int(parts[1])
    return data


def use_local_fonts(ui):
    """The editor's mono font is the addon's own file, so read it from disk instead of the client."""
    original = ui.font
    cache = {}

    def font(font_object):
        if font_object.path.startswith("/"):
            size = round(font_object.height * ui.scale)
            key = (font_object.path, size)
            if key not in cache:
                cache[key] = ImageFont.truetype(key[0], size, layout_engine=ImageFont.Layout.BASIC)
            return cache[key]
        return original(font_object)

    ui.font = font


def background(canvas, x, y, w, h):
    rock = canvas.ui.texture("interface/framegeneral/ui-background-rock.blp")
    wowmock.tiled(
        canvas, rock, x + 2, y + 21, w - 4, h - 23, rock.width / canvas.ui.scale, rock.height / canvas.ui.scale
    )
    canvas.draw(canvas.ui.atlas("_UI-Frame-TopTileStreaks"), x + 6, y + 21, w - 8, 43)


def inset(canvas, x, y, w, h):
    marble = canvas.ui.texture("interface/framegeneral/ui-background-marble.blp")
    wowmock.tiled(canvas, marble, x, y, w, h, marble.width / canvas.ui.scale, marble.height / canvas.ui.scale)
    wowmock.draw_nine_slice(canvas, wowmock.INSET_FRAME_LAYOUT, x, y, w, h)


def top_tabs(canvas, x, y, names, selected):
    """PanelTopTabButtonTemplate: the panel tab art flipped to hang upwards over the frame's top edge."""
    for index, name in enumerate(names):
        active = index == selected
        prefix = "uiframe-activetab" if active else "uiframe-tab"
        left = canvas.ui.atlas(f"{prefix}-left")
        right = canvas.ui.atlas(f"{prefix}-right")
        middle = canvas.ui.atlas(f"_{prefix}-center")
        font = FONTS["GameFontHighlightSmall" if active else "GameFontNormalSmall"]
        width = max(canvas.text_width(name, font) + 20, 72)
        top = y + 32 - left.height
        left_x = x + (-1 if active else -3)
        right_x = x + width + (8 if active else 7) - right.width
        canvas.draw(left, left_x, top, flip_v=True)
        canvas.draw(right, right_x, top, flip_v=True)
        canvas.draw(middle, left_x + left.width, top, right_x - left_x - left.width, middle.height, flip_v=True)
        canvas.text(x, y + 12 + (-3 if active else 2), name, font, justify="CENTER", width=width, box_height=10)
        x += width


def button(canvas, x, y, w, text, h=BUTTON_HEIGHT, state="normal"):
    wowmock.ui_panel_button(canvas, x, y, w, h, text, state=state)


def draw_row(canvas, x, y, width, icon, name, summary, selected, height=ROW_HEIGHT):
    if selected:
        canvas.draw(canvas.ui.atlas("auctionhouse-ui-row-select"), x, y, width, height, (1, 1, 1, 0.8), blend="ADD")
    icon_y = y + (height - ROW_ICON_SIZE) / 2
    canvas.draw(
        canvas.ui.texture(f"interface/icons/{icon}.blp"), x + ROW_ICON_INSET, icon_y, ROW_ICON_SIZE, ROW_ICON_SIZE
    )
    text_x = x + ROW_ICON_INSET + ROW_ICON_SIZE + ROW_ICON_GAP
    canvas.text(
        text_x,
        y,
        name,
        FONTS["GameFontHighlightSmall"],
        width=ROW_NAME_WIDTH,
        box_height=height,
    )
    summary_x = text_x + ROW_NAME_WIDTH + ROW_ICON_GAP
    canvas.text(
        summary_x,
        y,
        summary,
        FONTS["GameFontHighlightSmall"],
        MUTED,
        width=x + width - ROW_TEXT_RIGHT - summary_x,
        box_height=height,
    )


def line_geometry():
    """Absolute editor rectangles from the frame's constants."""
    editor_x = X + INSET_LEFT
    editor_y = Y - LIST_TOP + LIST_HEIGHT + GAP + HEADER_HEIGHT + GAP
    editor_w = WINDOW_WIDTH + INSET_RIGHT - INSET_LEFT
    editor_h = WINDOW_HEIGHT - BOTTOM_OFFSET - (editor_y - Y)
    gutter_x = editor_x + 4
    gutter_y = editor_y + 6
    text_x = gutter_x + GUTTER_WIDTH + 2
    text_y = gutter_y
    text_w = editor_x + editor_w - 6 - text_x
    text_h = editor_y + editor_h - 26 - text_y
    return editor_x, editor_y, editor_w, editor_h, gutter_x, gutter_y, text_x, text_y, text_w, text_h


def draw_editor(canvas, body, current_line, caret_column, data):
    editor_x, editor_y, editor_w, editor_h, gutter_x, gutter_y, text_x, text_y, text_w, _ = line_geometry()
    lines = body.split("\n")
    advance = FONT_SIZE * 14 / 24  # JetBrains Mono's fixed advance at this size: 14 px over 24 px.
    # The current-line highlight sits under the text, as the editor's BACKGROUND texture does.
    canvas.fill(
        text_x + TEXT_INSET_LEFT,
        text_y + TEXT_INSET_TOP + current_line * LINE_HEIGHT,
        text_w - TEXT_INSET_LEFT - TEXT_INSET_RIGHT,
        LINE_HEIGHT,
        (1, 0.82, 0.2, 0.10),
    )
    for index, line in enumerate(lines):
        top = text_y + TEXT_INSET_TOP + index * LINE_HEIGHT
        number_font = FONTS["GameFontHighlightSmall"]
        canvas.text(
            gutter_x,
            gutter_y + index * LINE_HEIGHT,
            str(index + 1),
            number_font,
            MUTED,
            justify="RIGHT",
            width=GUTTER_WIDTH - 4,
            box_height=LINE_HEIGHT,
        )
        highlighted = data["lines"].get(index + 1, line)
        canvas.text(text_x + TEXT_INSET_LEFT, top, highlighted, MONO, box_height=LINE_HEIGHT)
    # The caret is the EditBox's own white line, above the coloured overlay.
    if caret_column is not None:
        canvas.fill(
            text_x + TEXT_INSET_LEFT + caret_column * advance,
            text_y + TEXT_INSET_TOP + current_line * LINE_HEIGHT,
            1,
            LINE_HEIGHT,
            WHITE,
        )
    # One squiggle per diagnostic row, at the native 16 by 4 tile, tinted for its severity.
    for diagnostic in data["diagnostics"]:
        line_index, start, end = locate(body, diagnostic["from"], diagnostic["to"])
        y = text_y + TEXT_INSET_TOP + line_index * LINE_HEIGHT + LINE_HEIGHT - 1
        x = text_x + TEXT_INSET_LEFT + start * advance
        width = max(advance, (end - start) * advance)
        colour = (1, 0.25, 0.25, 0.95) if diagnostic["severity"] == "error" else (1, 0.82, 0.2, 0.95)
        offset = 0
        while offset < width:
            canvas.draw(SQUIGGLE, x + offset, y, 16, SQUIGGLE_HEIGHT, colour)
            offset += 16
    return text_x, text_y, text_w, advance


def locate(body, first, last):
    """The zero-based line and columns of a diagnostic's byte offsets in the whole macro."""
    start_line = body.count("\n", 0, first - 1)
    line_start = body.rfind("\n", 0, first - 1) + 1
    end_line = body.count("\n", 0, last)
    line_end = body.find("\n", last)
    if line_end < 0:
        line_end = len(body)
    if start_line == end_line:
        return start_line, first - 1 - line_start, last - line_start
    return start_line, first - 1 - line_start, line_end - line_start


def draw_completion(canvas, completion, caret_column, text_x, text_y, text_w):
    _, caret = completion[:2]
    x = text_x + TEXT_INSET_LEFT + caret_column * (FONT_SIZE * 14 / 24)
    y = text_y + TEXT_INSET_TOP + caret * LINE_HEIGHT + LINE_HEIGHT
    width = max(280, min(text_w, 560))
    rows = min(POPUP_ROWS, len(completion[2]))
    height = rows * POPUP_ROW_HEIGHT + POPUP_PADDING * 2
    canvas.draw(canvas.ui.atlas("common-dropdown-bg"), x, y, width, height, (1, 1, 1, 0.94))
    items = completion[2][:rows]
    badges = [BADGES.get(item["kind"], "?") for item in items]
    show_badges = len(set(badges)) > 1
    for index, item in enumerate(items):
        row_y = y + POPUP_PADDING + index * POPUP_ROW_HEIGHT
        row_x = x + POPUP_PADDING
        row_width = width - POPUP_PADDING * 2
        selected = completion[3] + index + 1 == completion[4]
        if selected:
            canvas.fill(row_x, row_y, row_width, POPUP_ROW_HEIGHT, (1, 0.82, 0.2, 0.18))
        label_x = row_x + 4
        if show_badges:
            canvas.text(
                row_x + 2,
                row_y,
                badges[index],
                FONTS["GameFontHighlightSmall"],
                justify="CENTER",
                width=14,
                box_height=POPUP_ROW_HEIGHT,
            )
            label_x = row_x + 20
        label_font = (
            MONO
            if item["kind"] in {"secure", "command", "chat", "emote", "directive", "condition", "unit", "value"}
            else FONTS["GameFontHighlight"]
        )
        canvas.text(label_x, row_y, item["label"], label_font, box_height=POPUP_ROW_HEIGHT)
        canvas.text(
            row_x + row_width - 4 - 146,
            row_y,
            item["detail"],
            FONTS["GameFontHighlightSmall"],
            justify="RIGHT",
            width=146,
            box_height=POPUP_ROW_HEIGHT,
        )


def window(ui, *, body, current_line, caret_column, data, completion=None):
    canvas = ui.canvas(WINDOW_WIDTH + 2 * X, WINDOW_HEIGHT + 2 * Y)
    background(canvas, X, Y, WINDOW_WIDTH, WINDOW_HEIGHT)
    # The list inset, its rows and its scroll bar.
    list_x = X + INSET_LEFT
    list_y = Y - LIST_TOP
    list_w = WINDOW_WIDTH + INSET_RIGHT - INSET_LEFT
    inset(canvas, list_x, list_y, list_w, LIST_HEIGHT)
    scroll_x = list_x + INSET_PADDING
    scroll_y = list_y + INSET_PADDING
    scroll_w = list_w - INSET_PADDING - (SCROLL_WIDTH + SCROLL_GAP + SCROLL_RIGHT_PADDING)
    scroll_h = LIST_HEIGHT - INSET_PADDING * 2
    for index, (icon, name, _) in enumerate(MACROS):
        row_y = scroll_y + index * ROW_HEIGHT
        height = min(ROW_HEIGHT, scroll_y + scroll_h - row_y)
        if height <= 0:
            break
        draw_row(
            canvas,
            scroll_x,
            row_y,
            scroll_w,
            icon,
            name,
            data["summary"][index + 1],
            index == SELECTED,
            height,
        )
    wowmock.minimal_scrollbar(
        canvas,
        scroll_x + scroll_w + SCROLL_GAP,
        scroll_y,
        scroll_h,
        visible=min(1.0, 7 / len(MACROS)),
    )
    # The selected macro's header, below the list.
    header_y = list_y + LIST_HEIGHT + GAP
    name, icon = MACROS[SELECTED][1], MACROS[SELECTED][0]
    canvas.draw(
        ui.texture("interface/common/whiteiconframe.blp"),
        X + INSET_LEFT + 10,
        header_y + 8,
        HEADER_ICON_FRAME,
        HEADER_ICON_FRAME,
        GOLD,
    )
    canvas.draw(
        ui.texture(f"interface/icons/{icon}.blp"),
        X + INSET_LEFT + 10 + (HEADER_ICON_FRAME - HEADER_ICON) // 2,
        header_y + 8 + (HEADER_ICON_FRAME - HEADER_ICON) // 2,
        HEADER_ICON,
        HEADER_ICON,
    )
    canvas.text(X + INSET_LEFT + 10 + HEADER_ICON_FRAME + 8, header_y + 7, name, FONTS["GameFontNormalLarge"])
    canvas.text(
        X + INSET_LEFT + 10 + HEADER_ICON_FRAME + 8,
        header_y + 7 + 16 + 3,
        f"Character macro · {len(MACROS)} of {MAX_CHARACTER}",
        FONTS["GameFontHighlightSmall"],
        MUTED,
    )
    button(
        canvas,
        X + WINDOW_WIDTH + INSET_RIGHT - 10 - CHANGE_WIDTH,
        header_y + (HEADER_HEIGHT - BUTTON_HEIGHT) // 2,
        CHANGE_WIDTH,
        "Change Name/Icon",
    )
    # The editor inset and its contents.
    editor_x, editor_y, editor_w, editor_h, *_ = line_geometry()
    inset(canvas, editor_x, editor_y, editor_w, editor_h)
    text_x, text_y, text_w, _ = draw_editor(canvas, body, current_line, caret_column, data)
    problem = "|cff33ff99No problems|r"
    if data["diagnostics"]:
        first = data["diagnostics"][0]
        colour = "|cffff4040" if first["severity"] == "error" else "|cffffd100"
        phrase = "%d problem · %s" if len(data["diagnostics"]) == 1 else "%d problems · %s"
        problem = colour + (phrase % (len(data["diagnostics"]), first["message"])) + "|r"
    status = (
        problem
        + "|cff9d9d9d  ·  |rNow: Arcane Shot on Defias Pillager"
        + f"|cff9d9d9d  ·  |r|cffffd100{data['length']}/255|r"
    )
    canvas.text(editor_x + 10, editor_y + editor_h - 15, status, FONTS["GameFontHighlightSmall"], box_height=10)
    # The window's own buttons, with the edited macro treated as dirty so Save and Cancel are live.
    button_y = Y + WINDOW_HEIGHT - 8 - BUTTON_HEIGHT
    button(canvas, X + 10, button_y, DELETE_WIDTH, "Delete")
    button(canvas, X + 10 + DELETE_WIDTH + GAP, button_y, BUTTON_WIDTH, "New")
    button(canvas, X + WINDOW_WIDTH - 10 - BUTTON_WIDTH, button_y, BUTTON_WIDTH, "Save")
    button(canvas, X + WINDOW_WIDTH - 10 - BUTTON_WIDTH * 2 - GAP, button_y, BUTTON_WIDTH, "Cancel")
    # The metal frame, portrait, title and close button sit over the contents; the tabs hang over its top edge.
    wowmock.portrait_frame_art(
        canvas, X, Y, WINDOW_WIDTH, WINDOW_HEIGHT, "interface/icons/inv_misc_note_01.blp", "Macros"
    )
    top_tabs(canvas, X + TAB_LEFT - 3, Y - TAB_TOP - 4, ["General", "Barry's Macros"], 1)
    # The popup is drawn last, over the editor text, as the editor's popup is in game.
    if completion:
        draw_completion(canvas, completion, caret_column, text_x, text_y, text_w)
    return canvas


def layout():
    editor_x, editor_y, editor_w, editor_h, *_ = line_geometry()
    button_y = Y + WINDOW_HEIGHT - 8 - BUTTON_HEIGHT
    widgets = [
        {
            "name": "list",
            "role": "list",
            "x": X + INSET_LEFT,
            "y": Y - LIST_TOP,
            "w": WINDOW_WIDTH + INSET_RIGHT - INSET_LEFT,
            "h": LIST_HEIGHT,
        },
        {
            "name": "change",
            "role": "button",
            "x": X + WINDOW_WIDTH + INSET_RIGHT - 10 - CHANGE_WIDTH,
            "y": Y - LIST_TOP + LIST_HEIGHT + GAP + (HEADER_HEIGHT - BUTTON_HEIGHT) // 2,
            "w": CHANGE_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {"name": "editor", "role": "edit", "x": editor_x, "y": editor_y, "w": editor_w, "h": editor_h},
        {"name": "delete", "role": "button", "x": X + 10, "y": button_y, "w": DELETE_WIDTH, "h": BUTTON_HEIGHT},
        {
            "name": "new",
            "role": "button",
            "x": X + 10 + DELETE_WIDTH + GAP,
            "y": button_y,
            "w": BUTTON_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "cancel",
            "role": "button",
            "x": X + WINDOW_WIDTH - 10 - BUTTON_WIDTH * 2 - GAP,
            "y": button_y,
            "w": BUTTON_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "save",
            "role": "button",
            "x": X + WINDOW_WIDTH - 10 - BUTTON_WIDTH,
            "y": button_y,
            "w": BUTTON_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {"name": "tabs", "role": "tabs", "x": X + TAB_LEFT - 3, "y": Y - TAB_TOP - 4, "w": 250, "h": 32},
    ]
    return {"frame": {"x": X, "y": Y, "w": WINDOW_WIDTH, "h": WINDOW_HEIGHT}, "widgets": widgets}


def completion_data(data):
    """The popup shows eight conditions after the player has moved down the list; item 14 starts the slice."""
    offset = 13
    selected = 21
    items = data["items"][offset : offset + POPUP_ROWS]
    return (COMPLETION_BODY.split("\n"), COMPLETION_LINE, items, offset, selected)


def main():
    data = sample()
    ui = wowmock.Ui(scale=2)
    use_local_fonts(ui)
    output = ROOT / "docs" / "screenshots"
    output.mkdir(parents=True, exist_ok=True)
    window_data = {
        "lines": data["macro_lines"].get(SELECTED + 1, {}),
        "summary": data["summary"],
        "diagnostics": [],
        "length": len(MACROS[SELECTED][2]),
    }
    canvas = window(
        ui,
        body=MACROS[SELECTED][2],
        current_line=CURRENT_LINE,
        caret_column=len(MACROS[SELECTED][2].split("\n")[CURRENT_LINE]),
        data=window_data,
    )
    wowmock.scene(ui, [(canvas, 0, 0)]).save(output / "window.png")
    print(output / "window.png")

    completion = completion_data(data)
    completion_scene = {
        **data,
        "summary": {**data["summary"], 1: data["completion_summary"]},
        # The last line is still being typed, so its missing `]` is not a saved problem: keep only the macro's
        # problem on line 2, which the squiggle and status row explain without the hover tooltip.
        "diagnostics": [item for item in data["diagnostics"] if item["from"] < COMPLETION_BODY.rindex("\n") + 2],
    }
    canvas = window(
        ui,
        body=COMPLETION_BODY,
        current_line=COMPLETION_LINE,
        caret_column=len("/cast ["),
        data=completion_scene,
        completion=completion,
    )
    wowmock.scene(ui, [(canvas, 0, 0)]).save(output / "completion.png")
    print(output / "completion.png")
    (output / "layout.json").write_text(json.dumps(layout(), indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
