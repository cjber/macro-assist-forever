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
