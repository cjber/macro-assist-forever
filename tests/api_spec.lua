-- Run from the repository root: luajit tests/api_spec.lua
-- MacroAssistForever.API, the contract docs/api.md documents: the TOC loads under a stubbed client with ForeverCore's
-- real APIKit (tests/forever_core.lua finds the checkout), then every member is checked for its answer, a fresh table
-- on every call and nil, "invalid" for each wrong argument, with the client gone.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

local function same(left, right, path)
	if type(left) ~= "table" or type(right) ~= "table" then
		equal(left, right, path)
		return
	end
	for key, value in pairs(left) do
		same(value, right[key], path .. "." .. tostring(key))
	end
	for key in pairs(right) do
		equal(left[key] ~= nil, true, path .. "." .. tostring(key) .. " is in both")
	end
end

-- A table answer that shares no table with an earlier one.
local function fresh(first, second, label)
	local seen = {}
	local function Collect(value)
		if type(value) == "table" and not seen[value] then
			seen[value] = true
			for _, inner in pairs(value) do
				Collect(inner)
			end
		end
	end
	Collect(first)
	local function Disjoint(value, visited)
		if type(value) ~= "table" or visited[value] then
			return
		end
		visited[value] = true
		equal(seen[value], nil, label .. ": no table is shared between calls")
		for _, inner in pairs(value) do
			Disjoint(inner, visited)
		end
	end
	Disjoint(second, {})
	same(first, second, label)
end

local function invalid(label, ...)
	local count = select("#", ...)
	local value, reason = ...
	equal(count, 2, label .. " answers two values")
	equal(value, nil, label .. " answers nil")
	equal(reason, "invalid", label .. " answers invalid")
end

-- ForeverCore's own APIKit, as the client loads it.
local coreDirectory = dofile("tests/forever_core.lua").directory()
local coreNs = {}
assert(loadfile(coreDirectory .. "/Core/APIKit.lua"))("ForeverCore", coreNs)
local APIKit = coreNs.APIKit

local client = {
	CreateFrame = function()
		return { RegisterEvent = function() end, SetScript = function() end }
	end,
	hooksecurefunc = function() end,
	ShowMacroFrame = function() end,
	GetNumMacros = function()
		return 0, 0
	end,
	C_AddOns = {
		GetAddOnMetadata = function()
			return nil
		end,
	},
}
for name, value in pairs(client) do
	_G[name] = value
end
_G.SlashCmdList = {}
_G.ForeverCore = {
	API = 1,
	Register = function()
		return { Report = {}, Attach = function() end }
	end,
	APIKit = APIKit,
}

local ns = {}
local toc = assert(io.open("MacroAssistForever.toc", "r"))
for line in toc:lines() do
	local entry = line:match("^%s*([^#%s].*)$")
	if entry then
		entry = entry:gsub("\\", "/"):gsub("%s+$", "")
		if entry:match("%.lua$") then
			assert(loadfile(entry))("MacroAssistForever", ns)
		end
	end
end
toc:close()

-- Pure: nothing below reaches the client.
for name in pairs(client) do
	_G[name] = nil
end

local api = MacroAssistForever.API
equal(api.version, 1, "version")
equal(api.minor, 0, "minor")

local listed
for _, entry in ipairs(APIKit.Addons()) do
	if entry.name == "MacroAssistForever" then
		listed = entry
	end
end
assert(listed, "APIKit.Addons lists the published API")
equal(listed.api, api, "Addons hands back the addon's own table")
equal(listed.version, 1, "Addons reads its version")
equal(listed.minor, 0, "Addons reads its minor")

local MACRO = "#showtooltip\n/cast [@mouseover,help] Flash Heal; Smite"

