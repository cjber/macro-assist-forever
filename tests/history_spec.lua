-- Macro history: snapshots land newest first, a macro keeps only its newest 20, a rename carries them, a deleted
-- macro stays listable, each row says what changed by a plain line diff, and Restore edits or creates through the
-- caller's write path but never in combat.
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
load("Core/History.lua")

local db = {}
ns.History.Initialize(db)

local first = ns.History.Snapshot(db, { name = "Arcane", icon = "icon1", body = "/cast A", tab = 2 }, 100)
equal(first.name, "Arcane", "a snapshot keeps the macro name")
equal(first.body, "/cast A", "a snapshot keeps the macro body")
equal(first.time, 100, "a snapshot keeps its time")
local second = ns.History.Snapshot(db, { name = "Arcane", icon = "icon2", body = "/cast B", tab = 2 }, 200)
equal(#ns.History.Entries(db, "Arcane"), 2, "two writes keep two snapshots")
equal(ns.History.Entries(db, "Arcane")[1], second, "the newest snapshot is first")
equal(ns.History.Entries(db, "Arcane")[2], first, "the older snapshot follows")

-- The limit bounds each macro separately, so a busy macro never pushes another macro's history out.
for index = 1, 25 do
	ns.History.Snapshot(db, { name = "Arcane", icon = "icon", body = "/cast " .. index, tab = 2 }, 300 + index)
end
ns.History.Snapshot(db, { name = "Trap", icon = "trap", body = "/cast Freezing Trap", tab = 2 }, 400)
equal(#ns.History.Entries(db, "Arcane"), ns.History.LIMIT, "the per-macro history is bounded at 20")
equal(ns.History.Entries(db, "Arcane")[1].body, "/cast 25", "bounding keeps the newest snapshot")
equal(ns.History.Entries(db, "Arcane")[20].body, "/cast 6", "bounding drops the oldest snapshot")
equal(#ns.History.Entries(db, "Trap"), 1, "another macro keeps its own history")

-- A create the client refuses removes the snapshot it took before the write, so no empty record is left behind.
local temporary = ns.History.Snapshot(db, { name = "Temporary", icon = "icon", body = "/cast A", tab = 1 }, 250)
ns.History.Remove(db, "Temporary", temporary)
equal(#ns.History.Entries(db, "Temporary"), 0, "a removed snapshot leaves no entries")
equal(db.history["Temporary"], nil, "a record with no entries is dropped")

-- A rename moves the whole record, so the renamed macro's history is still there.
ns.History.Snapshot(db, { name = "Arcane", icon = "icon", body = "/cast Renamed", tab = 2 }, 500)
local beforeRename = #ns.History.Entries(db, "Arcane")
ns.History.Rename(db, "Arcane", "Arcane Shot")
equal(#ns.History.Entries(db, "Arcane"), 0, "the old name no longer lists snapshots")
equal(#ns.History.Entries(db, "Arcane Shot"), beforeRename, "the rename carried every snapshot")
equal(db.history["Arcane Shot"].name, "Arcane Shot", "the record follows the new name")
equal(db.history["Arcane Shot"].tab, 2, "the record keeps its tab")

-- A name reused while the old macro was deleted merges into the existing record, newest first and bounded.
ns.History.Snapshot(db, { name = "Arcane", icon = "old", body = "/cast Old", tab = 2 }, 1000)
ns.History.Snapshot(db, { name = "Arcane Shot", icon = "new", body = "/cast New", tab = 2 }, 1100)
ns.History.Rename(db, "Arcane", "Arcane Shot")
equal(ns.History.Entries(db, "Arcane Shot")[1].body, "/cast New", "a merge puts the newer snapshot first")
local merged = #ns.History.Entries(db, "Arcane Shot")
equal(merged, ns.History.LIMIT, "a merge stays within the limit")

-- Deleted lists records whose name is no longer live, newest first, and skips live macros.
local deleted = ns.History.Deleted(db, { ["Arcane Shot"] = true })
equal(#deleted, 1, "only the deleted macro is listed")
equal(deleted[1].name, "Trap", "the deleted record is the missing macro")
ns.History.Snapshot(db, { name = "Old", icon = "old", body = "/cast Old", tab = 1 }, 3000)
deleted = ns.History.Deleted(db, { ["Arcane Shot"] = true, Trap = true })
equal(deleted[1].name, "Old", "deleted records are newest first")

-- Each row says what changed, from a plain line-by-line comparison of the snapshot and the next newer state.
local function change(oldBody, newBody, oldName, newName, oldIcon, newIcon)
	return ns.History.ChangeSummary({
		name = oldName or "Macro",
		icon = oldIcon or "icon",
		body = oldBody,
	}, {
		name = newName or "Macro",
		icon = newIcon or "icon",
		body = newBody,
	})
end

equal(change("one\ntwo\nthree", "one\ntwo\nfour"), "Line 3 changed", "one changed line names its line")
equal(change("one\ntwo\nthree", "one\nTWO\nTHREE"), "2 lines changed", "two changed lines share one phrase")
equal(change("one", "one\ntwo"), "+1 line", "one added line is counted")
equal(change("one\ntwo", "one"), "-1 line", "one removed line is counted")
equal(change("one", "one\ntwo\nthree"), "+2 lines", "added lines are counted together")
equal(change("one\ntwo\nthree", "one"), "-2 lines", "removed lines are counted together")
equal(change("one\ntwo", "two\none"), "2 lines changed", "a moved line is a plain line change, not a match")
equal(change("same", "same", "Old", "New"), "Renamed to New", "a name change is a rename")
equal(change("same", "same", "Macro", "Macro", "old", "new"), "Icon changed", "an icon change is named")
equal(
	change("one\ntwo", "one\nthree", "Old", "New", "same", "other"),
	"Renamed to New, Icon changed, Line 2 changed",
	"name, icon and body changes are listed together"
)
equal(change("same", "same"), "No change", "an unchanged snapshot says so")

-- The line diff behind the preview: one row per line of the older body, then one row for each line the newer body
-- adds. A row says whether the line is the same, changed or added or removed, its 1-based line number, and the text.
local diff = ns.History.LineDiff("one\ntwo\nthree", "one\nTWO\nthree")
equal(#diff, 3, "an equal-length diff has one row per line")
equal(diff[1].kind, "same", "an unchanged line reads as the same")
equal(diff[1].line, 1, "the first row is line 1")
equal(diff[1].old, "one", "a same row keeps the old text")
equal(diff[1].new, "one", "a same row keeps the new text")
equal(diff[2].kind, "changed", "a changed line reads as changed")
equal(diff[2].line, 2, "a changed row names its line")
equal(diff[2].old, "two", "a changed row keeps the old text")
equal(diff[2].new, "TWO", "a changed row keeps the new text")
equal(diff[3].kind, "same", "the line after a change can be the same")

-- A shorter or longer newer body adds rows after the lines the two bodies share.
diff = ns.History.LineDiff("one\ntwo", "one\ntwo\nthree\nfour")
equal(#diff, 4, "the added lines each get a row")
equal(diff[3].kind, "added", "a line only the newer body has is added")
equal(diff[3].line, 3, "the first added line is line 3")
equal(diff[3].old, nil, "an added row has no old text")
equal(diff[3].new, "three", "an added row keeps the new text")
equal(diff[4].line, 4, "the second added line is line 4")
diff = ns.History.LineDiff("one\ntwo\nthree\nfour", "one\ntwo")
equal(#diff, 4, "the removed lines each get a row")
equal(diff[3].kind, "removed", "a line only the older body has is removed")
equal(diff[3].line, 3, "the first removed line is line 3")
equal(diff[3].old, "three", "a removed row keeps the old text")
equal(diff[3].new, nil, "a removed row has no new text")
equal(diff[4].kind, "removed", "the last removed line is removed")

-- A moved line is a plain change at its new position, not a match elsewhere.
diff = ns.History.LineDiff("one\ntwo", "two\none")
equal(diff[1].kind, "changed", "a moved line is a change, not a match")
equal(diff[1].old, "one", "the moved row keeps the old first line")
equal(diff[1].new, "two", "the moved row keeps the new first line")

-- A body with no lines is empty, and a missing body is the same as an empty one.
diff = ns.History.LineDiff(nil, "one\ntwo")
equal(#diff, 2, "a nil body contributes no rows")
equal(diff[1].kind, "added", "every line of a new body is added")
equal(diff[1].line, 1, "the first added row is line 1")
diff = ns.History.LineDiff("one\ntwo", nil)
equal(#diff, 2, "a nil newer body removes every line")
equal(diff[1].kind, "removed", "every line of a removed body is removed")
equal(diff[2].line, 2, "the last removed row is line 2")
equal(#ns.History.LineDiff("", ""), 0, "two empty bodies have no rows")
equal(ns.History.LineDiff("one\ntwo", "one\ntwo")[2].kind, "same", "an unchanged body is all the same")

-- Restore edits a live macro through the given write, with the snapshot's name, icon and body.
local calls = {}
local snapshot = ns.History.Entries(db, "Arcane Shot")[1]
local kind, index = ns.History.Restore(snapshot, {
	inCombat = false,
	find = function(name)
		calls.find = name
		return 121
	end,
	edit = function(actual, name, icon, body)
		calls.edit = { actual, name, icon, body }
	end,
	create = function()
		error("a live macro must be edited, not created")
	end,
})
equal(kind, "edit", "a live macro is restored by editing")
equal(index, 121, "restore returns the edited macro index")
equal(calls.find, "Arcane Shot", "restore looks the macro up by name")
equal(calls.edit[3], snapshot.icon, "restore writes the snapshot icon")
equal(calls.edit[4], snapshot.body, "restore writes the snapshot body")

-- A deleted macro is created again, in the tab its record remembers.
calls = {}
local old = ns.History.Entries(db, "Old")[1]
kind, index = ns.History.Restore(old, {
	inCombat = false,
	find = function()
		return nil
	end,
	edit = function()
		error("a deleted macro must be created, not edited")
	end,
	create = function(name, icon, body, character)
		calls.create = { name, icon, body, character }
		return 1
	end,
	character = false,
})
equal(kind, "create", "a deleted macro is restored by creating it")
equal(index, 1, "restore returns the created macro index")
equal(calls.create[1], "Old", "restore creates the snapshot's name")
equal(calls.create[4], false, "restore creates in the record's tab")

-- Combat refuses the restore before any lookup or write.
local reason
kind, index, reason = ns.History.Restore(old, {
	inCombat = true,
	find = function()
		error("combat must not look a macro up")
	end,
	edit = function()
		error("combat must not edit")
	end,
	create = function()
		error("combat must not create")
	end,
})
equal(kind, nil, "combat refuses every restore")
equal(index, nil, "combat returns no macro index")
equal(reason, "combat", "combat reports why the restore was refused")

-- A save file older than this feature has no history key; the initialiser adds one and keeps the rest.
local oldSave = { kept = true }
ns.History.Initialize(oldSave)
equal(oldSave.kept, true, "an old saved value survives")
equal(type(oldSave.history), "table", "an old save file gains an empty history")

print(("history: %d checks"):format(checks))
