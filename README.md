<p align="center"><img src="media/icon-400.png" width="96" height="96" alt="Macro Assist Forever icon"></p>

<h1 align="center">Macro Assist Forever</h1>

<p align="center">Give WoW: Forever a macro window of its own: every macro in one list, and a mono-font editor with live checks.</p>

<p align="center">
<a href="https://github.com/cjber/macro-assist-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/macro-assist-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/macro-assist-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/macro-assist-forever" alt="Latest release"></a>
</p>

## Features

- **Every macro in one searchable list.** General and character tabs hang off the window's right edge, as in the game's spellbook, and each macro shows its icon, name and a short summary of its main action with a count of the other cases. The selected row has a soft gold fill and left bar, and the count sits beside the search box, which filters by name or summary as you type.
- **A real editor.** The macro text uses JetBrains Mono on a dark code panel, with a line-number gutter, a highlight on the current line, and colour for commands, conditions, units and spells.
- **A plain-English "What it does" panel.** The bottom of the code panel shows one row per click and modifier branch, read from the macro's own parse, and hides when there is nothing it can explain.
- **Completions as you type.** Type `/` for a command, `[` for a condition, `@` for a unit or start a spell name. Up and Down move through the suggestions, Tab inserts one, and each suggestion shows its live value as a yes or no tag.
- **Live conditions and spells.** Condition values come from the game right now, and the spellbook supplies your spell names and the ranks you know.
- **Problems with a fix.** A wavy underline marks text the game cannot run. Hover it for the explanation, then press Tab or click it to apply the suggested fix.
- **A status bar that says what fires now.** It shows the first problem in full with Tab to fix, the action the first matching line would take with your current target, and the character count out of 255 with a meter.
- **An icon picker in the window.** Click the header icon or Rename and the code gives way to one grid: the macro's Automatic icon and the icons of what it casts first, then your spellbook, then every icon in the game. Search by icon file name or by your own spells and items, or filter by class, spell school or item slot. The name is editable in the header, a pick shows at once, and Save keeps it.
- **Rename, New, Save, Cancel and Delete.** Delete asks for a second click. New adds a macro and opens the picker with its name ready to type. Drag a row or the header icon to an action bar to place the macro there.
- **History with Restore.** Every save, rename and delete keeps the macro's previous name, icon and text, the newest 20 for each macro. History lists them with their time and what changed, and Restore puts one back. Deleted macros stay in a Deleted section until you restore them.
- **Safe to open in combat.** Every button that writes to your macros is turned off in combat, Restore included, with a line in the status row saying why. Edits are saved when the window closes out of combat.

<p align="center"><img src="docs/screenshots/window.png" alt="The macro list beside the mono editor"></p>

The searchable macro list on the left, with the selected macro open in the editor on the right and the "What it does" panel below the code.

<p align="center"><img src="docs/screenshots/completion.png" alt="Conditions offered with live values beside a problem in the macro"></p>

Conditions are offered with their live value, and a wavy underline marks a problem on the line above.

<p align="center"><img src="docs/screenshots/history.png" alt="The History window listing saved versions and a deleted macro"></p>

History keeps the previous versions of each macro, with a Deleted section for macros that can be restored.

<p align="center"><img src="docs/screenshots/picker.png" alt="The icon picker in place of the editor, with the macro's own icons first"></p>

The icon picker: the macro's Automatic icon and what it casts, your spellbook, then every icon, with search and filters.

## Install

Put the `MacroAssistForever` folder in `World of Warcraft/_forever_/Interface/AddOns`, or install it from CurseForge. Then type `/reload`.

Nothing else needs installing.

## Usage

Open the macro window as you always do: `/macro`, `/m`, the game menu, or your keybind. `/macroassist` opens it too, and so does the addon compartment. Each one closes the window again when it is already open. The General tab holds account macros and the character tab holds this character's macros.

Click a macro to edit it, or type in the search box to narrow the list by name or summary. New creates a macro and opens the icon picker with its name ready to type. Rename, or a click on the header icon, opens the picker for the selected macro; Back to code returns to the editor. Cancel puts the editor back to the saved text, and Save writes it immediately. History lists the macro's earlier versions, and Restore puts one back. Closing the window also saves your text when you are out of combat.

## Works alongside

Macro Assist Forever covers Blizzard's macro panel but leaves the panel, its keybind and the macro store in place. It does not run macros for you.

## Development

Run `stylua --check .`, `luacheck .`, and every `tests/*_spec.lua` under LuaJIT. Render the screenshots with `python3 tools/screenshots.py`, then check them with `python3 tools/check_screenshots.py` and `python3 tools/visual_audit.py`.

## Credits

Thanks to the JetBrains Mono project for the bundled mono font, used under the SIL Open Font License, and to warcraft.wiki.gg for the macro conditional reference. [THIRD_PARTY.md](THIRD_PARTY.md) lists every input and its licence.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE). World of Warcraft is a trademark of Blizzard Entertainment, Inc. This addon is not affiliated with or endorsed by Blizzard Entertainment.

<!-- forever-family:start -->

## The Forever addons

Each one works on its own, and they work together when you install more than one.

| Addon | What it does | Issues |
|---|---|---|
| [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) | Plans journeys on foot, by air, by sea and through portals, with directions in the tracker. | [Issues](https://github.com/cjber/shortest-path-forever/issues) |
| [Adventure Guide Forever](https://www.curseforge.com/wow/addons/adventure-guide-forever) | Suggests quests for your level and routes you from one to the next. | [Issues](https://github.com/cjber/adventure-guide-forever/issues) |
| [SkillUp Forever](https://www.curseforge.com/wow/addons/skillup-forever) | Shows skill-up chances, recipe costs and levelling routes in the Professions window. | [Issues](https://github.com/cjber/skillup-forever/issues) |
| [Legacy Forever](https://www.curseforge.com/wow/addons/legacy-forever) | Shows your unfinished Legacy challenges on the world map and tracks the ones you choose. | [Issues](https://github.com/cjber/legacy-forever/issues) |
| [Tweaks Forever](https://www.curseforge.com/wow/addons/tweaks-forever) | Adds quest automation, rare alerts and merchant options to the game's settings. | [Issues](https://github.com/cjber/tweaks-forever/issues) |
| [Field Guide Forever](https://www.curseforge.com/wow/addons/field-guide-forever) | Keeps a cosmetic journal of the creatures you kill, zone by zone. | [Issues](https://github.com/cjber/field-guide-forever/issues) |
| [Commissions Forever](https://www.curseforge.com/wow/addons/commissions-forever) | Lists your commission turn-ins, the materials in your bags and the next NPC to visit. | [Issues](https://github.com/cjber/commissions-forever/issues) |
| [Macro Assist Forever](https://www.curseforge.com/wow/addons/macro-assist-forever) | Adds a macro window with every macro in one list, a mono editor with live checks, and history. | [Issues](https://github.com/cjber/macro-assist-forever/issues) |

Bug reports, feature requests and pull requests are welcome on each addon's GitHub. Everyone whose report or idea ships is thanked by name on the Thanks page in game, in the store page and in the changelog, unless they ask not to be.

For help, ideas and each day's release notes, join [cjber's Workshop on Discord](https://discord.gg/FpHugGxRJY).

<!-- forever-family:end -->
