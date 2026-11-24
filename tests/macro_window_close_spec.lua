local function runClose(hasPanel, panelShown)
	local windowHidden, panelHidden = false, false
	local env = setmetatable({
		HideUIPanel = function()
			error("closing the macro window must bypass HideUIPanel")
		end,
	}, { __index = _G })
	if hasPanel then
		env.MacroFrame = {
			IsShown = function()
				return panelShown
			end,
			Hide = function()
				panelHidden = true
			end,
		}
	end

	local ns = {}
	setfenv(assert(loadfile("UI/MacroWindow.lua")), env)("MacroAssistForever", ns)
	ns.MacroWindow.frame = {
		Hide = function()
			windowHidden = true
		end,
	}

	ns.MacroWindow.ClosePanel()
	assert(panelHidden == panelShown, "a visible Blizzard macro panel should close through its frame")
	assert(windowHidden ~= panelShown, "the standalone overlay should close when Blizzard's panel is absent or hidden")
end

runClose(true, true)
runClose(true, false)
runClose(false, false)

print("macro_window_close_spec: ok")
