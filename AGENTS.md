# AGENTS.md

Macro Assist Forever gives WoW: Forever (`Interface 16001`) a macro window of its own: General and character tabs, a
list of every macro, and an editor with a locale-aware font, line numbers, completions, live condition values and
diagnostics as you type. Blizzard's macro panel still opens; our window covers it at alpha 0. It never runs macros for
the player.

It declares ForeverCore in `## OptionalDeps` so it can load and explain a missing core (the release pinned in
`tools/forever-core.txt` ships in `.pkgmeta` `externals`). No core runtime file is vendored: a shared file that needs
a change is changed in forever-core. `Core/ForeverRequire.lua` is the one shared file carried here, copied byte for
byte: never edit it, nor `tools/deadcode.py`, `tools/check_client_load.py`, `tools/check_menu_scroll.py` or
`core-shared-drift.yml`, which are copied from forever-core too.

## Commands

```sh
python3 tools/gate.py               # the fast local gate: format, lint, typecheck, specs, generated data, changelog
python3 tools/gate.py --changed     # only the steps the diff against origin/main reaches
python3 tools/screenshots.py && python3 tools/visual_audit.py   # render every UI scene, then audit its layout
```

`gate.py` loads ForeverCore from `$FOREVER_CORE`, else `../forever-core`: set it in a worktree. CI adds the simulator,
the package build, actionlint, zizmor and gitleaks. A change's player-facing notes go in `changes/<issue>.md`; only
the release commit edits `CHANGELOG.md` (`python3 tools/changelog.py release X.Y.Z`). Release:
`.agents/skills/release/SKILL.md`, after checking the `headless-smoke` commit status on that exact commit.

## Rules

- Lua 5.1 in the game's sandbox. Never call protected functions. Never touch Blizzard's Lua state (WFA-38).
- Blizzard's `MacroFrame` still opens and closes through every player path. Our window, built from its frame
  templates, covers it at alpha 0 and every part inside is ours. Touch Blizzard's frame only with `HookScript` and
  engine calls, never open or hide it from addon code (`ShowMacroFrame` and `ShowUIPanel` run Blizzard's panel
  manager under our taint), and reach the macro store only through the global macro APIs.
- No idle `OnUpdate` handler or polling timer: work starts from an event or a player action. Do not save frames,
  functions, userdata or client tables.
- Parser code in `Core/` is pure Lua with no client calls, so specs cover it without the game.
- `Core/Require.lua` runs after `Core/ForeverRequire.lua` and stops the addon with one `UIErrorsFrame` line when the
  loaded ForeverCore lacks a member it calls; every file after it opens with `if ns.broken then return end`.
  `Core/Core.lua` registers the shared services once (`ns.core = ForeverCore.Register(...)`).
- Specs and the simulator load ForeverCore the way the client does (`tests/forever_core.lua` reads its TOC), so a spec
  never fakes a shared module.
- Macro text uses bundled JetBrains Mono (OFL-1.1, in `THIRD_PARTY.md`); on zhCN, zhTW and koKR it uses the file
  `ChatFontNormal:GetFont()` returns, for glyph coverage. Hidden FontStrings measure text, so layout supports
  proportional fonts. Every other string uses the game's font objects.
- Every player-visible phrase lives in `Locales/enUS.lua` and is read through `ns.L`.
- `Core/API.lua` publishes `MacroAssistForever.API` under forever-core's `docs/api-conventions.md`: members stay pure,
  return fresh tables and answer a wrong argument with `APIKit.Invalid()`. A member change updates `docs/api.md`,
  `types/API.lua` and `tests/api_spec.lua`; an addition raises `minor`.
- Every saved option gets a default in `ns.DEFAULTS` (`Core/Core.lua`), copied into `MacroAssistForeverDB` on load.
- Render every player-facing UI scene and inspect the PNG at full size; keep the render reproducible.
- Before cleanup, dead-code or refactoring work, read the live roots and settled shapes in `.sloppatrol/instructions.md`.

## Standards

- `wow-forever-addon`: https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-forever-addon (the WFA-*
  requirements every WoW: Forever addon meets: UI look, assets, README and store page, CI and releases)
- `wow-retail-ui-style`: https://github.com/cjber/forever-core/tree/main/.agents/skills/wow-retail-ui-style (read it,
  with its asset registry and blacklist, for window, widget and asset changes)
- `repo-standards`: the RS-* requirements every cjber and agent-labs-dev repo meets; its `audit.py` checks this repo.
