local _, ns = ...

if ns.broken then
	return
end

-- Our macro window. Blizzard's MacroFrame still opens and closes through every path the game has; once
-- Blizzard_MacroUI loads, its OnShow and OnHide hooks show and hide this frame and MacroFrame is drawn at alpha 0
-- underneath. Until then the window stands on its own at the panel manager's left-panel spot. Nothing here calls a
-- Lua method on MacroFrame, writes one of its fields or hooks one of its methods: the only contact is the engine's
-- own reads and calls (shown, alpha, frame level, points) and the two HookScripts in Core/Core.lua.

local L = ns.L

local WINDOW_WIDTH = 860
local WINDOW_HEIGHT = 500
local INSET_LEFT = 10
local INSET_RIGHT = -10
-- LargeSideTabButtonTemplate's art is 55 wide. The tabs own a rail inside the window's left edge, and the list
-- starts to the right of that rail, so the tabs sit beside the list they filter.
local SIDE_TAB_WIDTH = 55
local LIST_LEFT = INSET_LEFT + SIDE_TAB_WIDTH
local LIST_TOP = -60
local LIST_WIDTH = 250
local LIST_HEIGHT = 398
local SIDE_TAB_EDGE = 0
local SIDE_TAB_TOP = 60
local SIDE_TAB_GAP = 2
local HEADER_TOP = -30
local HEADER_HEIGHT = 34
local GAP = 8
local COLUMN_GAP = 12
local STATUS_HEIGHT = 22
local STATUS_INSET = 3
local BOTTOM_OFFSET = 42
local BUTTON_HEIGHT = 24
local BUTTON_WIDTH = 90
local DELETE_WIDTH = 90
local HISTORY_WIDTH = 90
local FOOTER_GAP = 6
local RENAME_WIDTH = 110
local RENAME_HEIGHT = 22
local SEARCH_LEFT = 60
local SEARCH_TOP = -32
local SEARCH_WIDTH = 146
local SEARCH_HEIGHT = 20
local COUNT_WIDTH = 40
local EXPLAIN_INSET = 3
local EXPLAIN_BOTTOM = 4
local EXPLAIN_TITLE_TOP = 8
local EXPLAIN_ROW_TOP = 26
local EXPLAIN_ROW_HEIGHT = 22
local EXPLAIN_KEY_GAP = 52
local EXPLAIN_ROWS = 5
local INSET_PADDING = 6
local SCROLL_RIGHT_PADDING = 4
local HEADER_ICON = 28
local HEADER_ICON_FRAME = 34
local ROW_HEIGHT = 38
local SCROLL_GAP = 4
local SCROLL_WIDTH = 18
-- Where Blizzard's panel manager puts a left-area panel, from UIParent's TOPLEFT
-- (Blizzard_UIParentPanelManager/Shared/UIPanelLayoutFrame.lua: LEFT_OFFSET and TOP_OFFSET).
local LEFT_PANEL_X = 16
local LEFT_PANEL_Y = -116

local WHITE_ICON_FRAME = "Interface\\Common\\WhiteIconFrame"
local MUTED = { 0.55, 0.55, 0.55 }
local ROW_MUTED = { 0.6, 0.6, 0.6 }
-- Icon art carries a baked-in border. The client's item buttons crop 8% off every edge, so every spell or item
-- icon we draw does the same and its frame never shows a second border inside ours.
local ICON_TEXCOORD = { 0.08, 0.92, 0.08, 0.92 }

-- Blizzard's MacroUI reads the slot limits as Constants.MacroConsts.MAX_* on this build; the client no longer
-- defines the old MAX_ACCOUNT_MACROS and MAX_CHARACTER_MACROS globals.
local MACRO_CONSTS = Constants and Constants.MacroConsts
local MAX_ACCOUNT = MACRO_CONSTS and MACRO_CONSTS.MAX_ACCOUNT_MACROS or 120
local MAX_CHARACTER = MACRO_CONSTS and MACRO_CONSTS.MAX_CHARACTER_MACROS or 30

---@class MacroAssistTab : Button
---@field Icon Texture
---@field SelectedTexture Texture
---@field tooltipText string
---@field SetChecked fun(self: MacroAssistTab, checked: boolean)
---@field SetFillToInterior fun(self: MacroAssistTab, fillToInterior: boolean, extent?: number)

---@class MacroAssistHeader : Frame
---@field iconButton Button
---@field icon Texture
---@field name FontString
---@field meta FontString
---@field rename Button

---@class MacroAssistSearchBox : EditBox
---@field Instructions FontString

---@class MacroAssistRow : Button
---@field macroIndex integer
---@field Icon Texture
---@field Name FontString
---@field Summary FontString
---@field Selected Texture
---@field SelectedBar Texture
---@field Highlight Texture

