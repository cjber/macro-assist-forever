local _, ns = ...

-- The little bit of the client that completion and checks need: the spellbook, with the rank names the client's own
-- spellbook shows, and a live yes/no for one condition. Everything else in the editor is pure Lua in Core/.

local L = ns.L

local ctx = { spells = {} }
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
					if not spellType or item.itemType == spellType then
						local rank
						if
							item.spellID
							and type(C_Spell) == "table"
							and type(C_Spell.GetSpellSubtext) == "function"
						then
							local subOk, sub = pcall(C_Spell.GetSpellSubtext, item.spellID)
							if subOk then
								rank = ns.Readable(sub)
							end
						end
						rank = rank or ns.Readable(item.subName)
						local number = type(rank) == "string" and tonumber(rank:match("(%d+)")) or nil
						local key = spellName:lower()
						local existing = byName[key]
						if existing then
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
								learned = true,
							}
							byName[key] = entry
							spells[#spells + 1] = entry
						end
					end
				end
			end
		end
	end
	return spells
end

function ns.Context.Rebuild()
	ctx.spells = Spellbook()
end

ns.Context.Rebuild()
