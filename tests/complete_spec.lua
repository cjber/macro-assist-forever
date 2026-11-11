-- Completion picks the right context from the text before the caret, and returns a replacement range and sorted items.
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
load("Core/Complete.lua")

local ctx = {
	spells = {
		{ name = "Flash Heal", ranks = { 1, 3, 7 }, learned = true },
		{ name = "Mind Flay", ranks = { 1, 2 }, learned = true },
		{ name = "Shadow Word: Pain", ranks = { 1 }, learned = false },
	},
	evaluate = function(condition)
		if condition.name == "harm" then
			return false
		end
		if condition.name == "dead" then
			return true
		end
		return true
	end,
}

local function find(items, insert)
	for _, item in ipairs(items) do
		if item.insert == insert then
			return item
		end
	end
end

local function position(items, insert)
	for index, item in ipairs(items) do
		if item.insert == insert then
			return index
		end
	end
end

local function apply(text, insert, from, to)
	return text:sub(1, from - 1) .. insert .. text:sub(to + 1)
end

-- A command after /.
local result = ns.Complete("/ca", 4, ctx)
equal(result.from, 1, "the command range starts at the slash")
equal(result.to, 3, "the command range ends at the caret")
local cast = find(result.items, "/cast")
yes(cast ~= nil, "/cast is offered")
equal(cast.kind, "secure", "the item carries the command kind")
equal(cast.label, "/cast", "the label is the text as typed")

-- A command with no description shows a readable category, never the raw key from Data/Commands.lua.
local all = ns.Complete("/", 2, ctx)
for _, item in ipairs(all.items) do
	yes(item.detail ~= nil and item.detail ~= "", item.label .. " has a detail")
	equal(item.detail:match("^[A-Z][A-Z0-9_]*$"), nil, item.label .. " does not show a raw category key")
end
equal(find(all.items, "/ach").detail, "Achievement", "the achievement category reads as a word")
equal(find(all.items, "/say").detail, "Chat", "the chat category reads as a word")

-- A prefix match comes before a substring match, and the order is stable.
result = ns.Complete("/spell", 7, ctx)
equal(result.items[1].insert, "/spell", "the prefix match is first")
equal(result.items[1].kind, "secure", "/spell is the secure cast alias")
yes(find(result.items, "/pingspell") ~= nil, "a substring match is still offered")
local again = ns.Complete("/spell", 7, ctx)
for index, item in ipairs(result.items) do
	equal(again.items[index].insert, item.insert, "completion order is deterministic")
end

