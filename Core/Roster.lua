local _, ns = ...

if ns.broken then
	return
end

-- The current group, for the roster beside the editor. The unit order is the client's own: the player first in a
-- party, then party1 to party4, and raid1 to raid40 in a raid. Every name and class is read through ns.Readable,
-- because another player's identity can be secret while the client still hands it to an addon.

local Roster = {}
ns.Roster = Roster

---@class MacroAssistRosterMember
---@field unit string
---@field name string
---@field className string?
---@field classFile string?

---@class MacroAssistRosterApi
---@field inRaid fun(): boolean
---@field groupCount fun(): integer
---@field name fun(unit: string): string?, string?
---@field class fun(unit: string): string?, string?

---@param raid boolean
---@param count integer
---@return string[]
function Roster.Units(raid, count)
	local units = {}
	if type(count) ~= "number" or count < 1 then
		return units
	end
	if raid then
		for index = 1, math.min(count, 40) do
			units[#units + 1] = "raid" .. index
		end
		return units
	end
	units[1] = "player"
	for index = 1, math.min(count - 1, 4) do
		units[#units + 1] = "party" .. index
	end
	return units
end

---@param api MacroAssistRosterApi
---@return boolean inGroup
---@return boolean raid
---@return MacroAssistRosterMember[] members
function Roster.Read(api)
	local count = ns.Readable(api.groupCount())
	if type(count) ~= "number" then
		count = 0
	end
	local raid = ns.Readable(api.inRaid()) == true
	local members = {}
	if count < 1 then
		return false, raid, members
	end
	for _, unit in ipairs(Roster.Units(raid, count)) do
		local name, realm = api.name(unit)
		name, realm = ns.Readable(name), ns.Readable(realm)
		if type(name) == "string" and name ~= "" and type(realm) == "string" and realm ~= "" then
			name = name .. "-" .. realm
		end
		if type(name) == "string" and name ~= "" then
			local className, classFile
			if api.class then
				className, classFile = api.class(unit)
				className = ns.Readable(className)
				classFile = ns.Readable(classFile)
			end
			members[#members + 1] = {
				unit = unit,
				name = name,
				className = className,
				classFile = classFile,
			}
		end
	end
	return true, raid, members
end
