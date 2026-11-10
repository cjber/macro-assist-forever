-- The client's macro store and spellbook, which the simulator does not boot itself: the globals Blizzard_MacroUI and
-- this addon call, and a small spellbook with rank subtexts and a flyout so completion and checks have real data.

local M = {}

local ICONS = {
	"INV_Misc_QuestionMark",
	"Ability_Hunter_Quickshot",
	"Spell_Shadow_DeathCoil",
	"Spell_Frost_FrostNova",
	"Ability_Hunter_SniperShot",
	"Ability_Hunter_RunningShot",
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
	local character = {
		{
			name = "Arcane",
			icon = "Ability_Hunter_Quickshot",
			body = "#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot",
		},
		{ name = "Pet", icon = "Ability_Hunter_Pet_Wolf", body = "/cast Mend Pet; Revive Pet" },
		{ name = "FD", icon = "Spell_Shadow_DeathCoil", body = "/cast Feign Death\n/stopattack" },
		{ name = "Trap", icon = "Spell_Frost_FrostNova", body = "/cast Freezing Trap" },
		{
			name = "Mark",
			icon = "Ability_Hunter_SniperShot",
			body = "/cast [@mouseover,harm,nodead][] Hunter's Mark\n/petattack [@mouseover,harm,nodead][]",
		},
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
	G.CreateMacro = function(name, icon, body, isCharacter)
		local target = list(isCharacter)
		local maximum = isCharacter and maxCharacter or maxAccount
		if #target >= maximum then
			return nil
		end
		target[#target + 1] = { name = name, icon = icon, body = body or "" }
		return base(isCharacter) + #target
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
		{ name = "Arcane Shot", rank = 4, id = 3044 },
		{ name = "Wing Clip", rank = 2, id = 2974 },
		{ name = "Raptor Strike", rank = 5, id = 2973 },
		{ name = "Mend Pet", id = 136 },
		{ name = "Revive Pet", id = 982 },
		{ name = "Feign Death", id = 5384 },
		{ name = "Freezing Trap", id = 1499 },
		{ name = "Hunter's Mark", id = 1130 },
		{ name = "Aspect of the Cheetah", id = 5118 },
		{ name = "Serpent Sting", id = 1978 },
		{ name = "Concussive Shot", id = 5116 },
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
				iconID = 134400,
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
		if spells[slot] or flyouts[slot - #spells] then
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
	sim.impl["C_Spell.GetSpellTexture"] = function()
		return 134400
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
