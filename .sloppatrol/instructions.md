# About the code

Macro Assist Forever is a World of Warcraft: Forever addon in Lua 5.1. The files `MacroAssistForever.toc` lists are
what the game loads; `tests/*_spec.lua` load them in that order inside a stubbed client.

- Keep every saved variable name and every global the TOC exposes unchanged.
- The vendored `tools/forever_tools/` and the files copied from forever-core are never edited by hand.
- Taint: never replace a Blizzard global or hook a secure function a spec does not already hook.
- Parser code in `Core/` stays pure: no frames, no client calls, so its specs need no game.
- Never use the network, and never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's
  `wow-forever-addon/in-game.md`) tests the build linked into the game, not this checkout, so in-game checks belong to
  the agent that ships a change.

## Live roots

Nothing below is dead code, even when no file calls it by name.

- The files `MacroAssistForever.toc` lists, loaded in order: `Locales/`, `Core/`, `UI/`.
- `## SavedVariables: MacroAssistForeverDB`: anything read from it may hold data an older version wrote.
- `ns.DEFAULTS` in `Core/Core.lua`: every saved option's default, read when an old save file loads.
- `UI/Report.lua` and `UI/ForeverFamily.lua`: shared Forever files the TOC loads, called by later UI work.
- `tools/`: run by CI, `tools/typecheck.sh` and releases, not imported by the addon.