---@class MacroAssistScrollBox : Frame
---@field SetDataProvider fun(self: MacroAssistScrollBox, provider: any, scrollContext?: any)
---@field ForEachFrame fun(self: MacroAssistScrollBox, callback: fun(row: MacroAssistRow))
---@field ScrollToElementDataIndex fun(self: MacroAssistScrollBox, index: integer, alignment?: any)
---@field GetDerivedScrollOffset fun(self: MacroAssistScrollBox): number
---@field ScrollToOffset fun(self: MacroAssistScrollBox, offset: number, noInterpolation?: boolean)
---@field ScrollToBegin fun(self: MacroAssistScrollBox, noInterpolation?: boolean)

---@class MacroAssistExplainRow
---@field chip Texture
---@field key FontString
---@field text FontString

---@class MacroAssistExplainPanel : Frame
---@field rule Texture
---@field title FontString
---@field rows MacroAssistExplainRow[]

---@class MacroAssistTitleContainer : Frame
---@field TitleText FontString

---@class MacroAssistPortraitContainer : Frame
---@field portrait Texture

---@class MacroAssistFrame : Frame
---@field TitleContainer MacroAssistTitleContainer
---@field PortraitContainer MacroAssistPortraitContainer
---@field Inset Frame
---@field CloseButton Button
---@field header MacroAssistHeader
---@field searchBox MacroAssistSearchBox
---@field count FontString
---@field listInset Frame
---@field editorSurface Frame
---@field statusBar Frame
---@field explainPanel MacroAssistExplainPanel
---@field editor MacroAssistEditor
---@field iconSelector MacroAssistIconSelector
---@field history MacroAssistHistoryFrame
---@field scrollBox MacroAssistScrollBox
---@field scrollBar Frame
---@field empty FontString
---@field deleteButton Button
---@field historyButton Button
---@field newButton Button
---@field saveButton Button
---@field cancelButton Button
---@field Tabs MacroAssistTab[]

---@class MacroAssistWindow
---@field frame MacroAssistFrame
---@field tab integer
---@field dirty boolean
---@field drafts table<integer, string>
---@field filter string
---@field scrollOffsets table<integer, number>
---@field deleteArmed boolean
---@field selected integer?
---@field historySelected table?
---@field combat boolean
---@field count integer?
---@field base integer?
---@field maximum integer?
---@field desiredPosition integer?
local Window = {}
ns.MacroWindow = Window

-- The close button and the editor's Escape close the window through here: Blizzard's panel when it is shown,
-- otherwise our own frame. HideUIPanel is the client's public panel API, not a method on a Blizzard object;
-- tests/sim/macro_window_scenario.lua proves the call leaves no taint in Blizzard's panel code.
function Window.ClosePanel()
	if MacroFrame and MacroFrame:IsShown() then
		HideUIPanel(MacroFrame)
	elseif Window.frame then
		Window.frame:Hide()
	end
end

---@param tab MacroAssistTab
---@param selected boolean
local function SelectTabArt(tab, selected)
	-- LargeSideTabButtonTemplate's own checked art: the gold ring around the selected tab's icon.
	tab:SetChecked(selected)
end

---@param frame Frame
---@return MacroAssistHeader
local function BuildHeader(frame)
	local header = CreateFrame("Frame", nil, frame) --[[@as MacroAssistHeader]]
	header:SetHeight(HEADER_HEIGHT)
	local button = CreateFrame("Button", nil, header)
	button:SetSize(HEADER_ICON_FRAME, HEADER_ICON_FRAME)
	button:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
	button:RegisterForDrag("LeftButton")
	header.iconButton = button
	local border = button:CreateTexture(nil, "ARTWORK")
	border:SetAllPoints(button)
	border:SetTexture(WHITE_ICON_FRAME)
	border:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(HEADER_ICON, HEADER_ICON)
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	icon:SetTexCoord(ICON_TEXCOORD[1], ICON_TEXCOORD[2], ICON_TEXCOORD[3], ICON_TEXCOORD[4])
	header.icon = icon
	local name = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	name:SetPoint("TOPLEFT", button, "TOPRIGHT", 8, -1)
	name:SetPoint("RIGHT", header, "RIGHT", -RENAME_WIDTH - GAP, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	header.name = name
	local meta = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	meta:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
	meta:SetPoint("RIGHT", header, "RIGHT", -RENAME_WIDTH - GAP, 0)
	meta:SetJustifyH("LEFT")
	meta:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	header.meta = meta
	local rename = CreateFrame("Button", nil, header, "SharedButtonSmallTemplate")
	rename:SetSize(RENAME_WIDTH, RENAME_HEIGHT)
	rename:SetPoint("RIGHT", header, "RIGHT", 0, 0)
	rename:SetText(L["Rename"])
	header.rename = rename
	button:SetScript("OnDragStart", function()
		if Window.selected then
			PickupMacro(Window.selected)
		end
	end)
	button:SetScript("OnEnter", function()
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Drag to your action bars"], 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		if GameTooltip:IsOwned(button) then
			GameTooltip:Hide()
		end
	end)
	return header
end

-- The "What it does" panel at the bottom of the code surface. It is a plain frame over the surface, with one row per
-- click and modifier branch; the window fills it from ns.ExplainCases whenever the editor's text changes.
---@param parent Frame
---@return MacroAssistExplainPanel
local function BuildExplainPanel(parent)
	local panel = CreateFrame("Frame", nil, parent) --[[@as MacroAssistExplainPanel]]
	panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", EXPLAIN_INSET, EXPLAIN_BOTTOM)
	panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -EXPLAIN_INSET, EXPLAIN_BOTTOM)
	panel:SetHeight(1)
	panel:SetFrameLevel(parent:GetFrameLevel() + 6)
	local background = panel:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(panel)
	background:SetColorTexture(0.035, 0.035, 0.04, 0.98)
	panel.rule = panel:CreateTexture(nil, "BORDER")
	panel.rule:SetColorTexture(1, 1, 1, 0.08)
	panel.rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	panel.rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
	panel.rule:SetHeight(1)
	panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -EXPLAIN_TITLE_TOP)
	panel.title:SetText(L["What it does"])
	panel.rows = {}
	for index = 1, EXPLAIN_ROWS do
		local chip = panel:CreateTexture(nil, "ARTWORK")
		chip:SetColorTexture(1, 1, 1, 0.08)
		local key = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		key:SetJustifyH("CENTER")
		key:SetWordWrap(false)
		local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
		text:SetTextColor(0.8, 0.8, 0.8)
		panel.rows[index] = { chip = chip, key = key, text = text }
	end
	panel:Hide()
	return panel
