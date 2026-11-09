-- What would fire now, from the parse tree, and which text is safe to hand to the client's option parser.
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
load("Core/Now.lua")

local function line(text)
	return ns.Parser.Parse(text).lines[1]
end

-- Known entries, aliases, the no prefix and an explicit unit are all safe.
yes(ns.SafeToEvaluate(line("/cast [harm] Flash Heal")), "a known condition is safe")
yes(ns.SafeToEvaluate(line("/cast [nodead] Flash Heal")), "a no form of a known condition is safe")
yes(ns.SafeToEvaluate(line("/cast [nopet] Call Pet")), "nopet is safe")
yes(ns.SafeToEvaluate(line("/cast [form] Flash Heal")), "form, an alias of stance, is safe")
yes(ns.SafeToEvaluate(line("/cast [group] Flash Heal")), "group with no value is safe")
yes(ns.SafeToEvaluate(line("/cast [mod] Flash Heal")), "mod with no value is safe")
yes(ns.SafeToEvaluate(line("/cast [channeling] Flash Heal")), "channeling with no value is safe")
yes(ns.SafeToEvaluate(line("/cast [@pet,dead] Revive Pet")), "a unit and one condition are safe")

-- A half-typed or unknown word, a missing required value, an empty optional value and an open bracket are not.
yes(not ns.SafeToEvaluate(line("/cast [har] Flash Heal")), "a half-typed condition is not safe")
yes(not ns.SafeToEvaluate(line("/cast [no] Call Pet")), "a bare no prefix is not safe")
yes(not ns.SafeToEvaluate(line("/cast [pe] Call Pet")), "a half-typed pet is not safe")
yes(not ns.SafeToEvaluate(line("/cast [equipped] Flash Heal")), "a required value that is missing is not safe")
yes(not ns.SafeToEvaluate(line("/cast [mod:] Flash Heal")), "an empty optional value is not safe")
yes(not ns.SafeToEvaluate(line("/cast [harm Flash Heal")), "an unclosed group is not safe")

local calls = {}
local function evaluate(text)
	calls[#calls + 1] = text
	if text:match(" 1$") then
		return "1"
	end
	local known = {
		["[nopet] Call Pet"] = "Call Pet",
		["[@focus] Flash Heal"] = "Flash Heal",
		["[][@focus] Flash Heal"] = "Flash Heal",
		["!Auto Shot"] = "!Auto Shot",
		["Aspect of the Hawk"] = "Aspect of the Hawk",
	}
	return known[text] or text
end

-- An untargeted spell names no unit: the old default appended "on <target>" for everything.
local now, hasCommands, unit = ns.Now(ns.Parser.Parse("/cast Aspect of the Hawk"), evaluate)
equal(now, "Aspect of the Hawk", "the spell is what fires")
equal(hasCommands, true, "the macro has a command")
equal(unit, nil, "an untargeted spell has no unit")

-- An explicit @unit is returned for the caller to name.
now, hasCommands, unit = ns.Now(ns.Parser.Parse("/cast [@focus] Flash Heal"), evaluate)
equal(now, "Flash Heal", "the targeted spell is what fires")
equal(hasCommands, true, "the targeted macro has a command")
equal(unit, "focus", "the explicit unit is returned")

-- The first group that matches decides: a bare group ahead of [@focus] fires on the default target.
now, hasCommands, unit = ns.Now(ns.Parser.Parse("/cast [][@focus] Flash Heal"), evaluate)
equal(hasCommands, true, "the two-group macro has a command")
equal(now, "Flash Heal", "the spell after the bare group fires")
equal(unit, nil, "a later group's unit is not reported when an earlier group matched")

-- The toggle guard is not part of the spell name.
now = ns.Now(ns.Parser.Parse("/cast !Auto Shot"), evaluate)
equal(now, "Auto Shot", "a leading ! is stripped from the shown result")

-- A line with an unknown condition never reaches the evaluator.
calls = {}
now, hasCommands = ns.Now(ns.Parser.Parse("/cast [har] Auto Shot"), evaluate)
equal(now, nil, "an unsafe line produces no result")
equal(hasCommands, true, "the macro still has a command line")
equal(#calls, 0, "the unsafe line is never evaluated")

-- No command lines at all is a different state from commands that do not fire now.
now, hasCommands = ns.Now(ns.Parser.Parse("#showtooltip\nMend Pet"), evaluate)
equal(now, nil, "a macro without commands fires nothing")
equal(hasCommands, false, "a macro without command lines says so")

-- An unknown command is still a command line; it just cannot produce a result.
now, hasCommands = ns.Now(ns.Parser.Parse("/bogus Flash Heal"), evaluate)
equal(now, nil, "an unknown command fires nothing")
equal(hasCommands, true, "an unknown command is still a command line")

print(("now_spec: %d checks passed"):format(checks))
