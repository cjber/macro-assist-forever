-- Every diagnostic has a positive and a negative case, with offsets that point at the text the player must change.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end
local function yes(value, label)
	equal(not not value, true, label)
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

local ctx = {
	spells = {
		{ name = "Flash Heal", ranks = { 1, 3, 7 }, learned = true },
		{ name = "Mind Flay", ranks = { 1, 2 }, learned = true },
		{ name = "Shadow Word: Pain", ranks = { 1 }, learned = true },
		{ name = "Aspect of the Cheetah", ranks = { 1 }, learned = true },
		{ name = "Aspect of the Hawk", ranks = { 1 }, learned = true },
		{ name = "Aspect of the Monkey", ranks = { 1 }, learned = true },
	},
	items = { "13" },
}
local unlearned = {
	spells = {
		{ name = "Shadow Word: Pain", ranks = { 1 }, learned = false },
	},
}

local function find(diagnostics, code)
	for _, diagnostic in ipairs(diagnostics) do
		if diagnostic.code == code then
			return diagnostic
		end
	end
end

local function has(text, context, code, label)
	local diagnostic = find(ns.Check(text, context or ctx), code)
	yes(diagnostic ~= nil, label or ("%s is reported for %q"):format(code, text))
	return diagnostic
end

local function lacks(text, context, code, label)
	local diagnostic = find(ns.Check(text, context or ctx), code)
	equal(diagnostic, nil, label or ("%s is not reported for %q"):format(code, text))
end

-- Unknown command, and a fix only when exactly one alias shares the typed prefix.
local diagnostic = has("/ca", ctx, "unknown-command")
equal(diagnostic.from, 1, "the unknown command starts at the slash")
equal(diagnostic.to, 3, "the unknown command ends at the typed name")
equal(diagnostic.fix, nil, "a prefix shared by many commands gets no fix")
diagnostic = has("/cleart", ctx, "unknown-command")
equal(diagnostic.fix.insert, "/cleartarget", "the one matching alias is the fix")
equal(diagnostic.fix.from, 1, "the fix starts at the slash")
equal(diagnostic.fix.to, 7, "the fix replaces the typed name")
lacks("/cast Flash Heal", ctx, "unknown-command", "a known command is not unknown")

-- Unknown condition.
local text = "/cast [bogus] Flash Heal"
diagnostic = has(text, ctx, "unknown-condition")
equal(diagnostic.from, text:find("bogus", 1, true), "the unknown condition starts at its name")
equal(diagnostic.to, text:find("bogus", 1, true) + 4, "the unknown condition ends at its name")
lacks("/cast [harm] Flash Heal", ctx, "unknown-condition", "a known condition is not unknown")
lacks("/cast [nodead] Flash Heal", ctx, "unknown-condition", "a no prefix is understood")

-- A condition the engine parses but nothing on Forever makes true: a warning, not an unknown condition.
text = "/cast [vehicleui] Flash Heal"
diagnostic = has(text, ctx, "never-on-forever")
equal(diagnostic.severity, "warning", "a Forever-impossible condition is a warning")
equal(diagnostic.message, "[vehicleui] is never true on WoW: Forever.", "the warning names the condition")
equal(diagnostic.from, text:find("vehicleui", 1, true), "the warning starts at the condition")
equal(diagnostic.to, text:find("vehicleui", 1, true) + 8, "the warning ends at the condition")
lacks(text, ctx, "unknown-condition", "a Forever-impossible condition is not unknown")
text = "/cast [novehicleui] Flash Heal"
diagnostic = has(text, ctx, "never-on-forever")
equal(diagnostic.message, "[novehicleui] is always true on WoW: Forever.", "the no form is always true")
equal(diagnostic.from, text:find("novehicleui", 1, true), "the no form warning starts at the condition")
equal(diagnostic.to, text:find("novehicleui", 1, true) + 10, "the no form warning ends at the condition")
lacks(text, ctx, "unknown-condition", "a no form of a Forever-impossible condition is not unknown")
has("/cast [flyable] Flash Heal", ctx, "never-on-forever", "flyable is warned")
has("/cast [spec:1] Flash Heal", ctx, "never-on-forever", "a parameterised Forever-impossible condition is warned")
lacks(text, ctx, "condition-missing-parameter", "a no form needs no parameter")
lacks("/cast [harm] Flash Heal", ctx, "never-on-forever", "a normal condition gets no warning")
lacks("/cast [known:Flash Heal] Flash Heal", ctx, "never-on-forever", "known can be true on Forever")

-- A required parameter is missing; an optional one is not; an empty colon is missing either way.
text = "/cast [stance] Flash Heal"
diagnostic = has(text, ctx, "condition-missing-parameter")
equal(diagnostic.from, text:find("stance", 1, true), "the missing parameter points at the condition")
equal(diagnostic.to, text:find("stance", 1, true) + 5, "the missing parameter covers the name")
has("/cast [mod:] Flash Heal", ctx, "condition-missing-parameter", "an empty parameter is missing")
lacks("/cast [stance:1] Flash Heal", ctx, "condition-missing-parameter", "a present parameter is not missing")
lacks("/cast [mod] Flash Heal", ctx, "condition-missing-parameter", "an optional parameter may be absent")

-- A condition with no parameter rejects one.
text = "/cast [help:1] Flash Heal"
diagnostic = has(text, ctx, "condition-unexpected-parameter")
equal(diagnostic.from, text:find(":", 1, true), "the unexpected parameter starts at the colon")
equal(diagnostic.to, text:find("1", 1, true), "the unexpected parameter ends at the value")
lacks("/cast [help] Flash Heal", ctx, "condition-unexpected-parameter", "a condition without a parameter is fine")

