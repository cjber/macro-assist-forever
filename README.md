# Macro Assist Forever

Macro Assist Forever gives WoW: Forever a macro window of its own. Blizzard's macro panel still opens with `/macro`, the game menu or its keybind; this addon covers it with a list on top and an editor below, so every macro is one click away while you write.

## What you get

- **Every macro in one list.** General and character tabs show each macro with its icon, name and a one-line summary of what it does. Select a row to edit it, or drag it onto an action bar.
- **A real editor.** The macro text uses JetBrains Mono, with line numbers down the side, a highlight on the current line, and colour for commands, conditions, units and spells.
- **Completions as you type.** Type `/` for a command, `[` for a condition, `@` for a unit or start a spell name. Up and Down move through the suggestions, Tab inserts one, and a tooltip explains the highlighted entry.
- **Live conditions and spells.** Condition values come from the game right now, and the spellbook supplies your spell names and the ranks you know.
- **Problems with a fix.** A wavy underline marks text the game cannot run. Hover it for the explanation, then press Tab or click it to apply the suggested fix.
- **A status line that says what fires now.** It shows the first problem, the action the first matching line would take with your current target, and the character count out of 255.
- **Name and icon, New, Save, Cancel and Delete.** Delete asks for a second click. Name and icon use the game's own picker, as does a new macro.
- **Safe to open in combat.** Every button that writes to your macros is turned off in combat, with a line in the status row saying why. Edits are saved when the window closes out of combat.

## Install

Put the `MacroAssistForever` folder in `World of Warcraft/_forever_/Interface/AddOns`, or install it from CurseForge. Then type `/reload`.

Nothing else is needed. The addon works with no other addon installed.

## Usage

Open the macro window as you always do: `/macro`, the game menu, or your keybind. The General tab holds account macros and the character tab holds this character's macros.

Click a macro to edit it. New creates a macro after you choose its name and icon. Change Name/Icon renames the selected macro. Cancel puts the editor back to the saved text, and Save writes it immediately. Closing the window also saves your text when you are out of combat.

## Status

The addon is in development. If something looks wrong, open an issue on GitHub with what you did and what happened.

## Credits

The shared Forever files come from [forever-core](https://github.com/cjber/forever-core). The macro window and client data belong to Blizzard's game, and JetBrains Mono is used under the SIL Open Font License. [THIRD_PARTY.md](THIRD_PARTY.md) lists every input and its licence.

## Licence

GPL-3.0-or-later. World of Warcraft is a trademark of Blizzard Entertainment, Inc. This addon is not affiliated with or endorsed by Blizzard Entertainment.
