local _, ns = ...

-- The History window: the selected macro's saved snapshots, newest first, and a Deleted section for macros that are
-- no longer in the store. It only lists and selects; the restore itself goes through MacroWindow's write path, so it
-- takes the same snapshot, the same combat refusal and the same list refresh as Save.

local L = ns.L

local WIDTH = 440
local HEIGHT = 420
local ROW_HEIGHT = 38
local INSET_PADDING = 6
local SCROLL_GAP = 4
local SCROLL_WIDTH = 18
local SCROLL_RIGHT_PADDING = 4
local BUTTON_WIDTH = 90
local BUTTON_HEIGHT = 24
local BOTTOM = 8

---@class MacroAssistHistoryRow : Button
---@field Time FontString
---@field Summary FontString
---@field Selected Texture
---@field SelectedBar Texture
---@field Highlight Texture

---@class MacroAssistHistoryFrame : Frame
---@field window MacroAssistWindow?
---@field TitleContainer MacroAssistTitleContainer
---@field PortraitContainer MacroAssistPortraitContainer
---@field Inset Frame
---@field CloseButton Button
---@field scrollBox MacroAssistScrollBox
---@field restoreButton Button
---@field combatText FontString
---@field empty FontString
---@field Refresh fun(self: MacroAssistHistoryFrame, window: MacroAssistWindow)
---@field UpdateButtons fun(self: MacroAssistHistoryFrame)
---@field Restore fun(self: MacroAssistHistoryFrame)

local Panel = {}

---@param time number?
---@return string
local function FormatTime(time)
	if type(time) ~= "number" or time <= 0 then
		return ""
	end
	local formatted = date("%Y-%m-%d %H:%M", time)
	return type(formatted) == "string" and formatted or ""
end

