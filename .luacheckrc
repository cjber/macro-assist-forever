std = "lua51"
max_line_length = 120
exclude_files = { "forever-core/**", "tools/.cache/**", "tools/forever_tools/**", ".release/**", ".types/**", "types/**", ".claude/**", ".agents/**", ".bugpatrol/runs/**", ".speedpatrol/runs/**", ".sloppatrol/runs/**" }
ignore = { "212/_.*" } -- unused args prefixed with _

globals = { "MacroAssistForever", "MacroAssistForeverDB", "SlashCmdList" }

read_globals = {
	"C_AddOns", "CreateFrame", "ChatFontNormal", "GetLocale",
	"date", "InCombatLockdown",
	"UIParent",
	-- The macro window and editor.
	"canaccessvalue", "Constants", "CreateAndInitFromMixin", "CreateDataProvider", "CreateFont",
	"CreateMacro", "CreateScrollBoxListLinearView", "C_Container", "C_Item", "C_Spell", "C_SpellBook",
	"DeleteMacro", "EditMacro",
	"Enum", "EventRegistry", "FONT_COLOR_CODE_CLOSE", "GameFontHighlightSmall", "GameTooltip", "GetCursorPosition", "GetFlyoutInfo",
	"GetFlyoutSlotInfo", "GetInventoryItemLink", "GetInventoryItemTexture", "GREEN_FONT_COLOR_CODE",
	"GetActionInfo", "GetActionText", "GetBindingKey", "GetBindingText",
	"GetMacroIndexByName", "GetMacroInfo", "GetServerTime",
	"GetNumMacros", "HideUIPanel", "hooksecurefunc", "IsModifiedClick", "GetCursorInfo", "ClearCursor",
	"IconDataProviderExtraType", "IconDataProviderMixin",
	"INVSLOT_FIRST_EQUIPPED", "INVSLOT_LAST_EQUIPPED", "MacroFrame",
	"NUM_BAG_SLOTS", "NORMAL_FONT_COLOR", "BreakUpLargeNumbers",
	"PickupMacro", "ScrollBoxConstants", "ScrollUtil", "SecureCmdOptionParse", "SetPortraitTexture", "UnitClass",
	"UnitName", "UnitFullName", "GetRealmName",
	-- The current group, read for name completion.
	"GetNumGroupMembers", "IsInRaid",
	-- The slash command, the addon compartment and the gamepad input style.
	"C_InputInterfaceStyle", "ShowMacroFrame",
	"SLASH_MACROASSISTFOREVER1", "SLASH_MACROASSISTFOREVER2",
	"SLASH_USE1", "SLASH_EQUIP1", "SLASH_CAST1",
	-- ForeverCore, the addon this one requires.
	"ForeverCore",
}

files["Locales/"] = { max_line_length = false } -- one phrase per line, however long
files["tests/"] = { std = "+luajit" }
