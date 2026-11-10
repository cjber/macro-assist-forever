-- Run from the repository root: luajit tests/core_dependency_spec.lua
-- Macro Assist Forever requires ForeverCore. The game refuses to load the addon when ForeverCore is absent, but an
-- older ForeverCore still loads, so Core/Require.lua stops the addon's own files with one line in the error frame,
-- never a chat message.
local TEXT = "Macro Assist Forever needs ForeverCore, which is missing or too old."

local function Require(foreverCore)
	local lines = {}
	local env = {
		UIErrorsFrame = {
			AddMessage = function(_, text, red, green, blue)
				lines[#lines + 1] = { text = text, red = red, green = green, blue = blue }
			end,
		},
	}
	env._G = env
	setmetatable(env, { __index = _G })
	env.ForeverCore = foreverCore
	local ns = {}
	setfenv(assert(loadfile("Locales/enUS.lua")), env)("MacroAssistForever", ns)
	setfenv(assert(loadfile("Core/Require.lua")), env)("MacroAssistForever", ns)
	return ns, lines
end

local missing, missingLines = Require(nil)
assert(missing.broken == true, "a missing ForeverCore stops the addon")
assert(#missingLines == 1 and missingLines[1].text == TEXT, "and says so in one error line")
assert(missingLines[1].red == 1 and missingLines[1].green ~= 1, "the line is red")

local old, oldLines = Require({ API = 0 })
assert(old.broken == true, "a ForeverCore older than API 1 stops the addon")
assert(#oldLines == 1 and oldLines[1].text == TEXT, "with the same one line")

local ready, readyLines = Require({ API = 1 })
assert(ready.broken == nil, "API 1 runs the addon")
assert(#readyLines == 0, "and says nothing")

print("core_dependency_spec: the API floor stops an old ForeverCore with one line")
