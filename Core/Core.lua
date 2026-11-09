local addonName = ...

local addon = CreateFrame("Frame")
addon:RegisterEvent("ADDON_LOADED")
addon:SetScript("OnEvent", function(_, event, name)
	if event ~= "ADDON_LOADED" or name ~= addonName then
		return
	end
	MacroAssistForeverDB = type(MacroAssistForeverDB) == "table" and MacroAssistForeverDB or {}
end)
