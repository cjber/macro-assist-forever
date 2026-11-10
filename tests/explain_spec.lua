-- The list summary comes from the parse tree: a default action first, alternatives with their condition phrases, and
-- no invented meaning for text it does not understand.
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
load("Core/Explain.lua")

equal(
	ns.Explain("/cast [mod:shift] Wing Clip; Raptor Strike"),
	"Raptor Strike, Wing Clip on Shift",
	"the default action comes first, then the shifted one"
)
equal(
	ns.Explain("/cast [@mouseover,harm,nodead][] Arcane Shot"),
	"Arcane Shot, mouseover first",
	"a mouseover group over a fallback is the mouseover-first case"
)
equal(
	ns.Explain("/cast [mod:alt] Aspect of the Cheetah"),
	"Aspect of the Cheetah on Alt",
	"a condition with a phrase stays attached to its action"
)
equal(
	ns.Explain("/cast [bogus] Fireball"),
	"Fireball",
	"an unknown condition contributes no phrase, so the spell is listed"
)
equal(
	ns.Explain("/castsequence reset=target Serpent Sting, Arcane Shot"),
	"Serpent Sting, Arcane Shot",
	"a castsequence lists its spells once, without reset="
)
equal(ns.Explain("/petattack [@mouseover,harm,nodead][]"), "Pet attack, mouseover first", "a command with no argument")
equal(ns.Explain("#showtooltip\n/cast Fireball"), "Fireball", "a directive is not an action")
equal(ns.Explain("#showtooltip"), "", "a directive-only macro has no summary")
equal(ns.Explain(""), "", "an empty body has no summary")
equal(ns.Explain("/cast Fireball\n/cast Frostbolt"), "Fireball, Frostbolt", "each command line adds its action")

-- The same spell is not repeated when two clauses do it.
equal(
	ns.Explain("/cast [harm] Fireball; Fireball"),
	"Fireball, Fireball on an enemy",
	"a repeated action keeps its condition on the alternative"
)

-- The "What it does" panel reads each click and modifier branch from the parse, then joins the commands that run
-- either way into one "Also" sentence. The Arcane macro is the panel's reference case.
local arcane = table.concat({
	"#showtooltip",
	"/cast [@mouseover,harm,nodead][] Arcane Shot",
	"/cast [mod:shift] Concussive Shot",
	"/petattack [@mouseover,harm,nodead][]",
	"/startattack",
}, "\n")
local cases = ns.ExplainCases(arcane)
equal(#cases, 3, "the Arcane macro has three cases")
equal(cases[1].key, "Click", "the default branch is Click")
equal(
	cases[1].text,
	"Arcane Shot your mouseover enemy, otherwise your target",
	"the click branch names the mouseover enemy and the fallback target"
)
equal(cases[2].key, "Shift", "the modifier branch is Shift")
equal(cases[2].text, "Concussive Shot your target", "the shift branch names the spell and the target")
equal(cases[3].key, "Also", "the commands with no branch are Also")
equal(
	cases[3].text,
	"Pet attacks your mouseover enemy, then you start attacking",
	"the Also sentence joins the pet attack and startattack"
)

local helpCases = ns.ExplainCases("/cast [@mouseover,help,nodead][] Flash Heal")
equal(helpCases[1].text, "Flash Heal your mouseover friend, otherwise your target", "help names a mouseover friend")

local playerCases = ns.ExplainCases("/cast [@player] Heavy Runecloth Bandage")
equal(playerCases[1].text, "Heavy Runecloth Bandage yourself", "the player unit reads as yourself")

local controlCases = ns.ExplainCases("/cast [mod:ctrl] Frost Nova; [mod:alt] Blink")
equal(#controlCases, 2, "the two modifier clauses make two cases")
equal(controlCases[1].key, "Ctrl", "a ctrl clause is Ctrl")
equal(controlCases[2].key, "Alt", "an alt clause is Alt")

equal(#ns.ExplainCases("/cast [bogus] Fireball"), 1, "a clause with an unknown condition still names its action")
equal(#ns.ExplainCases("/unknowncommand"), 0, "an unknown command adds no case")
equal(#ns.ExplainCases("#showtooltip"), 0, "a directive adds no case")
equal(#ns.ExplainCases(""), 0, "an empty body has no cases")

print(("explain: %d checks"):format(checks))
