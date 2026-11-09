-- The macro window (WFA-35): the player's way in through /macro (ShowMacroFrame, which the slash handler calls), /ma,
-- /macroassist and the addon compartment, a cold /ma that never loads Blizzard_MacroUI, the list and both tabs,
-- editing and saving, completion and a fix, New, Change Name/Icon and Delete, closing by our X and the editor's Escape,
-- reopening, combat with the window open, the gamepad interface on and off, and an old saved file.
-- luacheck: read globals scenario ADDON

local world = assert(loadfile("tests/sim/macro_world.lua"))()

local PLAYER = "MacroAssistForeverFrame"

local function check(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function equal(actual, expected, label)
	check(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

local function open(sim)
	-- This is the function Blizzard's /macro handler calls (Blizzard_ChatFrameBase/Shared/SlashCommands.lua). The
	-- simulator does not register the client's chat command table, so calling it is the same path from our side.
	sim:input(function()
		sim.G.ShowMacroFrame()
	end)
	sim:advance(0.3)
	local window = sim.G[PLAYER]
	check(window, "the addon did not build its window")
	check(sim.G.MacroFrame:IsShown(), "Blizzard's MacroFrame is not shown")
	check(window:IsShown(), "our window is not shown over MacroFrame")
	check(sim.G.MacroFrame:GetAlpha() == 0, "MacroFrame is not drawn at alpha 0 under our window")
	check(window:GetWidth() >= sim.G.MacroFrame:GetWidth(), "our window is narrower than MacroFrame")
	check(window:GetHeight() >= sim.G.MacroFrame:GetHeight(), "our window is shorter than MacroFrame")
	check(window:GetFrameLevel() > sim.G.MacroFrame:GetFrameLevel(), "our window is not above MacroFrame")
	check(window:IsMouseEnabled(), "our window does not take the mouse over MacroFrame")
	return window
end

local function rows(window)
	local out = {}
	window.scrollBox:ForEachFrame(function(row)
		if row:IsShown() and row.macroIndex then
			out[#out + 1] = row
		end
	end)
	return out
end

local function rowNamed(window, name)
	for _, row in ipairs(rows(window)) do
		if row.Name:GetText() == name then
			return row
		end
	end
end

local function selectedRow(window)
	for _, row in ipairs(rows(window)) do
		if row.Selected:IsShown() then
			return row
		end
	end
end

local function textOf(window)
	return window.editor.edit:GetText()
end

local function setText(sim, window, text, edited)
	sim:input(function()
		window.editor.edit:SetText(text)
		window.editor.edit:SetCursorPosition(#text)
		window.editor:RefreshAll()
	end)
	if edited then
		window.editor.onEdited()
	end
	sim:advance(0.05)
end

local function characterTab(sim, window)
	sim:click(window.Tabs[2])
	sim:advance(0.1)
	return window
end

local function openNamed(sim)
	world.install(sim)
	sim.world.units.target = { name = "Defias Pillager", level = 12, friendly = false }
	sim:login()
	return open(sim)
end

scenario("the list, both tabs and the editor show the selected macro", function(sim)
	local window = openNamed(sim)
	equal(#rows(window), 2, "the General tab lists only account macros")
	equal(selectedRow(window).Name:GetText(), "General One", "the first account macro is selected")
	equal(window.header.meta:GetText(), "General macro · 2 of 120", "the header counts account macros")
	equal(
		window.editor.status:GetText():find("Now: Arcane Shot", 1, true) ~= nil,
		true,
		"the status says what fires now"
	)

	characterTab(sim, window)
	local arcane = rowNamed(window, "Arcane")
	check(arcane, "the character tab does not list Arcane")
	equal(#rows(window), 5, "the character tab lists only character macros")
	equal(selectedRow(window).Name:GetText(), "Arcane", "the first character macro is selected")
	equal(window.header.name:GetText(), "Arcane", "the header shows the selected name")
	equal(window.header.meta:GetText(), "Character macro · 5 of 30", "the header counts character macros")
	equal(textOf(window), "#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot", "the editor holds the body")
	equal(
		window.editor.status:GetText():find("Now: Arcane Shot on Defias Pillager", 1, true) ~= nil,
		true,
		"the live line includes the target"
	)
	equal(arcane.Summary:GetText(), "Arcane Shot, mouseover first", "the row summarises the macro")

	local trap = rowNamed(window, "Trap")
	sim:click(trap)
	sim:advance(0.1)
	equal(selectedRow(window).Name:GetText(), "Trap", "clicking a row selects it")
	equal(window.editor.edit:GetText(), "/cast Freezing Trap", "the editor follows the selection")
	local drag = trap:GetScript("OnDragStart")
	sim:input(function()
		drag(trap)
	end)
	equal(sim.pickedMacro, trap.macroIndex, "dragging a row picks up its macro")
end)

scenario("completion, a problem and its fix", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	local editor = window.editor
	local original = textOf(window)
	setText(sim, window, "/cast Arc")
	sim:input(function()
		editor:RefreshCompletions()
	end)
	check(editor.popup:IsShown(), "completion did not open for /cast Arc")
	check(#editor.completion.items > 0, "completion returned no items")
	local down = editor.edit:GetScript("OnArrowPressed")
	check(down(editor.edit, "DOWN"), "Down did not move the completion selection")
	local tab = editor.edit:GetScript("OnTabPressed")
	check(tab(editor.edit), "Tab did not insert the highlighted completion")
	check(textOf(window):find("Arcane Shot", 1, true) ~= nil, "the completion was not inserted")
	check(not editor.popup:IsShown(), "the popup stayed open after insertion")

	setText(sim, window, "/cast Nope", true)
	check(#editor.diagnostics == 1, "an unknown spell was not reported")
	check(editor.diagnostics[1].code == "unknown-spell", "the wrong diagnostic was reported")
	local squiggle
	for _, frame in ipairs(editor.squiggles) do
		if frame:IsShown() then
			squiggle = frame
			break
		end
	end
	check(squiggle, "no squiggle was drawn")
	sim:hover(squiggle)
	check(sim.G.GameTooltip:IsShown(), "hovering the squiggle shows no explanation")
	sim:leave()
	check(
		editor.status:GetText():find("Spell not in your spellbook", 1, true) ~= nil,
		"the status does not name the problem"
	)

	setText(sim, window, "/stopcastin", true)
	check(editor.diagnostics[1] and editor.diagnostics[1].fix, "the mistyped command has no fix")
	local fixSquiggle
	for _, frame in ipairs(editor.squiggles) do
		if frame:IsShown() then
			fixSquiggle = frame
			break
		end
	end
	check(fixSquiggle, "the mistyped command has no squiggle")
	sim:hover(fixSquiggle)
	local fixTab = editor.edit:GetScript("OnTabPressed")
	check(fixTab(editor.edit), "Tab did not consume the fix")
	check(textOf(window) == "/stopcasting", "the fix did not replace the command")
	sim:leave()
	setText(sim, window, original, false)
end)

scenario("Save, Cancel, New, Change Name/Icon and Delete", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)

	setText(sim, window, "/cast Wing Clip", true)
	check(window.saveButton:IsEnabled(), "Save is disabled with unsaved edits")
	sim:click(window.saveButton)
	sim:advance(0.1)
	check(select(3, sim.G.GetMacroInfo(121)) == "/cast Wing Clip", "Save did not write the body")
	check(not window.saveButton:IsEnabled(), "Save stayed enabled after saving")

	setText(sim, window, "/cast Ignored", true)
	sim:click(window.cancelButton)
	sim:advance(0.1)
	check(textOf(window) == "/cast Wing Clip", "Cancel did not revert the editor")

	setText(sim, window, "/cast Hide Save", true)
	sim:click(window.CloseButton)
	sim:advance(0.2)
	check(select(3, sim.G.GetMacroInfo(121)) == "/cast Hide Save", "hiding the window did not save the edit")
	window = open(sim)
	characterTab(sim, window)
	check(textOf(window) == "/cast Hide Save", "the saved edit did not come back with the window")

	local before = select(2, sim.G.GetNumMacros())
	sim:click(window.newButton)
	sim:advance(0.2)
	check(window.iconSelector:IsShown(), "New did not open the name and icon frame")
	window.iconSelector.BorderBox.IconSelectorEditBox:SetText("Fresh")
	sim:click(window.iconSelector.BorderBox.OkayButton)
	sim:advance(0.2)
	check(select(2, sim.G.GetNumMacros()) == before + 1, "New did not create a character macro")
	check(window.header.name:GetText() == "Fresh", "New did not select the created macro")
	check(not window.iconSelector:IsShown(), "the name and icon frame stayed open")

	sim:click(window.header.change)
	sim:advance(0.2)
	window.iconSelector.BorderBox.IconSelectorEditBox:SetText("Renamed")
	sim:click(window.iconSelector.BorderBox.OkayButton)
	sim:advance(0.2)
	check(window.header.name:GetText() == "Renamed", "Change Name/Icon did not rename the macro")
	check(select(1, sim.G.GetMacroInfo(121 + before)) == "Renamed", "the rename was not written")

	sim:click(window.deleteButton)
	sim:advance(0.05)
	check(window.deleteButton:GetText() == "Click again to delete", "the first Delete click did not ask for a second")
	sim:click(window.deleteButton)
	sim:advance(0.2)
	check(select(2, sim.G.GetNumMacros()) == before, "the second Delete click did not delete the macro")
	check(not window.iconSelector:IsShown(), "the icon frame is open after deleting")
end)

scenario("closing by our X and the editor's Escape, and reopening", function(sim)
	local window = openNamed(sim)
	sim:click(window.CloseButton)
	sim:advance(0.2)
	check(not window:IsShown(), "our close button did not hide our window")
	check(not sim.G.MacroFrame:IsShown(), "our close button did not close Blizzard's MacroFrame")
	check(sim.G.MacroFrame:GetAlpha() == 1, "MacroFrame stayed at alpha 0 after closing")
	sim:expectNoGamepadTaint(ADDON)

	window = open(sim)
	characterTab(sim, window)
	local editor = window.editor
	setText(sim, window, "/cast Arc")
	sim:input(function()
		editor:RefreshCompletions()
	end)
	local escape = editor.edit:GetScript("OnEscapePressed")
	check(escape(editor.edit), "Escape was not consumed by the popup")
	check(not editor.popup:IsShown(), "Escape did not close the completion popup")
	check(window:IsShown() and sim.G.MacroFrame:IsShown(), "the first Escape closed the window")
	escape(editor.edit)
	sim:advance(0.2)
	check(not window:IsShown(), "the second Escape did not hide our window")
	check(not sim.G.MacroFrame:IsShown(), "the second Escape did not close Blizzard's MacroFrame")

	window = open(sim)
	-- The client's own Escape path: CloseAllWindows closes the panel; our OnHide hook then hides our window.
	sim:input(function()
		sim.G.CloseAllWindows()
	end)
	sim:advance(0.2)
	check(not sim.G.MacroFrame:IsShown(), "Escape's CloseAllWindows path did not close MacroFrame")
	check(not window:IsShown(), "our window stayed open after CloseAllWindows")
end)

scenario("in combat the window stays open and refuses every write", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	local editor = window.editor
	setText(sim, window, "/cast Wing Clip", true)
	sim:enterCombat()
	sim:advance(0.1)
	check(not window.saveButton:IsEnabled(), "Save is enabled in combat")
	check(not window.newButton:IsEnabled(), "New is enabled in combat")
	check(not window.deleteButton:IsEnabled(), "Delete is enabled in combat")
	check(not window.header.change:IsEnabled(), "Change Name/Icon is enabled in combat")
	check(editor.status:GetText():find("Saving is disabled in combat", 1, true) ~= nil, "the status does not say why")
	sim:click(window.saveButton)
	sim:click(window.deleteButton)
	sim:advance(0.1)
	local body = select(3, sim.G.GetMacroInfo(121))
	check(body == "#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot", "combat wrote the body")
	check(select(2, sim.G.GetNumMacros()) == 5, "combat deleted a macro")
	sim:expectNoErrors(ADDON)
	sim:leaveCombat()
	sim:advance(0.1)
	check(window.saveButton:IsEnabled(), "Save did not come back after combat")
	sim:click(window.saveButton)
	sim:advance(0.1)
	check(select(3, sim.G.GetMacroInfo(121)) == "/cast Wing Clip", "the edit was not saved after combat")
end)

scenario("the gamepad interface walks the window on and off", function(sim)
	world.install(sim)
	sim:login()
	sim:setGamepad(true)
	local window = open(sim)
	sim:gamepadNavigate()
	characterTab(sim, window)
	sim:gamepadNavigate()
	sim:click(rowNamed(window, "Mark"))
	sim:advance(0.1)
	check(selectedRow(window).Name:GetText() == "Mark", "a row did not become selected with the gamepad")
	sim:click(window.newButton)
	sim:advance(0.2)
	window.iconSelector:Hide()
	sim:click(window.CloseButton)
	sim:advance(0.2)
	check(not sim.G.MacroFrame:IsShown(), "the gamepad path did not close the panel")
	window = open(sim)
	sim:gamepadNavigate()
	sim:expectNoGamepadTaint(ADDON)
	sim:setGamepad(false)
	sim:click(window.Tabs[1])
	sim:advance(0.1)
	check(selectedRow(window).Name:GetText() == "General One", "the mouse path stopped working after the gamepad")
	sim:click(window.CloseButton)
	sim:advance(0.2)
end)

scenario("an old saved file still opens the window", function(sim)
	world.install(sim)
	sim:login({ savedVariables = "tests/sim/fixtures/old_saved.lua" })
	local window = open(sim)
	check(sim:savedState().MacroAssistForeverDB.showLineNumbers == false, "the old saved setting was lost")
	check(window:IsShown(), "the window did not open from the old save file")
	characterTab(sim, window)
	check(#rows(window) == 5, "the old save file broke the character list")
	sim:click(window.CloseButton)
	sim:advance(0.2)
end)

scenario("/ma, /macroassist and the addon compartment toggle the window in combat and on the gamepad", function(sim)
	world.install(sim)
	sim:login()
	equal(#sim:slashCommands(ADDON), 1, "the addon registers one slash command key")
	equal(sim:slashCommands(ADDON)[1], "/ma", "the command's short form is /ma")
	check(not sim.G[PLAYER], "the macro window was built at login")

	local function isWindowShown()
		local window = sim.G[PLAYER]
		return window and window:IsShown()
	end
	local function isOpen()
		return isWindowShown() and sim.G.MacroFrame ~= nil and sim.G.MacroFrame:IsShown()
	end
	local function isClosed()
		return sim.G.MacroFrame and not sim.G.MacroFrame:IsShown() and not isWindowShown()
	end

	-- A cold /ma builds our window by itself and never loads Blizzard_MacroUI, so nothing that addon defines is
	-- tainted. The X and the editor's own Escape both close it while it stands alone; the game's Escape is not ours
	-- to register.
	sim:slash("/ma")
	check(isWindowShown(), "a cold /ma did not open our window")
	check(sim.G.MacroFrame == nil, "a cold /ma created Blizzard's MacroFrame")
	check(sim.loader.loaded.Blizzard_MacroUI == nil, "a cold /ma loaded Blizzard_MacroUI")
	local standalone = sim.G[PLAYER]
	sim:click(standalone.CloseButton)
	sim:advance(0.2)
	check(not isWindowShown(), "our X did not close the standalone window")
	sim:slash("/ma")
	check(isWindowShown(), "a second cold /ma did not reopen our window")
	local standaloneEscape = standalone.editor.edit:GetScript("OnEscapePressed")
	check(standaloneEscape(standalone.editor.edit), "the editor's Escape was not consumed")
	sim:advance(0.2)
	check(not isWindowShown(), "the editor's Escape did not close the standalone window")
	check(not sim.G.GameMenuFrame or not sim.G.GameMenuFrame:IsShown(), "the editor's Escape opened the game menu")
	check(sim.loader.loaded.Blizzard_MacroUI == nil, "the editor's Escape loaded Blizzard_MacroUI")

	-- /macro (ShowMacroFrame, the function its slash handler calls) loads Blizzard_MacroUI; our window re-anchors
	-- over the panel and stays above it.
	sim:slash("/ma")
	sim:input(function()
		sim.G.ShowMacroFrame()
	end)
	sim:advance(0.2)
	check(isOpen(), "the game's own macro path did not open Blizzard's panel")
	check(sim.loader.loaded.Blizzard_MacroUI ~= nil, "/macro did not load Blizzard_MacroUI")
	check(sim.G.MacroFrame:GetAlpha() == 0, "MacroFrame is not drawn at alpha 0 under our window")
	check(sim.G[PLAYER]:GetFrameLevel() > sim.G.MacroFrame:GetFrameLevel(), "our window is not above MacroFrame")
	sim:input(function()
		sim.G.CloseAllWindows()
	end)
	sim:advance(0.2)
	check(isClosed(), "Escape's CloseAllWindows path did not close the pair")

	-- The gamepad interface cannot take a Blizzard panel from addon code without tainting its frame controls, so
	-- each way in opens and closes our own window instead, and the game's own macro path still opens the panel.
	sim:setGamepad(true)
	sim:slash("/ma")
	check(isWindowShown(), "/ma did not open our window with the gamepad")
	check(not sim.G.MacroFrame:IsShown(), "/ma opened Blizzard's panel with the gamepad")
	sim:gamepadNavigate()
	sim:input(function()
		sim.G.ShowMacroFrame() -- the game's own macro path, as its keybind calls it
	end)
	sim:advance(0.2)
	check(isOpen(), "the game's own macro path did not open Blizzard's panel")
	sim:gamepadNavigate()
	sim:input(function()
		sim.G.CloseAllWindows()
	end)
	sim:advance(0.2)
	check(isClosed(), "the game's own Escape path did not close the macro window")
	sim:slash("/macroassist")
	check(isWindowShown(), "/macroassist did not open our window with the gamepad")
	sim:gamepadNavigate()
	sim:input(function()
		sim.G.MacroAssistForever_OnAddonCompartmentClick("MacroAssistForever")
	end)
	sim:advance(0.2)
	check(isClosed(), "the addon compartment did not close our window with the gamepad")
	sim:setGamepad(false)

	for _, command in ipairs({ "/ma", "/macroassist" }) do
		sim:slash(command)
		check(isOpen(), command .. " did not open the macro window")
		sim:slash(command)
		check(isClosed(), command .. " did not close the macro window")
	end

	sim:input(function()
		sim.G.MacroAssistForever_OnAddonCompartmentClick("MacroAssistForever")
	end)
	sim:advance(0.2)
	check(isOpen(), "the addon compartment did not open the macro window")
	sim:input(function()
		sim.G.MacroAssistForever_OnAddonCompartmentClick("MacroAssistForever")
	end)
	sim:advance(0.2)
	check(isClosed(), "the addon compartment did not close the macro window")

	-- Combat: the panel manager refuses addon calls, so our own window opens and closes by itself as well.
	sim:enterCombat()
	sim:slash("/ma")
	check(isWindowShown(), "/ma did not open our window in combat")
	check(not sim.G.MacroFrame:IsShown(), "/ma opened Blizzard's panel in combat")
	sim:slash("/ma")
	check(isClosed(), "/ma did not close our window in combat")
	sim:slash("/macroassist")
	check(isWindowShown(), "/macroassist did not open our window in combat")
	local combatEscape = sim.G[PLAYER].editor.edit:GetScript("OnEscapePressed")
	check(combatEscape(sim.G[PLAYER].editor.edit), "the editor's Escape was not consumed in combat")
	sim:advance(0.2)
	check(isClosed(), "the editor's Escape did not close our window in combat")
	sim:slash("/macroassist")
	check(isWindowShown(), "/macroassist did not reopen our window in combat")
	sim:input(function()
		sim.G.MacroAssistForever_OnAddonCompartmentClick("MacroAssistForever")
	end)
	sim:advance(0.2)
	check(isClosed(), "the addon compartment did not close our window in combat")
	sim:leaveCombat()

	-- A pair opened before combat stays together: the panel manager refuses the hide until combat ends.
	sim:slash("/ma")
	check(isOpen(), "/ma did not open the macro window after combat")
	sim:enterCombat()
	sim:slash("/ma")
	check(isOpen(), "/ma closed the pair in combat")
	sim:leaveCombat()
	sim:slash("/ma")
	check(isClosed(), "/ma did not close the macro window after combat")

	sim:slash("/ma")
	sim:gamepadNavigate()
	sim:slash("/ma")
	check(isClosed(), "the mouse path stopped working after the gamepad")
	sim:expectNoErrors(ADDON)
	sim:expectNoGamepadTaint(ADDON)
end)
