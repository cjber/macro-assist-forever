-- The parser turns real macros into command, condition and argument nodes with byte offsets, and never errors.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end
local function yes(value, label)
	equal(not not value, true, label)
end

local ns = {}
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("MacroAssistForever", ns)
end
load("Locales/enUS.lua")
load("Core/Lexer.lua")
load("Core/Parser.lua")

local function parse(text)
	return ns.Parser.Parse(text)
end

-- The issue's mouseover macro: two directives, three ORed target groups, and a ranked spell.
local text = "#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] Flash Heal(Rank 3)"
local parsed = parse(text)
equal(#parsed.lines, 2, "the macro has two lines")
equal(parsed.lines[1].kind, "directive", "the first line is a directive")
equal(parsed.lines[1].directive, "showtooltip", "the directive is showtooltip")
equal(#parsed.lines[1].clauses, 0, "an empty showtooltip has no clause")
equal(parsed.lines[2].kind, "command", "the second line is a command")
equal(parsed.lines[2].command.name, "cast", "the command is cast")
equal(parsed.lines[2].command.from, text:find("/cast", 1, true), "the command starts at its slash")
equal(parsed.lines[2].command.to, text:find("/cast", 1, true) + 4, "the command ends after its name")
local clause = parsed.lines[2].clauses[1]
yes(clause ~= nil, "the cast line has a clause")
equal(#clause.groups, 3, "three bracketed groups are ORed in the clause")
equal(clause.groups[1].unit.kind, "at", "the first group uses @")
equal(clause.groups[1].unit.token, "mouseover", "the first group targets mouseover")
equal(#clause.groups[1].conditions, 2, "the first group has help and nodead")
equal(clause.groups[1].conditions[1].name, "help", "help is a condition")
equal(clause.groups[1].conditions[1].no, false, "help has no no prefix")
equal(clause.groups[1].conditions[2].rawName, "nodead", "nodead is kept as typed")
equal(clause.groups[1].conditions[2].name, "dead", "nodead names dead")
equal(clause.groups[1].conditions[2].no, true, "nodead carries the no prefix")
equal(clause.groups[2].unit, nil, "the second group has no target")
equal(clause.groups[3].unit.token, "player", "the third group targets the player")
equal(#clause.groups[3].conditions, 0, "the player group has no conditions")
equal(clause.unconditional, true, "a group with no conditions makes the clause unconditional")
equal(clause.args.text, "Flash Heal(Rank 3)", "the argument keeps the rank suffix")
local item = clause.args.items[1]
equal(item.name, "Flash Heal", "the rank is stripped from the name")
equal(item.rank, 3, "the rank is a number")
equal(item.nameFrom, text:find("Flash Heal", 1, true), "the name's first byte")
equal(item.nameTo, text:find("Flash Heal", 1, true) + 9, "the name's last byte")
equal(item.rankFrom, text:find("Rank 3", 1, true) + 5, "the rank digit's first byte")
equal(item.rankTo, item.rankFrom, "a one-digit rank")
equal(#parsed.diagnostics, 0, "the well-formed macro has no parser diagnostics")

-- The issue's unreachable-clause macro.
text = "/cast [mod:shift] Aspect of the Cheetah; [] Aspect of the Hawk; Aspect of the Monkey"
parsed = parse(text)
clause = parsed.lines[1].clauses[1]
equal(#parsed.lines[1].clauses, 3, "three clauses are separated by semicolons")
equal(clause.groups[1].conditions[1].name, "mod", "mod is a condition")
equal(clause.groups[1].conditions[1].param, "shift", "mod takes shift")
equal(clause.groups[1].conditions[1].paramFrom, text:find("shift", 1, true), "the parameter's first byte")
equal(parsed.lines[1].clauses[2].unconditional, true, "the empty [] clause always matches")
equal(#parsed.lines[1].clauses[2].groups, 1, "[] is still one group")
equal(parsed.lines[1].clauses[3].unconditional, true, "a clause with no groups always matches")
equal(parsed.lines[1].clauses[3].args.text, "Aspect of the Monkey", "the last clause keeps its argument")

-- A castsequence reset is an option, not a spell.
text = "/castsequence reset=10/target/combat Shadow Word: Pain, Mind Flay"
parsed = parse(text)
clause = parsed.lines[1].clauses[1]
equal(#clause.args.items, 2, "the sequence has two steps")
equal(clause.args.items[1].reset, true, "the first step is a reset option")
equal(clause.args.items[1].resetValues[1], "10", "reset=10")
equal(clause.args.items[1].resetValues[2], "target", "reset=target")
equal(clause.args.items[1].resetValues[3], "combat", "reset=combat")
equal(clause.args.items[1].name, "Shadow Word: Pain", "the first spell follows the reset")
equal(clause.args.items[2].name, "Mind Flay", "the second spell")
equal(clause.args.items[2].reset, nil, "the second step is not a reset")

-- Toggle prevention: the ! belongs to the spell, not the command.
text = "/cast !Stealth"
parsed = parse(text)
item = parsed.lines[1].clauses[1].args.items[1]
equal(item.bang, true, "the spell has the ! prefix")
equal(item.bangFrom, text:find("!", 1, true), "the ! prefix has its own offset")
equal(item.name, "Stealth", "the ! is stripped from the name")
equal(item.nameFrom, text:find("Stealth", 1, true), "the name starts after the !")

-- A ! before the slash is a line-level prefix, not a spell toggle.
parsed = parse("!/cast A")
equal(parsed.lines[1].kind, "command", "a bang before the slash is still a command")
equal(parsed.lines[1].bang, true, "the line keeps the bang")
equal(parsed.lines[1].bangFrom, 1, "the line bang starts at 1")
equal(parsed.lines[1].command.name, "cast", "the command follows the bang")

-- target=unit is an alias for @unit.
text = "/use [target=focus,harm] 13"
parsed = parse(text)
local group = parsed.lines[1].clauses[1].groups[1]
equal(group.unit.kind, "target", "target= is a target node")
equal(group.unit.token, "focus", "target=focus names focus")
equal(group.conditions[1].name, "harm", "the group also has harm")
equal(parsed.lines[1].clauses[1].args.items[1].name, "13", "an item slot is an argument")

-- #show takes conditions and a spell name.
text = "#show [harm] Fireball"
parsed = parse(text)
equal(parsed.lines[1].directive, "show", "the directive is show")
equal(parsed.lines[1].clauses[1].groups[1].conditions[1].name, "harm", "the directive reads conditions")
equal(parsed.lines[1].clauses[1].args.text, "Fireball", "the directive keeps the spell")

-- A malformed bracket produces a diagnostic and still parses what it can.
text = "/cast [help,nodead Flash Heal"
parsed = parse(text)
equal(parsed.lines[1].clauses[1].groups[1].closed, false, "the group is open")
equal(parsed.lines[1].clauses[1].groups[1].conditions[1].name, "help", "the first condition survives")
equal(parsed.diagnostics[1].code, "unclosed-bracket", "the missing ] is reported")
equal(parsed.diagnostics[1].from, text:find("[", 1, true), "the diagnostic starts at [")
equal(parsed.diagnostics[1].to, #text, "the diagnostic reaches the end of the line")

-- Malformed input never raises.
for _, broken in ipairs({
	"",
	"/",
	"[",
	"[]]",
	";;;",
	"/cast (Rank )",
	"/cast [mod:",
	"/cast []",
	"!/cast",
	"/castsequence reset=",
	"#showtooltip [",
}) do
	local ok = pcall(parse, broken)
	equal(ok, true, "parsing does not raise: " .. broken)
end

-- Byte ranges of the lines themselves.
parsed = parse("/cast A\n/cast B")
equal(parsed.lines[1].from, 1, "the first line starts at 1")
equal(parsed.lines[1].to, 7, "the first line ends before the newline")
equal(parsed.lines[2].from, 9, "the second line starts after the newline")
parsed = parse("")
equal(#parsed.lines, 1, "empty text has one line")
equal(parsed.lines[1].from, 1, "the empty line starts at 1")
equal(parsed.lines[1].to, 0, "the empty line ends at 0")
equal(parsed.lines[1].kind, "empty", "the line is empty")
parsed = parse("/cast A\n")
equal(#parsed.lines, 2, "a trailing newline adds an empty line")
equal(parsed.lines[2].kind, "empty", "the trailing line is empty")

print(("parser_spec: %d checks passed"):format(checks))
