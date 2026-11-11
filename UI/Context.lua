local _, ns = ...

if ns.broken then
	return
end

-- The little bit of the client that completion and checks need: the spellbook, with the rank names the client's own
-- spellbook shows, and a live yes/no for one condition. Everything else in the editor is pure Lua in Core/.

local L = ns.L

local ctx = { spells = {}, recipes = {} }
ns.Context = { ctx = ctx }

-- The parts of a condition descriptor or parser node that the engine call needs. Completion passes a descriptor
-- whose `no` is the actual negation; the wrapped condition's own `no` field only says that the engine accepts the no
-- prefix. A parser node passed directly has no wrapper.
---@param condition any
---@return string? name
---@return boolean negated
---@return string? param
local function Describe(condition)
	if type(condition) == "string" then
		return condition:lower(), false, nil
	end
	if type(condition) ~= "table" then
		return nil, false, nil
	end
	local node = condition.condition or condition
	local name = condition.name or node.name
	if type(name) ~= "string" or name == "" then
		return nil, false, nil
	end
	local negated
	if condition.condition ~= nil then
		negated = condition.no == true
	else
		negated = condition.no or node.no
	end
	local param = condition.param or node.param
	if type(param) ~= "string" or param == "" then
		param = nil
	end
	return name:lower(), not not negated, param
end

---@param condition any
---@return string?
local function ConditionText(condition)
	local name, negated, param = Describe(condition)
	if not name then
		return nil
	end
	local text = negated and ("no" .. name) or name
	if param then
		text = text .. ":" .. param
	end
	return text
end

---@param condition any
---@return string?
local function Evaluate(condition)
	local text = ConditionText(condition)
	if not text or type(SecureCmdOptionParse) ~= "function" then
		return nil
	end
	-- Only an entry the parser and ns.Conditions recognise may reach the engine; anything else is a typing mistake
	-- the checker reports, and the client would print it to chat. A parameter the entry cannot use is refused too.
	local name, negated, param = Describe(condition)
	if not ns.ConditionAccepted(name and ns.ConditionAliases[name], negated, param ~= nil, param) then
		return nil
	end
	local ok, value = pcall(SecureCmdOptionParse, "[" .. text .. "] 1")
	if not ok then
		return nil
	end
	return value == "1" and L["yes"] or L["no"]
end

ctx.evaluate = Evaluate

