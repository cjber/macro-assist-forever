# About the app

Macro Assist Forever is a World of Warcraft: Forever addon written in Lua 5.1. It cannot run outside the game client,
and this patrol never starts it (see the rules below). What runs here is its headless test harness: each
`tests/<name>_spec.lua` stubs the client API, loads the addon files the TOC lists, and checks one feature. Run a spec
with `luajit tests/<name>_spec.lua`; a failing spec exits non-zero and prints the failed assertion.
`luacheck <file>` lints a file.

The repository is a scaffold: the parser and the macro window UI are later work. The current spec proves that the
TOC's files load in order and that `Core/Core.lua` initialises `MacroAssistForeverDB` from `ns.DEFAULTS`.

Use the specs and `luajit -e` one-liners that load the harness to check what a change claims. Report a spec that
fails, an error that a spec prints, or a behaviour a spec shows that the change does not intend.

## Sign in

No sign-in.

## Important flows

- The TOC's load order: `Locales/`, the ForeverCore shared files, then `Core/Core.lua`.
- Saved settings: every key in `ns.DEFAULTS` is filled when the addon loads, and an existing value is kept.
- Shared Forever files: the error journal, debug log, report window and family links load without any other addon.

## Never do these things

- Never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's `wow-forever-addon/in-game.md`)
  tests the build linked into the game, not this checkout, so in-game checks belong to the agent that ships a change.
- Never edit, move or delete files.
- Never use the network.
- Never invent macro syntax, condition names or client API: the client owns them, and the parser's own tests pin them.
