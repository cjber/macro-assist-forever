local _, ns = ...

if ns.broken then
	return
end

-- Macro history: one record per macro name in MacroAssistForeverDB.history, holding the newest snapshots of that
-- macro's name, icon and body. A record follows a rename, and a deleted macro's record stays until the player
-- restores it. This file is pure Lua and never calls the client, so tests/history_spec.lua can cover storage,
-- bounding, restore, the change description and the combat check without the game.

local L = ns.L

local History = {}
ns.History = History

-- The newest snapshots kept for each macro. Older entries fall off the end; the player's save file stays small.
History.LIMIT = 20

---@class MacroAssistSnapshot
---@field name string
---@field icon any
---@field body string
---@field time number

---@class MacroAssistHistoryRecord
---@field name string
---@field icon any
---@field tab integer
---@field entries MacroAssistSnapshot[]

local function Copy(entry)
	return {
		name = type(entry.name) == "string" and entry.name or "",
		icon = entry.icon,
		body = type(entry.body) == "string" and entry.body or "",
		time = type(entry.time) == "number" and entry.time or 0,
	}
end

---@param entries MacroAssistSnapshot[]
local function Trim(entries)
	while #entries > History.LIMIT do
		table.remove(entries)
	end
end

-- Bring a saved table from an older version into shape: every record owns an entries list, every entry has the
-- four fields, and no record is longer than the limit. A key a save file no longer has is no error.
---@param db table
---@return table
function History.Initialize(db)
	if type(db) ~= "table" then
		return {}
	end
	if type(db.history) ~= "table" then
		db.history = {}
	end
	for name, record in pairs(db.history) do
		if type(record) ~= "table" or type(record.entries) ~= "table" then
			db.history[name] = nil
		else
			record.name = type(record.name) == "string" and record.name or name
			record.tab = record.tab == 2 and 2 or 1
			for index = #record.entries, 1, -1 do
				if type(record.entries[index]) ~= "table" then
					table.remove(record.entries, index)
				end
			end
			Trim(record.entries)
		end
	end
	return db.history
end

---@param db table
---@param name string?
---@return MacroAssistHistoryRecord?
function History.Record(db, name)
	if type(db) ~= "table" or type(name) ~= "string" or name == "" then
		return nil
	end
	History.Initialize(db)
	local record = db.history[name]
	if not record then
		record = { name = name, tab = 1, entries = {} }
		db.history[name] = record
	end
	return record
end

-- Store the macro's state as it was before a write. A renamed macro keeps its whole record: the caller snapshots
-- under the old name first, then moves the record with History.Rename.
---@param db table
---@param macro { name: string, icon: any, body: string?, tab: integer? }
---@param time number
---@return MacroAssistSnapshot?
function History.Snapshot(db, macro, time)
	if type(macro) ~= "table" or type(macro.name) ~= "string" or macro.name == "" then
		return nil
	end
	local record = History.Record(db, macro.name)
	if not record then
		return nil
	end
	record.name = macro.name
	if macro.tab == 1 or macro.tab == 2 then
		record.tab = macro.tab
	end
	record.icon = macro.icon
	local entry = Copy({
		name = macro.name,
		icon = macro.icon,
		body = macro.body,
		time = time,
	})
	table.insert(record.entries, 1, entry)
	Trim(record.entries)
	return entry
end

-- Drop one snapshot again, so a create that the client refuses does not leave a history record behind.
---@param db table
---@param name string
---@param entry MacroAssistSnapshot?
function History.Remove(db, name, entry)
	if type(db) ~= "table" or type(name) ~= "string" or type(entry) ~= "table" then
		return
	end
	History.Initialize(db)
	local record = db.history[name]
	if not record then
		return
	end
	for index = #record.entries, 1, -1 do
		if record.entries[index] == entry then
			table.remove(record.entries, index)
			break
		end
	end
	if #record.entries == 0 then
		db.history[name] = nil
	end
end

