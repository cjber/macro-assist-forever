-- The roster beside the editor and the word a dropped name replaces. The unit list is pure, so party, raid, a secret
-- name and an empty group are all checked without the client; the word rule keeps every byte outside the target.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %q, got %q"):format(label, tostring(expected), tostring(actual)))
end

local ns = {}
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("MacroAssistForever", ns)
end
load("Locales/enUS.lua")
load("Core/Lexer.lua")
load("Core/Parser.lua")
load("Core/Secret.lua")
load("Core/Roster.lua")
load("UI/Editor.lua")

-- Party order is the player and then party1 to party4; a raid uses raid1 to the group's size.
local party = ns.Roster.Units(false, 3)
equal(#party, 3, "a party of three is the player and two others")
equal(party[1], "player", "the party starts with the player")
equal(party[2], "party1", "the party continues with party1")
equal(party[3], "party2", "the party continues in order")
equal(#ns.Roster.Units(false, 5), 5, "a full party keeps the player and party1-4")
equal(#ns.Roster.Units(false, 1), 1, "a one-person group is the player alone")
equal(#ns.Roster.Units(false, 0), 0, "no group has no units")
local raid = ns.Roster.Units(true, 40)
equal(#raid, 40, "a raid is every raid unit")
equal(raid[1], "raid1", "a raid starts at raid1")
equal(raid[40], "raid40", "a raid ends at raid40")

local function api(inRaid, count, names, classes)
	return {
		inRaid = function()
			return inRaid
		end,
		groupCount = function()
			return count
		end,
		name = function(unit)
			return names[unit]
		end,
		class = function(unit)
			local entry = classes and classes[unit]
			return entry and entry[1], entry and entry[2]
		end,
	}
end

local grouped, isRaid, members = ns.Roster.Read(api(false, 3, {
	player = "Barry",
	party1 = "Alphonse",
	party2 = "Bertie",
}, {
	player = { "Warrior", "WARRIOR" },
	party1 = { "Mage", "MAGE" },
	party2 = { "Priest", "PRIEST" },
}))
equal(grouped, true, "a party reports that it is grouped")
equal(isRaid, false, "a party is not a raid")
equal(#members, 3, "the roster reads every party member")
equal(members[1].name, "Barry", "the player is first in the party roster")
equal(members[2].name, "Alphonse", "the first party member follows")
equal(members[2].classFile, "MAGE", "the roster keeps the class file for its colour")
equal(members[3].unit, "party2", "the roster keeps the unit for its member")

grouped, isRaid, members = ns.Roster.Read(api(true, 2, { raid1 = "Barry", raid2 = "Cass" }))
equal(grouped, true, "a raid reports that it is grouped")
equal(isRaid, true, "a raid is a raid")
equal(#members, 2, "the roster reads every raid member")
equal(members[2].unit, "raid2", "a raid member keeps its raid unit")

-- Another player's name can be secret; ns.Readable turns it into nil, so that row is left out rather than read.
-- The simulator's canaccessvalue is the guard the client provides.
local globals = _G
local originalCanAccess = rawget(globals, "canaccessvalue")
rawset(globals, "canaccessvalue", function(value)
	return value ~= "Hidden"
end)
local secretRaid
grouped, secretRaid, members = ns.Roster.Read(api(false, 2, { player = "Barry", party1 = "Hidden" }))
rawset(globals, "canaccessvalue", originalCanAccess)
equal(grouped, true, "a group with one secret name is still grouped")
equal(secretRaid, false, "a secret party name does not make the group a raid")
equal(#members, 1, "a secret name is not added to the roster")
equal(members[1].name, "Barry", "the readable name is kept")

grouped, isRaid, members = ns.Roster.Read(api(false, 0, {}))
equal(grouped, false, "no group reports that it is not grouped")
equal(isRaid, false, "no group is not a raid")
equal(#members, 0, "no group has no members")

-- The word under a drop is a whitespace-delimited run on one line, and only that run changes.
local text = "/raid Tank 1: <name>"
local function at(needle)
	return text:find(needle, 1, true) - 1
end
local from, to = ns.Editor.WordAt(text, at("<name>"))
equal(text:sub(from, to), "<name>", "the word under the drop is the placeholder")
local replaced, caret = ns.Editor.ReplaceWord(text, at("<name>"), "Alphonse")
equal(replaced, "/raid Tank 1: Alphonse", "the dropped name replaces only the target word")
equal(caret, #replaced, "the caret follows the inserted name")
replaced = ns.Editor.ReplaceWord(text, at("Tank"), "Alphonse")
equal(replaced, "/raid Alphonse 1: <name>", "a name dropped on another word replaces that word")
replaced = ns.Editor.ReplaceWord(text, at("1:"), "Alphonse")
equal(replaced, "/raid Tank Alphonse <name>", "punctuation in a word is replaced with the word")

-- A caret at a word's start or end still belongs to that word; a caret inside spaces belongs to neither.
equal(select(2, ns.Editor.WordAt("alpha beta", 0)), 5, "a word at the start of the text")
equal(select(2, ns.Editor.WordAt("alpha beta", 5)), 5, "a caret at a word's end keeps that word")
equal(select(1, ns.Editor.WordAt("alpha beta", 6)), 7, "a caret at the next word's start picks it")
equal(ns.Editor.WordAt("alpha  beta", 6), nil, "a caret between two spaces picks no word")
equal(ns.Editor.WordAt("", 0), nil, "empty text has no word")

-- A newline ends a word, so a drop on the next line cannot replace part of the previous line.
local lines = "alpha\nbeta"
equal(select(1, ns.Editor.WordAt(lines, 6)), 7, "a word after a newline starts at its own line")
equal(select(2, ns.Editor.WordAt(lines, 6)), 10, "a word after a newline ends before the text ends")
equal(select(2, ns.Editor.WordAt(lines, 5)), 5, "a caret just before a newline keeps the word it ends")

-- A name with multibyte characters is inserted as one run; byte offsets before and after it are untouched.
local unicode = "/say héllo <name> !"
local unicodeReplaced = ns.Editor.ReplaceWord(unicode, unicode:find("<name>", 1, true) - 1, "Jäger")
equal(unicodeReplaced, "/say héllo Jäger !", "a UTF-8 name replaces only the target word")

-- Guard counts before branching or arithmetic, and preserve the realm from UnitFullName.
rawset(globals, "canaccessvalue", function(value)
	return value ~= 987
end)
grouped, isRaid, members = ns.Roster.Read(api(false, 987, {}))
equal(isRaid, false, "an unreadable count is not a raid")
equal(grouped, false, "an unreadable count is treated as unavailable")
equal(#members, 0, "an unreadable count produces no rows")
rawset(globals, "canaccessvalue", originalCanAccess)
local realmApi = api(false, 1, {})
realmApi.name = function()
	return "Barry", "Normal"
end
local _, _, realmMembers = ns.Roster.Read(realmApi)
equal(realmMembers[1].name, "Barry-Normal", "a remote realm remains part of the inserted name")
realmApi.name = function()
	return "Barry", ""
end
_, _, realmMembers = ns.Roster.Read(realmApi)
equal(realmMembers[1].name, "Barry", "an empty local realm adds no separator")

print(("roster: %d checks"):format(checks))
