local _, ns = ...

if ns.broken then
	return
end

-- Recipes the completion list offers when the player types plain words on a line, such as "pet" or "heal mouseover".
-- A typed word matches a recipe's localized title and the resolved, localized name of every spell the recipe casts, so
-- the data never repeats a spell name. `words` holds only the intent words that are not spell names, such as "pet",
-- "kick" or "sheep". Every recipe is checked by tests/recipes_spec.lua before it ships: its rendered body has no
-- diagnostics and fits the 255-character limit. A body writes a spell name as `%s`, with the spell IDs in `spells` in
-- the same order, so the client's language decides the name. `title` is a key in Locales/enUS.lua, and `class` is the
-- UnitClass token the recipe belongs to; a recipe with no class is offered to every player.

---@class MacroAssistRecipe
---@field words string[] intent words that are not spell names
---@field title string the Locales key for the row's label
---@field class string? UnitClass token, or nil for every class
---@field body string the macro text, with `%s` for each spell in `spells`
---@field spells integer[] spell IDs, in `%s` order

---@type MacroAssistRecipe[]
local recipes = {
	{
		words = { "stop", "stop attack", "stop casting", "cancel" },
		title = "Stop the attack and the cast",
		body = "#showtooltip\n/stopattack\n/stopcasting",
		spells = {},
	},
	{
		words = { "attack", "auto attack", "start attack" },
		title = "Attack your target",
		body = "#showtooltip\n/targetenemy [dead][noharm]\n/startattack",
		spells = {},
	},
	{
		words = { "follow", "follow target" },
		title = "Follow your target",
		body = "#showtooltip\n/follow",
		spells = {},
	},
	{
		words = { "pet", "send pet", "pet attack" },
		title = "Send the pet",
		class = "HUNTER",
		body = "#showtooltip\n/petattack [@mouseover,harm,nodead][]",
		spells = {},
	},
	{
		words = { "pet", "heal pet", "pet heal" },
		title = "Heal the pet",
		class = "HUNTER",
		body = "#showtooltip\n/cast [@pet,nodead] %s",
		spells = { 136 },
	},
	{
		words = { "pet", "pet revive" },
		title = "Revive the pet",
		class = "HUNTER",
		body = "#showtooltip\n/cast [@pet,dead] %s",
		spells = { 982 },
	},
	{
		words = { "mark", "mark pet", "pet mark" },
		title = "Mark and send the pet",
		class = "HUNTER",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s\n/petattack [@mouseover,harm,nodead][]",
		spells = { 1130 },
	},
	{
		words = { "trap", "trap mouseover" },
		title = "Trap your mouseover",
		class = "HUNTER",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 1499 },
	},
	{
		words = { "heal", "heal mouseover" },
		title = "Heal your mouseover",
		class = "PRIEST",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 2061 },
	},
	{
		words = { "shield", "shield mouseover" },
		title = "Shield your mouseover",
		class = "PRIEST",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 17 },
	},
	{
		words = { "sheep", "polymorph mouseover" },
		title = "Polymorph your mouseover",
		class = "MAGE",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 118 },
	},
	{
		words = { "interrupt", "kick" },
		title = "Interrupt your mouseover",
		class = "MAGE",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 2139 },
	},
	{
		words = { "heal", "heal mouseover" },
		title = "Heal your mouseover",
		class = "DRUID",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 5185 },
	},
	{
		words = { "heal", "heal mouseover" },
		title = "Heal your mouseover",
		class = "SHAMAN",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 331 },
	},
	{
		words = { "heal", "heal mouseover" },
		title = "Heal your mouseover",
		class = "PALADIN",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 635 },
	},
	{
		words = { "fear mouseover" },
		title = "Fear your mouseover",
		class = "WARLOCK",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 5782 },
	},
	{
		words = { "sap mouseover" },
		title = "Sap your mouseover",
		class = "ROGUE",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 6770 },
	},
	{
		words = { "blind mouseover" },
		title = "Blind your mouseover",
		class = "ROGUE",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 2094 },
	},
}

-- Fill every `%s` in the body with the name the caller supplies for the next spell ID. Nil means the client does not
-- know that spell, so the recipe cannot be offered: a body with a missing name would be an incomplete macro.
---@param recipe MacroAssistRecipe
---@param spellName fun(spellID: integer): string?
---@return string?
local function Render(recipe, spellName)
	local names = {}
	for index, spellID in ipairs(recipe.spells or {}) do
		local name = spellName(spellID)
		if type(name) ~= "string" or name == "" then
			return nil
		end
		names[index] = name
	end
	local index = 0
	local body = recipe.body:gsub("%%s", function()
		index = index + 1
		return names[index] or ""
	end)
	if index ~= #names then
		return nil
	end
	return body
end

-- The selected recipe's state for this character: its rendered macro, whether every spell it needs is known, and the
-- level the client says the missing spells are learned at. The level is nil when the client does not state one for
-- every missing spell, so nothing guesses a Classic level or infers one from the character's level. A recipe with no
-- spells needs nothing from the spellbook and is always available.
---@class MacroAssistRecipeState
---@field recipe MacroAssistRecipe
---@field body string? the rendered macro, or nil when the client cannot name a required spell
---@field available boolean every required spell is known and the body rendered
---@field missing integer[] the spell IDs this character has not learned
---@field level integer? the highest level the client gives for the missing spells, or nil

-- `isKnown` answers from C_SpellBook.IsSpellKnown and `levelLearned` from C_Spell.GetSpellLevelLearned, or from nil
-- when the client does not have that call. Keeping both out of this file lets the specs cover the rule without a
-- client, and keeps the recipe data free of a second catalogue of spell levels.
---@param recipe MacroAssistRecipe
---@param spellName MacroAssistSpellName
---@param isKnown MacroAssistSpellKnown
---@param levelLearned MacroAssistSpellLevel
---@return MacroAssistRecipeState
local function State(recipe, spellName, isKnown, levelLearned)
	local missing = {}
	local level
	local everyLevelKnown = true
	for _, spellID in ipairs(recipe.spells or {}) do
		if isKnown(spellID) ~= true then
			missing[#missing + 1] = spellID
			local learnedAt = levelLearned(spellID)
			if type(learnedAt) == "number" and learnedAt > 0 then
				if not level or learnedAt > level then
					level = learnedAt
				end
			else
				everyLevelKnown = false
			end
		end
	end
	if not everyLevelKnown then
		level = nil
	end
	local body = Render(recipe, spellName)
	return {
		recipe = recipe,
		body = body,
		available = body ~= nil and #missing == 0,
		missing = missing,
		level = level,
	}
end

---@alias MacroAssistSpellName fun(spellID: integer): string?
---@alias MacroAssistSpellKnown fun(spellID: integer): boolean?
---@alias MacroAssistSpellLevel fun(spellID: integer): integer?

---@class MacroAssistRecipes
---@field List MacroAssistRecipe[]
---@field Render fun(recipe: MacroAssistRecipe, spellName: MacroAssistSpellName): string?

ns.Recipes = {
	List = recipes,
	Render = Render,
	State = State,
}
