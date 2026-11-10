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

-- What a clause targets, as the words a player reads in the "What it does" panel. A unit token the table does not
-- know gets no phrase, so the caller can skip the clause instead of inventing one.
local TARGET_PHRASES = {
	player = L["yourself"],
	mouseover = L["your mouseover"],
	target = L["your target"],
	focus = L["your focus"],
	pet = L["your pet"],
	targettarget = L["your target's target"],
	pettarget = L["your pet's target"],
}

-- Conditions that describe the unit or the modifier already named by the clause's target or key. Their phrase would
-- repeat the target ("your mouseover enemy on an enemy"), so the case leaves them out.
local TARGET_CONDITIONS = {
	harm = true,
	help = true,
	exists = true,
	dead = true,
	mouseover = true,
	target = true,
	focus = true,
	player = true,
	pet = true,
}

-- Commands whose clauses name an action, with an optional target: the /cast and /use family.
local ACTION_COMMANDS = {
	cast = true,
	spell = true,
	use = true,
	castsequence = true,
	castrandom = true,
	userandom = true,
	usetoy = true,
}

-- Commands that go in the "Also" case, with the words the panel uses for them. These lines run after the cast lines,
-- so they are one sentence joined by "then".
local ALSO_PHRASES = {
	petattack = L["Pet attacks"],
	petfollow = L["Pet follows"],
	petstay = L["Pet stays"],
	petpassive = L["Pet turns passive"],
	petdefensive = L["Pet turns defensive"],
	petassist = L["Pet assists"],
	startattack = L["You start attacking"],
	stopattack = L["You stop attacking"],
	stopcasting = L["You stop casting"],
}

