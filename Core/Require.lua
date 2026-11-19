local addonName, ns = ...

-- The one client icon this addon shows for itself in game, declared once in the TOC and read here so no other file
-- repeats the path. The window portrait and every other identity surface draw this value.
ns.Icon = C_AddOns.GetAddOnMetadata(addonName, "X-Forever-Icon")

-- The game refuses to load this addon when ForeverCore is absent (## Dependencies), but an older ForeverCore still
-- loads. Its members say whether it has everything this addon calls, so an out-of-date one stops the addon's own
-- files here. The warning itself is Core/ForeverRequire.lua, shared by every Forever addon. It names the addon to
-- update, never ForeverCore.
--
-- Register supplies shared services; APIKit's minor 2 members supply the public engine's argument errors and
-- discovery. Stop before loading the API if any member is absent, so the shared warning explains an older core.
local ready = ForeverCore ~= nil
	and type(ForeverCore.Register) == "function"
	and type(ForeverCore.APIKit) == "table"
	and type(ForeverCore.APIKit.Invalid) == "function"
	and type(ForeverCore.APIKit.Publish) == "function"

-- Core/Core.lua's slash words; the pin gate (forever_tools.require_slash) keeps the two lists equal. A
-- stopped addon still answers them with the line that names the fix, as its addon compartment entry does.
ns.Slash = { key = "MACROASSISTFOREVER", "/macroassist" }

ns.ForeverRequire(ready, ns.Slash)
