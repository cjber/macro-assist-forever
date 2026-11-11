local addonName, ns = ...

-- The one client icon this addon shows for itself in game, declared once in the TOC and read here so no other file
-- repeats the path. The window portrait and every other identity surface draw this value.
ns.Icon = C_AddOns.GetAddOnMetadata(addonName, "X-Forever-Icon")

-- The game refuses to load this addon when ForeverCore is absent (## Dependencies), but an older ForeverCore still
-- loads. Its members say whether it has everything this addon calls, so an out-of-date one stops the addon's own
-- files here. The warning itself is Core/ForeverRequire.lua, shared by every Forever addon. It names the addon to
-- update, never ForeverCore.
--
-- Register is the one ForeverCore member this addon calls directly: Core/Core.lua uses it for the report window, the
-- journal and the log. No member this addon calls arrived after API 1, so its presence is the whole check.
local ready = ForeverCore ~= nil and type(ForeverCore.Register) == "function"

ns.ForeverRequire(ready)
