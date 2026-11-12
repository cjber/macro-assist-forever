local _, ns = ...

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
		elseif keepBoth then
			plan.create[#plan.create + 1] = macro
		else
			plan.create[#plan.create + 1] = macro
		end
	end
	return plan
end

ns.CharacterMacros = Characters
