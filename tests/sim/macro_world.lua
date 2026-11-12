-- The client's macro store and spellbook, which the simulator does not boot itself: the globals Blizzard_MacroUI and
-- this addon call, and a small spellbook with rank subtexts and a flyout so completion and checks have real data.

local M = {}

local ICONS = {
	"INV_Misc_QuestionMark",
	132204,
	136145,
	135848,
	132212,
	132208,
	"Ability_Hunter_Pet_Wolf",
}

---@param sim table
---@return table
function M.install(sim)
	local G = sim.G
	local maxAccount = G.Constants.MacroConsts.MAX_ACCOUNT_MACROS
	local maxCharacter = G.Constants.MacroConsts.MAX_CHARACTER_MACROS
	local account = {
		{ name = "General One", icon = "INV_Misc_QuestionMark", body = "/cast Arcane Shot" },
		{ name = "General Two", icon = "INV_Misc_QuestionMark", body = "/cast Mend Pet" },
	}
	-- The client keeps each list in name order (EditMacro returns "the new index ... as they are sorted
	-- alphabetically"), so the fixture is in the order the client would report.
	local character = {
		{
			name = "Arcane",
			icon = 132204,
			body = "#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot",
		},
		{ name = "FD", icon = 136145, body = "/cast Feign Death\n/stopattack" },
		{
			name = "Mark",
			icon = 132212,
			body = "/cast [@mouseover,harm,nodead][] Hunter's Mark\n/petattack [@mouseover,harm,nodead][]",
		},
		{ name = "Pet", icon = "Ability_Hunter_Pet_Wolf", body = "/cast Mend Pet; Revive Pet" },
		{ name = "Trap", icon = 135848, body = "/cast Freezing Trap" },
	}

	local function list(isCharacter)
		return isCharacter and character or account
	end

	local function base(isCharacter)
		return isCharacter and maxAccount or 0
	end

	G.GetNumMacros = function()
		return #account, #character
	end
	G.GetMacroInfo = function(index)
		local isCharacter = index > maxAccount
		local info = list(isCharacter)[index - base(isCharacter)]
		if info then
			local icon = info.icon
			if type(icon) == "string" and not icon:find("[\\/]") then
				icon = "Interface\\Icons\\" .. icon
			end
			return info.name, icon, info.body
		end
	end
	-- The client keeps each macro list in name order: EditMacro's return is "the new index ... as they are sorted
	-- alphabetically", and CreateMacro returns the index the client's own picker selects. Inserting by name here is
	-- what catches an addon that keeps a stale index after a create.
	G.CreateMacro = function(name, icon, body, isCharacter)
		local target = list(isCharacter)
		local maximum = isCharacter and maxCharacter or maxAccount
		if #target >= maximum then
			return nil
		end
		local position = #target + 1
		for index, info in ipairs(target) do
			if (info.name or ""):lower() > name:lower() then
				position = index
				break
			end
		end
		table.insert(target, position, { name = name, icon = icon, body = body or "" })
		return base(isCharacter) + position
	end
	G.EditMacro = function(index, name, icon, body)
		local isCharacter = index > maxAccount
		local info = list(isCharacter)[index - base(isCharacter)]
		if not info then
			return nil
		end
		if name then
			info.name = name
		end
		if icon then
			info.icon = icon
		end
		if body then
			info.body = body
		end
		return index
	end
	G.DeleteMacro = function(index)
		local isCharacter = index > maxAccount
		local target = list(isCharacter)
		table.remove(target, index - base(isCharacter))
	end
	G.PickupMacro = function(index)
		sim.pickedMacro = index
	end
	G.GetLooseMacroIcons = function(into)
		for _, icon in ipairs(ICONS) do
			into[#into + 1] = icon
		end
	end
	G.GetLooseMacroItemIcons = function() end
	G.GetMacroIcons = function() end
	G.GetMacroItemIcons = function() end

	local spells = {
		{ name = "Arcane Shot", rank = 4, id = 3044, icon = 132204 },
		{ name = "Wing Clip", rank = 2, id = 2974, icon = 132208 },
		{ name = "Raptor Strike", rank = 5, id = 2973, icon = 132212 },
		{ name = "Mend Pet", id = 136, icon = 132179 },
		{ name = "Revive Pet", id = 982, icon = 136081 },
		{ name = "Feign Death", id = 5384, icon = 136145 },
		{ name = "Freezing Trap", id = 1499, icon = 135848 },
		{ name = "Hunter's Mark", id = 1130, icon = 132212 },
		{ name = "Aspect of the Cheetah", id = 5118, icon = 132242 },
		{ name = "Serpent Sting", id = 1978, icon = 132208 },
		{ name = "Concussive Shot", id = 5116, icon = 135860 },
	}
	-- A flyout last in the book, as Pet Utilities sits on the Beast Mastery tab. Call Pet is known; Feed Pet is not,
	-- so only the first belongs in the addon's spell list.
	local flyouts = {
		{
			id = 42,
			name = "Pet Utilities",
			slots = {
				{ name = "Call Pet", id = 883, known = true },
				{ name = "Feed Pet", id = 6991, known = false },
			},
		},
	}
	local subtext = {}
	for _, spell in ipairs(spells) do
		if spell.rank then
			subtext[spell.id] = "Rank " .. spell.rank
		else
			subtext[spell.id] = ""
		end
	end
	sim.impl["C_SpellBook.GetNumSpellBookSkillLines"] = function()
		return 1
	end
	sim.impl["C_SpellBook.GetSpellBookSkillLineInfo"] = function(index)
		if index == 1 then
			return {
				name = "General",
				itemIndexOffset = 0,
				numSpellBookItems = #spells + #flyouts,
				iconID = 134400,
			}
		end
	end
	sim.impl["C_SpellBook.GetSpellBookItemInfo"] = function(slot)
		local spell = spells[slot]
		if spell then
			return {
				name = spell.name,
				subName = subtext[spell.id],
				spellID = spell.id,
				actionID = spell.id,
				itemType = G.Enum.SpellBookItemType.Spell,
				iconID = spell.icon or 134400,
			}
		end
		local flyout = flyouts[slot - #spells]
		if flyout then
			return {
				name = flyout.name,
				subName = "",
				actionID = flyout.id,
				itemType = G.Enum.SpellBookItemType.Flyout,
				iconID = 134400,
			}
		end
	end
	sim.impl["C_SpellBook.GetSpellBookItemType"] = function(slot)
		local spell = spells[slot]
		if spell then
			return "SPELL", spell.id
		end
		local flyout = flyouts[slot - #spells]
		if flyout then
			return "FLYOUT", flyout.id
		end
	end
	sim.impl["C_SpellBook.GetSpellBookItemTexture"] = function(slot)
		local spell = spells[slot]
		if spell then
			return spell.icon or 134400
		end
		if flyouts[slot - #spells] then
			return 134400
		end
	end
	G.GetFlyoutInfo = function(flyoutID)
		for _, flyout in ipairs(flyouts) do
			if flyout.id == flyoutID then
				return flyout.name, "", #flyout.slots, true, 134400
			end
		end
	end
	G.GetFlyoutSlotInfo = function(flyoutID, index)
		for _, flyout in ipairs(flyouts) do
			if flyout.id == flyoutID then
				local slot = flyout.slots[index]
				if slot then
					return slot.id, nil, slot.known, slot.name
				end
				return nil
			end
		end
	end
	sim.impl["C_Spell.GetSpellSubtext"] = function(spellID)
		return subtext[spellID] or ""
	end
	local spellByID = {}
	local spellByName = {}
	for _, spell in ipairs(spells) do
		spellByID[spell.id] = spell
		spellByName[spell.name:lower()] = spell
	end
	for _, flyout in ipairs(flyouts) do
		for _, slot in ipairs(flyout.slots) do
			spellByID[slot.id] = slot
			spellByName[slot.name:lower()] = slot
		end
	end
	sim.impl["C_Spell.GetSpellTexture"] = function(spellID)
		local spell = spellByID[spellID]
		return spell and spell.icon or 134400
	end
	sim.impl["C_Spell.GetSpellInfo"] = function(name)
		local spell = type(name) == "number" and spellByID[name] or spellByName[tostring(name):lower()]
		if spell then
			return {
				name = spell.name,
				iconID = spell.icon or 134400,
				originalIconID = spell.icon or 134400,
				spellID = spell.id,
			}
		end
	end

	-- The action bar as the client answers it. A slot holding a macro reports "macro" and, when the macro's first
	-- spell is one the client knows, that spell's ID with subType "spell"; otherwise it reports the macro index
	-- (Blizzard_ActionBar's ActionButton.lua:1028-1033 and AssistedCombatManager.lua:203-213 read the ID as a spell).
	-- The name on the button, which is what GetActionText gives, is how an addon finds the macro again.
	sim.actionSlots = {}
	local function macroInfoAt(index)
		if type(index) ~= "number" then
			return nil
		end
		local isCharacter = index > maxAccount
		return list(isCharacter)[index - base(isCharacter)]
	end
	local function firstSpellID(body)
		for line in tostring(body):gmatch("[^\n]+") do
			local args = line:match("^%s*/[Cc][Aa][Ss][Tt]%s+(.*)$")
			if args then
				while args:sub(1, 1) == "[" do
					local close = args:find("]", 1, true)
					if not close then
						break
					end
					args = args:sub(close + 1):gsub("^%s+", "")
				end
				args = args:gsub("^!", "")
				local name = args:match("^([^,;]+)")
				if name then
					name = name:gsub("%s+$", "")
					local spell = spellByName[name:lower()]
					if spell then
						return spell.id
					end
				end
			end
		end
	end
	G.GetActionInfo = function(slot)
		local index = sim.actionSlots[slot]
		local info = macroInfoAt(index)
		if not info then
			return nil
		end
		local spellID = firstSpellID(info.body)
		if spellID then
			return "macro", spellID, "spell"
		end
		return "macro", index
	end
	G.GetActionText = function(slot)
		local info = macroInfoAt(sim.actionSlots[slot])
		return info and info.name or nil
	end
	G.GetMacroIndexByName = function(name)
		if type(name) ~= "string" then
			return 0
		end
		for index, info in ipairs(account) do
			if info.name == name then
				return index
			end
		end
		for index, info in ipairs(character) do
			if info.name == name then
				return maxAccount + index
			end
		end
		return 0
	end
	-- Blizzard's Mainline icon provider also walks talent groups, which the simulator does not boot.
	G.GetNumSpecGroups = function()
		return 0
	end

	-- A small SecureCmdOptionParse good enough for a macro line: split on `;`, test each clause's leading
	-- [condition,condition] groups against the scenario's world, and return the first matching clause's argument.
	local function trimmed(text)
		return (text:gsub("^%s+", ""):gsub("%s+$", ""))
	end
	local function conditionHolds(text, unit)
		text = trimmed(text)
		if text == "" then
			return true
		end
		local no = text:sub(1, 2) == "no"
		local word = no and text:sub(3) or text
		local name, param = word:match("^([^:]+):(.*)$")
		name = (name or word):lower()
		param = param and param:lower() or nil
		if name == "mod" then
			local value = (sim.modifiers and sim.modifiers[param]) == true
			return no and not value or value
		end
		if name == "harm" then
			local target = sim.world.units[unit]
			local value = target and target.friendly == false or false
			return no and not value or value
		end
		if name == "help" then
			local target = sim.world.units[unit]
			local value = target and target.friendly ~= false or false
			return no and not value or value
		end
		if name == "exists" then
			return (sim.world.units[unit] ~= nil) ~= no
		end
		if name == "dead" then
			local target = sim.world.units[unit]
			return (target and target.dead == true) ~= no
		end
		if name == "combat" then
			return (sim.inCombat == true) ~= no
		end
		if name == "group" then
			return (#sim.world.group > 0) ~= no
		end
		return true
	end
	local function secureCmdOptionParse(command)
		for clause in tostring(command):gmatch("[^;]+") do
			clause = trimmed(clause)
			local rest = clause
			local hasGroup = false
			local anyGroup = false
			local unit = "target"
			while rest:sub(1, 1) == "[" do
				local close = rest:find("]", 1, true)
				if not close then
					anyGroup = false
					break
				end
				hasGroup = true
				local body = rest:sub(2, close - 1)
				local groupUnit = body:match("^%s*@([%w_]+)")
				if groupUnit then
					unit = groupUnit
				end
				local groupMatches = true
				for condition in body:gmatch("[^,]+") do
					if not conditionHolds(condition, unit) then
						groupMatches = false
						break
					end
				end
				anyGroup = anyGroup or groupMatches
				rest = trimmed(rest:sub(close + 1))
			end
			local matches = (not hasGroup) or anyGroup
			if matches and rest ~= "" then
				return rest
			end
		end
	end
	sim.impl.SecureCmdOptionParse = secureCmdOptionParse
	-- The simulator's own placeholder returns nil; the scenario replaces it as it does the other macro globals.
	G.SecureCmdOptionParse = secureCmdOptionParse

	return { account = account, character = character }
end

return M