---@param parent Frame
---@return MacroAssistHistoryFrame
function Panel.Create(parent)
	local frame = CreateFrame("Frame", nil, parent, "ButtonFrameTemplate") --[[@as MacroAssistHistoryFrame]]
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(parent:GetFrameLevel() + 40)
	frame:SetClampedToScreen(true)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame.TitleContainer.TitleText:SetText(L["History"])
	frame.PortraitContainer.portrait:SetTexture("Interface\\Icons\\inv_misc_note_01")
	frame.Inset:Hide()
	frame.CloseButton:SetScript("OnClick", function()
		frame:Hide()
	end)

	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -50)
	inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 42)

	local scrollBox = CreateFrame("Frame", nil, inset, "WowScrollBoxList") --[[@as MacroAssistScrollBox]]
	scrollBox:SetPoint("TOPLEFT", inset, "TOPLEFT", INSET_PADDING, -INSET_PADDING)
	scrollBox:SetPoint(
		"BOTTOMRIGHT",
		inset,
		"BOTTOMRIGHT",
		-(SCROLL_WIDTH + SCROLL_GAP + SCROLL_RIGHT_PADDING),
		INSET_PADDING
	)
	local scrollBar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", SCROLL_GAP, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", SCROLL_GAP, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("MacroAssistHistoryRowTemplate", function(row, data)
		---@cast row MacroAssistHistoryRow
		Panel.InitializeRow(frame, row, data)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox --[[@as ScrollBoxListMixin]], scrollBar, view)
	frame.scrollBox = scrollBox

	local empty = inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	empty:SetPoint("CENTER", inset, "CENTER", 0, 0)
	empty:SetText(L["No history yet."])
	empty:SetTextColor(0.55, 0.55, 0.55)
	empty:Hide()
	frame.empty = empty

	local restore = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	restore:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	restore:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, BOTTOM)
	restore:SetText(L["Restore"])
	restore:SetScript("OnClick", function()
		frame:Restore()
	end)
	frame.restoreButton = restore

	local combatText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	combatText:SetPoint("LEFT", frame, "BOTTOMLEFT", 12, BOTTOM + BUTTON_HEIGHT / 2)
	combatText:SetText(L["Saving is disabled in combat."])
	combatText:SetTextColor(1, 0.25, 0.25)
	combatText:Hide()
	frame.combatText = combatText

	function frame:UpdateButtons()
		local window = self.window
		local combat = window ~= nil and window.combat == true
		self.restoreButton:SetEnabled(window ~= nil and window.historySelected ~= nil and not combat)
		self.combatText:SetShown(combat)
	end

	function frame:Restore()
		local window = self.window
		local selection = window and window.historySelected
		if not window or not selection then
			return
		end
		window:RestoreSnapshot(selection.key, selection.entry)
	end

	function frame:Refresh(window)
		self.window = window or self.window
		if not self.window then
			return
		end
		local owner = self.window
		---@cast owner MacroAssistWindow
		local db = MacroAssistForeverDB
		local provider = CreateDataProvider()
		local rows = {}
		local live = owner:LiveMacroNames()
		local selectedName
		if owner.selected then
			selectedName = GetMacroInfo(owner.selected)
		end
		-- The newest snapshot is compared with the macro's live text; every older one with the next newer snapshot.
		local current
		if selectedName then
			local _, currentIcon, currentBody = GetMacroInfo(owner.selected)
			current = { name = selectedName, icon = currentIcon, body = currentBody or "" }
		end

		local function addEntries(name, entries, deleted, newerOf)
			for index, entry in ipairs(entries) do
				rows[#rows + 1] = {
					key = name,
					entry = entry,
					deleted = deleted,
					newer = deleted and nil or (index == 1 and newerOf or entries[index - 1]),
				}
			end
		end

		local selectedEntries = selectedName and ns.History.Entries(db, selectedName) or {}
		if #selectedEntries > 0 then
			rows[#rows + 1] = { header = L["This macro"] }
			addEntries(selectedName, selectedEntries, false, current)
		end
		local deleted = ns.History.Deleted(db, live)
		if #deleted > 0 then
			rows[#rows + 1] = { header = L["Deleted"] }
			for _, record in ipairs(deleted) do
				addEntries(record.name, record.entries, true)
			end
		end

		local selection = owner.historySelected
		for _, row in ipairs(rows) do
			if row.header then
				provider:Insert({ header = row.header })
			else
				local summary
				if row.deleted then
					summary = ns.ExplainSummary(row.entry.body or "")
					if summary == "" then
						summary = L["No commands in this macro yet."]
					end
					summary = L["%s: %s"]:format(row.key, summary)
				else
					summary = ns.History.ChangeSummary(row.entry, row.newer)
				end
				if summary == "" then
					summary = L["No change"]
				end
				provider:Insert({
					key = row.key,
					entry = row.entry,
					time = FormatTime(row.entry.time),
					summary = summary,
					selected = selection ~= nil and selection.key == row.key and selection.entry == row.entry,
				})
			end
		end
		self.scrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
		self.empty:SetShown(#rows == 0)
		self:UpdateButtons()
	end

	frame:UpdateButtons()
	return frame
end

---@param frame MacroAssistHistoryFrame
---@param row MacroAssistHistoryRow
---@param data table
function Panel.InitializeRow(frame, row, data)
	row.Selected:SetShown(data.selected == true)
	row.SelectedBar:SetShown(data.selected == true)
	row.Highlight:Hide()
	if data.header then
		row.Time:Hide()
		row.Summary:Show()
		row.Summary:SetText(data.header)
		row.Summary:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		row:EnableMouse(false)
		row:SetScript("OnClick", nil)
		row:SetScript("OnEnter", nil)
		row:SetScript("OnLeave", nil)
		return
	end
	row.Time:Show()
	row.Summary:Show()
	row.Time:SetText(data.time or "")
	row.Summary:SetText(data.summary or "")
	if data.selected then
		row.Summary:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	else
		row.Summary:SetTextColor(1, 1, 1)
	end
	row:EnableMouse(true)
	row:SetScript("OnClick", function()
		local window = frame.window
		if not window then
			return
		end
		window.historySelected = { key = data.key, entry = data.entry }
		frame:Refresh(window)
	end)
	row:SetScript("OnEnter", function()
		row.Highlight:Show()
	end)
	row:SetScript("OnLeave", function()
		row.Highlight:Hide()
	end)
end

ns.HistoryPanel = Panel
