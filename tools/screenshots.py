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

TOC = (ROOT / "MacroAssistForever.toc").read_text(encoding="utf-8-sig")
SOURCE = (ROOT / "UI" / "MacroWindow.lua").read_text(encoding="utf-8")
PICKER = (ROOT / "UI" / "IconSelector.lua").read_text(encoding="utf-8")
EDITOR = (ROOT / "UI" / "Editor.lua").read_text(encoding="utf-8")
HISTORY = (ROOT / "UI" / "History.lua").read_text(encoding="utf-8")
IMPORT = (ROOT / "UI" / "Import.lua").read_text(encoding="utf-8")
SHORTEN = (ROOT / "UI" / "Shorten.lua").read_text(encoding="utf-8")
XML = (ROOT / "UI" / "MacroWindow.xml").read_text(encoding="utf-8")
FONT_FILE = ROOT / "media" / "fonts" / "JetBrainsMono-Regular.ttf"
SQUIGGLE = Image.open(ROOT / "media" / "squiggle.tga").convert("RGBA")
FONTS = wowmock.FONTS


def number(name, text=SOURCE):
    """A local constant from the addon's Lua, so a scene follows the window when its numbers move."""
    return int(re.search(rf"local {name} = (-?\d+)", text)[1])


def texcoord(name, text=SOURCE):
    """A local texcoord constant from the addon's Lua: the four numbers SetTexCoord receives."""
    block = re.search(rf"local {name} = \{{([^}}]+)\}}", text)[1]
    return [float(value) for value in block.split(",")]


def toc_field(name):
    """A TOC metadata value, such as the addon's one identity icon."""
    return re.search(rf"^##\s*{re.escape(name)}:\s*(.*?)\s*$", TOC, re.MULTILINE)[1]


# Every portrait scene draws the icon the TOC declares, the same value the addon reads at load.
IDENTITY_ICON = toc_field("X-Forever-Icon").replace("\\", "/").lower()
if not IDENTITY_ICON.endswith(".blp"):
    IDENTITY_ICON += ".blp"


WINDOW_WIDTH = number("WINDOW_WIDTH")
WINDOW_HEIGHT = number("WINDOW_HEIGHT")
INSET_LEFT = number("INSET_LEFT")
INSET_RIGHT = number("INSET_RIGHT")
LIST_LEFT = INSET_LEFT
LIST_TOP = number("LIST_TOP")
LIST_WIDTH = number("LIST_WIDTH")
LIST_HEIGHT = number("LIST_HEIGHT")
SIDE_TAB_X = number("SIDE_TAB_X")
SIDE_TAB_TOP = number("SIDE_TAB_TOP")
SIDE_TAB_GAP = number("SIDE_TAB_GAP")
HEADER_TOP = number("HEADER_TOP")
HEADER_HEIGHT = number("HEADER_HEIGHT")
GAP = number("GAP")
COLUMN_GAP = number("COLUMN_GAP")
STATUS_HEIGHT = number("STATUS_HEIGHT")
STATUS_INSET = number("STATUS_INSET")
BOTTOM_OFFSET = number("BOTTOM_OFFSET")
BUTTON_HEIGHT = number("BUTTON_HEIGHT")
BUTTON_WIDTH = number("BUTTON_WIDTH")
DELETE_WIDTH = number("DELETE_WIDTH")
HISTORY_WIDTH = number("HISTORY_WIDTH")
IMPORT_WIDTH = number("IMPORT_WIDTH")
FOOTER_GAP = number("FOOTER_GAP")
RENAME_WIDTH = number("RENAME_WIDTH")
RENAME_HEIGHT = number("RENAME_HEIGHT")
SEARCH_LEFT = number("SEARCH_LEFT")
SEARCH_TOP = number("SEARCH_TOP")
SEARCH_WIDTH = number("SEARCH_WIDTH")
SEARCH_HEIGHT = number("SEARCH_HEIGHT")
COUNT_WIDTH = number("COUNT_WIDTH")
EXPLAIN_INSET = number("EXPLAIN_INSET")
EXPLAIN_BOTTOM = number("EXPLAIN_BOTTOM")
EXPLAIN_TITLE_TOP = number("EXPLAIN_TITLE_TOP")
EXPLAIN_ROW_TOP = number("EXPLAIN_ROW_TOP")
EXPLAIN_ROW_HEIGHT = number("EXPLAIN_ROW_HEIGHT")
EXPLAIN_KEY_GAP = number("EXPLAIN_KEY_GAP")
INSET_PADDING = number("INSET_PADDING")
SCROLL_RIGHT_PADDING = number("SCROLL_RIGHT_PADDING")
HEADER_ICON = number("HEADER_ICON")
HEADER_ICON_FRAME = number("HEADER_ICON_FRAME")
ROW_HEIGHT = number("ROW_HEIGHT")
# The History window's own numbers, from UI/History.lua.
HISTORY_PANEL_WIDTH = number("WIDTH", HISTORY)
HISTORY_PANEL_HEIGHT = number("HEIGHT", HISTORY)
HISTORY_PANEL_INSET = number("INSET_PADDING", HISTORY)
HISTORY_SCROLL_GAP = number("SCROLL_GAP", HISTORY)
HISTORY_SCROLL_WIDTH = number("SCROLL_WIDTH", HISTORY)
HISTORY_SCROLL_RIGHT = number("SCROLL_RIGHT_PADDING", HISTORY)
HISTORY_BOTTOM = number("BOTTOM", HISTORY)
# The Import box's own numbers, from UI/Import.lua.
IMPORT_PANEL_WIDTH = number("WIDTH", IMPORT)
IMPORT_PANEL_HEIGHT = number("HEIGHT", IMPORT)
IMPORT_PANEL_INSET = number("INSET_PADDING", IMPORT)
IMPORT_HINT_TOP = number("HINT_TOP", IMPORT)
IMPORT_HINT_HEIGHT = number("HINT_HEIGHT", IMPORT)
IMPORT_BOX_BOTTOM = number("BOX_BOTTOM", IMPORT)
IMPORT_STATUS_BOTTOM = number("STATUS_BOTTOM", IMPORT)
IMPORT_BOTTOM = number("BOTTOM", IMPORT)
IMPORT_BUTTON_WIDTH = number("BUTTON_WIDTH", IMPORT)
IMPORT_BUTTON_HEIGHT = number("BUTTON_HEIGHT", IMPORT)
# The Shorten preview's own numbers, from UI/Shorten.lua.
SHORTEN_PANEL_WIDTH = number("WIDTH", SHORTEN)
SHORTEN_PANEL_HEIGHT = number("HEIGHT", SHORTEN)
SHORTEN_PANEL_INSET = number("INSET_PADDING", SHORTEN)
SHORTEN_HINT_TOP = number("HINT_TOP", SHORTEN)
SHORTEN_HINT_HEIGHT = number("HINT_HEIGHT", SHORTEN)
SHORTEN_BOX_BOTTOM = number("BOX_BOTTOM", SHORTEN)
SHORTEN_STATUS_BOTTOM = number("STATUS_BOTTOM", SHORTEN)
SHORTEN_BOTTOM = number("BOTTOM", SHORTEN)
SHORTEN_BUTTON_WIDTH = number("BUTTON_WIDTH", SHORTEN)
SHORTEN_BUTTON_HEIGHT = number("BUTTON_HEIGHT", SHORTEN)
ROW_ICON_SIZE = 26
ROW_ICON_INSET = 6
ROW_TEXT_X = 40
ROW_NAME_TOP = 4
ROW_SUMMARY_TOP = 21
ROW_TEXT_RIGHT = 6
SCROLL_GAP = number("SCROLL_GAP")
SCROLL_WIDTH = number("SCROLL_WIDTH")
ICON_TEXCOORD = texcoord("ICON_TEXCOORD")
FONT_SIZE = number("FONT_SIZE", EDITOR)
LINE_SPACING = number("LINE_SPACING", EDITOR)
LINE_HEIGHT = FONT_SIZE + LINE_SPACING  # one editor line: the font height plus the editor's SetSpacing
GUTTER_WIDTH = number("GUTTER_WIDTH", EDITOR)
TEXT_INSET_LEFT = number("TEXT_INSET_LEFT", EDITOR)
TEXT_INSET_RIGHT = number("TEXT_INSET_RIGHT", EDITOR)
TEXT_INSET_TOP = number("TEXT_INSET_TOP", EDITOR)
SQUIGGLE_HEIGHT = number("SQUIGGLE_HEIGHT", EDITOR)
POPUP_ROWS = number("POPUP_ROWS", EDITOR)
POPUP_ROW_HEIGHT = number("POPUP_ROW_HEIGHT", EDITOR)
POPUP_INSET_LEFT = number("POPUP_INSET_LEFT", EDITOR)
POPUP_INSET_TOP = number("POPUP_INSET_TOP", EDITOR)
POPUP_INSET_RIGHT = number("POPUP_INSET_RIGHT", EDITOR)
POPUP_INSET_BOTTOM = number("POPUP_INSET_BOTTOM", EDITOR)
POPUP_LABEL_X = number("POPUP_LABEL_X", EDITOR)
POPUP_LABEL_WIDTH = number("POPUP_LABEL_WIDTH", EDITOR)
POPUP_HELP_X = number("POPUP_HELP_X", EDITOR)
POPUP_TAG_WIDTH = number("POPUP_TAG_WIDTH", EDITOR)
POPUP_TAG_RIGHT = number("POPUP_TAG_RIGHT", EDITOR)
MAX_ACCOUNT = 120
MAX_CHARACTER = 30