end

---@return table
function Window.Create()
	if Window.frame then
		return Window
	end
	local template = "ButtonFrameTemplate"
	local frame = CreateFrame("Frame", "MacroAssistForeverFrame", UIParent, template) --[[@as MacroAssistFrame]]
	frame:Hide()
	Window.frame = frame
	frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", LEFT_PANEL_X, LEFT_PANEL_Y)
	frame:SetFrameLevel(10)
	frame:EnableMouse(true)
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame.TitleContainer.TitleText:SetText(L["Macros"])
	frame.PortraitContainer.portrait:SetTexture(ns.Icon)
	frame.Inset:Hide()
	frame.CloseButton:SetScript("OnClick", function()
		Window.ClosePanel()
	end)

	local name = ns.Readable(UnitName("player")) or L["General"]
	---@type MacroAssistTab[]
	local tabs = {}
	for index = 1, 2 do
		-- A Button, so the gamepad's SmartNavigation scan never reads a Frame's mouse scripts; the template owns
		-- the square side-tab art, its mask and the checked ring. The rail sits inside the window's left edge,
		-- beside the list the tabs filter.
		local tab = CreateFrame("Button", nil, frame, "LargeSideTabButtonTemplate") --[[@as MacroAssistTab]]
		tab:SetID(index)
		if index == 1 then
			tab:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_TAB_EDGE, -SIDE_TAB_TOP)
			-- art-ok: a square icon in the square LargeSideTabButtonTemplate sizes for it
			tab.Icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
			tab.tooltipText = L["General"]
		else
			tab:SetPoint("TOP", tabs[1], "BOTTOM", 0, -SIDE_TAB_GAP)
			tab.tooltipText = L["%s's Macros"]:format(name)
		end
		tab:SetFillToInterior(true)
		tab:SetScript("OnClick", function()
			Window:SelectTab(index)
		end)
		tabs[index] = tab
	end
	frame.Tabs = tabs
	Window:UpdatePortrait()

	local searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate") --[[@as MacroAssistSearchBox]]
	searchBox:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
	searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_LEFT + SEARCH_LEFT, SEARCH_TOP)
	searchBox.Instructions:SetText(L["Search macros"])
	searchBox:HookScript("OnTextChanged", function(edit)
		Window:SetFilter(edit:GetText() or "")
	end)
	frame.searchBox = searchBox

	-- The count sits at the list column's right edge, right of the search box, as "9/30".
	local count = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	count:SetPoint("RIGHT", frame, "TOPLEFT", LIST_LEFT + LIST_WIDTH, SEARCH_TOP - SEARCH_HEIGHT / 2)
	count:SetSize(COUNT_WIDTH, SEARCH_HEIGHT)
	count:SetJustifyH("RIGHT")
	count:SetWordWrap(false)
	count:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	frame.count = count

	local listInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	listInset:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_LEFT, LIST_TOP)
	listInset:SetSize(LIST_WIDTH, LIST_HEIGHT)
	frame.listInset = listInset

	local scrollBox = CreateFrame("Frame", nil, listInset, "WowScrollBoxList") --[[@as MacroAssistScrollBox]]
	scrollBox:SetPoint("TOPLEFT", listInset, "TOPLEFT", INSET_PADDING, -INSET_PADDING)
	scrollBox:SetPoint(
		"BOTTOMRIGHT",
		listInset,
		"BOTTOMRIGHT",
		-(SCROLL_WIDTH + SCROLL_GAP + SCROLL_RIGHT_PADDING),
		INSET_PADDING
	)
	local scrollBar = CreateFrame("EventFrame", nil, listInset, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", SCROLL_GAP, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", SCROLL_GAP, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("MacroAssistRowTemplate", function(row, data)
		---@cast row MacroAssistRow
		Window:InitializeRow(row, data)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox --[[@as ScrollBoxListMixin]], scrollBar, view)
	frame.scrollBox = scrollBox
	frame.scrollBar = scrollBar
	local empty = listInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	empty:SetPoint("CENTER", listInset, "CENTER", 0, 0)
	empty:SetText(L["No macros yet. Press New to make one."])
	empty:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	empty:Hide()
	frame.empty = empty

	local header = BuildHeader(frame)
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_LEFT + LIST_WIDTH + COLUMN_GAP, HEADER_TOP)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", INSET_RIGHT, HEADER_TOP)
	frame.header = header

	-- The code surface is a BackdropTemplate, not an InsetFrameTemplate: a dark panel behind the editor, filling the
	-- right column down to the status line.
	local editorSurface = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	editorSurface:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -GAP)
	editorSurface:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", INSET_RIGHT, BOTTOM_OFFSET + STATUS_HEIGHT)
	-- The tooltip's old loose backdrop files are blacklisted by the suite asset gate, so the same dark fill and
	-- 1-unit grey edge come from the client's white primitive instead of the pre-NineSlice tooltip files.
	editorSurface:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	editorSurface:SetBackdropColor(0.035, 0.035, 0.04, 0.94)
	editorSurface:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
	frame.editorSurface = editorSurface

	local statusBar = CreateFrame("Frame", nil, frame)
	statusBar:SetPoint("TOPLEFT", editorSurface, "BOTTOMLEFT", STATUS_INSET, 0)
	statusBar:SetPoint("TOPRIGHT", editorSurface, "BOTTOMRIGHT", -STATUS_INSET, 0)
	statusBar:SetHeight(STATUS_HEIGHT)
	statusBar:EnableMouse(false)
	frame.statusBar = statusBar

	local new = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	new:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	new:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", LIST_LEFT, 8)
	new:SetText(L["New"])
	local delete = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	delete:SetSize(DELETE_WIDTH, BUTTON_HEIGHT)
	delete:SetPoint("LEFT", new, "RIGHT", FOOTER_GAP, 0)
	delete:SetText(L["Delete"])
	local history = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	history:SetSize(HISTORY_WIDTH, BUTTON_HEIGHT)
	history:SetPoint("LEFT", delete, "RIGHT", FOOTER_GAP, 0)
	history:SetText(L["History"])
	local save = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	save:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	save:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", INSET_RIGHT, 8)
	save:SetText(L["Save"])
	local cancel = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	cancel:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	cancel:SetPoint("RIGHT", save, "LEFT", -FOOTER_GAP, 0)
	cancel:SetText(L["Cancel"])

	frame.deleteButton = delete
	frame.historyButton = history
	frame.newButton = new
	frame.saveButton = save
	frame.cancelButton = cancel

	Window.tab = 1
	Window.dirty = false
	Window.drafts = {}
	Window.filter = ""
	Window.scrollOffsets = {}
	Window.deleteArmed = false
	Window.selected = nil
	Window.historySelected = nil
	Window.combat = false

	frame.explainPanel = BuildExplainPanel(editorSurface)
	frame.editor = ns.Editor.Create(editorSurface, statusBar)
	frame.history = ns.HistoryPanel.Create(frame)
	local lastWidth
	editorSurface:SetScript("OnSizeChanged", function(_, width)
		if width > 1 and width ~= lastWidth and frame:IsShown() then
			lastWidth = width
			frame.editor:RefreshAll()
		end
	end)
	frame.editor.onEdited = function()
		Window:OnTextEdited()
	end
	frame.editor.onExplain = function()
		Window:UpdateExplain()
	end
	frame.editor.onEscape = function()
		Window.ClosePanel()
	end
	frame.iconSelector = ns.IconSelector.Create(frame)

	header.rename:SetScript("OnClick", function()
		Window:OpenNameAndIcon()
	end)
	delete:SetScript("OnClick", function()
		Window:Delete()
	end)
	history:SetScript("OnClick", function()
		Window:OpenHistory()
	end)
	new:SetScript("OnClick", function()
		Window:New()
	end)
	save:SetScript("OnClick", function()
		Window:Save()
	end)
	cancel:SetScript("OnClick", function()
		Window:Cancel()
	end)

	frame:SetScript("OnEvent", function(_, event, ...)
		Window:OnEvent(event, ...)
	end)
	frame:SetScript("OnShow", function()
		Window:OnShow()
	end)
	frame:SetScript("OnHide", function()
		Window:OnHide()
	end)

	SelectTabArt(tabs[1], true)
	SelectTabArt(tabs[2], false)
	Window:RefreshList()
	Window:UpdateExplain()
	return Window
