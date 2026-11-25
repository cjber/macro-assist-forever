local function runClose(panelShown, gamepadUI, combat)
	local windowHidden = false
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
		HideUIPanel = function()
			error("ClosePanel ran the panel manager from addon code (ADDON_ACTION_FORBIDDEN under the gamepad UI)")
		end,
	}, { __index = _G })

	local ns = {}
	setfenv(assert(loadfile("UI/MacroWindow.lua")), env)("MacroAssistForever", ns)
	ns.MacroWindow.frame = {
		Hide = function()
			windowHidden = true
		end,
	}

	local closed = ns.MacroWindow.ClosePanel()
	assert(closed == not panelShown, "a paired panel is left for Blizzard to close")
	assert(windowHidden ~= panelShown, "only the standalone overlay closes directly")
end

runClose(true, true, false)
runClose(true, false, true)
runClose(true, false, false)
runClose(false, true, true)

print("macro_window_close_spec: ok")
