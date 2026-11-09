local _, ns = ...

-- What the macro window's counter counts.
--
-- Blizzard_MacroUI.xml gives MacroFrameText `letters="255" countInvisibleLetters="true"` and writes
-- `MacroFrameCharLimitText:SetFormattedText(MACROFRAME_CHAR_LIMIT, MacroFrameText:GetNumLetters())` from
-- OnTextChanged. GetNumLetters is the letter count, not the byte count: the EditBox API has a separate
-- GetMaxBytes/SetMaxBytes for UTF-8 bytes, and GetMaxLetters/SetMaxLetters for characters. So a UTF-8 character counts
-- one however many bytes it takes, every newline counts one, and colour codes count as their bytes because
-- countInvisibleLetters is on. That is exactly the character count below.
--
-- The limit is 255. Keep this in step with Core/Check.lua's "too long" diagnostic.

local LIMIT = 255

-- A UTF-8 continuation byte is 10xxxxxx; every other byte begins a character. Invalid input still counts sensibly.
---@param text string?
---@return integer
local function Length(text)
	if type(text) ~= "string" then
		return 0
	end
	local _, count = text:gsub("[^\128-\191]", "")
	return count
end

-- The byte offset of the first character past `limit`, or #text + 1 when the text fits. An insertion range at that
-- offset starts where the counter turns red.
---@param text string
---@param limit integer
---@return integer
local function FirstOver(text, limit)
	local count = 0
	for position = 1, #text do
		local byte = text:byte(position)
		if byte < 0x80 or byte >= 0xC0 then
			count = count + 1
			if count > limit then
				return position
			end
		end
	end
	return #text + 1
end

ns.Length = Length
ns.FirstOver = FirstOver
ns.MacroLimit = LIMIT
