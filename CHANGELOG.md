# Changelog

All notable changes to Macro Assist Forever are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## [Unreleased]

<!-- discord-image: docs/screenshots/characters.png -->

- **Copy a macro from another character.** Characters lists the other characters' General and character macros and
  shows the lines that differ from the macro already using that name in a scrolling diff. Keep both saves it under a
  free name, Replace asks for a second click, and both are off in combat.
- **Renaming a macro keeps the editor on it.** Further edits and Save continue to change the renamed macro, leaving
  neighbouring macros untouched.
- **A history restore the game refuses leaves everything as it was.** The macro, its saved history and the editor text
  stay unchanged instead of reporting a restore that did not happen.
- **Recipes shows the whole macro, not just its first line.** The preview draws every laid-out row of the selected
  recipe on its own, indents every wrapped row, and scrolls when the macro is taller than the box. (#165)
- **The Recipes status line sits beside Import.** "Learn at level 20." and the other messages no longer draw over
  the third recipe row, staying on the Import button's row at the bottom of the popup. (#167)

## [0.5.1] - 2026-11-13

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [0.5.0] - 2026-11-13

<!-- discord-image: docs/screenshots/recipes-popup.png -->

- **Recipes for your class, checked against your spellbook.** Recipes in the macro window opens a native popup with
  the general recipes and your class's, each with its whole macro beside the list. A recipe with a spell you have not
  learned is greyed, with the level the client reports, and Import creates it through the same checked path as an
  imported macro.

## [0.4.5] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [0.4.4] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [0.4.3] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [0.4.2] - 2026-11-12

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [0.4.1] - 2026-11-11

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [0.4.0] - 2026-11-11

<!-- discord-image: docs/screenshots/import.png -->

- **Each macro says where it sits on your action bars and which key presses it.** The header names every slot the
  selected macro is on, with the key bound to that slot, and a macro on no bar is marked in the list as "Not on a bar"
  so it cannot be lost.
- **Import a macro by pasting it.** Addons have no network access, so Import takes text from wago.io or another
  character and checks it with the same parser and diagnostics as the editor before it is saved. Prose, MySlot exports
  and text over 255 characters are refused with the reason, and a good macro opens the name and icon picker.
- **Shorten a macro over 255 characters.** The status line offers Shorten when a lossless rewrite exists. The preview
  shows only the changed lines, with the old line in red and the new one in green, and Apply puts the rewrite in the
  editor without saving. It trims whitespace the macro does not need, uses each command's shortest alias, collapses an
  empty trailing clause and drops the clauses the checker calls unreachable.
- **Recipes found by typing plain words.** A line such as `pet` or `heal mouseover` offers checked recipes for your
  class in the completion list, with every spell name resolved in your client's language. Tab replaces the line with
  the whole macro. Each recipe is checked when it ships for a clean parse and a body within the 255-character limit,
  and a recipe whose spell this client does not know is left out.

## [0.3.4] - 2026-11-11

- **The players who helped are on the Thanks page.** Settings, Forever addons, Thanks lists everyone whose report or idea shipped in Macro Assist Forever, ranked by how much they gave. (#98)

## [0.3.3] - 2026-11-11

<!-- forever-core-sync -->

- Ships with the same shared code as your other Forever addons, so they keep working together.

## [0.3.2] - 2026-11-11

- **Tells you which addon to update.** If another Forever addon you have installed is older than this one and stops it starting, the message now names that addon, so you know exactly what to update.
- **Deleting the last macro no longer errors.** The window keeps the deleted macro's index while the client refreshes
  the list, so the delete clears its draft and leaves the tab empty.
- **Delete's armed label fits its button.** The label reads Confirm, the tooltip says a second click deletes, and the
  fixed width keeps History in place.
- **The icon picker opens without a frame drop.** Its All icons rows and labels are cached per column count and kind
  filter, so reopening it walks only what changed.
- **The icon picker's status line stays readable.** The editor's status text and counter hide while the picker is
  open, and its left text truncates before the right hint.

## [0.3.1] - 2026-11-11

- **Works again after updating.** Updating to the last version could leave the addon switched off in the game's AddOns list with "ForeverCore: missing", because the update did not bring Forever Core with it. Forever Core now comes inside this addon's download again, from CurseForge, Wago or GitHub alike, so updating is all it takes (cjber/shortest-path-forever#731).

## [0.3.0] - 2026-11-11

- **The icon picker lives in the macro window.** Clicking the header icon, or Rename, swaps the code surface for one
  scrolling grid: the macro's Automatic icon and what it casts, your spellbook, and every client icon with a count.
  Search by icon file name or by your own spells and items, filter by class, spell school or item slot, and hover an
  icon for its name and file name. The header name is editable in place, a pick previews in the header and list row,
  and Save keeps it while Cancel restores the old one.
- **List row icons wear the same frame as the header icon**, neutral grey on a normal row and gold on the selected
  row, so the row reads like the header instead of a bare picture.

<!-- discord-image: docs/screenshots/picker.png -->

## [0.2.3] - 2026-11-11

- **Forever Core now installs alongside it.** Forever Core is on CurseForge, so the CurseForge app installs and updates it with this addon instead of the addon carrying its own copy. On Wago, install Forever Core from its own page.

## [0.2.2] - 2026-11-10

### Fixed

- **The General and character tabs hang off the window's right edge again**, as they do in the game's spellbook and
  Professions windows. The list and editor use the window's full width.

## [0.2.1] - 2026-11-10

- **Forever Core now comes in the same download.** This addon needs Forever Core, and until Forever Core has its own CurseForge page every Forever addon's download carries a copy of it, so the addon loads with nothing else to install.

## [0.2.0] - 2026-11-10

- **Needs Forever Core.** The shared tracker column, bug report and leaderboards now come from one Forever Core addon
  that installs with it, so every Forever addon's tracker scale, lock and position stay in step. Your tracker settings
  carry over.

<!-- discord-image: docs/screenshots/window.png -->

## [0.1.3] - 2026-11-10

- **The General and character tabs moved beside the list.** Both keep their book and portrait art and their checked
  ring, and they now sit on the left edge of the window next to the macros they filter.
- **List rows show the main action and a count of the other cases**, such as "Arcane Shot +2", instead of a long
  sentence that an ellipsis cut short.
- **The macro icon in the header can be dragged to an action bar**, and its tooltip says so. Rows still drag the same
  way.
- **History keeps the last 20 versions of each macro and can restore one.** Every save, rename and delete stores the
  macro's previous name, icon and text, a renamed macro keeps its history, and a deleted macro stays restorable from a
  Deleted section. Each row shows its time and what changed against the next newer version, such as "Line 3 changed",
  "2 lines changed", "+1 line" or "Renamed to X", and a deleted macro's row keeps its name and summary. Restore goes
  through the same save path and is off in combat like the other write buttons.

## [0.1.2] - 2026-11-10

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
