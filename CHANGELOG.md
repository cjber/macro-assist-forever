# Changelog

All notable changes to Macro Assist Forever are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## [Unreleased]

- **The macro window is split into a searchable list and a full-height editor.** Each row shows the macro icon, name
  and summary on two lines, the selected row has a soft gold fill and left bar, and the count sits beside the search
  box. A "What it does" panel at the bottom of the code surface reads each click and modifier branch from the parse.
  The editor has a line-number gutter, a status bar that turns red with the full problem message and Tab to fix, and
  completions kept inside the surface with live value tags.
- **The caret, line highlight, wavy underlines and completions follow the real text and the editor's own word wrap.**
  Clicking to the right of a line keeps the cursor on that line, and the wavy underlines no longer block clicks; put
  the cursor on one to read it and press Tab to apply its fix.
- **The editor shows a caret again.** A white caret sits at the insert position and blinks while the editor has focus, so
  you can see where typing goes.
- **Editor text is larger and its lines have room to breathe.** Macro text is now 14 units on 19-unit lines, still in
  the same window, and a 255-character macro still fits without scrolling.
- **The General and character tabs are square tabs on the window's right edge.** General shows a book and the
  character tab shows your own portrait, and the list now starts higher, in the space the old tabs floated above.

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
