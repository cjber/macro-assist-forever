local addonName, ns = ...

if ns.broken then
	return
end

-- Our window builds and opens without Blizzard_MacroUI; this file never loads that addon. When Blizzard_MacroUI
-- loads, by the player's /macro, the game menu or a keybind, Attach re-anchors our window to MacroFrame and hooks its
-- show and hide. Nothing in here runs Blizzard's Lua on its frame: HookScript and the engine's own reads and alpha
-- call are the only contact, as WFA-38 allows.

-- ForeverCore's report window reads these when the player opens it: the macro counts, the history kept, and whether
-- our window has been built, which is where a macro bug usually starts. English throughout, like the report's field
-- labels, so one report reads the same in every locale.
---@return string[]
function ns.ReportLines()
	local general, character = GetNumMacros()
	local kept = 0
	if type(MacroAssistForeverDB) == "table" then
		for _ in pairs(MacroAssistForeverDB.history or {}) do
			kept = kept + 1
		end
	end
	return {
		("Macros: %d general, %d character"):format(general, character),
		("History: %d macros kept, at most %d versions each"):format(kept, ns.History.LIMIT),
		("Window: %s"):format(ns.MacroWindow.frame and "built" or "not built"),
	}
end

-- The shared services, registered once: the report window's title and this addon's own report lines. The journal and
-- the log are ForeverCore's, kept in this addon's own saved table.
ns.core = ForeverCore.Register(addonName, {
	title = ns.ReportTitle,
	lines = function()
		return ns.ReportLines()
	end,
})

-- Hands the generated player credits to the shared Thanks page (WFA-31). An older core has no Credits module, and the
-- addon loads as before.
if type(ForeverCore.Credits) == "table" then
	ns.core.SafeCall("credits", ForeverCore.Credits.Register, "Macro Assist Forever", ns.Credits)
end

local addon = CreateFrame("Frame")
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("UPDATE_MACROS")

-- Every saved key's default. A new option and an old save file agree because the load fills only a missing key.
ns.DEFAULTS = {
	history = {},
}

local attached = false
local function Attach()
	if not MacroFrame then
		return
	end
	ns.MacroWindow.Create()
	ns.MacroWindow.AttachToMacroFrame()
	if not attached then
		attached = true
		MacroFrame:HookScript("OnShow", function(frame)
			local window = ns.MacroWindow.frame
			frame:SetAlpha(0)
			window.CloseButton:Hide()
			window:Show()
		end)
		MacroFrame:HookScript("OnHide", function(frame)
			local window = ns.MacroWindow.frame
			if window then
				window:Hide()
				window.CloseButton:Show()
			end
			frame:SetAlpha(1)
		end)
	end
	if MacroFrame:IsShown() then
		MacroFrame:SetAlpha(0)
		local window = ns.MacroWindow.frame
		window.CloseButton:Hide()
		window:Show()
	end
end

-- Every way in (/macroassist and the addon compartment) opens the same window and closes it again only while it
-- stands alone. ShowMacroFrame is called only once Blizzard_MacroUI is loaded and the panel manager can take it: that
-- is the function Blizzard's own /macro handler calls (Blizzard_ChatFrameBase/Shared/SlashCommands.lua), so
-- Blizzard's panel sits at alpha 0 underneath. A paired panel is left open here, because hiding it from addon code
-- would run the panel manager under our taint; the player closes it with the X or Escape. Otherwise open the
-- standalone window. Nothing here loads Blizzard_MacroUI.
function ns.Toggle()
	local panel = MacroFrame
	local window = ns.MacroWindow.frame
	local panelShown = panel ~= nil and panel:IsShown()
	local windowShown = window ~= nil and window:IsShown()
	if panelShown or windowShown then
		ns.MacroWindow.ClosePanel()
	elseif panel and ns.MacroWindow.CanManagePanel() and ShowMacroFrame then
		ShowMacroFrame()
	else
		ns.MacroWindow.Create()
		ns.MacroWindow.frame:Show()
	end
end

addon:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_LOGIN" or event == "UPDATE_MACROS" then
		if type(MacroAssistForeverDB) == "table" and ns.CharacterMacros then
			ns.CharacterMacros.CaptureCurrent(MacroAssistForeverDB)
		end
		return
	end
	if event == "ADDON_LOADED" and name == addonName then
		-- The slash command goes in first, so a startup error below still leaves /macroassist answering.
		_G.SLASH_MACROASSISTFOREVER1 = "/macroassist"
		SlashCmdList.MACROASSISTFOREVER = function(message)
			local command = type(message) == "string" and message:lower():match("^%s*(.-)%s*$") or ""
			if ns.core.Report.Command(command) then
				return
			end
			ns.Toggle()
		end
		MacroAssistForeverDB = type(MacroAssistForeverDB) == "table" and MacroAssistForeverDB or {}
		for key, value in pairs(ns.DEFAULTS) do
			if MacroAssistForeverDB[key] == nil then
				MacroAssistForeverDB[key] = type(value) == "table" and {} or value
			end
		end
		ns.History.Initialize(MacroAssistForeverDB)
		-- Blizzard_MacroUI_Bootstrap.lua defines ShowMacroFrame at startup, before the load-on-demand UI itself.
		Attach() -- Blizzard_MacroUI may already be loaded by another addon
		-- The journal and the log are ForeverCore's, kept under `errors` and `log` in this table, the same keys the
		-- vendored files used, so a /reload keeps earlier sessions' errors.
		ns.core.Attach(MacroAssistForeverDB)
	elseif event == "ADDON_LOADED" and name == "Blizzard_MacroUI" then
		Attach()
	end
end)

-- The addon compartment entry (## AddonCompartmentFunc) uses the same toggle.
_G.MacroAssistForever_OnAddonCompartmentClick = function()
	ns.Toggle()
end
