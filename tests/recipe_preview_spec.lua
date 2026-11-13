-- The Recipes preview: the FontString gets the height of every laid-out row, not just the one line a word-wrap-off
-- FontString keeps on its own, so the whole macro shows and the child scrolls to all of it.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

local LINE_HEIGHT = 19
local rows = {
	{ row = 0, text = "#showtooltip" },
	{ row = 1, text = "/cast [@mouseover,harm,nodead][] Arcane Shot" },
	{ row = 0, text = "/petattack [@mouseover,harm,nodead][]" },
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

local function region()
	local value = { width = 0, height = 0 }
	function value:SetWidth(width)
		self.width = width
	end
	function value:SetHeight(height)
		self.height = height
	end
	function value:GetWidth()
		return self.width
	end
	function value:GetHeight()
		return self.height
	end
	return value
end

local previewText = region()
function previewText:SetText(text)
	self.text = text
end

local frame = {
	previewValue = "#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot\n/petattack [@mouseover,harm,nodead][]",
	lineHeight = LINE_HEIGHT,
	previewChild = region(),
	previewText = previewText,
	textMeasure = {
		width = function()
			return 0
		end,
	},
	preview = {
		GetWidth = function()
			return 320
		end,
		UpdateScrollChildRect = function() end,
		SetVerticalScroll = function() end,
	},
}

Panel.Measure(frame)

local height = #rows * LINE_HEIGHT
equal(frame.previewText:GetWidth(), 320, "the preview text is not the preview's width")
equal(frame.previewText:GetHeight(), height, "the preview FontString does not show every laid-out row")
equal(frame.previewChild:GetHeight(), height, "the scroll child does not hold every laid-out row")
equal(
	frame.previewText.text,
	table.concat({ rows[1].text, "  " .. rows[2].text, rows[3].text }, "\n"),
	"the rows are joined with their hanging indent"
)

print(("recipe preview: %d checks"):format(checks))