end

-- Once Blizzard_MacroUI loads, sit exactly over MacroFrame and above it. Engine calls only: points, strata and level.
function Window.AttachToMacroFrame()
	local frame = Window.frame
	if not frame or not MacroFrame then
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", MacroFrame, "TOPLEFT", 0, 0)
	frame:SetFrameStrata("HIGH")
	frame:SetFrameLevel(MacroFrame:GetFrameLevel() + 10)
end

-- The character tab is the player's own portrait, drawn by the client into the tab's square icon; UNIT_PORTRAIT_UPDATE
-- redraws it when the portrait changes (a haircut, a barbershop visit) and every show starts from the current one.
function Window:UpdatePortrait()
	local tabs = self.frame and self.frame.Tabs
	local tab = tabs and tabs[2]
	if not tab then
		return
	end
	SetPortraitTexture(tab.Icon, "player")
	tab:SetFillToInterior(true)
end

---@param row MacroAssistRow
---@param data table
function Window:InitializeRow(row, data)
	row.macroIndex = data.index
	row.Icon:SetTexture(data.icon)
	row.Icon:SetTexCoord(ICON_TEXCOORD[1], ICON_TEXCOORD[2], ICON_TEXCOORD[3], ICON_TEXCOORD[4])
	row.Name:SetText(data.name or "")
	row.Summary:SetText(data.summary or "")
	row.Summary:SetTextColor(ROW_MUTED[1], ROW_MUTED[2], ROW_MUTED[3])
	local selected = data.index == self.selected
	row.Selected:SetShown(selected)
	row.SelectedBar:SetShown(selected)
	if selected then
		row.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	else
		row.Name:SetTextColor(1, 1, 1)
	end
	row.Highlight:Hide()
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnClick", function()
		Window:SelectMacro(row.macroIndex)
	end)
	row:SetScript("OnDragStart", function()
		PickupMacro(row.macroIndex)
	end)
	row:SetScript("OnEnter", function()
		row.Highlight:Show()
	end)
	row:SetScript("OnLeave", function()
		row.Highlight:Hide()
	end)
