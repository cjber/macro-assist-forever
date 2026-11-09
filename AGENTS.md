# Macro Assist Forever

Macro Assist Forever is an editor layer on Blizzard's macro window for WoW: Forever (`Interface 16001`): a mono font
and line numbers, completions, live condition values and diagnostics as you type. It extends the macro window; it
does not replace it or run macros for the player.

## Commands

```sh
stylua --check .
luacheck .
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
python3 -m tools.forever_tools.assets
python3 tools/check_client_load.py
python3 tools/check_menu_scroll.py
bash tools/typecheck.sh
python3 tools/deadcode.py --check
python3 tools/changelog.py --check
ruff check tools && ruff format --check tools
```

CI runs the same gate in the jobs `deadcode`, `check`, `python`, `typecheck`, `project-rules` (changelog), `workflows`,
`secrets` and `package`, each on every pull request. The separate `core-shared` workflow runs the client load rule,
the menu rule and the vendored-file drift check. `tools/deadcode.py`, `tools/deadcode-allow.txt`,
`tools/check_client_load.py`, `tools/check_menu_scroll.py` and `.github/workflows/core-shared-drift.yml` are copied
from forever-core: change them there, never here. `tools/forever_tools/` is the suite's shared Python tooling and is
never edited by hand.

## Workflow

- Keep Lua compatible with Lua 5.1 and the game's addon sandbox.
- Never call protected functions.
- Never touch Blizzard's Lua state. WFA-38 in `wow-forever-addon` lists what addon code may do to Blizzard's frames,
  how to restyle one by drawing on top, and when a `taint-ok` exception holds.
- Do not add an idle `OnUpdate` handler or a polling timer. Work starts from an event or a player action.
- Parser code in `Core/` is pure Lua with no client calls, so the specs can cover it without the game.
- Do not save frames, functions, userdata, or client tables.
- Run `stylua --check .`, `luacheck .`, every `tests/*_spec.lua` under LuaJIT, and `python3 tools/changelog.py --check`
  before proposing changes.
- Sign commits with `git commit -S`; do not add `-s` sign-off lines.

## Rules

- Extend Blizzard's macro window with its frame templates and fonts. Do not build a second macro window.
- The one font exception: the macro text uses bundled JetBrains Mono (OFL-1.1; list it in `THIRD_PARTY.md` when the font file lands). Its
  fixed 6-unit advance at size 10 gives exact columns for the caret, squiggles and wrapping, which FRIZQT and ARIALN
  cannot. Every other string uses the game's font objects.
- Every player-visible phrase lives in `Locales/enUS.lua` and is read through `ns.L`, never as a bare string.
- Every saved option gets a default in an `ns.DEFAULTS` table in `Core/Core.lua`, copied into `MacroAssistForeverDB`
  on load, so an old save file and a new setting agree.
- The addon works with nothing else installed. Shared Forever files are vendored, never required as a dependency.

## Standards

- `wow-forever-addon`: https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon

- For window, widget and asset changes, read [wow-retail-ui-style](https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-retail-ui-style), including its asset registry and blacklist.