-- Parse
local parsed = api.Parse(MACRO)
equal(parsed.text, MACRO, "Parse keeps the body")
equal(#parsed.lines, 2, "Parse answers one entry per line")
equal(parsed.lines[1].kind, "directive", "the first line is a directive")
equal(parsed.lines[2].kind, "command", "the second is a command")
equal(parsed.lines[2].command.nameLower, "cast", "its command")
equal(#parsed.lines[2].clauses, 2, "split into its clauses")
equal(parsed.lines[2].clauses[1].groups[1].unit.token, "mouseover", "the first group's unit")
equal(parsed.lines[2].clauses[2].args.items[1].name, "Smite", "the second clause's argument")
same(parsed, ns.Parser.Parse(MACRO), "Parse")
fresh(parsed, api.Parse(MACRO), "Parse")
equal(#api.Parse("").lines, 1, "an empty body is one empty line")
equal(api.Parse("/cast [help").diagnostics[1].code, "unclosed-bracket", "Parse reports syntax")
invalid("Parse(nil)", api.Parse(nil))
invalid("Parse(5)", api.Parse(5))

-- Check
local spells = { { name = "Flash Heal", ranks = { 1, 2 } }, "Smite" }
same(api.Check(MACRO, { spells = spells }), {}, "a clean macro has no diagnostics")
local diagnostics = api.Check("/csat Smite\n/cast Shadow Bolt", { spells = spells })
equal(#diagnostics, 2, "Check finds both problems")
equal(diagnostics[1].code, "unknown-command", "sorted by offset: the command first")
equal(diagnostics[1].severity, "error", "an unknown command is an error")
same(diagnostics[1].fix, nil, "no single alias starts with csat")
equal(diagnostics[2].code, "unknown-spell", "a spell the player lacks")
equal(diagnostics[2].from, 19, "the spell's range")
equal(api.Check("/stopcas")[1].fix.insert, "/stopcasting", "a unique alias is the fix")
same(api.Check("/cast Shadow Bolt"), {}, "without spells no spell is judged")
same(api.Check(MACRO, { spells = spells, unknown = 5 }), {}, "an undocumented field is ignored")
same(api.Check("/cast Hearthstone", { spells = spells, items = { "Hearthstone" } }), {}, "an item is not a spell")
fresh(diagnostics, api.Check("/csat Smite\n/cast Shadow Bolt", { spells = spells }), "Check")
invalid("Check(nil)", api.Check(nil))
invalid("Check with a string context", api.Check(MACRO, "spells"))
invalid("Check with string spells", api.Check(MACRO, { spells = "Smite" }))
invalid("Check with numeric items", api.Check(MACRO, { items = 5 }))

-- Explain
equal(type(api.Explain(MACRO)), "string", "Explain answers a string")
equal(api.Explain(MACRO), ns.Explain(MACRO), "Explain is the list's summary")
equal(api.Explain(""), "", "an empty body explains to nothing")
invalid("Explain(nil)", api.Explain(nil))

-- Length and MacroLimit
equal(api.Length("abc"), 3, "Length counts characters")
equal(api.Length("a\nb"), 3, "a newline counts one")
equal(api.Length("é"), 1, "a UTF-8 character counts one")
equal(api.Length(""), 0, "an empty body is zero")
invalid("Length(nil)", api.Length(nil))
equal(api.MacroLimit(), 255, "MacroLimit")
local full = ("a"):rep(api.MacroLimit())
same(api.Check(full), {}, "a body at the limit fits")
equal(api.Check(full .. "a")[1].code, "too-long", "one past it is too long")

-- Complete
local completion = api.Complete("/ca")
equal(completion.from, 1, "the range starts at the command")
equal(completion.to, 3, "and ends at the caret")
local cast
for _, item in ipairs(completion.items) do
	if item.insert == "/cast" then
		cast = item
	end
end
assert(cast, "/cast is offered")
equal(cast.kind, "secure", "with its kind")
same(api.Complete("/ca", 4), completion, "the default cursor is the end")
fresh(completion, api.Complete("/ca"), "Complete")
equal(api.Complete("/ca", 3).to, 3, "the range covers the whole word under the caret")

local seenCondition
local live = api.Complete("/cast [dea", nil, {
	evaluate = function(condition)
		seenCondition = condition
		return condition.name == "dead" and not condition.no
	end,
})
local dead
for _, item in ipairs(live.items) do
	if item.insert == "dead" then
		dead = item
	end
end
assert(dead, "the dead condition is offered")
equal(dead.live, "true", "with its live value as a string")
equal(type(seenCondition.name), "string", "evaluate sees the condition's name")
equal(type(seenCondition.no), "boolean", "and its no form")
equal(seenCondition.condition, nil, "and nothing of the addon's own data")

local member = api.Complete("/invite Gr", nil, { members = { { name = "Grimm", className = "Priest" } } })
equal(member.items[1].insert, "Grimm", "a group member is offered")
equal(member.items[1].detail, "Priest", "with the class as detail")
local recipe = api.Complete("heal mouse", nil, {
	recipes = { { title = "Mouseover heal", body = "/cast [@mouseover] Flash Heal", words = { "heal mouseover" } } },
})
equal(recipe.items[1].insert, "/cast [@mouseover] Flash Heal", "a recipe is offered for plain words")
local spell = api.Complete("/cast Fla", nil, { spells = spells })
equal(spell.items[1].insert, "Flash Heal", "a spell is offered as an argument")

invalid("Complete(nil)", api.Complete(nil))
invalid("Complete with cursor 0", api.Complete("/ca", 0))
invalid("Complete past the end", api.Complete("/ca", 5))
invalid("Complete with a fractional cursor", api.Complete("/ca", 1.5))
invalid("Complete with a string cursor", api.Complete("/ca", "4"))
invalid("Complete with a string context", api.Complete("/ca", nil, "x"))
invalid("Complete with numeric members", api.Complete("/ca", nil, { members = 1 }))
invalid("Complete with a non-function evaluate", api.Complete("/ca", nil, { evaluate = true }))

for _, context in ipairs({
	{ spells = { false } },
	{ spells = { { name = "Heal", ranks = { {} } } } },
	{ spells = { { name = "Heal", ranks = "one" } } },
	{ spells = { { name = 1 } } },
	{ spells = { { name = "Heal", learned = "yes" } } },
	{ spells = { { name = "Heal", rank = 0 / 0 } } },
}) do
	invalid("Check rejects malformed spell data", api.Check("/cast Heal", context))
	invalid("Complete rejects malformed spell data", api.Complete("/cast He", nil, context))
end
for _, context in ipairs({
	{ recipes = { false } },
	{ recipes = { { title = 7, body = "/cast Heal" } } },
	{ recipes = { { title = "Heal", body = "/cast Heal", words = false } } },
	{ recipes = { { title = "Heal", body = "/cast Heal", spells = { {} } } } },
	{ members = { { name = "Tank", className = 1 } } },
	{ members = { false } },
}) do
	invalid("Complete rejects malformed rows", api.Complete("heal", nil, context))
end
invalid("Check rejects malformed item rows", api.Check("/cast Heal", { items = { {} } }))
equal(#api.Check("/cast Heal", { spells = {}, items = { Heal = true } }), 0, "item name maps accept true values")

print(("api_spec: %d checks pass"):format(checks))
