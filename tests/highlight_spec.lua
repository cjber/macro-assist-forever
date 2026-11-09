-- The overlay string carries the line's exact text with colour codes around parser tokens, and never a stray pipe.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %q, got %q"):format(label, tostring(expected), tostring(actual)))
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
load("Core/Lexer.lua")
load("Core/Parser.lua")
load("Core/Highlight.lua")

-- Strip the colour markup and undo the doubled literal pipe, which is what the overlay looks like to the player.
local function plain(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return (text:gsub("||", "|"))
end

local function highlighted(body)
	local parsed = ns.Parser.Parse(body)
	return ns.Highlight.Line(parsed.lines[1])
end

local body = "/cast [@mouseover,harm,nodead][] Arcane Shot"
local coloured = highlighted(body)
equal(plain(coloured), body, "colouring preserves the line")

local secondBody = "/cast [harm] Frostbolt"
local second = ns.Highlight.Line(ns.Parser.Parse("/cast Fireball\n" .. secondBody).lines[2])
equal(plain(second), secondBody, "a later line keeps its absolute offsets")
yes(second:find("|cffffd100", 1, true) ~= nil, "a condition on a later line is gold")
yes(coloured:find("|cff", 1, true) ~= nil, "the line carries colour codes")
yes(coloured:find("|cffffd100", 1, true) ~= nil, "a condition is gold")
yes(coloured:find("|cff69ccf0", 1, true) ~= nil, "a unit token is blue")

local piped = "/say a|b"
equal(plain(highlighted(piped)), piped, "a literal pipe is escaped once and restores exactly")

local directive = "#showtooltip"
equal(plain(highlighted(directive)), directive, "a directive survives colouring")
equal(ns.Highlight.Line(ns.Parser.Parse("").lines[1]), "", "an empty line has no overlay text")

print(("highlight: %d checks"):format(checks))
