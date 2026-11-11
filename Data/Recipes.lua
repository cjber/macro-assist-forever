local _, ns = ...

if ns.broken then
	return
end

-- Recipes the completion list offers when the player types plain words on a line, such as "pet" or "heal mouseover".
-- Every recipe is checked by tests/recipes_spec.lua before it ships: its rendered body has no diagnostics and fits the
-- 255-character limit. A body writes a spell name as `%s`, with the spell IDs in `spells` in the same order, so the
-- client's language decides the name. `title` is a key in Locales/enUS.lua, and `class` is the UnitClass token the
-- recipe belongs to; a recipe with no class is offered to every player.

---@class MacroAssistRecipe
---@field words string[] the plain words that offer this recipe
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
		words = { "pet", "heal pet", "mend pet", "pet heal" },
		title = "Heal the pet",
		class = "HUNTER",
		body = "#showtooltip\n/cast [@pet,nodead] %s",
		spells = { 136 },
	},
	{
		words = { "pet", "revive pet", "pet revive" },
		title = "Revive the pet",
		class = "HUNTER",
		body = "#showtooltip\n/cast [@pet,dead] %s",
		spells = { 982 },
	},
	{
		words = { "mark", "mark pet", "pet mark", "hunter's mark" },
		title = "Mark and send the pet",
		class = "HUNTER",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s\n/petattack [@mouseover,harm,nodead][]",
		spells = { 1130 },
	},
	{
		words = { "trap", "trap mouseover", "freezing trap" },
		title = "Trap your mouseover",
		class = "HUNTER",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 1499 },
	},
	{
		words = { "heal", "heal mouseover", "flash heal" },
		title = "Heal your mouseover",
		class = "PRIEST",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 2061 },
	},
	{
		words = { "shield", "shield mouseover", "power word shield" },
		title = "Shield your mouseover",
		class = "PRIEST",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 17 },
	},
	{
		words = { "polymorph", "sheep", "polymorph mouseover" },
		title = "Polymorph your mouseover",
		class = "MAGE",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 118 },
	},
	{
		words = { "interrupt", "counterspell", "kick" },
		title = "Interrupt your mouseover",
		class = "MAGE",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 2139 },
	},
	{
		words = { "heal", "heal mouseover", "healing touch" },
		title = "Heal your mouseover",
		class = "DRUID",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 5185 },
	},
	{
		words = { "heal", "heal mouseover", "healing wave" },
		title = "Heal your mouseover",
		class = "SHAMAN",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 331 },
	},
	{
		words = { "heal", "heal mouseover", "holy light" },
		title = "Heal your mouseover",
		class = "PALADIN",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 635 },
	},
	{
		words = { "fear", "fear mouseover" },
		title = "Fear your mouseover",
		class = "WARLOCK",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 5782 },
	},
	{
		words = { "sap", "sap mouseover" },
		title = "Sap your mouseover",
		class = "ROGUE",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 6770 },
	},
	{
		words = { "blind", "blind mouseover" },
		title = "Blind your mouseover",
		class = "ROGUE",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 2094 },
	},
	{
		words = { "intervene", "intervene mouseover" },
		title = "Intervene on your mouseover",
		class = "WARRIOR",
		body = "#showtooltip\n/cast [@mouseover,help,nodead][] %s",
		spells = { 3411 },
	},
	{
		words = { "death grip", "grip", "grip mouseover" },
		title = "Death Grip your mouseover",
		class = "DEATHKNIGHT",
		body = "#showtooltip\n/cast [@mouseover,harm,nodead][] %s",
		spells = { 49576 },
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

---@class MacroAssistRecipes
---@field List MacroAssistRecipe[]
---@field Render fun(recipe: MacroAssistRecipe, spellName: fun(spellID: integer): string?): string?

ns.Recipes = {
	List = recipes,
	Render = Render,
}
