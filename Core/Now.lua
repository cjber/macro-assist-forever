local _, ns = ...

if ns.broken then
	return
end

-- What a macro would run right now, from the parse tree only. SecureCmdOptionParse writes an unknown or half-typed
-- condition to chat, so a line reaches it only when every condition in it resolves to a known entry with a usable
-- parameter. The client read stays in the caller: this file is pure Lua and its spec needs no game.

---@param condition MacroAssistConditionNode
---@return MacroAssistCondition?
local function Entry(condition)
	local entry = ns.ConditionAliases[condition.rawName:lower()]
	if entry then
		return entry
	end
	if condition.no then
		return ns.ConditionAliases[condition.name]
	end
end

-- Whether the engine accepts a condition as written: a known entry, `no` only where the entry allows it, and a
-- parameter exactly when the entry reads one. Context's live values use the same rule.
---@param entry MacroAssistCondition?
---@param negated boolean?
---@param hasColon boolean?
---@param param string?
---@return boolean
local function Accepted(entry, negated, hasColon, param)
	if not entry or (negated and not entry.no) then
		return false
	end
	local hasValue = param ~= nil and param ~= ""
	if entry.param == "none" then
		return not hasColon
	end
	if entry.param == "required" then
		return hasValue
	end
	return not hasColon or hasValue
end

ns.ConditionAccepted = Accepted

---@param condition MacroAssistConditionNode
---@return boolean
local function Usable(condition)
	return Accepted(Entry(condition), condition.no, condition.hasColon, condition.param)
end

-- True when the whole line is safe to hand to SecureCmdOptionParse. A group the parser never closed is not safe:
-- its text has no closing bracket yet.
---@param line MacroAssistLine
---@return boolean
local function SafeToEvaluate(line)
	for _, clause in ipairs(line.clauses or {}) do
		for _, group in ipairs(clause.groups) do
			if not group.closed then
				return false
			end
			for _, condition in ipairs(group.conditions) do
				if not Usable(condition) then
					return false
				end
			end
		end
	end
	return true
end

ns.SafeToEvaluate = SafeToEvaluate

---@param line MacroAssistLine
---@param group MacroAssistGroup
---@return string
local function GroupText(line, group)
	return line.text:sub(group.from - line.from + 1, group.to - line.from + 1)
end

-- Returns the text the macro would run now, whether the macro has any command lines at all, and the explicit unit
-- of the clause that matched (the caller resolves its name). The text has no toggle `!` guard.
---@param parsed MacroAssistParse
---@param evaluate fun(text: string): any
---@return string? now
---@return boolean hasCommands
---@return string? unit
local function Now(parsed, evaluate)
	local hasCommands = false
	if type(parsed) ~= "table" then
		return nil, hasCommands, nil
	end
	for _, line in ipairs(parsed.lines) do
		local isCommand = line.kind == "command" and line.command and line.command.name ~= ""
		if isCommand then
			hasCommands = true
			local entry = ns.CommandAliases[line.command.nameLower]
			if entry and SafeToEvaluate(line) and type(evaluate) == "function" then
				local args = line.text:sub(line.command.to - line.from + 2):gsub("^%s+", "")
				if args ~= "" then
					local result = evaluate(args)
					if type(result) == "string" and result ~= "" then
						local unit
						for _, clause in ipairs(line.clauses) do
							local clauseText = line.text:sub(clause.from - line.from + 1, clause.to - line.from + 1)
							if evaluate(clauseText) ~= nil then
								-- The first group that matches decides; its unit counts only when it names one.
								for _, group in ipairs(clause.groups) do
									if evaluate(GroupText(line, group) .. " 1") == "1" then
										if group.unit and group.unit.token ~= "" then
											unit = group.unit.token
										end
										break
									end
								end
								break
							end
						end
						result = result:gsub("^%s*!", "")
						return result, hasCommands, unit
					end
				end
			end
		end
	end
	return nil, hasCommands, nil
end

ns.Now = Now