# The icon picker's own numbers, from UI/IconSelector.lua, so the scene follows the addon when they move.
PICKER_PADDING = number("PICKER_PADDING", PICKER)
PICKER_SEARCH_HEIGHT = number("SEARCH_HEIGHT", PICKER)
PICKER_SEARCH_GAP = number("SEARCH_GAP", PICKER)
PICKER_ROW_TOP_GAP = number("ROW_TOP_GAP", PICKER)
ICON_SIZE = number("ICON_SIZE", PICKER)
ICON_GAP = number("ICON_GAP", PICKER)
ICON_PITCH = ICON_SIZE + ICON_GAP
SECTION_HEIGHT = number("SECTION_HEIGHT", PICKER)
PICKER_SCROLL_GAP = number("SCROLL_GAP", PICKER)
PICKER_SCROLL_WIDTH = number("SCROLL_WIDTH", PICKER)

X, Y = 24, 24
MARGIN = 24
MONO = wowmock.Font(str(FONT_FILE), FONT_SIZE, wowmock.WHITE, None)
MUTED = (0.55, 0.55, 0.55)
WHITE = wowmock.WHITE
GOLD = wowmock.NORMAL
GREEN = wowmock.rgb("33ff99")
RED = wowmock.rgb("ff4040")
YELLOW = wowmock.rgb("ffd100")
DIM = wowmock.rgb("9d9d9d")
SURFACE = (0.035, 0.035, 0.04, 0.94)
EDGE = (0.45, 0.45, 0.45, 1)
RULE = (1, 1, 1, 0.08)


def fit(canvas, text, font, width):
    """Trim to the width with an ellipsis, as a FontString with word wrap off does."""
    if canvas.text_width(text, font) <= width:
        return text
    while text and canvas.text_width(text + "...", font) > width:
        text = text[:-1]
    return text.rstrip() + "..."


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
TAB_SELECTED = 1
# #57: the selected macro sits on the bottom-right bar, so the header names that slot and its key. Every other list row
# is on no bar and carries the dim marker.
BAR_TEXT = "Character macro, slot 61 (Shift-1)"
ON_BAR = {0}

# The picker scene's sample data. The Arcane macro's saved icon is Automatic, as a #showtooltip macro starts, so the
# header, the list row and the selected grid cell all show the question mark.
PICKER_ICON = "inv_misc_questionmark"
PICKER_FROM_MACRO = ["inv_misc_questionmark", "ability_impalingbolt", "spell_frost_stun"]
PICKER_SPELLBOOK = [
    "ability_hunter_snipershot",
    "ability_hunter_quickshot",
    "ability_upgrademoonglaive",
    "ability_hunter_mendpet",
    "ability_hunter_beastcall",
    "ability_rogue_feigndeath",
    "spell_nature_ravenform",
    "ability_rogue_trip",
    "spell_frost_chainsofice",
    "ability_hunter_runningshot",
    "spell_nature_spiritwolf",
    "ability_hunter_aspectofthemonkey",
    "ability_hunter_beasttaming",
    "ability_hunter_pet_wolf",
    "ability_physical_taunt",
    "ability_whirlwind",
    "ability_mount_jungletiger",
]
PICKER_ALL = [
    "inv_misc_food_19",
    "inv_misc_bandage_15",
    "inv_misc_note_01",
    "inv_misc_book_09",
    "inv_spear_07",
    "inv_sword_04",
    "inv_axe_09",
    "inv_mace_01",
    "inv_weapon_bow_02",
    "inv_weapon_rifle_01",
    "inv_staff_08",
    "inv_potion_51",
    "inv_potion_54",
    "inv_misc_gem_pearl_05",
    "inv_misc_herb_01",
    "inv_misc_bag_10",
    "inv_chest_leather_01",
    "inv_helmet_01",
    "inv_boots_05",
    "inv_gauntlets_04",
    "inv_shield_06",
    "spell_holy_flashheal",
    "spell_fire_fireball02",
    "spell_shadow_shadowbolt",
    "spell_nature_lightning",
    "spell_holy_renew",
    "spell_arcane_blink",
    "spell_nature_healingtouch",
    "spell_fire_flamebolt",
    "spell_shadow_curseofsargeras",
    "inv_misc_head_dragon_01",
    "inv_jewelry_ring_03",
    "inv_misc_coin_01",
    "inv_misc_key_03",
    "inv_misc_rune_01",
    "inv_letter_15",
    "inv_drink_07",
    "inv_misc_fish_02",
    "inv_ore_copper_01",
    "inv_fabric_linen_01",
]

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
# The recipe scene: plain words on a line offer the Hunter recipes whose words match, with their spell names resolved.
RECIPE_BODY = "pet"
RECIPE_CARET = 4
RECIPE_SPELL_NAMES = {136: "Mend Pet", 982: "Revive Pet", 1130: "Hunter's Mark", 1499: "Freezing Trap"}
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
    recipe_spells = ",\n".join(
        f"[{spell_id}] = {lua_string(name)}" for spell_id, name in sorted(RECIPE_SPELL_NAMES.items())
    )
    script = f"""
local ns = {{}}
for _, file in ipairs({{
    "Locales/enUS.lua",
    "Data/Commands.lua",
    "Data/Conditions.lua",
    "Data/Recipes.lua",
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
    print("SUMMARY\\t" .. index .. "\\t" .. clean(ns.ExplainSummary(body)))
    for caseIndex, case in ipairs(ns.ExplainCases(body)) do
        print("EXPLAIN\\t" .. index .. "\\t" .. caseIndex .. "\\t" .. clean(case.key) .. "\\t" .. clean(case.text))
    end
    for lineIndex, line in ipairs(ns.Parser.Parse(body).lines) do
        print("MACRO_LINE\\t" .. index .. "\\t" .. lineIndex .. "\\t" .. clean(ns.Highlight.Line(line)))
    end
end
local completion = {lua_string(COMPLETION_BODY)}
print("COMPLETION_SUMMARY\\t" .. clean(ns.ExplainSummary(completion)))
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
    print("ITEM\\t" .. index .. "\\t" .. item.kind .. "\\t" .. clean(item.label) .. "\\t" .. clean(item.detail)
        .. "\\t" .. clean(item.live or ""))
end
print("LENGTH\\t" .. ns.Length(completion))
local recipeSpells = {{
{recipe_spells}
}}
local recipes = {{}}
for _, recipe in ipairs(ns.Recipes.List) do
    if not recipe.class or recipe.class == "HUNTER" then
        local body = ns.Recipes.Render(recipe, function(spellID) return recipeSpells[spellID] end)
        if body then
            recipes[#recipes + 1] = {{
                words = recipe.words,
                title = ns.L[recipe.title] or recipe.title,
                body = body,
            }}
        end
    end
end
ctx.recipes = recipes
local recipeResult = ns.Complete({lua_string(RECIPE_BODY)}, {RECIPE_CARET}, ctx)
print("RECIPE_COMPLETE\\t" .. recipeResult.from .. "\\t" .. recipeResult.to)
for index, item in ipairs(recipeResult.items) do
    print("RECIPE_ITEM\\t" .. index .. "\\t" .. item.kind .. "\\t" .. clean(item.label) .. "\\t"
        .. clean(item.detail) .. "\\t" .. clean(item.insert))
end
"""
    result = subprocess.run(["luajit", "-e", script], cwd=ROOT, capture_output=True, text=True, check=True)
    data = {
        "summary": {},
        "explain": {},
        "macro_lines": {},
        "completion_summary": "",
        "lines": {},
        "diagnostics": [],
        "items": [],
        "complete": None,
        "length": 0,
        "recipe": {"from": 1, "to": 0, "items": []},
    }
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if parts[0] == "SUMMARY":
            data["summary"][int(parts[1])] = parts[2]
        elif parts[0] == "EXPLAIN":
            data["explain"].setdefault(int(parts[1]), []).append({"key": parts[3], "text": parts[4]})
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
            data["items"].append(
                {
                    "kind": parts[2],
                    "label": parts[3],
                    "detail": parts[4],
                    "live": parts[5] if len(parts) > 5 else "",
                }
            )
        elif parts[0] == "LENGTH":
            data["length"] = int(parts[1])
        elif parts[0] == "RECIPE_COMPLETE":
            data["recipe"]["from"] = int(parts[1])
            data["recipe"]["to"] = int(parts[2])
        elif parts[0] == "RECIPE_ITEM":
            data["recipe"]["items"].append(
                {
                    "kind": parts[2],
                    "label": parts[3],
                    "detail": parts[4],
                    "insert": parts[5] if len(parts) > 5 else "",
                }
            )
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