end

---@param index integer
function Window:SelectTab(index)
	if index == self.tab then
		return
	end
	local scrollBox = self.frame and self.frame.scrollBox
	if scrollBox and scrollBox.GetDerivedScrollOffset then
		local offset = scrollBox:GetDerivedScrollOffset()
		if type(offset) == "number" then
			self.scrollOffsets[self.tab] = offset
		end
	end
	self:LeaveSelected()
	self.tab = index
	self.deleteArmed = false
	for tabIndex, tab in ipairs(self.frame.Tabs) do
		SelectTabArt(tab, tabIndex == index)
	end
	self:RefreshList(self.scrollOffsets[index])
end

-- The search box filters on the name and the summary as the player types, without regard to case. The match is a
-- plain substring, so a space in the box matches the space between two summary words.
---@param text string
function Window:SetFilter(text)
	local filter = type(text) == "string" and text or ""
	if filter == self.filter then
		return
	end
	self.filter = filter
	self:RefreshList()
end

---@return integer base
---@return integer count
---@return integer maximum
function Window:TabBounds()
	local numAccount, numCharacter = GetNumMacros()
	numAccount, numCharacter = numAccount or 0, numCharacter or 0
	if self.tab == 1 then
		return 0, numAccount, MAX_ACCOUNT
	end
	return MAX_ACCOUNT, numCharacter, MAX_CHARACTER
end

---@param keepScrollOffset number? the scroll offset to restore after a tab switch
function Window:RefreshList(keepScrollOffset)
	if not self.frame then
		return
	end
	local base, count, maximum = self:TabBounds()
	self.count = count
	self.base = base
	self.maximum = maximum
	local position
	if self.desiredPosition then
		position = self.desiredPosition
	elseif self.selected and self.selected > base and self.selected <= base + count then
		position = self.selected - base
	elseif self.selected == nil and count > 0 then
		position = 1
	end
	if position and position > count then
		position = count
	end
	if position and position < 1 then
		position = count > 0 and 1 or nil
	end
	if not position then
		position = count > 0 and 1 or nil
	end
	self.desiredPosition = nil
	if count == 0 then
		self.deleteArmed = false
		self.selected = nil
		self.dirty = false
		self.frame.editor:SetText("")
	else
		local newSelected = base + position
		if newSelected ~= self.selected then
			self:LeaveSelected()
			self.selected = newSelected
			self:LoadSelected()
		end
	end

	local needle = (self.filter or ""):lower()
	local selectedVisible = false
	local provider = CreateDataProvider() --[[@as DataProviderMixin]]
	for index = 1, count do
		local actual = base + index
		local name, icon, body = GetMacroInfo(actual)
		local summary = name and ns.ExplainSummary(body or "") or ""
		if name and (needle == "" or name:lower():find(needle, 1, true) or summary:lower():find(needle, 1, true)) then
			provider:Insert({
				index = actual,
				name = name,
				icon = icon,
				summary = summary,
			})
			if actual == self.selected then
				selectedVisible = true
			end
		end
	end
	self.frame.scrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
	self.frame.empty:SetShown(count == 0)
	if self.frame.scrollBox.ForEachFrame then
		self.frame.scrollBox:ForEachFrame(function(row)
			---@cast row MacroAssistRow
			local selected = row.macroIndex == self.selected
			row.Selected:SetShown(selected)
			row.SelectedBar:SetShown(selected)
			if selected then
				row.Name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
			else
				row.Name:SetTextColor(1, 1, 1)
			end
		end)
	end
	if keepScrollOffset ~= nil and self.frame.scrollBox.ScrollToOffset then
		self.frame.scrollBox:ScrollToOffset(keepScrollOffset, true)
	elseif position and selectedVisible and self.frame.scrollBox.ScrollToElementDataIndex then
		self.frame.scrollBox:ScrollToElementDataIndex(position, ScrollBoxConstants.AlignNearest)
	elseif needle ~= "" and self.frame.scrollBox.ScrollToBegin then
		self.frame.scrollBox:ScrollToBegin(true)
	end
	self:UpdateHeader()
	self:UpdateButtons()
	self:RefreshHistory()
