-- The macro window (WFA-35): the player's way in through /macro (ShowMacroFrame, which the slash handler calls),
-- /macroassist and the addon compartment, a cold /macroassist that never loads Blizzard_MacroUI, the list and both
-- tabs, editing and saving, completion and a fix, New, Rename and Delete, closing by our X and the editor's
-- Escape, reopening, combat with the window open, the gamepad interface on and off, and an old saved file.
-- luacheck: read globals scenario ADDON

local world = assert(loadfile("tests/sim/macro_world.lua"))()
local ForeverCore = dofile("tests/forever_core.lua")

-- ForeverCore is a hard dependency, so every scenario runs with it registered and loaded first, as the client does
-- for a TOC's ## Dependencies. The scenario runner fires each addon's ADDON_LOADED in that order.
local declare = scenario
local function scenario(name, work)
	declare(name, { addons = ForeverCore.addons() }, work)
end

local PLAYER = "MacroAssistForeverFrame"

local function check(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function equal(actual, expected, label)
	check(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

-- This is the function Blizzard's /macro and /m handlers call (Blizzard_ChatFrameBase/Shared/SlashCommands.lua), and
-- the game menu's Macros button and the chat menu too. The simulator does not register the client's chat command
-- table and boots no game menu, so calling ShowMacroFrame is the same path from our side.
local function pressMacroCommand(sim)
	sim:input(function()
		sim.G.ShowMacroFrame()
	end)
	sim:advance(0.3)
end

local function panelOpen(sim)
	local window = sim.G[PLAYER]
	return sim.G.MacroFrame ~= nil and sim.G.MacroFrame:IsShown() and window ~= nil and window:IsShown()
end

local function panelClosed(sim)
	local window = sim.G[PLAYER]
	return sim.G.MacroFrame ~= nil and not sim.G.MacroFrame:IsShown() and (window == nil or not window:IsShown())
end

local function open(sim)
	pressMacroCommand(sim)
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

local function historyRows(window)
	local out = {}
	window.history.scrollBox:ForEachFrame(function(row)
		if row:IsShown() then
			out[#out + 1] = row
		end
	end)
	return out
end

local function historyEntry(window, summary)
	for _, row in ipairs(historyRows(window)) do
		if row.Time:IsShown() and row.Summary:GetText():find(summary, 1, true) then
			return row
		end
	end
end

local function textOf(window)
	return window.editor.edit:GetText()
end

-- The client reports the EditBox's caret rect after a cursor or text change; the simulator stores the cursor but
-- does not measure one, so the scenario reports the rect from the editor's own measured rows.
local function reportCursor(editor, position)
	editor.edit:SetCursorPosition(position)
	local index = editor.RowAtCursor(editor.rows, position)
	local row = index and editor.rows[index]
	if not row then
		return
	end
	local move = editor.edit:GetScript("OnCursorChanged")
	move(editor.edit, editor.RowOffset(row, position, editor.textMeasure), -row.y, 1, editor.lineHeight)
end

local function setText(sim, window, text, edited)
	sim:input(function()
		local editor = window.editor
		editor.edit:SetText(text)
		editor:RefreshAll()
		reportCursor(editor, #text)
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

local function paste(sim, panel, text)
	sim:input(function()
		panel.edit:SetText(text)
	end)
	sim:advance(0.05)
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
	check(selectedRow(window).SelectedBar:IsShown(), "the selected row has no gold bar")
	equal(window.header.meta:GetText(), "General macro, not on a bar", "the header names the tab and the bar")
	equal(window.count:GetText(), "2/120", "the count sits beside the search box")
	equal(window.editor.now:GetText():find("Arcane Shot", 1, true) ~= nil, true, "the status says what fires now")

	characterTab(sim, window)
	check(window.Tabs[2].SelectedTexture:IsShown(), "the character tab is not checked")
	check(not window.Tabs[1].SelectedTexture:IsShown(), "the General tab stayed checked")
	local arcane = rowNamed(window, "Arcane")
	check(arcane, "the character tab does not list Arcane")
	check(arcane.IconFrame:IsShown(), "the selected row icon has no frame")
	check(rowNamed(window, "Pet").IconFrame:IsShown(), "a normal row icon has no frame")
	equal(#rows(window), 5, "the character tab lists only character macros")
	equal(selectedRow(window).Name:GetText(), "Arcane", "the first character macro is selected")
	equal(window.header.name:GetText(), "Arcane", "the header shows the selected name")
	equal(window.header.meta:GetText(), "Character macro, not on a bar", "the header names the tab and the bar")
	equal(window.count:GetText(), "5/30", "the count follows the character tab")
	equal(textOf(window), "#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot", "the editor holds the body")
	check(window.explainPanel:IsShown(), "the What it does panel is hidden")
	equal(window.explainPanel.rows[1].key:GetText(), "Click", "the panel does not start with the click case")
	equal(
		window.explainPanel.rows[1].text:GetText(),
		"Arcane Shot your mouseover enemy, otherwise your target",
		"the panel does not read the click branch"
	)
	equal(
		window.editor.now:GetText():find("on Defias Pillager", 1, true),
		nil,
		"the live line names no unit when the matching clause has none"
	)
	equal(window.editor.now:GetText():find("Arcane Shot", 1, true) ~= nil, true, "the live line still says what fires")
	equal(
		arcane.Summary:GetText(),
		"Arcane Shot · Not on a bar",
		"the row shows the main action and that it is on no bar"
	)
	check(window.Tabs[1]:GetLeft() >= window:GetRight() - 2, "the side tabs do not hang off the window's right edge")

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

scenario("the header and rows show action bar slots and their keys", function(sim)
	world.install(sim)
	local account = sim.G.Constants.MacroConsts.MAX_ACCOUNT_MACROS
	local arcane = account + 1
	local trap = account + 4
	-- The client reports each macro's first spell as the slot's ID with subType "spell", so the slot's macro comes
	-- from the name the button shows, not from that ID.
	sim.actionSlots[61] = arcane
	sim.actionSlots[62] = arcane
	sim.actionSlots[1] = 1
	local keys = { MULTIACTIONBAR1BUTTON1 = "SHIFT-1", ACTIONBUTTON1 = "BUTTON4" }
	sim.G.GetBindingKey = function(binding)
		return keys[binding]
	end
	sim.G.GetBindingText = function(key)
		if key == "BUTTON4" then
			return "Button 4"
		end
		if key == "SHIFT-1" then
			return "Shift-1"
		end
		return key
	end
	sim:login()
	local window = open(sim)
	equal(
		window.header.meta:GetText(),
		"General macro, slot 1 (Button 4)",
		"the header names the general macro's slot and key"
	)
	check(
		rowNamed(window, "General One").Summary:GetText():find("Not on a bar", 1, true) == nil,
		"a macro on a bar is not marked as on none"
	)

	characterTab(sim, window)
	equal(
		window.header.meta:GetText(),
		"Character macro, slot 61 (Shift-1), slot 62",
		"the header names every slot and the key that presses it"
	)
	check(
		rowNamed(window, "Trap").Summary:GetText():find("Not on a bar", 1, true) ~= nil,
		"a macro on no bar is marked in the list"
	)

	-- The bottom-left bar loses its first button, its second is rebound and a macro moves onto another bar.
	sim.actionSlots[61] = nil
	keys.MULTIACTIONBAR1BUTTON2 = "CTRL-2"
	sim.actionSlots[37] = trap
	sim:input(function()
		sim.events.fire("ACTIONBAR_SLOT_CHANGED", 61)
	end)
	equal(
		window.header.meta:GetText(),
		"Character macro, slot 62 (CTRL-2)",
		"an action bar change rebuilds the slots while the window shows"
	)
	check(
		rowNamed(window, "Arcane").Summary:GetText():find("Not on a bar", 1, true) == nil,
		"the row keeps a macro that is still on a bar unmarked"
	)
	check(
		rowNamed(window, "Trap").Summary:GetText():find("Not on a bar", 1, true) == nil,
		"the row clears the mark when the macro moves onto a bar"
	)
	check(
		rowNamed(window, "Pet").Summary:GetText():find("Not on a bar", 1, true) ~= nil,
		"a macro on no bar stays marked"
	)
end)

scenario("the search box filters the list by name and summary", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	equal(window.searchBox.Instructions:GetText(), "Search macros", "the search box has no instructions")
	local width, height = window:GetWidth(), window:GetHeight()

	sim:input(function()
		window.searchBox:SetText("fd")
	end)
	sim:advance(0.05)
	equal(#rows(window), 1, "a name search did not narrow the list")
	equal(rows(window)[1].Name:GetText(), "FD", "the name search kept the wrong macro")

	sim:input(function()
		window.searchBox:SetText("FREEZING")
	end)
	sim:advance(0.05)
	equal(#rows(window), 1, "a summary search was not case-insensitive")
	equal(rows(window)[1].Name:GetText(), "Trap", "the summary search missed a macro")

	sim:input(function()
		window.searchBox:SetText("no such macro")
	end)
	sim:advance(0.05)
	equal(#rows(window), 0, "a search with no match still listed rows")

	sim:input(function()
		window.searchBox:SetText("")
	end)
	sim:advance(0.05)
	equal(#rows(window), 5, "clearing the search did not restore the list")

	sim:click(window.Tabs[1])
	sim:advance(0.1)
	equal(window:GetWidth(), width, "switching tabs changed the window width")
	equal(window:GetHeight(), height, "switching tabs changed the window height")
	sim:click(window.CloseButton)
	sim:advance(0.2)
end)

scenario("the caret is one measured line, follows the cursor and shows only while focused", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	local editor = window.editor
	equal(editor.lineHeight, 19, "the editor's measured line is not the 14-unit font plus its 5-unit spacing")
	setText(sim, window, "#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot", false)
	sim:input(function()
		editor:Focus()
	end)
	sim:advance(0.1)
	check(editor.caret:IsShown(), "the editor shows no caret while it has focus")
	equal(editor.caret:GetWidth(), 1, "the caret is not one unit wide")
	equal(editor.caret:GetHeight(), editor.lineHeight, "the caret is not one line tall")
	sim:input(function()
		reportCursor(editor, 3)
	end)
	sim:advance(0.05)
	check(editor.caret:IsShown(), "moving the cursor hid the caret")
	local before = editor.caret:GetLeft()
	sim:input(function()
		reportCursor(editor, #editor:GetText())
	end)
	sim:advance(0.05)
	check(editor.caret:GetLeft() > before, "the caret did not follow the cursor")
	sim:input(function()
		editor:ClearFocus()
	end)
	check(not editor.caret:IsShown(), "the caret stayed after the editor lost focus")
	sim:click(window.CloseButton)
	sim:advance(0.2)
end)

scenario("a 255-character macro fits the code surface without scrolling", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	local body = string.rep("/cast Freezing Trap\n", 12) .. "/cast Wing Clip"
	equal(#body, 255, "the fixture is a 255-character macro")
	setText(sim, window, body, true)
	check(
		window.editor.contentHeight <= window.editorSurface:GetHeight(),
		"the code surface is shorter than the macro's measured rows"
	)
	equal(#rows(window), 5, "the long macro changed the list")
end)

scenario("a click right of a line's end keeps the cursor on that line", function(sim)
	local window = openNamed(sim)
	local editor = window.editor
	setText(sim, window, "/cast A\n/cast B\n/cast C", false)
	sim:input(function()
		-- The EditBox's own click handling put the cursor at the start of line 3; the pointer is on line 2, to
		-- the right of its last character. Releasing must put the cursor at the end of line 2, before its newline.
		local top = editor.edit:GetTop()
		local left = editor.edit:GetLeft()
		local scale = editor.edit:GetEffectiveScale()
		local row = editor.rows[2]
		sim.mouseX = (left + 500) * scale
		sim.mouseY = (top - row.y - editor.lineHeight / 2) * scale
		local down = editor.edit:GetScript("OnMouseDown")
		down(editor.edit, "LeftButton")
		local up = editor.edit:GetScript("OnMouseUp")
		up(editor.edit, "LeftButton")
	end)
	local cursor
	sim:input(function()
		cursor = editor.edit:GetCursorPosition()
	end)
	equal(cursor, 15, "the click moved the cursor past line 2's newline")
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
	check(not squiggle:IsMouseEnabled(), "the squiggle still takes the mouse from the text")
	check(sim.G.GameTooltip:IsShown(), "moving the cursor into the problem shows no explanation")
	check(
		editor.problem:GetText():find("Spell not in your spellbook", 1, true) ~= nil,
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
	local fixTab = editor.edit:GetScript("OnTabPressed")
	check(fixTab(editor.edit), "Tab did not consume the fix")
	check(textOf(window) == "/stopcasting", "the fix did not replace the command")

	-- A spell inside a spellbook flyout is a spell the player knows; a slot the flyout marks unknown is not.
	setText(sim, window, "/cast Call Pet", true)
	equal(#editor.diagnostics, 0, "a spell inside a flyout was reported as not in the spellbook")

	setText(sim, window, "/cast Call", true)
	sim:input(function()
		editor:RefreshCompletions()
	end)
	local offered = false
	for _, item in ipairs(editor.completion.items) do
		if item.label == "Call Pet" then
			offered = true
			break
		end
	end
	check(offered, "completion did not offer a spell from a flyout")

	setText(sim, window, "/cast Feed Pet", true)
	check(
		#editor.diagnostics == 1 and editor.diagnostics[1].code == "unknown-spell",
		"a slot the flyout marks unknown was treated as known"
	)
	setText(sim, window, original, false)
end)

scenario("plain words offer checked recipes and Tab inserts one", function(sim)
	world.install(sim)
	sim.world.player.classFile = "HUNTER"
	sim.world.player.className = "Hunter"
	sim:login()
	local window = open(sim)
	characterTab(sim, window)
	local editor = window.editor

	setText(sim, window, "heal pet")
	sim:input(function()
		editor:RefreshCompletions()
	end)
	check(editor.popup:IsShown(), "plain words did not open the completion list")
	local recipe
	for _, item in ipairs(editor.completion.items) do
		if item.label == "Heal the pet" then
			recipe = item
			break
		end
	end
	check(recipe, "the Heal the pet recipe was not offered")
	equal(recipe.kind, "recipe", "a recipe has its own kind")
	equal(recipe.detail, "Recipe", "a recipe reads as a recipe")
	check(recipe.insert:find("Mend Pet", 1, true) ~= nil, "the recipe did not resolve its spell name")
	check(recipe.insert:find("%s", 1, true) == nil, "the recipe left its spell placeholder")

	local tab = editor.edit:GetScript("OnTabPressed")
	check(tab(editor.edit), "Tab did not insert the recipe")
	equal(textOf(window), recipe.insert, "the recipe did not replace the whole line")
	check(not editor.popup:IsShown(), "the popup stayed open after inserting a recipe")

	-- Another class's recipe is never offered, and a recipe whose spell this client does not know is skipped.
	setText(sim, window, "polymorph")
	sim:input(function()
		editor:RefreshCompletions()
	end)
	for _, item in ipairs(editor.completion.items) do
		check(item.kind ~= "recipe", "a Mage recipe was offered to a Hunter")
	end

	sim.world.player.classFile = "DEATHKNIGHT"
	sim.world.player.className = "Death Knight"
	sim:input(function()
		sim.events.fire("SPELLS_CHANGED")
	end)
	setText(sim, window, "death grip")
	sim:input(function()
		editor:RefreshCompletions()
	end)
	for _, item in ipairs(editor.completion.items) do
		check(item.kind ~= "recipe", "a recipe with an unknown spell was still offered")
	end
end)

scenario("a macro over the limit offers a shorter rewrite, previews it and applies it", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	local line = "/spell    [harm, nodead]   Arcane Shot; [harm] Arcane Shot"
	local long = table.concat({ line, line, line, line, line }, "\n")
	local expected = table.concat({
		"/cast [harm,nodead] Arcane Shot;[harm] Arcane Shot",
		"/cast [harm,nodead] Arcane Shot;[harm] Arcane Shot",
		"/cast [harm,nodead] Arcane Shot;[harm] Arcane Shot",
		"/cast [harm,nodead] Arcane Shot;[harm] Arcane Shot",
		"/cast [harm,nodead] Arcane Shot;[harm] Arcane Shot",
	}, "\n")
	check(#long > 255, "the sample macro is not over the limit")

	setText(sim, window, long, true)
	check(window.editor.shorten:IsShown(), "an over-limit macro does not offer Shorten")
	check(window.editor.shortenText == expected, "Shorten did not keep the lossless rewrite")

	sim:click(window.editor.shorten)
	sim:advance(0.1)
	local panel = window.shortenPanel
	check(panel:IsShown(), "Shorten did not open the preview")
	check(panel.diff:GetText():find("-" .. line, 1, true) ~= nil, "the preview does not show the old line")
	check(
		panel.diff:GetText():find("+/cast [harm,nodead] Arcane Shot;[harm] Arcane Shot", 1, true) ~= nil,
		"the preview does not show the new line"
	)
	check(panel.status:GetText():find("now 254/255", 1, true) ~= nil, "the preview does not count the new length")

	sim:click(panel.cancelButton)
	sim:advance(0.1)
	check(not panel:IsShown(), "Cancel left the preview open")
	equal(textOf(window), long, "Cancel changed the editor")

	sim:click(window.editor.shorten)
	sim:advance(0.1)
	sim:click(panel.applyButton)
	sim:advance(0.1)
	check(not panel:IsShown(), "Apply left the preview open")
	equal(textOf(window), expected, "Apply did not put the rewrite in the editor")
	check(not window.editor.shorten:IsShown(), "Shorten is still offered after the rewrite")
	check(window.saveButton:IsEnabled(), "the rewrite did not mark the macro dirty")

	sim:click(window.saveButton)
	sim:advance(0.1)
	equal(select(3, sim.G.GetMacroInfo(121)), expected, "Save did not keep the shortened macro")
end)

scenario("a body over the limit is refused and kept as a draft", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	local original = "#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot"
	local long = string.rep("/cast Arcane Shot\n", 16)
	check(#long > 255, "the sample body is not over the limit")

	setText(sim, window, long, true)
	check(window.saveButton:IsEnabled(), "Save is disabled with an over-limit edit")
	sim:click(window.saveButton)
	sim:advance(0.1)
	equal(select(3, sim.G.GetMacroInfo(121)), original, "Save wrote a body over the limit")
	check(
		window.editor.problem:GetText():find("Nothing was saved", 1, true) ~= nil,
		"the refused write is not in the status line"
	)
	check(window.saveButton:IsEnabled(), "Save stayed disabled after it refused the write")

	-- Switching tabs saves too, so the same refusal applies and the edit stays a draft on this macro.
	sim:click(window.Tabs[1])
	sim:advance(0.1)
	equal(select(3, sim.G.GetMacroInfo(121)), original, "switching tabs wrote a body over the limit")
	sim:click(window.Tabs[2])
	sim:advance(0.1)
	equal(textOf(window), long, "the refused edit did not come back as a draft")
	check(window.saveButton:IsEnabled(), "the draft is not marked dirty")
end)

scenario("Save, Cancel, New, Rename and Delete", function(sim)
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
	check(window.picker:IsShown(), "New did not open the icon picker")
	check(window.header.rename:GetText() == "Back to code", "Rename does not read Back to code while picking")
	window.header.nameEdit:SetText("Fresh")
	sim:click(window.saveButton)
	sim:advance(0.2)
	check(select(2, sim.G.GetNumMacros()) == before + 1, "New did not create a character macro")
	check(window.header.name:GetText() == "Fresh", "New did not select the created macro")
	check(select(1, sim.G.GetMacroInfo(121 + before)) == "Fresh", "New did not name the macro")

	sim:click(window.header.rename)
	sim:advance(0.2)
	check(not window.picker:IsShown(), "Back to code did not close the picker")

	sim:click(window.header.rename)
	sim:advance(0.2)
	check(window.picker:IsShown(), "Rename did not open the picker")
	window.header.nameEdit:SetText("Renamed")
	sim:click(window.saveButton)
	sim:advance(0.2)
	check(window.header.name:GetText() == "Renamed", "Rename did not rename the macro")
	check(select(1, sim.G.GetMacroInfo(121 + before)) == "Renamed", "the rename was not written")

	sim:click(window.deleteButton)
	sim:advance(0.05)
	check(window.deleteButton:GetText() == "Click again to delete", "the first Delete click did not ask for a second")
	sim:click(window.deleteButton)
	sim:advance(0.2)
	check(select(2, sim.G.GetNumMacros()) == before, "the second Delete click did not delete the macro")
	check(not window.picker:IsShown(), "the picker is open after deleting")
end)

scenario("Import checks pasted text, creates the macro and opens the picker", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	local panel = window.importPanel
	check(panel, "the window did not build the Import box")
	check(not panel:IsShown(), "the Import box is shown before it is asked for")

	sim:click(window.importButton)
	sim:advance(0.1)
	check(panel:IsShown(), "Import did not open the box")
	equal(panel.status:GetText(), "Paste a macro to import.", "an empty box says what to do")
	check(not panel.importButton:IsEnabled(), "Import is enabled with nothing pasted")

	paste(sim, panel, "I like pets and healing")
	equal(panel.status:GetText(), "Not a macro: no line starts with / or #.", "prose is refused")
	check(not panel.importButton:IsEnabled(), "Import is enabled for prose")

	paste(sim, panel, "!MySlot:AAAABBBBCCCC")
	equal(panel.status:GetText(), "This is a MySlot export, not a macro.", "a MySlot export is named")
	check(not panel.importButton:IsEnabled(), "Import is enabled for a MySlot export")

	paste(sim, panel, string.rep("/cast Arcane Shot\n", 20))
	check(
		panel.status:GetText():find("the limit is 255", 1, true) ~= nil,
		"text over the limit does not show its problem before saving"
	)
	check(not panel.importButton:IsEnabled(), "Import is enabled over the limit")

	-- The counter measures the body the macro store will take, so Windows line endings cost nothing: 14 lines are
	-- 266 bytes on the clipboard but a 252-character macro.
	paste(sim, panel, string.rep("/cast Arcane Shot\r\n", 14))
	equal(panel.length:GetText(), "252/255", "the counter measures the normalized body")
	equal(panel.status:GetText(), "Ready to import.", "a body that fits after normalization is ready")
	check(panel.importButton:IsEnabled(), "Import is disabled for a body that fits after normalization")

	paste(sim, panel, "/cast Arcane Shot\n/startattack")
	equal(panel.status:GetText(), "Ready to import.", "a checked macro is ready")
	check(panel.importButton:IsEnabled(), "Import is disabled for a checked macro")
	equal(panel.length:GetText(), "30/255", "the box counts the pasted characters")

	local before = select(2, sim.G.GetNumMacros())
	sim:click(panel.importButton)
	sim:advance(0.2)
	check(not panel:IsShown(), "Import left the box open")
	check(window.picker:IsShown(), "Import did not open the picker for the name and icon")
	check(select(2, sim.G.GetNumMacros()) == before + 1, "Import did not create a character macro")
	local actual = 121 + before
	equal(
		select(3, sim.G.GetMacroInfo(actual)),
		"/cast Arcane Shot\n/startattack",
		"Import did not keep the pasted body"
	)
	equal(window.header.nameEdit:GetText(), "New macro", "the picker did not start on a free name")

	window.header.nameEdit:SetText("Imported")
	sim:click(window.saveButton)
	sim:advance(0.2)
	equal(window.header.name:GetText(), "Imported", "the imported macro did not take the chosen name")
	equal(select(1, sim.G.GetMacroInfo(actual)), "Imported", "the chosen name was not written")

	-- Cancel closes the box without writing anything.
	sim:click(window.importButton)
	sim:advance(0.1)
	paste(sim, panel, "/cast Wing Clip")
	sim:click(panel.cancelButton)
	sim:advance(0.1)
	check(not panel:IsShown(), "Cancel left the Import box open")
	equal(select(2, sim.G.GetNumMacros()), before + 1, "Cancel imported a macro")
end)

scenario("the icon picker previews, searches and keeps a pick through Save", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	sim:click(window.header.iconButton)
	sim:advance(0.2)
	check(window.picker:IsShown(), "clicking the header icon did not open the picker")
	check(not window.editorSurface:IsShown(), "the code surface stayed shown behind the picker")
	equal(window.header.rename:GetText(), "Back to code", "Rename does not become Back to code")

	-- From this macro starts with Automatic, then the icons of what the macro casts, in order.
	equal(window.picker.rows[1].title, "From this macro", "the first section is not From this macro")
	equal(window.picker.rows[2].icons[1].icon, 134400, "Automatic is not the first icon")
	equal(window.picker.rows[2].icons[2].icon, 132204, "the first cast's icon is not second")

	-- Automatic names the action the client would run now, not a guess from the macro's first cast.
	window.picker:Pick(134400)
	sim:advance(0.1)
	check(
		window.picker.statusText:GetText():find("Arcane Shot", 1, true),
		"Automatic does not name the live #showtooltip action"
	)

	window.picker:Pick(132179)
	sim:advance(0.1)
	equal(window.header.icon:GetTexture(), 132179, "picking did not preview in the header")
	equal(selectedRow(window).Icon:GetTexture(), 132179, "picking did not preview in the list row")
	check(window.saveButton:IsEnabled(), "a picked icon does not enable Save")

	-- Escape leaves the picker and keeps the pick; Save writes it through the macro store.
	local escape = window.picker.searchBox:GetScript("OnEscapePressed")
	escape(window.picker.searchBox)
	sim:advance(0.1)
	check(not window.picker:IsShown(), "Escape did not leave the picker")
	check(window.editorSurface:IsShown(), "Escape did not bring the code surface back")
	equal(window.header.icon:GetTexture(), 132179, "Escape dropped the pending icon")
	sim:click(window.saveButton)
	sim:advance(0.1)
	equal(select(2, sim.G.GetMacroInfo(121)), 132179, "Save did not write the icon")

	-- Cancel restores the icon that was saved.
	sim:click(window.header.iconButton)
	sim:advance(0.2)
	window.picker:Pick(132212)
	sim:advance(0.1)
	sim:click(window.cancelButton)
	sim:advance(0.1)
	equal(window.header.icon:GetTexture(), 132179, "Cancel did not restore the saved icon")
	equal(select(2, sim.G.GetMacroInfo(121)), 132179, "Cancel wrote the pending icon")

	-- Search puts the player's own spells first, then every icon whose file name matches.
	sim:click(window.header.iconButton)
	sim:advance(0.2)
	window.picker.searchBox:SetText("pet")
	sim:advance(0.1)
	equal(window.picker.rows[1].title, "Your spells", "search does not start with Your spells")
	equal(window.picker.rows[2].icons[1].label, "Mend Pet", "Mend Pet is not the first search result")
	check(window.picker.rows[3].title == "All icons", "search does not follow with All icons")
	check(#window.picker.rows[3].note > 0, "the icon matches have no count")
	local matchRow
	for index = 3, #window.picker.rows do
		if window.picker.rows[index].icons then
			matchRow = window.picker.rows[index]
			break
		end
	end
	check(matchRow, "the file-name matches have no icon row")
	equal(matchRow.icons[1].name, "ability_hunter_pet_wolf", "the file-name match is listed")
	sim:click(window.header.rename)
	sim:advance(0.1)
	sim:click(window.cancelButton)
	sim:advance(0.1)
end)

scenario("history keeps a snapshot before a save and restores it", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	local original = "#showtooltip\n/cast [@mouseover,harm,nodead][] Arcane Shot"
	equal(textOf(window), original, "the Arcane macro starts as the fixture")

	sim:click(window.historyButton)
	sim:advance(0.1)
	check(window.history:IsShown(), "History did not open")
	equal(#historyRows(window), 0, "History lists a snapshot before any write")
	check(window.history.empty:IsShown(), "the empty History list has no message")
	sim:click(window.history.CloseButton)
	sim:advance(0.1)
	check(not window.history:IsShown(), "the History close button did not close it")

	setText(sim, window, "/cast Wing Clip", true)
	sim:click(window.saveButton)
	sim:advance(0.1)
	check(select(3, sim.G.GetMacroInfo(121)) == "/cast Wing Clip", "the save did not write the new body")

	sim:click(window.historyButton)
	sim:advance(0.1)
	local entry = historyEntry(window, "Line 1 changed")
	check(entry, "History does not describe the body the save replaced")
	equal(entry.Summary:GetText(), "Line 1 changed, -1 line", "History does not name the changed and removed line")
	check(entry.Time:GetText() ~= "", "the history entry shows no time")
	sim:click(entry)
	sim:advance(0.1)
	check(window.history.restoreButton:IsEnabled(), "Restore is not enabled for a selected snapshot")
	sim:click(window.history.restoreButton)
	sim:advance(0.1)
	equal(select(3, sim.G.GetMacroInfo(121)), original, "Restore did not write the snapshot body")
	equal(textOf(window), original, "the editor did not follow the restored body")
	sim:click(window.history.CloseButton)
	sim:advance(0.1)
end)

scenario("every identity surface shows the TOC's X-Forever-Icon", function(sim)
	world.install(sim)
	sim:login()
	local window = open(sim)
	local icon = sim.G.C_AddOns.GetAddOnMetadata(ADDON, "X-Forever-Icon")
	check(icon and icon ~= "", "the TOC declares no X-Forever-Icon")
	equal(window.PortraitContainer.portrait:GetTexture(), icon, "the macro window portrait is not the addon icon")

	sim:click(window.historyButton)
	sim:advance(0.1)
	equal(window.history.PortraitContainer.portrait:GetTexture(), icon, "the History portrait is not the addon icon")
	sim:click(window.history.CloseButton)
	sim:advance(0.1)
	sim:click(window.CloseButton)
	sim:advance(0.2)
end)

scenario("history rows say what changed against the newer text", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)

	-- One line changes and the line count stays the same.
	setText(sim, window, "#showtooltip\n/cast Wing Clip", true)
	sim:click(window.saveButton)
	sim:advance(0.1)
	sim:click(window.historyButton)
	sim:advance(0.1)
	local changed = historyEntry(window, "Line 2 changed")
	check(changed, "History does not name the line the save changed")
	equal(changed.Summary:GetText(), "Line 2 changed", "History uses another line description")
	sim:click(window.history.CloseButton)
	sim:advance(0.1)

	-- A line is added.
	setText(sim, window, "#showtooltip\n/cast Wing Clip\n/stopattack", true)
	sim:click(window.saveButton)
	sim:advance(0.1)
	sim:click(window.historyButton)
	sim:advance(0.1)
	local added = historyEntry(window, "+1 line")
	check(added, "History does not say the save added a line")
	equal(added.Summary:GetText(), "+1 line", "History uses another added-line description")
	sim:click(window.history.CloseButton)
	sim:advance(0.1)

	-- The rename is described against the live name.
	sim:click(window.header.rename)
	sim:advance(0.2)
	window.header.nameEdit:SetText("Arcane Shot")
	sim:click(window.saveButton)
	sim:advance(0.2)
	sim:click(window.historyButton)
	sim:advance(0.1)
	local renamed = historyEntry(window, "Renamed to Arcane Shot")
	check(renamed, "History does not say the macro was renamed")
	check(
		renamed.Summary:GetText():sub(1, #"Renamed to Arcane Shot") == "Renamed to Arcane Shot",
		"History uses another rename description"
	)
	sim:click(window.history.CloseButton)
	sim:advance(0.1)
end)

scenario("a deleted macro stays restorable from History", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	sim:click(rowNamed(window, "Trap"))
	sim:advance(0.1)
	equal(selectedRow(window).Name:GetText(), "Trap", "Trap is not selected")
	local before = select(2, sim.G.GetNumMacros())
	sim:click(window.deleteButton)
	sim:advance(0.05)
	sim:click(window.deleteButton)
	sim:advance(0.2)
	equal(select(2, sim.G.GetNumMacros()), before - 1, "Delete did not remove Trap")

	-- Open History from the other tab, so the restore has to bring its own tab and selection back with it.
	sim:click(window.Tabs[1])
	sim:advance(0.1)
	sim:click(window.historyButton)
	sim:advance(0.1)
	local deleted
	for _, row in ipairs(historyRows(window)) do
		if not row.Time:IsShown() and row.Summary:GetText() == "Deleted" then
			deleted = row
		end
	end
	check(deleted, "History has no Deleted section")
	local entry = historyEntry(window, "Trap: Freezing Trap")
	check(entry, "the deleted macro is not listed with its last body")
	sim:click(entry)
	sim:advance(0.1)
	sim:click(window.history.restoreButton)
	sim:advance(0.1)
	equal(select(2, sim.G.GetNumMacros()), before, "Restore did not recreate the deleted macro")
	check(select(1, sim.G.GetMacroInfo(121 + before - 1)) == "Trap", "Restore created the wrong macro")
	check(window.Tabs[2].SelectedTexture:IsShown(), "Restore did not switch to the deleted macro's tab")
	equal(window.header.meta:GetText(), "Character macro, not on a bar", "the header still names the other tab")
	equal(selectedRow(window).Name:GetText(), "Trap", "Restore did not select the macro it brought back")
	sim:click(window.history.CloseButton)
	sim:advance(0.1)
	check(rowNamed(window, "Trap"), "the restored macro is not in the list")
end)

scenario("history restore is off in combat", function(sim)
	local window = openNamed(sim)
	characterTab(sim, window)
	setText(sim, window, "/cast Wing Clip", true)
	sim:click(window.saveButton)
	sim:advance(0.1)
	sim:click(window.historyButton)
	sim:advance(0.1)
	local entry = historyEntry(window, "Line 1 changed")
	check(entry, "History has no snapshot to restore")
	sim:click(entry)
	sim:advance(0.1)
	check(window.history.restoreButton:IsEnabled(), "Restore is not enabled out of combat")

	sim:enterCombat()
	sim:advance(0.1)
	check(not window.history.restoreButton:IsEnabled(), "Restore is enabled in combat")
	check(window.history.combatText:IsShown(), "the History window does not say why Restore is off")
	check(
		window.history.combatText:GetText() == "Saving is disabled in combat.",
		"the History window uses another combat message"
	)
	sim:click(window.history.restoreButton)
	sim:advance(0.1)
	equal(select(3, sim.G.GetMacroInfo(121)), "/cast Wing Clip", "Restore wrote the macro in combat")

	sim:leaveCombat()
	sim:advance(0.1)
	check(window.history.restoreButton:IsEnabled(), "Restore did not come back after combat")
	sim:click(window.history.CloseButton)
	sim:advance(0.1)
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
	check(not window.importButton:IsEnabled(), "Import is enabled in combat")
	check(not window.deleteButton:IsEnabled(), "Delete is enabled in combat")
	check(not window.header.rename:IsEnabled(), "Rename is enabled in combat")
	check(editor.problem:GetText():find("Saving is disabled in combat", 1, true) ~= nil, "the status does not say why")
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
	sim:click(window.header.rename)
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

scenario("/macroassist and the addon compartment toggle the window in combat and on the gamepad", function(sim)
	world.install(sim)
	sim:login()
	equal(#sim:slashCommands(ADDON), 1, "the addon registers one slash command key")
	equal(sim:slashCommands(ADDON)[1], "/macroassist", "the command is /macroassist")
	check(sim.G.SLASH_MACROASSISTFOREVER2 == nil, "the client's /ma is not registered by the addon")
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

	-- A cold /macroassist builds our window by itself and never loads Blizzard_MacroUI, so nothing that addon defines
	-- is tainted. The X and the editor's own Escape both close it while it stands alone; the game's Escape is not ours
	-- to register.
	sim:slash("/macroassist")
	check(isWindowShown(), "a cold /macroassist did not open our window")
	check(sim.G.MacroFrame == nil, "a cold /macroassist created Blizzard's MacroFrame")
	check(sim.loader.loaded.Blizzard_MacroUI == nil, "a cold /macroassist loaded Blizzard_MacroUI")
	local standalone = sim.G[PLAYER]
	sim:click(standalone.CloseButton)
	sim:advance(0.2)
	check(not isWindowShown(), "our X did not close the standalone window")
	sim:slash("/macroassist")
	check(isWindowShown(), "a second cold /macroassist did not reopen our window")
	local standaloneEscape = standalone.editor.edit:GetScript("OnEscapePressed")
	check(standaloneEscape(standalone.editor.edit), "the editor's Escape was not consumed")
	sim:advance(0.2)
	check(not isWindowShown(), "the editor's Escape did not close the standalone window")
	check(not sim.G.GameMenuFrame or not sim.G.GameMenuFrame:IsShown(), "the editor's Escape opened the game menu")
	check(sim.loader.loaded.Blizzard_MacroUI == nil, "the editor's Escape loaded Blizzard_MacroUI")

	-- /macro (ShowMacroFrame, the function its slash handler calls) loads Blizzard_MacroUI; our window re-anchors
	-- over the panel and stays above it.
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
	sim:slash("/macroassist")
	check(isWindowShown(), "/macroassist did not open our window with the gamepad")
	check(not sim.G.MacroFrame:IsShown(), "/macroassist opened Blizzard's panel with the gamepad")
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

	-- One command key, /macroassist, toggles the pair.
	sim:slash("/macroassist")
	check(isOpen(), "/macroassist did not open the macro window")
	sim:slash("/macroassist")
	check(isClosed(), "/macroassist did not close the macro window")

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
	sim:slash("/macroassist")
	check(isWindowShown(), "/macroassist did not open our window in combat")
	check(not sim.G.MacroFrame:IsShown(), "/macroassist opened Blizzard's panel in combat")
	sim:slash("/macroassist")
	check(isClosed(), "/macroassist did not close our window in combat")
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
	sim:slash("/macroassist")
	check(isOpen(), "/macroassist did not open the macro window after combat")
	sim:enterCombat()
	sim:slash("/macroassist")
	check(isOpen(), "/macroassist closed the pair in combat")
	sim:leaveCombat()
	sim:slash("/macroassist")
	check(isClosed(), "/macroassist did not close the macro window after combat")

	sim:slash("/macroassist")
	sim:gamepadNavigate()
	sim:slash("/macroassist")
	check(isClosed(), "the mouse path stopped working after the gamepad")
	sim:expectNoErrors(ADDON)
	sim:expectNoGamepadTaint(ADDON)
end)

scenario("/macro and /m open, close and reopen the window, and combat keeps it open", function(sim)
	world.install(sim)
	sim:login()

	-- /macro stays Blizzard's command (WFA-38): the addon hooks ShowMacroFrame instead of writing its handler.
	local handler = sim.taint.slotInfo(sim.G.SlashCmdList, "MACRO")
	check(handler == nil or handler.addon ~= ADDON, "the addon wrote Blizzard's /macro handler")

	-- /macro and /m run the same handler, which calls ShowMacroFrame.
	pressMacroCommand(sim)
	check(panelOpen(sim), "/m did not open the macro window")
	pressMacroCommand(sim)
	check(panelClosed(sim), "/m did not close the macro window")
	pressMacroCommand(sim)
	check(panelOpen(sim), "/m did not reopen the macro window")
	pressMacroCommand(sim)
	check(panelClosed(sim), "/m did not close the macro window again")

	-- In combat the panel manager refuses an addon's hide, so /m leaves the pair open and raises no error.
	pressMacroCommand(sim)
	check(panelOpen(sim), "/macro did not open the macro window before combat")
	sim:enterCombat()
	pressMacroCommand(sim)
	check(panelOpen(sim), "/m closed the macro window in combat")
	sim:expectNoErrors(ADDON)
	sim:leaveCombat()
	pressMacroCommand(sim)
	check(panelClosed(sim), "/m did not close the macro window after combat")
	sim:expectNoErrors(ADDON)
	sim:expectNoGamepadTaint(ADDON)
end)

scenario("/macroassist then /m closes the window /macroassist opened", function(sim)
	world.install(sim)
	sim:login()
	pressMacroCommand(sim)
	pressMacroCommand(sim)
	sim:slash("/macroassist")
	check(panelOpen(sim), "/macroassist did not open the macro window")
	pressMacroCommand(sim)
	check(panelClosed(sim), "/m did not close the window /macroassist opened")
	sim:expectNoErrors(ADDON)
	sim:expectNoGamepadTaint(ADDON)
end)

scenario("a cold /macroassist is closed by the first /m", function(sim)
	world.install(sim)
	sim:login()
	sim:slash("/macroassist")
	check(sim.G[PLAYER] ~= nil and sim.G[PLAYER]:IsShown(), "/macroassist did not open our window")
	check(sim.G.MacroFrame == nil, "/macroassist created Blizzard's MacroFrame")
	check(sim.loader.loaded.Blizzard_MacroUI == nil, "/macroassist loaded Blizzard_MacroUI")

	pressMacroCommand(sim)
	check(panelClosed(sim), "/m did not close the window /macroassist opened")
	pressMacroCommand(sim)
	check(panelOpen(sim), "/m did not reopen the macro window")
	sim:expectNoErrors(ADDON)
	sim:expectNoGamepadTaint(ADDON)
end)

scenario("/m opens the window with the gamepad on and then leaves it open", function(sim)
	world.install(sim)
	sim:login()
	sim:setGamepad(true)
	pressMacroCommand(sim)
	check(panelOpen(sim), "/m did not open the macro window with the gamepad")
	pressMacroCommand(sim)
	check(panelOpen(sim), "/m closed the macro window with the gamepad")
	sim:gamepadNavigate()
	sim:expectNoGamepadTaint(ADDON)
	sim:setGamepad(false)
	pressMacroCommand(sim)
	check(panelClosed(sim), "/m did not close the macro window after the gamepad")
	sim:expectNoErrors(ADDON)
	sim:expectNoGamepadTaint(ADDON)
end)

scenario("/macroassist report opens ForeverCore's report with this addon's lines", function(sim)
	world.install(sim)
	sim:login()
	local ns
	for _, entry in ipairs(sim.loader.addons) do
		if entry.name == ADDON then
			ns = entry.ns
		end
	end
	check(ns and ns.core and ns.core.name == ADDON, "the addon did not register with ForeverCore")
	local text = ns.core.Report.Text(ns.ReportLines())
	check(text:find("Macros: 2 general, 5 character", 1, true) ~= nil, "the report misses the macro counts")
	check(text:find("History: 0 macros kept", 1, true) ~= nil, "the report misses the history")
	sim:slash("/macroassist report")
	local report = sim.G[ADDON .. "Report"]
	check(report ~= nil and report:IsShown(), "/macroassist report did not open the report window")
	sim:expectNoErrors(ADDON)
end)
