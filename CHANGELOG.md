# Changelog

All notable changes to Macro Assist Forever are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses semantic versioning.

## [Unreleased]

- **The macro window now has a list and an editor of its own.** General and character tabs show every macro with its
  icon, name and a one-line summary, and the selected macro opens in a mono-font editor with line numbers, colour and a
  current-line highlight.
- **Completions, live condition values and problems appear as you type.** Commands, conditions, units and your spells
  with their ranks are offered at the caret; a wavy underline explains a problem and can fix it; and the status line
  says what would fire now with your current target and how many of the 255 characters the macro uses.
- **New, Change Name/Icon, Save, Cancel and Delete work in the window.** Edits are saved when the window closes, Delete
  asks for a second click, and every macro write is refused in combat with a line saying why.
- **`/ma`, `/macroassist` and the addon compartment now open the macro window.** Each one closes it again when it is
  already open, and they work in combat like `/macro` does.
