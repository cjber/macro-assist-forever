local _, ns = ...

if ns.broken then
	return
end

-- The Shorten preview. It shows only the lines a lossless rewrite changes: the old line in red, the new one in green,
-- and the character count before and after. Apply puts the new text in the editor without saving, so the player still
-- has Cancel and Save, and can undo the rewrite by cancelling the editor.

local L = ns.L

local WIDTH = 480
local HEIGHT = 400
local INSET_PADDING = 8
local BUTTON_WIDTH = 90
local BUTTON_HEIGHT = 24
local BOTTOM = 8
local HINT_TOP = 50
local HINT_HEIGHT = 30
local BOX_BOTTOM = 76
local STATUS_BOTTOM = 48

local MUTED = { 0.55, 0.55, 0.55 }
local GREEN = { 0.2, 1, 0.6 }
local YELLOW = { 1, 0.82, 0.2 }
local COLOUR_CLOSE = "|r"
local COLOUR_RED = "|cffff4040"
local COLOUR_GREEN = "|cff33ff99"
local COLOUR_MUTED = "|cff9d9d9d"

---@class MacroAssistShortenPanel : Frame
---@field TitleContainer MacroAssistTitleContainer
---@field PortraitContainer MacroAssistPortraitContainer
---@field Inset Frame
---@field CloseButton Button
---@field inset Frame
---@field diff FontString
---@field status FontString
---@field applyButton Button
---@field cancelButton Button
---@field onApply fun(text: string)
---@field oldText string?
---@field newText string?

local Panel = {}

---@param text string
---@return string
local function Escaped(text)
	return (text:gsub("|", "||"))
end

-- The changed lines of one rewrite, as the colour-coded body of the diff panel.
---@param oldText string
---@param newText string
---@return string
function Panel.Diff(oldText, newText)
	local parts = {}
	for _, row in ipairs(ns.History.LineDiff(oldText, newText)) do
		if row.kind == "changed" then
			parts[#parts + 1] = COLOUR_RED .. "-" .. Escaped(row.old or "") .. COLOUR_CLOSE
			parts[#parts + 1] = COLOUR_GREEN .. "+" .. Escaped(row.new or "") .. COLOUR_CLOSE
		elseif row.kind == "removed" then
			parts[#parts + 1] = COLOUR_RED .. "-" .. Escaped(row.old or "") .. COLOUR_CLOSE
		elseif row.kind == "added" then
			parts[#parts + 1] = COLOUR_GREEN .. "+" .. Escaped(row.new or "") .. COLOUR_CLOSE
		end
	end
	if #parts == 0 then
		return COLOUR_MUTED .. L["No change."] .. COLOUR_CLOSE
	end
	return table.concat(parts, "\n")
end

---@param parent Frame
---@param onApply fun(text: string)
---@return MacroAssistShortenPanel
function Panel.Create(parent, onApply)
	local frame = CreateFrame("Frame", nil, parent, "ButtonFrameTemplate") --[[@as MacroAssistShortenPanel]]
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(parent:GetFrameLevel() + 40)
	frame:SetClampedToScreen(true)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame.TitleContainer.TitleText:SetText(L["Shorten macro"])
	frame.PortraitContainer.portrait:SetTexture(ns.Icon)
	frame.Inset:Hide()
	frame.CloseButton:SetScript("OnClick", function()
		Panel.Close(frame)
	end)
	frame.onApply = onApply

	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HINT_TOP)
	hint:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -HINT_TOP)
	hint:SetHeight(HINT_HEIGHT)
	hint:SetJustifyH("LEFT")
	hint:SetJustifyV("TOP")
	hint:SetWordWrap(true)
	hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	hint:SetText(L["This rewrite only removes what the macro does not need."])

	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(HINT_TOP + HINT_HEIGHT + 8))
	inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, BOX_BOTTOM)
	frame.inset = inset

	local diff = inset:CreateFontString(nil, "ARTWORK", "MacroAssistMono")
	diff:SetPoint("TOPLEFT", inset, "TOPLEFT", INSET_PADDING + 2, -(INSET_PADDING + 2))
	diff:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -(INSET_PADDING + 2), INSET_PADDING + 2)
	diff:SetJustifyH("LEFT")
	diff:SetJustifyV("TOP")
	diff:SetWordWrap(false)
	frame.diff = diff

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	status:SetPoint("LEFT", frame, "LEFT", 12, STATUS_BOTTOM)
	status:SetPoint("RIGHT", frame, "RIGHT", -110, STATUS_BOTTOM)
	status:SetJustifyH("LEFT")
	status:SetWordWrap(false)
	frame.status = status

	local apply = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	apply:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	apply:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, BOTTOM)
	apply:SetText(L["Apply"])
	apply:SetScript("OnClick", function()
		local text = frame.newText
		Panel.Close(frame)
		if text and frame.onApply then
			frame.onApply(text)
		end
	end)
	frame.applyButton = apply

	local cancel = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	cancel:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	cancel:SetPoint("RIGHT", apply, "LEFT", -6, 0)
	cancel:SetText(L["Cancel"])
	cancel:SetScript("OnClick", function()
		Panel.Close(frame)
	end)
	frame.cancelButton = cancel

	return frame
end

---@param oldText string
---@param newText string
function Panel.Open(frame, oldText, newText)
	frame.oldText = oldText
	frame.newText = newText
	frame.diff:SetText(Panel.Diff(oldText, newText))
	local oldLength = ns.Length(oldText)
	local newLength = ns.Length(newText)
	frame.status:SetText(L["%d/%d, now %d/%d"]:format(oldLength, ns.MacroLimit, newLength, ns.MacroLimit))
	if newLength > ns.MacroLimit then
		frame.status:SetTextColor(YELLOW[1], YELLOW[2], YELLOW[3])
	else
		frame.status:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
	end
	-- A macro still over the limit after every safe rewrite is a bad sign, not a reason to hide the preview: the
	-- player can still read the diff and decide. Apply only exists when there is a different text to apply.
	frame.applyButton:SetEnabled(newText ~= oldText)
	frame:Show()
end

function Panel.Close(frame)
	frame:Hide()
end

ns.ShortenPanel = {
	Create = Panel.Create,
	Open = Panel.Open,
	Close = Panel.Close,
	Diff = Panel.Diff,
}
