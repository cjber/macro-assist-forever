local ns = {}
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
C.Capture(db, "Cillian", "Azeroth", { { name = "Heal", body = "/cast Flash Heal" } }, {})
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
print("character_macros_spec: passed")
