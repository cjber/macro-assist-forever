local _, ns = ...

if ns.broken then
	return
end

-- What the icon picker needs to know without the client: the client's FileDataID-to-name table, the spells and items
-- a macro casts in clause order, and the division of a file name into a class, a spell school or an item slot. It
-- never touches the game, so every part of it is covered by a spec.

local Icons = {}

-- A file name under interface/icons/ names its subject: ability_<class>_, spell_<school>_, inv_<slot>_. Only tokens
-- the client's icon set actually uses are filters; the file name is the only source, so no table of subjects ships.
Icons.ClassOrder = {
	"warrior",
	"paladin",
	"hunter",
	"rogue",
	"priest",
	"deathknight",
	"shaman",
	"mage",
	"warlock",
	"monk",
	"druid",
	"demonhunter",
	"evoker",
}
Icons.SchoolOrder = { "physical", "holy", "fire", "nature", "frost", "shadow", "arcane" }
Icons.SlotOrder = { "head", "chest", "hands", "weapons", "shields", "jewelry", "consumables" }

local CLASSES = {}
for _, token in ipairs(Icons.ClassOrder) do
	CLASSES[token] = true
end
local SCHOOLS = {}
for _, token in ipairs(Icons.SchoolOrder) do
	SCHOOLS[token] = true
end

-- An inv_<token>_ file name, folded into the seven item groups the filter offers.
local SLOTS = {
	helm = "head",
	helmet = "head",
	chest = "chest",
	robe = "chest",
	glove = "hands",
	gauntlets = "hands",
	sword = "weapons",
	axe = "weapons",
	mace = "weapons",
	staff = "weapons",
	polearm = "weapons",
	bow = "weapons",
	crossbow = "weapons",
	gun = "weapons",
	thrown = "weapons",
	wand = "weapons",
	knife = "weapons",
	dagger = "weapons",
	fist = "weapons",
	spear = "weapons",
	weapon = "weapons",
	shield = "shields",
	buckler = "shields",
	ring = "jewelry",
	trinket = "jewelry",
	jewelry = "jewelry",
	necklace = "jewelry",
	potion = "consumables",
	flask = "consumables",
	drink = "consumables",
	food = "consumables",
}

-- Commands whose comma-separated arguments name the spells and items a macro acts on, the same set the summary uses.
local ACTION_COMMANDS = {
	cast = true,
	spell = true,
	use = true,
	castsequence = true,
	castrandom = true,
	userandom = true,
	usetoy = true,
}

---@param text string
---@return table<number, string> byID
---@return integer count
function Icons.Parse(text)
	local byID = {}
	local count = 0
	for line in tostring(text or ""):gmatch("[^\r\n]+") do
		local id, name = line:match("^(%d+)=(.*)$")
		local number = id and tonumber(id)
		if number and name and name ~= "" then
			byID[number] = name
			count = count + 1
		end
	end
	return byID, count
end

-- The parsed client table, built the first time an icon needs its name. Login reads one string; opening the picker
-- and hovering an icon pays for the parse once.
---@return table<number, string>
function Icons.Names()
	if not Icons.names then
		Icons.names = Icons.Parse(ns.IconNameText)
	end
	return Icons.names
end

-- An icon as the client hands it over: a FileDataID for most entries, or a path for the loose icon lists. Both become
-- the lowercase file name under interface/icons/, which is what the search, the tooltip and the filters read.
---@param icon any
---@return string?
function Icons.FileName(icon)
	if type(icon) == "number" then
		return Icons.Names()[icon]
	end
	if type(icon) == "string" and icon ~= "" then
		local name = icon:match("([^\\/]+)$") or icon
		name = name:gsub("%.[%w]+$", "")
		name = name:lower()
		return name ~= "" and name or nil
	end
end

---@param text string?
---@param needle string
---@return boolean
function Icons.Matches(text, needle)
	if type(text) ~= "string" or needle == "" then
		return false
	end
	return text:lower():find(needle:lower(), 1, true) ~= nil