SIDE_TABS = [
    ("interface/icons/inv_misc_book_09.blp", "General"),
    ("interface/characterframe/temporaryportrait-female-nightelf.blp", "Barry's Macros"),
]


def side_tabs(canvas, x, top, selected):
    """LargeSideTabButtonTemplate on the window's outer right rail, as SkillUp anchors it: wowmock draws the native
    common-sidetab art, its mask and the checked ring, and each tab stacks SIDE_TAB_GAP below the last."""
    y = top
    for index, (icon, _) in enumerate(SIDE_TABS):
        y += wowmock.side_tab(canvas, x, y, icon, selected=index == selected) + SIDE_TAB_GAP


def button(canvas, x, y, w, text, h=BUTTON_HEIGHT, state="normal"):
    wowmock.ui_panel_button(canvas, x, y, w, h, text, state=state)


def draw_icon(canvas, path, x, y, size):
    """A spell or item icon as the addon draws it: crop the baked-in border by ICON_TEXCOORD, then scale the
    remaining picture to `size` at its native aspect, centred, never stretched."""
    image = canvas.ui.texture(path)
    left = round(image.width * ICON_TEXCOORD[0])
    right = round(image.width * ICON_TEXCOORD[1])
    top = round(image.height * ICON_TEXCOORD[2])
    bottom = round(image.height * ICON_TEXCOORD[3])
    inner = image.crop((left, top, right, bottom))
    scale = min(size / inner.width, size / inner.height)
    width, height = inner.width * scale, inner.height * scale
    canvas.draw(inner, x + (size - width) / 2, y + (size - height) / 2, width, height)


def draw_row(canvas, x, y, width, icon, name, summary, selected, height=ROW_HEIGHT):
    """The selected row is a soft gold fill with a 2-unit bar on the left, never the auction house glow."""
    if selected:
        canvas.fill(x, y, width, height, (1, 0.82, 0.2, 0.10))
        canvas.fill(x, y + 3, 2, height - 6, (1, 0.82, 0.2, 1))
    icon_y = y + (height - ROW_ICON_SIZE) / 2
    canvas.draw(
        canvas.ui.texture("interface/common/whiteiconframe.blp"),
        x + ROW_ICON_INSET - 3,
        icon_y - 3,
        ROW_ICON_SIZE + 6,
        ROW_ICON_SIZE + 6,
        GOLD if selected else (0.45, 0.45, 0.45),
    )
    draw_icon(canvas, f"interface/icons/{icon}.blp", x + ROW_ICON_INSET, icon_y, ROW_ICON_SIZE)
    text_x = x + ROW_TEXT_X
    text_width = x + width - ROW_TEXT_RIGHT - text_x
    canvas.text(
        text_x,
        y + ROW_NAME_TOP,
        name,
        FONTS["GameFontHighlight"],
        GOLD if selected else WHITE,
        width=text_width,
    )
    canvas.text(
        text_x,
        y + ROW_SUMMARY_TOP,
        fit(canvas, summary, FONTS["GameFontHighlightSmall"], text_width),
        FONTS["GameFontHighlightSmall"],
        (0.6, 0.6, 0.6),
    )


def explain_panel(canvas, x, y, w, cases):
    """What the macro does, one row per click and modifier branch, read from the addon's own parse."""
    font = FONTS["GameFontHighlightSmall"]
    canvas.fill(x, y, w, 1, RULE)
    canvas.text(x + 10, y + EXPLAIN_TITLE_TOP, "What it does", FONTS["GameFontNormalSmall"])
    row_y = y + EXPLAIN_ROW_TOP
    for case in cases:
        key_width = canvas.text_width(case["key"], font) + 12
        canvas.fill(x + 10, row_y, key_width, 16, (1, 1, 1, 0.08))
        canvas.text(
            x + 10,
            row_y,
            case["key"],
            font,
            justify="CENTER",
            width=key_width,
            box_height=16,
        )
        canvas.text(x + 10 + EXPLAIN_KEY_GAP, row_y, case["text"], font, (0.8, 0.8, 0.8), box_height=16)
        row_y += EXPLAIN_ROW_HEIGHT


def editor_geometry():
    """The code surface rectangle, from the header's bottom and the window's footer."""
    editor_x = X + LIST_LEFT + LIST_WIDTH + COLUMN_GAP
    top = -HEADER_TOP + HEADER_HEIGHT + GAP
    editor_y = Y + top
    editor_w = WINDOW_WIDTH + INSET_RIGHT - LIST_LEFT - LIST_WIDTH - COLUMN_GAP
    editor_h = WINDOW_HEIGHT - BOTTOM_OFFSET - STATUS_HEIGHT - top
    return editor_x, editor_y, editor_w, editor_h


def status_geometry():
    editor_x, editor_y, editor_w, editor_h = editor_geometry()
    return editor_x + STATUS_INSET, editor_y + editor_h, editor_w - 2 * STATUS_INSET, STATUS_HEIGHT


def draw_editor(canvas, body, current_line, caret_column, data):
    editor_x, editor_y, editor_w, editor_h = editor_geometry()
    canvas.fill(editor_x, editor_y, editor_w, editor_h, SURFACE)
    canvas.fill(editor_x, editor_y, editor_w, 1, EDGE)
    canvas.fill(editor_x, editor_y + editor_h - 1, editor_w, 1, EDGE)
    canvas.fill(editor_x, editor_y, 1, editor_h, EDGE)
    canvas.fill(editor_x + editor_w - 1, editor_y, 1, editor_h, EDGE)
    canvas.fill(editor_x + GUTTER_WIDTH, editor_y + 6, 1, editor_h - 12, RULE)
    lines = body.split("\n")
    text_x = editor_x + GUTTER_WIDTH + 10
    text_y = editor_y + 10
    text_w = editor_x + editor_w - 6 - text_x
    advance = canvas.text_width("M" * 32, MONO) / 32
    # The current-line band sits under the text, inside the tooltip backdrop's own border.
    canvas.fill(editor_x + 4, text_y + current_line * LINE_HEIGHT, editor_w - 8, LINE_HEIGHT, (1, 0.82, 0.2, 0.08))
    for index, line in enumerate(lines):
        top = text_y + index * LINE_HEIGHT
        number_font = FONTS["GameFontHighlightSmall"]
        canvas.text(
            editor_x + 4,
            top,
            str(index + 1),
            number_font,
            WHITE if index == current_line else (0.4, 0.4, 0.4),
            justify="RIGHT",
            width=GUTTER_WIDTH - 10,
            box_height=LINE_HEIGHT,
        )
        highlighted = data["lines"].get(index + 1, line)
        canvas.text(text_x, top, highlighted, MONO, box_height=LINE_HEIGHT)
    # The caret is our own white line above the coloured overlay, placed at the measured column, one line tall.
    if caret_column is not None:
        prefix = lines[current_line][:caret_column]
        canvas.fill(
            text_x + canvas.text_width(prefix, MONO),
            text_y + current_line * LINE_HEIGHT,
            1,
            LINE_HEIGHT,
            WHITE,
        )
    # One squiggle per diagnostic row, at the native 16 by 4 tile, just under the glyphs rather than at the bottom of
    # the spaced line, where the extra SetSpacing would make it read as the next line's.
    for diagnostic in data["diagnostics"]:
        line_index, start, end = locate(body, diagnostic["from"], diagnostic["to"])
        y = text_y + line_index * LINE_HEIGHT + FONT_SIZE + 1
        x = text_x + start * advance
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
    """The completion list, kept inside the code surface: mono label, muted trimmed help and a live value tag."""
    lines, caret = completion[:2]
    prefix = lines[caret][:caret_column]
    editor_x, editor_y, editor_w, editor_h = editor_geometry()
    width = min(max(280, min(text_w, 560)), editor_w - 8)
    rows = min(POPUP_ROWS, len(completion[2]))
    height = rows * POPUP_ROW_HEIGHT + POPUP_INSET_TOP + POPUP_INSET_BOTTOM
    x = text_x + canvas.text_width(prefix, MONO)
    x = min(max(editor_x + 4, x), editor_x + editor_w - width - 4)
    y = text_y + caret * LINE_HEIGHT + LINE_HEIGHT + 2
    if y + height > editor_y + editor_h - 4:
        y = text_y + caret * LINE_HEIGHT - height - 2
    y = max(editor_y + 4, min(y, editor_y + editor_h - height - 4))
    # A flat dark panel with a 1-unit white edge, from the client's white primitive rather than a tooltip file.
    canvas.fill(x, y, width, height, (0.07, 0.07, 0.08, 0.98))
    canvas.fill(x, y, width, 1, (1, 1, 1, 0.18))
    canvas.fill(x, y + height - 1, width, 1, (1, 1, 1, 0.18))
    canvas.fill(x, y, 1, height, (1, 1, 1, 0.18))
    canvas.fill(x + width - 1, y, 1, height, (1, 1, 1, 0.18))
    items = completion[2][:rows]
    for index, item in enumerate(items):
        row_y = y + POPUP_INSET_TOP + index * POPUP_ROW_HEIGHT
        row_x = x + POPUP_INSET_LEFT
        row_width = width - POPUP_INSET_LEFT - POPUP_INSET_RIGHT
        selected = completion[3] + index + 1 == completion[4]
        if selected:
            canvas.fill(row_x, row_y, row_width, POPUP_ROW_HEIGHT, (1, 0.82, 0.2, 0.14))
        canvas.text(
            x + POPUP_LABEL_X,
            row_y,
            fit(canvas, item["label"], MONO, POPUP_LABEL_WIDTH),
            MONO,
            box_height=POPUP_ROW_HEIGHT,
        )
        live = item.get("live", "")
        detail = item["detail"]
        if live:
            suffix = "  " + live
            if detail.endswith(suffix):
                detail = detail[: -len(suffix)]
        help_width = width - POPUP_HELP_X - POPUP_TAG_RIGHT - POPUP_TAG_WIDTH - 6
        canvas.text(
            x + POPUP_HELP_X,
            row_y,
            fit(canvas, detail, FONTS["GameFontHighlightSmall"], help_width),
            FONTS["GameFontHighlightSmall"],
            (0.6, 0.6, 0.6),
            box_height=POPUP_ROW_HEIGHT,
        )
        if live:
            tag_x = x + width - POPUP_TAG_RIGHT - POPUP_TAG_WIDTH
            tag_y = row_y + (POPUP_ROW_HEIGHT - (POPUP_ROW_HEIGHT - 8)) / 2
            tag_colour = (0.2, 0.8, 0.4, 0.25) if live == "yes" else (1, 1, 1, 0.07)
            text_colour = GREEN if live == "yes" else MUTED
            canvas.fill(tag_x, tag_y, POPUP_TAG_WIDTH, POPUP_ROW_HEIGHT - 8, tag_colour)
            canvas.text(
                tag_x,
                tag_y,
                live,
                FONTS["GameFontHighlightSmall"],
                text_colour,
                justify="CENTER",
                width=POPUP_TAG_WIDTH,
                box_height=POPUP_ROW_HEIGHT - 8,
            )


