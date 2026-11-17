# Addon API

Other addons use Macro Assist Forever's macro engine through `MacroAssistForever.API` (`version = 1`): the same
parser, checks, plain-language summary, counter and completions the editor runs on. A WeakAura's custom code, an
action bar or another macro addon can read a macro body the way the editor does. On ForeverCore with
`ForeverCore.APIKit.Addons()`, the list includes this API too.

```lua
local api = MacroAssistForever and MacroAssistForever.API
if api and api.version == 1 and type(api.Check) == "function" then
	local diagnostics = api.Check("/cast [@mouseover,help] Flash Heal")
end
```

Every member is pure. It reads only its arguments and the addon's bundled command and condition data, never the
client, so it gives the same answer at load, in combat and on any character. Nothing the API answers changes over
time, so it has no `Subscribe` and no change keys. A member that returns a table builds a fresh one on every call, so
a caller may keep it or change it: it is never the addon's own table.

`version` changes only when a published member breaks: its arguments, the shape of its result or its meaning. An
addition keeps `version` at 1 and raises `minor`, so check that a function exists before calling it. The current
`minor` is 0; the history:

| minor | added |
|---|---|
| 0 | `Parse`, `Check`, `Explain`, `Length`, `MacroLimit` and `Complete`, the first published API |

## Wrong arguments

No member waits for data, so none answers `"loading"`, `"disabled"` or `"none"`. A wrong argument answers
`nil, "invalid"`: asking again with the same argument cannot help. An argument is wrong when:

- `body` is not a string.
- `context` is neither nil nor a table, or one of its documented fields has the wrong type. A field the member does not
  document is ignored.
- `cursor` is not a whole number from 1 to `#body + 1`.

Lists are dense sequences starting at 1. A spell rank is a positive whole number; `learned` is a boolean, and
member names, class names, recipe titles, macro bodies and intent words are strings. An item-name map may use
boolean values, for example `{ ["Healing Potion"] = true }`.

Offsets throughout are byte positions in `body`, the convention of `string.sub`: a range `from`, `to` covers
`body:sub(from, to)`, and an empty range has `to = from - 1`.

## Members

### `Parse(body)`

The parse tree of `body`: `{ text, lines, diagnostics }`. `lines` has one entry per line, in order, even an empty
one. `diagnostics` holds the syntax problems only (`unclosed-bracket`, `unexpected-token`); `Check` adds the rest.
Each line is:

| field | |
|---|---|
| `text`, `from`, `to` | the line and its range, without the newline |
| `kind` | `"empty"`, `"directive"` (`#showtooltip`), `"command"` (`/cast`) or `"text"` |
| `command` | for a command line: `name` as typed, `nameLower`, and the ranges `from`, `to`, `nameFrom`, `nameTo` |
| `bang`, `bangFrom`, `bangTo` | a directive's or command's `!` |
| `directive`, `directiveFrom`, `directiveTo` | a directive's name |
| `clauses` | the `;`-separated clauses |
| `tokens` | the line's lexer tokens |
| `diagnostics` | this line's syntax problems |

A clause has its range `from`, `to`, the `semicolon` that ends it, `groups` (each `[...]` with its `from`, `to`,
`closed`, `conditions` and `unit`), every condition of every group flattened into `conditions`, the clause's `unit`,
its arguments `args` (`text`, range and `items`), `unconditional` (true when it has no condition) and `key`, the same
string for clauses whose conditions read the same.

A condition has `text`, `rawName` as typed, `name` (lower case, without a `no` prefix), `no`, `param` with its
`/`-separated `alternatives`, and ranges for each part. A unit is `{ kind = "at" | "target", token }` with its ranges.
An argument item has `text`, `name` without `!`, `reset=` and `(Rank N)`, and `bang`, `rank` and `reset` with
`resetValues`, each with its range.

### `Check(body, context?)`

Every diagnostic the editor underlines, sorted by `from`, then `to`, then `code`. An empty list means the macro is
clean. Each diagnostic is:

| field | |
|---|---|
| `from`, `to` | the text the player must change |
| `severity` | `"error"` or `"warning"` |
| `code` | a stable name, listed below |
| `message` | the editor's message, in the player's language |
| `fix` | when there is exactly one fix: `{ from, to, insert }`; replacing `from`..`to` with `insert` applies it |

The codes are `unknown-command`, `unknown-condition`, `never-on-forever`, `condition-missing-parameter`,
`condition-unexpected-parameter`, `conditions-ignored`, `unknown-spell`, `unknown-rank`, `unreachable-clause`,
`empty-line`, `too-long`, `unclosed-bracket` and `unexpected-token`.

`context` says what the player knows, so the check can judge spell names:

| field | |
|---|---|
| `spells` | a list of spell names, or of `{ name, ranks?, rank?, learned? }`; `learned` is true when absent |
| `items` | item names, as a list, a map keyed by name, or `{ name }` entries; a `/cast` of one is not an unknown spell |

Without `spells`, no spell or item is judged, so `unknown-spell` and `unknown-rank` never appear.

### `Explain(body)`

The macro in plain words, the line the macro list shows: `"Flash Heal on a friend"` for
`/cast [@mouseover,help] Flash Heal`. The text is in the player's language and is cut to the list's length. An empty
or wordless body answers `""`.

### `Length(body)`

The count the macro window's counter shows: characters rather than bytes, so a UTF-8 character counts one and every
newline counts one. Compare it with `MacroLimit()`.

### `MacroLimit()`

The most characters a macro may hold, 255. `Check` reports `too-long` past it.

### `Complete(body, cursor?, context?)`

The completions for a caret at byte `cursor`, which defaults to the end of `body` (`#body + 1`). Items match the
text before the caret, and the range covers the whole word under it. The answer is `{ from, to, items }`: replacing `body`'s bytes `from`..`to` with an item's
`insert` makes the edit. Items come prefix matches first, then substring matches, each group by label. Each item is:

| field | |
|---|---|
| `label` | what to show |
| `insert` | the text that replaces `from`..`to` |
| `kind` | `"secure"`, `"command"`, `"chat"`, `"emote"`, `"condition"`, `"unit"`, `"member"`, `"spell"`, `"directive"`, `"recipe"` or `"value"` |
| `detail` | a short description, in the player's language |
| `live` | a condition's live value, when `context.evaluate` gave one |

`context` adds what only the caller knows:

| field | |
|---|---|
| `spells` | the same shape as `Check`'s, offered as `/cast` arguments with their ranks |
| `members` | `{ name, className? }` group members, offered as names |
| `recipes` | `{ title, body, words?, spells? }` whole macros, offered for plain words on a line |
| `evaluate` | `function(condition)` returning a condition's live value, shown with `tostring`. `condition` is a fresh `{ name, no }`. An error or nil shows nothing |
