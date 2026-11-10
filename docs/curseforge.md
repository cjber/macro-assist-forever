Macro Assist Forever gives WoW: Forever a macro window of its own. Blizzard's macro panel still opens; this addon puts every macro in one searchable list and opens the selected one in a mono-font editor beside it.

## Features

- **Every macro in one searchable list.** General and character tabs show each macro with its icon, name and a summary of what it does, the selected row has a soft gold fill and left bar, and the count sits beside the search box, which filters by name or summary as you type.
- **A real editor.** The macro text uses JetBrains Mono on a dark code panel, with a line-number gutter, a highlight on the current line, and colour for commands, conditions, units and spells.
- **A plain-English "What it does" panel.** The bottom of the code panel shows one row per click and modifier branch, read from the macro's own parse, and hides when there is nothing it can explain.
- **Completions as you type.** Type `/` for a command, `[` for a condition, `@` for a unit or start a spell name. Up and Down move through the suggestions, Tab inserts one, and each suggestion shows its live value as a yes or no tag.
- **Live conditions and spells.** Condition values come from the game right now, and the spellbook supplies your spell names and the ranks you know.
- **Problems with a fix.** A wavy underline marks text the game cannot run. Hover it for the explanation, then press Tab or click it to apply the suggested fix.
- **A status bar that says what fires now.** It shows the first problem in full with Tab to fix, the action the first matching line would take with your current target, and the character count out of 255 with a meter.
- **Rename, New, Save, Cancel and Delete.** Delete asks for a second click. Rename and New use the game's own name and icon picker.
- **Safe to open in combat.** Every button that writes to your macros is turned off in combat, with a line in the status row saying why. Edits are saved when the window closes out of combat.

![The macro list beside the mono editor](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/window.png)

The searchable macro list on the left, with the selected macro open in the editor on the right and the "What it does" panel below the code.

![Conditions offered with live values beside a problem in the macro](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/completion.png)

Conditions are offered with their live value, and a wavy underline marks a problem on the line above.

## Usage

Open the macro window as you always do: `/macro`, `/m`, the game menu, or your keybind. `/macroassist` opens it too, and so does the addon compartment. Each one closes the window again when it is already open. The General tab holds account macros and the character tab holds this character's macros.

Click a macro to edit it, or type in the search box to narrow the list by name or summary. New creates a macro after you choose its name and icon. Rename changes the selected macro's name and icon. Cancel puts the editor back to the saved text, and Save writes it immediately. Closing the window also saves your text when you are out of combat.

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

Source is on [GitHub](https://github.com/cjber/macro-assist-forever). GPL-3.0-or-later. World of Warcraft is a trademark of Blizzard Entertainment, Inc. This addon is not affiliated with or endorsed by Blizzard Entertainment.