end

function Window:LoadSelected()
	if not self.selected then
		self.dirty = false
		self.frame.editor:SetText("")
		return
	end
	local draft = self.drafts[self.selected]
	if draft then
		self.dirty = true
		self.frame.editor:SetText(draft)
	else
		local _, _, body = GetMacroInfo(self.selected)
		self.dirty = false
		self.frame.editor:SetText(body or "")
	end
	self.deleteArmed = false
	self:UpdateHeader()
	self:UpdateButtons()
end

function Window:LeaveSelected()
	if not self.selected then
		return
	end
	if self.dirty then
		if InCombatLockdown() then
			self.drafts[self.selected] = self.frame.editor:GetText()
		else
			self:SaveCurrent()
		end
	end
end

-- The clock a snapshot's time is stamped with: the client's server clock, so the History list's times match the
-- player's.
---@param _ MacroAssistWindow
---@return number
function Window.Now(_)
	if type(GetServerTime) == "function" then
		return GetServerTime()
	end
	return 0
end

---@param _ MacroAssistWindow
---@param index integer
---@return integer tab
function Window.TabForIndex(_, index)
	return index > MAX_ACCOUNT and 2 or 1
end

-- Every macro write goes through here, so a snapshot always lands in SavedVariables before the store changes. A
-- rename moves the macro's whole history to the new name, so it is not lost when the name changes.
---@param index integer
---@param name string?
---@param icon any
---@param body string?
---@return boolean
function Window:WriteMacro(index, name, icon, body)
	if InCombatLockdown() then
		return false
	end
	local oldName, oldIcon, oldBody = GetMacroInfo(index)
	if oldName then
		ns.History.Snapshot(MacroAssistForeverDB, {
			name = oldName,
			icon = oldIcon,
			body = oldBody,
			tab = self:TabForIndex(index),
		}, self:Now())
	end
	EditMacro(index, name, icon, body)
	if name and oldName and name ~= oldName then
		ns.History.Rename(MacroAssistForeverDB, oldName, name)
	end
	return true
end

-- A new macro's starting state is snapshotted before the create; a create the client refuses leaves no record.
---@param name string
---@param icon any
---@param body string?
---@param character boolean
---@return integer?
function Window:WriteCreate(name, icon, body, character)
	if InCombatLockdown() then
		return nil
	end
	local db = MacroAssistForeverDB
	local snapshot = ns.History.Snapshot(db, {
		name = name,
		icon = icon,
		body = body or "",
		tab = character and 2 or 1,
	}, self:Now())
	local actual = CreateMacro(name, icon, body, character)
	if not actual then
		ns.History.Remove(db, name, snapshot)
	end
	return actual
end

-- A delete writes too, and its snapshot is the macro's last live state, so the Deleted section can restore it.
---@param index integer
---@return boolean
function Window:WriteDelete(index)
	if InCombatLockdown() then
		return false
	end
	local name, icon, body = GetMacroInfo(index)
	if name then
		ns.History.Snapshot(MacroAssistForeverDB, {
			name = name,
			icon = icon,
			body = body,
			tab = self:TabForIndex(index),
		}, self:Now())
	end
	DeleteMacro(index)
	return true
end

function Window:SaveCurrent()
	if not self.dirty or not self.selected then
		return true
	end
	if not self:WriteMacro(self.selected, nil, nil, self.frame.editor:GetText()) then
		return false
	end
	self.drafts[self.selected] = nil
	self.dirty = false
	self:UpdateButtons()
	return true
end

---@param actual integer
function Window:SelectMacro(actual)
	if actual == self.selected then
		return
	end
	self:LeaveSelected()
	self.selected = actual
	self:LoadSelected()
	self:RefreshList()
end

