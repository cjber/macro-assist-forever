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
print("character_macros_spec: passed")
