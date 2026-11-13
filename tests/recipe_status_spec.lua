-- The Recipes popup's status line sits in the Import button's row at the frame's bottom edge. Anchored from the
-- frame's LEFT and RIGHT, its y was the popup's vertical centre, so "Learn at level 20." drew over the third list row.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end
local function yes(value, label)
	checks = checks + 1
	assert(value, label)
end

-- A frame stub that records its anchors: the client's own box, with the templates Recipes.lua names, and no layout.
---@param kind string
---@return table
local function Region(kind)
	local region = { kind = kind, points = {} }
	setmetatable(region, {
		__index = function(object, key)
			-- Everything else the popup calls on a frame or a region (text, colours, size, scripts) does nothing.
			local noop = function() end
			object[key] = noop
			return noop
		end,
	})
	function region:SetPoint(point, relativeTo, relativePoint, x, y)
		self.points[#self.points + 1] = {
			point = point,
			relativeTo = relativeTo,
			relativePoint = relativePoint,
			x = x or 0,
			y = y or 0,
		}
	end
	function region:GetPoint(index)
		local found = assert(self.points[index], "no anchor " .. tostring(index))
		return found.point, found.relativeTo, found.relativePoint, found.x, found.y
	end
	function region:GetNumPoints()
		return #self.points
	end
	function region:SetSize(width, height)
		self.width, self.height = width, height
	end
	function region:SetWidth(width)
		self.width = width
	end
	function region:SetHeight(height)
		self.height = height
	end
	function region:GetWidth()
		return self.width or 0
	end
	function region:GetHeight()
		return self.height or 0
	end
	function region.GetFrameLevel()
		return 0
	end
	function region.CreateFontString()
		return Region("FontString")
	end
	return region
end

---@param template string?
---@return table
local function Frame(template)
	local frame = Region("Frame")
	if template == "ButtonFrameTemplate" then
		frame.TitleContainer = { TitleText = Region("FontString") }
		frame.PortraitContainer = { portrait = Region("Texture") }
		frame.Inset = Region("Frame")
		frame.CloseButton = Region("Button")
	end
	return frame
end

_G.CreateFrame = function(_, _, _, template)
	return Frame(template)
end
_G.CreateScrollBoxListLinearView = function()
	return { SetElementExtent = function() end, SetElementInitializer = function() end }
end
_G.ScrollUtil = {
	InitScrollBoxListWithScrollBar = function() end,
	InitScrollFrameWithScrollBar = function() end,
}
_G.ScrollBoxConstants = { RetainScrollPosition = 1 }

local ns = { Icon = "Interface/Icons/INV_Misc_QuestionMark", Editor = { LineHeight = 15 } }
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("MacroAssistForever", ns)
end
load("Locales/enUS.lua")
load("UI/Recipes.lua")

local panel = ns.RecipesPanel.Create(Frame(), function() end)

---@param region table
---@param index number
---@return table
local function anchor(region, index)
	local point, relativeTo, relativePoint, x, y = region:GetPoint(index)
	return { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
end

-- The Import button gives the row: its own bottom edge plus half its height is where the status line belongs.
local import = anchor(panel.importButton, 1)
equal(import.point, "BOTTOMRIGHT", "the Import button is anchored by its bottom right corner")
yes(import.relativeTo == panel, "the Import button is anchored to the popup")
local importWidth = panel.importButton:GetWidth()
local centre = import.y + panel.importButton:GetHeight() / 2

equal(panel.status:GetNumPoints(), 2, "the status line has two anchors")
local left = anchor(panel.status, 1)
local right = anchor(panel.status, 2)

-- The line's own LEFT and RIGHT are its vertical centre; the frame's BOTTOMLEFT and BOTTOMRIGHT are its bottom edge.
equal(left.point, "LEFT", "the status line is held by its vertical centre on the left")
equal(left.relativePoint, "BOTTOMLEFT", "the status line's y is measured from the popup's bottom edge")
yes(left.relativeTo == panel, "the status line is anchored to the popup")
equal(right.point, "RIGHT", "the status line is held by its vertical centre on the right")
equal(right.relativePoint, "BOTTOMRIGHT", "the status line's y is measured from the popup's bottom edge")
yes(right.relativeTo == panel, "the status line is anchored to the popup")

-- The line's anchors are level with the Import button's vertical centre, not the popup's.
equal(left.y, centre, "the status line is not level with the Import button")
equal(right.y, centre, "the status line is not level with the Import button")
yes(left.y > 0, "the status line is below the popup's bottom edge")

-- The line stops before the Import button, as it did before the fix.
yes(right.x < import.x - importWidth, "the status line reaches under the Import button")

print(("%d checks passed"):format(checks))
