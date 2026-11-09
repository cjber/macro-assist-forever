local _, ns = ...

local L = ns.L

-- Macro conditions, from warcraft.wiki.gg/wiki/Macro_conditionals. Every entry keeps `verified = false` until an
-- in-game probe confirms it on this client; the probe is a later issue. `forever = false` marks a condition the
-- Forever client parses but nothing in its 1.x content can make true: the editor warns instead of calling it unknown,
-- and completion offers it last.

---@class MacroAssistCondition
---@field name string the canonical keyword
---@field aliases string[] every keyword, canonical first
---@field param "none"|"optional"|"required" whether a `:parameter` is read
---@field form string? how the parameter is written, for the completion detail
---@field values string[]? the parameter values completion offers
---@field no boolean whether the `no` prefix is accepted
---@field description string one line, for the completion detail
---@field forever boolean? false when the engine parses it but nothing on Forever makes it true
---@field verified boolean false until the in-game probe has confirmed this entry

---@type MacroAssistCondition[]
ns.Conditions = {
	{
		name = "exists",
		aliases = { "exists" },
		param = "none",
		no = true,
		description = L["The unit exists."],
		verified = false,
	},
	{
		name = "help",
		aliases = { "help" },
		param = "none",
		no = true,
		description = L["The unit exists and can be helped."],
		verified = false,
	},
	{
		name = "harm",
		aliases = { "harm" },
		param = "none",
		no = true,
		description = L["The unit exists and can be harmed."],
		verified = false,
	},
	{
		name = "dead",
		aliases = { "dead" },
		param = "none",
		no = true,
		description = L["The unit exists and is dead."],
		verified = false,
	},
	{
		name = "party",
		aliases = { "party" },
		param = "none",
		no = true,
		description = L["The unit is in your party."],
		verified = false,
	},
	{
		name = "raid",
		aliases = { "raid" },
		param = "none",
		no = true,
		description = L["The unit is in your raid or party."],
		verified = false,
	},
	{
		name = "combat",
		aliases = { "combat" },
		param = "none",
		no = true,
		description = L["You are in combat."],
		verified = false,
	},
	{
		name = "mounted",
		aliases = { "mounted" },
		param = "none",
		no = true,
		description = L["You are mounted."],
		verified = false,
	},
	{
		name = "swimming",
		aliases = { "swimming" },
		param = "none",
		no = true,
		description = L["You are swimming."],
		verified = false,
	},
	{
		name = "indoors",
		aliases = { "indoors" },
		param = "none",
		no = true,
		description = L["You are indoors."],
		verified = false,
	},
	{
		name = "outdoors",
		aliases = { "outdoors" },
		param = "none",
		no = true,
		description = L["You are outdoors."],
		verified = false,
	},
	{
		name = "resting",
		aliases = { "resting" },
		param = "none",
		no = true,
		description = L["You are resting."],
		verified = false,
	},
	{
		name = "stealth",
		aliases = { "stealth" },
		param = "none",
		no = true,
		description = L["You are stealthed."],
		verified = false,
	},
	{
		name = "cursor",
		aliases = { "cursor" },
		param = "none",
		no = true,
		description = L["Your cursor is holding an item, spell or macro."],
		verified = false,
	},
	{
		name = "stance",
		aliases = { "stance", "form" },
		param = "required",
		form = "stance:0-5",
		values = { "0", "1", "2", "3", "4", "5" },
		no = true,
		description = L["You are in the given stance or form."],
		verified = false,
	},
	{
		name = "mod",
		aliases = { "mod", "modifier" },
		param = "optional",
		form = "mod:shift/ctrl/alt",
		values = { "shift", "ctrl", "alt" },
		no = true,
		description = L["The given modifier key is held."],
		verified = false,
	},
	{
		name = "btn",
		aliases = { "btn", "button" },
		param = "required",
		form = "btn:1-5",
		values = { "1", "2", "3", "4", "5" },
		no = true,
		description = L["The macro was clicked with the given mouse button."],
		verified = false,
	},
	{
		name = "actionbar",
		aliases = { "actionbar", "bar" },
		param = "required",
		form = "actionbar:1-6",
		values = { "1", "2", "3", "4", "5", "6" },
		no = true,
		description = L["The given action bar page is shown."],
		verified = false,
	},
	{
		name = "bonusbar",
		aliases = { "bonusbar" },
		param = "optional",
		form = "bonusbar:1-5",
		values = { "1", "2", "3", "4", "5" },
		no = true,
		description = L["A bonus action bar is shown."],
		verified = false,
	},
	{
		name = "possessbar",
		aliases = { "possessbar" },
		param = "none",
		no = true,
		description = L["The possess action bar is shown."],
		verified = false,
	},
	{
		name = "channeling",
		aliases = { "channeling" },
		param = "optional",
		form = "channeling:<spell>",
		no = true,
		description = L["You are channeling a spell, or the given spell."],
		verified = false,
	},
	{
		name = "equipped",
		aliases = { "equipped", "worn" },
		param = "required",
		form = "equipped:<item type>",
		no = true,
		description = L["An item of the given type is equipped."],
		verified = false,
	},
	{
		name = "pet",
		aliases = { "pet" },
		param = "required",
		form = "pet:<name or family>",
		no = true,
		description = L["The given pet is out."],
		verified = false,
	},
	{
		name = "group",
		aliases = { "group" },
		param = "optional",
		form = "group:party/raid",
		values = { "party", "raid" },
		no = true,
		description = L["You are in a group, or the given kind of group."],
		verified = false,
	},
	{
		name = "known",
		aliases = { "known" },
		param = "required",
		form = "known:<spell name or ID>",
		no = true,
		description = L["You know the given spell."],
		verified = false,
	},

	-- Parsed by the engine, but nothing on Forever can make these true.
	{
		name = "advflyable",
		aliases = { "advflyable" },
		param = "none",
		no = true,
		description = L["You can use advanced flying here."],
		forever = false,
		verified = false,
	},
	{
		name = "canexitvehicle",
		aliases = { "canexitvehicle" },
		param = "none",
		no = true,
		description = L["You are in a vehicle and can leave it."],
		forever = false,
		verified = false,
	},
	{
		name = "vehicleui",
		aliases = { "vehicleui" },
		param = "none",
		no = true,
		description = L["The vehicle UI is shown."],
		forever = false,
		verified = false,
	},
	{
		name = "unithasvehicleui",
		aliases = { "unithasvehicleui" },
		param = "none",
		no = true,
		description = L["The unit exists and is in a vehicle."],
		forever = false,
		verified = false,
	},
	{
		name = "spec",
		aliases = { "spec" },
		param = "required",
		form = "spec:1-4",
		values = { "1", "2", "3", "4" },
		no = true,
		description = L["The given specialization is active."],
		forever = false,
		verified = false,
	},
	{
		name = "pvpcombat",
		aliases = { "pvpcombat" },
		param = "none",
		no = true,
		description = L["You are in PvP combat."],
		forever = false,
		verified = false,
	},
	{
		name = "petbattle",
		aliases = { "petbattle" },
		param = "none",
		no = true,
		description = L["You are in a pet battle."],
		forever = false,
		verified = false,
	},
	{
		name = "house",
		aliases = { "house" },
		param = "optional",
		form = "house:inside/plot/editor/neighborhood",
		values = { "inside", "plot", "editor", "neighborhood" },
		no = true,
		description = L["You are at the given housing location."],
		forever = false,
		verified = false,
	},
	{
		name = "extrabar",
		aliases = { "extrabar" },
		param = "none",
		no = true,
		description = L["An extra action bar is shown."],
		forever = false,
		verified = false,
	},
	{
		name = "overridebar",
		aliases = { "overridebar" },
		param = "none",
		no = true,
		description = L["The override action bar is replacing your main bar."],
		forever = false,
		verified = false,
	},
	{
		name = "shapeshift",
		aliases = { "shapeshift" },
		param = "none",
		no = true,
		description = L["A temporary shapeshift action bar is replacing your main bar."],
		forever = false,
		verified = false,
	},
	{
		name = "talent",
		aliases = { "talent" },
		param = "required",
		form = "talent:<row>/<column>",
		no = true,
		description = L["The given talent row and column is active."],
		forever = false,
		verified = false,
	},
	{
		name = "flyable",
		aliases = { "flyable" },
		param = "none",
		no = true,
		description = L["You can use a flying mount here."],
		forever = false,
		verified = false,
	},
	{
		name = "flying",
		aliases = { "flying" },
		param = "none",
		no = true,
		description = L["You are flying."],
		forever = false,
		verified = false,
	},
}

