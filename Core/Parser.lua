local _, ns = ...

if ns.broken then
	return
end

-- Parse a macro body into lines, clauses, condition groups and argument items, with byte offsets for every token.
-- The parser is syntax only: it does not know which commands or conditions exist, so a malformed line still produces
-- nodes plus diagnostics instead of an error.

local L = ns.L

---@param text string
---@param from integer
---@param to integer
---@return string
local function Slice(text, from, to)
	if from > to then
		return ""
	end
	return text:sub(from, to)
end

local IsSpaceByte = ns.Lexer.IsSpace

---@param text string
---@param from integer
---@param to integer
---@return integer from
---@return integer to
local function TrimRange(text, from, to)
	while from <= to and IsSpaceByte(text:byte(from)) do
		from = from + 1
	end
	while to >= from and IsSpaceByte(text:byte(to)) do
		to = to - 1
	end
	return from, to
end

---@param tokens MacroAssistToken[]
---@param base integer
---@return MacroAssistToken[]
local function Shift(tokens, base)
	for _, token in ipairs(tokens) do
		token.from = token.from + base
		token.to = token.to + base
	end
	return tokens
end

---@param tokens MacroAssistToken[]
---@param index integer
---@return integer
local function SkipSpace(tokens, index)
	while tokens[index] and tokens[index].kind == "space" do
		index = index + 1
	end
	return index
end

---@param line MacroAssistLine
---@param code string
---@param from integer
---@param to integer
---@param message string
local function Diagnose(line, code, from, to, message)
	line.diagnostics[#line.diagnostics + 1] = {
		from = from,
		to = to,
		severity = "warning",
		code = code,
		message = message,
	}
end

