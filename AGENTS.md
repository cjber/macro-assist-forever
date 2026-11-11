# Macro Assist Forever

Macro Assist Forever gives WoW: Forever (`Interface 16001`) a macro window of its own: General and character tabs, a
list of every macro, and an editor with a mono font, line numbers, completions, live condition values and diagnostics
as you type. Blizzard's macro panel still opens; our window covers it at alpha 0. It never runs macros for the player.

It requires ForeverCore (`## Dependencies: ForeverCore`, and the release `tools/forever-core.txt` pins ships in the
`.pkgmeta` `externals`), the standalone addon every Forever addon needs: the report window, the error journal, the
debug log and the family page are core's alone. The one core runtime file carried here is the shared warning below.

## Commands

```sh
export FOREVER_CORE=forever-core   # or ../forever-core, the checkout of tools/forever-core.txt's ref
stylua --check .
luacheck .
for spec in tests/*_spec.lua; do luajit "$spec" || exit 1; done
python3 tools/forever_sim/sync.py check
python3 tools/forever_sim/fetch.py
luajit tools/forever_sim/run.lua
python3 -m tools.forever_tools.assets
python3 tools/screenshots.py
python3 tools/check_screenshots.py
python3 tools/visual_audit.py
python3 tools/check_client_load.py
python3 tools/check_menu_scroll.py
bash tools/typecheck.sh
python3 tools/deadcode.py --check
python3 tools/changelog.py --check
python3 tools/forever_tools/credits.py --check # Data/Credits.lua and both thanks blocks are current (WFA-31)
python3 tools/gen_icon_names.py --check
ruff check tools && ruff format --check tools
```

CI runs the same gate in the jobs `deadcode`, `check`, `python`, `typecheck`, `project-rules` (changelog), `workflows`,
`secrets` and `package`, each on every pull request. The `check`, `typecheck` and `package` jobs check out
cjber/forever-core at the ref in `tools/forever-core.txt` into `forever-core/` and set `FOREVER_CORE` to it. The
separate `core-shared` workflow runs the client load rule, the menu rule and the vendored-tooling drift check.
`tools/deadcode.py`, `tools/deadcode-allow.txt`, `tools/check_client_load.py`, `tools/check_menu_scroll.py` and
`.github/workflows/core-shared-drift.yml` are copied from forever-core: change them there, never here.
`Core/ForeverRequire.lua`, the one out-of-date warning every Forever addon carries, is copied byte for byte from
forever-core too, and is never edited here.
`tools/forever_tools/` is the suite's shared Python tooling and `tools/forever_sim/` is the vendored simulator; both
are never edited by hand. The simulator's `fetch.py` cache lives in `tools/.cache/` and is never committed.

## Workflow

- Keep Lua compatible with Lua 5.1 and the game's addon sandbox.
- Never call protected functions.
- Never touch Blizzard's Lua state. WFA-38 in `wow-forever-addon` lists what addon code may do to Blizzard's frames,
  how to restyle one by drawing on top, and when a `taint-ok` exception holds.
- Do not add an idle `OnUpdate` handler or a polling timer. Work starts from an event or a player action.
- Parser code in `Core/` is pure Lua with no client calls, so the specs can cover it without the game.
- Render every player-facing UI scene and inspect the PNG at full size. Keep the render reproducible and audit its
  layout with `tools/visual_audit.py`.
- Do not save frames, functions, userdata, or client tables.
- `Core/Require.lua` runs after `Core/ForeverRequire.lua` and stops the addon with one line in `UIErrorsFrame` when
  the loaded ForeverCore lacks the member the addon calls. Every file after it opens with `if ns.broken then return end`.
- `Core/Core.lua` registers the addon's shared services once at load (`ns.core = ForeverCore.Register(...)`) and
  attaches the saved table at login. Everything shared (report, journal, log, family page) is ForeverCore's, read
  from the `ForeverCore` global: never copy one of its runtime files here.
- The specs and the sim load ForeverCore the way the client does: `tests/forever_core.lua` finds the checkout
  (`FOREVER_CORE`, else `../forever-core`) and reads its TOC, so a spec never fakes a shared module.
- Run `stylua --check .`, `luacheck .`, every `tests/*_spec.lua` under LuaJIT, and `python3 tools/changelog.py --check`
  before proposing changes.
- Sign commits with `git commit -S`; do not add `-s` sign-off lines.

## Rules

- Blizzard's `MacroFrame` still opens and closes through every player path. Our own window, built from its frame
  templates, covers it at alpha 0, and every part inside it is ours. Touch Blizzard's frame only with `HookScript` and
  engine calls, and reach the macro store only through the global macro APIs.
- The one font exception: the macro text uses bundled JetBrains Mono (OFL-1.1; listed in `THIRD_PARTY.md`). Its fixed
  advance, measured at runtime, gives exact columns for the caret, squiggles and wrapping, which FRIZQT and ARIALN
  cannot. Every other string uses the game's font objects.
- Every player-visible phrase lives in `Locales/enUS.lua` and is read through `ns.L`, never as a bare string.
- Every saved option gets a default in an `ns.DEFAULTS` table in `Core/Core.lua`, copied into `MacroAssistForeverDB`
  on load, so an old save file and a new setting agree.
- The addon requires ForeverCore and works with nothing else installed. No core runtime file is vendored: a shared
  file that needs a change is changed in forever-core and reaches players with its release. `Core/ForeverRequire.lua`
  is the one shared file carried here, copied byte for byte.

## Standards

- `wow-forever-addon`: https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon
- `repo-standards`: the RS-* requirements every cjber repo meets (repo, Actions and security settings, rulesets, CI hardening, community files), a skill in cjber/skills whose `audit.py` checks this repo

- For window, widget and asset changes, read [wow-retail-ui-style](https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-retail-ui-style), including its asset registry and blacklist.
