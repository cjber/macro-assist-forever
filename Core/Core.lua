local addonName, ns = ...

-- Our window builds and opens without Blizzard_MacroUI; this file never loads that addon. When Blizzard_MacroUI
-- loads, by the player's /macro, the game menu or a keybind, Attach re-anchors our window to MacroFrame and hooks its
-- show and hide. Nothing in here runs Blizzard's Lua on its frame: HookScript and the engine's own reads and alpha
-- call are the only contact, as WFA-38 allows.

local addon = CreateFrame("Frame")
addon:RegisterEvent("ADDON_LOADED")

-- Every saved key's default. A new option and an old save file agree because the load fills only a missing key.
ns.DEFAULTS = {
	history = {},
}

local attached = false
-- True when the MacroFrame OnShow hook has just run inside the ShowMacroFrame call that is still on the stack.
-- The post-hook reads it to tell "this call opened the panel" from "the panel was already open", then clears it.
local panelJustShowed = false
-- True when the OnShow hook found our own window already shown, as a cold /macroassist leaves it. The post-hook
-- then closes the pair, because that /m press found the window open.
local windowWasShown = false

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
			windowWasShown = window ~= nil and window:IsShown()
			panelJustShowed = true
			frame:SetAlpha(0)
			window:Show()
		end)
		MacroFrame:HookScript("OnHide", function(frame)
			panelJustShowed = false
			windowWasShown = false
			if ns.MacroWindow.frame then
				ns.MacroWindow.frame:Hide()
			end
			frame:SetAlpha(1)
		end)
	end
	if MacroFrame:IsShown() then
		MacroFrame:SetAlpha(0)
		ns.MacroWindow.frame:Show()
	end
end

-- The panel manager refuses an addon's ShowUIPanel and HideUIPanel in combat. Under the gamepad interface, Blizzard's
-- frame controls manager takes every panel that shows into its focus in the same call, so a show or hide an addon
-- starts taints the protected call that follows (#158). In both cases our own window opens and closes by itself.
local function PanelManagerAvailable()
	local styles, api = Enum and Enum.InputDeviceInterfaceType, C_InputInterfaceStyle
	local gamepad = styles ~= nil
		and api ~= nil
		and api.GetCurrentStyle ~= nil
		and api.GetCurrentStyle() == styles.Gamepad
	return not InCombatLockdown() and not gamepad
end

-- ShowMacroFrame is what /macro, /m, the game menu's Macros button and the chat menu all call. Our OnShow hook
-- runs first in the call that actually opens the panel; when it did not run, the panel was already open, so this
-- second press of the same command closes the pair. When it did run but found our window already shown, a cold
-- /macroassist left it there, so this /m press closes the pair as well. Combat and the gamepad interface refuse an
-- addon's hide, as ns.Toggle already knows, so there the pair stays open.
local function AfterShowMacroFrame()
	if panelJustShowed then
		panelJustShowed = false
		local foundOpen = windowWasShown
		windowWasShown = false
		if foundOpen and PanelManagerAvailable() then
			ns.MacroWindow.ClosePanel()
		end
		return
	end
	if MacroFrame and MacroFrame:IsShown() and PanelManagerAvailable() then
		ns.MacroWindow.ClosePanel()
	end
end

-- Every way in (/macroassist and the addon compartment) toggles the same window. ShowMacroFrame is called only
-- once Blizzard_MacroUI is loaded and the panel manager can take it: that is the function Blizzard's own /macro
-- handler calls (Blizzard_ChatFrameBase/Shared/SlashCommands.lua), so Blizzard's panel sits at alpha 0 underneath.
-- Every other case opens or closes our own window by itself, and nothing here loads Blizzard_MacroUI.
function ns.Toggle()
	local panel = MacroFrame
	local window = ns.MacroWindow.frame
	local panelShown = panel ~= nil and panel:IsShown()
	local windowShown = window ~= nil and window:IsShown()
	if panelShown or windowShown then
		-- The panel manager refuses an addon's hide in combat or under the gamepad interface, so a pair opened
		-- before then stays together until it can close.
		if panelShown and not PanelManagerAvailable() then
			return
		end
		ns.MacroWindow.ClosePanel()
	elseif panel and PanelManagerAvailable() and ShowMacroFrame then
		ShowMacroFrame()
	else
		ns.MacroWindow.Create()
		ns.MacroWindow.frame:Show()
	end
end

addon:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		MacroAssistForeverDB = type(MacroAssistForeverDB) == "table" and MacroAssistForeverDB or {}
		for key, value in pairs(ns.DEFAULTS) do
			if MacroAssistForeverDB[key] == nil then
				MacroAssistForeverDB[key] = type(value) == "table" and {} or value
			end
		end
		ns.History.Initialize(MacroAssistForeverDB)
		_G.SLASH_MACROASSISTFOREVER1 = "/macroassist"
		SlashCmdList.MACROASSISTFOREVER = function()
			ns.Toggle()
		end
		-- Blizzard_MacroUI_Bootstrap.lua defines ShowMacroFrame at startup, before the load-on-demand UI itself.
		hooksecurefunc("ShowMacroFrame", AfterShowMacroFrame)
		Attach() -- Blizzard_MacroUI may already be loaded by another addon
	elseif event == "ADDON_LOADED" and name == "Blizzard_MacroUI" then
		Attach()
	end
end)

-- The addon compartment entry (## AddonCompartmentFunc) uses the same toggle.
_G.MacroAssistForever_OnAddonCompartmentClick = function()
	ns.Toggle()
end
