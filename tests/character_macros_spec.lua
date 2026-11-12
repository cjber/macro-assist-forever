local ns = {}
assert(loadfile("Locales/enUS.lua"))("MacroAssistForever", ns)
assert(loadfile("Core/Length.lua"))("MacroAssistForever", ns)
assert(loadfile("Core/History.lua"))("MacroAssistForever", ns)
assert(loadfile("Core/CharacterMacros.lua"))("MacroAssistForever", ns)
local C = ns.CharacterMacros
local db = {}
C.Capture(
	db,
	"Barry",
	"Azeroth",
	{ { name = "Heal", body = "/cast Heal" } },
	{ { name = "Trap", body = "/cast Trap" } }
)
C.Capture(
	db,
	"Cillian",
	"Azeroth",
	{ { name = "Heal", body = "/cast Flash Heal" } },
	{ { name = "Trap", body = "/cast Trap" } }
)
local sources = C.Sources(db, C.Key("Barry", "Azeroth"))
assert(#sources == 1 and sources[1].name == "Cillian", "the current character is not excluded")
local plan = C.PlanCopy(sources[1], db.characters[C.Key("Barry", "Azeroth")].general, false, true)
assert(#plan.conflicts == 1 and plan.conflicts[1].name == "Heal", "conflicts were not detected")
assert(#plan.create == 1 and plan.create[1].body == "/cast Flash Heal", "Keep both does not retain the incoming body")
local replace = C.PlanCopy(sources[1], db.characters[C.Key("Barry", "Azeroth")].general, false, false)
assert(#replace.create == 0 and #replace.conflicts == 1, "Replace does not isolate the explicit conflict")
-- Character macros begin after the account capacity, not after the number of occupied account slots.
_G.Constants = { MacroConsts = { MAX_ACCOUNT_MACROS = 120 } }
_G.UnitFullName = function()
	return "Barry", "Azeroth"
end
_G.GetNumMacros = function()
	return 1, 1
end
_G.GetMacroInfo = function(index)
	if index == 1 then
		return "General", 1, "/say General"
	end
	if index == 121 then
		return "Character", 2, "/say Character"
	end
end
local current = C.CaptureCurrent(db)
assert(#db.characters[current].general == 1, "capture keeps account macros")
assert(#db.characters[current].character == 1, "capture reads the separate character slot range")
assert(db.characters[current].character[1].body == "/say Character", "capture preserves character macro bodies")
local entries = C.Macros(db, current)
assert(
	#entries == 2 and entries[1].scope == "general" and entries[2].scope == "character",
	"source macros do not retain their scope"
)
local one = C.PlanMacro(entries[2], db.characters[current].general, true)
assert(#one.create == 1 and one.create[1].body == "/cast Trap", "a character macro cannot be copied to General")

-- The conflict diff shows only changed lines, old before new, and says so when the bodies agree.
local rows = C.Diff(
	{ name = "Heal", body = "/cast Flash Heal\n/stopcasting" },
	{ name = "Heal", body = "/cast Heal\n/stopcasting" }
)
assert(#rows == 3, "the diff did not keep one changed line and its old/new pair")
assert(rows[1].kind == "name" and rows[1].text == "Heal", "the diff lost the macro name")
assert(rows[2].kind == "old" and rows[2].text == "/cast Heal", "the diff lost the old line")
assert(rows[3].kind == "new" and rows[3].text == "/cast Flash Heal", "the diff lost the incoming line")
local added = C.Diff({ name = "Extra", body = "/cast Trap" }, { name = "Extra", body = "" })
assert(#added == 2 and added[2].kind == "new" and added[2].text == "/cast Trap", "an added line is not shown")
local same = C.Diff({ name = "Same", body = "/cast Heal" }, { name = "Same", body = "/cast Heal" })
assert(#same == 2 and same[2].kind == "same", "an unchanged body does not say so")

-- A renamed copy fits the client's 16-letter name field without cutting a UTF-8 character.
local taken = { ["1234567890123456"] = true }
local short = C.UniqueName("1234567890123456", function(name)
	return taken[name] == true
end)
assert(#short == 16 and short ~= "1234567890123456", "a full-length copy name did not fit the 16-letter field")
local wide = "ÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜÜ"
taken = { [wide] = true }
local wideCopy = C.UniqueName(wide, function(name)
	return taken[name] == true
end)
assert(ns.Length(wideCopy) == 16, "a UTF-8 copy name did not fit 16 letters")
assert(#wideCopy == 30, "a UTF-8 copy name was cut by bytes instead of characters")
assert(wideCopy:sub(-2) == " 2", "a UTF-8 copy name lost its suffix")
print("character_macros_spec: passed")
