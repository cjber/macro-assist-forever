-- Shorten only rewrites lines whose command is secure in Data/Commands.lua. A secure command gets its shortest alias,
-- its conditions and arguments trimmed, and its unreachable clauses dropped; every other line keeps its text byte for
-- byte, so a `;` or `,` in chat, a whisper, /run or /script is never read as macro syntax.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %q, got %q"):format(label, tostring(expected), tostring(actual)))
end

local ns = {}
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("MacroAssistForever", ns)
end
load("Locales/enUS.lua")
load("Data/Commands.lua")
load("Data/Conditions.lua")
load("Core/Lexer.lua")
load("Core/Parser.lua")
load("Core/Length.lua")
load("Core/Check.lua")
load("Core/Shorten.lua")

-- A secure command keeps every rewrite: redundant whitespace goes, and the space inside a spell name and inside a
-- condition parameter stays.
local spaced = "  /spell   [harm, nodead]   Arcane Shot  "
equal(ns.Shorten(spaced).text, "/cast [harm,nodead] Arcane Shot", "a secure command is trimmed and aliased")

local named = "/cast [channeling:Mind   Flay] Mind Flay"
equal(ns.Shorten(named).text, named, "a condition parameter and a spell name keep their spaces")

-- A command is written with its shortest alias from its own data entry, and /use never becomes /cast.
equal(ns.Shorten("/spell Arcane Shot").text, "/cast Arcane Shot", "/spell uses the shortest alias of the same command")
equal(ns.Shorten("/achievement").text, "/ach", "a longer alias becomes the shortest")
equal(ns.Shorten("/use Roasted Quail").text, "/use Roasted Quail", "/use keeps its own command")
equal(ns.Shorten("/nonsense X").text, "/nonsense X", "an unknown command is left alone")

-- An empty trailing clause is collapsed, and a clause the checker calls unreachable is dropped, on a secure line only.
equal(ns.Shorten("/cast Arcane Shot;").text, "/cast Arcane Shot", "an empty trailing clause is collapsed")
equal(
	ns.Shorten("/cast Arcane Shot; Mend Pet; Revive Pet").text,
	"/cast Arcane Shot",
	"clauses after an unconditional one are dropped"
)
equal(
	ns.Shorten("/cast [harm] A; [harm] B; [nodead] C").text,
	"/cast [harm] A;[nodead] C",
	"a clause that repeats an earlier clause is dropped"
)

-- The lines that are not secure commands. Their arguments are the player's own text, so they come back byte for byte;
-- only the alias in front of them may change.
local untouched = {
	"/run local x = 1; print(x)",
	"/run print('a,   b')",
	"/w Barry   hello, there; friend",
	"/p hi;there",
	"/1 a ; b",
	"/tm [@target] 8; 1",
	"/nonsense X; Y",
	"#showtooltip [mod] A; B; C",
	"hello, world; how are you",
}
for _, line in ipairs(untouched) do
	equal(ns.Shorten(line).text, line, "a non-secure line keeps its text: " .. line)
end

-- The alias still shortens when the command is not secure, and nothing after it moves.
equal(
	ns.Shorten("/script SetCVar('x', 1); SetCVar('y', 2)").text,
	"/run SetCVar('x', 1); SetCVar('y', 2)",
	"/script becomes /run and its statements are untouched"
)
equal(
	ns.Shorten("/say hello, world; how are you").text,
	"/s hello, world; how are you",
	"/say becomes /s and its text is untouched"
)
equal(ns.Shorten("/say  spaced   out  ").text, "/s  spaced   out  ", "spaces in chat text are untouched")
equal(ns.Shorten("/emote waves, smiling").text, "/e waves, smiling", "/emote becomes /e and keeps its comma")

-- A directive keeps its word and its whole line, and an empty macro stays empty.
equal(ns.Shorten("#showtooltip   ").text, "#showtooltip   ", "a directive keeps its trailing spaces")
equal(ns.Shorten("/cast Arcane Shot").text, "/cast Arcane Shot", "a tight macro is unchanged")
equal(ns.Shorten("").text, "", "an empty macro stays empty")
equal(ns.Shorten("/cast A\n").text, "/cast A\n", "a trailing newline is kept")

-- The result says how many characters the rewrite saves, and never reports a negative saving.
local saved = ns.Shorten("/spell [harm, nodead] Arcane Shot")
equal(
	saved.saved,
	ns.Length("/spell [harm, nodead] Arcane Shot") - ns.Length(saved.text),
	"the saving is the length difference"
)
assert(saved.saved > 0, "a spaced /spell macro saves characters")
equal(ns.Shorten("/cast Arcane Shot").saved, 0, "a tight macro saves nothing")
equal(ns.Shorten("/run a; b").saved, 0, "a non-secure line with no shorter alias saves nothing")

print(("%d checks passed"):format(checks))
