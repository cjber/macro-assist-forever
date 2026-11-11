local _, ns = ...

if ns.broken then
	return
end

-- The action slots and the binding each one uses. A slot is the number GetActionInfo takes; the binding name is what
-- GetBindingKey takes to answer the key the player bound to it. A bar's page is its actionpage in
-- Blizzard_ActionBar/Shared/MultiActionBars.xml, and page N covers slots (N-1)*12+1 through N*12:
--
--   1-12     ACTIONBUTTON1-12             MainActionBar, page 1
--   61-72    MULTIACTIONBAR1BUTTON1-12    MultiBarBottomLeft, page 6
--   49-60    MULTIACTIONBAR2BUTTON1-12    MultiBarBottomRight, page 5
--   25-36    MULTIACTIONBAR3BUTTON1-12    MultiBarRight, page 3
--   37-48    MULTIACTIONBAR4BUTTON1-12    MultiBarLeft, page 4
--   145-156  MULTIACTIONBAR5BUTTON1-12    MultiBar5, page 13
--   157-168  MULTIACTIONBAR6BUTTON1-12    MultiBar6, page 14
--   169-180  MULTIACTIONBAR7BUTTON1-12    MultiBar7, page 15
--
-- While a stance is active the main bar shows one of the four bonus pages, 7 through 10, and ACTIONBUTTON1-12 press
-- that page's slots instead of page 1 (GetBonusBarOffset: base (NUM_ACTIONBAR_PAGES + offset - 1) * 12, as
-- Blizzard_Tutorials_RPE.lua uses it). Slots 73-120 are those pages, so their binding is ACTIONBUTTON too.
--
-- Slots 13-24 and 121-144 belong to pages no fixed Blizzard bar shows, so they carry no binding here.
local BARS = {
	{ page = 1, prefix = "ACTIONBUTTON" },
	{ page = 6, prefix = "MULTIACTIONBAR1BUTTON" },
	{ page = 5, prefix = "MULTIACTIONBAR2BUTTON" },
	{ page = 3, prefix = "MULTIACTIONBAR3BUTTON" },
	{ page = 4, prefix = "MULTIACTIONBAR4BUTTON" },
	{ page = 13, prefix = "MULTIACTIONBAR5BUTTON" },
	{ page = 14, prefix = "MULTIACTIONBAR6BUTTON" },
	{ page = 15, prefix = "MULTIACTIONBAR7BUTTON" },
}

local STANCE_PAGES = { 7, 8, 9, 10 }

local function AddPage(bindings, page, prefix)
	local first = (page - 1) * 12 + 1
	for button = 1, 12 do
		bindings[first + button - 1] = prefix .. button
	end
end

local bindings = {}
for _, bar in ipairs(BARS) do
	AddPage(bindings, bar.page, bar.prefix)
end
for _, page in ipairs(STANCE_PAGES) do
	AddPage(bindings, page, "ACTIONBUTTON")
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