-- One spell the player knows, added under its name. The same name reached twice, from a spellbook line and from a
-- flyout, is one entry whose ranks both contribute.
---@param spells table[]
---@param byName table
---@param spellName string
---@param spellID any
---@param subName any?
---@param icon any?
local function AddSpell(spells, byName, spellName, spellID, subName, icon)
	if icon == nil and spellID and type(C_Spell) == "table" and type(C_Spell.GetSpellTexture) == "function" then
		local textureOk, texture = pcall(C_Spell.GetSpellTexture, spellID)
		if textureOk then
			icon = texture
		end
	end
	local rank
	if spellID and type(C_Spell) == "table" and type(C_Spell.GetSpellSubtext) == "function" then
		local subOk, sub = pcall(C_Spell.GetSpellSubtext, spellID)
		if subOk then
			rank = ns.Readable(sub)
		end
	end
	rank = rank or ns.Readable(subName)
	local number = type(rank) == "string" and tonumber(rank:match("(%d+)")) or nil
	local key = spellName:lower()
	local existing = byName[key]
	if existing then
		existing.icon = existing.icon or icon
		if number then
			existing.ranks = existing.ranks or {}
			local found = false
			for _, value in ipairs(existing.ranks) do
				if value == number then
					found = true
					break
				end
			end
			if not found then
				existing.ranks[#existing.ranks + 1] = number
			end
		end
	else
		local entry = {
			name = spellName,
			ranks = number and { number } or nil,
			icon = icon,
			learned = true,
		}
		byName[key] = entry
		spells[#spells + 1] = entry
	end
end

-- A flyout is a button holding several spells: Pet Utilities, Aspect and the like. Blizzard's spell search walks one
-- the same way (Blizzard_SpellSearchNameFilter.lua, DerivedGetMatchTypeForFlyout): GetFlyoutInfo gives the slot count
-- and whether the flyout itself is known, and only a slot whose isKnown is true is a spell the player has.
---@param spells table[]
---@param byName table
---@param flyoutID any
local function AddFlyout(spells, byName, flyoutID)
	if type(GetFlyoutInfo) ~= "function" or type(GetFlyoutSlotInfo) ~= "function" then
		return
	end
	local infoOk, numSlots, isKnown = pcall(function()
		local _, _, slots, known = GetFlyoutInfo(flyoutID)
		return slots, known
	end)
	if not infoOk or isKnown == false or type(numSlots) ~= "number" then
		return
	end
	for index = 1, numSlots do
		local slotOk, spellID, slotKnown, slotName = pcall(function()
			local id, _, known, name = GetFlyoutSlotInfo(flyoutID, index)
			return id, known, name
		end)
		local spellName = slotOk and ns.Readable(slotName) or nil
		if slotKnown and type(spellName) == "string" and spellName ~= "" then
			AddSpell(spells, byName, spellName, spellID)
		end
	end
end

-- Blizzard's spellbook reads a slot's name from C_SpellBook.GetSpellBookItemInfo(slot, bank).name and its rank
-- from the entry's subName, falling back to the spell's subtext (Blizzard_MacroUI's spellbook item does the same).
---@return table[]
local function Spellbook()
	local spells = {}
	if type(C_SpellBook) ~= "table" or type(Enum) ~= "table" or not Enum.SpellBookSpellBank then
		return spells
	end
	local bank = Enum.SpellBookSpellBank.Player
	local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
	local flyoutType = Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
	local byName = {}
	local ok, count = pcall(C_SpellBook.GetNumSpellBookSkillLines)
	if not ok or type(count) ~= "number" then
		return spells
	end
	for line = 1, count do
		local skillOk, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
		if skillOk and type(info) == "table" then
			local first = (info.itemIndexOffset or 0) + 1
			local last = first + (info.numSpellBookItems or 0) - 1
			for slot = first, last do
				local itemOk, item = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
				local spellName = itemOk and type(item) == "table" and ns.Readable(item.name) or nil
				if type(spellName) == "string" and spellName ~= "" then
					if flyoutType and item.itemType == flyoutType then
						AddFlyout(spells, byName, item.actionID)
					elseif not spellType or item.itemType == spellType then
						AddSpell(spells, byName, spellName, item.spellID, item.subName)
					end
				end
			end
		end
	end
	return spells
end

-- The client's name for a spell ID, in the client's language. A spell the client does not know returns nil, which
-- keeps a recipe with a missing spell out of the list rather than inserting an incomplete macro.
---@param spellID integer
---@return string?
local function SpellName(spellID)
	if type(C_Spell) == "table" and type(C_Spell.GetSpellInfo) == "function" then
		local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
		if ok then
			local name = type(info) == "table" and info.name or info
			local readable = ns.Readable(name)
			if readable then
				return readable
			end
		end
	end
	local fallback = rawget(_G, "GetSpellInfo")
	if type(fallback) == "function" then
		local ok, name = pcall(fallback, spellID)
		if ok then
			return ns.Readable(name)
		end
	end
end

---@return string?
local function PlayerClass()
	if type(UnitClass) ~= "function" then
		return nil
	end
	local ok, _, token = pcall(UnitClass, "player")
	if ok and type(token) == "string" then
		return token
	end
end

-- The recipes this character can use, each already rendered with its spell names. A class recipe is left out until
-- UnitClass names the player's class, and a recipe whose spell the client does not know is left out entirely.
---@return table[]
local function AvailableRecipes()
	local class = PlayerClass()
	local list = {}
	for _, recipe in ipairs(ns.Recipes.List) do
		if recipe.class == nil or recipe.class == class then
			local body = ns.Recipes.Render(recipe, SpellName)
			if body then
				list[#list + 1] = {
					words = recipe.words,
					title = L[recipe.title] or recipe.title,
					body = body,
				}
			end
		end
	end
	return list
end

function ns.Context.Rebuild()
	ctx.spells = Spellbook()
	ctx.recipes = AvailableRecipes()
end

ns.Context.Rebuild()
