# Third party materials

## Inputs

| Input | Source and pin | Licence | Ships in zip |
|---|---|---|---|
| JetBrains Mono Regular | [JetBrains Mono v2.304](https://github.com/JetBrains/JetBrainsMono/releases/tag/v2.304), `fonts/ttf/JetBrainsMono-Regular.ttf` (sha256 `a0bf60ef0f83c5ed4d7a75d45838548b1f6873372dfac88f71804491898d138f`), with its `OFL.txt` beside it in `media/fonts/`. | SIL Open Font License 1.1 | Yes |
| Squiggle underline | Made for this addon by `tools/make_squiggle.py`, a 16 by 4 pixel tile tinted red or yellow for a problem. | GPL-3.0-or-later, this addon's own | Yes |
| Forever Core's shared Lua files | `cjber/forever-core`, pinned by `tools/check_core_shared.py` and `.github/workflows/core-shared-drift.yml`. | GPL-3.0-or-later | Yes |
| forever_sim | `cjber/forever-core`, `.agents/skills/wow-forever-addon/tooling/forever_sim`, vendored as `tools/forever_sim/` and pinned by `tools/forever_sim/MANIFEST.json` at revision `1a78116d829064c2417dfc896d8cef61fb56fec2`. | GPL-3.0-or-later | No, test-only |
| WoW: Forever client data | Read from the installed client at runtime; nothing is copied. | Blizzard Entertainment's game data | No separate data files |

## Ideas and contributors

The font is JetBrains Mono, made by JetBrains and used here under the SIL Open Font License. The wavy underline is the
addon's own art, drawn by the script above. Everything else that ships is this addon's code, Forever Core's shared
files, or art and data that belong to Blizzard's game.
