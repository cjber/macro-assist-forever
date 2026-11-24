local function runClose(panelShown, gamepadUI, combat)
	local closeCalls, windowHidden = 0, false
	local panel = {
		IsShown = function()
			return panelShown
		end,
	}
	local env = setmetatable({
		MacroFrame = panel,
		InputUtil = {
			IsGamepadUIEnabled = function()
				return gamepadUI
			end,
		},
		InCombatLockdown = function()
			return combat
		end,
		HideUIPanel = function(frame)
			assert(frame == panel, "the panel manager should close the Blizzard frame")
			closeCalls = closeCalls + 1
		end,
	}, { __index = _G })

	local ns = {}
	setfenv(assert(loadfile("UI/MacroWindow.lua")), env)("MacroAssistForever", ns)
	ns.MacroWindow.frame = {
		Hide = function()
			windowHidden = true
		end,
	}

	ns.MacroWindow.ClosePanel()
	local canClosePanel = panelShown and not gamepadUI and not combat
	assert(closeCalls == (canClosePanel and 1 or 0), "only an unmanaged visible panel should use HideUIPanel")
	assert(windowHidden ~= panelShown, "the standalone overlay should close directly")
end

runClose(true, true, false)
runClose(true, false, true)
runClose(true, false, false)
runClose(false, true, true)

print("macro_window_close_spec: ok")
