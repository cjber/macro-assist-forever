local _, ns = ...

-- Diagnostics for a macro body. Everything the client knows (spells, items, live condition values) arrives in `ctx`;
-- the command and condition tables are this addon's own data. The result is sorted by byte offset so a caller can
-- underline it without sorting again.
--
-- ctx.spells has the same shape as Core/Complete.lua documents. ctx.items is an optional list or map of item names, so
-- a /cast line that uses an item instead of a spell is not reported as an unknown spell.

local L = ns.L

---@param diagnostics MacroAssistDiagnostic[]
---@param from integer
---@param to integer
---@param severity string
---@param code string
---@param message string
---@param fix table?
local function Add(diagnostics, from, to, severity, code, message, fix)
	diagnostics[#diagnostics + 1] = {
		from = from,
		to = to,
		severity = severity,
		code = code,
		message = message,
		fix = fix,
	}
end

---@param spells table?
---@return table<string, { name: string, learned: boolean, ranks: table<any, boolean>? }>?
local function SpellIndex(spells)
	if type(spells) ~= "table" then
		return nil
	end
	local index = {}
	for _, value in ipairs(spells) do
		if type(value) == "string" then
			index[value:lower()] = { name = value, learned = true }
		elseif type(value) == "table" and type(value.name) == "string" then
			local ranks = value.ranks
			if type(ranks) ~= "table" then
				ranks = value.rank and { value.rank } or nil
			end
			local rankSet
			if ranks then
				rankSet = {}
				for _, rank in ipairs(ranks) do
					rankSet[tonumber(rank) or rank] = true
				end
			end
			index[value.name:lower()] = {
				name = value.name,
				learned = value.learned ~= false,
				ranks = rankSet,
			}
		end
	end
	return index
end

---@param items table?
---@return table<string, boolean>?
local function ItemIndex(items)
	if type(items) ~= "table" then
		return nil
	end
	local index = {}
	for key, value in pairs(items) do
		if type(key) == "string" then
			index[key:lower()] = true
		end
		if type(value) == "string" then
			index[value:lower()] = true
		elseif type(value) == "table" and type(value.name) == "string" then
			index[value.name:lower()] = true
		end
	end
	return index
end

-- The command a mistyped name was probably meant to be: exactly one command has an alias that starts with the typed
-- text. Anything less certain gets no fix.
---@param typed string
---@return string?
local function UniqueAlias(typed)
	if typed == "" then
		return nil
	end
	local best = {}
	for alias, entry in pairs(ns.CommandAliases) do
		if #alias > #typed and alias:sub(1, #typed) == typed then
			local current = best[entry]
			if not current or #alias < #current or (#alias == #current and alias < current) then
				best[entry] = alias
			end
		end
	end
	local count, only = 0, nil
	for entry in pairs(best) do
		count = count + 1
		only = entry
	end
	if count ~= 1 then
		return nil
	end
	return best[only]
end

---@param condition MacroAssistConditionNode
---@param diagnostics MacroAssistDiagnostic[]
local function CheckCondition(condition, diagnostics)
	local entry = ns.ConditionAliases[condition.rawName:lower()]
	local noForm = false
	if not entry and condition.no then
		entry = ns.ConditionAliases[condition.name]
		noForm = entry ~= nil
	end
	if not entry then
		Add(
			diagnostics,
			condition.nameFrom,
			condition.nameTo,
			"error",
			"unknown-condition",
			L["Unknown condition: %s."]:format(condition.rawName)
		)
		return
	end
	if entry.forever == false then
		local name = noForm and ("no" .. entry.name) or entry.name
		Add(
			diagnostics,
			condition.from,
			condition.to,
			"warning",
			"never-on-forever",
			noForm and L["[%s] is always true on WoW: Forever."]:format(name)
				or L["[%s] is never true on WoW: Forever."]:format(name)
		)
	end
	if entry.param == "none" then
		if condition.hasColon then
			Add(
				diagnostics,
				condition.colonFrom or condition.from,
				condition.paramTo or condition.colonTo or condition.to,
				"error",
				"condition-unexpected-parameter",
				L["%s does not take a parameter."]:format(entry.name)
			)
		end
		return
	end
	local hasValue = condition.param ~= nil and condition.param ~= ""
	if not hasValue and (entry.param == "required" or condition.hasColon) then
		Add(
			diagnostics,
			condition.from,
			condition.to,
			"error",
			"condition-missing-parameter",
			L["%s needs a parameter, e.g. %s."]:format(entry.name, entry.form or entry.name)
		)
	end
end

---@param entry MacroAssistCommand
---@return boolean
local function TakesSpells(entry)
	return entry.list == true or entry.name == "cast"
end

