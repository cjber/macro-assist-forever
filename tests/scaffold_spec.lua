-- The scaffold: the TOC's files load in order under a stubbed client and ForeverCore, and the addon creates its saved
-- table and registers once. ForeverCore itself is real in the sim (tests/sim) and in the client; here it is the one
-- context table Core/Core.lua calls, with no frames behind it.
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
_G.hooksecurefunc = function() end
_G.ShowMacroFrame = function() end
_G.GetNumMacros = function()
	return 2, 3
end
_G.SlashCmdList = {}

local registered, attached
local context = {
	Report = {
		Command = function(command)
			return command == "report"
		end,
	},
	Attach = function(db)
		attached = db
	end,
}
_G.ForeverCore = {
	API = 1,
	Register = function(name, spec)
		registered = { name = name, spec = spec }
		return context
	end,
}

local ns = {}
local addonName = "MacroAssistForever"
local metadata = {}

-- C_AddOns.GetAddOnMetadata as the client answers it: a TOC field of the named addon.
_G.C_AddOns = {
	GetAddOnMetadata = function(name, key)
		return name == addonName and metadata[key] or nil
	end,
}

local toc = assert(io.open("MacroAssistForever.toc", "r"))
local loaded = {}
for line in toc:lines() do
	local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
	if key then
		metadata[key] = value
	end
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

equal(metadata["Dependencies"], "ForeverCore", "the TOC requires ForeverCore")
equal(loaded[1], "Locales/enUS.lua", "the locale loads first")
equal(loaded[2], "Core/Require.lua", "the API floor follows it, before any addon code")
equal(loaded[#loaded], "Core/Core.lua", "the core loads last")
for _, shared in ipairs({ "Core/SafeCall.lua", "Core/Log.lua", "UI/Report.lua", "UI/ForeverFamily.lua" }) do
	for _, entry in ipairs(loaded) do
		assert(entry ~= shared, "the TOC still lists " .. shared)
	end
end
equal(type(ns.L), "table", "the locale table is published")
equal(ns.ReportTitle, "Macro Assist Forever report", "the report title is set")
equal(ns.Icon, metadata["X-Forever-Icon"], "the identity icon is the TOC's X-Forever-Icon")
assert(ns.Icon and ns.Icon ~= "", "the TOC declares no X-Forever-Icon")

assert(registered, "the addon registered its ForeverCore services")
equal(registered.name, addonName, "under its own folder name")
equal(registered.spec.title, ns.ReportTitle, "the report window takes the addon's title")
local lines = registered.spec.lines()
equal(lines[1], "Macros: 2 general, 3 character", "the report reads the client's macro counts")
assert(lines[2]:find("History: 0 macros kept", 1, true), "and the history it keeps")
assert(lines[3]:find("Window: not built", 1, true), "and whether the window is built")
assert(ns.core == context, "ns.core is the context Register returned")

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
assert(attached == MacroAssistForeverDB, "the saved table is attached to ForeverCore")
equal(MacroAssistForeverDB.errors, nil, "the addon's old journal key is gone")
equal(MacroAssistForeverDB.log, nil, "the addon's old log key is gone")

equal(SLASH_MACROASSISTFOREVER1, "/macroassist", "the full command is registered")
equal(SLASH_MACROASSISTFOREVER2, nil, "the client's /ma is not registered")
equal(type(SlashCmdList.MACROASSISTFOREVER), "function", "the command has a handler")

local toggled = false
ns.Toggle = function()
	toggled = true
end
SlashCmdList.MACROASSISTFOREVER("report")
equal(toggled, false, "/macroassist report opens the report instead of toggling")
SlashCmdList.MACROASSISTFOREVER("")
equal(toggled, true, "a bare /macroassist still toggles the window")

MacroAssistForeverDB.kept = true
addon.OnEvent(addon, "ADDON_LOADED", addonName)
equal(MacroAssistForeverDB.kept, true, "a saved value is kept")

print("scaffold_spec: the TOC loads and the addon initialises")