end

-- One icon as the store may hand it over either way: the same file, a FileDataID or a path, is one icon.
---@param first any
---@param second any
---@return boolean
function Icons.Same(first, second)
	if first == second then
		return true
	end
	if type(first) == "number" and type(second) == "number" then
		return false
	end
	if type(first) == "string" and type(second) == "string" then
		local firstName = first:match("([^\\/]+)$") or first
		local secondName = second:match("([^\\/]+)$") or second
		return firstName:lower() == secondName:lower()
	end
	local firstName = Icons.FileName(first)
	local secondName = Icons.FileName(second)
	return firstName ~= nil and firstName == secondName
end

-- The spells and items a macro acts on, in the order its clauses name them, with a client resolver turning each name
-- into an icon and the label the player sees. A name the client does not know, or an icon already listed, is skipped.
---@param body string
---@param resolve fun(name: string): table?
---@return table[]
function Icons.Actions(body, resolve)
	local out = {}
	local seen = {}
	if type(body) ~= "string" or body == "" or type(resolve) ~= "function" then
		return out
	end
	for _, line in ipairs(ns.Parser.Parse(body).lines) do
		if line.kind == "command" and line.command and ACTION_COMMANDS[line.command.nameLower] then
			for _, clause in ipairs(line.clauses) do
				if clause.args then
					for _, item in ipairs(clause.args.items) do
						if item.name and item.name ~= "" then
							local entry = resolve(item.name)
							if entry and entry.icon ~= nil and not seen[entry.icon] then
								seen[entry.icon] = true
								out[#out + 1] = entry
							end
						end
					end
				end
			end
		end
	end
	return out
end

-- The spell #showtooltip names, or nil when the directive has no argument. The live action is the editor's Now
-- result: a macro's #showtooltip with no argument shows what the client would run, which a segment can only decide
-- with SecureCmdOptionParse, not from the body alone.
---@param body string
---@return string?
function Icons.TooltipTarget(body)
	if type(body) ~= "string" or body == "" then
		return nil
	end
	for _, line in ipairs(ns.Parser.Parse(body).lines) do
		if line.kind == "directive" and line.directive == "showtooltip" then
			for _, clause in ipairs(line.clauses) do
				if clause.args then
					for _, item in ipairs(clause.args.items) do
						if item.name and item.name ~= "" then
							return item.name
						end
					end
				end
			end
		end
	end
end

-- Search results: the player's own spells and items whose name matches come first, then every icon whose file name
-- holds the text, in the client's own order. Both lists are case-insensitive plain substrings.
---@param known table[]
---@param icons table[]
---@param needle string
---@return table[] spells
---@return table[] matches
function Icons.Search(known, icons, needle)
	local spells = {}
	local matches = {}
	if type(needle) ~= "string" or needle == "" then
		return spells, matches
	end
	local seen = {}
	for _, entry in ipairs(known) do
		if entry.icon ~= nil and Icons.Matches(entry.label, needle) and not seen[entry.icon] then
			seen[entry.icon] = true
			spells[#spells + 1] = entry
		end
	end
	for _, entry in ipairs(icons) do
		if Icons.Matches(entry.name, needle) then
			matches[#matches + 1] = entry
		end
	end
	return spells, matches
end

-- The filter a file name answers: a class (ability_<class>_), a spell school (spell_<school>_) or an item slot
-- (inv_<slot>_). A name the filter has no group for answers nothing.
---@param name string?
---@return string? kind
---@return string? token
function Icons.Kind(name)
	if type(name) ~= "string" then
		return nil, nil
	end
	local token = name:match("^ability_(%w+)_")
	if token and CLASSES[token] then
		return "class", token
	end
	token = name:match("^spell_(%w+)_")
	if token and SCHOOLS[token] then
		return "school", token
	end
	token = name:match("^inv_(%w+)_")
	if token and SLOTS[token] then
		return "slot", SLOTS[token]
	end
	return nil, nil
end

ns.Icons = Icons
