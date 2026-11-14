local _, ns = ...

if ns.broken then
	return
end

local Characters = {}
local function key(name, realm)
	return (name or "Unknown") .. "-" .. (realm or "Unknown")
end

function Characters.Key(name, realm)
	return key(name, realm)
end

function Characters.Capture(db, name, realm, general, character)
	db.characters = db.characters or {}
	db.characters[key(name, realm)] = {
		name = name,
		realm = realm,
		general = general or {},
		character = character or {},
	}
end

function Characters.CaptureCurrent(db)
	local name, realm = UnitFullName("player")
	name = name or UnitName("player") or "Unknown"
	realm = realm or (GetRealmName and GetRealmName()) or "Unknown"
	local account, count = GetNumMacros()
	local general, character = {}, {}
	local constants = Constants and Constants.MacroConsts
	local accountLimit = constants and constants.MAX_ACCOUNT_MACROS or 120
	local function capture(first, last, target)
		for index = first, last do
			local macroName, icon, body = GetMacroInfo(index)
			if macroName then
				target[#target + 1] = { name = macroName, icon = icon, body = body or "" }
			end
		end
	end
	capture(1, account or 0, general)
	capture(accountLimit + 1, accountLimit + (count or 0), character)
	Characters.Capture(db, name, realm, general, character)
	return key(name, realm)
end

function Characters.Sources(db, current)
	local result = {}
	for id, record in pairs((db and db.characters) or {}) do
		if id ~= current then
			result[#result + 1] = record
		end
	end
	table.sort(result, function(a, b)
		return (a.name .. "-" .. a.realm) < (b.name .. "-" .. b.realm)
	end)
	return result
end

function Characters.Macros(db, current)
	local result = {}
	for _, record in ipairs(Characters.Sources(db, current)) do
		for _, scope in ipairs({ "general", "character" }) do
			for _, macro in ipairs(record[scope] or {}) do
				result[#result + 1] = { record = record, scope = scope, macro = macro }
			end
		end
	end
	return result
end

function Characters.PlanMacro(source, destination, keepBoth)
	local existing = {}
	for _, macro in ipairs(destination or {}) do
		existing[macro.name] = true
	end
	local plan = { create = {}, conflicts = {} }
	if existing[source.macro.name] then
		plan.conflicts[1] = source.macro
	end
	if keepBoth or not existing[source.macro.name] then
		plan.create[1] = source.macro
	end
	return plan
end

-- The client's macro name field takes 16 letters (Blizzard_MacroUI/Blizzard_MacroUI.xml gives the name box
-- `letters="16"`, and the picker's Box is the same contract). A copy that has to keep both names shortens the base
-- with UTF-8 characters, never bytes, so the suffix fits without cutting a character in half.
Characters.NAME_LIMIT = 16

---@param name string?
---@param taken fun(name: string): boolean
---@return string
function Characters.UniqueName(name, taken)
	name = type(name) == "string" and name or ""
	if not taken(name) then
		return name
	end
	for suffix = 2, 999 do
		local tail = " " .. suffix
		local room = Characters.NAME_LIMIT - ns.Length(tail)
		local base = room > 0 and name:sub(1, ns.FirstOver(name, room) - 1) or ""
		local candidate = base .. tail
		if not taken(candidate) then
			return candidate
		end
	end
	return name
end

-- What the copy popup shows for one source: the macro's name, then only the lines that differ between the macro
-- already here and the incoming one, old before new. An unchanged body says so instead of leaving an empty box, and
-- a source with no macro of that name reads as the whole incoming body added.
---@param incoming table
---@param existing? table
---@return table[]
function Characters.Diff(incoming, existing)
	local rows = { { kind = "name", text = incoming.name or "" } }
	for _, change in ipairs(ns.History.LineDiff((existing and existing.body) or "", incoming.body or "")) do
		if change.kind == "changed" then
			rows[#rows + 1] = { kind = "old", text = change.old or "" }
			rows[#rows + 1] = { kind = "new", text = change.new or "" }
		elseif change.kind == "removed" then
			rows[#rows + 1] = { kind = "old", text = change.old or "" }
		elseif change.kind == "added" then
			rows[#rows + 1] = { kind = "new", text = change.new or "" }
		end
	end
	if #rows == 1 then
		rows[#rows + 1] = { kind = "same", text = ns.L["No change"] }
	end
	return rows
end

function Characters.PlanCopy(source, destination, toCharacter, keepBoth)
	local macros = toCharacter and source.character or source.general
	local plan = { create = {}, conflicts = {} }
	local existing = {}
	for _, macro in ipairs(destination or {}) do
		existing[macro.name] = true
	end
	for _, macro in ipairs(macros or {}) do
		if existing[macro.name] then
			plan.conflicts[#plan.conflicts + 1] = macro
		end
		if keepBoth or not existing[macro.name] then
			plan.create[#plan.create + 1] = macro
		end
	end
	return plan
end

ns.CharacterMacros = Characters
