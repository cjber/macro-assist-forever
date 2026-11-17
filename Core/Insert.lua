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

-- The hyperlink grammar's display text, not a name inferred from the item's numeric payload.
---@param link string
---@return string?
function ns.ItemLinkName(link)
	return link:match("|Hitem:[^|]*|h%[(.-)%]|h")
end
