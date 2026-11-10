std = "lua51"
max_line_length = 120
exclude_files = { "forever-core/**", "tools/.cache/**", "tools/forever_tools/**", ".release/**", ".types/**", "types/**", ".claude/**", ".agents/**", ".bugpatrol/runs/**", ".speedpatrol/runs/**", ".sloppatrol/runs/**" }
ignore = { "212/_.*" } -- unused args prefixed with _

globals = { "MacroAssistForeverDB", "SlashCmdList" }

read_globals = {
	"CreateFrame",
	"date", "InCombatLockdown",
	"UIParent",
	-- The macro window and editor.
	"canaccessvalue", "Constants", "CreateAndInitFromMixin", "CreateDataProvider", "CreateFont",
	"CreateMacro", "CreateScrollBoxListLinearView", "C_Spell", "C_SpellBook", "DeleteMacro", "EditMacro",
	"Enum", "GameFontHighlightSmall", "GameTooltip", "GetCursorPosition", "GetFlyoutInfo", "GetFlyoutSlotInfo",
	"GetMacroInfo", "GetServerTime",
	"GetNumMacros", "HideUIPanel", "hooksecurefunc",
	"IconDataProviderExtraType", "IconDataProviderMixin",
	"IconSelectorPopupFrameTemplateMixin", "MacroFrame", "NORMAL_FONT_COLOR",
	"PickupMacro", "ScrollBoxConstants", "ScrollUtil", "SecureCmdOptionParse", "SetPortraitTexture", "UnitName",
	-- The slash command, the addon compartment and the gamepad input style.
	"C_InputInterfaceStyle", "ShowMacroFrame",
	"SLASH_MACROASSISTFOREVER1", "SLASH_MACROASSISTFOREVER2",
	-- ForeverCore, the addon this one requires.
	"ForeverCore",
}

files["Locales/"] = { max_line_length = false } -- one phrase per line, however long
files["tests/"] = { std = "+luajit" }
