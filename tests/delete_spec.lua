-- Delete's bookkeeping when the client refreshes macros inside DeleteMacro. UPDATE_MACROS can clear the selection
-- before Delete returns, so the index it deletes must be captured first and still clear that macro's draft.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end
local function yes(value, label)
	checks = checks + 1
	assert(value, label)
end

local ns = {}
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("MacroAssistForever", ns)
end
load("Locales/enUS.lua")
load("UI/MacroWindow.lua")

local Window = assert(ns.MacroWindow, "the macro window is not published")
local macros = {
	[121] = { name = "Last", icon = 134400, body = "/cast Arcane Shot" },
}
local drafts = { [121] = "/cast Wings Clip" }
local snapshots = 0
ns.History = {
	Snapshot = function()
		snapshots = snapshots + 1
	end,
}

_G.MacroAssistForeverDB = {}
_G.GetMacroInfo = function(index)
	local macro = macros[index]
	if macro then
		return macro.name, macro.icon, macro.body
	end
end
_G.InCombatLockdown = function()
	return false
end
local window
local deleted
_G.DeleteMacro = function(index)
	deleted = index
	macros[index] = nil
	-- The window's UPDATE_MACROS handler runs synchronously here: the tab is now empty, so it clears the selection.
	window.selected = nil
end

window = setmetatable({
	selected = 121,
	base = 120,
	drafts = drafts,
	deleteArmed = true,
	dirty = true,
	pendingName = "Last",
	pendingIcon = 132204,
	picking = false,
}, { __index = Window })
function window.Now(_)
	return 1
end
function window.TabForIndex(_, index)
	return index > 120 and 2 or 1
end
function window.RefreshList(_) end

Window.Delete(window)

equal(deleted, 121, "Delete wrote the wrong macro index")
equal(window.selected, nil, "Delete left a selection after the tab emptied")
equal(drafts[121], nil, "Delete left the deleted macro's draft")
equal(window.desiredPosition, 1, "Delete did not keep the deleted position for the list")
equal(window.deleteArmed, false, "Delete stayed armed")
equal(snapshots, 1, "Delete did not snapshot the macro before removing it")
yes(next(drafts) == nil, "a draft survived the delete")

print(("delete: %d checks"):format(checks))
