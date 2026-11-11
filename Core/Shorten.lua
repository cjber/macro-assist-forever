local _, ns = ...

if ns.broken then
	return
end

-- Lossless rewrites for a macro over the 255-character limit. Every rewrite comes from the parse tree or from the
-- command data, never from a guess about the words:
--
--   * line ends and the spaces between a command, its conditions and its arguments are trimmed, while spaces inside a
--     spell or item name and inside a condition's parameter stay exactly as typed;
--   * a command is written with its shortest known alias, from the same Data/Commands.lua entry, so /spell becomes
--     /cast and /use stays /use;
--   * clauses the checker reports as unreachable are dropped, and an empty trailing clause is collapsed.
--
-- The result is the best single rewrite: applying all three is lossless and saves at least as much as any one alone.

local function Trim(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
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

-- The byte ranges the checker called unreachable in this text. Core/Check.lua owns that rule, so Shorten never keeps a
-- second copy of it: it asks the checker and drops exactly the clauses it names.
---@param text string
---@return table<string, boolean>
local function Unreachable(text)
	local ranges = {}
	for _, diagnostic in ipairs(ns.Check(text)) do
		if diagnostic.code == "unreachable-clause" then
			ranges[diagnostic.from .. ":" .. diagnostic.to] = true
		end
	end
	return ranges
end

-- Whitespace between a group's brackets, conditions and commas carries no meaning; whitespace inside a condition
-- parameter does, as in [channeling:Mind Flay], so it is left alone.
---@param text string
---@param group MacroAssistGroup
---@return string
local function GroupText(text, group)
	local raw = text:sub(group.from, group.to)
	raw = raw:gsub("^%[%s*", "[")
	raw = raw:gsub("%s*%]$", "]")
	raw = raw:gsub("%s*,%s*", ",")
	return raw
end

-- The items of a clause, joined at the comma the macro syntax uses. Each item keeps its own text, including the spaces
-- in a spell name and the reset= prefix of a castsequence item.
---@param args MacroAssistArgs
---@return string
local function ArgsText(args)
	local parts = {}
	for _, item in ipairs(args.items) do
		parts[#parts + 1] = item.text
	end
	return table.concat(parts, ",")
end

---@param text string
---@param clause MacroAssistClause
---@return string
local function ClauseText(text, clause)
	local groups = {}
	for _, group in ipairs(clause.groups) do
		groups[#groups + 1] = GroupText(text, group)
	end
	local conditions = table.concat(groups)
	local args = clause.args and ArgsText(clause.args) or ""
	if conditions ~= "" and args ~= "" then
		return conditions .. " " .. args
	end
	return conditions ~= "" and conditions or args
end

-- The shortest alias of the command the line names, from the same entry the parser checked. A command with no shorter
-- alias keeps the text as typed, case included.
---@param line MacroAssistLine
---@return string
local function CommandName(line)
	local name = line.command.name
	local entry = ns.CommandAliases[line.command.nameLower]
	if not entry or not entry.aliases[1] then
		return name
	end
	local best = entry.aliases[1]
	for index = 2, #entry.aliases do
		if #entry.aliases[index] < #best then
			best = entry.aliases[index]
		end
	end
	if #best < #name then
		return best
	end
	return name
end

---@param text string
---@param line MacroAssistLine
---@param unreachable table<string, boolean>
---@return string
local function LineText(text, line, unreachable)
	if line.kind == "empty" then
		return ""
	end
	if line.kind == "text" then
		return Trim(text:sub(line.from, line.to))
	end
	local prefix
	if line.kind == "directive" then
		prefix = text:sub(line.directiveFrom, line.directiveTo)
	else
		prefix = (line.bang and "!" or "") .. "/" .. CommandName(line)
	end
	local clauses = {}
	for _, clause in ipairs(line.clauses) do
		local from, to = ClauseRange(clause)
		if not unreachable[from .. ":" .. to] then
			clauses[#clauses + 1] = ClauseText(text, clause)
		end
	end
	while #clauses > 0 and clauses[#clauses] == "" do
		clauses[#clauses] = nil
	end
	if #clauses == 0 then
		return prefix
	end
	return prefix .. " " .. table.concat(clauses, ";")
end

---@class MacroAssistShortenResult
---@field text string the rewritten macro
---@field saved integer characters saved, never negative

---@param text string
---@return MacroAssistShortenResult
local function Shorten(text)
	if type(text) ~= "string" or text == "" then
		return { text = text or "", saved = 0 }
	end
	local parsed = ns.Parser.Parse(text)
	local unreachable = Unreachable(text)
	local lines = {}
	for _, line in ipairs(parsed.lines) do
		lines[#lines + 1] = LineText(text, line, unreachable)
	end
	local result = table.concat(lines, "\n")
	local saved = ns.Length(text) - ns.Length(result)
	if saved < 0 then
		saved = 0
	end
	return { text = result, saved = saved }
end

ns.Shorten = Shorten
