-- The Recipes preview: this client draws only the first line of a word-wrap-off FontString, however many newlines its
-- text holds and whatever height it is given, so the preview must draw every laid-out row as its own FontString. The
-- spec models that client, then checks every row is visible in order at the layout's offsets, and that a shorter
-- recipe hides the rows it no longer needs.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

local LINE_HEIGHT = 19
local WIDTH = 320
local rows = {
	{ row = 0, y = 0, text = "#showtooltip" },
	{ row = 1, y = LINE_HEIGHT, text = "/cast [@mouseover,harm,nodead][] Arcane Shot" },
	{ row = 0, y = 2 * LINE_HEIGHT, text = "/petattack [@mouseover,harm,nodead][]" },
}

local ns = {
	Editor = {
		LineHeight = LINE_HEIGHT,
		LayoutRows = function()
			return rows
		end,
	},
}
local chunk = assert(loadfile("UI/Recipes.lua"))
chunk("MacroAssistForever", ns)
local Panel = assert(ns.RecipesPanel)

local function region(width, height)
	local value = { width = width or 0, height = height or 0 }
	function value:SetWidth(w)
		self.width = w
	end
	function value:SetHeight(h)
		self.height = h
	end
	function value:GetWidth()
		return self.width
	end
	function value:GetHeight()
		return self.height
	end
	return value
end

-- A FontString as this client draws one: with word wrap off it paints only the first line of its text. Its height
-- does not make the rest appear. The point and the shown state are recorded so a check can read the rows.
local function fontString()
	local value = region()
	value.text = ""
	value.wordWrap = true
	value.shown = true
	value.color = { 1, 1, 1 }
	function value:SetText(text)
		self.text = text
	end
	function value:GetText()
		return self.text
	end
	function value:SetWordWrap(on)
		self.wordWrap = not not on
	end
	function value:CanWordWrap()
		return self.wordWrap
	end
	function value.SetJustifyH() end
	function value.SetJustifyV() end
	function value:SetTextColor(r, g, b)
		self.color = { r or 1, g or 1, b or 1 }
	end
	function value:SetPoint(_point, _target, _targetPoint, x, y)
		self.x, self.y = x or 0, y or 0
	end
	function value:GetPointY()
		return self.y or 0
	end
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
			return self.text:match("^[^\n]*") or ""
		end
		return self.text
	end
	return value
end

local child = region()
child.fonts = {}
function child:CreateFontString()
	local font = fontString()
	self.fonts[#self.fonts + 1] = font
	return font
end

-- The one FontString b0d3fea drew every row into. It stays in the fake so the old code runs against the client's
-- rule above, paints one line, and the checks below fail on it.
local previewText = fontString()
previewText:SetWordWrap(false)

local frame = {
	previewValue = table.concat({ rows[1].text, rows[2].text, rows[3].text }, "\n"),
	lineHeight = LINE_HEIGHT,
	previewChild = child,
	previewRows = {},
	previewText = previewText,
	textMeasure = {
		width = function()
			return 0
		end,
	},
	preview = {
		GetWidth = function()
			return WIDTH
		end,
		UpdateScrollChildRect = function() end,
		SetVerticalScroll = function() end,
	},
}

-- Every character the client paints, in row order.
local function drawn()
	local visible = {}
	if previewText:GetText() ~= "" then
		visible[#visible + 1] = previewText:DrawableText()
	end
	for _, font in ipairs(child.fonts) do
		if font:IsShown() then
			visible[#visible + 1] = font:DrawableText()
		end
	end
	return table.concat(visible, "\n")
end

Panel.Measure(frame)

equal(
	drawn(),
	table.concat({ rows[1].text, "  " .. rows[2].text, rows[3].text }, "\n"),
	"the preview does not draw every laid-out row in order"
)
equal(#frame.previewRows, #rows, "the preview does not give every laid-out row its own FontString")
for index, row in ipairs(rows) do
	local font = frame.previewRows[index]
	equal(font:GetWidth(), WIDTH, ("row %d is not the preview's width"):format(index))
	equal(font:CanWordWrap(), false, ("row %d can word wrap again"):format(index))
	equal(font:GetPointY(), -row.y, ("row %d is not at the layout's offset"):format(index))
end
equal(frame.previewChild:GetHeight(), #rows * LINE_HEIGHT, "the scroll child does not hold every laid-out row")

-- A shorter recipe reuses the FontStrings it needs and hides the ones it does not, so the pool never grows past the
-- tallest macro selected.
rows = {
	{ row = 0, y = 0, text = "#showtooltip" },
	{ row = 0, y = LINE_HEIGHT, text = "/stopcasting" },
}
frame.previewValue = table.concat({ rows[1].text, rows[2].text }, "\n")
Panel.Measure(frame)

equal(#child.fonts, 3, "measuring a shorter recipe created more FontStrings")
equal(drawn(), "#showtooltip\n/stopcasting", "the shorter recipe still draws the hidden rows")
equal(frame.previewRows[3]:IsShown(), false, "the row a shorter recipe no longer needs is still shown")
equal(frame.previewChild:GetHeight(), 2 * LINE_HEIGHT, "the scroll child kept the taller recipe's height")

print(("recipe preview: %d checks"):format(checks))