function Window:UpdateHeader()
	local frame = self.frame
	local header = frame.header
	frame.count:SetText(L["%d/%d"]:format(self.count or 0, self.maximum or 0))
	if not self.selected then
		header.icon:SetTexture(nil)
		header.name:SetText(L["No macro selected"])
		header.meta:SetText("")
		return
	end
	local name, icon = GetMacroInfo(self.selected)
	header.icon:SetTexture(icon)
	header.name:SetText(name or L["No macro selected"])
	header.meta:SetText(self.tab == 1 and L["General macro"] or L["Character macro"])
end

-- Fill the "What it does" panel from the current text. No cases means no panel at all, never an empty one. The panel
-- is anchored to the bottom of the code surface, which keeps the full height of the right column.
function Window:UpdateExplain()
	local frame = self.frame
	if not frame or not frame.explainPanel or not frame.editor then
		return
	end
	local panel = frame.explainPanel
	local cases = ns.ExplainCases(frame.editor:GetText())
	if #cases == 0 then
		panel:Hide()
		return
	end
	panel:SetHeight(EXPLAIN_ROW_TOP + #cases * EXPLAIN_ROW_HEIGHT + EXPLAIN_TITLE_TOP)
	for index, row in ipairs(panel.rows) do
		local case = cases[index]
		if case then
			row.chip:Show()
			row.key:Show()
			row.text:Show()
			row.key:SetText(case.key)
			local keyWidth = row.key:GetStringWidth() + 12
			local y = -(EXPLAIN_ROW_TOP + (index - 1) * EXPLAIN_ROW_HEIGHT)
			row.chip:ClearAllPoints()
			row.chip:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, y)
			row.chip:SetSize(keyWidth, 16)
			row.key:ClearAllPoints()
			row.key:SetPoint("LEFT", row.chip, "LEFT", 0, 0)
			row.key:SetWidth(keyWidth)
			row.text:ClearAllPoints()
			row.text:SetPoint("LEFT", row.chip, "LEFT", EXPLAIN_KEY_GAP, 0)
			row.text:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
			row.text:SetText(case.text)
		else
			row.chip:Hide()
			row.key:Hide()
			row.text:Hide()
		end
	end
	panel:Show()
end

function Window:UpdateButtons()
	if not self.frame then
		return
	end
	local combat = self.combat == true
	local hasMacro = self.selected ~= nil
	self.frame.deleteButton:SetEnabled(hasMacro and not combat)
	self.frame.deleteButton:SetText(self.deleteArmed and L["Click again to delete"] or L["Delete"])
	self.frame.historyButton:SetEnabled(true)
	self.frame.newButton:SetEnabled((self.count or 0) < (self.maximum or 0) and not combat)
	self.frame.saveButton:SetEnabled(self.dirty and not combat)
	self.frame.cancelButton:SetEnabled(self.dirty)
	self.frame.header.rename:SetEnabled(hasMacro and not combat)
	if self.frame.history:IsShown() then
		self.frame.history:UpdateButtons()
	end
end

function Window:OnTextEdited()
	self.dirty = true
	self.deleteArmed = false
	self:UpdateButtons()
end

function Window:Save()
	if self:SaveCurrent() then
		self:RefreshList()
	end
end

function Window:Cancel()
	if self.drafts[self.selected] then
		self.drafts[self.selected] = nil
	end
	self.dirty = false
	self.deleteArmed = false
	self:LoadSelected()
	self:UpdateButtons()
end

function Window:Delete()
	if not self.selected or InCombatLockdown() then
		return
	end
	if not self.deleteArmed then
		self.deleteArmed = true
		self:UpdateButtons()
		return
	end
	local oldPosition = self.selected - (self.base or 0)
	self:WriteDelete(self.selected)
	self.drafts[self.selected] = nil
	self.selected = nil
	self.dirty = false
	self.deleteArmed = false
	self.desiredPosition = oldPosition
	self:RefreshList()
end

function Window:New()
	if InCombatLockdown() then
		return
	end
	if not self:SaveCurrent() then
		return
	end
	local base = self.base or 0
	self.frame.iconSelector:Open("", "Interface\\Icons\\INV_Misc_QuestionMark", function(name, icon)
		if InCombatLockdown() then
			return
		end
		local actual = self:WriteCreate(name, icon, nil, self.tab == 2)
		if not actual then
			return
		end
		self.drafts[actual] = nil
		self.selected = actual
		self.dirty = false
		self.desiredPosition = actual - base
		self:LoadSelected()
		self:RefreshList()
		self.frame.editor:Focus()
	end)
end

function Window:OpenNameAndIcon()
	if not self.selected or InCombatLockdown() then
		return
	end
	if not self:SaveCurrent() then
		return
	end
	local name, icon = GetMacroInfo(self.selected)
	if not name then
		return
	end
	self.frame.iconSelector:Open(name, icon, function(newName, newIcon)
		if InCombatLockdown() then
			return
		end
		self:WriteMacro(self.selected, newName, newIcon)
		self:RefreshList()
	end)
end

