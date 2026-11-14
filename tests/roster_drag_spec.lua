-- Source-owned gesture callbacks, independent of native cursor delivery or a running client.
local ns = {}
assert(loadfile("Locales/enUS.lua"))("MacroAssistForever", ns)
assert(loadfile("Core/Lexer.lua"))("MacroAssistForever", ns)
assert(loadfile("Core/Parser.lua"))("MacroAssistForever", ns)
assert(loadfile("UI/Editor.lua"))("MacroAssistForever", ns)
assert(loadfile("UI/Roster.lua"))("MacroAssistForever", ns)
local checks = 0
local function equal(actual, expected)
	checks = checks + 1
	assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local cursor, over, shown, inserted = nil, true, true, nil
_G.GetCursorInfo = function()
	return cursor
end
local editor = setmetatable(
	{ edit = {
		IsShown = function()
			return shown
		end,
		IsMouseOver = function()
			return over
		end,
	} },
	{ __index = ns.Editor }
)
editor.DropTextUnderPointer = function(_, text)
	inserted = text
	return true
end
local function source(name)
	local scripts = {}
	local row = {
		Name = { SetText = function() end, SetTextColor = function() end },
		RegisterForDrag = function() end,
		RegisterEvent = function(_, event)
			equal(event, "CURSOR_CHANGED")
		end,
		SetScript = function(_, event, callback)
			scripts[event] = callback
		end,
	}
	local function frame()
		return setmetatable({}, {
			__index = function(_, key)
				if key == "CreateFontString" then
					return frame
				end
				return function() end
			end,
		})
	end
	_G.CreateFrame = frame
	_G.CreateDataProvider = frame
	_G.CreateScrollBoxListLinearView = function()
		return {
			SetElementExtent = function() end,
			SetElementInitializer = function(_, _, initialize)
				initialize(row, { name = name })
			end,
		}
	end
	_G.ScrollUtil = { InitScrollBoxListWithScrollBar = function() end }
	_G.ScrollBoxConstants = {}
	_G.IsInRaid = function()
		return false
	end
	_G.GetNumGroupMembers = function()
		return 0
	end
	ns.Roster = {
		Read = function()
			return false, false, {}
		end,
	}
	ns.L = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	})
	ns.RosterPanel.Create({}, editor)
	return scripts
end

local row, other = source("Barry-Realm"), source("Other")
row.OnDragStart()
row.OnDragStop()
equal(inserted, "Barry-Realm")
equal(editor.textDrag, nil)
inserted = nil
row.OnDragStart()
over = false
row.OnDragStop()
over = true
equal(inserted, nil)
equal(editor.textDrag, nil)
row.OnDragStart()
row.OnHide()
row.OnDragStop()
equal(inserted, nil)
row.OnDragStart()
cursor = "item"
row.OnEvent()
row.OnDragStop()
equal(inserted, nil)
equal(cursor, "item")
cursor = nil
row.OnDragStart()
editor:ReceiveDrag()
row.OnDragStop()
equal(inserted, nil)
row.OnDragStart()
cursor = "spell"
row.OnDragStop()
equal(inserted, nil)
equal(cursor, "spell")
row.OnDragStart()
cursor = nil
row.OnDragStop()
equal(inserted, nil) -- starting over an occupied native cursor never claims it
row.OnDragStart()
other.OnDragStop()
equal(editor.textDrag.text, "Barry-Realm")
row.OnDragStop()
equal(inserted, "Barry-Realm")
inserted = nil
row.OnDragStart()
shown = false
row.OnDragStop()
shown = true
equal(inserted, nil)
equal(editor.textDrag, nil)
row.OnDragStart()
editor:EndTextDrag(nil, false)
row.OnDragStop()
equal(inserted, nil)
-- The drop uses the same measured rows as clicks, including effective UI scale and later lines.
local body = "/raid Tank 1: <name>\n/raid Heal: <other>"
local measure = {
	width = function(text)
		return #text * 8
	end,
}
local actualEditor = setmetatable({
	edit = {
		GetLeft = function()
			return 100
		end,
		GetTop = function()
			return 200
		end,
		GetEffectiveScale = function()
			return 0.75
		end,
	},
	rows = ns.Editor.LayoutRows(body, 1000, 20, measure),
	lineHeight = 20,
	textMeasure = measure,
}, { __index = ns.Editor })
local target = body:find("<other>", 1, true) - 1
local secondStart = body:find("\n", 1, true)
_G.GetCursorPosition = function()
	return (100 + (target - secondStart) * 8 + 1) * 0.75, 170 * 0.75
end
actualEditor.DropTextAt = function(_, text, position)
	inserted = ns.Editor.ReplaceWord(body, position, text)
	return true
end
equal(actualEditor:DropTextUnderPointer("Barry-Realm"), true)
equal(inserted, "/raid Tank 1: <name>\n/raid Heal: Barry-Realm")
_G.GetCursorPosition = function()
	return nil, nil
end
equal(actualEditor:DropTextUnderPointer("Barry-Realm"), false)
print(("roster drag: %d checks"):format(checks))
