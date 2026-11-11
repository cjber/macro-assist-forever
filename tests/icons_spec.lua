-- The icon picker's pure part: the generated FileDataID table, the cast order of a macro, and the search and prefix
-- rules the client's file names answer.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end
local function yes(value, label)
	checks = checks + 1
	assert(value, label)
end

local ns = {}
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("MacroAssistForever", ns)
end
load("Locales/enUS.lua")
load("Core/Lexer.lua")
load("Core/Parser.lua")
load("Core/Icons.lua")
local Icons = ns.Icons

-- The generated file is one long string of `FileDataID=name` lines; a malformed line is ignored, not fatal.
local byID, count = Icons.Parse("134400=inv_misc_questionmark\n132204=ability_hunter_quickshot\nnot a row\n")
equal(count, 2, "two valid rows are counted")
equal(byID[134400], "inv_misc_questionmark", "the question mark is keyed by its FileDataID")
equal(byID[132204], "ability_hunter_quickshot", "the second row is keyed by its FileDataID")
equal(byID[1], nil, "a malformed row adds nothing")

-- The client hands either a FileDataID or a loose path, and both answer the same lowercase file name.
ns.IconNameText = "134400=inv_misc_questionmark\n132204=ability_hunter_quickshot\n"
Icons.names = nil
equal(Icons.FileName(134400), "inv_misc_questionmark", "a FileDataID resolves through the table")
equal(Icons.FileName("Interface\\Icons\\Ability_Hunter_Quickshot"), "ability_hunter_quickshot", "a path is its name")
equal(Icons.FileName("INV_Misc_QuestionMark.blp"), "inv_misc_questionmark", "a bare file name keeps no suffix")
equal(Icons.FileName(999999), nil, "an unknown FileDataID has no name")
yes(Icons.Same(134400, "Interface\\Icons\\INV_Misc_QuestionMark"), "a FileDataID and its path are one icon")
yes(not Icons.Same(134400, 132204), "different icons are different")
yes(Icons.Matches("Ability_Hunter_Pet_Owl", "pet"), "search ignores case")
yes(not Icons.Matches("Ability_Hunter_Pet_Owl", "pet."), "search is a plain substring, not a pattern")

-- From this macro: Automatic is added by the picker, then one entry per spell or item the macro casts, in clause order.
local iconsByName = {
	["Arcane Shot"] = { icon = 132204, label = "Arcane Shot" },
	["Concussive Shot"] = { icon = 135860, label = "Concussive Shot" },
	["Roasted Quail"] = { icon = 133971, label = "Roasted Quail", kind = "item" },
}
local function resolve(name)
	return iconsByName[name]
end
local arcane =
	"#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot\n/cast [mod:shift] Concussive Shot\n/petattack"
local actions = Icons.Actions(arcane, resolve)
equal(#actions, 2, "only the cast lines name spells")
equal(actions[1].icon, 132204, "the first cast comes first")
equal(actions[2].icon, 135860, "the second cast comes second")
equal(#Icons.Actions("/use Roasted Quail", resolve), 1, "an item is an action too")
equal(Icons.Actions("/say Arcane Shot", resolve)[1], nil, "free text is not a cast")
equal(#Icons.Actions("/cast Arcane Shot, Arcane Shot", resolve), 1, "a repeated spell appears once")
equal(#Icons.Actions("/cast Unknown Spell", resolve), 0, "a name the client does not know is skipped")

-- What #showtooltip picks: its own argument, never a guess at the first cast. A directive with no argument leaves the
-- answer to the live Now result, which the editor computes through the client's option parser.
equal(Icons.TooltipTarget("#showtooltip Concussive Shot\n/cast Arcane Shot"), "Concussive Shot", "the argument wins")
equal(Icons.TooltipTarget("#showtooltip\n/cast Arcane Shot"), nil, "no argument is not guessed from the cast")
equal(Icons.TooltipTarget("#showtooltip !Auto Shot"), "Auto Shot", "the toggle guard is not part of the name")
equal(Icons.TooltipTarget("/cast Arcane Shot"), nil, "a cast without a directive names no tooltip")
equal(Icons.TooltipTarget("/petattack"), nil, "a command with no argument names no spell")
equal(Icons.TooltipTarget(""), nil, "an empty macro names no spell")

-- Search: the player's own spells and items whose name matches come first; every icon whose file name matches follows
-- in the client's order.
local known = {
	{ icon = 132179, label = "Mend Pet" },
	{ icon = 132180, label = "Call Pet" },
	{ icon = 132204, label = "Arcane Shot" },
}
local all = {
	{ icon = 1, name = "ability_hunter_pet_owl" },
	{ icon = 2, name = "inv_misc_food_19" },
	{ icon = 132179, name = "ability_hunter_mendpet" },
	{ icon = 3, name = "achievement_pet_01" },
}
local spells, matches = Icons.Search(known, all, "pet")
equal(#spells, 2, "two known spells match pet")
equal(spells[1].label, "Mend Pet", "the spellbook order puts Mend Pet first")
equal(spells[2].label, "Call Pet", "Call Pet follows")
equal(#matches, 3, "three file names match pet")
equal(matches[1].name, "ability_hunter_pet_owl", "file-name matches keep the client's order")
equal(matches[2].name, "ability_hunter_mendpet", "the second match follows")
equal(matches[3].name, "achievement_pet_01", "the third match follows")
local noneSpells, noneMatches = Icons.Search(known, all, "")
equal(#noneSpells, 0, "an empty search has no spells")
equal(#noneMatches, 0, "an empty search has no icons")

-- The prefix filters read the file name's own subject: ability_<class>_, spell_<school>_, inv_<slot>_.
local classKind, classToken = Icons.Kind("ability_hunter_quickshot")
equal(classKind, "class", "an ability_hunter_icon is a class icon")
equal(classToken, "hunter", "the class token is the file's own")
local schoolKind, schoolToken = Icons.Kind("spell_frost_frostnova")
equal(schoolKind, "school", "a spell_frost_icon is a school icon")
equal(schoolToken, "frost", "the school token is the file's own")
local slotKind, slotToken = Icons.Kind("inv_sword_04")
equal(slotKind, "slot", "an inv_sword_icon is a slot icon")
equal(slotToken, "weapons", "a sword folds into Weapons")
equal(select(2, Icons.Kind("inv_jewelry_ring_03")), "jewelry", "a ring folds into Rings and trinkets")
equal(select(2, Icons.Kind("inv_potion_51")), "consumables", "a potion folds into Potions and food")
equal(select(2, Icons.Kind("inv_helm_01")), "head", "a helm folds into Head")
equal(select(2, Icons.Kind("inv_chest_cloth_01")), "chest", "a chest folds into Chest")
equal(select(2, Icons.Kind("inv_gauntlets_04")), "hands", "gauntlets fold into Hands")
equal(select(2, Icons.Kind("inv_shield_06")), "shields", "a shield folds into Shields")
equal(Icons.Kind("inv_misc_food_19"), nil, "an unmapped inv_ subject answers no kind")
equal(Icons.Kind("ability_physical_taunt"), nil, "a non-class ability subject answers no class")
equal(Icons.Kind("spell_hunter_mark"), nil, "a spell_<class>_ name is not a spell school")
equal(Icons.Kind(nil), nil, "no name answers no kind")

print(("icons: %d checks"):format(checks))
