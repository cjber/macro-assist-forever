local _, ns = ...

if ns.broken then
	return
end

-- Cursor is the EditBox's zero-based byte offset, including when a selection will be replaced by Insert.
---@param text string
---@param cursor integer
---@param name string
---@param kind string item or spell
---@param usable boolean?
---@param command string? localized slash command, supplied by the client-facing caller
---@return string
function ns.InsertText(text, cursor, name, kind, usable, command)
	if cursor == 0 or text:sub(cursor, cursor) == "\n" then
		command = command or (kind == "item" and (usable and "/use" or "/equip") or "/cast")
		return command .. " " .. name .. "\n"
	end
	return name
end

-- A spellbook name as the parser reads it back: `Name(Rank N)` for a rank subtitle, the bare name for any other.
---@param name string?
---@param subName any
---@return string?
function ns.SpellInsertName(name, subName)
	if type(name) == "string" and type(subName) == "string" and ns.Parser.RankDigits(subName) then
		return name .. "(" .. subName .. ")"
	end
	return name
end

-- The hyperlink grammar's display text, not a name inferred from the item's numeric payload.
---@param link string
---@return string?
function ns.ItemLinkName(link)
	return link:match("|Hitem:[^|]*|h%[(.-)%]|h")
end
