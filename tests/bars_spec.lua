-- The action slot to Blizzard binding map: every slot a bar shows names the binding whose key the player presses, and
-- a slot no bar shows names nothing.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %q, got %q"):format(label, tostring(expected), tostring(actual)))
end

local ns = {}
local chunk = assert(loadfile("Core/Bars.lua"))
chunk("MacroAssistForever", ns)

equal(ns.Bars.Binding(1), "ACTIONBUTTON1", "the main bar starts at action slot 1")
equal(ns.Bars.Binding(12), "ACTIONBUTTON12", "the main bar ends at action slot 12")
equal(ns.Bars.Binding(61), "MULTIACTIONBAR1BUTTON1", "the bottom-right bar starts at action slot 61")
equal(ns.Bars.Binding(72), "MULTIACTIONBAR1BUTTON12", "the bottom-right bar ends at action slot 72")
equal(ns.Bars.Binding(49), "MULTIACTIONBAR2BUTTON1", "the bottom-left bar starts at action slot 49")
equal(ns.Bars.Binding(60), "MULTIACTIONBAR2BUTTON12", "the bottom-left bar ends at action slot 60")
equal(ns.Bars.Binding(37), "MULTIACTIONBAR3BUTTON1", "the right bar starts at action slot 37")
equal(ns.Bars.Binding(48), "MULTIACTIONBAR3BUTTON12", "the right bar ends at action slot 48")
equal(ns.Bars.Binding(25), "MULTIACTIONBAR4BUTTON1", "the left bar starts at action slot 25")
equal(ns.Bars.Binding(36), "MULTIACTIONBAR4BUTTON12", "the left bar ends at action slot 36")
equal(ns.Bars.Binding(73), "MULTIACTIONBAR5BUTTON1", "the fifth bar starts at action slot 73")
equal(ns.Bars.Binding(96), "MULTIACTIONBAR6BUTTON12", "the sixth bar ends at action slot 96")
equal(ns.Bars.Binding(97), "MULTIACTIONBAR7BUTTON1", "the seventh bar starts at action slot 97")
equal(ns.Bars.Binding(108), "MULTIACTIONBAR7BUTTON12", "the seventh bar ends at action slot 108")

-- The slots between and after the bars have no key: a macro there cannot be pressed.
for _, slot in ipairs({ 0, 13, 24, 109, 120, 121 }) do
	equal(ns.Bars.Binding(slot), nil, "action slot " .. slot .. " has no Blizzard binding")
end
equal(ns.Bars.Binding(nil), nil, "a missing slot has no binding")
equal(ns.Bars.Binding("1"), nil, "a string is not an action slot")

print(("%d checks passed"):format(checks))
