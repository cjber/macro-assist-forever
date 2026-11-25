-- Closing the paired window must not call HideUIPanel from addon code: on the gamepad binding teardown path that
-- reaches the protected SetPreferredGamepadInteractTarget, tainting the addon. A plain MacroFrame:Hide runs the
-- panel's own OnHide instead, so the window and the manager's tracking still close.
local function runClose(panelShown, gamepadUI, combat)
	local hideUIPanelCalls, panelHideCalls, windowHidden = 0, 0, false
	local panel = {
		IsShown = function()
			return panelShown
		end,
		Hide = function()
			panelHideCalls = panelHideCalls + 1
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
			hideUIPanelCalls = hideUIPanelCalls + 1
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
	assert(hideUIPanelCalls == 0, "ClosePanel must not route Blizzard's panel through HideUIPanel")
	assert(panelHideCalls == (canClosePanel and 1 or 0), "a managed panel should be hidden directly")
	assert(windowHidden ~= panelShown, "the standalone overlay should close directly")
end

runClose(true, true, false)
runClose(true, false, true)
runClose(true, false, false)
runClose(false, true, true)
runClose(false, false, false)

print("macro_window_close_spec: ok")
