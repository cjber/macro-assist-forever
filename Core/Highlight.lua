local _, ns = ...

if ns.broken then
	return
end

-- Colour-coded text for one parsed macro line. The editor's EditBox draws the real text transparent and an
-- overlay FontString draws this string with the same font and width; colour codes therefore never enter the
-- EditBox, where they would count against its 255 letters. Every literal `|` in the macro is doubled, so the
-- overlay shows exactly what the player typed.

local TEXT = "|cffffffff"
local CODE = "|cff9d9d9d"
local CONDITION = "|cffffd100"
local UNIT = "|cff69ccf0"
local PARAM = "|cff1eff00"
local CLOSE = "|r"

---@param colours string[]
---@param length integer
---@param from integer?
---@param to integer?
---@param colour string
local function Paint(colours, length, from, to, colour)
	if not from or not to or to < from then
		return
	end
	if from < 1 then
		from = 1
	end
	if to > length then
		to = length
	end
	for position = from, to do
		colours[position] = colour
	end
end

---@param line MacroAssistLine
---@return string
local function Line(line)
	local length = #line.text
	if length == 0 then
		return ""
	end
	local colours = {}
	for position = 1, length do
		colours[position] = TEXT
	end

	-- The leading bang and the command are code, and so is a directive's `#name`.
	if line.bangFrom then
		Paint(colours, length, line.bangFrom - line.from + 1, line.bangTo - line.from + 1, CODE)
	end
	if line.command then
		Paint(colours, length, line.command.from - line.from + 1, line.command.to - line.from + 1, CODE)
	end
	if line.directiveFrom then
		Paint(colours, length, line.directiveFrom - line.from + 1, line.directiveTo - line.from + 1, CODE)
	end

	for _, clause in ipairs(line.clauses) do
		for _, group in ipairs(clause.groups) do
			Paint(colours, length, group.from - line.from + 1, group.to - line.from + 1, CONDITION)
			if group.unit then
				Paint(colours, length, group.unit.from - line.from + 1, group.unit.to - line.from + 1, UNIT)
			end
			for _, condition in ipairs(group.conditions) do
				Paint(colours, length, condition.from - line.from + 1, condition.to - line.from + 1, CONDITION)
				Paint(
					colours,
					length,
					condition.paramFrom and (condition.paramFrom - line.from + 1) or nil,
					condition.paramTo and (condition.paramTo - line.from + 1) or nil,
					PARAM
				)
				for _, alternative in ipairs(condition.alternatives or {}) do
					Paint(colours, length, alternative.from - line.from + 1, alternative.to - line.from + 1, PARAM)
				end
			end
		end
		if clause.args then
			for _, item in ipairs(clause.args.items) do
				if item.bangFrom then
					Paint(colours, length, item.bangFrom - line.from + 1, item.bangTo - line.from + 1, CODE)
				end
				if item.resetFrom then
					Paint(colours, length, item.resetFrom - line.from + 1, item.resetTo - line.from + 1, PARAM)
				end
				if item.rankFrom then
					Paint(colours, length, item.rankFrom - line.from + 1, item.rankTo - line.from + 1, PARAM)
				end
			end
		end
		if clause.semicolon then
			Paint(colours, length, clause.semicolon - line.from + 1, clause.semicolon - line.from + 1, CODE)
		end
	end

	local out = {}
	local run
	local runFrom = 1
	for position = 1, length + 1 do
		local colour = position <= length and colours[position] or nil
		if colour ~= run then
			if run then
				local raw = line.text:sub(runFrom, position - 1):gsub("|", "||")
				out[#out + 1] = run
				out[#out + 1] = raw
				out[#out + 1] = CLOSE
			end
			run = colour
			runFrom = position
		end
	end
	return table.concat(out)
end

ns.Highlight = { Line = Line }
