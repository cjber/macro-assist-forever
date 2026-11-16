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

local members = {
	{ name = "Alphonse-Forever", className = "Mage", classFile = "MAGE" },
	{ name = "Althea-Forever", className = "Druid", classFile = "DRUID" },
	{ name = "Bertie-Forever", className = "Priest", classFile = "PRIEST" },
}

local ctx = {
	spells = {
		{ name = "Flash Heal", ranks = { 1, 3, 7 }, learned = true },
		{ name = "Mind Flay", ranks = { 1, 2 }, learned = true },
		{ name = "Shadow Word: Pain", ranks = { 1 }, learned = false },
	},
	members = members,
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

-- Plain words on a line offer checked recipes, and Tab replaces the whole line with the recipe's body. A recipe is
-- found by its intent words, its localized title and the resolved name of each spell it casts.
local recipeCtx = {
	spells = ctx.spells,
	members = members,
	evaluate = ctx.evaluate,
	recipes = {
		{
			words = { "pet", "send pet" },
			title = "Send the pet",
			spells = {},
			body = "#showtooltip\n/petattack [@mouseover,harm,nodead][]",
		},
		{
			words = { "heal", "heal mouseover" },
			title = "Heal your mouseover",
			spells = { "Flash Heal" },
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
result = ns.Complete("flash heal", 11, recipeCtx)
equal(result.items[1] and result.items[1].label, "Heal your mouseover", "a resolved spell name offers the recipe")
result = ns.Complete("heal your", 10, recipeCtx)
equal(result.items[1] and result.items[1].label, "Heal your mouseover", "the localized title offers the recipe")
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

-- Group members share the unit slots, inserted exactly as the client names them, realm included.
result = ns.Complete("/cast [@Al", 11, ctx)
equal(result.from, 9, "the member range starts after @")
local alphonse = find(result.items, "Alphonse-Forever")
yes(alphonse ~= nil, "a party member is offered after @")
equal(alphonse.kind, "member", "a member has the member kind")
equal(alphonse.detail, "Mage", "a member's detail is their class")
result = ns.Complete("/cast [target=Ber", 18, ctx)
equal(result.from, 15, "the member range starts after target=")
yes(find(result.items, "Bertie-Forever") ~= nil, "a party member is offered after target=")
local memberText = "/cast [@Alphonse-F]"
result = ns.Complete(memberText, #memberText, ctx)
equal(
	apply(memberText, "Alphonse-Forever", result.from, result.to),
	"/cast [@Alphonse-Forever]",
	"a hyphenated realm is replaced with the whole name"
)

-- The first argument of every command that takes a player name offers the group.
for _, command in ipairs({
	"/tell",
	"/whisper",
	"/w",
	"/invite",
	"/inv",
	"/target",
	"/tar",
	"/assist",
	"/focus",
	"/follow",
	"/inspect",
}) do
	local typedText = command .. " Al"
	result = ns.Complete(typedText, #typedText + 1, ctx)
	local offered = find(result.items, "Alphonse-Forever")
	yes(offered ~= nil, command .. " offers a member name")
	if offered then
		equal(
			apply(typedText, offered.insert, result.from, result.to),
			command .. " Alphonse-Forever",
			command .. " inserts the member name"
		)
	end
end

-- Any word inside a chat command's message offers the group.
local chatText = "/raid Tank 1: Alph"
result = ns.Complete(chatText, #chatText + 1, ctx)
equal(result.from, 15, "the chat word starts after the last space")
yes(find(result.items, "Alphonse-Forever") ~= nil, "a member is offered inside a raid message")
equal(
	apply(chatText, "Alphonse-Forever", result.from, result.to),
	"/raid Tank 1: Alphonse-Forever",
	"the member replaces the word being typed"
)
for _, command in ipairs({ "/rw", "/party", "/say", "/yell" }) do
	local typedText = command .. " Tank 1: Alph"
	result = ns.Complete(typedText, #typedText + 1, ctx)
	yes(find(result.items, "Alphonse-Forever") ~= nil, command .. " offers a member inside its message")
end

-- A solo player has no members to offer, and a name never becomes a condition or a spell.
local solo = { spells = ctx.spells, evaluate = ctx.evaluate, recipes = ctx.recipes, members = {} }
local soloText = "/raid Tank 1: Alph"
result = ns.Complete(soloText, #soloText + 1, solo)
equal(#result.items, 0, "a solo player has no names inside a chat message")
result = ns.Complete("/invite Al", 11, solo)
equal(#result.items, 0, "a solo player has no names for a player command")
result = ns.Complete("/cast [Al", 10, ctx)
for _, item in ipairs(result.items) do
	yes(item.kind ~= "member", "a member is not offered as a condition")
end
result = ns.Complete("/cast Alph", 11, ctx)
for _, item in ipairs(result.items) do
	yes(item.kind ~= "member", "a member is not offered as a spell")
end

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

-- A chat message offers a name only once a word is started, and only the names that word starts.
do
	local grouped =
		{ members = { { name = "Alphonse-Forever", className = "Priest" }, { name = "Cass", className = "Rogue" } } }
	local message = "/raid pull "
	local offered = ns.Complete(message, #message + 1, grouped)
	equal(#offered.items, 0, "a space in a chat message opened the name popup")
	message = "/raid pull as"
	offered = ns.Complete(message, #message + 1, grouped)
	equal(#offered.items, 0, "a chat word matched a name in its middle")
	message = "/raid Tank 1: ca"
	offered = ns.Complete(message, #message + 1, grouped)
	equal(
		offered.items[1] and offered.items[1].label,
		"Cass",
		"a started chat word does not complete the name it starts"
	)
end

print(("complete_spec: %d checks passed"):format(checks))
