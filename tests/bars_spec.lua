-- The action slot to Blizzard binding map: every slot a bar shows names the binding whose key the player presses, and
-- a slot no fixed bar shows names nothing. The slots come from each bar's actionpage in MultiActionBars.xml, so page N
-- covers (N-1)*12+1 through N*12.
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
equal(ns.Bars.Binding(61), "MULTIACTIONBAR1BUTTON1", "MultiBarBottomLeft (page 6) starts at action slot 61")
equal(ns.Bars.Binding(72), "MULTIACTIONBAR1BUTTON12", "MultiBarBottomLeft (page 6) ends at action slot 72")
equal(ns.Bars.Binding(49), "MULTIACTIONBAR2BUTTON1", "MultiBarBottomRight (page 5) starts at action slot 49")
equal(ns.Bars.Binding(60), "MULTIACTIONBAR2BUTTON12", "MultiBarBottomRight (page 5) ends at action slot 60")
equal(ns.Bars.Binding(25), "MULTIACTIONBAR3BUTTON1", "MultiBarRight (page 3) starts at action slot 25")
equal(ns.Bars.Binding(36), "MULTIACTIONBAR3BUTTON12", "MultiBarRight (page 3) ends at action slot 36")
equal(ns.Bars.Binding(37), "MULTIACTIONBAR4BUTTON1", "MultiBarLeft (page 4) starts at action slot 37")
equal(ns.Bars.Binding(48), "MULTIACTIONBAR4BUTTON12", "MultiBarLeft (page 4) ends at action slot 48")
equal(ns.Bars.Binding(145), "MULTIACTIONBAR5BUTTON1", "MultiBar5 (page 13) starts at action slot 145")
equal(ns.Bars.Binding(156), "MULTIACTIONBAR5BUTTON12", "MultiBar5 (page 13) ends at action slot 156")
equal(ns.Bars.Binding(157), "MULTIACTIONBAR6BUTTON1", "MultiBar6 (page 14) starts at action slot 157")
equal(ns.Bars.Binding(168), "MULTIACTIONBAR6BUTTON12", "MultiBar6 (page 14) ends at action slot 168")
equal(ns.Bars.Binding(169), "MULTIACTIONBAR7BUTTON1", "MultiBar7 (page 15) starts at action slot 169")
equal(ns.Bars.Binding(180), "MULTIACTIONBAR7BUTTON12", "MultiBar7 (page 15) ends at action slot 180")

-- The four bonus (stance) pages are what the main bar shows while a stance is active, so the ACTIONBUTTON keys press
-- their slots and every one of 73-120 names a key.
equal(ns.Bars.Binding(73), "ACTIONBUTTON1", "the first stance page starts at action slot 73")
equal(ns.Bars.Binding(84), "ACTIONBUTTON12", "the first stance page ends at action slot 84")
equal(ns.Bars.Binding(85), "ACTIONBUTTON1", "the second stance page starts at action slot 85")
equal(ns.Bars.Binding(96), "ACTIONBUTTON12", "the second stance page ends at action slot 96")
equal(ns.Bars.Binding(97), "ACTIONBUTTON1", "the third stance page starts at action slot 97")
equal(ns.Bars.Binding(108), "ACTIONBUTTON12", "the third stance page ends at action slot 108")
equal(ns.Bars.Binding(109), "ACTIONBUTTON1", "the fourth stance page starts at action slot 109")
equal(ns.Bars.Binding(120), "ACTIONBUTTON12", "the fourth stance page ends at action slot 120")

-- The pages between and after the fixed bars have no key: a macro there cannot be pressed.
for _, slot in ipairs({ 0, 13, 24, 121, 144, 181 }) do
	equal(ns.Bars.Binding(slot), nil, "action slot " .. slot .. " has no Blizzard binding")
end
equal(ns.Bars.Binding(nil), nil, "a missing slot has no binding")
equal(ns.Bars.Binding("1"), nil, "a string is not an action slot")

print(("%d checks passed"):format(checks))
