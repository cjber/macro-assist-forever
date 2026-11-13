-- The recipe availability model: a recipe is available only when the client can name every spell it needs and
-- C_SpellBook says the player knows them. The level is the client's answer for the missing spells, and is nil when
-- the client gives none, so nothing is guessed.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

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
load("Data/Recipes.lua")

local State = ns.Recipes.State
assert(type(State) == "function", "Data/Recipes.lua has no availability model")

local names = {
	[17] = "Power Word: Shield",
	[2061] = "Flash Heal",
}

local function knownAll()
	return true
end

local function unknownAll()
	return false
end

local function noLevels()
	return nil
end

local function spellName(spellID)
	return names[spellID]
end

-- A recipe with no spells needs nothing from the spellbook.
local general = { title = "Attack your target", body = "/startattack", spells = {} }
local generalState = State(general, spellName, unknownAll, noLevels)
check(generalState.available, "a recipe with no spells needs the spellbook")
equal(generalState.body, "/startattack", "a recipe with no spells still renders")
equal(#generalState.missing, 0, "a recipe with no spells has no missing spell")
equal(generalState.level, nil, "a recipe with no spells has no learn level")

-- Every required spell is known: the body renders and Import may run.
local spellRecipe = {
	title = "Shield your mouseover",
	body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
	spells = { 17 },
}
local knownState = State(spellRecipe, spellName, knownAll, noLevels)
check(knownState.available, "a recipe whose spell is known is available")
equal(
	knownState.body,
	"#showtooltip\n/cast [@mouseover,help,nodead][] Power Word: Shield",
	"the spell name fills its placeholder"
)
equal(knownState.level, nil, "a known recipe asks for no level")

-- The client can name the spell but the player has not learned it: grey it, with the level the client reports.
local learnedAt = function()
	return 12
end
local missingState = State(spellRecipe, spellName, unknownAll, learnedAt)
check(not missingState.available, "a recipe whose spell is not known is unavailable")
equal(missingState.level, 12, "the missing spell carries the client's learn level")
equal(#missingState.missing, 1, "the missing spell is named by its ID")
equal(missingState.missing[1], 17, "the missing spell ID is the catalogue's ID")

-- With more than one missing spell the level is the highest one, because the whole macro waits for the last spell.
local twoSpells = {
	title = "Mark and send the pet",
	body = "#showtooltip\n/cast %s\n/cast %s",
	spells = { 136, 1130 },
}
names[136] = "Mend Pet"
names[1130] = "Hunter's Mark"
local levels = { [136] = 8, [1130] = 14 }
local multiState = State(twoSpells, spellName, unknownAll, function(spellID)
	return levels[spellID]
end)
equal(multiState.level, 14, "the highest missing spell's level is the recipe's level")
equal(#multiState.missing, 2, "both missing spells are recorded")

-- One missing spell with no client level means no level at all, never a guess for the other one.
local incompleteLevels = State(twoSpells, spellName, unknownAll, function(spellID)
	return spellID == 136 and 8 or nil
end)
equal(incompleteLevels.level, nil, "a missing spell with no client level removes the hint")
check(not incompleteLevels.available, "the recipe stays unavailable without every level")

-- A known spell's level never contributes: only the spells the player has to learn set the hint.
local oneKnown = State(twoSpells, spellName, function(spellID)
	return spellID == 136
end, function(spellID)
	return spellID == 1130 and 14 or 3
end)
equal(oneKnown.level, 14, "a known spell's level does not lower the hint")
equal(#oneKnown.missing, 1, "only the unlearned spell is missing")

-- The client cannot name a required spell at all: no body, so Import stays off even if the known check says yes.
local nameless = State(spellRecipe, function()
	return nil
end, knownAll, noLevels)
check(not nameless.available, "a recipe with no rendered body is unavailable")
equal(nameless.body, nil, "a nameless spell leaves no body")

-- Every phrase the popup shows has a locale entry.
for _, key in ipairs({
	"Recipes",
	"%s recipes",
	"Choose a recipe to preview its macro.",
	"Learn at level %d",
	"Learn at level %d.",
	"Not learned",
	"Not learned.",
	"No recipe selected.",
	"No recipes yet.",
	"This recipe needs a spell this client does not know.",
	"No macro slots are free.",
}) do
	check(type(ns.L[key]) == "string" and ns.L[key] ~= "", "the locale is missing " .. key)
end

print(("recipe_presets_spec: %d checks passed"):format(checks))