---@param condition MacroAssistConditionNode
---@return string
local function ConditionKey(condition)
	local parameter = ""
	if condition.param then
		local alternatives = {}
		for alternative in condition.param:lower():gmatch("[^/]+") do
			alternatives[#alternatives + 1] = alternative
		end
		table.sort(alternatives)
		parameter = ":" .. table.concat(alternatives, "/")
	end
	return (condition.no and "no:" or "") .. condition.name .. parameter
end

---@param clause MacroAssistClause
---@return string
local function ClauseKey(clause)
	local groups = {}
	for _, group in ipairs(clause.groups) do
		local conditions = {}
		for _, condition in ipairs(group.conditions) do
			conditions[#conditions + 1] = ConditionKey(condition)
		end
		table.sort(conditions)
		local unit = group.unit and ("unit=" .. group.unit.token) or ""
		groups[#groups + 1] = unit .. "[" .. table.concat(conditions, ",") .. "]"
	end
	table.sort(groups)
	return table.concat(groups, "|")
end

-- `Spell(Rank N)` at the end of a name. Returns the end of the bare name, the rank and the rank's byte range.
---@param text string
---@param from integer
---@param to integer
---@return integer nameTo
---@return integer? rank
---@return integer? rankFrom
---@return integer? rankTo
local function ParseRank(text, from, to)
	local raw = text:sub(from, to)
	local openAt = raw:match(".*()%(")
	if not openAt then
		return to
	end
	local inner = raw:sub(openAt + 1)
	local close = inner:match("%)%s*$")
	if not close then
		return to
	end
	local body = inner:sub(1, #inner - #close)
	local digits = body:match("^%s*[Rr][Aa][Nn][Kk]%s+(%d+)%s*$")
	if not digits then
		return to
	end
	local digitAt = body:find(digits, 1, true)
	local rankFrom = from + openAt + digitAt - 1
	local rankTo = rankFrom + #digits - 1
	local nameTo = from + openAt - 2
	while nameTo >= from and IsSpaceByte(text:byte(nameTo)) do
		nameTo = nameTo - 1
	end
	return nameTo, tonumber(digits), rankFrom, rankTo
end

-- One comma-separated argument. `reset=` is stripped first (castsequence), then a leading `!` (toggle prevention),
-- then a trailing `(Rank N)`.
---@param text string
---@param from integer
---@param to integer
---@return MacroAssistItem
local function ParseItem(text, from, to)
	---@type MacroAssistItem
	local item = { text = Slice(text, from, to), from = from, to = to, name = "" }
	if from > to then
		return item
	end
	if text:sub(from, from + 5):lower() == "reset=" then
		item.reset = true
		item.resetFrom = from
		local valueFrom = from + 6
		local valueTo = valueFrom - 1
		local position = valueFrom
		while position <= to and not IsSpaceByte(text:byte(position)) do
			valueTo = position
			position = position + 1
		end
		item.resetTo = valueTo
		item.resetValues = {}
		for part in Slice(text, valueFrom, valueTo):gmatch("[^/]+") do
			item.resetValues[#item.resetValues + 1] = part
		end
		from = position
		from, to = TrimRange(text, from, to)
		if from > to then
			item.name = ""
			return item
		end
	end
	if text:sub(from, from) == "!" then
		item.bang = true
		item.bangFrom = from
		item.bangTo = from
		from = from + 1
		from, to = TrimRange(text, from, to)
	end
	item.nameFrom = from
	item.nameTo = to
	if from > to then
		item.name = ""
		return item
	end
	local nameTo, rank, rankFrom, rankTo = ParseRank(text, from, to)
	item.nameTo = nameTo
	item.name = Slice(text, from, nameTo)
	item.rank = rank
	item.rankFrom = rankFrom
	item.rankTo = rankTo
	return item
end

---@param text string
---@param from integer
---@param to integer
---@return MacroAssistItem[]
local function ParseItems(text, from, to)
	local items = {}
	local start = from
	for position = from, to + 1 do
		if position > to or text:byte(position) == 44 then
			local itemFrom, itemTo = TrimRange(text, start, position - 1)
			if itemFrom <= itemTo then
				items[#items + 1] = ParseItem(text, itemFrom, itemTo)
			end
			start = position + 1
		end
	end
	return items
end

---@param tokens MacroAssistToken[]
---@param index integer
---@param line MacroAssistLine
---@param text string
---@return MacroAssistGroup group
---@return integer index
local function ParseGroup(tokens, index, line, text)
	local open = tokens[index]
	---@type MacroAssistGroup
	local group = { from = open.from, to = open.to, closed = false, conditions = {} }
	index = index + 1
	while tokens[index] and tokens[index].kind ~= "rbracket" do
		index = SkipSpace(tokens, index)
		local token = tokens[index]
		if not token or token.kind == "rbracket" then
			break
		end
		if token.kind == "comma" then
			index = index + 1
		elseif token.kind == "at" then
			index = SkipSpace(tokens, index + 1)
			local word = tokens[index]
			if word and word.kind == "word" then
				group.unit = {
					kind = "at",
					token = word.text:lower(),
					from = token.from,
					to = word.to,
					tokenFrom = word.from,
					tokenTo = word.to,
				}
				index = index + 1
			else
				group.unit = {
					kind = "at",
					token = "",
					from = token.from,
					to = token.to,
					tokenFrom = token.to + 1,
					tokenTo = token.to,
				}
			end
		elseif token.kind == "word" then
			local nextIndex = SkipSpace(tokens, index + 1)
			if token.text:lower() == "target" and tokens[nextIndex] and tokens[nextIndex].kind == "equals" then
				local equals = tokens[nextIndex]
				local unitIndex = SkipSpace(tokens, nextIndex + 1)
				local unit = tokens[unitIndex]
				if unit and unit.kind == "word" then
					group.unit = {
						kind = "target",
						token = unit.text:lower(),
						from = token.from,
						to = unit.to,
						tokenFrom = unit.from,
						tokenTo = unit.to,
					}
					index = unitIndex + 1
				else
					group.unit = {
						kind = "target",
						token = "",
						from = token.from,
						to = equals.to,
						tokenFrom = equals.to + 1,
						tokenTo = equals.to,
					}
					index = nextIndex + 1
				end
			else
				---@type MacroAssistConditionNode
				local condition = {
					text = token.text,
					rawName = token.text,
					from = token.from,
					to = token.to,
					nameFrom = token.from,
					nameTo = token.to,
					name = token.text:lower(),
					no = false,
				}
				if #condition.name > 2 and condition.name:sub(1, 2) == "no" then
					condition.no = true
					condition.name = condition.name:sub(3)
					condition.nameFrom = token.from + 2
				end
				index = index + 1
				local colonIndex = SkipSpace(tokens, index)
				if tokens[colonIndex] and tokens[colonIndex].kind == "colon" then
					condition.hasColon = true
					condition.colonFrom = tokens[colonIndex].from
					condition.colonTo = tokens[colonIndex].to
					index = colonIndex + 1
					local alternatives = {}
					local alternativeFrom
					local alternativeTo
					while tokens[index] and tokens[index].kind ~= "comma" and tokens[index].kind ~= "rbracket" do
						local part = tokens[index]
						if part.kind == "slash" then
							if alternativeFrom and alternativeTo then
								alternatives[#alternatives + 1] = {
									from = alternativeFrom,
									to = alternativeTo,
									text = Slice(text, alternativeFrom, alternativeTo),
								}
							end
							alternativeFrom = nil
							alternativeTo = nil
						elseif part.kind ~= "space" then
							alternativeFrom = alternativeFrom or part.from
							alternativeTo = part.to
							condition.paramFrom = condition.paramFrom or part.from
							condition.paramTo = part.to
						end
						index = index + 1
					end
					if alternativeFrom and alternativeTo then
						alternatives[#alternatives + 1] = {
							from = alternativeFrom,
							to = alternativeTo,
							text = Slice(text, alternativeFrom, alternativeTo),
						}
					end
					condition.alternatives = alternatives
					if condition.paramFrom then
						condition.param = Slice(text, condition.paramFrom, condition.paramTo)
					else
						condition.param = ""
					end
				end
				group.conditions[#group.conditions + 1] = condition
			end
		else
			Diagnose(line, "unexpected-token", token.from, token.to, L["Unexpected character in a condition."])
			index = index + 1
		end
	end
	if tokens[index] and tokens[index].kind == "rbracket" then
		group.closed = true
		group.to = tokens[index].to
		index = index + 1
	else
		group.to = line.to
		Diagnose(line, "unclosed-bracket", group.from, group.to, L["A condition is missing its closing bracket."])
	end
	return group, index
end

---@param line MacroAssistLine
---@param tokens MacroAssistToken[]
---@param index integer
---@param text string
---@param single boolean? true for a directive, whose rest is one argument even if it contains a semicolon
---@return MacroAssistClause clause
---@return integer index
local function ParseClause(line, tokens, index, text, single)
	---@type MacroAssistClause
	local clause = { groups = {}, conditions = {}, from = 0, to = -1, unconditional = false, key = "" }
	local start = SkipSpace(tokens, index)
	index = start
	local firstFrom
	local lastTo
	while tokens[index] and tokens[index].kind == "lbracket" do
		local group
		group, index = ParseGroup(tokens, index, line, text)
		clause.groups[#clause.groups + 1] = group
		for _, condition in ipairs(group.conditions) do
			clause.conditions[#clause.conditions + 1] = condition
		end
		firstFrom = firstFrom or group.from
		lastTo = group.to
		index = SkipSpace(tokens, index)
	end
	local argsFrom
	local argsTo
	local run = index
	while tokens[run] and (single or tokens[run].kind ~= "semicolon") do
		if tokens[run].kind ~= "space" then
			argsFrom = argsFrom or tokens[run].from
			argsTo = tokens[run].to
		end
		run = run + 1
	end
	if argsFrom then
		clause.args = {
			text = Slice(text, argsFrom, argsTo),
			from = argsFrom,
			to = argsTo,
			items = ParseItems(text, argsFrom, argsTo),
		}
		firstFrom = firstFrom or argsFrom
		lastTo = argsTo
	end
	if not single and tokens[run] and tokens[run].kind == "semicolon" then
		clause.semicolon = tokens[run].to
		run = run + 1
	end
	local firstToken = tokens[start]
	clause.from = firstFrom or (firstToken and firstToken.from) or (line.to + 1)
	clause.to = lastTo or (clause.from - 1)
	clause.unconditional = #clause.groups == 0
	for _, group in ipairs(clause.groups) do
		if #group.conditions == 0 then
			clause.unconditional = true
		end
	end
	clause.key = ClauseKey(clause)
	return clause, run
end

---@param text string
---@param line MacroAssistLine
local function ParseLine(text, line)
	local tokens = Shift(ns.Lexer.Tokens(line.text), line.from - 1)
	line.tokens = tokens
	local index = SkipSpace(tokens, 1)
	if not tokens[index] then
		line.kind = "empty"
		line.clauses = {}
		return
	end
	if tokens[index].kind == "hash" then
		line.kind = "directive"
		local hash = tokens[index]
		line.directiveFrom = hash.from
		local word = tokens[index + 1]
		if word and word.kind == "word" then
			line.directive = word.text:lower()
			line.directiveTo = word.to
			index = index + 2
		else
			line.directive = ""
			line.directiveTo = hash.to
			index = index + 1
		end
		if tokens[index] then
			local clause = ParseClause(line, tokens, index, text, true)
			if clause then
				line.clauses[#line.clauses + 1] = clause
			end
		end
		return
	end
	local bang = false
	if tokens[index].kind == "bang" then
		bang = true
		line.bangFrom = tokens[index].from
		line.bangTo = tokens[index].to
		index = index + 1
	end
	if tokens[index] and tokens[index].kind == "slash" then
		line.kind = "command"
		line.bang = bang
		local slash = tokens[index]
		local nameIndex = SkipSpace(tokens, index + 1)
		local word = tokens[nameIndex]
		if word and word.kind == "word" then
			line.command = {
				name = word.text,
				nameLower = word.text:lower(),
				from = slash.from,
				to = word.to,
				nameFrom = word.from,
				nameTo = word.to,
			}
			index = nameIndex + 1
		else
			line.command = {
				name = "",
				nameLower = "",
				from = slash.from,
				to = slash.to,
				nameFrom = slash.to + 1,
				nameTo = slash.to,
			}
			index = nameIndex
		end
		while tokens[index] do
			local clause
			clause, index = ParseClause(line, tokens, index, text, false)
			if clause then
				line.clauses[#line.clauses + 1] = clause
			end
		end
		return
	end
	line.kind = "text"
	local clause = ParseClause(line, tokens, index, text, true)
	if clause then
		line.clauses[#line.clauses + 1] = clause
	end
end

---@class MacroAssistUnitNode
---@field kind "at"|"target"
---@field token string the lower-case unit token
---@field from integer
---@field to integer
---@field tokenFrom integer
---@field tokenTo integer

---@class MacroAssistConditionNode
---@field text string the condition as typed
---@field from integer
---@field to integer
---@field rawName string the typed word, including a `no` prefix
---@field name string the lower-case name after a `no` prefix
---@field nameFrom integer
---@field nameTo integer
---@field no boolean
---@field hasColon boolean?
---@field colonFrom integer?
---@field colonTo integer?
---@field param string? the parameter text, including `/` alternatives
---@field paramFrom integer?
---@field paramTo integer?
---@field alternatives MacroAssistAlternative[]?

---@class MacroAssistAlternative
---@field text string
---@field from integer
---@field to integer

---@class MacroAssistGroup
---@field from integer
---@field to integer
---@field closed boolean
---@field conditions MacroAssistConditionNode[]
---@field unit MacroAssistUnitNode?

---@class MacroAssistItem
---@field text string
---@field from integer
---@field to integer
---@field name string the spell or item name without `!`, `reset=` and `(Rank N)`
---@field nameFrom integer?
---@field nameTo integer?
---@field bang boolean?
---@field bangFrom integer?
---@field bangTo integer?
---@field rank integer?
---@field rankFrom integer?
---@field rankTo integer?
---@field reset boolean?
---@field resetFrom integer?
---@field resetTo integer?
---@field resetValues string[]?

---@class MacroAssistArgs
---@field text string
---@field from integer
---@field to integer
---@field items MacroAssistItem[]

---@class MacroAssistClause
---@field from integer
---@field to integer
---@field groups MacroAssistGroup[]
---@field conditions MacroAssistConditionNode[]
---@field unit MacroAssistUnitNode?
---@field args MacroAssistArgs?
---@field unconditional boolean
---@field key string
---@field semicolon integer?

---@class MacroAssistCommandNode
---@field name string
---@field nameLower string
---@field from integer
---@field to integer
---@field nameFrom integer
---@field nameTo integer

---@class MacroAssistDiagnostic
---@field from integer
---@field to integer
---@field severity string
---@field code string
---@field message string
---@field fix? table

---@class MacroAssistLine
---@field text string
---@field from integer
---@field to integer
---@field kind string empty, directive, command or text
---@field bang boolean?
---@field bangFrom integer?
---@field bangTo integer?
---@field command MacroAssistCommandNode?
---@field directive string?
---@field directiveFrom integer?
---@field directiveTo integer?
---@field clauses MacroAssistClause[]
---@field tokens MacroAssistToken[]
---@field diagnostics MacroAssistDiagnostic[]

---@class MacroAssistParse
---@field text string
---@field lines MacroAssistLine[]
---@field diagnostics MacroAssistDiagnostic[]

---@param body string
---@return MacroAssistParse
local function Parse(body)
	if type(body) ~= "string" then
		body = ""
	end
	---@type MacroAssistParse
	local parsed = { text = body, lines = {}, diagnostics = {} }
	local from = 1
	while true do
		local newline = body:find("\n", from, true)
		local lineTo = (newline or (#body + 1)) - 1
		---@type MacroAssistLine
		local line = {
			text = body:sub(from, lineTo),
			from = from,
			to = lineTo,
			kind = "empty",
			clauses = {},
			tokens = {},
			diagnostics = {},
		}
		ParseLine(body, line)
		parsed.lines[#parsed.lines + 1] = line
		for _, diagnostic in ipairs(line.diagnostics) do
			parsed.diagnostics[#parsed.diagnostics + 1] = diagnostic
		end
		if not newline then
			break
		end
		from = newline + 1
	end
	return parsed
end

---@class MacroAssistParser
---@field Parse fun(body: string): MacroAssistParse
---@type MacroAssistParser
ns.Parser = { Parse = Parse }
