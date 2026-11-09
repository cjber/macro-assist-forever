local addonName, ns = ...

-- The addon frame loads our window when Blizzard_MacroUI loads, and hooks its show and hide. Nothing in here runs
-- Blizzard's Lua on its frame: HookScript and the engine's own reads and alpha call are the only contact, as WFA-38
-- allows.

local addon = CreateFrame("Frame")
addon:RegisterEvent("ADDON_LOADED")

local attached = false

local function Attach()
	if attached or not MacroFrame then
		return
	end
	attached = true
	ns.MacroWindow.Create()
	MacroFrame:HookScript("OnShow", function(frame)
		frame:SetAlpha(0)
		ns.MacroWindow.frame:Show()
	end)
	MacroFrame:HookScript("OnHide", function(frame)
		if ns.MacroWindow.frame then
			ns.MacroWindow.frame:Hide()
		end
		frame:SetAlpha(1)
	end)
	if MacroFrame:IsShown() then
		MacroFrame:SetAlpha(0)
		ns.MacroWindow.frame:Show()
	end
end

addon:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == addonName then
		MacroAssistForeverDB = type(MacroAssistForeverDB) == "table" and MacroAssistForeverDB or {}
		Attach() -- Blizzard_MacroUI may already be loaded by another addon
	elseif event == "ADDON_LOADED" and name == "Blizzard_MacroUI" then
		Attach()
	end
end)