---@type table<string, MacroAssistCondition>
ns.ConditionAliases = {}
for _, condition in ipairs(ns.Conditions) do
	for _, alias in ipairs(condition.aliases) do
		ns.ConditionAliases[alias] = condition
	end
	ns.ConditionAliases[condition.name] = condition
end

-- Unit tokens for @unit and target=unit. party and raid pets exist in 1.x, and a unit can be followed by `target` to
-- look at its target. Arenas do not exist in 1.x content, but the client still parses the tokens, so they stay.
local units = {
	"player",
	"target",
	"focus",
	"mouseover",
	"pet",
	"none",
}
for index = 1, 4 do
	units[#units + 1] = "party" .. index
	units[#units + 1] = "partypet" .. index
end
for index = 1, 40 do
	units[#units + 1] = "raid" .. index
	units[#units + 1] = "raidpet" .. index
end
for index = 1, 5 do
	units[#units + 1] = "arena" .. index
end
local chained = {}
for _, unit in ipairs(units) do
	if unit ~= "none" then
		chained[#chained + 1] = unit .. "target"
	end
end
for _, unit in ipairs(chained) do
	units[#units + 1] = unit
end
table.sort(units)

---@type string[]
ns.Units = units

---@type table<string, boolean>
ns.UnitSet = {}
for _, unit in ipairs(ns.Units) do
	ns.UnitSet[unit] = true
end
