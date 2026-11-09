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

print(("explain: %d checks"):format(checks))
