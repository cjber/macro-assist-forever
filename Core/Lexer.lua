local _, ns = ...

if ns.broken then
	return
end

-- Split one macro line into tokens with byte offsets. The lexer never rejects input: every byte belongs to a token,
-- so the parser can report a malformed line without losing the text the player typed.

---@class MacroAssistToken
---@field kind string space, word, slash, bang, hash, at, brackets, comma, semicolon, colon, equals or parens
---@field text string the exact bytes this token covers
---@field from integer first byte, 1-based
---@field to integer last byte, 1-based

-- Bytes that end a word. Punctuation the macro grammar uses gets its own token.
local PUNCTUATION = {
	[33] = "bang",
	[35] = "hash",
	[40] = "lparen",
	[41] = "rparen",
	[44] = "comma",
	[47] = "slash",
	[58] = "colon",
	[59] = "semicolon",
	[61] = "equals",
	[64] = "at",
	[91] = "lbracket",
	[93] = "rbracket",
}

---@param byte integer?
---@return boolean
local function IsSpace(byte)
	return byte == 9 or byte == 13 or byte == 32
end

---@param byte integer
---@return boolean
local function IsWord(byte)
	return not IsSpace(byte) and PUNCTUATION[byte] == nil
end

---@param text string
---@return MacroAssistToken[]
local function Tokens(text)
	local tokens = {}
	local index = 1
	local length = #text
	while index <= length do
		local byte = text:byte(index)
		local kind
		if IsSpace(byte) then
			kind = "space"
		else
			kind = PUNCTUATION[byte] or "word"
		end
		local first = index
		if kind == "word" then
			index = index + 1
			while index <= length and IsWord(text:byte(index)) do
				index = index + 1
			end
		else
			index = index + 1
		end
		tokens[#tokens + 1] = {
			kind = kind,
			text = text:sub(first, index - 1),
			from = first,
			to = index - 1,
		}
	end
	return tokens
end

---@class MacroAssistLexer
---@field Tokens fun(text: string): MacroAssistToken[]
---@field IsSpace fun(byte: integer?): boolean
---@type MacroAssistLexer
ns.Lexer = { Tokens = Tokens, IsSpace = IsSpace }
