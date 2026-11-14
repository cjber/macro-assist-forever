local _, ns = ...

if ns.broken then
	return
end

-- The compact roster beside the editor. It lists the players in the current party or raid, and a row is a drag
-- source: its OnDragStop delivers the name to the editor under the pointer. The panel is read-only
-- and takes no macro action, so it stays live in combat.

local L = ns.L

local TITLE_HEIGHT = 18
local TITLE_GAP = 4
local INSET_PADDING = 3
local SCROLL_GAP = 4
local SCROLL_WIDTH = 14
local ROW_HEIGHT = 20

---@class MacroAssistRosterRow : Button
---@field Name FontString
---@field Highlight Texture

---@class MacroAssistRosterPanel : Frame
---@field title FontString
---@field inset Frame
---@field scrollBox Frame
---@field scrollBar Frame
---@field empty FontString
---@field provider DataProviderMixin
---@field members MacroAssistRosterMember[]
---@field inGroup boolean
---@field raid boolean

local Panel = {}
ns.RosterPanel = Panel

---@return MacroAssistRosterApi
local function Api()
	return {
		inRaid = function()
			return IsInRaid()
		end,
		groupCount = function()
			return GetNumGroupMembers()
		end,
		name = function(unit)
			return UnitFullName(unit)
		end,
		class = function(unit)
			return UnitClass(unit)
		end,
	}
end

---@param row MacroAssistRosterRow
---@param name string
---@param classFile string?
local function StyleRow(row, name, classFile)
	row.Name:SetText(name)
	local color
	if classFile and type(C_ClassColor) == "table" and type(C_ClassColor.GetClassColor) == "function" then
		color = C_ClassColor.GetClassColor(classFile)
	end
	local r = color and ns.Readable(color.r) or 1
	local g = color and ns.Readable(color.g) or 1
	local b = color and ns.Readable(color.b) or 1
	row.Name:SetTextColor(r or 1, g or 1, b or 1)
end

-- A row's release owns delivery even when there is no native cursor payload. Hiding/recycling
-- the source or receiving a native cursor change cancels the gesture before another drag can use it.
---@param row MacroAssistRosterRow
---@param editor MacroAssistEditor
---@param name string
function Panel.BindDrag(row, editor, name)
	row:RegisterForDrag("LeftButton")
	row:SetScript("OnDragStart", function()
		editor:BeginTextDrag(row, name)
	end)
	row:SetScript("OnDragStop", function()
		editor:EndTextDrag(row, true)
	end)
	row:SetScript("OnHide", function()
		editor:EndTextDrag(row, false)
	end)
	row:RegisterEvent("CURSOR_CHANGED")
	row:SetScript("OnEvent", function()
		editor:EndTextDrag(row, false)
	end)
end

---@param parent Frame
---@param editor MacroAssistEditor
---@return MacroAssistRosterPanel
function Panel.Create(parent, editor)
	local panel = CreateFrame("Frame", nil, parent) --[[@as MacroAssistRosterPanel]]
	panel.members = {}
	panel.inGroup = false
	panel.raid = false
	panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, 0)
	panel.title:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
	panel.title:SetJustifyH("LEFT")
	panel.title:SetWordWrap(false)
	panel.title:SetText(L["Group"])

	panel.inset = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
	panel.inset:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(TITLE_HEIGHT + TITLE_GAP))
	panel.inset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

	panel.scrollBox = CreateFrame("Frame", nil, panel.inset, "WowScrollBoxList")
	panel.scrollBox:SetPoint("TOPLEFT", panel.inset, "TOPLEFT", INSET_PADDING, -INSET_PADDING)
	panel.scrollBox:SetPoint(
		"BOTTOMRIGHT",
		panel.inset,
		"BOTTOMRIGHT",
		-(INSET_PADDING + SCROLL_WIDTH + SCROLL_GAP),
		INSET_PADDING
	)
	panel.scrollBar = CreateFrame("EventFrame", nil, panel.inset, "MinimalScrollBar")
	panel.scrollBar:SetPoint("TOPLEFT", panel.scrollBox, "TOPRIGHT", SCROLL_GAP, 0)
	panel.scrollBar:SetPoint("BOTTOMLEFT", panel.scrollBox, "BOTTOMRIGHT", SCROLL_GAP, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("MacroAssistRosterRowTemplate", function(row, data)
		---@cast row MacroAssistRosterRow
		StyleRow(row, data.name, data.classFile)
		Panel.BindDrag(row, editor, data.name)
		row:SetScript("OnEnter", function(button)
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetText(data.name, 1, 1, 1, 1, true)
			GameTooltip:AddLine(L["Drag a name onto a word to replace it."], 0.8, 0.8, 0.8, true)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function(button)
			if GameTooltip:IsOwned(button) then
				GameTooltip:Hide()
			end
		end)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(panel.scrollBox, panel.scrollBar, view)

	panel.empty = panel.inset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	panel.empty:SetPoint("TOPLEFT", panel.inset, "TOPLEFT", 8, -8)
	panel.empty:SetPoint("BOTTOMRIGHT", panel.inset, "BOTTOMRIGHT", -8, 8)
	panel.empty:SetJustifyH("CENTER")
	panel.empty:SetJustifyV("MIDDLE")
	panel.empty:SetTextColor(0.55, 0.55, 0.55)
	panel.empty:SetText(L["Not in a group."])
	panel.empty:Hide()

	panel.provider = CreateDataProvider() --[[@as DataProviderMixin]]

	---@return MacroAssistRosterPanel
	function panel:Refresh()
		editor:EndTextDrag(nil, false)
		local inGroup, raid, members = ns.Roster.Read(Api())
		self.inGroup = inGroup
		self.raid = raid
		self.members = members
		self.title:SetText(raid and L["Raid"] or inGroup and L["Party"] or L["Group"])
		local provider = CreateDataProvider() --[[@as DataProviderMixin]]
		for _, member in ipairs(members) do
			provider:Insert(member)
		end
		self.provider = provider
		self.scrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
		self.empty:SetShown(#members == 0)
		if #members == 0 then
			self.empty:SetText(inGroup and L["No group members."] or L["Not in a group."])
		end
		return self
	end

	panel:Refresh()
	return panel
end
