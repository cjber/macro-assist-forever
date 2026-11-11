-- Shorten rewrites a macro from its parse tree and the command data. Every rewrite is lossless: the parse shapes of
-- the text before and after match once whitespace and the command alias are set aside, empty trailing clauses and the
-- clauses the checker calls unreachable are ignored.
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
load("Data/Commands.lua")
load("Data/Conditions.lua")
load("Core/Lexer.lua")
load("Core/Parser.lua")
load("Core/Length.lua")
load("Core/Check.lua")
load("Core/Shorten.lua")

local function clauseRange(clause)
	if clause.groups[1] then
		return clause.groups[1].from, clause.groups[1].to
	end
	if clause.args then
		return clause.args.from, clause.args.to
	end
	return clause.from, clause.to
end

local function clauseShape(clause)
	local groups = {}
	for _, group in ipairs(clause.groups) do
		local conditions = {}
		for _, condition in ipairs(group.conditions) do
			conditions[#conditions + 1] = (condition.no and "no:" or "")
				.. condition.name
				.. ":"
				.. tostring(condition.param or "")
		end
		local unit = group.unit and (group.unit.kind .. "=" .. group.unit.token) or ""
		groups[#groups + 1] = unit .. "[" .. table.concat(conditions, ",") .. "]"
	end
	local args = {}
	if clause.args then
		for _, item in ipairs(clause.args.items) do
			args[#args + 1] = item.text
		end
	end
	return { groups = groups, args = args, empty = #groups == 0 and #args == 0 }
end

local function lineShape(_text, line, unreachable)
	if line.kind == "command" then
		local entry = ns.CommandAliases[line.command.nameLower]
		local clauses = {}
		for _, clause in ipairs(line.clauses) do
			local from, to = clauseRange(clause)
			if not unreachable[from .. ":" .. to] then
				clauses[#clauses + 1] = clauseShape(clause)
			end
		end
		while #clauses > 0 and clauses[#clauses].empty do
			clauses[#clauses] = nil
		end
		return {
			kind = line.kind,
			command = entry and entry.name or line.command.name:lower(),
			bang = line.bang == true,
			clauses = clauses,
		}
	elseif line.kind == "directive" then
		local clauses = {}
		for _, clause in ipairs(line.clauses) do
			clauses[#clauses + 1] = clauseShape(clause)
		end
		return { kind = line.kind, directive = line.directive, clauses = clauses }
	elseif line.kind == "text" then
		return { kind = line.kind, text = (line.text:gsub("^%s+", ""):gsub("%s+$", "")) }
	end
	return { kind = line.kind }
end

local function shape(text)
	local unreachable = {}
	for _, diagnostic in ipairs(ns.Check(text)) do
		if diagnostic.code == "unreachable-clause" then
			unreachable[diagnostic.from .. ":" .. diagnostic.to] = true
		end
	end
	local lines = {}
	for _, line in ipairs(ns.Parser.Parse(text).lines) do
		lines[#lines + 1] = lineShape(text, line, unreachable)
	end
	return lines
end

local function serialize(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(left, right)
		return tostring(left) < tostring(right)
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		parts[#parts + 1] = tostring(key) .. "=" .. serialize(value[key])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function lossless(old, new, label)
	checks = checks + 1
	assert(serialize(shape(old)) == serialize(shape(new)), label .. ": the rewrite changed the parse")
end

-- Redundant whitespace: the line ends, the space after the command and the spaces around condition commas go, while
-- the space inside a spell name and inside a condition parameter stays.
local spaced = "  /cast   [harm, nodead]   Arcane Shot  "
local tight = ns.Shorten(spaced)
equal(tight.text, "/cast [harm,nodead] Arcane Shot", "redundant whitespace is dropped")
lossless(spaced, tight.text, "whitespace")

local named = "/cast [channeling:Mind   Flay] Mind Flay"
local namedTight = ns.Shorten(named)
equal(namedTight.text, named, "a condition parameter and a spell name keep their spaces")

-- A command is written with its shortest alias from its own data entry, and /use never becomes /cast.
local aliased = ns.Shorten("/spell Arcane Shot")
equal(aliased.text, "/cast Arcane Shot", "/spell uses the shortest alias of the same command")
lossless("/spell Arcane Shot", aliased.text, "spell alias")
equal(ns.Shorten("/achievement").text, "/ach", "a longer alias becomes the shortest")
lossless("/achievement", "/ach", "achievement alias")
equal(ns.Shorten("/use Roasted Quail").text, "/use Roasted Quail", "/use keeps its own command")
equal(ns.Shorten("/nonsense X").text, "/nonsense X", "an unknown command is left alone")

-- An empty trailing clause is collapsed, and a clause the checker calls unreachable is dropped.
equal(ns.Shorten("/cast Arcane Shot;").text, "/cast Arcane Shot", "an empty trailing clause is collapsed")
lossless("/cast Arcane Shot;", "/cast Arcane Shot", "empty trailing clause")
equal(
	ns.Shorten("/cast Arcane Shot; Mend Pet; Revive Pet").text,
	"/cast Arcane Shot",
	"clauses after an unconditional one are dropped"
)
lossless("/cast Arcane Shot; Mend Pet; Revive Pet", "/cast Arcane Shot", "unreachable after unconditional")
equal(
	ns.Shorten("/cast [harm] A; [harm] B; [nodead] C").text,
	"/cast [harm] A;[nodead] C",
	"a clause that repeats an earlier clause is dropped"
)
lossless("/cast [harm] A; [harm] B; [nodead] C", "/cast [harm] A;[nodead] C", "repeated condition")

-- A directive keeps its own word, and a macro that is already tight comes back unchanged.
equal(ns.Shorten("#showtooltip   ").text, "#showtooltip", "a directive keeps its word and loses trailing space")
equal(ns.Shorten("/cast Arcane Shot").text, "/cast Arcane Shot", "a tight macro is unchanged")
equal(ns.Shorten("").text, "", "an empty macro stays empty")
equal(ns.Shorten("/cast A\n").text, "/cast A\n", "a trailing newline is kept")

-- The result says how many characters the rewrite saves, and never reports a negative saving.
local saved = ns.Shorten("/spell [harm, nodead] Arcane Shot")
equal(
	saved.saved,
	ns.Length("/spell [harm, nodead] Arcane Shot") - ns.Length(saved.text),
	"the saving is the length difference"
)
assert(saved.saved > 0, "a spaced /spell macro saves characters")
equal(ns.Shorten("/cast Arcane Shot").saved, 0, "a tight macro saves nothing")

print(("%d checks passed"):format(checks))
