-- The generated command table and the hand-written condition table describe the client accurately and consistently.
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

yes(#ns.Commands > 400, "the command table covers the client's commands")
yes(#ns.Conditions >= 25, "the condition table covers the client's conditions")

local cast = ns.CommandAliases.cast
yes(cast ~= nil, "/cast is in the table")
equal(cast.name, "cast", "the canonical cast name")
equal(cast.aliases[1], "cast", "the canonical alias comes first")
yes(cast.aliases[2] == "spell", "/spell is an alias of /cast")
equal(cast.kind, "secure", "/cast is secure")
equal(cast.category, "COMBAT", "/cast is in the combat category")
equal(cast.conditions, true, "/cast takes conditions")
yes(cast.description ~= nil and cast.description:find("spell", 1, true) ~= nil, "/cast keeps the source description")

local castsequence = ns.CommandAliases.castsequence
yes(castsequence ~= nil, "/castsequence is in the table")
equal(castsequence.list, true, "/castsequence takes a spell list")
equal(castsequence.conditions, true, "/castsequence is secure")
equal(castsequence.kind, "secure", "/castsequence is a secure command")

local castrandom = ns.CommandAliases.castrandom
yes(castrandom ~= nil, "/castrandom is in the table")
equal(castrandom.list, true, "/castrandom takes a spell list")
yes(ns.CommandAliases.userandom == castrandom, "/userandom is the same command as /castrandom")

local say = ns.CommandAliases.say
yes(say ~= nil, "/say is in the table")
equal(say.kind, "chat", "/say is a chat command")
equal(say.conditions, false, "/say ignores conditions")
equal(say.category, "CHAT", "chat commands have the CHAT category")

local kiss = ns.CommandAliases.kiss
yes(kiss ~= nil, "/kiss is in the table")
equal(kiss.kind, "emote", "/kiss is an emote")
equal(kiss.category, "EMOTE", "emotes have the EMOTE category")
yes(ns.CommandAliases.blow == kiss, "/blow is the same emote as /kiss")

equal(ns.CommandAliases.console.kind, "command", "/console is an insecure command")
equal(ns.CommandAliases.console.conditions, false, "/console ignores conditions")

-- Every command is well formed and no alias belongs to two entries.
local owner = {}
for _, command in ipairs(ns.Commands) do
	checks = checks + 1
	assert(type(command.name) == "string" and command.name ~= "", "a command has a name")
	checks = checks + 1
	assert(type(command.category) == "string" and command.category ~= "", "a command has a category")
	checks = checks + 1
	assert(type(command.conditions) == "boolean", "conditions is a boolean")
	checks = checks + 1
	assert(type(command.aliases) == "table", "aliases is a table")
	if #command.aliases > 0 then
		equal(command.aliases[1], command.name, "the canonical alias is first for " .. command.name)
	end
	if command.conditions then
		equal(command.kind, "secure", "only secure commands take conditions: " .. command.name)
	end
	if command.list then
		yes(
			command.name == "castsequence" or command.name == "castrandom",
			"only the spell lists are marked: " .. command.name
		)
	end
	for _, alias in ipairs(command.aliases) do
		checks = checks + 1
		assert(owner[alias] == nil, ("alias /%s belongs to two entries"):format(alias))
		owner[alias] = command
		equal(ns.CommandAliases[alias], command, "the alias index finds /" .. alias)
	end
end

-- Every category a command uses has a readable label, never the raw key.
for _, command in ipairs(ns.Commands) do
	local label = ns.CommandCategoryLabels[command.category]
	yes(label ~= nil, "a label exists for " .. command.category)
	if label then
		equal(label:match("^[A-Z][A-Z0-9_]*$"), nil, "the label for " .. command.category .. " is not a raw key")
	end
end
equal(ns.CommandCategoryLabels.CHAT, "Chat", "the CHAT category reads as Chat")
equal(ns.CommandCategoryLabels.TARGETING, "Targeting", "the TARGETING category reads as Targeting")

-- Every condition is well formed, unverified, and has a usable description.
for _, condition in ipairs(ns.Conditions) do
	checks = checks + 1
	assert(type(condition.name) == "string" and condition.name ~= "", "a condition has a name")
	checks = checks + 1
	assert(
		condition.param == "none" or condition.param == "optional" or condition.param == "required",
		"a valid parameter kind"
	)
	checks = checks + 1
	assert(type(condition.description) == "string" and condition.description ~= "", "a condition has a description")
	equal(condition.verified, false, "the in-game probe has not verified " .. condition.name)
	if condition.param ~= "none" then
		yes(condition.form ~= nil, condition.name .. " says how its parameter is written")
	end
	for _, alias in ipairs(condition.aliases) do
		equal(ns.ConditionAliases[alias], condition, "the condition alias " .. alias)
	end
end

equal(ns.ConditionAliases.modifier.name, "mod", "modifier is an alias of mod")
equal(ns.ConditionAliases.worn.name, "equipped", "worn is an alias of equipped")
equal(ns.ConditionAliases.form.name, "stance", "form is an alias of stance")
equal(ns.ConditionAliases.nodead, nil, "nodead is not a condition of its own; the no prefix makes it")
equal(ns.ConditionAliases.pet.param, "optional", "pet works with no name or family")
equal(ns.ConditionAliases.stance.param, "optional", "stance and form work with no value")

yes(ns.UnitSet.player, "player is a unit")
yes(ns.UnitSet.mouseover, "mouseover is a unit")
yes(ns.UnitSet.party1 and ns.UnitSet.party4, "party1-4 are units")
yes(ns.UnitSet.raid1 and ns.UnitSet.raid40, "raid1-40 are units")
yes(ns.UnitSet.raidpet1 and ns.UnitSet.raidpet40, "raid pet units are units")
yes(ns.UnitSet.targettarget, "target chains are units")
yes(ns.UnitSet.focustarget, "focus chains are units")
equal(ns.UnitSet.nonetarget, nil, "none has no target chain")

print(("commands_spec: %d checks passed"):format(checks))
