std = "lua51"
max_line_length = 120
exclude_files = { "tools/.cache/**", "tools/forever_tools/**", ".release/**", ".types/**", "types/**", ".claude/**", ".agents/**", ".bugpatrol/runs/**", ".speedpatrol/runs/**", ".sloppatrol/runs/**" }
ignore = { "212/_.*" } -- unused args prefixed with _

globals = { "ForeverFamily", "MacroAssistForeverDB" }

read_globals = {
	"C_AddOns", "C_Map", "ChatFontNormal", "CreateFrame", "CreateSettingsButtonInitializer",
	"date", "debugstack", "GameFontNormal", "GetBuildInfo", "GetLocale", "geterrorhandler",
	"GetTime", "InCombatLockdown", "InputUtil", "seterrorhandler", "Settings", "strtrim",
	"tContains", "UIParent", "UISpecialFrames", "UnitClass", "UnitFactionGroup", "UnitLevel", "UnitRace",
	-- The macro window and editor.
	"canaccessvalue", "Constants", "CreateAndInitFromMixin", "CreateDataProvider", "CreateFont",
	"CreateMacro", "CreateScrollBoxListLinearView", "C_Spell", "C_SpellBook", "DeleteMacro", "EditMacro",
	"Enum", "GameFontHighlightSmall", "GameTooltip", "GetMacroInfo", "GetNumMacros", "HideUIPanel",
	"IconDataProviderExtraType", "IconDataProviderMixin", "IconSelectorPopupFrameIconFilterTypes",
	"IconSelectorPopupFrameTemplateMixin", "MacroFrame", "NORMAL_FONT_COLOR", "PickupMacro",
	"ScrollBoxConstants", "ScrollUtil", "SecureCmdOptionParse", "UnitName",
}

files["Locales/"] = { max_line_length = false } -- one phrase per line, however long
files["tests/"] = { std = "+luajit" }
