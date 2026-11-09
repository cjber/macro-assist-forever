<p align="center"><img src="media/icon-400.png" width="96" height="96" alt="Macro Assist Forever icon"></p>

<h1 align="center">Macro Assist Forever</h1>

<p align="center">Give WoW: Forever a macro window of its own: every macro in one list, and a mono-font editor with live checks.</p>

<p align="center">
<a href="https://github.com/cjber/macro-assist-forever/actions/workflows/ci.yml"><img src="https://github.com/cjber/macro-assist-forever/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<a href="https://github.com/cjber/macro-assist-forever/releases/latest"><img src="https://img.shields.io/github/v/release/cjber/macro-assist-forever" alt="Latest release"></a>
</p>

## Features

- **Every macro in one list.** General and character tabs show each macro with its icon, name and a one-line summary of what it does.
- **A real editor.** The macro text uses JetBrains Mono, with line numbers, a highlight on the current line, and colour for commands, conditions, units and spells.
- **Completions as you type.** Type `/` for a command, `[` for a condition, `@` for a unit or start a spell name. Up and Down move through the suggestions, Tab inserts one, and a tooltip explains the highlighted entry.
- **Live conditions and spells.** Condition values come from the game right now, and the spellbook supplies your spell names and the ranks you know.
- **Problems with a fix.** A wavy underline marks text the game cannot run. Hover it for the explanation, then press Tab or click it to apply the suggested fix.
- **A status line that says what fires now.** It shows the first problem, the action the first matching line would take with your current target, and the character count out of 255.
- **Name and icon, New, Save, Cancel and Delete.** Delete asks for a second click. Name and icon use the game's own picker, as does a new macro.
- **Safe to open in combat.** Every button that writes to your macros is turned off in combat, with a line in the status row saying why. Edits are saved when the window closes out of combat.

<p align="center"><img src="docs/screenshots/window.png" alt="The macro list above the mono editor"></p>

Every macro in one list, with the selected macro open in the editor below.

<p align="center"><img src="docs/screenshots/completion.png" alt="Conditions offered with live values beside a problem in the macro"></p>

Conditions are offered with their live value, and a wavy underline marks a problem on the line above.

## Install

Put the `MacroAssistForever` folder in `World of Warcraft/_forever_/Interface/AddOns`, or install it from CurseForge. Then type `/reload`.

Nothing else is needed. The addon works with no other addon installed.

## Usage

Open the macro window as you always do: `/macro`, the game menu, or your keybind. `/ma` or `/macroassist` opens it too, and so does the addon compartment. The General tab holds account macros and the character tab holds this character's macros.

Click a macro to edit it. New creates a macro after you choose its name and icon. Change Name/Icon renames the selected macro. Cancel puts the editor back to the saved text, and Save writes it immediately. Closing the window also saves your text when you are out of combat.

## Works alongside

Macro Assist Forever covers Blizzard's macro panel but leaves the panel, its keybind and the macro store in place. It does not run macros for you and needs no other addon.

## Development

Run `stylua --check .`, `luacheck .`, and every `tests/*_spec.lua` under LuaJIT. Render the screenshots with `python3 tools/screenshots.py`, then check them with `python3 tools/check_screenshots.py` and `python3 tools/visual_audit.py`.

## Credits

Thanks to the JetBrains Mono project for the bundled mono font, used under the SIL Open Font License, and to warcraft.wiki.gg for the macro conditional reference. The shared family, report and log files come from [Forever Core](https://github.com/cjber/forever-core). [THIRD_PARTY.md](THIRD_PARTY.md) lists every input and its licence.

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

Bug reports, feature requests and pull requests are welcome on each addon's GitHub. Everyone whose report or idea ships is thanked by name in the addon's credits and changelog.

For help, ideas and each day's release notes, join [cjber's Workshop on Discord](https://discord.gg/FpHugGxRJY).

<!-- forever-family:end -->