---@param item MacroAssistItem
---@param spells table<string, { name: string, learned: boolean, ranks: table<any, boolean>? }>
---@param items table<string, boolean>?
---@param diagnostics MacroAssistDiagnostic[]
local function CheckSpell(item, spells, items, diagnostics)
	if not item.name or item.name == "" then
		return
	end
	if items and items[item.name:lower()] then
		return
	end
	if item.name:match("^%d+$") or item.name:match("^%d+%s+%d+$") then
		return
	end
	local spell = spells[item.name:lower()]
	if not spell or not spell.learned then
		Add(
			diagnostics,
			item.nameFrom or item.from,
			item.nameTo or item.to,
			"error",
			"unknown-spell",
			L["Spell not in your spellbook: %s."]:format(item.name)
		)
		return
	end
	if item.rank and spell.ranks and not spell.ranks[item.rank] then
		Add(
			diagnostics,
			item.rankFrom or item.from,
			item.rankTo or item.to,
			"error",
			"unknown-rank",
			L["%s has no rank %d."]:format(item.name, item.rank)
		)
	end
end

---@param clause MacroAssistClause
---@return integer from
---@return integer to
local function ClauseRange(clause)
	if clause.groups[1] then
		return clause.groups[1].from, clause.groups[1].to
	end
	if clause.args then
		return clause.args.from, clause.args.to
	end
	return clause.from, clause.to
end

---@param line MacroAssistLine
---@param diagnostics MacroAssistDiagnostic[]
local function CheckClauses(line, diagnostics)
	local seen = {}
	local unconditional = false
	for index, clause in ipairs(line.clauses) do
		local empty = #clause.groups == 0 and not clause.args
		if index > 1 and not empty then
			local from, to = ClauseRange(clause)
			if unconditional then
				Add(
					diagnostics,
					from,
					to,
					"warning",
					"unreachable-clause",
					L["This clause can never run: an earlier clause always matches."]
				)
			elseif seen[clause.key] then
				Add(
					diagnostics,
					from,
					to,
					"warning",
					"unreachable-clause",
					L["This clause can never run: its conditions repeat an earlier clause."]
				)
			end
		end
		if not empty then
			seen[clause.key] = true
			if clause.unconditional then
				unconditional = true
			end
		end
	end
end

---@param parsed MacroAssistParse
---@param diagnostics MacroAssistDiagnostic[]
local function CheckEmptyLines(parsed, diagnostics)
	for index, line in ipairs(parsed.lines) do
		if line.kind == "empty" then
			local later = false
			for nextIndex = index + 1, #parsed.lines do
				if parsed.lines[nextIndex].kind ~= "empty" then
					later = true
					break
				end
			end
			if later then
				local from = line.from
				local to = line.to
				if to < from then
					to = from
				end
				Add(diagnostics, from, to, "warning", "empty-line", L["Empty line in the middle of the macro."])
			end
		end
	end
end

---@class MacroAssistCheckContext
---@field spells table?
---@field items table?
---@field evaluate? fun(condition: any): any

---@param text string
---@param ctx MacroAssistCheckContext?
---@return MacroAssistDiagnostic[]
local function Check(text, ctx)
	if type(text) ~= "string" then
		text = ""
	end
	if type(ctx) ~= "table" then
		ctx = {}
	end
	local parsed = ns.Parser.Parse(text)
	---@type MacroAssistDiagnostic[]
	local diagnostics = {}
	for _, diagnostic in ipairs(parsed.diagnostics) do
		diagnostics[#diagnostics + 1] = diagnostic
	end
	local spells = SpellIndex(ctx.spells)
	local items = ItemIndex(ctx.items)

	for _, line in ipairs(parsed.lines) do
		local entry = line.command and ns.CommandAliases[line.command.nameLower]
		if line.kind == "command" and line.command and line.command.nameLower ~= "" and not entry then
			local fix
			local alias = UniqueAlias(line.command.nameLower)
			if alias then
				fix = { from = line.command.from, to = line.command.to, insert = "/" .. alias }
			end
			Add(
				diagnostics,
				line.command.from,
				line.command.to,
				"error",
				"unknown-command",
				L["Unknown command /%s."]:format(line.command.name),
				fix
			)
		end
		for _, clause in ipairs(line.clauses) do
			for _, condition in ipairs(clause.conditions) do
				CheckCondition(condition, diagnostics)
			end
			if entry and not entry.conditions then
				for _, group in ipairs(clause.groups) do
					if #group.conditions > 0 then
						Add(
							diagnostics,
							group.from,
							group.to,
							"warning",
							"conditions-ignored",
							L["/%s ignores conditions."]:format(entry.name)
						)
						break
					end
				end
			end
			if entry and TakesSpells(entry) and spells and clause.args then
				for _, item in ipairs(clause.args.items) do
					CheckSpell(item, spells, items, diagnostics)
				end
			end
		end
		if line.kind == "command" then
			CheckClauses(line, diagnostics)
		end
	end

	CheckEmptyLines(parsed, diagnostics)

	local length = ns.Length(text)
	if length > ns.MacroLimit then
		Add(
			diagnostics,
			ns.FirstOver(text, ns.MacroLimit),
			#text,
			"error",
			"too-long",
			L["Macro is %d characters; the limit is %d."]:format(length, ns.MacroLimit)
		)
	end

	table.sort(diagnostics, function(left, right)
		if left.from ~= right.from then
			return left.from < right.from
		end
		if left.to ~= right.to then
			return left.to < right.to
		end
		return left.code < right.code
	end)
	return diagnostics
end

ns.Check = Check