def status_bar(canvas, x, y, w, length, now, data):
    """The strip under the code: problems left, the live result, then the character meter on the right."""
    font = FONTS["GameFontHighlightSmall"]
    label = f"{min(length, 255)}/255"
    label_w = canvas.text_width(label, font)
    if data["diagnostics"]:
        # A problem takes the whole strip before the count: a red tint, the full first message, then Tab to fix.
        first = data["diagnostics"][0]
        canvas.fill(x, y, w, STATUS_HEIGHT, (0.25, 0.02, 0.02, 0.45))
        canvas.fill(x, y, w, 1, (1, 0.25, 0.25, 0.5))
        count = len(data["diagnostics"])
        count_text = ("%d problem" if count == 1 else "%d problems") % count
        cursor = x + 10
        canvas.text(cursor, y, count_text, font, RED, box_height=STATUS_HEIGHT)
        cursor += canvas.text_width(count_text, font) + 6
        available = x + w - 10 - label_w - 8 - cursor
        message = fit(canvas, first["message"], font, available)
        canvas.text(cursor, y, message, font, WHITE, box_height=STATUS_HEIGHT)
        cursor += canvas.text_width(message, font)
        if first["fix"]:
            fix = "Tab to fix"
            if cursor + 6 + canvas.text_width(fix, font) <= x + w - 10 - label_w - 8:
                canvas.text(cursor + 6, y, fix, font, MUTED, box_height=STATUS_HEIGHT)
        canvas.text(x + w - 10 - label_w, y, label, font, MUTED, box_height=STATUS_HEIGHT)
        return
    canvas.fill(x, y, w, STATUS_HEIGHT, (0, 0, 0, 0.35))
    canvas.fill(x, y, w, 1, RULE)
    canvas.draw(canvas.ui.atlas("common-icon-checkmark"), x + 8, y + 5, 12, 12)
    canvas.text(x + 24, y, "No problems", font, GREEN, box_height=STATUS_HEIGHT)
    canvas.text(x + 112, y, "Now", font, MUTED, box_height=STATUS_HEIGHT)
    now_x = x + 112 + canvas.text_width("Now", font) + 6
    meter_w = 90
    mx = x + w - 10 - label_w - 8 - meter_w
    canvas.text(now_x, y, fit(canvas, now, font, mx - 8 - now_x), font, box_height=STATUS_HEIGHT)
    canvas.fill(mx, y + 9, meter_w, 4, (1, 1, 1, 0.12))
    canvas.fill(mx, y + 9, meter_w * min(length, 255) / 255, 4, (1, 0.82, 0.2, 0.9))
    canvas.text(x + w - 10 - label_w, y, label, font, MUTED, box_height=STATUS_HEIGHT)


def picker_icon(canvas, name, x, y, selected=False, label=None):
    """One 36-unit icon with the header's gold white frame when selected and the Auto label over Automatic."""
    draw_icon(canvas, f"interface/icons/{name}.blp", x, y, ICON_SIZE)
    if selected:
        canvas.draw(
            canvas.ui.texture("interface/common/whiteiconframe.blp"),
            x - 2,
            y - 2,
            ICON_SIZE + 4,
            ICON_SIZE + 4,
            GOLD,
        )
    if label:
        canvas.text(
            x,
            y + ICON_SIZE - 14,
            label,
            FONTS["NumberFontNormal"],
            justify="CENTER",
            width=ICON_SIZE,
        )


def picker_section(canvas, x, y, w, title, note=""):
    canvas.text(x, y + 3, title, FONTS["GameFontNormal"])
    if note:
        canvas.text(x, y + 4, note, FONTS["GameFontHighlightSmall"], MUTED, justify="RIGHT", width=w)
    return y + SECTION_HEIGHT


