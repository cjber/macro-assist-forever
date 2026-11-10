# Third party materials

## Inputs

| Input | Source and pin | Licence | Ships in zip |
|---|---|---|---|
| JetBrains Mono Regular | [JetBrains Mono v2.304](https://github.com/JetBrains/JetBrainsMono/releases/tag/v2.304), `fonts/ttf/JetBrainsMono-Regular.ttf` (sha256 `a0bf60ef0f83c5ed4d7a75d45838548b1f6873372dfac88f71804491898d138f`), with its `OFL.txt` beside it in `media/fonts/`. | SIL Open Font License 1.1 | Yes |
| Macro conditionals reference | [warcraft.wiki.gg/wiki/Macro_conditionals](https://warcraft.wiki.gg/wiki/Macro_conditionals), read for the condition names and forms in `Data/Conditions.lua`; no text is copied. | CC BY-SA 4.0 | No |
| Squiggle underline | Made for this addon by `tools/make_squiggle.py`, a 16 by 4 pixel tile tinted red or yellow for a problem. | GPL-3.0-or-later, this addon's own | Yes |
| Forever Core | `cjber/forever-core`, a required addon the stores install alongside this one (`## Dependencies: ForeverCore`). Its development tooling is copied here and pinned by `tools/check_core_shared.py` and `.github/workflows/core-shared-drift.yml`. | GPL-3.0-or-later | No, a required addon |
| forever_sim | `cjber/forever-core`, `.agents/skills/wow-forever-addon/tooling/forever_sim`, vendored as `tools/forever_sim/` and pinned by `tools/forever_sim/MANIFEST.json` at revision `d4f9420728efbe1f224134c341dd1a78d0bf3a13`. | GPL-3.0-or-later | No, test-only |
| WoW: Forever client data | Read from the installed client at runtime; nothing is copied. | Blizzard Entertainment's game data | No separate data files |
| Ko-fi's Support me on Ko-fi button | Its PNG render, `docs/kofi-button.png`, is the support button in the store description; rendered in forever-core from Ko-fi's `ko-fi.com/img/githubbutton_sm.svg`. No pin. | Ko-fi's brand asset, used as Ko-fi provides it for linking to a Ko-fi page | No |
| `docs/github-sponsors-button.png` | The GitHub Sponsors button in the store description; drawn in forever-core to match the Ko-fi button, with the heart from GitHub's [Octicons](https://github.com/primer/octicons) and the Adwaita Sans font. No pin. | Octicons: MIT; Adwaita Sans: SIL OFL 1.1 | No |
| `docs/discord-button.png` | The Discord button on the store page; drawn in forever-core with Discord's logo from [Simple Icons](https://simpleicons.org) and the Adwaita Sans font | Simple Icons: CC0; Adwaita Sans: SIL OFL 1.1; the logo is Discord's, used to link to a Discord server | No |

## Ideas and contributors

The font is JetBrains Mono, made by JetBrains and used here under the SIL Open Font License. The condition names and
forms follow warcraft.wiki.gg's macro conditional reference. The wavy underline is the addon's own art, drawn by the
script above. Everything else that ships is this addon's code, or art and data that belong to Blizzard's game.
