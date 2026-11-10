# Changelog

All notable changes to Macro Assist Forever are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## [Unreleased]

## [0.1.1] - 2026-11-10

- **Spells behind a spellbook flyout now count as yours.** Call Pet, Aspect and the other spells inside a flyout
  button appear in completion and are no longer flagged as "Spell not in your spellbook".
- **Typing a condition no longer writes "Unknown macro option" to chat.** A half-typed or unknown condition stays in
  the checker until it is complete, and the live value and "Now" line only ask the client about conditions it knows.
- **`[pet]` and `[nopet]` work with no name**, as do the bare stance, form, group, modifier and channeling forms. Only
  conditions that really need a value are flagged.
- **Hovering a wavy underline shows its message again**, and moving the caret into a problem shows it too.
- **The status row is accurate.** It says "Nothing fires now" when a macro has commands but none matches, names a unit
  only when the macro targets one explicitly, and drops the `!` toggle guard from the shown spell.
- **Command completions show a readable category instead of a raw key** such as `CHAT_COMMAND`, in both the detail
  column and the tooltip.

## [0.1.0] - 2026-11-09

<!-- discord-image: docs/screenshots/window.png -->

- **The macro window now has a list and an editor of its own.** General and character tabs show every macro with its
  icon, name and a one-line summary, and the selected macro opens in a mono-font editor with line numbers, colour and a
  current-line highlight.
- **Completions, live condition values and problems appear as you type.** Commands, conditions, units and your spells
  with their ranks are offered at the caret; a wavy underline explains a problem and can fix it; and the status line
  says what would fire now with your current target and how many of the 255 characters the macro uses.
- **New, Change Name/Icon, Save, Cancel and Delete work in the window.** Edits are saved when the window closes, Delete
  asks for a second click, and every macro write is refused in combat with a line saying why.
- **Every way in toggles the macro window.** `/macro`, `/m`, the game menu's Macros button, `/macroassist` and the
  addon compartment each open the window when it is closed and close it when it is open. `/macroassist` and the
  compartment also work in combat, like `/macro` does.