def picker_grid(canvas, names, x, y, w, bottom, selected=None, labels=None):
    columns = max(1, (w + ICON_GAP) // ICON_PITCH)
    for index, name in enumerate(names):
        row, col = divmod(index, columns)
        row_y = y + row * ICON_PITCH
        if row_y + ICON_SIZE > bottom:
            break
        picker_icon(
            canvas,
            name,
            x + col * ICON_PITCH,
            row_y,
            selected=name == selected,
            label=(labels or {}).get(name),
        )


def picker_filter_dropdown(canvas, right, top, text):
    """WowStyle1FilterDropdownTemplate with the picker's one change: its Text is re-anchored TOP (0, 1), so the
    label's centre sits on the button face's centre instead of the template's 20-unit box hanging 1 unit low."""
    font = FONTS["GameFontNormal"]
    width, height = canvas.text_width(text, font) + 60, 18
    x = right - width
    canvas.draw(canvas.ui.atlas("common-dropdown-b-button"), x - 4, top - 4, width + 8, height + 8)
    canvas.text(x, top - 1, text, font, justify="CENTER", width=width, box_height=20)
    return x, top, width, height


def draw_picker(canvas, icon=PICKER_ICON):
    """The picker in the editor's rectangle: search and filter, one scrolling grid, and its own status strip."""
    x, y, w, h = editor_geometry()
    canvas.fill(x, y, w, h, SURFACE)
    canvas.fill(x, y, w, 1, EDGE)
    canvas.fill(x, y + h - 1, w, 1, EDGE)
    canvas.fill(x, y, 1, h, EDGE)
    canvas.fill(x + w - 1, y, 1, h, EDGE)

    left = x + PICKER_PADDING
    top = y + PICKER_PADDING
    filter_x, _, _, _ = picker_filter_dropdown(canvas, x + w - PICKER_PADDING, top + 1, "All icons")
    search_w = filter_x - PICKER_SEARCH_GAP - left
    wowmock.search_box(
        canvas,
        left,
        top,
        search_w,
        PICKER_SEARCH_HEIGHT,
        instructions="Search icons, spells and items",
    )

    grid_x = left
    grid_y = top + PICKER_SEARCH_HEIGHT + PICKER_ROW_TOP_GAP
    grid_w = w - 2 * PICKER_PADDING - (PICKER_SCROLL_WIDTH + PICKER_SCROLL_GAP)
    bottom = y + h - PICKER_PADDING
    columns = max(1, (grid_w + ICON_GAP) // ICON_PITCH)
    row_y = picker_section(canvas, grid_x, grid_y, grid_w, "From this macro")
    picker_grid(
        canvas,
        PICKER_FROM_MACRO,
        grid_x,
        row_y,
        grid_w,
        bottom,
        selected=icon,
        labels={PICKER_FROM_MACRO[0]: "Auto"},
    )
    row_y += ((len(PICKER_FROM_MACRO) + columns - 1) // columns) * ICON_PITCH
    row_y = picker_section(canvas, grid_x, row_y, grid_w, "Spellbook", "Hunter")
    picker_grid(canvas, PICKER_SPELLBOOK, grid_x, row_y, grid_w, bottom, selected=icon)
    row_y += ((len(PICKER_SPELLBOOK) + columns - 1) // columns) * ICON_PITCH
    row_y = picker_section(canvas, grid_x, row_y, grid_w, "All icons", f"{len(PICKER_ALL):,}")
    picker_grid(canvas, PICKER_ALL, grid_x, row_y, grid_w, bottom, selected=icon)

    wowmock.minimal_scrollbar(
        canvas,
        grid_x + grid_w + PICKER_SCROLL_GAP,
        grid_y,
        bottom - grid_y,
        visible=0.4,
    )

    status_x, status_y, status_w, _ = status_geometry()
    canvas.fill(status_x, status_y, status_w, STATUS_HEIGHT, (0, 0, 0, 0.35))
    canvas.fill(status_x, status_y, status_w, 1, RULE)
    font = FONTS["GameFontHighlightSmall"]
    automatic = "Automatic"
    detail = "shows the icon of the spell #showtooltip picks: Arcane Shot"
    hint = "Click to pick, Save to keep"
    hint_w = canvas.text_width(hint, font)
    # The left text is anchored to end before the right hint and truncates there, as the FontString does.
    available = status_w - 10 - 8 - hint_w - 10
    left = fit(canvas, automatic + " " + detail, font, available)
    if len(left) <= len(automatic):
        canvas.text(status_x + 10, status_y, left, font, GREEN, box_height=STATUS_HEIGHT)
    else:
        canvas.text(status_x + 10, status_y, automatic, font, GREEN, box_height=STATUS_HEIGHT)
        cursor = status_x + 10 + canvas.text_width(automatic, font)
        canvas.text(cursor, status_y, left[len(automatic) :], font, box_height=STATUS_HEIGHT)
    canvas.text(
        status_x + status_w - 10 - hint_w,
        status_y,
        hint,
        font,
        MUTED,
        box_height=STATUS_HEIGHT,
    )


def window(ui, *, body, current_line, caret_column, data, completion=None, picker=False, picker_icon=None):
    rail_width, _ = side_tab_extent(ui)
    canvas = ui.canvas(WINDOW_WIDTH + 2 * X + rail_width, WINDOW_HEIGHT + 2 * Y)
    background(canvas, X, Y, WINDOW_WIDTH, WINDOW_HEIGHT)
    # The search box sits beside the portrait; the list runs from below it down to the footer.
    wowmock.search_box(
        canvas,
        X + LIST_LEFT + SEARCH_LEFT,
        Y - SEARCH_TOP,
        SEARCH_WIDTH,
        SEARCH_HEIGHT,
        instructions="Search macros",
    )
    canvas.text(
        X + LIST_LEFT + LIST_WIDTH - COUNT_WIDTH,
        Y - SEARCH_TOP,
        f"{len(MACROS)}/{MAX_CHARACTER}",
        FONTS["GameFontHighlightSmall"],
        MUTED,
        justify="RIGHT",
        width=COUNT_WIDTH,
        box_height=SEARCH_HEIGHT,
    )
    list_x = X + LIST_LEFT
    list_y = Y - LIST_TOP
    inset(canvas, list_x, list_y, LIST_WIDTH, LIST_HEIGHT)
    scroll_x = list_x + INSET_PADDING
    scroll_y = list_y + INSET_PADDING
    scroll_w = LIST_WIDTH - INSET_PADDING - (SCROLL_WIDTH + SCROLL_GAP + SCROLL_RIGHT_PADDING)
    scroll_h = LIST_HEIGHT - INSET_PADDING * 2
    for index, (icon, name, _) in enumerate(MACROS):
        if picker and index == SELECTED:
            icon = picker_icon or PICKER_ICON
        row_y = scroll_y + index * ROW_HEIGHT
        height = min(ROW_HEIGHT, scroll_y + scroll_h - row_y)
        if height <= 0:
            break
        summary = data["summary"][index + 1]
        if index not in ON_BAR:
            summary = f"{summary} · Not on a bar" if summary else "Not on a bar"
        draw_row(
            canvas,
            scroll_x,
            row_y,
            scroll_w,
            icon,
            name,
            summary,
            index == SELECTED,
            height,
        )
    wowmock.minimal_scrollbar(
        canvas,
        scroll_x + scroll_w + SCROLL_GAP,
        scroll_y,
        scroll_h,
        visible=0.8,
    )
    # The selected macro's header on one line, beside the list.
    header_x = X + LIST_LEFT + LIST_WIDTH + COLUMN_GAP
    header_y = Y - HEADER_TOP
    header_w = WINDOW_WIDTH + INSET_RIGHT - LIST_LEFT - LIST_WIDTH - COLUMN_GAP
    name, icon = MACROS[SELECTED][1], MACROS[SELECTED][0]
    if picker:
        icon = picker_icon or PICKER_ICON
    canvas.draw(
        ui.texture("interface/common/whiteiconframe.blp"),
        header_x,
        header_y,
        HEADER_ICON_FRAME,
        HEADER_ICON_FRAME,
        GOLD,
    )
    draw_icon(
        canvas,
        f"interface/icons/{icon}.blp",
        header_x + (HEADER_ICON_FRAME - HEADER_ICON) // 2,
        header_y + (HEADER_ICON_FRAME - HEADER_ICON) // 2,
        HEADER_ICON,
    )
    canvas.text(header_x + HEADER_ICON_FRAME + 8, header_y + 1, name, FONTS["GameFontNormalLarge"])
    canvas.text(
        header_x + HEADER_ICON_FRAME + 8,
        header_y + 20,
        BAR_TEXT,
        FONTS["GameFontHighlightSmall"],
        MUTED,
    )
    button(
        canvas,
        header_x + header_w - RENAME_WIDTH,
        header_y + (HEADER_HEIGHT - RENAME_HEIGHT) // 2,
        RENAME_WIDTH,
        "Back to code" if picker else "Rename",
        h=RENAME_HEIGHT,
    )
    if picker:
        draw_picker(canvas, picker_icon or PICKER_ICON)
        text_x = text_y = text_w = None
    else:
        # The full-height code surface, its gutter, the "What it does" panel at its bottom, and the status strip.
        text_x, text_y, text_w, _ = draw_editor(canvas, body, current_line, caret_column, data)
        editor_x, editor_y, editor_w, editor_h = editor_geometry()
        cases = data.get("explain", [])
        if cases and completion is None:
            panel_h = EXPLAIN_ROW_TOP + len(cases) * EXPLAIN_ROW_HEIGHT + EXPLAIN_TITLE_TOP
            panel_x = editor_x + EXPLAIN_INSET
            panel_y = editor_y + editor_h - EXPLAIN_BOTTOM - panel_h
            panel_w = editor_w - 2 * EXPLAIN_INSET
            canvas.fill(panel_x, panel_y, panel_w, panel_h, SURFACE)
            explain_panel(canvas, panel_x, panel_y, panel_w, cases)
        status_x, status_y, status_w, _ = status_geometry()
        status_bar(canvas, status_x, status_y, status_w, data["length"], "Arcane Shot on Defias Pillager", data)
    # The window's own buttons, with the edited macro treated as dirty so Save and Cancel are live.
    button_y = Y + WINDOW_HEIGHT - 8 - BUTTON_HEIGHT
    button(canvas, X + LIST_LEFT, button_y, BUTTON_WIDTH, "New", h=BUTTON_HEIGHT)
    button(canvas, X + LIST_LEFT + BUTTON_WIDTH + FOOTER_GAP, button_y, DELETE_WIDTH, "Delete", h=BUTTON_HEIGHT)
    button(
        canvas,
        X + LIST_LEFT + BUTTON_WIDTH + DELETE_WIDTH + FOOTER_GAP * 2,
        button_y,
        HISTORY_WIDTH,
        "History",
        h=BUTTON_HEIGHT,
    )
    button(
        canvas,
        X + LIST_LEFT + BUTTON_WIDTH + DELETE_WIDTH + HISTORY_WIDTH + FOOTER_GAP * 3,
        button_y,
        IMPORT_WIDTH,
        "Import",
        h=BUTTON_HEIGHT,
    )
    button(canvas, X + WINDOW_WIDTH + INSET_RIGHT - BUTTON_WIDTH, button_y, BUTTON_WIDTH, "Save", h=BUTTON_HEIGHT)
    button(
        canvas,
        X + WINDOW_WIDTH + INSET_RIGHT - BUTTON_WIDTH * 2 - FOOTER_GAP,
        button_y,
        BUTTON_WIDTH,
        "Cancel",
        h=BUTTON_HEIGHT,
    )
    # The metal frame, portrait, title and close button sit over the contents; the side tabs hang off its right edge.
    wowmock.portrait_frame_art(canvas, X, Y, WINDOW_WIDTH, WINDOW_HEIGHT, IDENTITY_ICON, "Macros")
    # As in Blizzard's spellbook and Professions windows, the tabs start at the frame's right edge and run into
    # the margin, leaving the list and editor the whole window width.
    side_tabs(canvas, X + WINDOW_WIDTH + SIDE_TAB_X, Y + SIDE_TAB_TOP, TAB_SELECTED)
    # The popup is drawn last, over the editor text, as the editor's popup is in game.
    if completion:
        draw_completion(canvas, completion, caret_column, text_x, text_y, text_w)
    return canvas


def side_tab_extent(ui):
    """One rail rectangle over both stacked tabs: the native art's width and each visible tab's height."""
    art = ui.atlas("common-sidetab")
    return art.width, 2 * (art.height - 5) + SIDE_TAB_GAP


def window_layout(ui):
    editor_x, editor_y, editor_w, editor_h = editor_geometry()
    status_x, status_y, status_w, status_h = status_geometry()
    header_x = X + LIST_LEFT + LIST_WIDTH + COLUMN_GAP
    header_y = Y - HEADER_TOP
    button_y = Y + WINDOW_HEIGHT - 8 - BUTTON_HEIGHT
    rail_width, rail_height = side_tab_extent(ui)
    widgets = [
        {
            "name": "search",
            "role": "input",
            "x": X + LIST_LEFT + SEARCH_LEFT,
            "y": Y - SEARCH_TOP,
            "w": SEARCH_WIDTH,
            "h": SEARCH_HEIGHT,
        },
        {
            "name": "count",
            "role": "text",
            "x": X + LIST_LEFT + LIST_WIDTH - COUNT_WIDTH,
            "y": Y - SEARCH_TOP,
            "w": COUNT_WIDTH,
            "h": SEARCH_HEIGHT,
        },
        {
            "name": "list",
            "role": "list",
            "x": X + LIST_LEFT,
            "y": Y - LIST_TOP,
            "w": LIST_WIDTH,
            "h": LIST_HEIGHT,
        },
        {
            "name": "rename",
            "role": "button",
            "x": header_x + WINDOW_WIDTH + INSET_RIGHT - LIST_LEFT - LIST_WIDTH - COLUMN_GAP - RENAME_WIDTH,
            "y": header_y + (HEADER_HEIGHT - RENAME_HEIGHT) // 2,
            "w": RENAME_WIDTH,
            "h": RENAME_HEIGHT,
        },
        {"name": "editor", "role": "edit", "x": editor_x, "y": editor_y, "w": editor_w, "h": editor_h},
        {"name": "status", "role": "status", "x": status_x, "y": status_y, "w": status_w, "h": status_h},
        {
            "name": "new",
            "role": "button",
            "x": X + LIST_LEFT,
            "y": button_y,
            "w": BUTTON_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "delete",
            "role": "button",
            "x": X + LIST_LEFT + BUTTON_WIDTH + FOOTER_GAP,
            "y": button_y,
            "w": DELETE_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "history",
            "role": "button",
            "x": X + LIST_LEFT + BUTTON_WIDTH + DELETE_WIDTH + FOOTER_GAP * 2,
            "y": button_y,
            "w": HISTORY_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "import",
            "role": "button",
            "x": X + LIST_LEFT + BUTTON_WIDTH + DELETE_WIDTH + HISTORY_WIDTH + FOOTER_GAP * 3,
            "y": button_y,
            "w": IMPORT_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "cancel",
            "role": "button",
            "x": X + WINDOW_WIDTH + INSET_RIGHT - BUTTON_WIDTH * 2 - FOOTER_GAP,
            "y": button_y,
            "w": BUTTON_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "save",
            "role": "button",
            "x": X + WINDOW_WIDTH + INSET_RIGHT - BUTTON_WIDTH,
            "y": button_y,
            "w": BUTTON_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "tabs",
            "role": "tabs",
            "edge": "outside-right",
            "x": X + WINDOW_WIDTH + SIDE_TAB_X,
            "y": Y + SIDE_TAB_TOP,
            "w": rail_width,
            "h": rail_height,
        },
    ]
    return {"frame": {"x": X, "y": Y, "w": WINDOW_WIDTH, "h": WINDOW_HEIGHT}, "widgets": widgets}


# The History dialog's sample snapshots. Each live row says what changed against the next newer text; a deleted
# macro keeps its name and summary.
HISTORY_ENTRIES = [
    ("header", "This macro"),
    ("2026-11-10 14:32", "Line 2 changed"),
    ("2026-11-10 14:20", "Renamed to Arcane Shot"),
    ("2026-11-10 14:02", "Icon changed, +1 line"),
    ("header", "Deleted"),
    ("2026-11-10 13:50", "Trap: Freezing Trap"),
]


def history_geometry():
    x = X + (WINDOW_WIDTH - HISTORY_PANEL_WIDTH) // 2
    y = Y + (WINDOW_HEIGHT - HISTORY_PANEL_HEIGHT) // 2
    return x, y, HISTORY_PANEL_WIDTH, HISTORY_PANEL_HEIGHT


def draw_history(canvas):
    """The History window over the macro window: a native portrait frame, an inset list, and Restore."""
    x, y, w, h = history_geometry()
    background(canvas, x, y, w, h)
    inset_x, inset_y = x + 10, y + 50
    inset_w, inset_h = w - 20, h - 50 - 42
    inset(canvas, inset_x, inset_y, inset_w, inset_h)
    scroll_x = inset_x + HISTORY_PANEL_INSET
    scroll_y = inset_y + HISTORY_PANEL_INSET
    scroll_w = inset_w - HISTORY_PANEL_INSET - (HISTORY_SCROLL_WIDTH + HISTORY_SCROLL_GAP + HISTORY_SCROLL_RIGHT)
    scroll_h = inset_h - HISTORY_PANEL_INSET * 2
    for index, (time, summary) in enumerate(HISTORY_ENTRIES):
        row_y = scroll_y + index * ROW_HEIGHT
        height = min(ROW_HEIGHT, scroll_y + scroll_h - row_y)
        if height <= 0:
            break
        if index == 1:
            canvas.fill(scroll_x, row_y, scroll_w, height, (1, 0.82, 0.2, 0.10))
            canvas.fill(scroll_x, row_y + 3, 2, height - 6, (1, 0.82, 0.2, 1))
        if time == "header":
            canvas.text(
                scroll_x + 8,
                row_y + 10,
                summary,
                FONTS["GameFontHighlight"],
                GOLD,
                width=scroll_w - 14,
            )
        else:
            canvas.text(
                scroll_x + 8,
                row_y + 4,
                time,
                FONTS["GameFontHighlightSmall"],
                MUTED,
                width=scroll_w - 14,
            )
            canvas.text(
                scroll_x + 8,
                row_y + 20,
                summary,
                FONTS["GameFontHighlight"],
                GOLD if index == 1 else WHITE,
                width=scroll_w - 14,
            )
    wowmock.minimal_scrollbar(
        canvas,
        scroll_x + scroll_w + HISTORY_SCROLL_GAP,
        scroll_y,
        scroll_h,
        visible=0.8,
    )
    button(
        canvas,
        x + w - 10 - BUTTON_WIDTH,
        y + h - HISTORY_BOTTOM - BUTTON_HEIGHT,
        BUTTON_WIDTH,
        "Restore",
        h=BUTTON_HEIGHT,
    )
    wowmock.portrait_frame_art(canvas, x, y, w, h, IDENTITY_ICON, "History")
    return x, y, w, h


def history_layout():
    x, y, w, h = history_geometry()
    scroll_x = x + 10 + HISTORY_PANEL_INSET
    scroll_w = w - 20 - HISTORY_PANEL_INSET - (HISTORY_SCROLL_WIDTH + HISTORY_SCROLL_GAP + HISTORY_SCROLL_RIGHT)
    return {
        "frame": {"x": x, "y": y, "w": w, "h": h},
        "widgets": [
            {
                "name": "history-list",
                "role": "list",
                "x": scroll_x,
                "y": y + 50 + HISTORY_PANEL_INSET,
                "w": scroll_w,
                "h": h - 50 - 42 - HISTORY_PANEL_INSET * 2,
            },
            {
                "name": "history-restore",
                "role": "button",
                "x": x + w - 10 - BUTTON_WIDTH,
                "y": y + h - HISTORY_BOTTOM - BUTTON_HEIGHT,
                "w": BUTTON_WIDTH,
                "h": BUTTON_HEIGHT,
            },
        ],
    }


def draw_characters(canvas):
    """Characters copy panel with separate source scopes and bounded conflict detail."""
    x, y, w, h = X + 70, Y + 70, 440, 300
    inset(canvas, x, y, w, h)
    canvas.text(x + 14, y + 12, "Copy from another character", FONTS["GameFontNormal"], WHITE)
    canvas.text(
        x + 14,
        y + 42,
        "General One: - /cast Heal / + /cast Other",
        FONTS["GameFontHighlightSmall"],
        MUTED,
        width=400,
    )
    labels = ("Other - Forever · general · General One", "Other - Forever · character · Character One")
    for row, label in enumerate(labels):
        button(canvas, x + 14, y + 126 + row * 30, 390, label, h=26)
    wowmock.minimal_scrollbar(canvas, x + 410, y + 126, 124, visible=0.35)
    canvas.text(x + w - 24, y + 10, "×", FONTS["GameFontNormal"], WHITE)
    button(canvas, x + 14, y + h - 40, 180, "Keep both", h=26)
    button(canvas, x + 216, y + h - 40, 180, "Replace", h=26)
    return x, y, w, h


def characters_layout():
    x, y, w, h = X + 70, Y + 70, 440, 300
    return {
        "frame": {"x": x, "y": y, "w": w, "h": h},
        "widgets": [
            {"name": "characters-sources", "role": "list", "x": x + 14, "y": y + 126, "w": 390, "h": 124},
            {"name": "characters-keep", "role": "button", "x": x + 14, "y": y + h - 40, "w": 180, "h": 26},
            {"name": "characters-replace", "role": "button", "x": x + 216, "y": y + h - 40, "w": 180, "h": 26},
        ],
    }


# The Import box's sample text: a short macro already pasted and checked, so the scene shows the ready line and count.
IMPORT_BODY = "/cast [@mouseover,harm,nodead][] Arcane Shot\n/startattack"


def import_geometry():
    x = X + (WINDOW_WIDTH - IMPORT_PANEL_WIDTH) // 2
    y = Y + (WINDOW_HEIGHT - IMPORT_PANEL_HEIGHT) // 2
    return x, y, IMPORT_PANEL_WIDTH, IMPORT_PANEL_HEIGHT


def draw_import(canvas):
    """The Import box over the macro window: a pasted, checked macro with the panel's Import and Cancel buttons."""
    x, y, w, h = import_geometry()
    background(canvas, x, y, w, h)
    canvas.text(
        x + 12,
        y + IMPORT_HINT_TOP,
        "Paste a macro from wago.io or another character.",
        FONTS["GameFontHighlightSmall"],
        MUTED,
        width=w - 24,
    )
    box_x = x + 10
    box_y = y + IMPORT_HINT_TOP + IMPORT_HINT_HEIGHT + 8
    box_w = w - 20
    box_h = h - (IMPORT_HINT_TOP + IMPORT_HINT_HEIGHT + 8) - IMPORT_BOX_BOTTOM
    inset(canvas, box_x, box_y, box_w, box_h)
    line_y = box_y + IMPORT_PANEL_INSET + 4
    for line in IMPORT_BODY.split("\n"):
        canvas.text(
            box_x + IMPORT_PANEL_INSET + 2,
            line_y,
            line,
            FONTS["GameFontHighlight"],
            WHITE,
            width=box_w - IMPORT_PANEL_INSET * 2 - 4,
        )
        line_y += 18
    canvas.text(
        x + 12,
        y + h - IMPORT_STATUS_BOTTOM - 6,
        "Ready to import.",
        FONTS["GameFontHighlightSmall"],
        (0.2, 1, 0.6),
    )
    canvas.text(
        x + w - 70,
        y + h - IMPORT_STATUS_BOTTOM - 6,
        f"{len(IMPORT_BODY)}/255",
        FONTS["GameFontHighlightSmall"],
        MUTED,
        width=58,
        justify="RIGHT",
    )
    button(
        canvas,
        x + w - 10 - IMPORT_BUTTON_WIDTH,
        y + h - IMPORT_BOTTOM - IMPORT_BUTTON_HEIGHT,
        IMPORT_BUTTON_WIDTH,
        "Import",
        h=IMPORT_BUTTON_HEIGHT,
    )
    button(
        canvas,
        x + w - 10 - IMPORT_BUTTON_WIDTH * 2 - 6,
        y + h - IMPORT_BOTTOM - IMPORT_BUTTON_HEIGHT,
        IMPORT_BUTTON_WIDTH,
        "Cancel",
        h=IMPORT_BUTTON_HEIGHT,
    )
    wowmock.portrait_frame_art(canvas, x, y, w, h, IDENTITY_ICON, "Import macro")
    return x, y, w, h


def import_layout():
    x, y, w, h = import_geometry()
    box_y = y + IMPORT_HINT_TOP + IMPORT_HINT_HEIGHT + 8
    return {
        "frame": {"x": x, "y": y, "w": w, "h": h},
        "widgets": [
            {
                "name": "import-input",
                "role": "input",
                "x": x + 10,
                "y": box_y,
                "w": w - 20,
                "h": h - (IMPORT_HINT_TOP + IMPORT_HINT_HEIGHT + 8) - IMPORT_BOX_BOTTOM,
            },
            {
                "name": "import-cancel",
                "role": "button",
                "x": x + w - 10 - IMPORT_BUTTON_WIDTH * 2 - 6,
                "y": y + h - IMPORT_BOTTOM - IMPORT_BUTTON_HEIGHT,
                "w": IMPORT_BUTTON_WIDTH,
                "h": IMPORT_BUTTON_HEIGHT,
            },
            {
                "name": "import-button",
                "role": "button",
                "x": x + w - 10 - IMPORT_BUTTON_WIDTH,
                "y": y + h - IMPORT_BOTTOM - IMPORT_BUTTON_HEIGHT,
                "w": IMPORT_BUTTON_WIDTH,
                "h": IMPORT_BUTTON_HEIGHT,
            },
        ],
    }


def picker_layout(ui):
    editor_x, editor_y, editor_w, editor_h = editor_geometry()
    status_x, status_y, status_w, status_h = status_geometry()
    left = editor_x + PICKER_PADDING
    top = editor_y + PICKER_PADDING
    filter_w = 110
    filter_x = editor_x + editor_w - PICKER_PADDING - filter_w
    search_w = filter_x - PICKER_SEARCH_GAP - left
    grid_y = top + PICKER_SEARCH_HEIGHT + PICKER_ROW_TOP_GAP
    grid_w = editor_w - 2 * PICKER_PADDING - (PICKER_SCROLL_WIDTH + PICKER_SCROLL_GAP)
    button_y = Y + WINDOW_HEIGHT - 8 - BUTTON_HEIGHT
    header_x = X + LIST_LEFT + LIST_WIDTH + COLUMN_GAP
    header_y = Y - HEADER_TOP
    rail_width, rail_height = side_tab_extent(ui)
    widgets = [
        {"name": "picker-search", "role": "input", "x": left, "y": top, "w": search_w, "h": PICKER_SEARCH_HEIGHT},
        {"name": "picker-filter", "role": "button", "x": filter_x, "y": top, "w": filter_w, "h": 18},
        {
            "name": "picker-list",
            "role": "list",
            "x": left,
            "y": grid_y,
            "w": grid_w,
            "h": editor_y + editor_h - PICKER_PADDING - grid_y,
        },
        {"name": "picker-status", "role": "status", "x": status_x, "y": status_y, "w": status_w, "h": status_h},
        {
            "name": "rename",
            "role": "button",
            "x": header_x + WINDOW_WIDTH + INSET_RIGHT - LIST_LEFT - LIST_WIDTH - COLUMN_GAP - RENAME_WIDTH,
            "y": header_y + (HEADER_HEIGHT - RENAME_HEIGHT) // 2,
            "w": RENAME_WIDTH,
            "h": RENAME_HEIGHT,
        },
        {"name": "new", "role": "button", "x": X + LIST_LEFT, "y": button_y, "w": BUTTON_WIDTH, "h": BUTTON_HEIGHT},
        {
            "name": "delete",
            "role": "button",
            "x": X + LIST_LEFT + BUTTON_WIDTH + FOOTER_GAP,
            "y": button_y,
            "w": DELETE_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "history",
            "role": "button",
            "x": X + LIST_LEFT + BUTTON_WIDTH + DELETE_WIDTH + FOOTER_GAP * 2,
            "y": button_y,
            "w": HISTORY_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "import",
            "role": "button",
            "x": X + LIST_LEFT + BUTTON_WIDTH + DELETE_WIDTH + HISTORY_WIDTH + FOOTER_GAP * 3,
            "y": button_y,
            "w": IMPORT_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "cancel",
            "role": "button",
            "x": X + WINDOW_WIDTH + INSET_RIGHT - BUTTON_WIDTH * 2 - FOOTER_GAP,
            "y": button_y,
            "w": BUTTON_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "save",
            "role": "button",
            "x": X + WINDOW_WIDTH + INSET_RIGHT - BUTTON_WIDTH,
            "y": button_y,
            "w": BUTTON_WIDTH,
            "h": BUTTON_HEIGHT,
        },
        {
            "name": "tabs",
            "role": "tabs",
            "edge": "outside-right",
            "x": X + WINDOW_WIDTH + SIDE_TAB_X,
            "y": Y + SIDE_TAB_TOP,
            "w": rail_width,
            "h": rail_height,
        },
    ]
    return {"frame": {"x": X, "y": Y, "w": WINDOW_WIDTH, "h": WINDOW_HEIGHT}, "widgets": widgets}


# The Shorten preview's sample: five long lines rewritten to fit, with the old line in red and the new one in green.
SHORTEN_OLD_LINE = "/spell      [harm, nodead]      Arcane Shot"
SHORTEN_NEW_LINE = "/cast [harm,nodead] Arcane Shot"
SHORTEN_OLD = "\n".join([SHORTEN_OLD_LINE] * 6)
SHORTEN_NEW = "\n".join([SHORTEN_NEW_LINE] * 6)


def shorten_geometry():
    x = X + (WINDOW_WIDTH - SHORTEN_PANEL_WIDTH) // 2
    y = Y + (WINDOW_HEIGHT - SHORTEN_PANEL_HEIGHT) // 2
    return x, y, SHORTEN_PANEL_WIDTH, SHORTEN_PANEL_HEIGHT


def draw_shorten(canvas):
    """The Shorten preview over the macro window: the changed lines and the counts before and after."""
    x, y, w, h = shorten_geometry()
    background(canvas, x, y, w, h)
    canvas.text(
        x + 12,
        y + SHORTEN_HINT_TOP,
        "This rewrite only removes what the macro does not need.",
        FONTS["GameFontHighlightSmall"],
        MUTED,
        width=w - 24,
    )
    box_x = x + 10
    box_y = y + SHORTEN_HINT_TOP + SHORTEN_HINT_HEIGHT + 8
    box_w = w - 20
    box_h = h - (SHORTEN_HINT_TOP + SHORTEN_HINT_HEIGHT + 8) - SHORTEN_BOX_BOTTOM
    inset(canvas, box_x, box_y, box_w, box_h)
    diff_y = box_y + SHORTEN_PANEL_INSET + 2
    for _ in range(6):
        canvas.text(
            box_x + SHORTEN_PANEL_INSET + 2,
            diff_y,
            f"-{SHORTEN_OLD_LINE}",
            MONO,
            (1, 0.25, 0.25),
            width=box_w - SHORTEN_PANEL_INSET * 2 - 4,
        )
        diff_y += 18
        canvas.text(
            box_x + SHORTEN_PANEL_INSET + 2,
            diff_y,
            f"+{SHORTEN_NEW_LINE}",
            MONO,
            (0.2, 1, 0.6),
            width=box_w - SHORTEN_PANEL_INSET * 2 - 4,
        )
        diff_y += 18
    canvas.text(
        x + 12,
        y + h - SHORTEN_STATUS_BOTTOM - 6,
        f"{len(SHORTEN_OLD)}/255, now {len(SHORTEN_NEW)}/255",
        FONTS["GameFontHighlightSmall"],
        (0.2, 1, 0.6),
    )
    button(
        canvas,
        x + w - 10 - SHORTEN_BUTTON_WIDTH,
        y + h - SHORTEN_BOTTOM - SHORTEN_BUTTON_HEIGHT,
        SHORTEN_BUTTON_WIDTH,
        "Apply",
        h=SHORTEN_BUTTON_HEIGHT,
    )
    button(
        canvas,
        x + w - 10 - SHORTEN_BUTTON_WIDTH * 2 - 6,
        y + h - SHORTEN_BOTTOM - SHORTEN_BUTTON_HEIGHT,
        SHORTEN_BUTTON_WIDTH,
        "Cancel",
        h=SHORTEN_BUTTON_HEIGHT,
    )
    wowmock.portrait_frame_art(canvas, x, y, w, h, IDENTITY_ICON, "Shorten macro")
    return x, y, w, h


def shorten_layout():
    x, y, w, h = shorten_geometry()
    box_y = y + SHORTEN_HINT_TOP + SHORTEN_HINT_HEIGHT + 8
    return {
        "frame": {"x": x, "y": y, "w": w, "h": h},
        "widgets": [
            {
                "name": "shorten-diff",
                "role": "text",
                "x": x + 10,
                "y": box_y,
                "w": w - 20,
                "h": h - (SHORTEN_HINT_TOP + SHORTEN_HINT_HEIGHT + 8) - SHORTEN_BOX_BOTTOM,
            },
            {
                "name": "shorten-cancel",
                "role": "button",
                "x": x + w - 10 - SHORTEN_BUTTON_WIDTH * 2 - 6,
                "y": y + h - SHORTEN_BOTTOM - SHORTEN_BUTTON_HEIGHT,
                "w": SHORTEN_BUTTON_WIDTH,
                "h": SHORTEN_BUTTON_HEIGHT,
            },
            {
                "name": "shorten-apply",
                "role": "button",
                "x": x + w - 10 - SHORTEN_BUTTON_WIDTH,
                "y": y + h - SHORTEN_BOTTOM - SHORTEN_BUTTON_HEIGHT,
                "w": SHORTEN_BUTTON_WIDTH,
                "h": SHORTEN_BUTTON_HEIGHT,
            },
        ],
    }


def layout(ui):
    return {
        "scenes": [
            window_layout(ui),
            history_layout(),
            import_layout(),
            shorten_layout(),
            picker_layout(ui),
            characters_layout(),
        ]
    }


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
        "explain": data["explain"].get(SELECTED + 1, []),
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

    history_canvas = window(
        ui,
        body=MACROS[SELECTED][2],
        current_line=CURRENT_LINE,
        caret_column=len(MACROS[SELECTED][2].split("\n")[CURRENT_LINE]),
        data=window_data,
    )
    draw_history(history_canvas)
    wowmock.scene(ui, [(history_canvas, 0, 0)]).save(output / "history.png")
    print(output / "history.png")

    characters_canvas = window(
        ui,
        body=MACROS[SELECTED][2],
        current_line=CURRENT_LINE,
        caret_column=len(MACROS[SELECTED][2].split("\n")[CURRENT_LINE]),
        data=window_data,
    )
    draw_characters(characters_canvas)
    wowmock.scene(ui, [(characters_canvas, 0, 0)]).save(output / "characters.png")
    print(output / "characters.png")

    import_canvas = window(
        ui,
        body=MACROS[SELECTED][2],
        current_line=CURRENT_LINE,
        caret_column=len(MACROS[SELECTED][2].split("\n")[CURRENT_LINE]),
        data=window_data,
    )
    draw_import(import_canvas)
    wowmock.scene(ui, [(import_canvas, 0, 0)]).save(output / "import.png")
    print(output / "import.png")

    shorten_canvas = window(
        ui,
        body=MACROS[SELECTED][2],
        current_line=CURRENT_LINE,
        caret_column=len(MACROS[SELECTED][2].split("\n")[CURRENT_LINE]),
        data=window_data,
    )
    draw_shorten(shorten_canvas)
    wowmock.scene(ui, [(shorten_canvas, 0, 0)]).save(output / "shorten.png")
    print(output / "shorten.png")

    picker_canvas = window(
        ui,
        body=MACROS[SELECTED][2],
        current_line=CURRENT_LINE,
        caret_column=len(MACROS[SELECTED][2].split("\n")[CURRENT_LINE]),
        data={**window_data, "explain": []},
        picker=True,
    )
    wowmock.scene(ui, [(picker_canvas, 0, 0)]).save(output / "picker.png")
    print(output / "picker.png")

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

    recipe_data = {
        "lines": {1: "pet"},
        "summary": data["summary"],
        "explain": [],
        "diagnostics": [],
        "length": len(RECIPE_BODY),
    }
    recipe_completion = (RECIPE_BODY.split("\n"), 0, data["recipe"]["items"][:POPUP_ROWS], 0, 0)
    canvas = window(
        ui,
        body=RECIPE_BODY,
        current_line=0,
        caret_column=len(RECIPE_BODY),
        data=recipe_data,
        completion=recipe_completion,
    )
    wowmock.scene(ui, [(canvas, 0, 0)]).save(output / "recipes.png")
    print(output / "recipes.png")
    (output / "layout.json").write_text(json.dumps(layout(ui), indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
