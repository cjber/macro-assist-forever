Macro Assist Forever gives WoW: Forever a macro window of its own. Blizzard's macro panel still opens; this addon puts every macro in one searchable list and opens the selected one in a mono-font editor beside it.

Free, with nothing locked behind it. If it saves you time, you can [sponsor me on GitHub](https://github.com/sponsors/cjber), which takes no fees, or [buy me a coffee on Ko-fi](https://ko-fi.com/cjber). For help and each day's release notes, [join me on Discord](https://discord.gg/FpHugGxRJY).

[![Join me on Discord](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/discord-button.png)](https://discord.gg/FpHugGxRJY) [![Sponsor me on GitHub](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/github-sponsors-button.png)](https://github.com/sponsors/cjber) [![Support me on Ko-fi](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/kofi-button.png)](https://ko-fi.com/cjber)

![The macro list beside the mono editor](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/window.png)

The searchable macro list on the left, with the selected macro open in the editor on the right and the "What it does" panel below the code.

![Group member names offered in a raid assignment line](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/roster.png)

Inside a raid or party message, the completion list offers every group member's name, with their class.

![Conditions offered with live values beside a problem in the macro](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/completion.png)

Conditions are offered with their live value, and a wavy underline marks a problem on the line above.

![The Characters copy panel listing another character's macros and the differing lines](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/characters.png)

Characters copies a macro from another character, showing the lines that differ before Keep both or Replace.

![The icon picker in place of the editor, with the macro's own icons first](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/picker.png)

The icon picker: the macro's Automatic icon and what it casts, your spellbook, then every icon, with search and filters.

![The Recipes window listing class recipes beside a full macro preview](https://raw.githubusercontent.com/cjber/macro-assist-forever/main/docs/screenshots/recipes-popup.png)

Recipes lists the general and class macros with the whole macro beside the list; an unlearned spell greys its recipe and names the level the client reports.

These images are generated previews of the Macro Assist UI.

## Features

- **Every macro in one searchable list.** General and character tabs hang off the window's right edge, as in the game's spellbook, and each macro shows its icon, name and a short summary of its main action with a count of the other cases. The count sits beside the search box, which filters by name or summary as you type. Characters copies a macro from another character, with the differing lines shown before Keep both or Replace.
- **A real editor with a plain-English panel and group member names.** The macro text uses JetBrains Mono on a dark code panel, with a line-number gutter, a current-line highlight, and colour for commands, conditions, units and spells. The bottom of the panel shows one row per click and modifier branch. While grouped, the completion list offers every other member's name after `@` and `target=`, as the first argument of `/invite`, `/target`, `/tell` and the other player commands, and in any word inside a `/raid`, `/party` or other chat message.
- **Completions.** Type `/` for commands, `[` for conditions, `@` for units, or start a spell name. Tab or Down moves forward. Shift-Tab or Up moves back. Enter inserts the selection. Suggestions show live values.
- **Recipes for your class.** Recipes opens the general and class macros beside a full preview. A recipe with a spell you have not learned is greyed, with the level the client reports, and Import creates it through the same checked path as an imported macro.
- **Problems with a fix.** Place the caret on underlined text for the explanation. Press Escape to close suggestions if needed, then Tab to apply the fix. The status bar shows the first problem, what the first matching line would do with your current target, and the character count out of 255.
- **Rename, New, Save, Cancel and Delete, with an icon picker in the window.** Rename or the header icon opens it: the macro's own icons first, then your spellbook and every icon, with search and filters by class, spell school or item slot. New opens it with the name ready to type, and Delete asks for a second click.
- **History with Restore.** Every save, rename and delete keeps the previous name, icon and text, the newest 20 for each macro, listed with their time and what changed. Restore puts one back, and deleted macros stay restorable in a Deleted section.
- **Safe to open in combat.** Every write is turned off in combat, Restore included, with a line saying why. Edits are saved when the window closes out of combat.

## Known limitations

- A macro holds at most 255 characters in the game. The editor shows how many of the 255 you have used, Import refuses anything longer, and Shorten can rewrite an over-long macro when it can do so without changing what it does.
- The game does not let addons create, change or delete macros in combat, so New, Import, Rename, Save, Restore and Delete are switched off until combat ends. Edits are saved when you close the window out of combat.
- Addons cannot reach web sites such as wago.io, so Import takes pasted text only. Characters copies macros only from characters you have already logged in on with this addon.
- In some fights and instances the game hides other players' names from addons. Then the live value beside a condition such as `@mouseover` can show nothing, and a group member's name can be missing from the completion list.

## Usage

Open the macro window as you always do: `/macro`, `/m`, the game menu, or your keybind. `/macroassist` opens it too, and so does the addon compartment. Each one closes the window again when it is already open. General holds account macros and the character tab holds this character's macros.

Click a macro to edit it, or type in the search box to narrow the list. New creates a macro and opens the icon picker with its name ready to type. Rename, or a click on the header icon, opens the picker; Back to code returns to the editor. Recipes lists the general and class macros, with the whole macro beside the list; pick one and Import creates it. Characters copies a macro from another character into the open tab. While grouped, the completion list offers the other members' names inside a `/raid`, `/party` or other chat message, after `@` and `target=`, and as the first argument of `/invite`, `/target`, `/tell` and the other player commands. Cancel puts the editor back to the saved text, and Save writes it immediately. History lists the macro's earlier versions, and Restore puts one back. Closing also saves your text out of combat.

For a bug report, paste `/macroassist report`.

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

<!-- forever-credits:start -->

Thanks to Kal66, zizhengwu, Pinnnnnnnnnn and everyone who reported a bug or asked for a feature.

<!-- forever-credits:end -->

Source code and issues: [github.com/cjber/macro-assist-forever](https://github.com/cjber/macro-assist-forever). Licence: GPL-3.0-or-later.

Built with AI assistance.
