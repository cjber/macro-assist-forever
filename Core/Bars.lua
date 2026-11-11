local _, ns = ...

if ns.broken then
	return
end

-- The action slots and the binding each one uses. A slot is the number GetActionInfo takes; the binding name is what
-- GetBindingKey takes to answer the key the player bound to it. The client lays the bars out in this order, with the
-- main bar first and the four multi bars counting right to left from the bottom right (Blizzard_ActionBar's
-- MultiActionBar_Update and the BINDING_NAME_MULTIACTIONBAR entries):
--
--   1-12     ACTIONBUTTON1-12             the main bar
--   61-72    MULTIACTIONBAR1BUTTON1-12    bottom right
--   49-60    MULTIACTIONBAR2BUTTON1-12    bottom left
--   37-48    MULTIACTIONBAR3BUTTON1-12    right
--   25-36    MULTIACTIONBAR4BUTTON1-12    left
--   73-84    MULTIACTIONBAR5BUTTON1-12
--   85-96    MULTIACTIONBAR6BUTTON1-12
--   97-108   MULTIACTIONBAR7BUTTON1-12
--
-- Slots 13-24 and 109-120 are not shown on a Blizzard bar, so they carry no binding the player can press.
local BARS = {
	{ first = 1, last = 12, prefix = "ACTIONBUTTON" },
	{ first = 61, last = 72, prefix = "MULTIACTIONBAR1BUTTON" },
	{ first = 49, last = 60, prefix = "MULTIACTIONBAR2BUTTON" },
	{ first = 37, last = 48, prefix = "MULTIACTIONBAR3BUTTON" },
	{ first = 25, last = 36, prefix = "MULTIACTIONBAR4BUTTON" },
	{ first = 73, last = 84, prefix = "MULTIACTIONBAR5BUTTON" },
	{ first = 85, last = 96, prefix = "MULTIACTIONBAR6BUTTON" },
	{ first = 97, last = 108, prefix = "MULTIACTIONBAR7BUTTON" },
}

local bindings = {}
for _, bar in ipairs(BARS) do
	for slot = bar.first, bar.last do
		bindings[slot] = bar.prefix .. (slot - bar.first + 1)
	end
end

-- The Blizzard binding name for an action slot, or nil for a slot no Blizzard bar shows.
---@param slot integer
---@return string?
local function Binding(slot)
	if type(slot) ~= "number" then
		return nil
	end
	return bindings[slot]
end

ns.Bars = {
	Binding = Binding,
}
