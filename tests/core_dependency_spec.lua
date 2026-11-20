-- Run from the repository root: luajit tests/core_dependency_spec.lua
-- Core/Require.lua computes whether the loaded ForeverCore has the member this addon calls, and hands the warning to
-- Core/ForeverRequire.lua. The shared warning's own cases are ForeverCore's tests/forever_require_spec.lua; this
-- checks the two sides meet: a core missing required members stops with one line, and a complete one loads on.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

-- The TOC's own fields, as C_AddOns.GetAddOnMetadata answers them in the client.
local metadata = {}
local toc = assert(io.open("MacroAssistForever.toc", "r"))
for line in toc:lines() do
	local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
	if key then
		metadata[key] = value
	end
end
toc:close()

local ADDON = "MacroAssistForever"
local TITLE = metadata["Title"]
assert(metadata["X-Forever-Core"], "the TOC names the ForeverCore release it bundles")

local messages = {}
local addons = {
	{
		name = ADDON,
		title = TITLE,
		tag = metadata["X-Forever-Core"],
		loaded = true,
		enabled = 2,
		coreDependency = true,
	},
	{
		name = "OtherForever",
		title = "Other Forever",
		tag = "v1.4.1",
		loaded = true,
		enabled = 2,
		coreDependency = true,
	},
	{ name = "ForeverCore", title = "ForeverCore", loaded = true, enabled = 2 },
}

_G.C_AddOns = {
	GetNumAddOns = function()
		return #addons
	end,
	GetAddOnInfo = function(index)
		return addons[index] and addons[index].name
	end,
	GetAddOnMetadata = function(target, field)
		local item = type(target) == "number" and addons[target] or nil
		if type(target) == "string" then
			for _, addon in ipairs(addons) do
				if addon.name == target then
					item = addon
					break
				end
			end
		end
		if not item then
			return nil
		end
		if field == "X-Curse-Project-ID" and item.name == "ForeverCore" then
			return "1796337"
		end
		if field == "X-Forever-Icon" then
			return metadata["X-Forever-Icon"]
		end
		if field == "Title" then
			return item.title
		end
		if field == "X-Forever-Core" then
			return item.tag
		end
		return nil
	end,
	IsAddOnLoaded = function(index)
		return addons[index] and addons[index].loaded == true
	end,
	GetAddOnEnableState = function(index)
		return addons[index] and addons[index].enabled or 0
	end,
	-- The client answers one return per dependency, never a table.
	GetAddOnDependencies = function(index)
		if addons[index] and addons[index].coreDependency then
			return "ForeverCore" -- multi-value: one return per dependency
		end
	end,
	GetAddOnOptionalDependencies = function() end,
}
_G.UnitName = function(unit)
	assert(unit == "player", "asks about the player")
	return "Tester"
end
_G.UIErrorsFrame = {
	AddMessage = function(_, text, red)
		messages[#messages + 1] = { text = text, red = red }
	end,
}

-- Loads the files in TOC order: the locale, the shared warning, then this addon's ready check.
local function Run(core)
	messages = {}
	_G.ForeverCore = core
	local ns = {}
	assert(loadfile("Locales/enUS.lua"))(ADDON, ns)
	assert(loadfile("Core/ForeverRequire.lua"))(ADDON, ns)
	assert(loadfile("Core/Require.lua"))(ADDON, ns)
	return ns
end

-- No ForeverCore global, with its folder installed: the addon stops.
local absent = Run(nil)
check(absent.broken == true, "a missing ForeverCore marks the addon broken")
check(#messages == 1, "a missing ForeverCore shows one line")

-- A ForeverCore with no Register: Core/Core.lua could not register this addon, so the addon stops.
local older = Run({ API = 1 })
check(older.broken == true, "a core without Register marks the addon broken")
check(#messages == 1, "exactly one line is shown")
check(messages[1].red == 1, "the line is red")
check(
	messages[1].text:find("Other Forever", 1, true) ~= nil,
	"the line names the other addon whose download brings this core"
)

-- Without an installed folder, the warning explains how to install the core.
local coreAddon = table.remove(addons)
local missing = Run(nil)
check(missing.broken == true, "an uninstalled core marks the addon broken")
check(#messages == 1, "an uninstalled core shows exactly one line")
check(messages[1].red == 1, "the missing folder line is red")
check(
	messages[1].text
		== "Macro Assist Forever needs ForeverCore. Install it from CurseForge, "
			.. "or choose Reinstall on ForeverCore in the CurseForge app.",
	"the missing folder line gives the exact installation instructions"
)
addons[#addons + 1] = coreAddon

-- An installed but disabled core needs enabling rather than reinstalling.
coreAddon.loaded = false
coreAddon.enabled = 0
local disabled = Run(nil)
check(disabled.broken == true, "a disabled core marks the addon broken")
check(#messages == 1, "a disabled core shows exactly one line")
check(messages[1].red == 1, "the disabled core line is red")
check(
	messages[1].text == "Macro Assist Forever: ForeverCore is turned off. Enable it in the AddOns list to fix this.",
	"the disabled core line gives the exact enable instructions"
)
coreAddon.loaded = true
coreAddon.enabled = 2

-- A core with the member this addon calls: the addon loads and nothing is shown.
local kit = {
	Invalid = function()
		return nil, "invalid"
	end,
	Publish = function() end,
}
for _, partial in ipairs({
	{ Register = function() end },
	{ Register = function() end, APIKit = {} },
	{ Register = function() end, APIKit = { Invalid = kit.Invalid } },
	{ Register = function() end, APIKit = { Publish = kit.Publish } },
	{ Register = function() end, APIKit = kit },
}) do
	local incomplete = Run(partial)
	check(incomplete.broken == true, "a core missing an APIKit member or CharacterKey stops the addon")
	check(#messages == 1, "a core missing an APIKit member or CharacterKey shows one warning")
end
local complete = Run({ API = 1, Register = function() end, APIKit = kit, CharacterKey = function() end })
check(complete.broken == nil, "a complete core leaves the addon unbroken")
check(#messages == 0, "a complete core shows nothing")
check(type(complete.ForeverRequire) == "function", "the shared warning is loaded")
check(complete.Icon == metadata["X-Forever-Icon"], "the TOC identity icon is read")

print(("core_dependency_spec: %d checks passed"):format(checks))
