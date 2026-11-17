-- Font selection is pure: loading the editor and choosing paths needs no client APIs.
local ns = {}
assert(loadfile("Core/Lexer.lua"))("MacroAssistForever", ns)
assert(loadfile("Core/Parser.lua"))("MacroAssistForever", ns)
assert(loadfile("UI/Editor.lua"))("MacroAssistForever", ns)
assert(type(ns.EditorFontPath) == "function", "editor must expose its locale font choice")
local bundled = "Interface/AddOns/MacroAssistForever/media/fonts/JetBrainsMono-Regular.ttf"
local chat = "Fonts/locale-chat.ttf"
for _, locale in ipairs({ "zhCN", "zhTW", "koKR" }) do
	assert(ns.EditorFontPath(locale, chat) == chat, locale .. " must use the client's chat font")
end
for _, locale in ipairs({ "enUS", "deDE", "ruRU" }) do
	assert(ns.EditorFontPath(locale, chat) == bundled, locale .. " must keep JetBrains Mono")
end
-- A proportional font must drive both wrap points and caret offsets through measured widths.
local widths = {
	width = function(text)
		local width = 0
		for character in text:gmatch(".") do
			width = width + (character == "W" and 12 or 3)
		end
		return width
	end,
}
local rows = ns.Editor.LayoutRows("W ii", 15, 19, widths)
assert(#rows == 2 and rows[1].text == "W " and rows[2].text == "ii", "wrap uses measured widths")
assert(ns.Editor.RowOffset(rows[1], 1, widths) == 12, "caret offset uses the wide glyph's width")
assert(ns.Editor.RowOffset(rows[2], 3, widths) == 3, "caret offset uses the narrow glyph's width")
print("editor_font_spec: passed")