-- An insecure command ignores conditions, but a directive does not.
text = "/say [harm] hi"
diagnostic = has(text, ctx, "conditions-ignored")
equal(diagnostic.from, text:find("[", 1, true), "the ignored conditions start at [")
equal(diagnostic.to, text:find("]", 1, true), "the ignored conditions end at ]")
lacks("/cast [harm] Flash Heal", ctx, "conditions-ignored", "a secure command reads conditions")
lacks("#showtooltip [harm] Flash Heal", ctx, "conditions-ignored", "a directive reads conditions")

-- A spell that is not in the spellbook, and an unlearned spell in the client's list.
text = "/cast Bogus"
diagnostic = has(text, ctx, "unknown-spell")
equal(diagnostic.from, text:find("Bogus", 1, true), "the unknown spell starts at its name")
equal(diagnostic.to, text:find("Bogus", 1, true) + 4, "the unknown spell ends at its name")
lacks("/cast Flash Heal", ctx, "unknown-spell", "a learned spell is not unknown")
has("/cast Shadow Word: Pain", unlearned, "unknown-spell", "an unlearned spell is reported")
lacks("/cast 13", ctx, "unknown-spell", "a numeric item slot is not a spell")

-- A rank the spell does not have; an unknown spell does not also get a rank diagnostic.
text = "/cast Flash Heal(Rank 9)"
diagnostic = has(text, ctx, "unknown-rank")
equal(diagnostic.from, text:find("9", 1, true), "the unknown rank points at the digit")
equal(diagnostic.to, diagnostic.from, "a one-digit rank range")
lacks("/cast Flash Heal(Rank 3)", ctx, "unknown-rank", "a known rank is fine")
has("/cast Bogus(Rank 3)", ctx, "unknown-spell")
equal(find(ns.Check("/cast Bogus(Rank 3)", ctx), "unknown-rank"), nil, "an unknown spell gets no rank diagnostic")

-- A clause after one that always matches, and a clause that repeats an earlier condition set.
text = "/cast [mod:shift] Flash Heal; [] Mind Flay; Flash Heal"
diagnostic = has(text, ctx, "unreachable-clause")
local firstSpell = text:find("Flash Heal", 1, true)
equal(diagnostic.from, text:find("Flash Heal", firstSpell + 1, true), "the unreachable clause is the last one")
lacks("/cast [help] Flash Heal; [harm] Mind Flay", ctx, "unreachable-clause", "different conditions are reachable")
has("/cast [help] Flash Heal; [help] Mind Flay", ctx, "unreachable-clause", "a repeated condition set is unreachable")
has(
	"/cast [help,nodead] Flash Heal; [nodead,help] Mind Flay",
	ctx,
	"unreachable-clause",
	"condition order does not matter"
)

-- The 255-character limit, counted in characters rather than UTF-8 bytes.
text = string.rep("a", 256)
diagnostic = has(text, ctx, "too-long")
equal(diagnostic.from, 256, "the first character over the limit")
equal(diagnostic.to, 256, "the last character over the limit")
lacks(string.rep("a", 255), ctx, "too-long", "255 characters fit")
lacks(string.rep("a", 253) .. "\n" .. "b", ctx, "too-long", "a newline counts as one character")
text = string.rep("é", 256)
diagnostic = has(text, ctx, "too-long")
equal(diagnostic.from, 511, "a two-byte character still counts once")
lacks(string.rep("é", 255), ctx, "too-long", "255 two-byte characters fit")

-- An empty line between commands, but not a trailing newline.
text = "/cast Flash Heal\n\n/cast Mind Flay"
diagnostic = has(text, ctx, "empty-line")
equal(diagnostic.from, 18, "the empty line points at its newline")
lacks("/cast Flash Heal\n/cast Mind Flay", ctx, "empty-line", "no empty line means no diagnostic")
lacks("/cast Flash Heal\n", ctx, "empty-line", "a trailing newline is not an empty line in the middle")

-- Parser diagnostics reach the editor too.
has("/cast [help Flash Heal", ctx, "unclosed-bracket", "an unclosed bracket is reported")

-- The issue's real macros.
lacks(
	"#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] Flash Heal(Rank 3)",
	ctx,
	"unknown-spell",
	"the mouseover macro's spell is known"
)
local diagnostics =
	ns.Check("/cast [mod:shift] Aspect of the Cheetah; [] Aspect of the Hawk; Aspect of the Monkey", ctx)
equal(#diagnostics, 1, "the aspect macro has one diagnostic")
equal(diagnostics[1].code, "unreachable-clause", "the last aspect clause is unreachable")

-- A castsequence reset is not a spell, and the spell after it is still checked.
lacks(
	"/castsequence reset=10/target/combat Shadow Word: Pain, Mind Flay",
	ctx,
	"unknown-spell",
	"reset= is not a spell"
)
text = "/castsequence reset=10/combat Bogus, Mind Flay"
diagnostic = has(text, ctx, "unknown-spell")
equal(diagnostic.from, text:find("Bogus", 1, true), "the spell after reset is checked")

-- The result is sorted by offset.
diagnostics = ns.Check("/cast [bogus] Bogus\n/cleart", ctx)
for index = 2, #diagnostics do
	checks = checks + 1
	assert(diagnostics[index - 1].from <= diagnostics[index].from, "diagnostics are sorted by offset")
end

-- A well-formed macro with a known spell has no diagnostics at all.
equal(
	#ns.Check("#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] Flash Heal(Rank 3)", ctx),
	0,
	"the mouseover macro is clean"
)
equal(#ns.Check("", ctx), 0, "an empty macro is clean")

print(("check_spec: %d checks passed"):format(checks))
