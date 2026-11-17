-- Native insertion rules are pure; the EditBox fixture models the engine's byte cursor, selection and letter cap.
local ns = {}
for _, path in ipairs({
	"Locales/enUS.lua",
	"Core/Lexer.lua",
	"Core/Length.lua",
	"Core/Insert.lua",
	"UI/Editor.lua",
}) do
	assert(loadfile(path))("MacroAssistForever", ns)
end
local checks = 0
local function equal(actual, expected)
	checks = checks + 1
	assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
for _, case in ipairs({
	{ "", 0, "Potion", "item", true, "/use Potion\n" },
	{ "", 0, "Sword", "item", false, "/equip Sword\n" },
	{ "/say hi\nnext", 8, "Heal", "spell", false, "/cast Heal\n" },
	{ "/cast ", 6, "Heal", "spell", false, "Heal" },
	{ "abc", 1, "Potion", "item", true, "Potion" },
}) do
	equal(ns.InsertText(case[1], case[2], case[3], case[4], case[5]), case[6])
end
equal(ns.InsertText("", 0, "Heilung", "spell", false, "/wirken"), "/wirken Heilung\n")
local link = "|cffffffff|Hitem:123::::::::|h[Potion of Healing]|h|r"
equal(ns.ItemLinkName(link), "Potion of Healing")
equal(ns.ItemLinkName("|Hspell:123|h[Heal]|h"), nil)
local edit = { text = "/cast old suffix", cursor = 6, from = 6, to = 9, focused = true, limit = 0 }
function edit:HasFocus()
	return self.focused
end
function edit:GetText()
	return self.text
end
function edit:GetCursorPosition()
	return self.cursor
end
function edit:GetMaxLetters()
	return self.limit
end
function edit:SetMaxLetters(limit)
	self.limit = limit
end
function edit:Insert(text)
	local before, after = self.text:sub(1, self.from or self.cursor), self.text:sub((self.to or self.cursor) + 1)
	local available = self.limit - ns.Length(before .. after)
	text = text:sub(1, ns.FirstOver(text, math.max(0, available)) - 1)
	self.text = before .. text .. after
	self.cursor = #before + #text
	self.from, self.to = nil, nil
end
local editor = setmetatable({ edit = edit }, { __index = ns.Editor })
equal(editor:InsertName("Heal", "spell"), true)
equal(edit.text, "/cast Heal suffix")
equal(edit.limit, 0)
edit.text, edit.cursor = string.rep("a", 252), 252
equal(editor:InsertName("治疗", "spell"), true)
equal(ns.Length(edit.text), 254)
edit.cursor = #edit.text
editor:InsertName("治疗", "spell")
equal(ns.Length(edit.text), 255)
equal(edit.text:sub(-3), "治")
edit.focused = false
equal(editor:InsertName("Heal", "spell"), false)
local unchanged = edit.text
equal(edit.text, unchanged)
print("insert_spec: " .. checks .. " checks passed")

-- Only recognized, successfully inserted cursor payloads are consumed. No focus leaves the cursor alone.
local cursor, cleared = { "spell", 1, "spell", 42 }, 0
_G.GetCursorInfo = function()
	return unpack(cursor)
end
_G.ClearCursor = function()
	cleared = cleared + 1
end
_G.C_Spell = {
	GetSpellInfo = function(id)
		equal(id, 42)
		return { name = "Heal" }
	end,
}
_G.C_Item = {
	GetItemInfo = function()
		return nil
	end,
	GetItemSpell = function()
		return "Heal"
	end,
}
edit.text, edit.cursor, edit.focused = "", 0, true
equal(editor:ReceiveDrop(), true)
equal(edit.text, "/cast Heal\n")
equal(cleared, 1)
cursor = { "item", 123, link }
edit.text, edit.cursor = "", 0
equal(editor:ReceiveDrop(), true)
equal(edit.text, "/use Potion of Healing\n")
cursor = { "macro", 1 }
equal(editor:ReceiveDrop(), false)
cursor = { "money", 1 }
equal(editor:ReceiveDrop(), false)
equal(cleared, 2)
edit.focused = false
cursor = { "spell", 1, "spell", 42 }
equal(editor:ReceiveDrop(), false)
equal(cleared, 2)
equal(edit.text, "/use Potion of Healing\n")
print("insert_spec: " .. checks .. " checks passed including drops")

_G.SLASH_CAST1 = "/wirken"
_G.SLASH_USE1 = "/benutzen"
_G.SLASH_EQUIP1 = "/anlegen"
for _, case in ipairs({
	{ "spell", false, "/wirken Heal\n" },
	{ "item", true, "/benutzen Heal\n" },
	{ "item", false, "/anlegen Heal\n" },
}) do
	edit.text, edit.cursor, edit.focused = "", 0, true
	editor:InsertName("Heal", case[1], case[2])
	equal(edit.text, case[3])
end
_G.SLASH_CAST1, _G.SLASH_USE1, _G.SLASH_EQUIP1 = nil, nil, nil
print("insert_spec: " .. checks .. " checks passed including localized commands")
