Macro Assist Forever gives WoW: Forever a macro window of its own. Blizzard's macro panel still opens; this addon puts every macro in one searchable list and opens the selected one in a mono-font editor beside it.

Macro Assist Forever needs [Forever Core](https://www.curseforge.com/wow/addons/forevercore), which CurseForge and Wago install with it.

Free, with nothing locked behind it. If it saves you time, you can [sponsor me on GitHub](https://github.com/sponsors/cjber), which takes no fees, or [buy me a coffee on Ko-fi](https://ko-fi.com/cjber). For help and each day's release notes, [join me on Discord](https://discord.gg/FpHugGxRJY).

[![Join me on Discord](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/discord-button.png)](https://discord.gg/FpHugGxRJY) [![Sponsor me on GitHub](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/github-sponsors-button.png)](https://github.com/sponsors/cjber) [![Support me on Ko-fi](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/kofi-button.png)](https://ko-fi.com/cjber)

## Features

- **Every macro in one searchable list.** General and character tabs sit beside the list they filter, and each macro shows its icon, name and a short summary of its main action with a count of the other cases. The count sits beside the search box, which filters by name or summary as you type.
- **A real editor.** The macro text uses JetBrains Mono on a dark code panel, with a line-number gutter, a current-line highlight, and colour for commands, conditions, units and spells.
- **A plain-English "What it does" panel.** The bottom of the code panel shows one row per click and modifier branch, read from the macro's own parse, and hides when there is nothing it can explain.
- **Completions as you type.** Type `/` for a command, `[` for a condition, `@` for a unit or a spell name. Up and Down move the suggestions, Tab inserts one, and each shows its live value.
- **Live conditions and spells.** Condition values come from the game right now, and the spellbook supplies your spell names and the ranks you know.
- **Problems with a fix.** A wavy underline marks text the game cannot run. Hover it for the explanation, then press Tab or click it to apply the suggested fix.
- **A status bar that says what fires now.** It shows the first problem with Tab to fix, what the first matching line would do with your current target, and the character count out of 255.
- **Rename, New, Save, Cancel and Delete.** Delete asks for a second click. Rename and New use the game's name and icon picker. Drag a row or the header icon to an action bar.
- **History with Restore.** Every save, rename and delete keeps the previous name, icon and text, the newest 20 for each macro. History lists them with their time and what changed, and Restore puts one back. Deleted macros stay restorable in a Deleted section.
- **Safe to open in combat.** Every write is turned off in combat, Restore included, with a line saying why. Edits are saved when the window closes out of combat.

![The macro list beside the mono editor](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/window.png)

The searchable macro list on the left, with the selected macro open in the editor on the right and the "What it does" panel below the code.

![Conditions offered with live values beside a problem in the macro](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/completion.png)

Conditions are offered with their live value, and a wavy underline marks a problem on the line above.

![The History window listing saved versions and a deleted macro](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/history.png)

History keeps the previous versions of each macro, with a Deleted section for macros that can be restored.

## Usage

Open the macro window as you always do: `/macro`, `/m`, the game menu, or your keybind. `/macroassist` opens it too, and so does the addon compartment. Each one closes the window again when it is already open. General holds account macros and the character tab holds this character's macros.

Click a macro to edit it, or type in the search box to narrow the list. New creates a macro after you choose its name and icon. Rename changes the selected macro's name and icon. Cancel puts the editor back to the saved text, and Save writes it immediately. History lists the macro's earlier versions, and Restore puts one back. Closing also saves your text out of combat.

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

Bug reports, feature requests and pull requests are welcome on each addon's GitHub. Everyone whose report or idea ships is thanked by name in the addon's credits and changelog.

For help, ideas and each day's release notes, join [cjber's Workshop on Discord](https://discord.gg/FpHugGxRJY).

<!-- forever-family:end -->

Source is on [GitHub](https://github.com/cjber/macro-assist-forever). GPL-3.0-or-later. World of Warcraft is a trademark of Blizzard Entertainment, Inc. This addon is not affiliated with or endorsed by Blizzard Entertainment.

Built with AI assistance.
