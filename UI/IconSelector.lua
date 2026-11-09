local _, ns = ...

-- Our own icon picker: the client template and its icon data provider, parented to our window so it hides with it.
-- Nothing here reaches MacroFrame or its popup; the provider is created and released on this instance only.

local L = ns.L

local Selector = {}

---@class MacroAssistSelectedIconButton : Button
---@field GetIconTexture fun(self: MacroAssistSelectedIconButton): any
---@field SetIconTexture fun(self: MacroAssistSelectedIconButton, icon: any)

---@class MacroAssistSelectedIconArea : Frame
---@field SelectedIconButton MacroAssistSelectedIconButton

---@class MacroAssistIconSelectorBorderBox : Frame
---@field EditBoxHeaderText FontString
---@field IconSelectorEditBox EditBox
---@field OkayButton Button
---@field SelectedIconArea MacroAssistSelectedIconArea

---@class MacroAssistIconSelectorList : Frame
---@field SetSelectionsDataProvider fun(self: MacroAssistIconSelectorList, get: function, count: function)
---@field SetSelectedCallback fun(self: MacroAssistIconSelectorList, callback: fun(index: integer, icon: any))
---@field SetSelectedIndex fun(self: MacroAssistIconSelectorList, index: integer)
---@field ScrollToSelectedIndex? fun(self: MacroAssistIconSelectorList)

---@class MacroAssistIconSelector : Frame
---@field iconDataProvider? table
---@field startName? string
---@field startIcon? any
---@field onAccept? fun(name: string, icon: any)
---@field BorderBox MacroAssistIconSelectorBorderBox
---@field IconSelector MacroAssistIconSelectorList
---@field GetIconByIndex fun(self: MacroAssistIconSelector, index: integer): any
---@field GetIndexOfIcon fun(self: MacroAssistIconSelector, icon: any): integer?
---@field GetNumIcons fun(self: MacroAssistIconSelector): integer
---@field GetSelectedIndex fun(self: MacroAssistIconSelector): integer?
---@field OkayButton_OnClick fun(self: MacroAssistIconSelector)
---@field Open fun(self: MacroAssistIconSelector, name: string, icon: any, accept: fun(name: string, icon: any))

---@param parent Frame
---@return MacroAssistIconSelector
function Selector.Create(parent)
	local frame = CreateFrame("Frame", nil, parent, "IconSelectorPopupFrameTemplate") --[[@as MacroAssistIconSelector]]
	frame:Hide()
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(parent:GetFrameLevel() + 50)
	frame:SetClampedToScreen(true)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 6, 6)
	frame.BorderBox.EditBoxHeaderText:SetText(L["Name and icon"])
	-- The template's own OnShow and OnHide scripts run the shared mixin on this frame; our scripts call the mixin
	-- first, then set up our provider. Both frames and fields here are ours, not Blizzard's.
	frame:SetScript("OnHide", function(self)
		---@cast self MacroAssistIconSelector
		---@diagnostic disable-next-line: param-type-mismatch
		IconSelectorPopupFrameTemplateMixin.OnHide(self)
		if self.iconDataProvider then
			self.iconDataProvider:Release()
			self.iconDataProvider = nil
		end
	end)
	frame:SetScript("OnShow", function(self)
		---@cast self MacroAssistIconSelector
		---@diagnostic disable-next-line: param-type-mismatch
		IconSelectorPopupFrameTemplateMixin.OnShow(self)
		if not self.iconDataProvider then
			self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Spellbook)
		end
		self.IconSelector:SetSelectionsDataProvider(function(index)
			return self:GetIconByIndex(index)
		end, function()
			return self:GetNumIcons()
		end)
		self.IconSelector:SetSelectedCallback(function(_, icon)
			self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
		end)
		local index = self.startIcon and self:GetIndexOfIcon(self.startIcon) or 1
		index = index or 1
		self.IconSelector:SetSelectedIndex(index)
		self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self:GetIconByIndex(index))
		self.BorderBox.IconSelectorEditBox:SetText(self.startName or "")
		self.BorderBox.IconSelectorEditBox:SetFocus()
		if self.IconSelector.ScrollToSelectedIndex then
			self.IconSelector:ScrollToSelectedIndex()
		end
	end)
	frame.OkayButton_OnClick = function(self)
		local name = self.BorderBox.IconSelectorEditBox:GetText() or ""
		name = name:gsub('"', "")
		local icon = self.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
		local accept = self.onAccept
		self:Hide()
		if accept and name ~= "" then
			accept(name, icon)
		end
	end

	function frame:Open(name, icon, accept)
		self.startName = name or ""
		self.startIcon = icon
		self.onAccept = accept
		self:Show()
	end

	return frame
end

ns.IconSelector = Selector