-- The panel's row order: the plain click first, then each modifier, then the commands that run either way.
local CASE_ORDER = {
	L["Click"],
	L["Shift"],
	L["Ctrl"],
	L["Alt"],
	L["Also"],
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

---@param group MacroAssistGroup
---@param name string
---@return boolean
local function GroupHasCondition(group, name)
	for _, condition in ipairs(group.conditions) do
		if condition.name == name and not condition.no then
			return true
		end
	end
	return false
end

-- One condition group's target phrase. A group with no unit and no conditions is the macro's fallback, and a group
-- with no unit but conditions still acts on the player's target. A unit token the table does not know returns nil.
---@param group MacroAssistGroup
---@return string?
local function GroupTarget(group)
	local unit = group.unit
	if unit and unit.token ~= "" then
		local phrase = TARGET_PHRASES[unit.token]
		if not phrase then
			return nil
		end
		if unit.token == "mouseover" then
			if GroupHasCondition(group, "harm") then
				return L["your mouseover enemy"]
			end
			if GroupHasCondition(group, "help") then
				return L["your mouseover friend"]
			end
		end
		return phrase
	end
	if #group.conditions == 0 then
		return L["otherwise your target"]
	end
	return L["your target"]
end

-- Every target a clause names, in the order the client tries its groups. nil when one group has a unit this file does
-- not understand, so the whole clause is skipped rather than given a made-up target.
---@param clause MacroAssistClause
---@return string?
local function ClauseTarget(clause)
	if #clause.groups == 0 then
		return L["your target"]
	end
	local phrases = {}
	for _, group in ipairs(clause.groups) do
		local phrase = GroupTarget(group)
		if not phrase then
			return nil
		end
		phrases[#phrases + 1] = phrase
	end
	return table.concat(phrases, ", ")
end

-- The clause's target for an "Also" command: the first group only, so a mouseover-then-target command reads as one
-- short sentence instead of repeating the fallback.
---@param clause MacroAssistClause
---@return string?
local function AlsoTarget(clause)
	if #clause.groups == 0 then
		return L["your target"]
	end
	local phrase = GroupTarget(clause.groups[1])
	if phrase == L["otherwise your target"] then
		return L["your target"]
	end
	return phrase
end

-- Conditions that add meaning beyond the target, such as [combat] or [mounted]. Target conditions and modifiers are
-- already covered by the target phrase and the row's key.
---@param clause MacroAssistClause
---@return string?
local function ClauseExtra(clause)
	local phrases = {}
	local seen = {}
	for _, condition in ipairs(clause.conditions) do
		if condition.name ~= "mod" and not TARGET_CONDITIONS[condition.name] then
			local phrase = CONDITION_PHRASES[ConditionKey(condition)]
			if not phrase and not condition.no then
				phrase = CONDITION_PHRASES[condition.name]
			end
			if phrase and not seen[phrase] then
				seen[phrase] = true
				phrases[#phrases + 1] = phrase
			end
		end
	end
	if #phrases == 0 then
		return nil
	end
	return table.concat(phrases, " ")
end

-- The action a clause names, or nil when it names none (for example `/cast [mod:shift]` with no spell).
---@param clause MacroAssistClause
---@return string?
local function ClauseAction(clause)
	if not clause.args then
		return nil
	end
	local names = {}
	for _, item in ipairs(clause.args.items) do
		if item.name and item.name ~= "" then
			names[#names + 1] = item.name
		end
	end
	if #names == 0 then
		return nil
	end
	return table.concat(names, ", ")
end

-- The row key a clause belongs to: its modifier, or Click when it has none. An unsupported modifier skips the clause.
---@param clause MacroAssistClause
---@return string? key
---@return boolean understood
local function ClauseKey(clause)
	for _, condition in ipairs(clause.conditions) do
		if condition.name == "mod" and not condition.no then
			local param = (condition.param or ""):lower()
			if param == "shift" then
				return L["Shift"], true
			elseif param == "ctrl" then
				return L["Ctrl"], true
			elseif param == "alt" then
				return L["Alt"], true
			end
			return nil, false
		end
	end
	return L["Click"], true
end

---@param text string
---@return string
local function LowerFirst(text)
	if text == "" then
		return text
	end
	return text:sub(1, 1):lower() .. text:sub(2)
end

-- What the macro does, one row per click and modifier branch, then one "Also" row for the commands that run either
-- way. Built from the parse tree only: a line, clause or condition this file cannot read adds nothing.
---@class MacroAssistExplainCase
---@field key string
---@field text string
---@field action string

---@class MacroAssistExplainCases
---@field [integer] MacroAssistExplainCase
---@field count? integer the number of actions joined into these cases

---@param body string?
---@return MacroAssistExplainCases
local function ExplainCases(body)
	if type(body) ~= "string" or body == "" then
		return {} --[[@as MacroAssistExplainCases]]
	end
	local parsed = ns.Parser.Parse(body)
	local cases = {}
	local byKey = {}
	local also = {}
	local total = 0

	-- `action` is the case's first action alone, without its target: the list summary shows it beside a count of
	-- the other cases, so a macro with several branches reads short instead of repeating the What it does panel.
	-- The clause with no conditions is the macro's main action, so it wins the case's action even when it is not
	-- the first clause the parser reads.
	local function Add(key, text, action, primary)
		if not key or not text or text == "" then
			return
		end
		total = total + 1
		local case = byKey[key]
		if case then
			case.text = case.text .. ", " .. text
			if primary and action then
				case.action = action
			end
			return
		end
		case = { key = key, text = text, action = action or text }
		byKey[key] = case
		cases[#cases + 1] = case
	end

	for _, line in ipairs(parsed.lines) do
		local command = line.kind == "command" and line.command and line.command.nameLower or nil
		if command and ACTION_COMMANDS[command] then
			for _, clause in ipairs(line.clauses) do
				local action = ClauseAction(clause)
				local key, understood = ClauseKey(clause)
				local target = ClauseTarget(clause)
				if action and understood and target then
					local text = action .. " " .. target
					local extra = ClauseExtra(clause)
					if extra then
						text = text .. " " .. extra
					end
					Add(key, text, action, clause.unconditional)
				end
			end
		elseif command and ALSO_PHRASES[command] then
			local phrase = ALSO_PHRASES[command]
			local clause = line.clauses[1]
			local target
			if command == "petattack" and clause then
				target = AlsoTarget(clause)
			end
			also[#also + 1] = { phrase = phrase, target = target }
		end
	end

	if #also > 0 then
		local parts = {}
		for index, item in ipairs(also) do
			local text = item.phrase
			if item.target then
				text = text .. " " .. item.target
			end
			if index > 1 then
				text = LowerFirst(text)
			end
			parts[#parts + 1] = text
		end
		Add(L["Also"], table.concat(parts, ", then "), also[1].phrase)
	end

	local ordered = {}
	for _, key in ipairs(CASE_ORDER) do
		if byKey[key] then
			ordered[#ordered + 1] = byKey[key]
		end
	end
	ordered.count = total
	return ordered --[[@as MacroAssistExplainCases]]
end

-- The list's one-line summary: the first case's action, then a count of the remaining actions. A macro with a single
-- action reads as just that action, and one the parse cannot branch falls back to the full Explain line.
---@param body string?
---@return string
local function ExplainSummary(body)
	local cases = ExplainCases(body)
	if #cases == 0 then
		return Explain(body)
	end
	local main = cases[1].action or cases[1].text
	local others = (cases.count or #cases) - 1
	if others <= 0 then
		return main
	end
	return L["%s +%d"]:format(main, others)
end

ns.Explain = Explain
ns.ExplainCases = ExplainCases
ns.ExplainSummary = ExplainSummary
