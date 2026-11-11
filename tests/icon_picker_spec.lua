-- The icon picker's cost on reopen: the All icons rows depend only on the column count and kind filter, so they are
-- built once and reused. Labels stay lazy. Search, kind filtering and the status line still answer as before.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end
local function yes(value, label)
	checks = checks + 1
	assert(value, label)
end

local ns = {
	Readable = function(value)
		return value
	end,
	Context = { ctx = { spells = {} } },
}
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("MacroAssistForever", ns)
end
load("Locales/enUS.lua")
load("Core/Lexer.lua")
load("Core/Parser.lua")
load("Core/Icons.lua")
load("UI/IconSelector.lua")
local Icons = assert(ns.Icons)
local Picker = assert(ns.IconPicker)

-- A 27,714-icon client, the size the live provider hands the picker. Every hundredth icon is a Hunter class icon so
-- the kind filter has something to keep.
local TOTAL = 27714
local FIRST = 1000001
local HUNTER_ICONS = math.floor(TOTAL / 100)
local allIcons = {}
local names = {}
for index = 1, TOTAL do
	local icon = FIRST + index - 1
	allIcons[index] = { icon = icon }
	if index % 100 == 0 then
		names[icon] = ("ability_hunter_icon_%05d"):format(index)
	else
		names[icon] = ("inv_misc_icon_%05d"):format(index)
	end
end
Icons.names = names

local fileNameCalls = 0
local fileName = Icons.FileName
Icons.FileName = function(icon)
	if type(icon) == "number" and icon >= FIRST and icon < FIRST + TOTAL then
		fileNameCalls = fileNameCalls + 1
	end
	return fileName(icon)
end

_G.BreakUpLargeNumbers = tostring
_G.CreateDataProvider = function()
	local provider = { rows = {} }
	function provider:Insert(row)
		self.rows[#self.rows + 1] = row
	end
	return provider
end

local picker = setmetatable({
	editor = {
		NowRaw = function()
			return ""
		end,
	},
	searchBox = {
		SetWidth = function() end,
		SetText = function() end,
		SetFocus = function() end,
	},
	dropdown = {
		SetText = function() end,
		GetWidth = function()
			return 110
		end,
	},
	scrollBox = {
		GetWidth = function()
			return 800
		end,
		SetDataProvider = function(self, provider)
			self.provider = provider
		end,
		ScrollToBegin = function() end,
		ForEachFrame = function() end,
	},
	statusText = {
		SetText = function(self, text)
			self.text = text
		end,
	},
	allIcons = allIcons,
	macroIcons = {},
	show = "all",
	search = "",
	className = "Hunter",
}, { __index = Picker })
function picker:Show()
	self.shown = true
end
function picker:Hide()
	self.shown = false
end
function picker:IsShown()
	return self.shown == true
end
function picker.GetWidth(_)
	return 840
end

local started = os.clock()
picker:Open(134400, "", "Hunter")
local firstOpen = os.clock() - started
local columns = picker.columns
local cachedRows = picker.allRows and picker.allRows[columns]
yes(cachedRows, "the first Open did not cache the All icons rows")
equal(#cachedRows, math.ceil(TOTAL / columns), "the cached rows do not cover every icon")

-- Prime the kind cache: filtering the whole client list is the one walk it may do, once.
fileNameCalls = 0
picker:SetKind("class", "hunter")
yes(fileNameCalls > 0, "the kind filter did not read the icon names")
local hunter = picker:KindIcons({ kind = "class", token = "hunter" })
equal(#hunter.icons, HUNTER_ICONS, "the Hunter filter kept the wrong number of icons")
fileNameCalls = 0
picker:SetKind("class", "hunter")
equal(fileNameCalls, 0, "switching back to the same kind read every icon again")

-- The second Open is the regression: it must reuse the rows and read no per-icon name at all.
fileNameCalls = 0
started = os.clock()
picker:Open(134400, "", "Hunter")
local secondOpen = os.clock() - started
equal(fileNameCalls, 0, "the second Open read every icon's label")
yes(picker.allRows[columns] == cachedRows, "the second Open rebuilt the All icons rows")
yes(picker.allIcons == allIcons, "the second Open rebuilt the client icon list")
yes(secondOpen <= firstOpen, ("the second Open is slower: %.6fs then %.6fs"):format(firstOpen, secondOpen))

-- Search still walks the names it needs, and the kind filter's rows stay cached.
picker:SetSearch("hunter")
equal(picker.rows[1].title, "Your spells", "search does not start with Your spells")
local allHeader
for index, row in ipairs(picker.rows) do
	if row.title == "All icons" then
		allHeader = index
	end
end
yes(allHeader, "search does not follow with All icons")
yes(#picker.rows[allHeader].note > 0, "the icon matches have no count")
local matches = 0
for index = allHeader + 1, #picker.rows do
	if picker.rows[index].icons then
		matches = matches + #picker.rows[index].icons
	end
end
equal(matches, HUNTER_ICONS, "search found the wrong number of Hunter icons")

-- Selecting an icon names it in the status line, read lazily from the client table.
picker:SetSearch("")
picker:SetSelected(FIRST)
equal(picker.statusText.text, names[FIRST], "the status line did not name the selected icon")

print(("icon picker: %d checks, two Opens %.6fs and %.6fs"):format(checks, firstOpen, secondOpen))
