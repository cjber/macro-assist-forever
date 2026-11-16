local _, ns = ...

if ns.broken then
	return
end

-- Completion for the macro editor. `Complete(text, cursor, ctx)` looks only at the text before the caret, so it can
-- be called from OnTextChanged without touching the client. `cursor` is a byte offset into `text`, the same convention
-- as string.sub: the text before the caret is text:sub(1, cursor - 1). The answer is `{ from, to, items }`, where
-- replacing bytes from..to with an item's `insert` makes the edit. `from` may be cursor and `to` cursor - 1 for an
-- insertion at the caret.
--
-- ctx.spells is an array of `{ name = "Flash Heal", ranks = { 1, 3, 7 }, learned = true }`; a bare string is a learned
-- spell, and learned defaults to true. ctx.evaluate(condition) returns a live value for a condition's detail.

local L = ns.L

local IsSpaceByte = ns.Lexer.IsSpace

---@param typed string
---@param label string
---@return integer?
local function Match(typed, label)
	if typed == "" then
		return 1
	end
	local wanted = typed:lower()
	local text = label:lower()
	if wanted:sub(1, 1) ~= "/" and wanted:sub(1, 1) ~= "#" then
		if text:sub(1, 1) == "/" or text:sub(1, 1) == "#" then
			text = text:sub(2)
		end
	end
	if text:sub(1, #wanted) == wanted then
		return 1
	end
	if text:find(wanted, 1, true) then
		return 2
	end
end

---@class MacroAssistCompletion
---@field from integer
---@field to integer
---@field items MacroAssistCompletionItem[]

---@class MacroAssistCompletionItem
---@field label string
---@field insert string
---@field kind string secure, command, chat, emote, condition, unit, member, spell, directive, recipe or value
---@field detail string
---@field live string? the condition's live value, when one was asked for

---@param items MacroAssistCompletionItem[]
---@param seen table<string, boolean>
---@param from integer
---@param to integer
---@param typed string
---@param kind string
---@param detail string
---@param rankOffset integer? pushes the item after the items without it
---@param live string? the condition's live value
local function Add(items, seen, from, to, typed, label, insert, kind, detail, rankOffset, live)
	local rank = Match(typed, label)
	if not rank or seen[insert] then
		return
	end
	rank = rank + (rankOffset or 0)
	seen[insert] = true
	items[#items + 1] = {
		label = label,
		insert = insert,
		kind = kind,
		detail = detail,
		live = live,
		rank = rank,
		from = from,
		to = to,
	}
end

-- Keep prefix matches before substring matches, then sort by label and insertion text. No fuzzy score: the order is
-- the same on every call and for every client.
---@param items table[]
---@return MacroAssistCompletionItem[]
local function Finish(items)
	table.sort(items, function(left, right)
		if left.rank ~= right.rank then
			return left.rank < right.rank
		end
		local leftLabel, rightLabel = left.label:lower(), right.label:lower()
		if leftLabel ~= rightLabel then
			return leftLabel < rightLabel
		end
		if left.label ~= right.label then
			return left.label < right.label
		end
		return left.insert < right.insert
	end)
	local result = {}
	for index, item in ipairs(items) do
		result[index] = {
			label = item.label,
			insert = item.insert,
			kind = item.kind,
			detail = item.detail,
			live = item.live,
		}
	end
	return result
end

-- The group members completion may offer, as `{ name, className }` entries read fresh by the window.
---@param ctx table
---@return MacroAssistRosterMember[]
local function MemberEntries(ctx)
	local entries = {}
	if type(ctx.members) ~= "table" then
		return entries
	end
	for _, member in ipairs(ctx.members) do
		if type(member) == "table" and type(member.name) == "string" and member.name ~= "" then
			entries[#entries + 1] = member
		end
	end
	return entries
end

---@param items MacroAssistCompletionItem[]
---@param seen table<string, boolean>
---@param from integer
---@param to integer
---@param typed string
---@param members MacroAssistRosterMember[]
---@param prefixOnly boolean? only names that start with the typed text, for words inside a chat message
local function AddMembers(items, seen, from, to, typed, members, prefixOnly)
	local wanted = typed:lower()
	for _, member in ipairs(members) do
		if not prefixOnly or member.name:lower():sub(1, #wanted) == wanted then
			Add(items, seen, from, to, typed, member.name, member.name, "member", member.className or "")
		end
	end
end

-- The best rank one recipe gives the typed text, or nil when none of them match. A recipe is found by its intent
-- words, its localized title and the resolved, localized name of each spell it casts, so a player who types the spell
-- name in their own language finds it without the data file repeating spell names.
---@param typed string
---@param recipe table
---@return integer?
local function RecipeRank(typed, recipe)
	local best
	local function Consider(label)
		if type(label) ~= "string" then
			return
		end
		local rank = Match(typed, label)
		if rank and (not best or rank < best) then
			best = rank
		end
	end
	for _, words in ipairs(recipe.words or {}) do
		Consider(words)
	end
	Consider(recipe.title)
	for _, name in ipairs(recipe.spells or {}) do
		Consider(name)
	end
	return best
end

---@param parsed MacroAssistParse
---@param cursor integer
---@return MacroAssistLine
local function LineAt(parsed, cursor)
	local found = parsed.lines[1]
	for _, line in ipairs(parsed.lines) do
		if line.from > cursor then
			break
		end
		if cursor <= line.to + 1 then
			found = line
		end
	end
	return found
end

---@param line MacroAssistLine
---@param cursor integer
---@return MacroAssistClause?
local function ClauseAt(line, cursor)
	for index, clause in ipairs(line.clauses) do
		local nextClause = line.clauses[index + 1]
		local last = nextClause and (nextClause.from - 1) or (line.to + 1)
		if cursor >= clause.from and cursor <= last then
			return clause
		end
	end
end

---@param clause MacroAssistClause
---@param cursor integer
---@return MacroAssistGroup?
local function GroupAt(clause, cursor)
	for _, group in ipairs(clause.groups) do
		local last = group.closed and group.to or (group.to + 1)
		if cursor > group.from and cursor <= last then
			return group
		end
	end
end

---@param text string
---@param position integer
---@return integer
local function WordEnd(text, position)
	local index = position
	while index <= #text do
		local byte = text:byte(index)
		local word = byte
			and (
				byte == 95
				or (byte >= 48 and byte <= 57)
				or (byte >= 65 and byte <= 90)
				or (byte >= 97 and byte <= 122)
			)
		if not word then
			break
		end
		index = index + 1
	end
	return index - 1
end

-- A unit slot's token end. A player name can carry the realm with a hyphen, which the plain word scan stops at.
---@param text string
---@param position integer
---@return integer
local function NameEnd(text, position)
	local index = position
	while index <= #text do
		local byte = text:byte(index)
		local word = byte
			and (
				byte == 95
				or byte == 45
				or (byte >= 48 and byte <= 57)
				or (byte >= 65 and byte <= 90)
				or (byte >= 97 and byte <= 122)
			)
		if not word then
			break
		end
		index = index + 1
	end
	return index - 1
end

-- The word being typed in a command's arguments: from after the whitespace before the caret to the next
-- whitespace. `first` says the caret is still in the command's first argument.
---@param text string
---@param argsFrom integer
---@param cursor integer
---@return integer from
---@return integer to
---@return boolean first
local function ArgumentWord(text, argsFrom, cursor)
	local firstFrom = argsFrom
	while firstFrom < cursor and (IsSpaceByte(text:byte(firstFrom)) or text:byte(firstFrom) == 10) do
		firstFrom = firstFrom + 1
	end
	local from = firstFrom
	for position = firstFrom, cursor - 1 do
		local byte = text:byte(position)
		if IsSpaceByte(byte) or byte == 10 then
			from = position + 1
		end
	end
	local to = cursor - 1
	while to < #text do
		local byte = text:byte(to + 1)
		if not byte or IsSpaceByte(byte) or byte == 10 then
			break
		end
		to = to + 1
	end
	return from, to, from == firstFrom
end

---@param text string
---@param position integer
---@return integer
local function DirectiveEnd(text, position)
	local index = position
	while index <= #text do
		local byte = text:byte(index)
		if not byte or not ((byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)) then
			break
		end
		index = index + 1
	end
	return index - 1
end

---@param text string
---@param position integer
---@return integer
local function ParameterEnd(text, position)
	local index = position
	while index <= #text do
		local byte = text:byte(index)
		if not byte or byte == 44 or byte == 93 or byte == 47 or byte == 10 or byte == 59 then
			break
		end
		index = index + 1
	end
	return index - 1
end

---@param text string
---@param position integer
---@return integer
local function SpellEnd(text, position)
	local index = position
	while index <= #text do
		local byte = text:byte(index)
		if not byte or byte == 44 or byte == 59 or byte == 10 or byte == 93 then
			break
		end
		index = index + 1
	end
	return index - 1
end

---@param text string
---@param position integer
---@return integer
local function ResetEnd(text, position)
	local index = position
	while index <= #text do
		local byte = text:byte(index)
		if not byte or IsSpaceByte(byte) or byte == 44 or byte == 59 or byte == 93 or byte == 10 then
			break
		end
		index = index + 1
	end
	return index - 1
end

-- The live value `ctx.evaluate(cond)` supplies for a condition, as a detail suffix. Every value is a small
-- descriptor: the condition's own `no` field says that the engine accepts a no prefix, not that this item is the no
-- form, so the descriptor carries the actual negation separately (the caller can tell [dead] from [nodead]).
---@param ctx table
---@param condition MacroAssistCondition
---@param no boolean
---@return string?
local function LiveValue(ctx, condition, no)
	if type(ctx.evaluate) ~= "function" then
		return nil
	end
	local value = { name = condition.name, no = no, condition = condition }
	local ok, live = pcall(ctx.evaluate, value)
	if not ok or live == nil then
		return nil
	end
	return tostring(live)
end

---@param spells table?
---@return table[] entries
local function SpellEntries(spells)
	local entries = {}
	if type(spells) ~= "table" then
		return entries
	end
	for _, value in ipairs(spells) do
		if type(value) == "string" then
			entries[#entries + 1] = { name = value, learned = true }
		elseif type(value) == "table" and type(value.name) == "string" then
			local ranks = value.ranks
			if type(ranks) ~= "table" then
				ranks = value.rank and { value.rank } or nil
			end
			entries[#entries + 1] = {
				name = value.name,
				ranks = ranks,
				learned = value.learned ~= false,
			}
		end
	end
	return entries
end

---@param text string
---@param cursor integer
---@param ctx table?
---@return MacroAssistCompletion
local function Complete(text, cursor, ctx)
	if type(text) ~= "string" then
		return { from = 1, to = 0, items = {} }
	end
	if type(cursor) ~= "number" then
		cursor = #text + 1
	end
	if cursor < 1 then
		cursor = 1
	elseif cursor > #text + 1 then
		cursor = #text + 1
	end
	if type(ctx) ~= "table" then
		ctx = {}
	end
	local parsed = ns.Parser.Parse(text)
	local line = LineAt(parsed, cursor)
	local prefix = text:sub(line.from, cursor - 1)
	local typed
	local from = cursor
	local to = cursor - 1
	local items = {}
	local seen = {}
	local members = MemberEntries(ctx)

	-- A #show or #showtooltip directive.
	local lead, hashAt, directive = prefix:match("^(%s*)()#([%a]*)$")
	if lead then
		from = line.from + hashAt - 1
		to = DirectiveEnd(text, cursor)
		typed = directive
		Add(
			items,
			seen,
			from,
			to,
			typed,
			"#showtooltip",
			"#showtooltip",
			"directive",
			L["Show this macro's icon and tooltip."]
		)
		Add(items, seen, from, to, typed, "#show", "#show", "directive", L["Show this macro's icon and name."])
		return { from = from, to = to, items = Finish(items) }
	end

	-- A command after the slash at the start of the line.
	local commandLead, slashAt, commandWord = prefix:match("^(%s*)!?()/([%w_]*)$")
	if commandLead then
		from = line.from + slashAt - 1
		to = WordEnd(text, cursor)
		typed = commandWord
		for _, command in ipairs(ns.Commands) do
			local detail = command.description or ns.CommandCategoryLabels[command.category]
			for _, alias in ipairs(command.aliases) do
				Add(items, seen, from, to, typed, "/" .. alias, "/" .. alias, command.kind, detail)
			end
		end
		return { from = from, to = to, items = Finish(items) }
	end

	-- Plain words on a line offer the recipes whose words match them. The insert is the whole recipe body and the range
	-- is the whole line, so Tab replaces what the player typed with a ready macro.
	if line.kind == "text" and not prefix:find("^%s*[%@%[]") then
		typed = prefix:match("^%s*(.-)%s*$")
		if typed ~= "" then
			from = line.from
			to = line.to
			for _, recipe in ipairs(ctx.recipes or {}) do
				local rank = RecipeRank(typed, recipe)
				if rank and type(recipe.body) == "string" and not seen[recipe.body] then
					seen[recipe.body] = true
					items[#items + 1] = {
						label = recipe.title or "",
						insert = recipe.body,
						kind = "recipe",
						detail = L["Recipe"],
						rank = rank,
						from = from,
						to = to,
					}
				end
			end
			if #items > 0 then
				return { from = from, to = to, items = Finish(items) }
			end
		end
	end

	local clause = ClauseAt(line, cursor)
	local group = clause and GroupAt(clause, cursor)
	if clause and group then
		local segmentStart = group.from + 1
		for position = group.from + 1, cursor - 1 do
			if text:byte(position) == 44 then
				segmentStart = position + 1
			end
		end
		local contentFrom = segmentStart
		while contentFrom < cursor and IsSpaceByte(text:byte(contentFrom)) do
			contentFrom = contentFrom + 1
		end
		local rest = text:sub(contentFrom, cursor - 1)

		local unitToken = rest:match("^@([%w_%-]*)$")
		if unitToken then
			from = contentFrom + 1
			to = NameEnd(text, cursor)
			typed = unitToken
			for _, unit in ipairs(ns.Units) do
				Add(items, seen, from, to, typed, unit, unit, "unit", L["Unit"])
			end
			AddMembers(items, seen, from, to, typed, members)
			return { from = from, to = to, items = Finish(items) }
		end
		unitToken = rest:match("^[Tt][Aa][Rr][Gg][Ee][Tt]=([%w_%-]*)$")
		if unitToken then
			from = contentFrom + 7
			to = NameEnd(text, cursor)
			typed = unitToken
			for _, unit in ipairs(ns.Units) do
				Add(items, seen, from, to, typed, unit, unit, "unit", L["Unit"])
			end
			AddMembers(items, seen, from, to, typed, members)
			return { from = from, to = to, items = Finish(items) }
		end

		local conditionName, valueText = rest:match("^([%a_]+):(.*)$")
		if conditionName then
			local condition = ns.ConditionAliases[conditionName:lower()]
			if condition and condition.values then
				local valueOffset = contentFrom + #conditionName + 1
				local alternative = 1
				for position in valueText:gmatch("()/") do
					alternative = position + 1
				end
				from = valueOffset + alternative - 1
				while from < cursor and IsSpaceByte(text:byte(from)) do
					from = from + 1
				end
				to = ParameterEnd(text, cursor)
				typed = text:sub(from, cursor - 1)
				for _, value in ipairs(condition.values) do
					Add(items, seen, from, to, typed, value, value, "value", condition.description)
				end
			end
			return { from = from, to = to, items = Finish(items) }
		end

		from = contentFrom
		to = WordEnd(text, cursor)
		typed = rest
		local wantedNo = typed:lower():sub(1, 2) == "no"
		for _, condition in ipairs(ns.Conditions) do
			local detail = condition.description
			if condition.form then
				detail = detail .. "  " .. condition.form
			end
			local forever = condition.forever == false
			local live
			if forever then
				detail = detail .. "  " .. L["Never applies on WoW: Forever."]
			else
				live = LiveValue(ctx, condition, wantedNo)
				if live then
					detail = detail .. "  " .. live
				end
			end
			local rankOffset = forever and 2 or 0
			if wantedNo then
				if condition.no then
					for _, alias in ipairs(condition.aliases) do
						Add(
							items,
							seen,
							from,
							to,
							typed,
							"no" .. alias,
							"no" .. alias,
							"condition",
							detail,
							rankOffset,
							live
						)
					end
				end
			else
				for _, alias in ipairs(condition.aliases) do
					Add(items, seen, from, to, typed, alias, alias, "condition", detail, rankOffset, live)
				end
			end
		end
		return { from = from, to = to, items = Finish(items) }
	end

	-- A group member's name as a command argument: the first argument of a player command such as /invite or /tell,
	-- and any word inside a chat command's message such as /raid.
	local command = line.command and ns.CommandAliases[line.command.nameLower]
	if command and clause and (command.player or command.kind == "chat") then
		local argsFrom
		if clause.args then
			argsFrom = clause.args.from
		elseif clause.groups[#clause.groups] then
			argsFrom = clause.groups[#clause.groups].to + 1
		elseif line.command then
			argsFrom = line.command.to + 1
		else
			argsFrom = clause.from
		end
		if cursor >= argsFrom then
			local wordFrom, wordTo, first = ArgumentWord(text, argsFrom, cursor)
			typed = text:sub(wordFrom, cursor - 1)
			-- A word in a chat message offers the names it starts, once it is started, so ordinary prose opens no popup.
			local nameSlot = command.player and first
			if nameSlot or (command.kind == "chat" and typed ~= "") then
				AddMembers(items, seen, wordFrom, wordTo, typed, members, not nameSlot)
				if #items > 0 then
					return { from = wordFrom, to = wordTo, items = Finish(items) }
				end
			end
		end
	end

	-- A spell argument of /cast, /castsequence, /castrandom or /userandom.
	if not command or not (command.list or command.name == "cast") then
		return { from = from, to = to, items = {} }
	end
	if not clause then
		return { from = from, to = to, items = {} }
	end
	local argsFrom
	if clause.args then
		argsFrom = clause.args.from
	elseif clause.groups[#clause.groups] then
		argsFrom = clause.groups[#clause.groups].to + 1
	else
		argsFrom = clause.from
	end
	if cursor < argsFrom then
		return { from = from, to = to, items = {} }
	end
	local itemStart = argsFrom
	for position = argsFrom, cursor - 1 do
		if text:byte(position) == 44 then
			itemStart = position + 1
		end
	end
	while itemStart < cursor and IsSpaceByte(text:byte(itemStart)) do
		itemStart = itemStart + 1
	end
	if text:sub(itemStart, itemStart) == "!" then
		itemStart = itemStart + 1
		while itemStart < cursor and IsSpaceByte(text:byte(itemStart)) do
			itemStart = itemStart + 1
		end
	end
	local itemPrefix = text:sub(itemStart, cursor - 1)
	if command.name == "castsequence" then
		local resetValue = itemPrefix:match("^[Rr][Ee][Ss][Ee][Tt]=([^%s]*)$")
		if resetValue then
			from = itemStart + 6
			to = ResetEnd(text, cursor)
			for _, value in ipairs({ "target", "combat", "shift", "ctrl", "alt" }) do
				Add(items, seen, from, to, resetValue, value, value, "value", L["Reset value"])
			end
			return { from = from, to = to, items = Finish(items) }
		end
		local afterReset = itemPrefix:match("^[Rr][Ee][Ss][Ee][Tt]=[^%s]+%s+(.*)$")
		if afterReset then
			itemStart = itemStart + (#itemPrefix - #afterReset)
			itemPrefix = afterReset
		end
	end
	from = itemStart
	to = SpellEnd(text, cursor)
	typed = itemPrefix
	local spells = SpellEntries(ctx.spells)
	for _, spell in ipairs(spells) do
		local detail = spell.learned and L["Spell"] or L["Not learned"]
		Add(items, seen, from, to, typed, spell.name, spell.name, "spell", detail)
		if spell.ranks then
			for _, rank in ipairs(spell.ranks) do
				local label = spell.name .. "(Rank " .. tostring(rank) .. ")"
				local rankDetail = spell.learned and L["Rank %d"]:format(rank) or L["Not learned"]
				Add(items, seen, from, to, typed, label, label, "spell", rankDetail)
			end
		end
	end
	return { from = from, to = to, items = Finish(items) }
end

ns.Complete = Complete