---@param _ MacroAssistWindow
---@param name string?
---@return integer?
function Window.FindMacro(_, name)
	if type(name) ~= "string" then
		return nil
	end
	local account, character = GetNumMacros()
	account, character = account or 0, character or 0
	for index = 1, account do
		if GetMacroInfo(index) == name then
			return index
		end
	end
	for index = MAX_ACCOUNT + 1, MAX_ACCOUNT + character do
		if GetMacroInfo(index) == name then
			return index
		end
	end
end

---@param _ MacroAssistWindow
---@return table<string, boolean>
function Window.LiveMacroNames(_)
	local live = {}
	local account, character = GetNumMacros()
	account, character = account or 0, character or 0
	for index = 1, account do
		local name = GetMacroInfo(index)
		if name then
			live[name] = true
		end
	end
	for index = MAX_ACCOUNT + 1, MAX_ACCOUNT + character do
		local name = GetMacroInfo(index)
		if name then
			live[name] = true
		end
	end
	return live
end

function Window:OpenHistory()
	local frame = self.frame
	if not frame or not frame.history then
		return
	end
	if not frame.history:IsShown() then
		self.historySelected = nil
	end
	frame.history:Refresh(self)
	frame.history:Show()
end

function Window:RefreshHistory()
	local frame = self.frame
	if frame and frame.history and frame.history:IsShown() then
		frame.history:Refresh(self)
	end
end

-- Restore writes the chosen snapshot through the same path as Save: the macro is edited when its name is live, and
-- created when the macro was deleted. In combat nothing is written.
---@param key string
---@param entry MacroAssistSnapshot
function Window:RestoreSnapshot(key, entry)
	if InCombatLockdown() then
		return
	end
	local db = MacroAssistForeverDB
	local record = db and db.history and db.history[key]
	local kind, actual = ns.History.Restore(entry, {
		inCombat = InCombatLockdown(),
		find = function(name)
			return self:FindMacro(name)
		end,
		edit = function(index, name, icon, body)
			self:WriteMacro(index, name, icon, body)
		end,
		create = function(name, icon, body, character)
			return self:WriteCreate(name, icon, body, character)
		end,
		character = record ~= nil and record.tab == 2,
	})
	if not kind or not actual then
		self:RefreshHistory()
		return
	end
	local tab = record and record.tab or self:TabForIndex(actual)
	if tab ~= self.tab then
		self.tab = tab
		for tabIndex, button in ipairs(self.frame.Tabs) do
			SelectTabArt(button, tabIndex == tab)
		end
	end
	self.drafts[actual] = nil
	self.selected = actual
	self.dirty = false
	self.deleteArmed = false
	self.desiredPosition = actual - (tab == 1 and 0 or MAX_ACCOUNT)
	self:LoadSelected()
	self:RefreshList()
end

function Window:OnShow()
	local frame = self.frame
	frame:RegisterEvent("UPDATE_MACROS")
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterEvent("SPELLS_CHANGED")
	frame:RegisterEvent("MODIFIER_STATE_CHANGED")
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
	ns.Context.Rebuild()
	self.combat = InCombatLockdown()
	self.deleteArmed = false
	self:UpdatePortrait()
	frame.editor:RefreshAll()
	frame.editor:SetCombat(self.combat)
	self:RefreshList()
	self:UpdateButtons()
end

function Window:OnHide()
	local frame = self.frame
	if self.dirty then
		self:SaveCurrent()
	end
	frame:UnregisterEvent("UPDATE_MACROS")
	frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
	frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
	frame:UnregisterEvent("SPELLS_CHANGED")
	frame:UnregisterEvent("MODIFIER_STATE_CHANGED")
	frame:UnregisterEvent("PLAYER_TARGET_CHANGED")
	frame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
	frame:UnregisterEvent("UNIT_PORTRAIT_UPDATE")
	frame.editor:ClearFocus()
	frame.editor:HideCompletion()
	if frame.iconSelector then
		frame.iconSelector:Hide()
	end
	if frame.history then
		frame.history:Hide()
	end
end

function Window:OnEvent(event, ...)
	local frame = self.frame
	if event == "UPDATE_MACROS" then
		self:RefreshList()
	elseif event == "UNIT_PORTRAIT_UPDATE" then
		local unit = ...
		if unit == "player" then
			self:UpdatePortrait()
		end
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		self.combat = event == "PLAYER_REGEN_DISABLED"
		frame.editor:SetCombat(self.combat)
		self:UpdateButtons()
	elseif event == "SPELLS_CHANGED" then
		ns.Context.Rebuild()
		frame.editor:RefreshAll()
		if frame.editor.popup:IsShown() then
			frame.editor:RefreshCompletions()
		end
	elseif
		event == "MODIFIER_STATE_CHANGED"
		or event == "PLAYER_TARGET_CHANGED"
		or event == "UPDATE_MOUSEOVER_UNIT"
	then
		frame.editor:UpdateStatus()
		if frame.editor.popup:IsShown() then
			frame.editor:RefreshCompletions()
		end
	end
end
