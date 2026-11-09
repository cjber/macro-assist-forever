local _, ns = ...

-- One line for the macro list, built from the parse tree only: no keyword guessing over the macro's free text.
-- A condition contributes a phrase only when Locales/enUS.lua has one for it; anything else falls back to listing
-- the spells the clause casts. The default clause comes first, as the macro's main action, then the alternatives.

local L = ns.L

local CONDITION_PHRASES = {
	["mod:shift"] = L["on Shift"],
	["mod:ctrl"] = L["on Ctrl"],
	["mod:alt"] = L["on Alt"],
	["mod:meta"] = L["on Meta"],
	["mod:any"] = L["on any modifier"],
	["mod"] = L["on that modifier"],
	["actionbar"] = L["on that action bar"],
	["bonusbar"] = L["on the bonus action bar"],
	["btn"] = L["on that mouse button"],
	["canexitvehicle"] = L["while you can leave the vehicle"],
	["cursor"] = L["while holding something"],
	["equipped"] = L["with that item type equipped"],
	["extrabar"] = L["on the extra action bar"],
	["house"] = L["at that housing location"],
	["known"] = L["if you know that spell"],
	["overridebar"] = L["on the override action bar"],
	["party"] = L["in a party"],
	["possessbar"] = L["on the possess action bar"],
	["raid"] = L["in a raid"],
	["shapeshift"] = L["in that form"],
	["spec"] = L["in that specialization"],
	["talent"] = L["with that talent"],
	["unithasvehicleui"] = L["while the unit is in a vehicle"],
	["bar"] = L["on that action bar"],
	["form"] = L["in that form"],
	["stance"] = L["in that form"],
	["mouseover"] = L["on mouseover"],
	["target"] = L["on your target"],
	["focus"] = L["on your focus"],
	["harm"] = L["on an enemy"],
	["help"] = L["on a friend"],
	["exists"] = L["if it exists"],
	["no:exists"] = L["if it doesn't exist"],
	["dead"] = L["if it is dead"],
	["no:dead"] = L["if it is alive"],
	["combat"] = L["in combat"],
	["no:combat"] = L["out of combat"],
	["mounted"] = L["while mounted"],
	["no:mounted"] = L["while not mounted"],
	["swimming"] = L["while swimming"],
	["flying"] = L["while flying"],
	["flyable"] = L["where you can fly"],
	["advflyable"] = L["where you can use advanced flying"],
	["stealth"] = L["while stealthed"],
	["indoors"] = L["indoors"],
	["outdoors"] = L["outdoors"],
	["resting"] = L["while resting"],
	["group"] = L["in a group"],
	["group:party"] = L["in a party"],
	["group:raid"] = L["in a raid"],
	["pet"] = L["with a pet"],
	["channeling"] = L["while channelling"],
	["pvpcombat"] = L["in PvP combat"],
	["petbattle"] = L["in a pet battle"],
	["vehicleui"] = L["while in a vehicle"],
	["vehicle"] = L["while in a vehicle"],
	["bonusbar:5"] = L["on the bonus action bar"],
	["bar:1"] = L["on the first action bar"],
	["bar:2"] = L["on the second action bar"],
	["bar:3"] = L["on the third action bar"],
	["bar:4"] = L["on the fourth action bar"],
	["bar:5"] = L["on the fifth action bar"],
	["bar:6"] = L["on the sixth action bar"],
	["stance:1"] = L["in that form"],
	["stance:2"] = L["in that form"],
	["stance:3"] = L["in that form"],
	["form:1"] = L["in that form"],
	["form:2"] = L["in that form"],
	["form:3"] = L["in that form"],
}

local COMMAND_PHRASES = {
	petattack = L["Pet attack"],
	petfollow = L["Pet follow"],
	petstay = L["Pet stay"],
	petpassive = L["Pet passive"],
	petdefensive = L["Pet defensive"],
	petassist = L["Pet assist"],
	startattack = L["Start attacking"],
	stopattack = L["Stop attacking"],
	stopcasting = L["Stop casting"],
}

local MAX_SUMMARY = 100