-- Plain words on a line offer checked recipes, and Tab replaces the whole line with the recipe's body.
local recipeCtx = {
	spells = ctx.spells,
	evaluate = ctx.evaluate,
	recipes = {
		{
			words = { "pet", "send pet" },
			title = "Send the pet",
			body = "#showtooltip\n/petattack [@mouseover,harm,nodead][]",
		},
		{
			words = { "heal", "heal mouseover" },
			title = "Heal your mouseover",
			body = "/cast [@mouseover,help,nodead][] Flash Heal",
		},
	},
}
result = ns.Complete("pet", 4, recipeCtx)
equal(result.from, 1, "a recipe replaces the whole line from its start")
equal(result.to, 3, "a recipe replaces the whole line to its end")
equal(#result.items, 1, "one recipe matches pet")
equal(result.items[1].kind, "recipe", "the recipe kind")
equal(result.items[1].label, "Send the pet", "the recipe title is the label")
equal(result.items[1].insert, "#showtooltip\n/petattack [@mouseover,harm,nodead][]", "the recipe body is the insert")
equal(result.items[1].detail, "Recipe", "the recipe reads as a recipe")
result = ns.Complete("heal mo", 8, recipeCtx)
equal(result.items[1].label, "Heal your mouseover", "a longer phrase narrows the recipe")
result = ns.Complete("pe", 3, recipeCtx)
equal(result.from, 1, "a partial word still replaces the line from its start")
equal(result.to, 2, "a partial word replaces to the line's end")
result = ns.Complete("", 1, recipeCtx)
equal(#result.items, 0, "an empty line offers no recipes")
result = ns.Complete("/cast Flash", 12, recipeCtx)
equal(result.items[1].kind, "spell", "a command line still offers spells, not recipes")

-- A directive after #.
result = ns.Complete("#sh", 4, ctx)
equal(result.from, 1, "the directive range starts at #")
equal(result.to, 3, "the directive range ends at the caret")
yes(find(result.items, "#showtooltip") ~= nil, "showtooltip is offered")
yes(find(result.items, "#show") ~= nil, "show is offered")
equal(find(result.items, "#showtooltip").kind, "directive", "the directive kind")

-- Conditions inside [.
result = ns.Complete("/cast [", 8, ctx)
equal(result.from, 8, "an empty condition is inserted at the caret")
equal(result.to, 7, "an empty condition replaces nothing")
local harm = find(result.items, "harm")
yes(harm ~= nil, "harm is offered")
equal(harm.kind, "condition", "the condition kind")
yes(harm.detail:find("false", 1, true) ~= nil, "evaluate supplies the live harm value")
local help = find(result.items, "help")
yes(help.detail:find("true", 1, true) ~= nil, "evaluate supplies the live help value")

-- The condition's `no` field says the engine reads a no prefix; it does not make the plain item the no form.
local precise = {
	evaluate = function(condition)
		return condition.no and "no" or "yes"
	end,
}
result = ns.Complete("/cast [", 8, precise)
yes(find(result.items, "harm").detail:find("yes", 1, true) ~= nil, "a plain condition is read as itself")
yes(find(result.items, "help").detail:find("yes", 1, true) ~= nil, "accepting a no prefix is not the no form")
result = ns.Complete("/cast [no", 10, precise)
yes(find(result.items, "noharm").detail:find("no", 1, true) ~= nil, "a no variant is read as the no form")

-- no variants are offered once the player types no.
result = ns.Complete("/cast [no", 10, ctx)
yes(find(result.items, "nodead") ~= nil, "nodead is offered")
yes(find(result.items, "noharm") ~= nil, "noharm is offered")
equal(find(result.items, "dead"), nil, "a plain condition is not offered after no")

-- Conditions nothing on Forever can make true are still offered, after the normal ones, and say so.
result = ns.Complete("/cast [", 8, ctx)
local vehicle = find(result.items, "vehicleui")
yes(vehicle ~= nil, "vehicleui is still offered")
equal(
	vehicle.detail,
	ns.L["The vehicle UI is shown."] .. "  " .. ns.L["Never applies on WoW: Forever."],
	"the detail says it never applies on Forever"
)
yes(
	position(result.items, "vehicleui") > position(result.items, "harm"),
	"a Forever-impossible condition comes after the normal ones"
)
local spec = find(result.items, "spec")
yes(spec ~= nil, "spec is offered")
yes(
	spec.detail:find(ns.L["Never applies on WoW: Forever."], 1, true) ~= nil,
	"a parameterised Forever-impossible condition says it never applies"
)
result = ns.Complete("/cast [no", 10, ctx)
local noVehicle = find(result.items, "novehicleui")
yes(noVehicle ~= nil, "novehicleui is still offered")
yes(noVehicle.detail:find(ns.L["Never applies on WoW: Forever."], 1, true) ~= nil, "a no form says it never applies")
yes(position(result.items, "novehicleui") > position(result.items, "noharm"), "a no form comes after the normal ones")

-- A parameter value after a condition name.
result = ns.Complete("/cast [mod:", 12, ctx)
equal(result.from, 12, "the value range starts after the colon")
yes(find(result.items, "shift") ~= nil, "shift is offered")
equal(find(result.items, "shift").kind, "value", "a parameter value has the value kind")

-- Units after @ and target=.
result = ns.Complete("/cast [@mo", 11, ctx)
equal(result.from, 9, "the unit range starts after @")
yes(find(result.items, "mouseover") ~= nil, "mouseover is offered")
yes(find(result.items, "mouseovertarget") ~= nil, "a target chain is offered")
result = ns.Complete("/cast [target=foc", 18, ctx)
equal(result.from, 15, "the unit range starts after target=")
yes(find(result.items, "focus") ~= nil, "focus is offered after target=")
yes(find(result.items, "focustarget") ~= nil, "a target= chain is offered")

-- Conditions on a directive are still conditions.
result = ns.Complete("#showtooltip [ha", 17, ctx)
yes(find(result.items, "harm") ~= nil, "a directive's condition is offered")

-- Spells and their ranks, learned or not.
result = ns.Complete("/cast Fla", 10, ctx)
equal(result.from, 7, "the spell range starts at the first letter")
equal(result.to, 9, "the spell range ends at the caret")
yes(find(result.items, "Flash Heal") ~= nil, "the spell is offered")
yes(find(result.items, "Flash Heal(Rank 3)") ~= nil, "a rank is offered")
equal(find(result.items, "Flash Heal(Rank 3)").kind, "spell", "a spell has the spell kind")
result = ns.Complete("/cast Shadow", 12, ctx)
local unlearned = find(result.items, "Shadow Word: Pain")
yes(unlearned ~= nil, "an unlearned spell is still offered")
equal(unlearned.detail, ns.L["Not learned"], "an unlearned spell says so")

-- The caret in the middle of a word replaces the rest of the spell.
local text = "/cast Flash Heal"
result = ns.Complete(text, 8, ctx)
equal(result.from, 7, "the middle-of-word range starts at the word")
equal(result.to, #text, "the middle-of-word range reaches the end of the spell")
equal(
	apply(text, "Flash Heal(Rank 3)", result.from, result.to),
	"/cast Flash Heal(Rank 3)",
	"the whole spell is replaced"
)

-- A trailing space after the command or its conditions is still the spell argument.
text = "/cast "
result = ns.Complete(text, #text + 1, ctx)
equal(result.from, #text + 1, "the spell is inserted after the space")
yes(find(result.items, "Flash Heal") ~= nil, "a spell is offered after /cast ")
text = "/cast [harm] "
result = ns.Complete(text, #text + 1, ctx)
equal(result.from, #text + 1, "the spell is inserted after the condition and space")
yes(find(result.items, "Flash Heal") ~= nil, "a spell is offered after the conditions")

-- The ! stays before the spell.
text = "/cast !Fla"
result = ns.Complete(text, 11, ctx)
equal(result.from, 8, "the replacement starts after !")
equal(apply(text, "Flash Heal", result.from, result.to), "/cast !Flash Heal", "the ! is kept")

-- A castsequence reset value.
text = "/castsequence reset="
result = ns.Complete(text, #text + 1, ctx)
equal(result.from, #text + 1, "the reset value is inserted at the caret")
yes(find(result.items, "target") ~= nil, "reset=target is offered")
yes(find(result.items, "combat") ~= nil, "reset=combat is offered")
equal(apply(text, "target", result.from, result.to), "/castsequence reset=target", "the reset value is inserted")

-- Nothing to offer is still a valid answer.
result = ns.Complete("", 1, ctx)
equal(#result.items, 0, "empty text has no completion")
equal(result.from, 1, "empty text inserts at 1")
equal(result.to, 0, "empty text replaces nothing")
result = ns.Complete("/cast Fla", 10, nil)
equal(#result.items, 0, "without spells there is nothing to offer")

print(("complete_spec: %d checks passed"):format(checks))
