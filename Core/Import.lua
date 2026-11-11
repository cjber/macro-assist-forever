local _, ns = ...

if ns.broken then
	return
end

-- What the Import box accepts. Addons have no network access, so pasted text is the only way a macro arrives from
-- wago.io or another character. This file is pure Lua: the panel classifies the text, then asks the parser and the
-- checker about it before it is written.
--
-- A macro has at least one line that begins with `/` or `#`, after any indentation. A MySlot export is a different
-- format entirely and is named as such instead of being saved as a broken macro.

local M = {}

-- The client stores macro lines separated by one newline, whatever an operating system put on the clipboard.
---@param text string
---@return string
local function Normalize(text)
	return (text:gsub("\r\n", "\n"):gsub("\r", "\n"))
end

---@class MacroAssistImport
---@field kind "macro"|"myslot"|"text"|"empty"
---@field body string the text as the macro store takes it

---@param text string?
---@return MacroAssistImport
local function Classify(text)
	if type(text) ~= "string" then
		return { kind = "empty", body = "" }
	end
	local body = Normalize(text)
	if body:match("^%s*$") then
		return { kind = "empty", body = body }
	end
	for line in body:gmatch("[^\n]*") do
		local firstByte = line:match("^%s*(.)")
		if firstByte == "/" or firstByte == "#" then
			return { kind = "macro", body = body }
		end
		if line:lower():match("^%s*!myslot:") then
			return { kind = "myslot", body = body }
		end
	end
	return { kind = "text", body = body }
end

M.Classify = Classify

ns.Import = M