---@param condition MacroAssistConditionNode
---@return string
local function ConditionKey(condition)
	local name = condition.name or ""
	local key = (condition.no and "no:" or "") .. name
	if condition.param and condition.param ~= "" then
		key = key .. ":" .. condition.param:lower()
	end
	return key
end

---@param clause MacroAssistClause
---@return string?
local function ClausePhrase(clause)
	local phrases = {}
	local seen = {}
	for _, condition in ipairs(clause.conditions) do
		local phrase = CONDITION_PHRASES[ConditionKey(condition)]
		if not phrase and not condition.no then
			phrase = CONDITION_PHRASES[condition.name]
		end
		if phrase and not seen[phrase] then
			seen[phrase] = true
			phrases[#phrases + 1] = phrase
		end
	end
	if #phrases == 0 then
		return nil
	end
	return table.concat(phrases, " ")
end

---@param clause MacroAssistClause
---@return string? unit
local function ClauseUnit(clause)
	for _, group in ipairs(clause.groups) do
		if group.unit and group.unit.token ~= "" then
			return group.unit.token
		end
	end
end

---@param clause MacroAssistClause
---@return boolean
local function HasFallbackGroup(clause)
	for _, group in ipairs(clause.groups) do
		if #group.conditions == 0 then
			return true
		end
	end
	return false
end

---@param clause MacroAssistClause
---@param line MacroAssistLine
---@return string
local function ClauseText(clause, line)
	local names = {}
	if clause.args then
		for _, item in ipairs(clause.args.items) do
			if item.name and item.name ~= "" then
				names[#names + 1] = item.name
			end
		end
	end
	if #names > 0 then
		return table.concat(names, ", ")
	end
	if line.command and line.command.nameLower ~= "" then
		local phrase = COMMAND_PHRASES[line.command.nameLower]
		if phrase then
			return phrase
		end
		return "/" .. line.command.name
	end
	return ""
end

---@param text string
---@return string
local function Cut(text)
	if #text <= MAX_SUMMARY then
		return text
	end
	local stop = MAX_SUMMARY - 3
	while stop > 0 and text:byte(stop + 1) and text:byte(stop + 1) >= 0x80 and text:byte(stop + 1) < 0xC0 do
		stop = stop - 1
	end
	return text:sub(1, stop) .. "..."
end

---@param line MacroAssistLine
---@param parts string[]
---@param seen table<string, boolean>
local function AddLine(line, parts, seen)
	if line.kind == "empty" or line.kind == "directive" then
		return
	end
	if line.kind ~= "command" then
		local text = line.text:gsub("^%s+", ""):gsub("%s+$", "")
		if text ~= "" and not seen[text] then
			seen[text] = true
			parts[#parts + 1] = text
		end
		return
	end
	local defaultText
	local alternatives = {}
	for _, clause in ipairs(line.clauses) do
		local text = ClauseText(clause, line)
		if clause.unconditional and defaultText == nil and text ~= "" then
			defaultText = text
			local unit = ClauseUnit(clause)
			if unit == "mouseover" and HasFallbackGroup(clause) then
				alternatives[#alternatives + 1] = L["mouseover first"]
			end
		elseif text ~= "" then
			local phrase = ClausePhrase(clause)
			if phrase then
				alternatives[#alternatives + 1] = text .. " " .. phrase
			else
				alternatives[#alternatives + 1] = text
			end
		end
	end
	if defaultText and not seen[defaultText] then
		seen[defaultText] = true
		parts[#parts + 1] = defaultText
	end
	for _, text in ipairs(alternatives) do
		if not seen[text] then
			seen[text] = true
			parts[#parts + 1] = text
		end
	end
end

---@param body string?
---@return string
local function Explain(body)
	if type(body) ~= "string" or body == "" then
		return ""
	end
	local parsed = ns.Parser.Parse(body)
	local parts = {}
	local seen = {}
	for _, line in ipairs(parsed.lines) do
		AddLine(line, parts, seen)
	end
	return Cut(table.concat(parts, ", "))
end

ns.Explain = Explain
