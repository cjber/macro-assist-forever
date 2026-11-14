-- The editor draws every laid-out visual row as its own FontString. A word-wrapped FontString breaks a token its own
-- way, so a pasted line wider than the editor used to run past its edge while the gutter followed the measured rows.
-- The spec models the client, then checks every measured row is drawn once, in order, at the layout's offset, with
-- each line number beside the first row of the line it names.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %q, got %q"):format(label, tostring(expected), tostring(actual)))
end

local ns = {}
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("MacroAssistForever", ns)
end
load("Locales/enUS.lua")
load("Core/Lexer.lua")
load("Core/Parser.lua")
load("Core/Highlight.lua")
load("UI/Editor.lua")

local ADVANCE = 10
local LINE_HEIGHT = 19
-- At 70 units a row holds seven characters, so ordinary macro lines wrap and one long condition token is split.
local WIDTH = 70

-- The text a FontString actually paints, with the overlay's colour codes and doubled pipes removed.
local function plain(text)
	local pipe = "\1"
	text = text:gsub("||", pipe)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return (text:gsub(pipe, "|"))
end

-- The mono font's fixed advance, as the editor's textMeasure reports it.
local measured = { text = "" }
function measured:SetText(text)
	self.text = text or ""
end
function measured:GetStringWidth()
	return #plain(self.text) * ADVANCE
end
local widths = {
	width = function(text)
		measured:SetText(text)
		return measured:GetStringWidth()
	end,
}

-- A FontString as this client draws one: with word wrap off it paints only the first line of its text. The point,
-- width and shown state are recorded so a check can read the row the editor placed.
local function fontString()
	local value = { text = "", wordWrap = true, shown = true, width = 0, y = 0 }
	function value:SetText(text)
		self.text = text or ""
	end
	function value:GetText()
		return self.text
	end
	function value:SetWidth(width)
		self.width = width
	end
	function value:GetWidth()
		return self.width
	end
	function value:SetWordWrap(on)
		self.wordWrap = not not on
	end
	function value:CanWordWrap()
		return self.wordWrap
	end
	function value:SetPoint(_point, _target, _targetPoint, _x, y)
		self.y = y or 0
	end
	function value:GetPointY()
		return self.y
	end
	function value.SetTextColor() end
	function value.SetJustifyH() end
	function value.SetSpacing() end
	function value:Show()
		self.shown = true
	end
	function value:Hide()
		self.shown = false
	end
	function value:IsShown()
		return self.shown
	end
	function value:DrawableText()
		if self.wordWrap == false then
			return plain(self.text):match("^[^\n]*") or ""
		end
		return plain(self.text)
	end
	return value
end

local function region()
	local value = { fonts = {} }
	function value:CreateFontString()
		local font = fontString()
		self.fonts[#self.fonts + 1] = font
		return font
	end
	return value
end

-- Run the real layout and the real overlay placement over a fake client, so the assertions below read exactly what
-- the editor asked the client to draw.
local function render(text)
	local parsed = ns.Parser.Parse(text)
	local rows = ns.Editor.LayoutRows(text, WIDTH, LINE_HEIGHT, widths)
	local editor = setmetatable({
		rows = rows,
		wrapWidth = WIDTH,
		lineHeight = LINE_HEIGHT,
		lineFonts = {},
		numberFonts = {},
		overlay = region(),
		gutter = region(),
	}, { __index = ns.Editor })
	editor:LayoutLines(parsed)
	return editor, rows, parsed
end

local function checkRendering(text, label)
	local editor, rows, parsed = render(text)
	equal(#editor.lineFonts, #rows, label .. ": every measured row has its own FontString")
	for index, row in ipairs(rows) do
		local font = editor.lineFonts[index]
		equal(font:CanWordWrap(), false, ("%s: row %d is left to wrap again"):format(label, index))
		equal(font:GetWidth(), WIDTH, ("%s: row %d is not the editor's width"):format(label, index))
		equal(font:GetPointY(), -row.y, ("%s: row %d is not at the layout's offset"):format(label, index))
		equal(font:DrawableText(), row.text, ("%s: row %d draws the wrong text"):format(label, index))
	end
	local firstRow = {}
	for _, row in ipairs(rows) do
		firstRow[row.line] = firstRow[row.line] or row.y
	end
	equal(#editor.numberFonts, #parsed.lines, label .. ": every line has one number")
	for line = 1, #parsed.lines do
		equal(
			editor.numberFonts[line]:GetPointY(),
			-(firstRow[line] or 0),
			("%s: line %d's number is not beside its first row"):format(label, line)
		)
	end
end

-- One 250-character line, with a condition token wider than the editor and many words after it, as a long pasted
-- command line has. The measured layout splits both the token and the words; the overlay must follow those rows.
local condition = "[@mouseover,harm,nodead][@target,harm,nodead][@focus,harm,nodead]"
local longLine = "/cast " .. condition .. " " .. string.rep("Shadow Bolt ", 15)
equal(#longLine >= 250, true, "the sample line is not about 250 characters")
checkRendering(longLine, "one long line")

-- Several long lines pasted at once: every line's number stays beside its own first row, and no line's text is
-- pushed past the right edge or onto the next line's number.
local pasted = table.concat({
	"#showtooltip",
	longLine,
	"/cast " .. condition .. " Serpent Sting",
	"/petattack " .. condition,
	"/startattack",
}, "\n")
checkRendering(pasted, "several long lines")

-- A short macro still draws one FontString per measured row, so the same path serves both.
checkRendering("one two\nthree four\nfive", "short macro")

print(("editor rows: %d checks"):format(checks))