-- A renamed macro keeps its history under the new name. A record already at the new name (a name reused since the
-- old macro was deleted) takes the older record's snapshots, newest first, and the limit applies to the result.
---@param db table
---@param oldName string?
---@param newName string?
function History.Rename(db, oldName, newName)
	if type(db) ~= "table" or type(oldName) ~= "string" or type(newName) ~= "string" then
		return
	end
	if oldName == "" or newName == "" or oldName == newName then
		return
	end
	History.Initialize(db)
	local record = db.history[oldName]
	if not record then
		return
	end
	db.history[oldName] = nil
	local existing = db.history[newName]
	if not existing then
		record.name = newName
		db.history[newName] = record
		return
	end
	for _, entry in ipairs(record.entries) do
		existing.entries[#existing.entries + 1] = entry
	end
	table.sort(existing.entries, function(first, second)
		return (first.time or 0) > (second.time or 0)
	end)
	Trim(existing.entries)
	existing.name = newName
end

---@param db table
---@param name string
---@return MacroAssistSnapshot[]
function History.Entries(db, name)
	if type(db) ~= "table" or type(name) ~= "string" then
		return {}
	end
	History.Initialize(db)
	local record = db.history[name]
	return record and record.entries or {}
end

-- Records whose macro is no longer in the macro store, newest snapshot first, for the Deleted section.
---@param db table
---@param live table<string, boolean>
---@return MacroAssistHistoryRecord[]
function History.Deleted(db, live)
	History.Initialize(db)
	local deleted = {}
	for name, record in pairs(db.history) do
		if not (live and live[name]) and #record.entries > 0 then
			deleted[#deleted + 1] = record
		end
	end
	table.sort(deleted, function(first, second)
		local firstTime = first.entries[1] and first.entries[1].time or 0
		local secondTime = second.entries[1] and second.entries[1].time or 0
		return firstTime > secondTime
	end)
	return deleted
end

-- Split a body into its lines without reading any text pattern: one plain line-by-line comparison, so a line that
-- moved reads as a change rather than being matched somewhere else.
---@param body string?
---@return string[]
local function SplitLines(body)
	local lines = {}
	if type(body) ~= "string" or body == "" then
		return lines
	end
	local start = 1
	while true do
		local newline = body:find("\n", start, true)
		if not newline then
			lines[#lines + 1] = body:sub(start)
			return lines
		end
		lines[#lines + 1] = body:sub(start, newline - 1)
		start = newline + 1
	end
end

---@class MacroAssistDiffLine
---@field kind "same"|"changed"|"added"|"removed"
---@field line integer
---@field old string?
---@field new string?

-- One row for each line of the older text, then one for each line the newer text adds. The comparison is the same
-- plain line-by-line one ChangeSummary describes, so a preview and a history row never disagree.
---@param body string?
---@param newerBody string?
---@return MacroAssistDiffLine[]
function History.LineDiff(body, newerBody)
	local oldLines = SplitLines(body)
	local newLines = SplitLines(newerBody)
	local rows = {}
	local common = math.min(#oldLines, #newLines)
	for index = 1, common do
		if oldLines[index] == newLines[index] then
			rows[#rows + 1] = { kind = "same", line = index, old = oldLines[index], new = newLines[index] }
		else
			rows[#rows + 1] = { kind = "changed", line = index, old = oldLines[index], new = newLines[index] }
		end
	end
	for index = common + 1, #oldLines do
		rows[#rows + 1] = { kind = "removed", line = index, old = oldLines[index] }
	end
	for index = common + 1, #newLines do
		rows[#rows + 1] = { kind = "added", line = index, new = newLines[index] }
	end
	return rows
end

---@param body string?
---@param newerBody string?
---@return string[]
local function BodyChanges(body, newerBody)
	local oldLines = SplitLines(body)
	local newLines = SplitLines(newerBody)
	local common = math.min(#oldLines, #newLines)
	local changed = 0
	local firstChanged
	for index = 1, common do
		if oldLines[index] ~= newLines[index] then
			changed = changed + 1
			if not firstChanged then
				firstChanged = index
			end
		end
	end
	local parts = {}
	if changed == 1 then
		parts[#parts + 1] = L["Line %d changed"]:format(firstChanged)
	elseif changed > 1 then
		parts[#parts + 1] = L["%d lines changed"]:format(changed)
	end
	local added = #newLines - common
	if added == 1 then
		parts[#parts + 1] = L["+1 line"]
	elseif added > 1 then
		parts[#parts + 1] = L["+%d lines"]:format(added)
	end
	local removed = #oldLines - common
	if removed == 1 then
		parts[#parts + 1] = L["-1 line"]
	elseif removed > 1 then
		parts[#parts + 1] = L["-%d lines"]:format(removed)
	end
	return parts
end

-- What one snapshot changed against the state after the write it captured: the next newer snapshot, or the live
-- macro's text for the newest. A rename, an icon change and each body line change are separate phrases, so a row
-- reads "Renamed to Arcane Shot, line 2 changed" instead of guessing from text.
---@param entry MacroAssistSnapshot
---@param newer MacroAssistSnapshot?
---@return string
function History.ChangeSummary(entry, newer)
	if type(entry) ~= "table" or type(newer) ~= "table" then
		return ""
	end
	local parts = {}
	if entry.name ~= newer.name then
		parts[#parts + 1] = L["Renamed to %s"]:format(tostring(newer.name or ""))
	end
	if entry.icon ~= newer.icon then
		parts[#parts + 1] = L["Icon changed"]
	end
	for _, part in ipairs(BodyChanges(entry.body, newer.body)) do
		parts[#parts + 1] = part
	end
	if #parts == 0 then
		return L["No change"]
	end
	return table.concat(parts, ", ")
end

-- Put a snapshot back through the same write path the editor uses: an edit when a macro with that name is live, a
-- create when it is not. The caller supplies those two writes and its combat state; in combat the snapshot is
-- never written, which is the same refusal every other write button has.
---@class MacroAssistRestoreContext
---@field inCombat boolean?
---@field find fun(name: string): integer?
---@field edit fun(index: integer, name: string, icon: any, body: string)
---@field create fun(name: string, icon: any, body: string, character: boolean): integer?
---@field character boolean?

---@param snapshot MacroAssistSnapshot?
---@param context MacroAssistRestoreContext
---@return string? kind "edit" or "create"
---@return integer? index
---@return string? reason "combat", "missing" or "full"
function History.Restore(snapshot, context)
	if type(snapshot) ~= "table" or type(snapshot.name) ~= "string" or snapshot.name == "" then
		return nil, nil, "missing"
	end
	if not context or context.inCombat then
		return nil, nil, "combat"
	end
	local index = context.find and context.find(snapshot.name) or nil
	if index then
		context.edit(index, snapshot.name, snapshot.icon, snapshot.body or "")
		return "edit", index
	end
	if not context.create then
		return nil, nil, "missing"
	end
	local created = context.create(snapshot.name, snapshot.icon, snapshot.body or "", context.character == true)
	if not created then
		return nil, nil, "full"
	end
	return "create", created
end

return History
