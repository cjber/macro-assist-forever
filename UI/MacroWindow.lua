local _, ns = ...

-- Our macro window. Blizzard's MacroFrame still opens and closes through every path the game has; once
-- Blizzard_MacroUI loads, its OnShow and OnHide hooks show and hide this frame and MacroFrame is drawn at alpha 0
-- underneath. Until then the window stands on its own at the panel manager's left-panel spot. Nothing here calls a
-- Lua method on MacroFrame, writes one of its fields or hooks one of its methods: the only contact is the engine's
-- own reads and calls (shown, alpha, frame level, points) and the two HookScripts in Core/Core.lua.

local L = ns.L

local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 930
local INSET_LEFT = 8
local INSET_RIGHT = -8
local TAB_LEFT = 54
local TAB_TOP = -32
local LIST_TOP = -70
local LIST_HEIGHT = 320
local HEADER_HEIGHT = 64
local GAP = 8
local BOTTOM_OFFSET = 46
local BUTTON_HEIGHT = 30
local BUTTON_WIDTH = 120
local DELETE_WIDTH = 140
local CHANGE_WIDTH = 200
local INSET_PADDING = 6
local SCROLL_RIGHT_PADDING = 4
local HEADER_ICON = 36
local HEADER_ICON_FRAME = 44
local ROW_HEIGHT = 46
local SCROLL_GAP = 4
local SCROLL_WIDTH = 18
-- Where Blizzard's panel manager puts a left-area panel, from UIParent's TOPLEFT
-- (Blizzard_UIParentPanelManager/Shared/UIPanelLayoutFrame.lua: LEFT_OFFSET and TOP_OFFSET).
local LEFT_PANEL_X = 16
local LEFT_PANEL_Y = -116

local PORTRAIT = "Interface\\Icons\\inv_misc_note_01"
local WHITE_ICON_FRAME = "Interface\\Common\\WhiteIconFrame"
local MUTED = { 0.55, 0.55, 0.55 }

-- Blizzard's MacroUI reads the slot limits as Constants.MacroConsts.MAX_* on this build; the client no longer
-- defines the old MAX_ACCOUNT_MACROS and MAX_CHARACTER_MACROS globals.
local MACRO_CONSTS = Constants and Constants.MacroConsts
local MAX_ACCOUNT = MACRO_CONSTS and MACRO_CONSTS.MAX_ACCOUNT_MACROS or 120
local MAX_CHARACTER = MACRO_CONSTS and MACRO_CONSTS.MAX_CHARACTER_MACROS or 30

---@class MacroAssistTab : Button
---@field Left Texture
---@field Middle Texture
---@field Right Texture
---@field LeftActive Texture
---@field MiddleActive Texture
---@field RightActive Texture
---@field Text FontString

---@class MacroAssistHeader : Frame
---@field icon Texture
---@field name FontString
---@field meta FontString
---@field change Button

---@class MacroAssistRow : Button
---@field macroIndex integer
---@field Icon Texture
---@field Name FontString
---@field Summary FontString
---@field Selected Texture
---@field Highlight Texture

---@class MacroAssistScrollBox : Frame
---@field SetDataProvider fun(self: MacroAssistScrollBox, provider: any, scrollContext?: any)
---@field ForEachFrame fun(self: MacroAssistScrollBox, callback: fun(row: MacroAssistRow))
---@field ScrollToElementDataIndex fun(self: MacroAssistScrollBox, index: integer, alignment?: any)

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
---@field listInset Frame
---@field editorInset Frame
---@field editor MacroAssistEditor
---@field iconSelector MacroAssistIconSelector
---@field scrollBox MacroAssistScrollBox
---@field scrollBar Frame
---@field empty FontString
---@field deleteButton Button
---@field newButton Button
---@field saveButton Button
---@field cancelButton Button
---@field Tabs MacroAssistTab[]
---@field tabPadding number
---@field minTabWidth number
---@field maxTabWidth number

---@class MacroAssistWindow
---@field frame MacroAssistFrame
---@field tab integer
---@field dirty boolean
---@field drafts table<integer, string>
---@field deleteArmed boolean
---@field selected integer?
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
	tab.LeftActive:SetShown(selected)
	tab.MiddleActive:SetShown(selected)
	tab.RightActive:SetShown(selected)
	tab.Left:SetShown(not selected)
	tab.Middle:SetShown(not selected)
	tab.Right:SetShown(not selected)
	tab.Text:SetPoint("CENTER", tab, "CENTER", 0, selected and -4 or -8)
	if selected then
		tab:Disable()
		tab:SetDisabledFontObject(GameFontHighlightSmall)
	else
		tab:Enable()
	end
