-- The scaffold: the TOC's files load in order under a stubbed client, and the addon creates its saved table.
local function equal(actual, expected, label)
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

local frames = {}
_G.CreateFrame = function(kind)
	local frame = { kind = kind, events = {} }
	function frame:RegisterEvent(event)
		self.events[event] = true
	end
	function frame:SetScript(script, handler)
		self[script] = handler
	end
	frames[#frames + 1] = frame
	return frame
end
_G.geterrorhandler = function()
	return function() end
end
_G.seterrorhandler = function() end
_G.SlashCmdList = {}

local ns = {}
local addonName = "MacroAssistForever"

local toc = assert(io.open("MacroAssistForever.toc", "r"))
local loaded = {}
for line in toc:lines() do
	local entry = line:match("^%s*([^#%s].*)$")
	if entry then
		entry = entry:gsub("\\", "/"):gsub("%s+$", "")
		if entry:match("%.lua$") then
			local chunk = assert(loadfile(entry))
			chunk(addonName, ns)
		end
		loaded[#loaded + 1] = entry
	end
end
toc:close()

equal(loaded[1], "Locales/enUS.lua", "the locale loads first")
equal(loaded[#loaded], "Core/Core.lua", "the core loads last")
equal(type(ns.L), "table", "the locale table is published")
equal(type(ns.SafeCall), "function", "the shared error journal is loaded")
equal(type(ns.Log), "function", "the shared log is loaded")
equal(type(ns.Family), "table", "the shared family links are loaded")
equal(type(ns.Report), "table", "the shared report window is loaded")

local addon
for _, frame in ipairs(frames) do
	if frame.events.ADDON_LOADED and frame.OnEvent then
		addon = frame
	end
end
assert(addon, "Core/Core.lua registers for ADDON_LOADED")

addon.OnEvent(addon, "ADDON_LOADED", "SomeOtherAddon")
equal(MacroAssistForeverDB, nil, "another addon's load does not initialise this one")

addon.OnEvent(addon, "ADDON_LOADED", addonName)
assert(type(MacroAssistForeverDB) == "table", "ADDON_LOADED creates the saved table")

equal(SLASH_MACROASSISTFOREVER1, "/ma", "the short command is registered")
equal(SLASH_MACROASSISTFOREVER2, "/macroassist", "the full command is registered")
equal(type(SlashCmdList.MACROASSISTFOREVER), "function", "the command has a handler")

MacroAssistForeverDB.kept = true
addon.OnEvent(addon, "ADDON_LOADED", addonName)
equal(MacroAssistForeverDB.kept, true, "a saved value is kept")

print("scaffold_spec: the TOC loads and the addon initialises")
