-- Every recipe ships checked: its rendered body has no diagnostics and fits the 255-character limit, its title has a
-- locale entry, and its spell placeholders line up with its spell IDs.
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
load("Data/Recipes.lua")
load("Core/Lexer.lua")
load("Core/Parser.lua")
load("Core/Length.lua")
load("Core/Check.lua")

-- The names the client supplies for the spell IDs the recipes use. A real client may lack one, and Context then skips
-- that recipe; this stub proves the shipped bodies are clean once every name is known.
local names = {
	[17] = "Power Word: Shield",
	[118] = "Polymorph",
	[136] = "Mend Pet",
	[331] = "Healing Wave",
	[635] = "Holy Light",
	[982] = "Revive Pet",
	[1130] = "Hunter's Mark",
	[1499] = "Freezing Trap",
	[2061] = "Flash Heal",
	[2094] = "Blind",
	[2139] = "Counterspell",
	[3411] = "Intervene",
	[5185] = "Healing Touch",
	[5782] = "Fear",
	[6770] = "Sap",
	[49576] = "Death Grip",
}

local spellList = {}
local ids = {}
for id in pairs(names) do
	ids[#ids + 1] = id
end
table.sort(ids)
for _, id in ipairs(ids) do
	spellList[#spellList + 1] = { name = names[id], learned = true }
end

local function spellName(id)
	return names[id]
end

local knownClasses = {
	HUNTER = true,
	PRIEST = true,
	MAGE = true,
	DRUID = true,
	SHAMAN = true,
	PALADIN = true,
	WARLOCK = true,
	ROGUE = true,
	WARRIOR = true,
	DEATHKNIGHT = true,
}

for index, recipe in ipairs(ns.Recipes.List) do
	local label = ("recipe %d (%s)"):format(index, recipe.title or "no title")
	assert(type(recipe.title) == "string" and ns.L[recipe.title], label .. " has no locale title")
	assert(type(recipe.words) == "table" and #recipe.words > 0, label .. " has no words")
	if recipe.class then
		assert(knownClasses[recipe.class], label .. " names an unknown class " .. tostring(recipe.class))
	end
	local body = ns.Recipes.Render(recipe, spellName)
	assert(type(body) == "string" and body ~= "", label .. " does not render")
	local diagnostics = ns.Check(body, { spells = spellList })
	checks = checks + 1
	assert(#diagnostics == 0, label .. " has a diagnostic: " .. (diagnostics[1] and diagnostics[1].message or ""))
	checks = checks + 1
	assert(ns.Length(body) <= ns.MacroLimit, label .. " is over the 255-character limit")
end

-- The spell IDs fill the placeholders in order, and a missing name refuses the recipe rather than leaving a gap.
local mark
for _, recipe in ipairs(ns.Recipes.List) do
	if recipe.title == "Mark and send the pet" then
		mark = recipe
	end
end
assert(mark, "the Hunter's Mark recipe is missing")
local markBody = ns.Recipes.Render(mark, spellName)
assert(markBody:find("Hunter's Mark", 1, true), "the spell name did not fill its placeholder")
equal(ns.Recipes.Render(mark, function() end), nil, "a missing spell name refuses the recipe")
equal(select(2, markBody:gsub("\n", "\n")), 2, "the recipe keeps its three lines")

print(("%d checks passed"):format(checks))