end

---@param frame Frame
---@return MacroAssistHeader
local function BuildHeader(frame)
	local header = CreateFrame("Frame", nil, frame) --[[@as MacroAssistHeader]]
	header:SetHeight(HEADER_HEIGHT)
	local border = header:CreateTexture(nil, "ARTWORK")
	border:SetSize(HEADER_ICON_FRAME, HEADER_ICON_FRAME)
	border:SetPoint("TOPLEFT", header, "TOPLEFT", 10, -8)
	border:SetTexture(WHITE_ICON_FRAME)
	border:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetSize(HEADER_ICON, HEADER_ICON)
	icon:SetPoint("CENTER", border, "CENTER", 0, 0)
	header.icon = icon
	local name = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	name:SetPoint("TOPLEFT", border, "TOPRIGHT", 8, -1)
	name:SetPoint("RIGHT", header, "RIGHT", -220, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	header.name = name
	local meta = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	meta:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
	meta:SetPoint("RIGHT", header, "RIGHT", -220, 0)
	meta:SetJustifyH("LEFT")
	meta:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	header.meta = meta
	local change = CreateFrame("Button", nil, header, "SharedButtonTemplate")
	change:SetSize(CHANGE_WIDTH, BUTTON_HEIGHT)
	change:SetPoint("RIGHT", header, "RIGHT", -10, 0)
	change:SetText(L["Change Name/Icon"])
	header.change = change
	return header
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
	frame.PortraitContainer.portrait:SetTexture(PORTRAIT)
	frame.Inset:Hide()
	frame.CloseButton:SetScript("OnClick", function()
		Window.ClosePanel()
	end)

	local name = ns.Readable(UnitName("player")) or L["General"]
	---@type MacroAssistTab[]
	local tabs = {}
	for index = 1, 2 do
		local tab = CreateFrame("Button", nil, frame, "PanelTopTabButtonTemplate") --[[@as MacroAssistTab]]
		tab:SetID(index)
		if index == 1 then
			tab:SetPoint("TOPLEFT", frame, "TOPLEFT", TAB_LEFT, TAB_TOP)
			tab:SetText(L["General"])
		else
			tab:SetPoint("LEFT", tabs[1], "RIGHT", 3, 0)
			tab:SetText(L["%s's Macros"]:format(name))
		end
		tab:SetScript("OnClick", function()
			Window:SelectTab(index)
		end)
		tabs[index] = tab
	end
	frame.Tabs = tabs
	frame.tabPadding = 0
	frame.minTabWidth = 0
	frame.maxTabWidth = 240

	local listInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	listInset:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET_LEFT, LIST_TOP)
	listInset:SetPoint("TOPRIGHT", frame, "TOPRIGHT", INSET_RIGHT, LIST_TOP)
	listInset:SetHeight(LIST_HEIGHT)
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
	header:SetPoint("TOPLEFT", listInset, "BOTTOMLEFT", 0, -GAP)
	header:SetPoint("TOPRIGHT", listInset, "BOTTOMRIGHT", 0, -GAP)
	frame.header = header

	local editorInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	editorInset:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -GAP)
	editorInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", INSET_RIGHT, BOTTOM_OFFSET)
	frame.editorInset = editorInset

	local delete = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	delete:SetSize(DELETE_WIDTH, BUTTON_HEIGHT)
	delete:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 8)
	delete:SetText(L["Delete"])
	local new = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	new:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	new:SetPoint("LEFT", delete, "RIGHT", GAP, 0)
	new:SetText(L["New"])
	local save = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	save:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	save:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 8)
	save:SetText(L["Save"])
	local cancel = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	cancel:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	cancel:SetPoint("RIGHT", save, "LEFT", -GAP, 0)
	cancel:SetText(L["Cancel"])

	frame.deleteButton = delete
	frame.newButton = new
	frame.saveButton = save
	frame.cancelButton = cancel

	Window.tab = 1
	Window.dirty = false
	Window.drafts = {}
	Window.deleteArmed = false
	Window.selected = nil
	Window.combat = false

	frame.editor = ns.Editor.Create(editorInset)
	editorInset:SetScript("OnSizeChanged", function()
		if editorInset:GetWidth() > 1 and frame:IsShown() then
			frame.editor:RefreshAll()
		end
	end)
	frame.editor.onEdited = function()
		Window:OnTextEdited()
	end
	frame.editor.onEscape = function()
		Window.ClosePanel()
	end
	frame.iconSelector = ns.IconSelector.Create(frame)

	header.change:SetScript("OnClick", function()
		Window:OpenNameAndIcon()
	end)
	delete:SetScript("OnClick", function()
		Window:Delete()
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

	frame:SetScript("OnEvent", function(_, event)
		Window:OnEvent(event)
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

---@param row MacroAssistRow
---@param data table
function Window:InitializeRow(row, data)
	row.macroIndex = data.index
	row.Icon:SetTexture(data.icon)
	row.Name:SetText(data.name or "")
	row.Summary:SetText(data.summary or "")
	row.Summary:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	row.Selected:SetShown(data.index == self.selected)
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
	self:LeaveSelected()
	self.tab = index
	self.deleteArmed = false
	self.desiredPosition = 1
	for tabIndex, tab in ipairs(self.frame.Tabs) do
		SelectTabArt(tab, tabIndex == index)
	end
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

function Window:RefreshList()
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

	local provider = CreateDataProvider()
	for index = 1, count do
		local actual = base + index
		local name, icon, body = GetMacroInfo(actual)
		if name then
			provider:Insert({
				index = actual,
				name = name,
				icon = icon,
				summary = ns.Explain(body or ""),
			})
		end
	end
	self.frame.scrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
	self.frame.empty:SetShown(count == 0)
	if self.frame.scrollBox.ForEachFrame then
		self.frame.scrollBox:ForEachFrame(function(row)
			---@cast row MacroAssistRow
			row.Selected:SetShown(row.macroIndex == self.selected)
		end)
	end
	if position and self.frame.scrollBox.ScrollToElementDataIndex then
		self.frame.scrollBox:ScrollToElementDataIndex(position, ScrollBoxConstants.AlignNearest)
	end
	self:UpdateHeader()
	self:UpdateButtons()
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

function Window:SaveCurrent()
	if not self.dirty or not self.selected then
		return true
	end
	if InCombatLockdown() then
		return false
	end
	EditMacro(self.selected, nil, nil, self.frame.editor:GetText())
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
	local header = self.frame.header
	if not self.selected then
		header.icon:SetTexture(nil)
		header.name:SetText(L["No macro selected"])
		header.meta:SetText("")
		return
	end
	local name, icon = GetMacroInfo(self.selected)
	header.icon:SetTexture(icon)
	header.name:SetText(name or L["No macro selected"])
	local count = self.count or 0
	if self.tab == 1 then
		header.meta:SetText(L["General macro · %d of %d"]:format(count, MAX_ACCOUNT))
	else
		header.meta:SetText(L["Character macro · %d of %d"]:format(count, MAX_CHARACTER))
	end
end

function Window:UpdateButtons()
	if not self.frame then
		return
	end
	local combat = self.combat == true
	local hasMacro = self.selected ~= nil
	self.frame.deleteButton:SetEnabled(hasMacro and not combat)
	self.frame.deleteButton:SetText(self.deleteArmed and L["Click again to delete"] or L["Delete"])
	self.frame.newButton:SetEnabled((self.count or 0) < (self.maximum or 0) and not combat)
	self.frame.saveButton:SetEnabled(self.dirty and not combat)
	self.frame.cancelButton:SetEnabled(self.dirty)
	self.frame.header.change:SetEnabled(hasMacro and not combat)
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
	DeleteMacro(self.selected)
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
		local actual = CreateMacro(name, icon, nil, self.tab == 2)
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
		EditMacro(self.selected, newName, newIcon)
		self:RefreshList()
	end)
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
	ns.Context.Rebuild()
	self.combat = InCombatLockdown()
	self.deleteArmed = false
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
	frame.editor:ClearFocus()
	frame.editor:HideCompletion()
	if frame.iconSelector then
		frame.iconSelector:Hide()
	end
end

function Window:OnEvent(event)
	local frame = self.frame
	if event == "UPDATE_MACROS" then
		self:RefreshList()
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
